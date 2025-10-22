#' Rust Backend FFI Layer
#'
#' Low-level extendr FFI wrappers with error handling and fallbacks for Rust implementations.

#' Check if Rust backend is available and loaded
#'
#' @return logical TRUE if Rust backend is available
#' @export
#' @examples
#' \dontrun{
#'   if (rust_backend_available()) {
#'     cat("Rust backend is available\n")
#'   }
#' }
rust_backend_available <- function() {
  tryCatch({
    .Call("wrap__check_rust_backend", PACKAGE = "soilmotif")
    TRUE
  }, error = function(e) {
    FALSE
  })
}

#' Compute RMSE via Rust backend
#'
#' @param observed numeric vector of observed values
#' @param predicted numeric vector of predicted values
#'
#' @return numeric RMSE value
#' @keywords internal
objective_rmse_rust <- function(observed, predicted) {
  if (!rust_backend_available()) {
    return(sqrt(mean((observed - predicted)^2)))
  }
  
  tryCatch({
    .Call("wrap__objective_rmse_rust", 
          as.numeric(observed), 
          as.numeric(predicted),
          PACKAGE = "soilmotif")
  }, error = function(e) {
    warning("Rust RMSE failed: ", e$message, "; falling back to R")
    sqrt(mean((observed - predicted)^2))
  })
}

#' Compute SSE via Rust backend
#'
#' @param observed numeric vector of observed values
#' @param predicted numeric vector of predicted values
#'
#' @return numeric SSE value
#' @keywords internal
objective_sse_rust <- function(observed, predicted) {
  if (!rust_backend_available()) {
    return(sum((observed - predicted)^2))
  }
  
  tryCatch({
    .Call("wrap__objective_sse_rust", 
          as.numeric(observed), 
          as.numeric(predicted),
          PACKAGE = "soilmotif")
  }, error = function(e) {
    warning("Rust SSE failed: ", e$message, "; falling back to R")
    sum((observed - predicted)^2)
  })
}

#' Compute MAE via Rust backend
#'
#' @param observed numeric vector of observed values
#' @param predicted numeric vector of predicted values
#'
#' @return numeric MAE value
#' @keywords internal
objective_mae_rust <- function(observed, predicted) {
  if (!rust_backend_available()) {
    return(mean(abs(observed - predicted)))
  }
  
  tryCatch({
    .Call("wrap__objective_mae_rust", 
          as.numeric(observed), 
          as.numeric(predicted),
          PACKAGE = "soilmotif")
  }, error = function(e) {
    warning("Rust MAE failed: ", e$message, "; falling back to R")
    mean(abs(observed - predicted))
  })
}

#' Compute R-squared via Rust backend
#'
#' @param observed numeric vector of observed values
#' @param predicted numeric vector of predicted values
#'
#' @return numeric R-squared value
#' @keywords internal
objective_r2_rust <- function(observed, predicted) {
  if (!rust_backend_available()) {
    mean_obs <- mean(observed)
    ss_tot <- sum((observed - mean_obs)^2)
    ss_res <- sum((observed - predicted)^2)
    1.0 - (ss_res / ss_tot)
  }
  
  tryCatch({
    .Call("wrap__objective_r2_rust", 
          as.numeric(observed), 
          as.numeric(predicted),
          PACKAGE = "soilmotif")
  }, error = function(e) {
    warning("Rust R^2 failed: ", e$message, "; falling back to R")
    mean_obs <- mean(observed)
    ss_tot <- sum((observed - mean_obs)^2)
    ss_res <- sum((observed - predicted)^2)
    1.0 - (ss_res / ss_tot)
  })
}

