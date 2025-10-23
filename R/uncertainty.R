#' Adaptive Bootstrap for Soil Profile Optimization
#'
#' Performs adaptive bootstrap resampling to quantify uncertainty in soil
#' profile parameter estimates. This function fits the specified shape function
#' to the observed data, then generates bootstrap samples. The resampling method
#' adapts based on data resolution: parametric bootstrap for sparse data
#' (n <= sieve_threshold) and sieve bootstrap with AR(1) models for dense data
#' (n > sieve_threshold).
#'
#' @param observed Numeric vector of observed soil property values (e.g., clay content)
#' @param depths Numeric vector of corresponding depth values (same length as observed)
#' @param initial_params Numeric vector of initial parameter values for optimization
#' @param shape_family Character string specifying the shape function family
#'   (e.g., "sigmoid", "exponential", "uniform")
#' @param objective Character string specifying the objective function ("rmse", "sse", "mae", "r2")
#' @param optimizer Character string specifying the optimization algorithm ("auto", "nelder_mead", "lbfgs", etc.)
#' @param n_bootstrap Integer number of bootstrap samples (default: 1000)
#' @param method Character string specifying bootstrap method: "auto" (default, select based on data size),
#'   "parametric" (resample residuals independently), or "sieve" (AR(1) model-based resampling)
#' @param sieve_threshold Integer threshold for automatic method selection (default: 20).
#'   If method="auto", uses parametric if length(observed) <= sieve_threshold, else sieve
#' @param seed Integer seed for reproducible results, or NULL for random (default: NULL)
#' @param fallback_strategy Character string for fallback behavior ("auto", "explicit", "strict").
#'   Only applies when method="auto": if "auto", sieve falls back to parametric on AR(1) fit failure
#' @param strict Logical controlling fallback behavior (deprecated in favor of fallback_strategy).
#'   If TRUE and method="auto", falls back on AR(1) failure; if FALSE, errors (default: FALSE)
#' @param max_retries Integer maximum retries per optimization (default: 3)
#' @param parallel Logical whether to use parallel processing (default: TRUE)
#'
#' @return A list with class "bootstrap_result" containing:
#'   \item{param_samples}{Matrix of parameter samples (n_successful x n_params)}
#'   \item{rmse_samples}{Vector of RMSE values for each bootstrap sample}
#'   \item{r2_samples}{Vector of R² values for each bootstrap sample}
#'   \item{aic_samples}{Vector of AIC values for each bootstrap sample}
#'   \item{failed_indices}{Vector of indices for failed bootstrap samples}
#'   \item{n_successful}{Number of successful bootstrap samples}
#'   \item{n_failed}{Number of failed bootstrap samples}
#'   \item{method_used}{Character string indicating which bootstrap method was actually used}
#'   \item{ar1_coef}{AR(1) coefficient (if sieve method used), or NA}
#'   \item{summary}{List with summary statistics (means, sds, cis)}
#'   \item{original_fit}{List with original optimization results}
#'   \item{settings}{List with function call settings}
#'
#' @details
#' ## Bootstrap Methods
#'
#' **Parametric Bootstrap**: Resamples residuals independently from the fitted model.
#' Suitable for sparse data where AR(1) estimation is unreliable.
#'
#' **Sieve Bootstrap**: Fits an AR(1) model to residuals, then resamples innovations.
#' Preserves autocorrelation structure in residuals. Suitable for high-resolution data.
#' Falls back to parametric if AR(1) fitting fails (unless method="sieve" explicitly).
#'
#' ## Method Selection
#'
#' When method="auto":
#' - Uses parametric if length(observed) <= sieve_threshold
#' - Uses sieve if length(observed) > sieve_threshold
#' - Fallback to parametric on AR(1) failure is controlled by fallback_strategy/strict
#'
#' When method="parametric":
#' - Always uses parametric bootstrap, no AR(1) fitting
#'
#' When method="sieve":
#' - Always attempts sieve bootstrap
#' - Errors if AR(1) fitting fails (fallback_strategy is ignored)
#'
#' @examples
#' \dontrun{
#' # Example with sigmoid shape and default auto method selection
#' depths <- 1:200
#' observed <- sm_motif(depths, c(100, 20, 0.1, 50)) + rnorm(200, 0, 5)
#'
#' # Use automatic method selection (sparse data -> parametric, dense -> sieve)
#' result <- sm_optim_bootstrap(
#'   observed = observed,
#'   depths = depths,
#'   initial_params = c(100, 20, 0.1, 50),
#'   shape_family = "sigmoid",
#'   n_bootstrap = 100
#' )
#'
#' # Explicitly use sieve bootstrap for AR(1) modeling
#' result_sieve <- sm_optim_bootstrap(
#'   observed = observed,
#'   depths = depths,
#'   initial_params = c(100, 20, 0.1, 50),
#'   shape_family = "sigmoid",
#'   method = "sieve",
#'   n_bootstrap = 100
#' )
#'
#' # View parameter confidence intervals
#' print(result$summary$param_ci_lower)
#' print(result$summary$param_ci_upper)
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
  method = c("auto", "parametric", "sieve"),
  sieve_threshold = 20L,
  seed = NULL,
  fallback_strategy = c("auto", "explicit", "strict"),
  strict = FALSE,
  max_retries = 3L,
  parallel = TRUE
) {
  # Input validation FIRST (before match.arg)
  .validate_bootstrap_inputs(
    observed, depths, initial_params, shape_family,
    objective, optimizer, n_bootstrap, seed,
    fallback_strategy, max_retries, parallel,
    method, sieve_threshold, strict
  )

  # Then match and validate method parameter
  method <- match.arg(method)
  fallback_strategy <- match.arg(fallback_strategy)

  # Determine which bootstrap method to use
  method_to_use <- if (method == "auto") {
    # Auto-select based on data size
    if (length(observed) <= sieve_threshold) {
      "parametric"
    } else {
      "sieve"
    }
  } else {
    method
  }

  # Normalize shape_family aliases to canonical names (e.g., "sigmoid" -> "wetting_front")
  # This matches the behavior in sm_optim_dispatch()
  shape_family_normalized <- switch(shape_family,
    "sigmoid" = "wetting_front",
    "wetting_front" = "wetting_front",
    shape_family  # Default: use as-is for other shapes
  )

  # Determine fallback behavior for sieve method
  # If method="sieve" explicitly, never fall back (error on AR(1) failure)
  # If method="auto", use strict parameter to control fallback
  use_fallback <- if (method == "sieve") {
    FALSE  # Explicit sieve request: no fallback, error on failure
  } else if (method == "auto" && method_to_use == "sieve") {
    # Auto-selected sieve: fallback based on strict or fallback_strategy
    if (!is.na(strict) && strict) {
      FALSE  # strict=TRUE means don't fall back (error on AR(1) failure)
    } else if (fallback_strategy == "auto") {
      TRUE   # fallback_strategy="auto" means do fall back to parametric
    } else {
      FALSE  # fallback_strategy="explicit" or "strict" means error on failure
    }
  } else {
    FALSE  # Parametric method: no fallback logic needed
  }

  # Create the configuration list for the Rust FFI function
  config <- list(
    shape_type = shape_family_normalized,
    objective_name = objective,
    optimizer_name = optimizer,
    n_bootstrap = as.integer(n_bootstrap),
    seed = if (is.null(seed)) -1L else as.integer(seed),
    fallback = as.integer(use_fallback),
    method = method_to_use,  # Pass the method to use: "parametric" or "sieve"
    sieve_threshold = as.integer(sieve_threshold),
    max_retries = as.integer(max_retries),
    parallel = as.integer(parallel)  # Convert boolean to integer (0 or 1)
  )

  # Call the Rust bootstrap engine with simplified signature
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
    method = method,
    method_used = method_to_use,
    sieve_threshold = sieve_threshold,
    seed = seed,
    fallback_strategy = fallback_strategy,
    strict = strict,
    max_retries = max_retries,
    parallel = parallel,
    call = match.call()
  )

  # Add AR(1) coefficient if available
  result_list$ar1_coef <- if (!is.null(rust_result$ar1_coef)) {
    rust_result$ar1_coef
  } else {
    NA_real_
  }

  result_list
}

