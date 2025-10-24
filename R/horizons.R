# Horizon Boundary Detection and Classification Functions
# Phase 3g: Mahalanobis Distance Boundary Detection
# Phase 3h: Fuzzy k-means Horizon Classification

# ============================================================================
# Constants for horizon detection algorithms
# ============================================================================

# Mahalanobis distance boundary detection defaults
.MAHALANOBIS_DEFAULT_THRESHOLD <- 2.0

# Fuzzy k-means clustering defaults
.FUZZY_DEFAULT_EXPONENT <- 2.0
.FUZZY_DEFAULT_MAX_ITER <- 100
.FUZZY_DEFAULT_TOLERANCE <- 1e-4

# ============================================================================
# Phase 3g: Mahalanobis Distance Boundary Detection
# ============================================================================

#' Internal: Compute Mahalanobis distance for a window
#'
#' @param window_data Numeric matrix (rows = depths, cols = elements)
#' @param reference_center Optional mean vector for comparison
#' @param reference_cov Optional covariance matrix for comparison
#' @return Numeric vector of Mahalanobis distances
#' @noRd
.compute_mahalanobis_window <- function(window_data,
                                         reference_center = NULL,
                                         reference_cov = NULL) {

  # Remove any rows with NA (complete cases only)
  complete_idx <- complete.cases(window_data)
  if (sum(complete_idx) < 2) {
    # Not enough data for covariance
    return(rep(NA_real_, nrow(window_data)))
  }

  window_data <- window_data[complete_idx, , drop = FALSE]

  # Compute center and covariance if not provided
  if (is.null(reference_center)) {
    reference_center <- colMeans(window_data, na.rm = TRUE)
  }

  if (is.null(reference_cov)) {
    reference_cov <- stats::cov(window_data, use = "complete.obs")
  }

  # Check if covariance is singular
  cov_det <- try(det(reference_cov), silent = TRUE)
  if (inherits(cov_det, "try-error") || abs(cov_det) < 1e-10) {
    # Singular covariance - return NA
    return(rep(NA_real_, sum(complete_idx)))
  }

  # Use base R stats::mahalanobis()
  distances <- stats::mahalanobis(window_data,
                                   center = reference_center,
                                   cov = reference_cov,
                                   inverted = FALSE)

  # Return full vector with NA for incomplete cases
  result <- rep(NA_real_, length(complete_idx))
  result[complete_idx] <- distances

  return(result)
}


#' Internal: Create depth-based windows
#'
#' @param depths Numeric vector of depth values
#' @param element_matrix Numeric matrix of element concentrations
#' @param window_size Window size in depth units
#' @param window_type "centered", "forward", or "backward"
#' @return List of windows with metadata
#' @noRd
.create_depth_windows <- function(depths, element_matrix,
                                    window_size, window_type = "centered") {

  n <- length(depths)
  windows <- list()

  for (i in seq_along(depths)) {
    center_depth <- depths[i]

    # Determine window range based on type
    if (window_type == "centered") {
      half_window <- window_size / 2
      range_min <- center_depth - half_window
      range_max <- center_depth + half_window
    } else if (window_type == "forward") {
      range_min <- center_depth
      range_max <- center_depth + window_size
    } else if (window_type == "backward") {
      range_min <- center_depth - window_size
      range_max <- center_depth
    } else {
      stop("Unknown window_type: ", window_type)
    }

    # Find depths within window
    in_window <- depths >= range_min & depths <= range_max
    window_indices <- which(in_window)

    if (length(window_indices) < 2) {
      # Not enough points for this window
      next
    }

    windows[[i]] <- list(
      center_depth = center_depth,
      center_index = i,
      depth_range = c(range_min, range_max),
      data = element_matrix[window_indices, , drop = FALSE],
      indices = window_indices
    )
  }

  # Remove NULL entries
  windows <- Filter(Negate(is.null), windows)

  return(windows)
}


