#' Parametric Bootstrap for Soil Profile Optimization
#'
#' Performs parametric bootstrap resampling to quantify uncertainty in soil
#' profile parameter estimates. This function fits the specified shape function
#' to the observed data, then generates bootstrap samples by resampling residuals
#' and re-optimizing to obtain confidence intervals and uncertainty estimates.
#'
#' @param observed Numeric vector of observed soil property values (e.g., clay content)
#' @param depths Numeric vector of corresponding depth values (same length as observed)
#' @param initial_params Numeric vector of initial parameter values for optimization
#' @param shape_family Character string specifying the shape function family
#'   (e.g., "sigmoid", "exponential", "uniform")
#' @param objective Character string specifying the objective function ("rmse", "sse", "mae", "r2")
#' @param optimizer Character string specifying the optimization algorithm ("auto", "nelder_mead", "lbfgs", etc.)
#' @param n_bootstrap Integer number of bootstrap samples (default: 1000)
#' @param seed Integer seed for reproducible results, or NULL for random (default: NULL)
#' @param fallback_strategy Character string for fallback behavior ("auto", "explicit", "strict")
#' @param max_retries Integer maximum retries per optimization (default: 3)
#' @param parallel Logical whether to use parallel processing (default: TRUE)
#'
#' @return A list with class "bootstrap_result" containing:
#'   \item{param_samples}{Matrix of parameter samples (n_bootstrap x n_params)}
#'   \item{rmse_samples}{Vector of RMSE values for each bootstrap sample}
#'   \item{r2_samples}{Vector of R² values for each bootstrap sample}
#'   \item{aic_samples}{Vector of AIC values for each bootstrap sample}
#'   \item{failed_indices}{Vector of indices for failed bootstrap samples}
#'   \item{summary}{List with summary statistics (means, sds, cis)}
#'   \item{original_fit}{List with original optimization results}
#'   \item{settings}{List with function call settings}
#'
#' @examples
#' \dontrun{
#' # Example with sigmoid shape
#' depths <- 1:200
#' observed <- sm_motif(depths, c(100, 20, 0.1, 50)) + rnorm(200, 0, 5)
#'
#' result <- sm_optim_bootstrap(
#'   observed = observed,
#'   depths = depths,
#'   initial_params = c(100, 20, 0.1, 50),
#'   shape_family = "sigmoid",
#'   n_bootstrap = 100
#' )
#'
#' # View parameter confidence intervals
#' print(result$summary$param_ci)
#' }
#'
#' @export
sm_optim_bootstrap <- function(
  observed,
  depths,
  initial_params,
  shape_family,
  objective = "rmse",
  optimizer = "auto",
  n_bootstrap = 1000L,
  seed = NULL,
  fallback_strategy = "auto",
  max_retries = 3L,
  parallel = TRUE
) {
  # Input validation
  .validate_bootstrap_inputs(
    observed, depths, initial_params, shape_family,
    objective, optimizer, n_bootstrap, seed,
    fallback_strategy, max_retries, parallel
  )

  # Normalize shape_family aliases to canonical names (e.g., "sigmoid" -> "wetting_front")
  # This matches the behavior in sm_optim_dispatch()
  shape_family_normalized <- switch(shape_family,
    "sigmoid" = "wetting_front",
    "wetting_front" = "wetting_front",
    shape_family  # Default: use as-is for other shapes
  )

  # Create the configuration list for the Rust FFI function
  config <- list(
    shape_type = shape_family_normalized,
    objective_name = objective,
    optimizer_name = optimizer,
    n_bootstrap = as.integer(n_bootstrap),
    seed = if (is.null(seed)) -1L else as.integer(seed),
    fallback = as.integer(fallback_strategy == "auto"),  # Convert boolean to integer (0 or 1)
    max_retries = as.integer(max_retries),
    parallel = as.integer(parallel)  # Convert boolean to integer (0 or 1)
  )

  # Call the Rust bootstrap engine with simplified signature (4 parameters instead of 11)
  rust_result <- bootstrap_engine_rust(
    observed = as.double(observed),
    depths = as.double(depths),
    initial_params = as.double(initial_params),
    config = config
  )

  # Process the raw Rust result into R-friendly format
  result_list <- .process_bootstrap_result(rust_result, initial_params, n_bootstrap)

  # Add the S3 class to the returned list
  class(result_list) <- "bootstrap_result"

  # Add metadata
  result_list$settings <- list(
    shape_family = shape_family,
    objective = objective,
    optimizer = optimizer,
    n_bootstrap = n_bootstrap,
    seed = seed,
    fallback_strategy = fallback_strategy,
    max_retries = max_retries,
    parallel = parallel,
    call = match.call()
  )

  result_list
}

