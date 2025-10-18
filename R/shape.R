# select from a set of pre-determined shape models
# or define your own custom function/parameters

#' @importFrom stats dnorm plogis
#'
#' Models an S-shaped curve; smooth transition between depths. Useful for wetting fronts, reaction fronts.
#'
#' @param x numeric. Depth vector.
#' @param xlim numeric. Parameters: c(depth_inflection_start, depth_inflection_end).
#' @param ascending logical. If TRUE, increases with depth. If FALSE, decreases.
#'
#' @return numeric vector in the range 0 to 1 representing the shape.
#' @export
#' @examples
#' plot(sm_shape_sigmoid(0:100, c(20, 50)), 0:100, ylim = c(100, 0))
sm_shape_sigmoid <- function(x, xlim, ascending = TRUE) {
  num2 <- sum(xlim) / 2
  num <- vector("numeric", length(x))
  num[x < num2] <- (2 * ((x[x < num2] - xlim[1]) / (xlim[2] - xlim[1])) ^ 2)
  num[x >= num2] <- 1 - (2 * ((x[x >= num2] - xlim[2]) / (xlim[2] - xlim[1])) ^ 2)
  num[x < xlim[1]] <- 0
  num[x > xlim[2]] <- 1
  if (!ascending)
    return(1 - num)
  num
}

#' Uniform Shape Function
#'
#' Models a constant value at all depths. Useful for undeveloped or mixed soils.
#'
#' @param x numeric. Depth vector.
#' @param xlim numeric. Parameters: c(mean_value). The constant value in the range 0 to 1.
#' @param ascending logical. If FALSE, inverts the constant value (1 - mean_value).
#'
#' @return numeric vector in the range 0 to 1 representing the shape.
#' @export
#' @examples
#' plot(sm_shape_uniform(0:100, c(0.5)), 0:100, ylim = c(100, 0))
sm_shape_uniform <- function(x, xlim, ascending = TRUE) {
  shape <- rep(xlim[1], length(x))
  if (!ascending) {
    shape <- 1 - shape
  }
  shape
}

#' Gradational Shape Function
#'
#' Models a linear or smooth change with depth. Useful for steady accumulation processes.
#'
#' @param x numeric. Depth vector.
#' @param xlim numeric. Parameters: c(start_value, end_value). Values in the range 0 to 1.
#' @param ascending logical. If TRUE, increases from start to end. If FALSE, decreases.
#' @param type character. "linear" (default) or "smooth" (polynomial).
#'
#' @return numeric vector in the range 0 to 1 representing the shape.
#' @export
#' @examples
#' plot(sm_shape_gradational(0:100, c(0.2, 0.8)), 0:100, ylim = c(100, 0))
sm_shape_gradational <- function(x, xlim, ascending = TRUE, type = "linear") {
  if (type == "linear") {
    x_norm <- (x - min(x)) / (max(x) - min(x))
    shape <- xlim[1] + x_norm * (xlim[2] - xlim[1])
  } else {
    # For smooth, could use polynomial, but for now linear
    shape <- xlim[1] + (x - min(x)) / (max(x) - min(x)) * (xlim[2] - xlim[1])
  }
  if (!ascending) {
    shape <- xlim[2] - (shape - xlim[1])  # invert
  }
  shape
}

#' Exponential Shape Function
#'
#' Models rapid change at surface with asymptotic behavior. Useful for OM, roots, surface-driven processes.
#'
#' @param x numeric. Depth vector.
#' @param xlim numeric. Parameters: c(C0_surface_value, k_decay_rate). C0 in the range 0 to 1, k > 0.
#' @param ascending logical. If TRUE, high at surface, low at depth. If FALSE, low at surface, high at depth.
#'
#' @return numeric vector in the range 0 to 1 representing the shape.
#' @export
#' @examples
#' plot(sm_shape_exponential(0:100, c(1, 0.05)), 0:100, ylim = c(100, 0))
sm_shape_exponential <- function(x, xlim, ascending = TRUE) {
  C0 <- xlim[1]
  k <- xlim[2]
  shape <- C0 * exp(-k * x)
  # Normalize to [0, 1]
  shape <- (shape - min(shape)) / (max(shape) - min(shape))
  if (!ascending) {
    shape <- 1 - shape
  }
  shape
}