#' Internal: Detect boundaries using various methods
#'
#' @param distances Numeric vector of Mahalanobis distances
#' @param depths Corresponding depth values
#' @param method "threshold", "local_maxima", or "changepoint"
#' @param threshold Numeric threshold value
#' @param min_separation Minimum distance between peaks
#' @return Integer vector of indices where boundaries detected
#' @noRd
.detect_boundaries <- function(distances, depths, method,
                                 threshold, min_separation) {

  # Remove NA distances
  valid_idx <- !is.na(distances)
  valid_distances <- distances[valid_idx]
  valid_depths <- depths[valid_idx]

  if (length(valid_distances) < 3) {
    return(integer(0))
  }

  boundary_indices <- switch(method,
    threshold = {
      # Simple threshold crossing
      which(valid_distances > threshold)
    },

    local_maxima = {
      # Find local maxima above threshold
      n <- length(valid_distances)
      if (n < 3) return(integer(0))

      # Compute gradient using diff()
      grad <- diff(valid_distances)

      # Sign changes from positive to negative indicate maxima
      sign_changes <- diff(sign(grad))

      # Indices where sign change from + to - (maxima)
      maxima_idx <- which(sign_changes < 0) + 1  # +1 to adjust for diff offset

      # Filter by threshold
      maxima_idx <- maxima_idx[valid_distances[maxima_idx] > threshold]

      maxima_idx
    },

    changepoint = {
      # Simple changepoint detection using sliding window variance
      n <- length(valid_distances)
      if (n < 10) return(integer(0))

      window_size <- min(10, floor(n / 3))
      changepoint_scores <- numeric(n)

      for (i in seq(window_size + 1, n - window_size)) {
        before <- valid_distances[(i - window_size):(i - 1)]
        after <- valid_distances[i:(i + window_size - 1)]

        # t-test for mean difference
        test_result <- try(stats::t.test(before, after), silent = TRUE)

        if (!inherits(test_result, "try-error")) {
          changepoint_scores[i] <- abs(test_result$statistic)
        }
      }

      # Find peaks in changepoint scores above threshold
      grad <- diff(changepoint_scores)
      sign_changes <- diff(sign(grad))
      cp_maxima <- which(sign_changes < 0) + 1

      # Filter by threshold
      cp_threshold <- stats::quantile(changepoint_scores[changepoint_scores > 0],
                                       0.9, na.rm = TRUE)
      cp_maxima[changepoint_scores[cp_maxima] > cp_threshold]
    },

    stop("Unknown method: ", method)
  )

  # Apply minimum separation constraint
  if (length(boundary_indices) > 1) {
    # Sort by depth
    boundary_indices <- boundary_indices[order(valid_depths[boundary_indices])]

    # Keep boundaries that are separated by at least min_separation
    keep <- rep(TRUE, length(boundary_indices))
    for (i in seq(2, length(boundary_indices))) {
      depth_diff <- valid_depths[boundary_indices[i]] -
                    valid_depths[boundary_indices[i - 1]]
      if (depth_diff < min_separation) {
        keep[i] <- FALSE
      }
    }

    boundary_indices <- boundary_indices[keep]
  }

  # Convert back to original indices
  original_indices <- which(valid_idx)[boundary_indices]

  return(original_indices)
}


#' Internal: Validate horizon data quality
#'
#' @param data data.frame with depth and element columns
#' @param depth_col Character, depth column name
#' @param element_cols Character vector, element column names
#' @return List with validation results
#' @noRd
.validate_horizon_data <- function(data, depth_col, element_cols) {

  warnings <- character(0)
  errors <- character(0)

  # Check depth column exists and is numeric
  if (!depth_col %in% names(data)) {
    errors <- c(errors, sprintf("Depth column '%s' not found", depth_col))
  } else if (!is.numeric(data[[depth_col]])) {
    errors <- c(errors, "Depth column must be numeric")
  }

  # Check for duplicate depths
  if (any(duplicated(data[[depth_col]]))) {
    errors <- c(errors, "Duplicate depth values found")
  }

  # Check element columns
  for (col in element_cols) {
    if (!col %in% names(data)) {
      errors <- c(errors, sprintf("Element column '%s' not found", col))
    } else if (!is.numeric(data[[col]])) {
      errors <- c(errors, sprintf("Element column '%s' must be numeric", col))
    } else {
      # Check missing values
      missing_pct <- sum(is.na(data[[col]])) / nrow(data) * 100
      if (missing_pct > 10) {
        warnings <- c(warnings,
                      sprintf("Column '%s' has %.1f%% missing values", col, missing_pct))
      }
    }
  }

  # Check depth spacing regularity (only if depth column exists and is valid)
  if (length(errors) == 0 && depth_col %in% names(data)) {
    depth_diffs <- diff(sort(data[[depth_col]]))
    if (length(depth_diffs) > 0) {
      median_diff <- stats::median(depth_diffs, na.rm = TRUE)
      max_diff <- max(depth_diffs, na.rm = TRUE)

      if (!is.na(max_diff) && !is.na(median_diff) && median_diff > 0 &&
          max_diff > 3 * median_diff) {
        warnings <- c(warnings,
                      "Irregular depth spacing detected. Consider using sm_prepare() for interpolation.")
      }
    }
  }

  return(list(
    valid = length(errors) == 0,
    warnings = warnings,
    errors = errors
  ))
}