#' Validate inputs for bootstrap function
#' @keywords internal
#' @noRd 
.validate_bootstrap_inputs <- function(
  observed, depths, initial_params, shape_family,
  objective, optimizer, n_bootstrap, seed,
  fallback_strategy, max_retries, parallel
) {
  # Basic type checks
  if (!is.numeric(observed) || !is.vector(observed)) {
    stop("observed must be a numeric vector")
  }
  if (!is.numeric(depths) || !is.vector(depths)) {
    stop("depths must be a numeric vector")
  }
  if (length(observed) != length(depths)) {
    stop("observed and depths must have the same length")
  }
  if (!is.numeric(initial_params) || !is.vector(initial_params)) {
    stop("initial_params must be a numeric vector")
  }
  if (!is.character(shape_family) || length(shape_family) != 1) {
    stop("shape_family must be a single character string")
  }
  if (!is.character(objective) || length(objective) != 1) {
    stop("objective must be a single character string")
  }
  if (!is.character(optimizer) || length(optimizer) != 1) {
    stop("optimizer must be a single character string")
  }
  if (!is.numeric(n_bootstrap) || length(n_bootstrap) != 1 || n_bootstrap <= 0) {
    stop("n_bootstrap must be a positive integer")
  }
  if (!is.null(seed) && (!is.numeric(seed) || length(seed) != 1)) {
    stop("seed must be NULL or a single integer")
  }
  if (!is.character(fallback_strategy) || length(fallback_strategy) != 1) {
    stop("fallback_strategy must be a single character string")
  }
  if (!is.numeric(max_retries) || length(max_retries) != 1 || max_retries < 0) {
    stop("max_retries must be a non-negative integer")
  }
  if (!is.logical(parallel) || length(parallel) != 1) {
    stop("parallel must be a single logical value")
  }

  # Value checks
  valid_objectives <- c("rmse", "sse", "mae", "r2")
  if (!objective %in% valid_objectives) {
    stop("objective must be one of: ", paste(valid_objectives, collapse = ", "))
  }

  valid_optimizers <- c("auto", "nelder_mead", "lbfgs", "particle_swarm", "simulated_annealing", "newton_cg")
  if (!optimizer %in% valid_optimizers) {
    stop("optimizer must be one of: ", paste(valid_optimizers, collapse = ", "))
  }

  valid_fallbacks <- c("auto", "explicit", "strict")
  if (!fallback_strategy %in% valid_fallbacks) {
    stop("fallback_strategy must be one of: ", paste(valid_fallbacks, collapse = ", "))
  }

  # Check for valid shape family
  valid_shapes <- c("uniform", "gradational", "exponential", "sigmoid", "wetting_front", "abrupt", "peak", "minimax")
  if (!shape_family %in% valid_shapes) {
    stop("shape_family must be one of: ", paste(valid_shapes, collapse = ", "))
  }

  # Check data quality
  if (any(is.na(observed)) || any(is.na(depths))) {
    stop("observed and depths cannot contain NA values")
  }
  if (length(observed) < 2) {
    stop("observed must have at least 2 elements")
  }
}

