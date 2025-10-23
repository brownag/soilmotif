
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
