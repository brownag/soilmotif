#' @importFrom utils read.csv
#' @title Data Preprocessing for Soil Profiles
#' @description Convert horizon or sensor data to continuous depth profiles suitable for motif fitting.
#'
#' @details
#' This function provides three interpolation methods for converting discrete horizon data
#' to continuous depth profiles:
#' 
#' - **step**: Piecewise constant interpolation where each horizon value is held constant
#'   across its depth range. Fast and preserves original horizon boundaries.
#' - **linear**: Linear interpolation between horizon midpoints. Smooth transitions but
#'   may overshoot extreme values.
#' - **spline**: Mass-preserving spline interpolation using mpspline2 (if available).
#'   Most sophisticated method that preserves mass balance and handles irregular sampling.
#' 
#' Input can be data.frames, SoilProfileCollection objects (requires aqp), or CSV file paths.
#' Output is a nested list structure: properties -> profile IDs -> numeric vectors.
#'
#' @param data data.frame, SoilProfileCollection, or character path to CSV file
#' @param property character. Name(s) of property column(s) to extract. If NULL, uses all numeric columns except 'top'/'bottom'
#' @param method character. Interpolation method: "step", "spline", or "linear"
#' @param depth_range numeric. c(min, max) depth range in cm
#' @param resolution numeric. Depth interval for output vectors
#' @param ... Additional arguments passed to interpolation methods
#'
#' @return Named list of lists: outer names = properties, inner names = profile IDs, values = numeric vectors
#' @export
#'
#' @examples
#' # Example with data.frame
#' data <- data.frame(
#'   id = c("P1", "P1", "P1"),
#'   top = c(0, 20, 50),
#'   bottom = c(20, 50, 100),
#'   clay = c(10, 30, 25)
#' )
#' result <- sm_prepare(data, property = "clay", method = "step")
#' depths <- seq(1, 200, by = 1)
#' plot(result$clay$P1, depths, ylim = c(200, 1), type = "l")
sm_prepare <- function(data,
                       property = NULL,
                       method = "step",
                       depth_range = c(1, 200),
                       resolution = 1,
                       ...) {

  # Validate inputs
  if (!(method %in% c("step", "spline", "linear"))) {
    stop("method must be one of 'step', 'spline', or 'linear'")
  }

  if (length(depth_range) != 2 || depth_range[1] >= depth_range[2]) {
    stop("depth_range must be c(min, max) with min < max")
  }

  if (resolution <= 0) {
    stop("resolution must be positive")
  }

  # Handle CSV input
  if (is.character(data)) {
    if (!file.exists(data)) {
      stop("File not found: ", data)
    }
    data <- read.csv(data, stringsAsFactors = FALSE)
  }

  # Dispatch based on input type
  if (inherits(data, "SoilProfileCollection")) {
    result <- switch(method,
      "step" = .sm_prepare_spc_step(data, property, depth_range, resolution, ...),
      "spline" = .sm_prepare_spc_spline(data, property, depth_range, resolution, ...),
      "linear" = .sm_prepare_spc_linear(data, property, depth_range, resolution, ...)
    )
  } else if (is.data.frame(data)) {
    result <- switch(method,
      "step" = .sm_prepare_df_step(data, property, depth_range, resolution, ...),
      "spline" = .sm_prepare_df_spline(data, property, depth_range, resolution, ...),
      "linear" = .sm_prepare_df_linear(data, property, depth_range, resolution, ...)
    )
  } else {
    stop("data must be data.frame, SoilProfileCollection, or path to CSV file")
  }

  result
}

# Helper to convert SoilProfileCollection to standardized data.frame
.spc_to_df <- function(spc) {
  if (!requireNamespace("aqp", quietly = TRUE)) {
    stop("aqp package required for SoilProfileCollection input")
  }

  # Get horizon data
  df <- aqp::horizons(spc)
  
  # Standardize column names
  id_col <- aqp::idname(spc)
  depth_cols <- aqp::horizonDepths(spc)
  
  df$id <- df[[id_col]]
  df$top <- df[[depth_cols[1]]]
  df$bottom <- df[[depth_cols[2]]]

  df
}