#' Wetting Front Shape Function
#'
#' Models an S-shaped curve; smooth transition between depths. Useful for reaction fronts, leaching.
#'
#' @param x numeric. Depth vector.
#' @param xlim numeric. Parameters: c(depth_inflection_start, depth_inflection_end).
#' @param ascending logical. If TRUE, increases with depth. If FALSE, decreases.
#'
#' @return numeric vector in the range 0 to 1 representing the shape.
#' @export
#' @examples
#' plot(sm_shape_wetting_front(0:100, c(20, 50)), 0:100, ylim = c(100, 0))
sm_shape_wetting_front <- function(x, xlim, ascending = TRUE) {
  sm_shape_sigmoid(x, xlim, ascending)
}

#' Abrupt Shape Function
#'
#' Models a sharp step-like discontinuity at a single depth. Useful for lithologic changes.
#'
#' @param x numeric. Depth vector.
#' @param xlim numeric. Parameters: c(depth_discontinuity, transition_width). Width optional, default 0 for hard step.
#' @param ascending logical. If TRUE, 0 above, 1 below. If FALSE, 1 above, 0 below.
#'
#' @return numeric vector in the range 0 to 1 representing the shape.
#' @export
#' @examples
#' plot(sm_shape_abrupt(0:100, c(50, 0)), 0:100, ylim = c(100, 0))  # hard step
sm_shape_abrupt <- function(x, xlim, ascending = TRUE) {
  depth_disc <- xlim[1]
  transition_width <- if (length(xlim) > 1) xlim[2] else 0
  
  if (transition_width == 0) {
    shape <- as.numeric(x >= depth_disc)
  } else {
    # Smooth step using logistic
    shape <- plogis(x, location = depth_disc, scale = transition_width)
  }
  
  if (!ascending) {
    shape <- 1 - shape
  }
  shape
}

#' Peak Shape Function
#'
#' Models a bell-shaped accumulation zone. Useful for Bt horizon, clay peaks.
#'
#' @param x numeric. Depth vector.
#' @param xlim numeric. Parameters: c(depth_of_max, width, skewness). Skewness optional, default 0.
#' @param ascending logical. If TRUE, peak. If FALSE, valley.
#'
#' @return numeric vector in the range 0 to 1 representing the shape.
#' @export
#' @examples
#' plot(sm_shape_peak(0:100, c(50, 20)), 0:100, ylim = c(100, 0))
sm_shape_peak <- function(x, xlim, ascending = TRUE) {
  depth_max <- xlim[1]
  width <- xlim[2]
  skew <- if (length(xlim) > 2) xlim[3] else 0  # TODO: implement skewness
  
  # Normal distribution
  shape <- dnorm(x, mean = depth_max, sd = width)
  shape <- shape / max(shape)  # Normalize to [0, 1]
  
  if (!ascending) {
    shape <- 1 - shape
  }
  shape
}

#' MiniMax Shape Function
#'
#' Models two peaks: minimum then maximum. Useful for complex multi-process soils.
#'
#' @param x numeric. Depth vector.
#' @param xlim numeric. Parameters: c(depth_min, width_min, depth_max, width_max, skew_min, skew_max).
#' @param ascending logical. If TRUE, minimum then maximum. If FALSE, inverted.
#'
#' @return numeric vector in the range 0 to 1 representing the shape.
#' @export
#' @examples
#' plot(sm_shape_minimax(0:100, c(30, 10, 70, 15)), 0:100, ylim = c(100, 0))
sm_shape_minimax <- function(x, xlim, ascending = TRUE) {
  depth_min <- xlim[1]
  width_min <- xlim[2]
  depth_max <- xlim[3]
  width_max <- xlim[4]
  # skew_min <- if (length(xlim) > 4) xlim[5] else 0
  # skew_max <- if (length(xlim) > 5) xlim[6] else 0
  
  # Create valley and peak
  valley <- 1 - dnorm(x, mean = depth_min, sd = width_min)
  valley <- valley / max(valley)
  
  peak <- dnorm(x, mean = depth_max, sd = width_max)
  peak <- peak / max(peak)
  
  # Combine
  shape <- (valley + peak) / 2
  shape <- shape / max(shape)
  
  if (!ascending) {
    shape <- 1 - shape
  }
  shape
}
