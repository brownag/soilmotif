
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

# NOTE: sm_recommend_optimizer() is defined in fit.R (exported).
# It uses the Rust backend when available for sophisticated algorithm selection
# based on problem dimensionality, size, and objective function smoothness.

#' Get shape function by name
#'
#' Internal helper to retrieve a shape function by its name string.
#' Handles both "sigmoid" and "sm_shape_sigmoid" naming formats.
#'
#' @param shape_family character. Shape function name
#' @return A shape function (callable)
#' @noRd
#' @keywords internal
.get_shape_function <- function(shape_family) {
  # Handle both "sigmoid" and "sm_shape_sigmoid" formats
  if (grepl("^sm_shape_", shape_family)) {
    shape_name <- sub("^sm_shape_", "", shape_family)
  } else {
    shape_name <- shape_family
  }

  switch(shape_name,
    "sigmoid" = sm_shape_sigmoid,
    "wetting_front" = sm_shape_wetting_front,
    "uniform" = sm_shape_uniform,
    "gradational" = sm_shape_gradational,
    "exponential" = sm_shape_exponential,
    "abrupt" = sm_shape_abrupt,
    "peak" = sm_shape_peak,
    "minimax" = sm_shape_minimax,
    # Default fallback
    sm_shape_sigmoid
  )
}
