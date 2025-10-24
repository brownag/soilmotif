#' Plot soil profile optimization results
#'
#' Creates a base R plot showing observed data, fitted curve, and optionally
#' bootstrap uncertainty bands for soil profile optimization results.
#'
#' @param x A soilmotif optimization result (object of class "soilmotif_optimization")
#' @param bootstrap_result Optional bootstrap_result object for uncertainty visualization
#' @param depths Numeric vector of depth values (default: original depths from x)
#' @param xlim Numeric vector of length 2 for x-axis limits (property values)
#' @param ylim Numeric vector of length 2 for y-axis limits (depth, reversed by default)
#' @param col Color for the fitted line
#' @param ci_col Color for confidence interval bands (if bootstrap_result provided)
#' @param add Logical; if TRUE, add to existing plot instead of creating new one
#' @param main Character string for plot title
#' @param xlab Character string for x-axis label
#' @param ylab Character string for y-axis label
#' @param ... Additional arguments passed to plot() or lines()
#' @return Invisible NULL (standard plotting function behavior)
#' @export
#' @examples
#' \dontrun{
#' # Basic plot
#' clay_data <- sm_motif(1:200, c(40, 60))
#' fit <- sm_optim(clay_data, c(40, 60), use_rust = TRUE)
#' plot(fit)
#'
#' # With bootstrap uncertainty
#' boot <- sm_optim_bootstrap(clay_data, depths = 1:200,
#'                           initial_params = c(40, 60),
#'                           shape_family = "sigmoid", n_bootstrap = 100)
#' plot(fit, bootstrap_result = boot)
#' }
plot.soilmotif_optimization <- function(x, bootstrap_result = NULL,
                                       depths = NULL, xlim = NULL, ylim = NULL,
                                       col = "blue", ci_col = adjustcolor(col, alpha.f = 0.3),
                                       add = FALSE, main = "Soil Profile Fit",
                                       xlab = "Property Value", ylab = "Depth (cm)",
                                       ...) {
  # Handle both list format and numeric vector with attributes (backward compatibility)
  if (is.list(x) && !is.null(x$observed)) {
    # New list format
    observed <- x$observed
    fitted <- x$fitted
    shape_family <- x$shape_family
    if (is.null(depths)) depths <- x$depths
  } else if (is.numeric(x) && !is.null(attr(x, "optimization_result"))) {
    # Backward compatibility: numeric vector with optimization_result attribute
    opt_result <- attr(x, "optimization_result")
    observed <- opt_result$observed
    fitted <- x  # The main result is the fitted values
    shape_family <- opt_result$shape_family
    if (is.null(depths)) depths <- opt_result$depths
  } else {
    stop("Invalid optimization result format")
  }

  # Set default x-axis label based on shape family
  if (is.null(xlab)) {
    xlab <- switch(shape_family,
      "sigmoid" = "Clay Content (%)",
      "wetting_front" = "Clay Content (%)",
      "uniform" = "Property Value",
      "gradational" = "Property Value",
      "exponential" = "Property Value",
      "abrupt" = "Property Value",
      "peak" = "Property Value",
      "minimax" = "Property Value",
      "Property Value"  # default
    )
  }

  # Set up plot limits
  if (is.null(xlim)) {
    xlim <- range(c(observed, fitted), na.rm = TRUE)
    if (!is.null(bootstrap_result) && bootstrap_result$n_successful > 0) {
      # Include bootstrap predictions in range calculation
      shape_fun <- .get_shape_function(shape_family)
      boot_preds <- apply(bootstrap_result$param_samples, 1, function(params) {
        sm_motif(depths, params, FUN = shape_fun)
      })
      if (is.matrix(boot_preds)) {
        xlim <- range(c(xlim, boot_preds), na.rm = TRUE)
      }
    }
    # Add 5% padding
    xlim_range <- diff(xlim)
    xlim <- xlim + c(-0.05, 0.05) * xlim_range
  }

  if (is.null(ylim)) {
    ylim <- rev(range(depths, na.rm = TRUE))  # Reverse for soil convention
  }

  # Create new plot if not adding to existing
  if (!add) {
    plot(0, 0, type = "n", xlim = xlim, ylim = ylim,
         main = main, xlab = xlab, ylab = ylab, ...)
  }

  # Add confidence bands first (behind everything else)
  if (!is.null(bootstrap_result) && bootstrap_result$n_successful > 0) {
    shape_fun <- .get_shape_function(shape_family)
    boot_preds <- apply(bootstrap_result$param_samples, 1, function(params) {
      sm_motif(depths, params, FUN = shape_fun)
    })

    if (is.matrix(boot_preds)) {
      # Calculate confidence intervals
      pred_lower <- apply(boot_preds, 1, quantile, 0.025, na.rm = TRUE)
      pred_upper <- apply(boot_preds, 1, quantile, 0.975, na.rm = TRUE)

      # Add confidence bands as polygon
      polygon(c(pred_lower, rev(pred_upper)), c(depths, rev(depths)),
              col = ci_col, border = NA)
    }
  }

  # Add observed data points
  points(observed, depths, pch = 16, col = "black")

  # Add fitted line
  lines(fitted, depths, col = col, lwd = 2)

  # Add legend
  if (!is.null(bootstrap_result) && bootstrap_result$n_successful > 0) {
    legend("topright", c("Observed", "Fitted", "95% CI"),
           col = c("black", col, ci_col), pch = c(16, NA, NA),
           lty = c(NA, 1, 1), lwd = c(NA, 2, 10), bg = "white")
  } else {
    legend("topright", c("Observed", "Fitted"), col = c("black", col),
           pch = c(16, NA), lty = c(NA, 1), lwd = c(NA, 2), bg = "white")
  }

  invisible(NULL)
}

