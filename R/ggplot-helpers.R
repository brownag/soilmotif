#' Prepare optimization results for ggplot2
#'
#' Returns data.frame ready for standard ggplot2 geoms from soilmotif optimization results.
#' Compatible with ggplot2 when installed.
#'
#' @param x A soilmotif_optimization object
#' @param bootstrap_result Optional bootstrap_result object for uncertainty bands
#' @param depths Optional depth sequence (default: original depths from x)
#' @return A data.frame with columns: depth, observed, fitted, ci_lower, ci_upper
#' @export
#' @examples
#' \dontrun{
#' library(ggplot2)
#' clay_data <- sm_motif(1:200, c(40, 60)) + rnorm(200, 0, 3)
#' fit <- sm_optim(clay_data, c(40, 60), use_rust = TRUE)
#'
#' # Basic plot
#' plot_data <- prepare_ggplot_data(fit)
#' ggplot(plot_data, aes(y = depth)) +
#'   geom_point(aes(x = observed)) +
#'   geom_line(aes(x = fitted), color = "blue") +
#'   scale_y_reverse() +
#'   labs(x = "Clay (%)", y = "Depth (cm)")
#'
#' # With uncertainty
#' boot <- sm_optim_bootstrap(clay_data, depths = 1:200,
#'                           initial_params = c(40, 60),
#'                           shape_family = "sigmoid", n_bootstrap = 100)
#' plot_data <- prepare_ggplot_data(fit, boot)
#' ggplot(plot_data, aes(y = depth)) +
#'   geom_ribbon(aes(xmin = ci_lower, xmax = ci_upper), alpha = 0.3) +
#'   geom_point(aes(x = observed)) +
#'   geom_line(aes(x = fitted), color = "blue") +
#'   scale_y_reverse() +
#'   labs(x = "Clay (%)", y = "Depth (cm)")
#' }
prepare_ggplot_data <- function(x, bootstrap_result = NULL, depths = NULL) {
  .require_package("ggplot2", "ggplot2 visualization helpers")

  # Handle both list format and numeric vector with attributes (backward compatibility)
  if (is.list(x) && !is.null(x$observed)) {
    # New list format
    observed <- x$observed
    fitted <- x$fitted
    shape_family <- x$shape_family
    params <- x$params
    original_depths <- x$depths
    if (is.null(depths)) depths <- original_depths
  } else if (is.numeric(x) && !is.null(attr(x, "optimization_result"))) {
    # Backward compatibility: numeric vector with optimization_result attribute
    opt_result <- attr(x, "optimization_result")
    observed <- opt_result$observed
    fitted <- x  # The main result is the fitted values
    shape_family <- opt_result$shape_family
    params <- opt_result$params
    original_depths <- opt_result$depths
    if (is.null(depths)) depths <- original_depths
  } else {
    stop("Invalid optimization result format")
  }

  # If custom depths provided, interpolate data
  if (!is.null(depths) && length(depths) != length(original_depths)) {
    # Interpolate observed and fitted to new depths
    observed <- approx(original_depths, observed, depths, rule = 2)$y
    fitted <- approx(original_depths, fitted, depths, rule = 2)$y
  }

  result <- data.frame(
    depth = depths,
    observed = observed,
    fitted = fitted
  )

  # Add bootstrap confidence intervals if available
  if (!is.null(bootstrap_result) && bootstrap_result$n_successful > 0) {
    shape_fun <- get_shape_function(shape_family)
    boot_preds <- apply(bootstrap_result$param_samples, 1, function(params) {
      sm_motif(depths, params, FUN = shape_fun)
    })

    if (is.matrix(boot_preds)) {
      result$ci_lower <- apply(boot_preds, 1, quantile, 0.025, na.rm = TRUE)
      result$ci_upper <- apply(boot_preds, 1, quantile, 0.975, na.rm = TRUE)
    } else {
      result$ci_lower <- NA_real_
      result$ci_upper <- NA_real_
    }
  } else {
    result$ci_lower <- NA_real_
    result$ci_upper <- NA_real_
  }

  result
}

#' Prepare horizon data for ggplot2
#'
#' Returns data.frame ready for geom_rect() or geom_hline() from horizon detection results.
#' Compatible with ggplot2 when installed.
#'
#' @param boundary_result Result from horizon boundary detection (03g)
#' @return A data.frame with columns: horizon_id, top, bottom, label
#' @export
#' @examples
#' \dontrun{
#' library(ggplot2)
#' # After 03g implementation:
#' # boundaries <- horizon_boundaries_mahalanobis(element_data)
#' # horizon_data <- prepare_horizon_ggplot(boundaries)
#' # ggplot(horizon_data, aes(y = top)) +
#' #   geom_rect(aes(ymin = top, ymax = bottom, xmin = -Inf, xmax = Inf),
#' #             alpha = 0.1, fill = "gray") +
#' #   geom_text(aes(x = 0, label = label), hjust = 0)
#' }
prepare_horizon_ggplot <- function(boundary_result) {
  .require_package("ggplot2", "ggplot2 visualization helpers")

  # Placeholder for 03g integration
  # This will be implemented when horizon detection is complete
  message("Horizon ggplot2 preparation will be available after Phase 3g implementation")

  # Return empty data.frame with expected structure
  data.frame(
    horizon_id = integer(0),
    top = numeric(0),
    bottom = numeric(0),
    label = character(0)
  )
}

#' Prepare fuzzy horizon data for ggplot2
#'
#' Returns data.frame ready for geom_tile() or geom_raster() from fuzzy horizon classification.
#' Compatible with ggplot2 when installed.
#'
#' @param fuzzy_result Result from fuzzy horizon classification (03h)
#' @return A data.frame with columns: depth, horizon, membership
#' @export
#' @examples
#' \dontrun{
#' library(ggplot2)
#' # After 03h implementation:
#' # fuzzy <- horizon_classify_fuzzy(element_data, n_horizons = 3)
#' # fuzzy_data <- prepare_fuzzy_ggplot(fuzzy)
#' # ggplot(fuzzy_data, aes(x = horizon, y = depth, fill = membership)) +
#' #   geom_tile() +
#' #   scale_fill_gradient(low = "white", high = "blue") +
#' #   scale_y_reverse()
#' }
prepare_fuzzy_ggplot <- function(fuzzy_result) {
  .require_package("ggplot2", "ggplot2 visualization helpers")

  # Placeholder for 03h integration
  # This will be implemented when fuzzy clustering is complete
  message("Fuzzy horizon ggplot2 preparation will be available after Phase 3h implementation")

  # Return empty data.frame with expected structure
  data.frame(
    depth = numeric(0),
    horizon = character(0),
    membership = numeric(0)
  )
}

# Helper function to get shape function from string (used internally)
get_shape_function <- function(shape_family) {
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