#' Detect horizon boundaries using Mahalanobis distance
#'
#' Implements moving-window Mahalanobis distance analysis to objectively
#' identify horizon boundaries in multivariate soil data (e.g., pXRF element
#' concentrations).
#'
#' @details
#' **IMPORTANT: Data Preparation for Field-Described Horizons**
#'
#' This algorithm requires smooth variation in element composition. Field-described
#' horizons typically have constant values within each described layer. To apply
#' this function to field data:
#'
#' 1. Start with layer-wise data (top, bottom, element values)
#' 2. Interpolate using smooth methods such as:
#'    - mpspline2 package (Mass-Preserving Splines)
#'    - Spline interpolation with control via boundary distinctness
#'    - Linear interpolation at boundaries
#'
#' 3. Use boundary distinctness classes to control transition sharpness:
#'    - "abrupt": 2 cm transitions (sharp contact)
#'    - "clear": 5 cm transitions (typical)
#'    - "gradual": 10+ cm transitions (diffuse boundary)
#'
#' **Why interpolation is needed:**
#' Without smooth variation, element values are constant within horizons, creating
#' singular covariance matrices. This prevents distance computation. Interpolation
#' adds realistic variation consistent with boundary distinctness classes.
#'
#' @param data data.frame with depth and element concentration columns
#' @param depth_col character. Name of depth column. Default: "depth"
#' @param element_cols character vector. Element column names. If NULL, uses all
#'   numeric columns except depth_col. User is responsible for subsetting data
#'   if only specific elements should be used.
#' @param window_size numeric. Moving window size in DEPTH UNITS (e.g., 10 = 10 cm),
#'   not number of observations. Default: 10
#' @param threshold numeric. Mahalanobis distance threshold for boundary detection.
#'   Absolute threshold (e.g., 2.0 means distance > 2.0 indicates boundary).
#'   Default: 2.0
#' @param method character. Peak detection method: "threshold", "local_maxima",
#'   or "changepoint". Default: "local_maxima"
#' @param min_horizon_depth numeric. Minimum horizon thickness in depth units.
#'   Boundaries closer than this are merged. Default: 5
#' @param window_type character. Window positioning: "centered", "forward", "backward".
#'   Default: "centered"
#'
#' @return Object of class "horizon_boundaries" (S3 list) with components:
#'   \itemize{
#'     \item call: Original function call
#'     \item boundaries: data.frame with depth, mahal_distance, is_boundary
#'     \item horizons: data.frame with horizon_id, top, bottom, thickness
#'     \item raw_distances: Mahalanobis distance at each depth
#'     \item method: Peak detection method used
#'     \item threshold: Threshold value used
#'     \item element_cols: Element columns analyzed
#'     \item window_size: Window size in depth units
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' # Example: Using interpolated field data
#' # (Field-described horizons must be interpolated first using mpspline2 or similar)
#' set.seed(42)
#' data <- data.frame(
#'   depth = 0:100,
#'   Al = c(rnorm(31, 10, 0.5), rnorm(40, 25, 0.5), rnorm(30, 15, 0.5)),
#'   Fe = c(rnorm(31, 5, 0.3), rnorm(40, 15, 0.3), rnorm(30, 8, 0.3)),
#'   Si = c(rnorm(31, 60, 1), rnorm(40, 45, 1), rnorm(30, 65, 1))
#' )
#'
#' # Detect boundaries with local maxima method
#' boundaries <- horizon_boundaries_mahalanobis(data, window_size = 15, threshold = 1.0)
#' print(boundaries)
#'
#' # More conservative threshold
#' boundaries2 <- horizon_boundaries_mahalanobis(data, window_size = 15, threshold = 2.0)
#' print(boundaries2)
#' }
#' Internal: Compute Mahalanobis distances using R implementation
#'
#' @param element_matrix Numeric matrix of element concentrations (n_depths x n_elements)
#' @param depths Numeric vector of depth values
#' @param window_size Numeric. Window size in depth units
#'
#' @return Numeric vector of Mahalanobis distances
#' @noRd
._mahalanobis_distances_r <- function(element_matrix, depths, window_size) {
  n_depths <- length(depths)
  distances <- rep(NA_real_, n_depths)

  for (i in seq_along(depths)) {
    center_depth <- depths[i]

    # Define windows before and after this depth
    before_window <- depths >= (center_depth - window_size) & depths < center_depth
    after_window <- depths > center_depth & depths <= (center_depth + window_size)

    if (sum(before_window) >= 2 && sum(after_window) >= 2) {
      # Get data for each window
      before_data <- element_matrix[before_window, , drop = FALSE]
      after_data <- element_matrix[after_window, , drop = FALSE]

      # Compute centers
      before_center <- colMeans(before_data, na.rm = TRUE)
      after_center <- colMeans(after_data, na.rm = TRUE)

      # Pooled covariance
      before_cov <- stats::cov(before_data, use = "complete.obs")
      after_cov <- stats::cov(after_data, use = "complete.obs")
      pooled_cov <- (before_cov + after_cov) / 2

      # Check for singular covariance
      cov_det <- try(det(pooled_cov), silent = TRUE)
      if (!inherits(cov_det, "try-error") && abs(cov_det) >= 1e-10) {
        # Mahalanobis distance between window centers
        diff <- after_center - before_center
        cov_inv <- try(solve(pooled_cov), silent = TRUE)

        if (!inherits(cov_inv, "try-error")) {
          mahal_dist <- sqrt(as.numeric(t(diff) %*% cov_inv %*% diff))
          distances[i] <- mahal_dist
        }
      }
    }
  }

  distances
}