# Step method for data.frame
.sm_prepare_df_step <- function(data, property, depth_range, resolution, ...) {
  # Validate required columns
  required_cols <- c("id", "top", "bottom")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Determine properties to extract
  if (is.null(property)) {
    numeric_cols <- names(data)[sapply(data, is.numeric)]
    property <- setdiff(numeric_cols, c("id", "top", "bottom"))
    if (length(property) == 0) {
      stop("No numeric property columns found")
    }
  } else {
    missing_props <- setdiff(property, names(data))
    if (length(missing_props) > 0) {
      stop("Property columns not found: ", paste(missing_props, collapse = ", "))
    }
  }

  # Create output depths
  depths <- seq(depth_range[1], depth_range[2], by = resolution)

  result <- list()

  for (prop in property) {
    profiles <- unique(data$id)
    prof_list <- list()

    for (prof_id in profiles) {
      prof_data <- data[data$id == prof_id, ]

      # Sort by top depth
      prof_data <- prof_data[order(prof_data$top), ]

      # Initialize continuous vector
      continuous <- numeric(length(depths))

      # Fill by horizons
      for (i in seq_len(nrow(prof_data))) {
        top <- prof_data$top[i]
        bottom <- prof_data$bottom[i]
        value <- prof_data[[prop]][i]

        # Skip if value is NA
        if (is.na(value)) next

        # Find indices in output depths
        idx_start <- findInterval(top, depths)
        idx_end <- findInterval(bottom, depths)

        if (idx_start <= length(depths) && idx_end >= 1) {
          idx_start <- max(1, idx_start)
          idx_end <- min(length(depths), idx_end)
          
          # For horizons after the first, start from top+1 to avoid overlap
          if (i > 1) {
            idx_start <- idx_start + 1
          }
          
          if (idx_start <= idx_end) {
            continuous[idx_start:idx_end] <- value
          }
        }
      }

      # Extend last horizon to the end if not already covered
      last_bottom <- max(prof_data$bottom, na.rm = TRUE)
      if (last_bottom < max(depths)) {
        last_value <- prof_data[[prop]][which.max(prof_data$bottom)]
        if (!is.na(last_value)) {
          idx_start <- findInterval(last_bottom, depths) + 1
          if (idx_start <= length(depths)) {
            continuous[idx_start:length(depths)] <- last_value
          }
        }
      }

      prof_list[[as.character(prof_id)]] <- continuous
    }

    result[[prop]] <- prof_list
  }

  result
}

# Step method for SoilProfileCollection
.sm_prepare_spc_step <- function(spc, property, depth_range, resolution, ...) {
  df <- .spc_to_df(spc)
  .sm_prepare_df_step(df, property, depth_range, resolution, ...)
}

# Linear method for data.frame
.sm_prepare_df_linear <- function(data, property, depth_range, resolution, ...) {
  # Validate required columns
  required_cols <- c("id", "top", "bottom")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Determine properties
  if (is.null(property)) {
    numeric_cols <- names(data)[sapply(data, is.numeric)]
    property <- setdiff(numeric_cols, c("id", "top", "bottom"))
    if (length(property) == 0) {
      stop("No numeric property columns found")
    }
  } else {
    missing_props <- setdiff(property, names(data))
    if (length(missing_props) > 0) {
      stop("Property columns not found: ", paste(missing_props, collapse = ", "))
    }
  }

  # Create output depths
  depths <- seq(depth_range[1], depth_range[2], by = resolution)

  result <- list()

  for (prop in property) {
    profiles <- unique(data$id)
    prof_list <- list()

    for (prof_id in profiles) {
      prof_data <- data[data$id == prof_id, ]

      # Sort by top depth
      prof_data <- prof_data[order(prof_data$top), ]

      # Use horizon midpoints for interpolation
      prof_data$mid <- (prof_data$top + prof_data$bottom) / 2

      # Remove NA values
      prof_data <- prof_data[!is.na(prof_data[[prop]]), ]

      if (nrow(prof_data) == 0) {
        warning("No valid data for profile ", prof_id, " and property ", prop)
        prof_list[[as.character(prof_id)]] <- rep(NA, length(depths))
        next
      }

      # Interpolate
      continuous <- stats::approx(
        prof_data$mid,
        prof_data[[prop]],
        xout = depths,
        rule = 2  # Extend with boundary values
      )$y

      prof_list[[as.character(prof_id)]] <- continuous
    }

    result[[prop]] <- prof_list
  }

  result
}

# Linear method for SoilProfileCollection
.sm_prepare_spc_linear <- function(spc, property, depth_range, resolution, ...) {
  df <- .spc_to_df(spc)
  .sm_prepare_df_linear(df, property, depth_range, resolution, ...)
}

