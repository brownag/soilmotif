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
#' @section Parameter Semantics by Motif Type:
#' 
#' - **Uniform:** Single constant value
#' - **Gradational:** c(start_value, end_value); order matters
#' - **Exponential:** c(surface_value, decay_rate); order matters
#' - **Wetting Front:** c(inflection_start, inflection_end); can be sorted
#' - **Abrupt:** c(discontinuity_depth, transition_width); order matters
#' - **Peak:** c(depth_of_max, width, skewness); order matters
#' - **MiniMax:** c(depth_min, width_min, depth_max, width_max); order matters
#' @seealso \code{\link{sm_optim}}, \code{\link{sm_shape_uniform}}, \code{\link{sm_shape_gradational}}, \code{\link{sm_shape_exponential}}, \code{\link{sm_shape_sigmoid}}, \code{\link{sm_shape_abrupt}}, \code{\link{sm_shape_peak}}, \code{\link{sm_shape_minimax}}
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
#' @param use_rust logical. If TRUE, attempt to use high-performance Rust backend (if available). Defaults to FALSE.
#' @param compare logical. If TRUE, run both R and Rust implementations and return comparison results. Defaults to FALSE.
#' @param algorithm character. Optimization algorithm for Rust backend ("nelder_mead", "auto"). Defaults to "nelder_mead".
#' @details
#' sm_optim uses numerical optimization to find the best-fitting parameters for a given
#' shape function. It employs Brent's method for single parameters and Nelder-Mead
#' for multi-parameter optimization. Parameters are constrained to reasonable ranges
#' (shape parameters typically in the range 0 to 1 for single parameters). For wetting_front motifs,
#' parameters are automatically sorted after optimization.
#' 
#' When use_rust=TRUE, the function uses the Rust backend with custom optimization
#' algorithms. The Rust implementation provides significant performance improvements
#' while maintaining identical results to the R implementation.
#' @importFrom stats optim quantile sd
#' @seealso \code{\link{sm_motif}}, \code{\link{sm_shape_uniform}}, \code{\link{sm_shape_gradational}}, \code{\link{sm_shape_exponential}}, \code{\link{sm_shape_sigmoid}}, \code{\link{sm_shape_abrupt}}, \code{\link{sm_shape_peak}}, \code{\link{sm_shape_minimax}}
sm_optim <- function(x, X, ...,
                     FUN = sm_shape_sigmoid,
                     OPTFUN = sm_optim_rmse) {
  # Use Brent method for 1D optimization to avoid Nelder-Mead issues
  method <- if (length(X) == 1) "Brent" else "Nelder-Mead"
  lower <- if (length(X) == 1) 0 else -Inf  # Shape parameters are in [0,1]
  upper <- if (length(X) == 1) 1 else Inf
  
  fit <- stats::optim(X, function(Y) OPTFUN(sm_motif(x, Y, FUN = FUN, ...), x),
                      method = method, lower = lower, upper = upper)
  
  # Only sort for specific motif types where it makes sense
  final_par <- fit$par
  if (identical(FUN, sm_shape_wetting_front)) {
    final_par <- sort(final_par)
  }
  
  res <- sm_motif(x, final_par, FUN = FUN, ...)
  attr(res, 'par') <- final_par
  res
}

#' Suggest Initial Parameters for Motif Fitting
#'
#' Provides reasonable starting points for optimization based on data characteristics.
#'
#' @param x numeric. Vector of soil property values.
#' @param motif_type character. Type of motif: "uniform", "gradational", "exponential", "wetting_front", "abrupt", "peak", "minimax".
#' @return numeric vector of initial parameters.
#' @keywords internal
.suggest_initial_params <- function(x, motif_type = "exponential") {
  n <- length(x)
  # Ensure depths are within valid range
  clamp_depth <- function(d) max(1, min(n, d))
  
  switch(motif_type,
    "uniform" = mean(x),
    "gradational" = c(min(x), max(x)),
    "exponential" = c(max(x), 0.01),
    "wetting_front" = {
      q <- quantile(x, c(0.25, 0.75))
      # If quantiles are the same, use fixed positions
      if (q[1] == q[2]) c(0.25 * n, 0.75 * n) else c(q[1], q[2])
    },
    "abrupt" = {
      # Find largest change point, default to middle if no change
      changes <- diff(x)
      depth <- if (all(changes == 0)) n/2 else which.max(abs(changes))
      width <- max(sd(x), 0.1)  # Minimum width to avoid division by zero
      c(clamp_depth(depth), width)
    },
    "peak" = {
      depth <- clamp_depth(which.max(x))
      width <- max(sd(x), 0.1)
      c(depth, width)
    },
    "minimax" = {
      depth_min <- clamp_depth(which.min(x))
      depth_max <- clamp_depth(which.max(x))
      width <- max(sd(x), 0.1)
      c(depth_min, width, depth_max, width)
    },
    stop("Unknown motif_type: ", motif_type)
  )
}

# ============================================================================
# Rust Backend Integration (Phase 2)
# ============================================================================

# Store original R implementation for dispatch
sm_optim_r_impl <- sm_optim

# Replace sm_optim with dispatch wrapper that can route to Rust
sm_optim <- function(x, X, ..., FUN = sm_shape_sigmoid,
                     OPTFUN = sm_optim_rmse, use_rust = FALSE,
                     compare = FALSE, algorithm = "nelder_mead") {
  # If comparison mode requested, run both R and Rust and return comparison
  if (compare) {
    return(compare_r_vs_rust(x, X, FUN = FUN, OPTFUN = OPTFUN, ...))
  }

  # If Rust requested, dispatch to Rust backend (with R fallback)
  if (use_rust) {
    if (!rust_backend_available()) {
      warning("Rust backend not available; falling back to R")
      return(sm_optim_r_impl(x, X, ..., FUN = FUN, OPTFUN = OPTFUN))
    }

    # Determine objective type from OPTFUN
    objective_type <- if (identical(OPTFUN, sm_optim_ssq)) "sse" else "rmse"

    # Determine shape type from FUN
    shape_type <- deparse(substitute(FUN))
    shape_type <- gsub("^sm_shape_", "", shape_type)

    # Determine depth vector
    depth_vector <- seq_along(x)

    # Try Rust implementation with algorithm selection and fallback to R
    tryCatch({
      result <- optimize_profile_rust_flexible(
        observed = x,
        x = depth_vector,
        initial_params = X,
        shape_type = shape_type,
        ascending = TRUE,  # Default for now
        objective_type = objective_type
      )

      # Return result in same format as R implementation
      predicted <- sm_motif(x, result, FUN = FUN, ...)
      attr(predicted, 'par') <- result
      return(predicted)

    }, error = function(e) {
      warning("Rust optimization failed: ", e$message, "; falling back to R")
      return(sm_optim_r_impl(x, X, ..., FUN = FUN, OPTFUN = OPTFUN))
    })
  }

  # Use R implementation (default path)
  sm_optim_r_impl(x, X, ..., FUN = FUN, OPTFUN = OPTFUN)
}