#' Internal: Compute Mahalanobis distances (dispatch wrapper)
#'
#' Tries Rust implementation first, falls back to R
#'
#' @param element_matrix Numeric matrix of element concentrations
#' @param depths Numeric vector of depth values
#' @param window_size Numeric. Window size in depth units
#'
#' @return Numeric vector of Mahalanobis distances
#' @noRd
._mahalanobis_distances <- function(element_matrix, depths, window_size) {
  # Try Rust implementation first if available
  if (rust_backend_available()) {
    tryCatch({
      return(.Call(
        "wrap__mahalanobis_boundary_detection_rust",
        element_matrix, depths, as.integer(window_size),
        PACKAGE = "soilmotif"
      ))
    }, error = function(e) {
      # Fall back to R implementation
      NULL
    })
  }

  # Use R implementation
  ._mahalanobis_distances_r(element_matrix, depths, window_size)
}


horizon_boundaries_mahalanobis <- function(data,
                                            depth_col = "depth",
                                            element_cols = NULL,
                                            window_size = 10,
                                            threshold = .MAHALANOBIS_DEFAULT_THRESHOLD,
                                            method = "local_maxima",
                                            min_horizon_depth = 5,
                                            window_type = "centered") {

  # Input validation
  if (!is.data.frame(data)) {
    stop("data must be a data.frame")
  }

  # Auto-detect element columns if not specified
  if (is.null(element_cols)) {
    numeric_cols <- names(data)[sapply(data, is.numeric)]
    element_cols <- setdiff(numeric_cols, depth_col)

    if (length(element_cols) == 0) {
      stop("No numeric element columns found")
    }
  }

  # Validate data
  validation <- .validate_horizon_data(data, depth_col, element_cols)

  if (!validation$valid) {
    stop("Data validation failed:\n  ", paste(validation$errors, collapse = "\n  "))
  }

  if (length(validation$warnings) > 0) {
    for (w in validation$warnings) {
      warning(w, call. = FALSE)
    }
  }

  # Sort by depth
  data <- data[order(data[[depth_col]]), ]
  depths <- data[[depth_col]]
  element_matrix <- as.matrix(data[, element_cols, drop = FALSE])

  # Create moving windows
  windows <- .create_depth_windows(depths, element_matrix,
                                     window_size, window_type)

  if (length(windows) < 2) {
    stop("Not enough valid windows. Try reducing window_size or checking data quality.")
  }

  # Compute Mahalanobis distances
  distances <- ._mahalanobis_distances(element_matrix, depths, window_size)

  # Detect boundaries
  boundary_indices <- .detect_boundaries(distances, depths, method,
                                          threshold, min_horizon_depth)

  # Create boundaries data.frame
  boundaries_df <- data.frame(
    depth = depths,
    mahal_distance = distances,
    is_boundary = seq_along(depths) %in% boundary_indices
  )

  # Create horizons data.frame
  if (length(boundary_indices) == 0) {
    # No boundaries detected - single horizon
    horizons_df <- data.frame(
      horizon_id = 1,
      top = min(depths),
      bottom = max(depths),
      thickness = max(depths) - min(depths)
    )
  } else {
    # Multiple horizons
    boundary_depths <- depths[boundary_indices]
    n_horizons <- length(boundary_depths) + 1

    horizons_df <- data.frame(
      horizon_id = seq_len(n_horizons),
      top = c(min(depths), boundary_depths),
      bottom = c(boundary_depths, max(depths)),
      thickness = NA_real_
    )

    horizons_df$thickness <- horizons_df$bottom - horizons_df$top
  }

  # Create result object
  result <- list(
    call = match.call(),
    boundaries = boundaries_df,
    horizons = horizons_df,
    raw_distances = distances,
    method = method,
    threshold = threshold,
    element_cols = element_cols,
    window_size = window_size,
    window_type = window_type
  )

  class(result) <- "horizon_boundaries"

  return(result)
}