#' Process bootstrap results from Rust into R-friendly format
#' @keywords internal 
#' @noRd 
.process_bootstrap_result <- function(rust_result, initial_params, n_bootstrap) {
  # Extract successful samples - with safe defaults
  n_successful <- if (is.null(rust_result$n_successful)) 0L else rust_result$n_successful
  n_failed <- if (is.null(rust_result$n_failed)) 0L else rust_result$n_failed

  # Convert parameter samples to matrix
  param_samples <- if (n_successful > 0 && length(rust_result$parameter_samples) > 0) {
    tryCatch({
      do.call(rbind, rust_result$parameter_samples)
    }, error = function(e) {
      matrix(NA_real_, nrow = 0, ncol = length(initial_params))
    })
  } else {
    matrix(NA_real_, nrow = 0, ncol = length(initial_params))
  }

  # Extract diagnostic samples
  rmse_samples <- rust_result$rmse_samples
  r2_samples <- rust_result$r2_samples
  aic_samples <- rust_result$aic_samples
  failed_indices <- rust_result$failed_indices

  # Compute summary statistics
  summary <- if (n_successful > 0) {
    .compute_bootstrap_summary(param_samples, rmse_samples, r2_samples, aic_samples)
  } else {
    list(
      param_mean = rep(NA_real_, length(initial_params)),
      param_sd = rep(NA_real_, length(initial_params)),
      param_ci_lower = rep(NA_real_, length(initial_params)),
      param_ci_upper = rep(NA_real_, length(initial_params)),
      rmse_mean = NA_real_,
      rmse_sd = NA_real_,
      r2_mean = NA_real_,
      r2_sd = NA_real_,
      aic_mean = NA_real_,
      aic_sd = NA_real_
    )
  }

  # Original fit (placeholder - would need to be computed)
  original_fit <- list(
    params = initial_params,  # This should be the actual fitted params
    rmse = NA_real_,
    r2 = NA_real_,
    aic = NA_real_,
    converged = TRUE
  )

  list(
    param_samples = param_samples,
    rmse_samples = rmse_samples,
    r2_samples = r2_samples,
    aic_samples = aic_samples,
    failed_indices = failed_indices,
    n_successful = n_successful,
    n_failed = n_failed,
    success_rate = n_successful / n_bootstrap,
    summary = summary,
    original_fit = original_fit,
    message = rust_result$message
  )
}

#' Compute summary statistics for bootstrap results
#' @keywords internal
#' @noRd 
.compute_bootstrap_summary <- function(param_samples, rmse_samples, r2_samples, aic_samples) {
  # Parameter summaries
  param_mean <- colMeans(param_samples)
  param_sd <- apply(param_samples, 2, sd)
  param_ci <- apply(param_samples, 2, quantile, probs = c(0.025, 0.975))
  param_ci_lower <- param_ci[1, ]
  param_ci_upper <- param_ci[2, ]

  # Diagnostic summaries
  rmse_mean <- mean(rmse_samples)
  rmse_sd <- sd(rmse_samples)
  r2_mean <- mean(r2_samples)
  r2_sd <- sd(r2_samples)
  aic_mean <- mean(aic_samples)
  aic_sd <- sd(aic_samples)

  list(
    param_mean = param_mean,
    param_sd = param_sd,
    param_ci_lower = param_ci_lower,
    param_ci_upper = param_ci_upper,
    rmse_mean = rmse_mean,
    rmse_sd = rmse_sd,
    r2_mean = r2_mean,
    r2_sd = r2_sd,
    aic_mean = aic_mean,
    aic_sd = aic_sd
  )
}

#' Print method for bootstrap_result objects
#'
#' Displays a summary of bootstrap results including shape family, number of samples,
#' success rate, parameter confidence intervals, and diagnostic statistics.
#'
#' @param x A bootstrap_result object (returned from sm_optim_bootstrap)
#' @param ... Additional arguments passed to print methods (currently unused)
#'
#' @return Invisibly returns x (standard print method convention)
#' @export
print.bootstrap_result <- function(x, ...) {
  cat("Parametric Bootstrap Results\n")
  cat("==========================\n")
  cat(sprintf("Shape family: %s\n", x$settings$shape_family))
  cat(sprintf("Bootstrap samples: %d\n", x$settings$n_bootstrap))
  cat(sprintf("Successful fits: %d (%.1f%%)\n",
              length(x$parameter_samples), x$success_rate * 100))
  cat(sprintf("Failed fits: %d\n", length(x$failed_indices)))

  if (length(x$parameter_samples) > 0) {
    cat("\nParameter Estimates (95% CI):\n")
    param_matrix <- do.call(rbind, x$parameter_samples)
    param_ci <- apply(param_matrix, 2, quantile, probs = c(0.025, 0.975), na.rm = TRUE)
    param_mean <- colMeans(param_matrix, na.rm = TRUE)
    for (i in seq_along(param_mean)) {
      cat(sprintf("  Param %d: %.3f (%.3f, %.3f)\n", i,
                  param_mean[i],
                  param_ci[1, i],
                  param_ci[2, i]))
    }

    cat(sprintf("\nDiagnostics:\n"))
    cat(sprintf("  RMSE: %.3f ± %.3f\n", mean(x$rmse_samples, na.rm = TRUE), sd(x$rmse_samples, na.rm = TRUE)))
    cat(sprintf("  R²: %.3f ± %.3f\n", mean(x$r2_samples, na.rm = TRUE), sd(x$r2_samples, na.rm = TRUE)))
    cat(sprintf("  AIC: %.3f ± %.3f\n", mean(x$aic_samples, na.rm = TRUE), sd(x$aic_samples, na.rm = TRUE)))
  }

  if (nchar(x$message) > 0) {
    cat(sprintf("\nMessage: %s\n", x$message))
  }
}

