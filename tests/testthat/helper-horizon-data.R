# Helper functions to generate synthetic horizon test data
# Shared between test-horizons.R (03g) and test-fuzzy-horizons.R (03h)

#' Generate synthetic multivariate soil profile data
#'
#' Creates test data with known horizon structure for validating
#' boundary detection and fuzzy classification algorithms.
#'
#' @param n_depths Integer. Number of depth observations
#' @param horizon_depths Numeric vector. Depths where boundaries occur
#' @param n_elements Integer. Number of element features
#' @param noise_level Numeric. Standard deviation for added noise
#' @param transition_width Numeric. Width of transitional zones between horizons
#' @return data.frame with depth and element columns
generate_horizon_data <- function(n_depths = 100,
                                   horizon_depths = c(30, 70),
                                   n_elements = 5,
                                   noise_level = 0.1,
                                   transition_width = 5) {

  depths <- seq(1, n_depths, by = 1)
  n_horizons <- length(horizon_depths) + 1

  # Generate element concentrations for each horizon type
  # Each horizon has distinct element signature
  horizon_signatures <- matrix(runif(n_horizons * n_elements, 10, 90),
                                nrow = n_horizons, ncol = n_elements)

  # Assign each depth to a horizon (with smooth transitions)
  element_matrix <- matrix(NA, nrow = n_depths, ncol = n_elements)

  for (d in seq_along(depths)) {
    depth <- depths[d]

    # Find which horizon this depth belongs to
    horizon_id <- 1
    for (i in seq_along(horizon_depths)) {
      if (depth > horizon_depths[i]) {
        horizon_id <- i + 1
      }
    }

    # Base values from horizon signature
    base_values <- horizon_signatures[horizon_id, ]

    # Add smooth transitions near boundaries
    if (horizon_id > 1) {
      boundary <- horizon_depths[horizon_id - 1]
      dist_to_boundary <- abs(depth - boundary)

      if (dist_to_boundary < transition_width) {
        # Blend with previous horizon
        prev_values <- horizon_signatures[horizon_id - 1, ]
        weight <- dist_to_boundary / transition_width
        base_values <- weight * base_values + (1 - weight) * prev_values
      }
    }

    # Add noise
    element_matrix[d, ] <- base_values + rnorm(n_elements, 0, noise_level)
  }

  # Create data.frame
  df <- as.data.frame(element_matrix)
  names(df) <- paste0("element_", seq_len(n_elements))
  df$depth <- depths

  # Reorder columns to put depth first
  df <- df[, c("depth", paste0("element_", seq_len(n_elements)))]

  # Store metadata as attributes
  attr(df, "true_boundaries") <- horizon_depths
  attr(df, "n_horizons") <- n_horizons
  attr(df, "horizon_signatures") <- horizon_signatures

  return(df)
}


#' Generate test data: Simple case with sharp boundaries
#'
#' 3 horizons, clear separation, minimal noise
test_data_simple <- function() {
  set.seed(123)  # Reproducible
  generate_horizon_data(
    n_depths = 100,
    horizon_depths = c(30, 70),
    n_elements = 3,
    noise_level = 0.05,
    transition_width = 2
  )
}


#' Generate test data: Gradual transitions
#'
#' 4 horizons, smooth changes between horizons
test_data_gradual <- function() {
  set.seed(456)
  generate_horizon_data(
    n_depths = 120,
    horizon_depths = c(25, 55, 90),
    n_elements = 4,
    noise_level = 0.1,
    transition_width = 10
  )
}


#' Generate test data: Noisy measurements
#'
#' 3 horizons with realistic measurement variability
test_data_noisy <- function() {
  set.seed(789)
  generate_horizon_data(
    n_depths = 100,
    horizon_depths = c(35, 75),
    n_elements = 5,
    noise_level = 0.3,  # Higher noise
    transition_width = 5
  )
}


#' Generate test data: Irregular spacing
#'
#' Non-uniform depth increments (sparse sampling)
test_data_irregular <- function() {
  set.seed(101112)

  # First generate regular data
  df <- generate_horizon_data(
    n_depths = 100,
    horizon_depths = c(30, 70),
    n_elements = 4,
    noise_level = 0.1,
    transition_width = 5
  )

  # Subsample irregularly
  # Dense near surface, sparse at depth
  indices <- c(
    seq(1, 30, by = 2),    # Every 2 cm near surface
    seq(32, 70, by = 5),   # Every 5 cm in middle
    seq(75, 100, by = 10)  # Every 10 cm at depth
  )

  df <- df[indices, ]
  rownames(df) <- NULL

  return(df)
}


#' Generate test data: Missing values
#'
#' Realistic scenario with some missing measurements
test_data_missing <- function() {
  set.seed(131415)

  df <- generate_horizon_data(
    n_depths = 100,
    horizon_depths = c(30, 70),
    n_elements = 5,
    noise_level = 0.1,
    transition_width = 5
  )

  # Introduce 5-10% missing values randomly
  n_cells <- nrow(df) * (ncol(df) - 1)  # Exclude depth column
  n_missing <- round(0.07 * n_cells)

  for (i in seq_len(n_missing)) {
    row <- sample(nrow(df), 1)
    col <- sample(2:ncol(df), 1)  # Skip depth column
    df[row, col] <- NA
  }

  return(df)
}


