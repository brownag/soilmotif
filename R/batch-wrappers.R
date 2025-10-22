#' Batch Optimization via Rust Backend
#'
#' Efficient optimization of multiple soil profiles with optional parallelization.
#' Supports raster grid cell workflows and large observational datasets.

#' Batch optimize multiple profiles (Rust backend)
#'
#' Fits shape functions to multiple profiles simultaneously using the Rust backend.
#' Collects errors and success/failure information for each profile.
#'
#' @param profiles list of numeric vectors, each representing one soil profile
#' @param initial_params_list list of numeric vectors with initial parameters for each profile.
#'   If length 1, will be recycled for all profiles. If NULL, will use default parameters.
#' @param x numeric vector of depth positions (shared across all profiles).
#'   If NULL, assumes `1:length(profiles[[1]])`.
#' @param shape_type character name of shape function
#'   ("uniform", "gradational", "exponential", "wetting_front", "abrupt", "peak", "minimax")
#' @param ascending logical direction flag (TRUE = increasing, FALSE = decreasing)
#' @param objective_type character objective function ("rmse", "sse", "mae", "r2")
#'
#' @return list (S3 class "batch_result") with elements:
#'   - profile_ids: integer vector of profile indices (0-based)
#'   - params: list of numeric vectors (NULL for failed profiles)
#'   - rmse_values: numeric vector of objective values
#'   - converged: logical vector of convergence flags
#'   - errors: character vector of error messages (NA_character_ for successful)
#'   - method: character indicating method used (e.g., "Sequential", "Rayon Parallel")
#'   - summary: character summary string
#'   - failed_count: integer number of failed profiles
#'
#' @details
#' Error handling: By default halts on first error (as instructed). If a profile
#' optimization fails, it is marked with an error message for spatial debugging
#' (e.g., identify which grid cells failed in raster data).
#'
#' Raster grid cells: Ideal for workflows where each grid cell has a depth profile.
#' Extract profiles by iterating through raster cells or using terra::values() with
#' appropriate reshaping.
#'
#' @export
#' @keywords internal
#' @seealso \code{\link{sm_optim}}, \code{\link{sm_motif}}, \code{\link{batch_get_successful}}, \code{\link{batch_get_failed}}, \code{\link{as_summary_table}}
#' @examples
#' \dontrun{
#'   # Single profile (for testing)
#'   profile <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))
#'   result <- batch_optimize_profiles(
#'     profiles = list(profile),
#'     initial_params_list = list(c(100, 20)),
#'     shape_type = "wetting_front"
#'   )
#'   print(result)
#'
#'   # Multiple profiles (e.g., raster grid cells)
#'   profiles <- lapply(1:100, function(i) {
#'     c(rep(10 + i * 0.1, 30), seq(10 + i * 0.1, 40 + i * 0.1, length.out = 120),
#'       rep(40 + i * 0.1, 50))
#'   })
#'   result <- batch_optimize_profiles(profiles)
#'   cat(result$summary, "\n")
#'
#'   # Check for failed profiles
#'   failed <- batch_get_failed(result)
#'   if (length(failed) > 0) {
#'     cat("Failed cells:", failed, "\n")
#'   }
#' }
batch_optimize_profiles <- function(profiles,
                                    initial_params_list = NULL,
                                    x = NULL,
                                    shape_type = "wetting_front",
                                    ascending = TRUE,
                                    objective_type = "rmse") {
  if (!rust_backend_available()) {
    stop("Rust backend not available. Cannot perform batch optimization.")
  }

  if (!is.list(profiles) || length(profiles) == 0) {
    stop("profiles must be a non-empty list")
  }

  # Infer depth vector if not provided
  if (is.null(x)) {
    x <- seq_len(length(profiles[[1]]))
  }

  # Handle initial_params_list
  if (is.null(initial_params_list)) {
    # Use default parameters for shape type
    default_params <- switch(shape_type,
      uniform = c(100),
      gradational = c(100, 20),
      exponential = c(100, 20),
      wetting_front = c(100, 20),
      abrupt = c(100, 20),
      peak = c(100, 20),
      minimax = c(100, 20, 50),
      stop("Unknown shape_type: ", shape_type)
    )
    initial_params_list <- rep(list(default_params), length(profiles))
  } else if (!is.list(initial_params_list)) {
    stop("initial_params_list must be a list or NULL")
  } else if (length(initial_params_list) == 1) {
    # Recycle single parameter set for all profiles
    initial_params_list <- rep(initial_params_list, length(profiles))
  } else if (length(initial_params_list) != length(profiles)) {
    stop("initial_params_list must have length 1 or length(profiles)")
  }

  # Ensure all profiles are numeric vectors
  profiles <- lapply(profiles, as.numeric)
  initial_params_list <- lapply(initial_params_list, as.numeric)

  # Call Rust batch optimizer
  tryCatch({
    result <- .Call("wrap__batch_optimize_profiles_rust",
      profiles,
      initial_params_list,
      as.numeric(x),
      as.character(shape_type),
      as.logical(ascending),
      as.character(objective_type),
      PACKAGE = "soilmotif"
    )

    # Validate result
    if (is.null(result) || !is.list(result)) {
      stop("Batch optimization returned invalid result")
    }

    # Ensure profile_ids are 1-based for R (convert from 0-based Rust indices)
    if (!is.null(result$profile_ids)) {
      result$profile_ids <- as.integer(result$profile_ids + 1L)
    }

    # Set class for S3 methods
    class(result) <- c("batch_result", "list")
    result
  }, error = function(e) {
    stop("Batch optimization failed: ", e$message)
  })
}

