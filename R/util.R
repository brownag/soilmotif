
#' Scale a vector to be between specified limits
#'
#' @param x numeric. a numeric vector to be scaled to new low/high values.
#' @param xlim numeric. length 2 vector with low and high value limits to be applied to `x`.
#'
#' @return numeric vector, bounded by `xlim`
#' @noRd
#' @keywords internal
.scaleprop <- function(x, xlim = c(min(x), max(x))) {
  # Handle constant values (all x are the same)
  x_min <- min(x, na.rm = TRUE)
  x_max <- max(x, na.rm = TRUE)
  
  if (abs(x_max - x_min) < 1e-10) {
    # All values are essentially identical - return the midpoint of xlim
    return(rep((xlim[1] + xlim[2]) / 2, length(x)))
  }
  
  # Normalize x to [0, 1] range first, then scale to xlim
  x_normalized <- (x - x_min) / (x_max - x_min)
  # Scale to target range [xlim[1], xlim[2]]
  pmin(pmax(xlim[1], x_normalized * (xlim[2] - xlim[1]) + xlim[1]), xlim[2])
}

#' Check for required suggested packages
#'
#' Internal helper for checking and requiring suggested package dependencies.
#' Follows the pattern established in R/preprocess.R and R/spline.R.
#'
#' @param pkg character. Package name to check for.
#' @param reason character. Description of why the package is needed (for error message).
#' @return invisible TRUE if package is available, otherwise throws error.
#' @noRd
#' @keywords internal
.require_package <- function(pkg, reason = "this functionality") {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Package '%s' is required for %s.\nInstall with: install.packages('%s')",
                 pkg, reason, pkg),
         call. = FALSE)
  }
}

#' Recommend optimization algorithm based on problem characteristics
#'
#' Uses Rust backend recommendation logic when available for sophisticated
#' algorithm selection based on problem dimensionality, problem size, and
#' objective function smoothness.
#'
#' Fallback logic (when Rust unavailable):
#' - 1 param: Nelder-Mead (simple, grid search fallback)
#' - 2-3 params, smooth objective (rmse/sse/mae/r2): L-BFGS
#'   (fast gradient-based)
#' - 2-3 params, complex objective (huber/quantile/ordinal/bounded):
#'   Nelder-Mead (robust gradient-free)
#' - 4 params, smooth objective: L-BFGS (scales well with gradients)
#' - 4 params, complex objective: Particle Swarm
#'   (global population-based search)
#' - 5+ params: Particle Swarm (handles high-dimensional spaces)
#'
#' @param n_params integer. Number of parameters to optimize
#' @param n_obs integer. Number of observations
#' @param objective_type character. Type of objective function
#'   ("rmse", "sse", "mae", "r2", "weighted_rmse", "huber", "quantile",
#'   "ordinal", "bounded")
#' @return character. Recommended algorithm name
#' @noRd
#' @keywords internal
sm_recommend_optimizer <- function(n_params, n_obs = NULL,
                                   objective_type = "rmse") {
  # If Rust backend is available, use its sophisticated recommendation logic
  if (rust_backend_available()) {
    tryCatch({
      n_obs_val <- if (is.null(n_obs)) 100 else n_obs
      return(recommend_optimizer_rust(
        as.integer(n_params),
        as.integer(n_obs_val),
        objective_type
      ))
    }, error = function(e) {
      # Fall through to R-based logic if Rust fails
    })
  }

  # R-based fallback logic
  # Classify objective function complexity
  is_smooth <- objective_type %in% c("rmse", "sse", "mae", "r2")

  if (n_params == 1) {
    "nelder_mead"
  } else if (n_params <= 3) {
    # For 2-3 params, use gradient-based for smooth objectives,
    # gradient-free for complex
    if (is_smooth) "lbfgs" else "nelder_mead"
  } else if (n_params == 4) {
    # For 4 params, use LBFGS for smooth, PSO for complex objectives
    if (is_smooth) "lbfgs" else "particle_swarm"
  } else {
    # For 5+ params, PSO can handle high-dimensional spaces better
    "particle_swarm"
  }
}