#' Print method for horizon_boundaries objects
#'
#' @param x Object of class "horizon_boundaries"
#' @param ... Additional arguments (unused)
#' @export
print.horizon_boundaries <- function(x, ...) {
  cat("Horizon Boundary Detection (Mahalanobis Distance)\n")
  cat("==================================================\n\n")

  cat("Method:", x$method, "\n")
  cat("Threshold:", x$threshold, "\n")
  cat("Window size:", x$window_size, "depth units\n")
  cat("Elements analyzed:", length(x$element_cols), "-",
      paste(head(x$element_cols, 3), collapse = ", "),
      if (length(x$element_cols) > 3) "..." else "", "\n\n")

  cat("Detected horizons:", nrow(x$horizons), "\n")
  cat("Boundaries detected:", sum(x$boundaries$is_boundary), "\n\n")

  cat("Horizons:\n")
  print(x$horizons, row.names = FALSE)

  invisible(x)
}


#' Summary method for horizon_boundaries objects
#'
#' @param object Object of class "horizon_boundaries"
#' @param ... Additional arguments (unused)
#' @export
summary.horizon_boundaries <- function(object, ...) {
  cat("Horizon Boundary Detection Summary\n")
  cat("===================================\n\n")

  cat("Detection method:", object$method, "\n")
  cat("Threshold:", object$threshold, "\n")
  cat("Window configuration:", object$window_size, "depth units (",
      object$window_type, ")\n\n")

  cat("Data:\n")
  cat("  Depths analyzed:", length(object$raw_distances), "\n")
  cat("  Elements:", length(object$element_cols), "\n")
  cat("  Elements:", paste(object$element_cols, collapse = ", "), "\n\n")

  cat("Results:\n")
  cat("  Horizons detected:", nrow(object$horizons), "\n")
  cat("  Boundaries:", sum(object$boundaries$is_boundary), "\n\n")

  # Distance statistics
  valid_distances <- object$raw_distances[!is.na(object$raw_distances)]
  if (length(valid_distances) > 0) {
    cat("Mahalanobis Distance Statistics:\n")
    cat("  Min:", sprintf("%.3f", min(valid_distances)), "\n")
    cat("  Median:", sprintf("%.3f", stats::median(valid_distances)), "\n")
    cat("  Mean:", sprintf("%.3f", mean(valid_distances)), "\n")
    cat("  Max:", sprintf("%.3f", max(valid_distances)), "\n")
    cat("  Above threshold:", sum(valid_distances > object$threshold), "\n\n")
  }

  cat("Horizon Details:\n")
  print(object$horizons, row.names = FALSE)

  invisible(object)
}


# ============================================================================
# Phase 3h: Fuzzy k-means Horizon Classification
# ============================================================================

