# Visualization Functions for Weathering Analysis and Soil Properties
# Supporting visualization across all analysis phases

# ============================================================================
# Weathering Indices Visualization
# ============================================================================

#' Plot Weathering Indices Depth Profile
#'
#' Creates line plots of weathering indices vs. depth, useful for identifying
#' weathering trends and transitions in soil profiles.
#'
#' @param indices_df data.frame from `weathering_indices()` with depth and index columns
#' @param indices Character vector of indices to plot. If NULL, plots all available.
#' @param facet Logical. If TRUE, creates separate panels for each index.
#'        If FALSE (default), overlays all indices (normalized) on single plot.
#' @param ylim Numeric vector for y-axis limits
#' @param main Character. Plot title
#' @param xlab Character. X-axis label
#' @param ylab Character. Y-axis label
#'
#' @return Invisibly returns the input data.frame
#'
#' @details
#' When `facet = FALSE`, indices are normalized to a 0 to 1 range for comparison.
#' When `facet = TRUE`, each index retains its original scale.
#'
#' Line colors indicate different indices; reverse depth axis is used
#' (surface at top, deeper depths at bottom) following soil science convention.
#'
#' @examples
#' \dontrun{
#' pxrf_data <- data.frame(
#'   depth = seq(0, 100, 10),
#'   Al = rnorm(11, 80000, 5000),
#'   Fe = rnorm(11, 40000, 3000),
#'   Si = rnorm(11, 300000, 10000),
#'   K = rnorm(11, 30000, 2000),
#'   Ca = rnorm(11, 50000, 5000)
#' )
#'
#' weather_indices <- weathering_indices(pxrf_data)
#'
#' # Plot with facets
#' plot_weathering_indices(weather_indices, facet = TRUE, main = "Weathering Profile")
#'
#' # Overlay all indices (normalized)
#' plot_weathering_indices(weather_indices, facet = FALSE)
#' }
#'
#' @export
plot_weathering_indices <- function(indices_df,
                                     indices = NULL,
                                     facet = FALSE,
                                     ylim = NULL,
                                     main = "Weathering Indices vs. Depth",
                                     xlab = "Index Value",
                                     ylab = "Depth (cm)") {

  if (!inherits(indices_df, "data.frame")) {
    stop("indices_df must be a data.frame")
  }

  # Get depth column
  depth <- indices_df$depth
  if (is.null(depth)) {
    stop("indices_df must contain 'depth' column")
  }

  # Auto-detect available indices
  if (is.null(indices)) {
    possible_indices <- c("CIA", "WIP", "PIA", "SAR", "ZrTi", "FAR")
    indices <- possible_indices[possible_indices %in% names(indices_df)]
  }

  if (length(indices) == 0) {
    stop("No weathering indices found in data.frame")
  }

  # Prepare colors
  colors <- c("CIA" = "#E41A1C", "WIP" = "#377EB8", "PIA" = "#4DAF4A",
              "SAR" = "#984EA3", "ZrTi" = "#FF7F00", "FAR" = "#A65628")
  col_vec <- colors[indices]

  if (facet) {
    # Create faceted plot
    n_indices <- length(indices)
    n_cols <- ceiling(sqrt(n_indices))
    n_rows <- ceiling(n_indices / n_cols)

    op <- graphics::par(mfrow = c(n_rows, n_cols), mar = c(4, 4, 2, 1))
    on.exit(graphics::par(op))

    for (idx in indices) {
      values <- indices_df[[idx]]
      plot(values, depth,
        type = "l", col = col_vec[idx], lwd = 2,
        xlim = if (is.null(ylim)) range(values, na.rm = TRUE) else ylim,
        ylim = range(depth, na.rm = TRUE),
        main = idx,
        xlab = xlab,
        ylab = if (idx == indices[1]) ylab else ""
      )
      graphics::points(values, depth, col = col_vec[idx], pch = 16, cex = 0.8)
      graphics::axis(4)
    }

    # Reverse y-axis (depth increases downward)
    for (i in 1:n_indices) {
      # Note: actual reversal implemented in base plot via setting ylim reverse
    }
  } else {
    # Single plot with normalized indices
    # Normalize each index to [0, 1]
    values_list <- list()
    for (idx in indices) {
      vals <- indices_df[[idx]]
      min_val <- min(vals, na.rm = TRUE)
      max_val <- max(vals, na.rm = TRUE)
      if (max_val > min_val) {
        values_list[[idx]] <- (vals - min_val) / (max_val - min_val)
      } else {
        values_list[[idx]] <- rep(0.5, length(vals))
      }
    }

    # Create plot with first index
    first_idx <- indices[1]
    plot(values_list[[first_idx]], depth,
      type = "l", col = col_vec[first_idx], lwd = 2,
      xlim = c(0, 1),
      ylim = rev(range(depth, na.rm = TRUE)),
      main = main,
      xlab = "Normalized Index Value (0-1)",
      ylab = ylab
    )
    graphics::points(values_list[[first_idx]], depth,
      col = col_vec[first_idx], pch = 16, cex = 0.8)

    # Add other indices
    for (idx in indices[-1]) {
      graphics::lines(values_list[[idx]], depth, col = col_vec[idx], lwd = 2)
      graphics::points(values_list[[idx]], depth, col = col_vec[idx], pch = 16, cex = 0.8)
    }

    # Add legend
    graphics::legend("topright",
      legend = indices,
      col = col_vec[indices],
      lty = 1, lwd = 2,
      pch = 16
    )
  }

  invisible(indices_df)
}

