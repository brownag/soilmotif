% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fit.R
\name{sm_motif}
\alias{sm_motif}
\alias{sm_optim}
\title{Fit a Soil Property Shape Function}
\usage{
sm_motif(
  x,
  X,
  FUN = sm_shape_sigmoid,
  ...,
  ylim = c(1, 200),
  as_function = FALSE
)

sm_optim(x, X, ..., FUN = sm_shape_sigmoid, OPTFUN = sm_optim_rmse)
}
\arguments{
\item{x}{A continuous vector representing a soil property; e.g. spline output or otherwise made continuous (i.e. 1 unit intervals). See methods for spline/step interpolation.}

\item{X}{Parameters for the shape function \code{FUN}}

\item{FUN}{Shape function. Defaults to \code{sm_shape_sigmoid()}}

\item{...}{Additional arguments passed to \code{FUN}}

\item{ylim}{numeric. Length 2 vector representing \code{Y} (depth) limits.}

\item{as_function}{Return function that takes \code{Y} (depth) vector as input?}

\item{OPTFUN}{Objective function. Defaults to \code{sm_optim_rmse()}.}
}
\value{
numeric vector or function when \code{as_function=TRUE}
}
\description{
Fit a Soil Property Shape Function
}
\examples{
clay_spline <- inverse.rle(structure(list(lengths = c(19, 8, 5, 3, 1, 2, 1,
                             1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 3, 4, 17, 7,
                             37, 5, 2, 2, 1, 1, 1, 2, 2, 6, 6, 6, 3, 5, 38),
                           values = c(7, 6, 7, 8, 9, 10, 12, 13, 15, 17, 19,
                             23, 26, 28, 30, 32, 33, 35, 36, 37, 38, 39, 40,
                             41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 50,
                             49, 48, 47)), class = "rle"))

plot(rep(c(0, 50), 100), 1:200, ylim = c(200, 0), type = "n")
points(clay_spline, 1:200, pch = "+")
lines(sm_motif(clay_spline, c(40, 60)), 1:200, col = "red", lty = 2)
lines(sm_optim(clay_spline, c(40,60)), 1:200, col = "blue")
legend("bottomleft", c("Input", "Initial", "Optimized"),
       pch = c("+", NA, NA),
       lty = c(NA, 2, 1),
       col = c("BLACK","RED","BLUE"))
}