#' Internal: Fuzzy k-means algorithm (R reference implementation)
#'
#' @param data_matrix Numeric matrix (rows = depths, cols = elements)
#' @param k Number of clusters
#' @param m Fuzziness exponent (> 1.0)
#' @param max_iter Maximum iterations
#' @param tol Convergence tolerance
#' @param init_method Initialization method ("kmeans" or "random")
#' @param convergence Convergence criterion ("membership", "centers", "both")
#' @return List with centers, memberships, entropy, iterations, converged
#' @noRd
.fuzzy_kmeans_r <- function(data_matrix, k, m = .FUZZY_DEFAULT_EXPONENT,
                             max_iter = .FUZZY_DEFAULT_MAX_ITER,
                             tol = .FUZZY_DEFAULT_TOLERANCE,
                             init_method = "kmeans",
                             convergence = "membership") {

  # Validate inputs
  if (m <= 1.0) {
    stop("Fuzziness exponent m must be > 1.0")
  }

  n <- nrow(data_matrix)
  p <- ncol(data_matrix)

  if (k >= n) {
    stop("Number of clusters k must be less than number of observations")
  }

  # Initialize cluster centers
  if (init_method == "kmeans") {
    # Use base R kmeans for initialization
    km_init <- stats::kmeans(data_matrix, centers = k, nstart = 10)
    centers <- km_init$centers
  } else {
    # Random initialization
    set.seed(NULL)  # Ensure randomness
    init_indices <- sample(n, k)
    centers <- data_matrix[init_indices, , drop = FALSE]
  }

  # Initialize membership matrix
  memberships <- matrix(0, nrow = n, ncol = k)

  # Iterative updates
  converged <- FALSE
  iter <- 0

  for (iter in seq_len(max_iter)) {
    memberships_old <- memberships
    centers_old <- centers

    # Step 1: Update membership matrix
    # Compute distances from each point to each center
    distances <- matrix(0, nrow = n, ncol = k)
    for (j in seq_len(k)) {
      diff_matrix <- sweep(data_matrix, 2, centers[j, ])
      distances[, j] <- sqrt(rowSums(diff_matrix^2))
    }

    # Handle zero distances (point exactly at center)
    zero_dist <- distances < 1e-10
    distances[zero_dist] <- 1e-10

    # Compute memberships using fuzzy c-means formula
    exp_factor <- 2 / (m - 1)
    for (i in seq_len(n)) {
      for (j in seq_len(k)) {
        ratio_sum <- sum((distances[i, j] / distances[i, ])^exp_factor)
        memberships[i, j] <- 1 / ratio_sum
      }
    }

    # Normalize memberships (ensure rows sum to 1)
    row_sums <- rowSums(memberships)
    memberships <- memberships / row_sums

    # Step 2: Update centers
    for (j in seq_len(k)) {
      weights <- memberships[, j]^m
      weight_sum <- sum(weights)
      if (weight_sum > 1e-10) {
        centers[j, ] <- colSums(data_matrix * weights) / weight_sum
      }
    }

    # Step 3: Check convergence
    if (convergence == "membership" || convergence == "both") {
      membership_change <- max(abs(memberships - memberships_old))
      membership_converged <- membership_change < tol
    } else {
      membership_converged <- TRUE
    }

    if (convergence == "centers" || convergence == "both") {
      center_change <- max(abs(centers - centers_old))
      center_converged <- center_change < tol
    } else {
      center_converged <- TRUE
    }

    if (membership_converged && center_converged) {
      converged <- TRUE
      break
    }
  }

  # Compute normalized entropy for each depth
  entropy <- numeric(n)
  for (i in seq_len(n)) {
    u <- memberships[i, ]
    u <- u[u > 1e-10]  # Avoid log(0)
    if (length(u) > 0) {
      entropy[i] <- -sum(u * log(u)) / log(k)  # Normalized to [0, 1]
    }
  }

  return(list(
    centers = centers,
    memberships = memberships,
    entropy = entropy,
    iterations = iter,
    converged = converged
  ))
}