#' Extract successful results from batch result
#'
#' @param x batch_result object
#' @param include_rmse logical include RMSE values in output
#'
#' @return data.frame with profile_id, params (as list column), and optionally rmse
#' @export
#' @keywords internal
#' @seealso \code{\link{batch_optimize_profiles}}, \code{\link{batch_get_failed}}, \code{\link{as_summary_table}}
batch_get_successful <- function(x, include_rmse = TRUE) {
  if (!inherits(x, "batch_result")) {
    stop("x must be a batch_result object")
  }

  # Find successful profiles (error == empty string or NA)
  successful_idx <- which(x$errors == "" | is.na(x$errors))

  if (length(successful_idx) == 0) {
    # No successful profiles
    return(data.frame(
      profile_id = integer(0),
      params = list(),
      rmse = numeric(0)
    ))
  }

  result <- data.frame(
    profile_id = x$profile_ids[successful_idx],
    stringsAsFactors = FALSE
  )

  # Add params as list column
  result$params <- x$params[successful_idx]

  if (include_rmse) {
    result$rmse <- x$rmse_values[successful_idx]
  }

  result
}

#' Extract failed profiles from batch result
#'
#' Returns profile IDs and error messages for profiles that failed optimization.
#' Useful for spatial debugging (e.g., identify which raster cells failed).
#'
#' @param x batch_result object
#'
#' @return data.frame with profile_id and error columns (empty if no failures)
#' @export
#' @keywords internal
#' @seealso \code{\link{batch_optimize_profiles}}, \code{\link{batch_get_successful}}, \code{\link{as_summary_table}}
batch_get_failed <- function(x) {
  if (!inherits(x, "batch_result")) {
    stop("x must be a batch_result object")
  }

  # Find failed profiles (error != empty string and not NA)
  failed_idx <- which(x$errors != "" & !is.na(x$errors))

  if (length(failed_idx) == 0) {
    return(data.frame(profile_id = integer(0), error = character(0)))
  }

  data.frame(
    profile_id = x$profile_ids[failed_idx],
    error = x$errors[failed_idx],
    stringsAsFactors = FALSE
  )
}

#' Print batch result summary
#'
#' @param x batch_result object
#' @param ... additional arguments (unused)
#'
#' @return x (invisibly)
#' @export
#' @keywords internal
print.batch_result <- function(x, ...) {
  cat("\n=== Batch Optimization Result ===\n")
  cat(x$summary, "\n")
  cat("Method:", x$method, "\n")

  if (x$failed_count > 0) {
    cat("\nFailed profiles:\n")
    failed_df <- batch_get_failed(x)
    print(failed_df, row.names = FALSE)
  } else {
    cat("\nAll profiles converged successfully.\n")
  }

  invisible(x)
}

#' Convert batch result to summary table
#'
#' Creates a data.frame with optimization results and diagnostics for each profile.
#'
#' @param x batch_result object
#' @param include_params logical include parameters as list column
#'
#' @return data.frame with profile_id, converged, rmse, error, and optionally params
#' @export
#' @keywords internal
#' @seealso \code{\link{batch_optimize_profiles}}, \code{\link{batch_get_successful}}, \code{\link{batch_get_failed}}
as_summary_table <- function(x, include_params = TRUE) {
  if (!inherits(x, "batch_result")) {
    stop("x must be a batch_result object")
  }

  result <- data.frame(
    profile_id = x$profile_ids,
    converged = x$converged,
    rmse = x$rmse_values,
    error = ifelse(x$errors == "NA", NA_character_, x$errors),
    stringsAsFactors = FALSE
  )

  if (include_params) {
    result$params <- x$params
  }

  result
}

#' Extract component data from batch result
#'
#' @param x batch_result object
#' @param what character one of "params", "rmse", "converged", "errors", "failed_ids"
#'
#' @return Extracted component
#' @export
#' @keywords internal
#' @seealso \code{\link{batch_optimize_profiles}}, \code{\link{batch_get_successful}}, \code{\link{batch_get_failed}}
batch_get <- function(x, what = "params") {
  if (!inherits(x, "batch_result")) {
    stop("x must be a batch_result object")
  }

  switch(what,
    params = x$params,
    rmse = x$rmse_values,
    converged = x$converged,
    errors = x$errors,
    failed_ids = x$profile_ids[which(x$errors != "NA")],
    stop("Unknown component: ", what)
  )
}

#' High-level batch fitting for soil property data
#'
#' Wrapper around batch_optimize_profiles with sensible defaults for common workflows.
#'
#' @param profile_data list of data.frames with columns: id, depth, property.
#'   Alternatively, list of numeric vectors (profiles only).
#' @param shape_type character shape function name
#' @param ascending logical direction flag
#' @param use_rust logical use Rust backend (default TRUE if available)
#' @param objective_type character objective function
#' @param ... additional arguments to batch_optimize_profiles
#'
#' @return batch_result object
#' @export
#' @keywords internal
#' @seealso \code{\link{batch_optimize_profiles}}, \code{\link{sm_optim}}, \code{\link{sm_motif}}
fit_batch_profiles <- function(profile_data,
                               shape_type = "wetting_front",
                               ascending = TRUE,
                               use_rust = TRUE,
                               objective_type = "rmse",
                               ...) {
  # Extract profiles from list of data.frames if needed
  if (is.data.frame(profile_data[[1]])) {
    profiles <- lapply(profile_data, function(df) {
      df$property
    })
  } else {
    profiles <- profile_data
  }

  if (!use_rust || !rust_backend_available()) {
    stop("R backend for batch processing not yet implemented. Use use_rust=TRUE.")
  }

  batch_optimize_profiles(
    profiles = profiles,
    shape_type = shape_type,
    ascending = ascending,
    objective_type = objective_type,
    ...
  )
}
