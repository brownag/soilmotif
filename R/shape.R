# select from a set of pre-determined shape models
# or define your own custom function/parameters

sm_shape_linear <- function() {

}

sm_shape_step <- function() {

}

#' Shape functions
#'
#' @param x numeric. inputs to shape function
#' @param xlim numeric. parameter(s) to be applied in shape function with `x` as input.
#' @param ascending logical. Should the resulting shape be "increasing" (default: `TRUE`) or "decreasing"?
#'
#' @return numeric
#' @export
#'
#' @examples
#'
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

sm_shape_uniform <- function() {

}