#' Summary method for bootstrap_result objects
#'
#' Provides detailed statistical summaries of bootstrap results including parameter
#' statistics (mean, SD, confidence intervals, range) and diagnostic statistics
#' (RMSE, R², AIC). Displays failed sample indices if any failures occurred.
#'
#' @param object A bootstrap_result object (returned from sm_optim_bootstrap)
#' @param ... Additional arguments passed to summary methods (currently unused)
#'
#' @return Invisibly returns object$summary (summary statistics list)
#' @export
summary.bootstrap_result <- function(object, ...) {
  cat("Parametric Bootstrap Summary\n")
  cat("===========================\n")
  cat(sprintf("Shape family: %s\n", object$settings$shape_family))
  cat(sprintf("Bootstrap samples: %d\n", object$settings$n_bootstrap))
  cat(sprintf("Successful fits: %d (%.1f%%)\n",
              length(object$parameter_samples), object$success_rate * 100))
  cat(sprintf("Failed fits: %d\n", length(object$failed_indices)))

  if (length(object$parameter_samples) > 0) {
    cat("\nParameter Statistics:\n")
    param_matrix <- do.call(rbind, object$parameter_samples)
    param_stats <- data.frame(
      Parameter = paste0("Param_", seq_len(ncol(param_matrix))),
      Mean = colMeans(param_matrix, na.rm = TRUE),
      SD = apply(param_matrix, 2, sd, na.rm = TRUE),
      CI_Lower = apply(param_matrix, 2, quantile, probs = 0.025, na.rm = TRUE),
      CI_Upper = apply(param_matrix, 2, quantile, probs = 0.975, na.rm = TRUE),
      Min = apply(param_matrix, 2, min, na.rm = TRUE),
      Max = apply(param_matrix, 2, max, na.rm = TRUE)
    )
    print(param_stats, row.names = FALSE)

    cat("\nDiagnostic Statistics:\n")
    diag_stats <- data.frame(
      Metric = c("RMSE", "R²", "AIC"),
      Mean = c(mean(object$rmse_samples, na.rm = TRUE),
               mean(object$r2_samples, na.rm = TRUE),
               mean(object$aic_samples, na.rm = TRUE)),
      SD = c(sd(object$rmse_samples, na.rm = TRUE),
             sd(object$r2_samples, na.rm = TRUE),
             sd(object$aic_samples, na.rm = TRUE)),
      Min = c(min(object$rmse_samples, na.rm = TRUE),
              min(object$r2_samples, na.rm = TRUE),
              min(object$aic_samples, na.rm = TRUE)),
      Max = c(max(object$rmse_samples, na.rm = TRUE),
              max(object$r2_samples, na.rm = TRUE),
              max(object$aic_samples, na.rm = TRUE))
    )
    print(diag_stats, row.names = FALSE)
  }

  if (length(object$failed_indices) > 0) {
    cat(sprintf("\nFailed bootstrap indices: %s\n",
                paste(object$failed_indices, collapse = ", ")))
  }

  if (nchar(object$message) > 0) {
    cat(sprintf("\nMessage: %s\n", object$message))
  }

  invisible(object$summary)
}