#' Mass-preserving Spline Interpolation
#'
#' Basic wrapper around `mpspline2::mpspline()` and `aqp::spc2mpspline()`.
#'
#' @param x a data.frame, SoilProfileCollection, or numeric vector
#' @param ... Additional arguments passed to `mpspline2::mpspline()` and/or `aqp::spc2mplspline()`
#'
#' @return a data.frame or SoilProfileCollection (when `x` is a SoilProfileCollection)
#' @export
#'
#' @examples
#'
#' x <- data.frame(id=1,
#'                 top=c(0,10,20,30,40,50),
#'                 bottom=c(10,20,30,40,50,200),
#'                 prop=c(10,11,22,31,32,31))
#' plot(sm_spline(x, var_name="prop")[[1]]$est_1cm, 1:200, ylim=c(60,0))
#'
sm_spline <- function(x, ...) {
 if (inherits(x, 'data.frame') && requireNamespace("mpspline2")) {
   res <- mpspline2::mpspline(x, ...)
 } else if (inherits(x, 'SoilProfileCollection') && requireNamespace("aqp")) {
   res <- aqp::spc2mpspline(x, ...)
 } else if (is.numeric(x) && requireNamespace("mpspline2")) {
   s <- seq_along(x)
   d <- data.frame(id = 1, top = s - 1,  bottom = s, prop = x)
   res <- mpspline2::mpspline(d, var_name = "prop")
 } else {
   stop("`x` should be a data.frame, SoilProfileCollection or numeric vector", call. = FALSE)
 }
 res
}