#' Evaluate a shape function via Rust backend
#'
#' @param shape_type character name of shape ("uniform", "gradational", "exponential",
#'   "wetting_front", "abrupt", "peak", "minimax")
#' @param x numeric vector of depth values
#' @param params numeric vector of shape parameters
#' @param ascending logical whether values increase (TRUE) or decrease (FALSE)
#'
#' @return numeric vector of shape values in 0 to 1 range
#' @keywords internal
shape_eval_rust <- function(shape_type, x, params, ascending = TRUE) {
  if (!rust_backend_available()) {
    # Fall back to R implementation using built-in shape functions
    # params is expected to match Rust parameter order
    result <- switch(shape_type,
      uniform = sm_shape_uniform(x, params[1], ascending = ascending),
      gradational = sm_shape_gradational(x, params[1:2], ascending = ascending),
      exponential = sm_shape_exponential(x, params[1:2], ascending = ascending),
      wetting_front = sm_shape_wetting_front(x, params[1:2], ascending = ascending),
      sigmoid = sm_shape_sigmoid(x, params[1:2], ascending = ascending),  # sigmoid is alias for wetting_front
      abrupt = sm_shape_abrupt(x, params[1:2], ascending = ascending),
      peak = sm_shape_peak(x, params[1:2], ascending = ascending),
      minimax = sm_shape_minimax(x, params[1:4], ascending = ascending),
      {
        warning("Unknown shape type: ", shape_type)
        NULL
      }
    )
    return(result)
  }
  
  # Map sigmoid to wetting_front for Rust backend
  rust_shape_type <- if (shape_type == "sigmoid") "wetting_front" else shape_type
  
  tryCatch({
    result <- .Call("wrap__shape_eval_rust", 
                    as.character(rust_shape_type),
                    as.numeric(x), 
                    as.numeric(params), 
                    as.logical(ascending),
                    PACKAGE = "soilmotif")
    if (is.null(result)) {
      return(NULL)
    }
    result
  }, error = function(e) {
    warning("Rust shape evaluation failed: ", e$message, "; falling back to R")
    # Fall back to R implementation on error
    result <- switch(shape_type,
      uniform = sm_shape_uniform(x, params[1], ascending = ascending),
      gradational = sm_shape_gradational(x, params[1:2], ascending = ascending),
      exponential = sm_shape_exponential(x, params[1:2], ascending = ascending),
      wetting_front = sm_shape_wetting_front(x, params[1:2], ascending = ascending),
      sigmoid = sm_shape_sigmoid(x, params[1:2], ascending = ascending),  # sigmoid is alias for wetting_front
      abrupt = sm_shape_abrupt(x, params[1:2], ascending = ascending),
      peak = sm_shape_peak(x, params[1:2], ascending = ascending),
      minimax = sm_shape_minimax(x, params[1:4], ascending = ascending),
      NULL
    )
    result
  })
}

#' Optimize with pluggable objective function (Rust backend)
#'
#' @param observed numeric. Observed data vector
#' @param x numeric. Depth/position vector (typically 1..200)
#' @param initial_params numeric. Initial shape function parameters
#' @param shape_type character. Name of shape function ("uniform", "gradational", etc.)
#' @param ascending logical. Direction flag (TRUE = increasing, FALSE = decreasing)
#' @param objective_type character. Objective function ("rmse", "sse", "mae", "r2")
#' @param algorithm character. Optimization algorithm to use. Options:
#'   \itemize{
#'     \item \code{"auto"} (default): Automatically select based on problem characteristics
#'     \item \code{"nelder_mead"}: Nelder-Mead simplex (gradient-free, robust)
#'     \item \code{"lbfgs"}: L-BFGS quasi-Newton (gradient-based, fast for smooth problems)
#'     \item \code{"particle_swarm"} or \code{"pso"}: Particle Swarm Optimization (population-based global search)
#'     \item \code{"simulated_annealing"} or \code{"sa"}: Simulated Annealing (probabilistic, escapes local minima)
#'     \item \code{"newton_cg"}: Newton-CG (uses gradient + Hessian, very fast for smooth problems)
#'   }
#'
#' @return numeric vector of optimized parameters
#' @keywords internal
#' @examples
#' \dontrun{
#'   observed <- c(rep(10, 50), seq(10, 40, length.out=100), rep(40, 50))
#'   x <- 1:200
#'   params <- c(100, 20)
#'   result <- optimize_profile_rust_flexible(observed, x, params, 
#'                                             "wetting_front", TRUE, "rmse")
#' }
optimize_profile_rust_flexible <- function(observed, x, initial_params,
                                           shape_type = "sigmoid",
                                           ascending = TRUE,
                                           objective_type = "rmse",
                                           algorithm = "auto") {
  if (!rust_backend_available()) {
    stop("Rust backend not available")
  }

  # Map sigmoid to wetting_front for Rust backend
  rust_shape_type <- if (shape_type == "sigmoid") "wetting_front" else shape_type

  tryCatch({
    result <- .Call("wrap__optimize_profile_rust_flexible",
                    as.numeric(observed),
                    as.numeric(x),
                    as.numeric(initial_params),
                    as.character(rust_shape_type),
                    as.logical(ascending),
                    as.character(objective_type),
                    as.character(algorithm),
                    PACKAGE = "soilmotif")
    as.numeric(result)
  }, error = function(e) {
    warning("Rust optimization failed: ", e$message,
            "; returning initial parameters")
    initial_params
  })
}