#' Generate test data: pXRF-like element suite
#'
#' Realistic element names and concentrations
test_data_pxrf <- function() {
  set.seed(161718)

  depths <- seq(1, 150, by = 1)
  n_depths <- length(depths)

  # Define 4 horizons with realistic element concentrations
  # Boundaries at 25, 60, 110 cm
  horizon_boundaries <- c(25, 60, 110)

  # Element concentrations typical of weathered soil profile
  # Rows = horizons (A, E, Bt, C), Columns = elements
  horizon_signatures <- rbind(
    # A horizon: lower Si, moderate Fe/Al
    c(Al = 8.5, Fe = 3.2, Si = 55, K = 2.1, Ca = 1.5, Ti = 0.6, Zr = 0.08, Mn = 0.15),
    # E horizon: high Si, low Fe/Al (eluvial)
    c(Al = 5.0, Fe = 1.8, Si = 72, K = 1.8, Ca = 0.8, Ti = 0.4, Zr = 0.06, Mn = 0.08),
    # Bt horizon: high Al/Fe, lower Si (illuvial clay)
    c(Al = 12.5, Fe = 5.8, Si = 48, K = 2.5, Ca = 2.2, Ti = 0.8, Zr = 0.10, Mn = 0.20),
    # C horizon: parent material, higher Si
    c(Al = 7.0, Fe = 2.8, Si = 68, K = 2.8, Ca = 3.5, Ti = 0.5, Zr = 0.12, Mn = 0.12)
  )

  n_elements <- ncol(horizon_signatures)
  element_matrix <- matrix(NA, nrow = n_depths, ncol = n_elements)

  for (d in seq_along(depths)) {
    depth <- depths[d]

    # Determine horizon
    horizon_id <- 1
    for (i in seq_along(horizon_boundaries)) {
      if (depth > horizon_boundaries[i]) {
        horizon_id <- i + 1
      }
    }

    # Base values
    base_values <- horizon_signatures[horizon_id, ]

    # Smooth transitions (5 cm wide)
    if (horizon_id > 1) {
      boundary <- horizon_boundaries[horizon_id - 1]
      dist_to_boundary <- abs(depth - boundary)

      if (dist_to_boundary < 5) {
        prev_values <- horizon_signatures[horizon_id - 1, ]
        weight <- dist_to_boundary / 5
        base_values <- weight * base_values + (1 - weight) * prev_values
      }
    }

    # Add realistic measurement noise (CV ~ 5-15% depending on element)
    noise <- rnorm(n_elements, 0, base_values * 0.08)
    element_matrix[d, ] <- pmax(base_values + noise, 0.01)  # Keep positive
  }

  # Create data.frame
  df <- as.data.frame(element_matrix)
  names(df) <- colnames(horizon_signatures)
  df$depth <- depths

  # Reorder
  df <- df[, c("depth", colnames(horizon_signatures))]

  # Metadata
  attr(df, "true_boundaries") <- horizon_boundaries
  attr(df, "n_horizons") <- 4
  attr(df, "horizon_names") <- c("A", "E", "Bt", "C")
  attr(df, "horizon_signatures") <- horizon_signatures

  return(df)
}


#' Generate test data: Overlapping clusters
#'
#' For fuzzy k-means where boundaries are truly gradational
test_data_fuzzy_overlapping <- function() {
  set.seed(192021)

  depths <- seq(1, 100, by = 1)
  n_depths <- length(depths)

  # 3 overlapping horizons with very gradual transitions
  # Boundaries are not sharp - membership changes gradually

  # Define cluster centers
  centers <- rbind(
    c(20, 30, 40, 25),  # Horizon 1
    c(50, 45, 55, 50),  # Horizon 2
    c(75, 70, 65, 80)   # Horizon 3
  )

  n_elements <- ncol(centers)
  element_matrix <- matrix(NA, nrow = n_depths, ncol = n_elements)

  # Use smooth membership functions (like fuzzy k-means would produce)
  for (d in seq_along(depths)) {
    depth <- depths[d]

    # Membership decreases with distance from center
    # Peak membership: depth 20 → H1, depth 50 → H2, depth 80 → H3
    membership_peaks <- c(20, 50, 80)
    memberships <- exp(-((depth - membership_peaks) / 15)^2)
    memberships <- memberships / sum(memberships)  # Normalize

    # Weighted combination of centers
    values <- colSums(memberships * centers)

    # Add noise
    element_matrix[d, ] <- values + rnorm(n_elements, 0, 2)
  }

  df <- as.data.frame(element_matrix)
  names(df) <- paste0("element_", seq_len(n_elements))
  df$depth <- depths
  df <- df[, c("depth", paste0("element_", seq_len(n_elements)))]

  # Metadata
  attr(df, "true_centers") <- centers
  attr(df, "n_clusters") <- 3
  attr(df, "membership_peaks") <- c(20, 50, 80)

  return(df)
}
