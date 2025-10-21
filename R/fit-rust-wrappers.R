#' Rust Backend FFI Layer
#'
#' Low-level extendr FFI wrappers with error handling and fallbacks for Rust implementations.

#' Check if Rust backend is available and loaded
#'
#' @return logical TRUE if Rust backend is available
#' @export
#' @keywords internal
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
#' @export
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
#' @export
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
#' @export
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
#' @export
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
#' @export
#' @keywords internal
shape_eval_rust <- function(shape_type, x, params, ascending = TRUE) {
  if (!rust_backend_available()) {
    # Fall back to R implementation using built-in shape functions
    # Reconstruct xlim from params (params is expected to match Rust parameter order)
    result <- switch(shape_type,
      uniform = sm_shape_uniform(x, params[1], ascending = ascending),
      gradational = sm_shape_gradational(x, c(params[1], params[2]), ascending = ascending),
      exponential = sm_shape_exponential(x, c(params[1], params[2]), ascending = ascending),
      wetting_front = sm_shape_wetting_front(x, c(params[1], params[2]), ascending = ascending),
      abrupt = sm_shape_abrupt(x, c(params[1], params[2]), ascending = ascending),
      peak = sm_shape_peak(x, c(params[1], params[2]), ascending = ascending),
      minimax = sm_shape_minimax(x, c(params[1], params[2], params[3]), ascending = ascending),
      {
        warning("Unknown shape type: ", shape_type)
        NULL
      }
    )
    return(result)
  }
  
  tryCatch({
    result <- .Call("wrap__shape_eval_rust", 
                    as.character(shape_type),
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
      gradational = sm_shape_gradational(x, c(params[1], params[2]), ascending = ascending),
      exponential = sm_shape_exponential(x, c(params[1], params[2]), ascending = ascending),
      wetting_front = sm_shape_wetting_front(x, c(params[1], params[2]), ascending = ascending),
      abrupt = sm_shape_abrupt(x, c(params[1], params[2]), ascending = ascending),
      peak = sm_shape_peak(x, c(params[1], params[2]), ascending = ascending),
      minimax = sm_shape_minimax(x, c(params[1], params[2], params[3]), ascending = ascending),
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
                                           objective_type = "rmse") {
  if (!rust_backend_available()) {
    stop("Rust backend not available")
  }
  
  tryCatch({
    result <- .Call("wrap__optimize_profile_rust",
                    as.numeric(observed),
                    as.numeric(x),
                    as.numeric(initial_params),
                    as.character(shape_type),
                    as.logical(ascending),
                    as.character(objective_type),
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
      objective_type = objective_type
    )
  }, error = function(e) {
    warning("Rust optimization failed: ", e$message, "; falling back to R")
    sm_optim_r_impl(x, X, FUN = FUN, OPTFUN = OPTFUN, ...)
  })
  
  result
}