#' Rust-backed optimization with R dispatch logic
#'
#' @param x numeric. Data vector (observed property)
#' @param X numeric. Initial parameters for shape function
#' @param FUN function. Shape function to fit
#' @param OPTFUN function. Objective function (sm_optim_rmse or sm_optim_ssq)
#' @param ascending logical. Shape direction (TRUE = increasing)
#' @param use_rust logical. If TRUE, use Rust backend when available
#' @param ... additional arguments (currently unused)
#'
#' @return numeric vector of optimized parameters
#' @keywords internal
sm_optim_dispatch <- function(x, X, FUN = sm_shape_sigmoid,
                              OPTFUN = sm_optim_rmse,
                              ascending = TRUE,
                              use_rust = FALSE, ...) {
  if (!use_rust) {
    # Existing R implementation
    return(sm_optim_r_impl(x, X, FUN = FUN, OPTFUN = OPTFUN, ...))
  }
  
  # Check if Rust backend is available
  if (!rust_backend_available()) {
    warning("Rust backend not available; falling back to R")
    return(sm_optim_r_impl(x, X, FUN = FUN, OPTFUN = OPTFUN, ...))
  }
  
  # Determine objective type from OPTFUN
  objective_type <- if (identical(OPTFUN, sm_optim_ssq)) "sse" else "rmse"
  
  # Determine shape type from FUN
  shape_type <- deparse(substitute(FUN))
  shape_type <- gsub("^sm_shape_", "", shape_type)
  
  # Determine depth vector
  depth_vector <- seq_along(x)
  
  # Call Rust implementation with flexible objectives
  result <- tryCatch({
    optimize_profile_rust_flexible(
      observed = x,
      x = depth_vector,
      initial_params = X,
      shape_type = shape_type,
      ascending = ascending,
      objective_type = objective_type,
      algorithm = "auto"
    )
  }, error = function(e) {
    warning("Rust optimization failed: ", e$message, "; falling back to R")
    sm_optim_r_impl(x, X, FUN = FUN, OPTFUN = OPTFUN, ...)
  })
  
  result
}

#' Compare R and Rust implementations side-by-side
#'
#' Runs the same optimization with both R and Rust backends and compares results.
#' Useful for validation and debugging numerical differences.
#'
#' @param x numeric vector of observed data
#' @param X numeric initial parameters
#' @param FUN shape function (R implementation)
#' @param OPTFUN objective function (R implementation)
#' @param tolerance numeric tolerance for parameter comparison (default 0.01)
#' @param ... additional arguments passed to shape/objective functions
#'
#' @return list with r_result, rust_result, r_rmse, rust_rmse, diff_rmse, passed
#' @keywords internal
#' @examples
#' \dontrun{
#'   # Compare R vs Rust for a simple profile
#'   observed <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))
#'   comp <- compare_r_vs_rust(observed, c(100, 20))
#'   print(comp$passed)  # Should be TRUE if implementations match
#' }
compare_r_vs_rust <- function(x, X, FUN = sm_shape_sigmoid,
                              OPTFUN = sm_optim_rmse,
                              tolerance = 0.01, ...) {
  # Run R implementation
  r_start <- Sys.time()
  r_result <- sm_optim_r_impl(x, X, FUN = FUN, OPTFUN = OPTFUN, ...)
  r_time <- difftime(Sys.time(), r_start, units = "secs")

  r_params <- attr(r_result, 'par')
  r_rmse <- OPTFUN(r_result, x)

  # Run Rust implementation (if available)
  if (!rust_backend_available()) {
    return(list(
      r_result = r_result,
      rust_result = NULL,
      r_params = r_params,
      rust_params = NULL,
      r_rmse = r_rmse,
      rust_rmse = NA,
      diff_rmse = NA,
      passed = FALSE,
      error = "Rust backend not available",
      r_time = as.numeric(r_time),
      rust_time = NA
    ))
  }

  rust_start <- Sys.time()
  tryCatch({
    # Determine objective and shape types for Rust
    objective_type <- if (identical(OPTFUN, sm_optim_ssq)) "sse" else "rmse"
    shape_type <- deparse(substitute(FUN))
    shape_type <- gsub("^sm_shape_", "", shape_type)
    depth_vector <- seq_along(x)

    rust_params <- optimize_profile_rust_flexible(
      observed = x,
      x = depth_vector,
      initial_params = X,
      shape_type = shape_type,
      ascending = TRUE,
      objective_type = objective_type,
      algorithm = "auto"
    )

    rust_result <- sm_motif(x, rust_params, FUN = FUN, ...)
    rust_time <- difftime(Sys.time(), rust_start, units = "secs")

    rust_rmse <- OPTFUN(rust_result, x)
    diff_rmse <- abs(r_rmse - rust_rmse)

    # Check if results are within tolerance
    passed <- diff_rmse < tolerance

    list(
      r_result = r_result,
      rust_result = rust_result,
      r_params = r_params,
      rust_params = rust_params,
      r_rmse = r_rmse,
      rust_rmse = rust_rmse,
      diff_rmse = diff_rmse,
      passed = passed,
      error = NULL,
      r_time = as.numeric(r_time),
      rust_time = as.numeric(rust_time)
    )

  }, error = function(e) {
    list(
      r_result = r_result,
      rust_result = NULL,
      r_params = r_params,
      rust_params = NULL,
      r_rmse = r_rmse,
      rust_rmse = NA,
      diff_rmse = NA,
      passed = FALSE,
      error = e$message,
      r_time = as.numeric(r_time),
      rust_time = NA
    )
  })
}