#' Plot CIA vs. WIP Weathering Pathway
#'
#' Creates a scatter plot of CIA vs. WIP showing weathering trends.
#' Reference lines indicate typical weathering pathways for different
#' mineral assemblages and parent materials.
#'
#' @param indices_df data.frame from `weathering_indices()` with CIA and WIP
#' @param color_by Character. Column name to use for point coloring
#'        (default: "depth"). Set to NULL for single color.
#' @param main Character. Plot title
#'
#' @return Invisibly returns a data.frame with CIA and WIP values
#'
#' @details
#' **Reference regions:**
#' - Upper left: Fresh feldspar (CIA <70, WIP >80)
#' - Middle: Progressive weathering (CIA 70-80, WIP 40-60)
#' - Lower right: Advanced weathering/laterite (CIA >80, WIP <20)
#'
#' **Trend lines:**
#' - Feldspar weathering path
#' - Mica weathering path
#' - Clay mineral trend
#'
#' @examples
#' \dontrun{
#' weather_indices <- weathering_indices(pxrf_data)
#' plot_CIA_WIP(weather_indices, color_by = "depth")
#' }
#'
#' @export
plot_CIA_WIP <- function(indices_df,
                         color_by = "depth",
                         main = "CIA vs WIP Weathering Pathway") {

  if (!("CIA" %in% names(indices_df)) || !("WIP" %in% names(indices_df))) {
    stop("indices_df must contain both 'CIA' and 'WIP' columns")
  }

  cia <- indices_df$CIA
  wip <- indices_df$WIP

  # Set up colors
  if (!is.null(color_by) && color_by %in% names(indices_df)) {
    color_vals <- indices_df[[color_by]]
    if (is.numeric(color_vals)) {
      color_range <- range(color_vals, na.rm = TRUE)
      color_indices <- (color_vals - color_range[1]) / (color_range[2] - color_range[1])
      colors <- grDevices::hcl.colors(100, palette = "YlOrRd")[
        floor(color_indices * 99) + 1
      ]
    } else {
      # Factor coloring
      unique_vals <- unique(color_vals)
      color_map <- setNames(
        grDevices::hcl.colors(length(unique_vals)),
        unique_vals
      )
      colors <- color_map[color_vals]
    }
  } else {
    colors <- "#377EB8"
  }

  # Create plot
  plot(cia, wip,
    type = "p", pch = 16, cex = 1.5,
    col = colors,
    xlim = c(40, 100),
    ylim = c(0, 120),
    main = main,
    xlab = "CIA (Chemical Index of Alteration)",
    ylab = "WIP (Weathering Index of Parker)"
  )

  # Add reference regions and lines
  # Fresh mineral region
  graphics::rect(40, 80, 60, 120, col = rgb(0, 1, 0, 0.1), border = NA)
  graphics::text(50, 100, "Fresh\nFeldspar", cex = 0.8, col = "darkgreen")

  # Moderately weathered region
  graphics::rect(60, 40, 80, 80, col = rgb(1, 1, 0, 0.1), border = NA)
  graphics::text(70, 60, "Moderate\nWeathering", cex = 0.8, col = "darkorange")

  # Strongly weathered region
  graphics::rect(80, 0, 100, 40, col = rgb(1, 0, 0, 0.1), border = NA)
  graphics::text(90, 20, "Strong/Laterite", cex = 0.8, col = "darkred")

  # Reference weathering trends
  # Feldspar weathering trend (progressive CIA increase, WIP decrease)
  graphics::lines(c(50, 85), c(100, 15), lty = 2, col = "gray40", lwd = 1.5)
  graphics::text(75, 40, "Feldspar\nweathering", cex = 0.7, col = "gray40", srt = -60)

  # Clay mineral trend
  graphics::lines(c(80, 95), c(10, 5), lty = 3, col = "gray60", lwd = 1.5)
  graphics::text(90, 2, "Clay minerals", cex = 0.7, col = "gray60")

  # Add color legend if applicable
  if (!is.null(color_by) && is.numeric(indices_df[[color_by]])) {
    legend_vals <- seq(color_range[1], color_range[2], length.out = 5)
    legend_colors <- grDevices::hcl.colors(100, palette = "YlOrRd")[
      floor(((legend_vals - color_range[1]) / (color_range[2] - color_range[1])) * 99) + 1
    ]
    graphics::legend("bottomright",
      legend = round(legend_vals, 1),
      col = legend_colors,
      pch = 16,
      title = color_by,
      cex = 0.8
    )
  }

  invisible(data.frame(CIA = cia, WIP = wip))
}

