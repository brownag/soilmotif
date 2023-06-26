#' Objective Functions
#'
#' @param x numeric. Vector of "observed" values.
#' @param y numeric. Vector of "predicted" values.
#' @param ... Additional arguments to statistics functions `mean()`, `sum()` etc. such as `na.rm`.
#'
#' @return numeric
#' @rdname sm-objective
#' @export
#'
#' @examples
#' sm_optim_rmse(1:10, runif(10))
sm_optim_rmse <- function(x, y, ...) {
  sqrt(mean((y - x) ^ 2, ...))
}

#' @rdname sm-objective
#' @export
#'
#' @examples
#' sm_optim_ssq(1:10, runif(10))
sm_optim_ssq <- function(x, y, ...) {
  sum((y - x) ^ 2, ...)
}

## TODO: some functions might be (initially) parameterized by first doing some math on clusters
# sm_motif_kmeans <- function(x, centers = 2, ..., ylim = c(1, 200),
#                             FUN = soilmotif::sm_shape_sigmoid) {
#  pr <- kmeans(x, centers = centers, ...)
#  propmin <- pr$centers[1]
#  propmax <- pr$centers[2]
#  sm_optim_rmse(x, .scaleprop(FUN(seq(ylim[1], ylim[2]), c(propmin, propmax)), c(min(x), max(x))))
# }
# sm_motif_kmeans(z$clay_spline)

#' Fit a Soil Property Shape Function
#'
#' @param x A continuous vector representing a soil property; e.g. spline output or otherwise made continuous (i.e. 1 unit intervals). See methods for spline/step interpolation.
#' @param X Parameters for the shape function `FUN`
#' @param FUN Shape function. Defaults to `sm_shape_sigmoid()`
#' @param ... Additional arguments passed to `FUN`
#' @param ylim numeric. Length 2 vector representing `Y` (depth) limits.
#' @param OPTFUN Objective function. Defaults to `sm_optim_rmse()`.
#' @param as_function Return function that takes `Y` (depth) vector as input?
#' @return numeric vector or function when `as_function=TRUE`
#' @export
#' @rdname sm_motif
#' @examples
#' clay_spline <- inverse.rle(structure(list(lengths = c(19, 8, 5, 3, 1, 2, 1,
#'                              1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 3, 4, 17, 7,
#'                              37, 5, 2, 2, 1, 1, 1, 2, 2, 6, 6, 6, 3, 5, 38),
#'                            values = c(7, 6, 7, 8, 9, 10, 12, 13, 15, 17, 19,
#'                              23, 26, 28, 30, 32, 33, 35, 36, 37, 38, 39, 40,
#'                              41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 50,
#'                              49, 48, 47)), class = "rle"))
#'
#' plot(rep(c(0, 50), 100), 1:200, ylim = c(200, 0), type = "n")
#' points(clay_spline, 1:200, pch = "+")
#' lines(sm_motif(clay_spline, c(40, 60)), 1:200, col = "red", lty = 2)
#' lines(sm_optim(clay_spline, c(40,60)), 1:200, col = "blue")
#' legend("bottomleft", c("Input", "Initial", "Optimized"),
#'        pch = c("+", NA, NA),
#'        lty = c(NA, 2, 1),
#'        col = c("BLACK","RED","BLUE"))
sm_motif <- function(x, X,
                     FUN = sm_shape_sigmoid,
                     ..., ylim = c(1, 200),
                     as_function = FALSE) {
  # TODO: property scaling not need to be based on minima/maxima within x
  .fun <- \(Y) .scaleprop(FUN(Y, X, ...), c(min(x), max(x)))
  if (as_function)
    return(.fun)
  .fun(seq(ylim[1], ylim[2]))
}

#' @export
#' @rdname sm_motif
#' @importFrom stats optim
sm_optim <- function(x, X, ...,
                     FUN = sm_shape_sigmoid,
                     OPTFUN = sm_optim_rmse) {
  fit <- stats::optim(X, function(Y) OPTFUN(sm_motif(x, Y, FUN = FUN, ...), x))
  res <- sm_motif(x, sort(fit$par))
  attr(res, 'par') <- fit$par
  res
}

