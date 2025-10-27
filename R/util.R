
#' Scale a vector to be between specified limits
#'
#' Scales a numeric vector to specified limits while preserving natural asymptotes.
#' Uses proportional scaling: maps the shape function's actual range into the
#' target range without forcing endpoints. This allows sigmoid asymptotes to
#' remain at their natural values (~0.07, ~0.93) instead of being forced to
#' exactly min/max of observed data.
#'
#' @param x numeric. A numeric vector to be scaled to new low/high values.
#' @param xlim numeric. Length 2 vector with low and high value limits to be applied to `x`.
#' @param shape_range numeric. Length 2 vector with the natural [min, max] range of the shape
#'   function output. If NULL (default), uses range of x (legacy behavior that forces asymptotes).
#'
#' @return numeric vector, scaled proportionally to fit within xlim while preserving
#'   the relationship between shape_range and xlim
#' @noRd
#' @keywords internal
.scaleprop <- function(x, xlim = c(min(x), max(x)), shape_range = NULL) {
  # Handle constant values (all x are the same)
  x_min <- min(x, na.rm = TRUE)
  x_max <- max(x, na.rm = TRUE)
  
  if (abs(x_max - x_min) < 1e-10) {
    # All values are essentially identical - return the midpoint of xlim
    return(rep((xlim[1] + xlim[2]) / 2, length(x)))
  }
  
  # If shape_range provided, use it for proportional scaling (preserves asymptotes)
  # Otherwise fall back to normalizing based on x itself (forces asymptotes to xlim)
  if (!is.null(shape_range) && length(shape_range) == 2) {
    shape_min <- shape_range[1]
    shape_max <- shape_range[2]
    
    if (abs(shape_max - shape_min) < 1e-10) {
      return(rep((xlim[1] + xlim[2]) / 2, length(x)))
    }
    
    # Proportional scaling: preserve relationship between shape output and target range
    # If shape outputs [0, 1], maps linearly to [xlim[1], xlim[2]]
    # If shape outputs [0.07, 0.93], those asymptotes are preserved proportionally
    result <- xlim[1] + (x - shape_min) / (shape_max - shape_min) * (xlim[2] - xlim[1])
  } else {
    # Legacy behavior: normalize x to [0, 1] then scale to xlim (FORCES asymptotes)
    x_normalized <- (x - x_min) / (x_max - x_min)
    result <- xlim[1] + x_normalized * (xlim[2] - xlim[1])
  }
  
  # Clamp to xlim bounds for safety
  pmin(pmax(xlim[1], result), xlim[2])
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