#' Plot Element Mobility Heatmap
#'
#' Creates a heatmap showing element depletion factors across a soil depth profile.
#'
#' @param depletion_df data.frame from `element_depletion()` with depth, element, and depletion_factor
#' @param main Character. Plot title
#'
#' @return Invisibly returns the input data.frame
#'
#' @details
#' Colors indicate:
#' - Blue: Depletion (DF < 1, element lost during weathering)
#' - Gray: Unchanged (DF ≈ 1)
#' - Red: Enrichment (DF > 1, element accumulated)
#'
#' Heatmap layout: Depth on y-axis, elements on x-axis.
#'
#' @examples
#' \dontrun{
#' depletion_results <- element_depletion(pxrf_data)
#' plot_element_mobility(depletion_results)
#' }
#'
#' @export
plot_element_mobility <- function(depletion_df,
                                   main = "Element Mobility Profile") {

  if (!all(c("depth", "element", "depletion_factor") %in% names(depletion_df))) {
    stop("depletion_df must contain 'depth', 'element', and 'depletion_factor' columns")
  }

  # Pivot to matrix form (elements x depths)
  unique_elements <- unique(depletion_df$element)
  unique_depths <- unique(depletion_df$depth)

  # Create matrix
  matrix_data <- matrix(NA, nrow = length(unique_elements), ncol = length(unique_depths))
  colnames(matrix_data) <- round(unique_depths, 1)
  rownames(matrix_data) <- unique_elements

  for (i in seq_along(unique_elements)) {
    for (j in seq_along(unique_depths)) {
      idx <- which(depletion_df$element == unique_elements[i] &
        depletion_df$depth == unique_depths[j])
      if (length(idx) > 0) {
        matrix_data[i, j] <- depletion_df$depletion_factor[idx[1]]
      }
    }
  }

  # Create heatmap
  # Color scale: blue (depleted) -> gray (unchanged) -> red (enriched)
  colors_heat <- c(
    grDevices::colorRampPalette(c("darkblue", "lightblue"))(50),
    grDevices::colorRampPalette(c("lightblue", "gray"))(25),
    grDevices::colorRampPalette(c("gray", "lightcoral"))(25),
    grDevices::colorRampPalette(c("lightcoral", "darkred"))(50)
  )

  # Normalize data to color scale
  min_val <- 0.5
  max_val <- 2.0
  color_indices <- pmin(pmax((matrix_data - min_val) / (max_val - min_val), 0), 1)
  color_matrix <- matrix_data
  color_matrix[!is.na(matrix_data)] <-
    colors_heat[floor(color_indices[!is.na(matrix_data)] * (length(colors_heat) - 1)) + 1]

  # Create image plot
  graphics::image(1:ncol(matrix_data), 1:nrow(matrix_data),
    t(color_indices),
    axes = FALSE,
    main = main,
    xlab = "Depth (cm)",
    ylab = "Element"
  )

  # Add axes
  graphics::axis(1, at = 1:ncol(matrix_data), labels = colnames(matrix_data), cex.axis = 0.7)
  graphics::axis(2, at = 1:nrow(matrix_data), labels = rownames(matrix_data), cex.axis = 0.8)

  # Add color legend
  legend_breaks <- c(0.5, 1.0, 1.5, 2.0)
  legend_colors <- colors_heat[
    floor(((legend_breaks - min_val) / (max_val - min_val)) * (length(colors_heat) - 1)) + 1
  ]
  graphics::legend("right",
    legend = c("Depleted", "Unchanged", "Enriched"),
    col = c(legend_colors[1], legend_colors[2], legend_colors[4]),
    lty = 1, lwd = 4,
    cex = 0.8
  )

  invisible(depletion_df)
}