#' Classify soil horizons using fuzzy k-means clustering
#'
#' Implements fuzzy c-means clustering on multivariate soil data to identify
#' horizon types based on element composition. Unlike hard clustering, fuzzy
#' k-means assigns membership scores to each horizon, allowing for gradational
#' boundaries.
#'
#' @param data data.frame with depth and element concentration columns
#' @param depth_col character. Name of depth column. Default: "depth"
#' @param element_cols character vector. Element column names. If NULL, uses all
#'   numeric columns except depth_col. Depth is NOT used as a clustering feature
#'   unless include_depth_feature = TRUE. User is responsible for subsetting
#'   if only specific elements desired.
#' @param n_horizons integer. Number of horizon clusters (k). Default: 5
#' @param m numeric. Fuzziness exponent (must be > 1.0). Higher = softer boundaries.
#'   Default: 2.0. Typical range: 1.5-3.0
#' @param max_iter integer. Maximum iterations. Default: 100
#' @param tolerance numeric. Convergence tolerance. Default: 1e-4
#' @param convergence character. Convergence criterion: "membership" (default),
#'   "centers", or "both"
#' @param init_method character. Initialization: "kmeans" (base R kmeans++),
#'   or "random". Default: "kmeans"
#' @param include_depth_feature logical. Include depth as clustering feature?
#'   Default: FALSE (cluster by element composition only). Set TRUE for noisy
#'   data to encourage spatial grouping.
#' @param use_rust logical. Use Rust implementation? Default: TRUE (when available).
#'   Falls back to R implementation if Rust not available.
#'
#' @return Object of class "fuzzy_horizons" (S3 list) with components:
#'   \itemize{
#'     \item call: Original function call
#'     \item depths: Depth values (sorted)
#'     \item element_cols: Element columns used
#'     \item centers: Cluster centers matrix (k x p)
#'     \item memberships: Membership matrix (n x k), rows sum to 1
#'     \item entropy: Normalized entropy between 0 and 1 per depth
#'     \item dominant_horizon: Horizon with max membership per depth
#'     \item n_horizons: Number of clusters (k)
#'     \item m: Fuzziness exponent used
#'     \item iterations: Actual iterations to convergence
#'     \item converged: Logical, did algorithm converge?
#'     \item method: "r" or "rust"
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' # Generate synthetic data with 3 distinct horizons
#' set.seed(42)
#' data <- data.frame(
#'   depth = 0:100,
#'   Al = c(rnorm(31, 10, 0.5), rnorm(40, 25, 0.5), rnorm(30, 15, 0.5)),
#'   Fe = c(rnorm(31, 5, 0.3), rnorm(40, 15, 0.3), rnorm(30, 8, 0.3)),
#'   Si = c(rnorm(31, 60, 1), rnorm(40, 45, 1), rnorm(30, 65, 1))
#' )
#'
#' # Classify into 3 fuzzy horizons
#' fuzzy_result <- horizon_classify_fuzzy(data, n_horizons = 3, m = 2.0)
#' print(fuzzy_result)
#'
#' # Softer boundaries with higher fuzziness
#' fuzzy_soft <- horizon_classify_fuzzy(data, n_horizons = 3, m = 3.0)
#' summary(fuzzy_soft)
#' }
horizon_classify_fuzzy <- function(data,
                                    depth_col = "depth",
                                    element_cols = NULL,
                                    n_horizons = 5,
                                    m = .FUZZY_DEFAULT_EXPONENT,
                                    max_iter = .FUZZY_DEFAULT_MAX_ITER,
                                    tolerance = .FUZZY_DEFAULT_TOLERANCE,
                                    convergence = "membership",
                                    init_method = "kmeans",
                                    include_depth_feature = FALSE,
                                    use_rust = TRUE) {

  # Input validation
  if (!is.data.frame(data)) {
    stop("data must be a data.frame")
  }

  # Validate m parameter (required by Rust implementation)
  if (!is.numeric(m) || m <= 1.0) {
    stop("Fuzziness exponent m must be > 1.0, got: ", m)
  }

  # Auto-detect element columns if not specified
  if (is.null(element_cols)) {
    numeric_cols <- names(data)[sapply(data, is.numeric)]
    element_cols <- setdiff(numeric_cols, depth_col)

    if (length(element_cols) == 0) {
      stop("No numeric element columns found")
    }
  }

  # Validate data (reuse from 03g)
  validation <- .validate_horizon_data(data, depth_col, element_cols)

  if (!validation$valid) {
    stop("Data validation failed:\n  ", paste(validation$errors, collapse = "\n  "))
  }

  if (length(validation$warnings) > 0) {
    for (w in validation$warnings) {
      warning(w, call. = FALSE)
    }
  }

  # Sort by depth
  data <- data[order(data[[depth_col]]), ]
  depths <- data[[depth_col]]
  element_matrix <- as.matrix(data[, element_cols, drop = FALSE])

  # Handle missing values - remove rows with any NA
  complete_rows <- complete.cases(element_matrix)
  if (sum(complete_rows) < n_horizons) {
    stop("Too many missing values. Need at least ", n_horizons,
         " complete observations for ", n_horizons, " clusters.")
  }

  if (sum(!complete_rows) > 0) {
    warning(sum(!complete_rows), " rows with missing values removed before clustering",
            call. = FALSE)
    element_matrix <- element_matrix[complete_rows, , drop = FALSE]
    depths <- depths[complete_rows]
  }

  # Optionally include depth as feature
  if (include_depth_feature) {
    # Standardize depth to similar scale as elements
    depth_standardized <- scale(depths)
    element_matrix <- cbind(element_matrix, depth = depth_standardized)
  }

  # Call implementation (try Rust first if available)
  result_raw <- NULL
  method_used <- "r"

  if (use_rust && rust_backend_available()) {
    # Try Rust implementation
    tryCatch({
      # Initialize centers for Rust
      if (init_method == "kmeans") {
        km_init <- stats::kmeans(element_matrix, centers = n_horizons, nstart = 10)
        centers_init <- km_init$centers
      } else {
        set.seed(NULL)
        init_indices <- sample(nrow(element_matrix), n_horizons)
        centers_init <- element_matrix[init_indices, , drop = FALSE]
      }

      # Call Rust implementation directly via .Call
      rust_result <- .Call(
        "wrap__fuzzy_kmeans_rust",
        element_matrix, as.integer(n_horizons), as.numeric(m),
        as.integer(max_iter), as.numeric(tolerance),
        centers_init,
        PACKAGE = "soilmotif"
      )

      # Convert Rust result to expected format
      result_raw <- list(
        centers = rust_result$centers,
        memberships = rust_result$memberships,
        entropy = rust_result$entropy,
        iterations = rust_result$iterations,
        converged = rust_result$converged
      )
      method_used <- "rust"
    }, error = function(e) {
      # Rust implementation failed, will fall back to R
      NULL
    })
  }

  # Fall back to R implementation if Rust not available or failed
  if (is.null(result_raw)) {
    result_raw <- .fuzzy_kmeans_r(
      element_matrix, k = n_horizons, m = m,
      max_iter = max_iter, tol = tolerance,
      init_method = init_method,
      convergence = convergence
    )
    method_used <- "r"
  }

  # Determine dominant horizon for each depth
  dominant_horizon <- apply(result_raw$memberships, 1, which.max)

  # Create result object
  result <- list(
    call = match.call(),
    depths = depths,
    element_cols = element_cols,
    centers = result_raw$centers,
    memberships = result_raw$memberships,
    entropy = result_raw$entropy,
    dominant_horizon = dominant_horizon,
    n_horizons = n_horizons,
    m = m,
    iterations = result_raw$iterations,
    converged = result_raw$converged,
    method = method_used
  )

  class(result) <- "fuzzy_horizons"

  return(result)
}


