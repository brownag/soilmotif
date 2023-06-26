
#' Scale a vector to be between specified limits
#'
#' @param x numeric. a numeric vector to be scaled to new low/high values.
#' @param xlim numeric. length 2 vector with low and high value limits to be applied to `x`.
#'
#' @return numeric vector, bounded by `xlim`
#' @noRd
#' @keywords internal
.scaleprop <- function(x, xlim = c(min(x), max(x))) {
  pmin(pmax(xlim[1], x * (xlim[2] - xlim[1])), xlim[2])
}