# Spline method for data.frame
.sm_prepare_df_spline <- function(data, property, depth_range, resolution, ...) {
  # Check for mpspline2
  if (!requireNamespace("mpspline2", quietly = TRUE)) {
    warning("mpspline2 not available; falling back to linear interpolation")
    return(.sm_prepare_df_linear(data, property, depth_range, resolution, ...))
  }

  # Validate required columns
  required_cols <- c("id", "top", "bottom")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Determine properties
  if (is.null(property)) {
    numeric_cols <- names(data)[sapply(data, is.numeric)]
    property <- setdiff(numeric_cols, c("id", "top", "bottom"))
    if (length(property) == 0) {
      stop("No numeric property columns found")
    }
  } else {
    missing_props <- setdiff(property, names(data))
    if (length(missing_props) > 0) {
      stop("Property columns not found: ", paste(missing_props, collapse = ", "))
    }
  }

  # Create output depths
  depths <- seq(depth_range[1], depth_range[2], by = resolution)

  result <- list()

  for (prop in property) {
    profiles <- unique(data$id)
    prof_list <- list()

    for (prof_id in profiles) {
      prof_data <- data[data$id == prof_id, c("top", "bottom", prop)]

      # Remove NA values
      prof_data <- prof_data[!is.na(prof_data[[prop]]), ]

      if (nrow(prof_data) == 0) {
        warning("No valid data for profile ", prof_id, " and property ", prop)
        prof_list[[as.character(prof_id)]] <- rep(NA, length(depths))
        next
      }

      # Fit spline
      tryCatch({
        spline_result <- mpspline2::mpspline(prof_data, var_name = prop, ...)

        # Extract interpolated values at desired depths
        # mpspline2 returns est_1cm, est_5cm, etc.
        # We need to interpolate to our resolution
        spline_depths <- as.numeric(gsub("est_|cm", "", names(spline_result)))
        spline_values <- unlist(spline_result)

        continuous <- stats::approx(
          spline_depths,
          spline_values,
          xout = depths,
          rule = 2
        )$y

        prof_list[[as.character(prof_id)]] <- continuous
      }, error = function(e) {
        warning("Spline fitting failed for profile ", prof_id, ": ", e$message, "; using linear")
        # Fallback to linear
        prof_data$mid <- (prof_data$top + prof_data$bottom) / 2
        continuous <- stats::approx(
          prof_data$mid,
          prof_data[[prop]],
          xout = depths,
          rule = 2
        )$y
        prof_list[[as.character(prof_id)]] <- continuous
      })
    }

    result[[prop]] <- prof_list
  }

  result
}

# Spline method for SoilProfileCollection
.sm_prepare_spc_spline <- function(spc, property, depth_range, resolution, ...) {
  if (!requireNamespace("aqp", quietly = TRUE)) {
    stop("aqp package required for SoilProfileCollection input")
  }

  # Use aqp's spc2mpspline
  if (!requireNamespace("mpspline2", quietly = TRUE)) {
    warning("mpspline2 not available; falling back to linear interpolation")
    return(.sm_prepare_spc_linear(spc, property, depth_range, resolution, ...))
  }

  # Determine properties
  if (is.null(property)) {
    # Get all horizon-level numeric columns
    hz_data <- aqp::horizons(spc)
    numeric_cols <- names(hz_data)[sapply(hz_data, is.numeric)]
    property <- setdiff(numeric_cols, aqp::horizonDepths(spc))
    if (length(property) == 0) {
      stop("No numeric property columns found in horizons")
    }
  }

  # Create output depths
  depths <- seq(depth_range[1], depth_range[2], by = resolution)

  result <- list()

  for (prop in property) {
    tryCatch({
      # Use aqp's spline function
      spline_spc <- aqp::spc2mpspline(spc, var = prop, ...)

      # Extract profiles
      profiles <- unique(aqp::profile_id(spc))
      prof_list <- list()

      for (prof_id in profiles) {
        prof_data <- spline_spc[spline_spc[[aqp::idname(spline_spc)]] == prof_id, ]

        if (nrow(prof_data) == 0) next

        # Get spline data - aqp adds columns like prop_est_1cm, etc.
        est_cols <- grep(paste0(prop, "_est_"), names(prof_data), value = TRUE)
        if (length(est_cols) == 0) {
          warning("No spline estimates found for ", prop, " in profile ", prof_id)
          prof_list[[as.character(prof_id)]] <- rep(NA, length(depths))
          next
        }

        # Extract depths and values
        spline_depths <- as.numeric(gsub(paste0(prop, "_est_|cm"), "", est_cols))
        spline_values <- as.numeric(prof_data[1, est_cols])

        # Interpolate to desired resolution
        continuous <- stats::approx(
          spline_depths,
          spline_values,
          xout = depths,
          rule = 2
        )$y

        prof_list[[as.character(prof_id)]] <- continuous
      }

      result[[prop]] <- prof_list
    }, error = function(e) {
      warning("Spline processing failed for property ", prop, ": ", e$message, "; using linear")
      result[[prop]] <- .sm_prepare_spc_linear(spc, prop, depth_range, resolution, ...)[[prop]]
    })
  }

  result
}