#' Print method for fuzzy_horizons objects
#'
#' @param x Object of class "fuzzy_horizons"
#' @param ... Additional arguments (unused)
#' @export
print.fuzzy_horizons <- function(x, ...) {
  cat("Fuzzy Horizon Classification\n")
  cat("=============================\n\n")

  cat("Number of horizons:", x$n_horizons, "\n")
  cat("Fuzziness exponent (m):", x$m, "\n")
  cat("Converged:", x$converged, "after", x$iterations, "iterations\n")
  cat("Elements analyzed:", length(x$element_cols), "-",
      paste(head(x$element_cols, 3), collapse = ", "),
      if (length(x$element_cols) > 3) "..." else "", "\n\n")

  cat("Entropy statistics (0=certain, 1=uncertain):\n")
  cat("  Mean:", sprintf("%.3f", mean(x$entropy)), "\n")
  cat("  Median:", sprintf("%.3f", stats::median(x$entropy)), "\n")
  cat("  Range: [", sprintf("%.3f", min(x$entropy)), ",",
      sprintf("%.3f", max(x$entropy)), "]\n\n")

  cat("Horizon distribution (dominant assignments):\n")
  horizon_counts <- table(x$dominant_horizon)
  print(horizon_counts)

  invisible(x)
}


#' Summary method for fuzzy_horizons objects
#'
#' @param object Object of class "fuzzy_horizons"
#' @param ... Additional arguments (unused)
#' @export
summary.fuzzy_horizons <- function(object, ...) {
  cat("Fuzzy Horizon Classification Summary\n")
  cat("=====================================\n\n")

  cat("Clustering parameters:\n")
  cat("  Number of horizons (k):", object$n_horizons, "\n")
  cat("  Fuzziness exponent (m):", object$m, "\n")
  cat("  Convergence criterion:", "membership", "\n")  # From implementation
  cat("  Converged:", object$converged, "\n")
  cat("  Iterations:", object$iterations, "\n\n")

  cat("Data:\n")
  cat("  Depths analyzed:", length(object$depths), "\n")
  cat("  Depth range: [", min(object$depths), ",", max(object$depths), "]\n")
  cat("  Elements:", length(object$element_cols), "\n")
  cat("  Elements:", paste(object$element_cols, collapse = ", "), "\n\n")

  cat("Classification quality:\n")
  cat("  Mean entropy:", sprintf("%.3f", mean(object$entropy)), "\n")
  cat("  Median entropy:", sprintf("%.3f", stats::median(object$entropy)), "\n")
  cat("  High uncertainty depths (entropy > 0.7):",
      sum(object$entropy > 0.7), "\n\n")

  cat("Dominant horizon distribution:\n")
  horizon_table <- table(object$dominant_horizon)
  horizon_df <- data.frame(
    Horizon = names(horizon_table),
    Count = as.numeric(horizon_table),
    Percentage = sprintf("%.1f%%", 100 * as.numeric(horizon_table) / length(object$dominant_horizon))
  )
  print(horizon_df, row.names = FALSE)

  cat("\nCluster Centers (element means):\n")
  centers_df <- as.data.frame(object$centers)
  colnames(centers_df) <- object$element_cols
  rownames(centers_df) <- paste0("H", seq_len(object$n_horizons))
  print(round(centers_df, 2))

  invisible(object)
}