#' Validate inputs for bootstrap function
#' @keywords internal
#' @noRd 
.validate_bootstrap_inputs <- function(
  observed, depths, initial_params, shape_family,
  objective, optimizer, n_bootstrap, seed,
  fallback_strategy, max_retries, parallel,
  method = "auto", sieve_threshold = 20L, strict = FALSE
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
  if (!is.character(fallback_strategy)) {
    stop("fallback_strategy must be a character string or vector")
  }
  # If fallback_strategy is length > 1, it's the default (from match.arg call later)
  # Otherwise, it should be a single value
  if (length(fallback_strategy) == 1) {
    valid_fallbacks <- c("auto", "explicit", "strict")
    if (!fallback_strategy %in% valid_fallbacks) {
      stop("fallback_strategy must be one of: ", paste(valid_fallbacks, collapse = ", "))
    }
  } else if (length(fallback_strategy) > 1) {
    # This is the defaults vector - will be handled by match.arg() later
    valid_fallbacks <- c("auto", "explicit", "strict")
    if (!all(fallback_strategy %in% valid_fallbacks)) {
      stop("fallback_strategy must be one of: ", paste(valid_fallbacks, collapse = ", "))
    }
  }
  if (!is.character(method)) {
    stop("method must be a character string or vector")
  }
  # If method is length > 1, it's the default (from match.arg call later)
  # Otherwise, it should be a single value
  if (length(method) == 1) {
    valid_methods <- c("auto", "parametric", "sieve")
    if (!method %in% valid_methods) {
      stop("method must be one of: ", paste(valid_methods, collapse = ", "))
    }
  }
  if (!is.numeric(sieve_threshold) || length(sieve_threshold) != 1 || sieve_threshold < 1) {
    stop("sieve_threshold must be a positive integer")
  }
  if (!is.logical(strict) || length(strict) != 1) {
    stop("strict must be a single logical value")
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
  cat("Bootstrap Results\n")
  cat("================\n")
  cat(sprintf("Bootstrap method: %s\n", 
              if (!is.null(x$settings$method_used)) x$settings$method_used else "parametric"))
  cat(sprintf("Shape family: %s\n", x$settings$shape_family))
  cat(sprintf("Bootstrap samples: %d\n", x$settings$n_bootstrap))
  
  n_successful <- if (nrow(x$param_samples) > 0) nrow(x$param_samples) else 0
  cat(sprintf("Successful fits: %d (%.1f%%)\n",
              n_successful,
              if (x$settings$n_bootstrap > 0) n_successful / x$settings$n_bootstrap * 100 else 0))
  cat(sprintf("Failed fits: %d\n", length(x$failed_indices)))

  if (!is.na(x$ar1_coef)) {
    cat(sprintf("AR(1) coefficient: %.4f\n", x$ar1_coef))
  }

  if (nrow(x$param_samples) > 0) {
    cat("\nParameter Estimates (95% CI):\n")
    param_ci <- apply(x$param_samples, 2, quantile, probs = c(0.025, 0.975), na.rm = TRUE)
    param_mean <- colMeans(x$param_samples, na.rm = TRUE)
    for (i in seq_along(param_mean)) {
      cat(sprintf("  Param %d: %.3f (%.3f, %.3f)\n", i,
                  param_mean[i],
                  param_ci[1, i],
                  param_ci[2, i]))
    }

    cat(sprintf("\nDiagnostics:\n"))
    cat(sprintf("  RMSE: %.3f +/- %.3f\n", mean(x$rmse_samples, na.rm = TRUE), sd(x$rmse_samples, na.rm = TRUE)))
    cat(sprintf("  R^2: %.3f +/- %.3f\n", mean(x$r2_samples, na.rm = TRUE), sd(x$r2_samples, na.rm = TRUE)))
    cat(sprintf("  AIC: %.3f +/- %.3f\n", mean(x$aic_samples, na.rm = TRUE), sd(x$aic_samples, na.rm = TRUE)))
  }

  if (!is.null(x$message) && nchar(x$message) > 0) {
    cat(sprintf("\nMessage: %s\n", x$message))
  }
}

#' Summary method for bootstrap_result objects
#'
#' Provides detailed statistical summaries of bootstrap results including parameter
#' statistics (mean, SD, confidence intervals, range) and diagnostic statistics
#' (RMSE, R^2, AIC). Displays failed sample indices if any failures occurred.
#' Shows bootstrap method (parametric or sieve) and AR(1) coefficient if applicable.
#'
#' @param object A bootstrap_result object (returned from sm_optim_bootstrap)
#' @param ... Additional arguments passed to summary methods (currently unused)
#'
#' @return Invisibly returns object$summary (summary statistics list)
#' @export
summary.bootstrap_result <- function(object, ...) {
  method_used <- if (!is.null(object$settings$method_used)) {
    object$settings$method_used
  } else {
    "parametric"
  }

  cat("Bootstrap Summary\n")
  cat("=================\n")
  cat(sprintf("Bootstrap method: %s\n", method_used))
  cat(sprintf("Shape family: %s\n", object$settings$shape_family))
  cat(sprintf("Bootstrap samples: %d\n", object$settings$n_bootstrap))
  
  n_successful <- if (!is.null(object$n_successful)) object$n_successful else nrow(object$param_samples)
  cat(sprintf("Successful fits: %d (%.1f%%)\n",
              n_successful,
              if (object$settings$n_bootstrap > 0) n_successful / object$settings$n_bootstrap * 100 else 0))
  cat(sprintf("Failed fits: %d\n", length(object$failed_indices)))

  if (!is.na(object$ar1_coef)) {
    cat(sprintf("AR(1) coefficient: %.4f\n", object$ar1_coef))
  }

  if (nrow(object$param_samples) > 0) {
    cat("\nParameter Statistics:\n")
    param_stats <- data.frame(
      Parameter = paste0("Param_", seq_len(ncol(object$param_samples))),
      Mean = colMeans(object$param_samples, na.rm = TRUE),
      SD = apply(object$param_samples, 2, sd, na.rm = TRUE),
      CI_Lower = apply(object$param_samples, 2, quantile, probs = 0.025, na.rm = TRUE),
      CI_Upper = apply(object$param_samples, 2, quantile, probs = 0.975, na.rm = TRUE),
      Min = apply(object$param_samples, 2, min, na.rm = TRUE),
      Max = apply(object$param_samples, 2, max, na.rm = TRUE)
    )
    print(param_stats, row.names = FALSE)

    cat("\nDiagnostic Statistics:\n")
    diag_stats <- data.frame(
      Metric = c("RMSE", "R^2", "AIC"),
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