#' Extract plot data for custom visualization
#'
#' Prepares data from optimization and bootstrap results for use with custom plotting
#' functions (base R, ggplot2, plotly, etc.).
#'
#' @param optimization_result A soilmotif optimization result (object of class "soilmotif_optimization")
#' @param bootstrap_result Optional bootstrap_result object
#' @param depths Numeric vector of depth values (default: original depths from optimization_result)
#' @return A data.frame with columns: depth, observed, fitted, ci_lower, ci_upper
#' @export
#' @examples
#' \dontrun{
#' clay_data <- sm_motif(1:200, c(40, 60))
#' fit <- sm_optim(clay_data, c(40, 60), use_rust = TRUE)
#' plot_data <- extract_plot_data(fit)
#' str(plot_data)
#' }
sm_extract_plot_data <- function(optimization_result, bootstrap_result = NULL, depths = NULL) {
  # Handle both list format and numeric vector with attributes (backward compatibility)
  if (is.list(optimization_result) && !is.null(optimization_result$observed)) {
    # New list format
    observed <- optimization_result$observed
    fitted <- optimization_result$fitted
    shape_family <- optimization_result$shape_family
    params <- optimization_result$params
    original_depths <- optimization_result$depths
    if (is.null(depths)) depths <- original_depths
  } else if (is.numeric(optimization_result) && !is.null(attr(optimization_result, "optimization_result"))) {
    # Backward compatibility: numeric vector with optimization_result attribute
    opt_result <- attr(optimization_result, "optimization_result")
    observed <- opt_result$observed
    fitted <- optimization_result  # The main result is the fitted values
    shape_family <- opt_result$shape_family
    params <- opt_result$params
    original_depths <- opt_result$depths
    if (is.null(depths)) depths <- original_depths
  } else {
    stop("Invalid optimization result format")
  }

  # If custom depths provided, subset or interpolate data
  if (!is.null(depths) && length(depths) != length(original_depths)) {
    indices <- match(depths, original_depths)
    if (all(!is.na(indices)) && length(indices) == length(depths)) {
      # Subset existing data
      observed <- observed[indices]
      fitted <- fitted[indices]
    } else {
      # Interpolate/re-evaluate
      observed <- approx(original_depths, observed, depths, rule = 2)$y
      fitted <- sm_motif(depths, params, FUN = shape_fun)
    }
  }

  # Initialize result data.frame
  result <- data.frame(
    depth = depths,
    observed = observed,
    fitted = fitted,
    stringsAsFactors = FALSE
  )

  # Add bootstrap uncertainty if available
  if (!is.null(bootstrap_result) && bootstrap_result$n_successful > 0) {
    shape_fun <- .get_shape_function(shape_family)
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

#' Plot horizon boundary detection results
#'
#' Visualizes the results of horizon boundary detection algorithms (to be implemented in 03g).
#' This is a placeholder function that will be enhanced when horizon detection is complete.
#'
#' @param boundary_result Result from horizon boundary detection (placeholder)
#' @param element_data Original element concentration data
#' @param which Which plots to show: "all", "elements", "distance", "horizons"
#' @param ... Additional arguments passed to plotting functions
#' @return Invisible NULL
#' @export
sm_plot_horizon_boundaries <- function(boundary_result, element_data = NULL,
                                   which = "all", ...) {
  # Placeholder implementation for future 03g integration
  message("Horizon boundary plotting will be available after Phase 3g implementation")

  # Basic structure for future implementation:
  # - Multi-panel plot showing element profiles, Mahalanobis distance, and boundaries
  # - Uses base R plotting functions
  # - Follows soil science conventions (depth increasing downward)

  invisible(NULL)
}

#' Plot fuzzy horizon classification results
#'
#' Visualizes fuzzy k-means clustering results for horizon classification (to be implemented in 03h).
#' This is a placeholder function that will be enhanced when fuzzy clustering is complete.
#'
#' @param fuzzy_result Result from fuzzy horizon classification (placeholder)
#' @param type Type of plot: "heatmap", "profiles", "centers"
#' @param ... Additional arguments passed to plotting functions
#' @return Invisible NULL
#' @export
sm_plot_fuzzy_horizons <- function(fuzzy_result, type = "heatmap", ...) {
  # Placeholder implementation for future 03h integration
  message("Fuzzy horizon plotting will be available after Phase 3h implementation")

  # Basic structure for future implementation:
  # - Heatmap showing membership probabilities
  # - Profile plots with fuzzy boundaries
  # - Cluster center visualization
  # - Uses base R plotting functions (image(), matplot(), etc.)

  invisible(NULL)
}

# Note: get_shape_function helper is now in util.R as ..get_shape_function()

#' Plot bootstrap parameter distributions
#'
#' Creates histograms or density plots showing the distribution of parameter estimates
#' from bootstrap resampling.
#'
#' @param x A bootstrap_result object
#' @param type Plot type: "histogram" (default) or "density"
#' @param ... Additional arguments passed to hist() or plot()
#' @export
#' @examples
#' \dontrun{
#' clay_data <- sm_motif(1:200, c(40, 60)) + rnorm(200, 0, 3)
#' boot <- sm_optim_bootstrap(clay_data, depths = 1:200,
#'                           initial_params = c(40, 60),
#'                           shape_family = "sigmoid", n_bootstrap = 100)
#' plot_bootstrap_params(boot)
#' }
sm_plot_bootstrap_params <- function(x, type = "histogram", ...) {
  if (x$n_successful == 0) {
    stop("No successful bootstrap samples to plot")
  }

  n_params <- ncol(x$param_samples)
  if (n_params == 0) {
    stop("No parameter samples found")
  }

  # Set up multi-panel plot
  old_par <- par(mfrow = c(1, n_params), mar = c(4, 4, 2, 1))

  tryCatch({
    for (i in 1:n_params) {
      param_data <- x$param_samples[, i]
      param_name <- paste0("Parameter ", i)

      if (type == "histogram") {
        hist(param_data,
             main = param_name,
             xlab = "Parameter Value",
             col = "lightblue",
             border = "white",
             ...)
      } else if (type == "density") {
        plot(density(param_data, na.rm = TRUE),
             main = param_name,
             xlab = "Parameter Value",
             ...)
      } else {
        stop("type must be 'histogram' or 'density'")
      }
    }
  }, finally = {
    par(old_par)  # Restore original par settings
  })

  invisible(NULL)
}

#' Plot residual diagnostics
#'
#' Creates diagnostic plots for optimization residuals including residual vs fitted,
#' residual vs depth, and Q-Q plot.
#'
#' @param x A soilmotif_optimization object or numeric vector with optimization_result attribute
#' @param ... Additional arguments (unused)
#' @export
#' @examples
#' \dontrun{
#' clay_data <- sm_motif(1:200, c(40, 60)) + rnorm(200, 0, 3)
#' fit <- sm_optim(clay_data, c(40, 60), use_rust = TRUE)
#' plot_residuals(fit)
#' }
sm_plot_residuals <- function(x, ...) {
  # Handle both list format and numeric vector with attributes (backward compatibility)
  if (is.list(x) && !is.null(x$observed)) {
    # New list format
    observed <- x$observed
    fitted <- x$fitted
    depths <- x$depths
  } else if (is.numeric(x) && !is.null(attr(x, "optimization_result"))) {
    # Backward compatibility: numeric vector with optimization_result attribute
    opt_result <- attr(x, "optimization_result")
    observed <- opt_result$observed
    fitted <- x  # The main result is the fitted values
    depths <- opt_result$depths
  } else {
    stop("Invalid optimization result format")
  }

  # Ensure fitted is numeric without class to prevent plot dispatch issues
  fitted <- as.numeric(fitted)
  observed <- as.numeric(observed)
  depths <- as.numeric(depths)

  residuals <- observed - fitted

  # Set up 2x2 plot layout
  old_par <- par(mfrow = c(2, 2), mar = c(4, 4, 2, 1))

  tryCatch({
    # Residuals vs Fitted
    plot(fitted, residuals,
         xlab = "Fitted Values", ylab = "Residuals",
         main = "Residuals vs Fitted",
         pch = 16, col = "blue")
    abline(h = 0, lty = 2, col = "red")

    # Residuals vs Depth
    plot(depths, residuals,
         xlab = "Depth", ylab = "Residuals",
         main = "Residuals vs Depth",
         pch = 16, col = "blue")
    abline(h = 0, lty = 2, col = "red")

    # Q-Q plot
    qqnorm(residuals, main = "Normal Q-Q Plot", pch = 16, col = "blue")
    qqline(residuals, col = "red")

    # Histogram of residuals
    hist(residuals,
         main = "Residual Distribution",
         xlab = "Residuals",
         col = "lightblue",
         border = "white")

  }, finally = {
    par(old_par)  # Restore original par settings
  })

  invisible(NULL)
}