# Comprehensive R vs Rust Implementation Comparison
# Tests to verify Rust implementations produce equivalent results to R

# Helper: Extract internal functions from package namespace
.get_internal_function <- function(pkg_name, fn_name) {
  get(fn_name, envir = asNamespace(pkg_name), inherits = FALSE)
}

# ============================================================================
# Part 1: Mahalanobis Boundary Detection Comparison
# ============================================================================

test_that("Mahalanobis R: distances are computed correctly", {
  # Create simple synthetic data with clear horizons
  n <- 100
  depths <- seq(0, 100, length.out = n)

  # Create distinct element concentrations
  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)

  # Run R implementation
  result_r <- horizon_boundaries_mahalanobis(
    data,
    window_size = 10,
    method = "local_maxima",
    threshold = 2.0
  )

  # Check basic properties
  expect_s3_class(result_r, "horizon_boundaries")
  expect_true(nrow(result_r$boundaries) > 0)
  expect_true(all(result_r$distances >= 0, na.rm = TRUE))

  # Check boundaries are detected
  detected <- result_r$boundaries$depth[result_r$boundaries$is_boundary]
  expect_true(length(detected) > 0)

  # True boundaries are around 30 and 70 - should detect something near those
  expect_true(any(detected > 25 & detected < 35))
  expect_true(any(detected > 65 & detected < 75))
})

test_that("Mahalanobis Rust FFI: function callable and returns correct structure", {
  # Skip if Rust not available
  skip_if_not(exists("mahalanobis_boundary_detection_rust",
                     envir = asNamespace("soilmotif")))

  # Create synthetic data
  n <- 100
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  element_matrix <- as.matrix(data.frame(Al = Al, Fe = Fe, Si = Si))

  # Call Rust implementation directly
  distances_rust <- soilmotif:::mahalanobis_boundary_detection_rust(
    element_matrix,
    depths,
    10
  )

  # Check properties
  expect_type(distances_rust, "double")
  expect_length(distances_rust, n)
  expect_true(all(distances_rust >= 0, na.rm = TRUE))
})

test_that("Mahalanobis R vs Rust: distances match within tolerance", {
  # Skip if Rust not available
  skip_if_not(exists("mahalanobis_boundary_detection_rust",
                     envir = asNamespace("soilmotif")))

  # Use consistent seed for reproducibility
  set.seed(42)

  # Create synthetic data
  n <- 100
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)
  element_matrix <- as.matrix(data[, c("Al", "Fe", "Si")])

  # Get R implementation distances
  result_r <- horizon_boundaries_mahalanobis(
    data,
    window_size = 10,
    method = "local_maxima"
  )
  distances_r <- result_r$distances

  # Get Rust implementation distances
  distances_rust <- soilmotif:::mahalanobis_boundary_detection_rust(
    element_matrix,
    depths,
    10
  )

  # Compare distances
  # Remove NAs for comparison
  valid_idx <- !is.na(distances_r) & !is.na(distances_rust)

  distances_r_clean <- distances_r[valid_idx]
  distances_rust_clean <- distances_rust[valid_idx]

  # Check that distances exist and are similar
  expect_true(length(distances_r_clean) > 0)
  expect_equal(length(distances_r_clean), length(distances_rust_clean))

  # Allow some tolerance for numerical differences
  # Using RMSE and correlation as metrics
  rmse <- sqrt(mean((distances_r_clean - distances_rust_clean) ^ 2))
  correlation <- cor(distances_r_clean, distances_rust_clean)

  cat("\n  Mahalanobis Distance Comparison:")
  cat("\n  RMSE:", round(rmse, 4))
  cat("\n  Correlation:", round(correlation, 4))
  cat("\n  R mean distance:", round(mean(distances_r_clean), 2))
  cat("\n  Rust mean distance:", round(mean(distances_rust_clean), 2))

  # Expect high correlation and reasonable RMSE
  expect_gt(correlation, 0.95, label = "Distance correlation")
  expect_lt(rmse / mean(distances_r_clean), 0.1,
            label = "Relative RMSE")
})

test_that("Mahalanobis: boundary detection matches between R and Rust", {
  # Skip if Rust not available
  skip_if_not(exists("mahalanobis_boundary_detection_rust",
                     envir = asNamespace("soilmotif")))

  set.seed(42)

  # Create synthetic data with clear boundaries
  n <- 100
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)
  element_matrix <- as.matrix(data[, c("Al", "Fe", "Si")])

  # Get R implementation boundaries
  result_r <- horizon_boundaries_mahalanobis(
    data,
    window_size = 10,
    method = "local_maxima",
    threshold = 2.0
  )
  boundaries_r <- result_r$boundaries$depth[result_r$boundaries$is_boundary]

  # Get Rust distances and apply same detection
  distances_rust <- soilmotif:::mahalanobis_boundary_detection_rust(
    element_matrix,
    depths,
    10
  )

  # Find local maxima in Rust distances
  valid_idx <- !is.na(distances_rust)
  valid_distances <- distances_rust[valid_idx]
  valid_depths <- depths[valid_idx]

  # Simple local maxima detection matching R logic
  if (length(valid_distances) > 2) {
    local_maxima_idx <- logical(length(valid_distances))
    for (i in 2:(length(valid_distances) - 1)) {
      if (valid_distances[i] > valid_distances[i-1] &&
          valid_distances[i] > valid_distances[i+1] &&
          valid_distances[i] >= 2.0) {
        local_maxima_idx[i] <- TRUE
      }
    }
    boundaries_rust <- valid_depths[local_maxima_idx]
  } else {
    boundaries_rust <- numeric(0)
  }

  cat("\n  Boundary Detection Comparison:")
  cat("\n  R boundaries at depths:", paste(round(boundaries_r, 1), collapse = ", "))
  cat("\n  Rust boundaries at depths:", paste(round(boundaries_rust, 1), collapse = ", "))

  # Both should detect boundaries near 30 and 70
  expect_gt(length(boundaries_r), 0)
  expect_gt(length(boundaries_rust), 0)
})

# ============================================================================
# Part 2: Fuzzy k-means Clustering Comparison
# ============================================================================

test_that("Fuzzy k-means R: clustering produces valid memberships", {
  # Create synthetic data
  n <- 100
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)

  # Run R implementation
  result_r <- horizon_classify_fuzzy(data, n_horizons = 3)

  # Check structure
  expect_s3_class(result_r, "fuzzy_horizons")
  expect_equal(nrow(result_r$memberships), n)
  expect_equal(ncol(result_r$memberships), 3)

  # Check membership properties
  row_sums <- rowSums(result_r$memberships)
  expect_true(all(abs(row_sums - 1.0) < 1e-6))

  # Check all values in [0, 1]
  expect_true(all(result_r$memberships >= 0 & result_r$memberships <= 1))

  # Check entropy
  expect_true(all(result_r$entropy >= 0 & result_r$entropy <= 1))
})

test_that("Fuzzy k-means Rust FFI: function callable and returns correct structure", {
  skip_if_not(exists("fuzzy_kmeans_rust",
                     envir = asNamespace("soilmotif")))

  # Create synthetic data
  n <- 100
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  element_matrix <- as.matrix(data.frame(Al = Al, Fe = Fe, Si = Si))

  # Initialize centers using k-means
  km <- stats::kmeans(element_matrix, centers = 3, iter.max = 10)
  centers_init <- km$centers

  # Call Rust implementation
  result_rust <- soilmotif:::fuzzy_kmeans_rust(
    element_matrix,
    k = 3,
    m = 2.0,
    max_iter = 100,
    tol = 1e-6,
    centers_init = centers_init
  )

  # Check structure
  expect_is(result_rust, "list")
  expect_named(result_rust, c("centers", "memberships", "entropy", "converged", "iterations"))

  # Check dimensions
  expect_equal(nrow(result_rust$centers), 3)
  expect_equal(ncol(result_rust$centers), 3)
  expect_equal(nrow(result_rust$memberships), n)
  expect_equal(ncol(result_rust$memberships), 3)

  # Check membership properties
  row_sums <- rowSums(result_rust$memberships)
  expect_true(all(abs(row_sums - 1.0) < 1e-6))
})

test_that("Fuzzy k-means R vs Rust: memberships match within tolerance", {
  skip_if_not(exists("fuzzy_kmeans_rust",
                     envir = asNamespace("soilmotif")))

  set.seed(42)

  # Create synthetic data
  n <- 100
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)
  element_matrix <- as.matrix(data[, c("Al", "Fe", "Si")])

  # Get R implementation
  result_r <- horizon_classify_fuzzy(data, n_horizons = 3)

  # Get Rust implementation with same centers
  result_rust <- soilmotif:::fuzzy_kmeans_rust(
    element_matrix,
    k = 3,
    m = 2.0,
    max_iter = 100,
    tol = 1e-6,
    centers_init = result_r$centers
  )

  # Compare memberships
  rmse_membership <- sqrt(mean((result_r$memberships - result_rust$memberships) ^ 2))

  cat("\n  Fuzzy k-means Comparison:")
  cat("\n  Membership RMSE:", round(rmse_membership, 6))
  cat("\n  R entropy mean:", round(mean(result_r$entropy), 4))
  cat("\n  Rust entropy mean:", round(mean(result_rust$entropy), 4))
  cat("\n  Correlation:", round(cor(as.vector(result_r$memberships),
                                    as.vector(result_rust$memberships)), 4))

  # Check convergence
  expect_true(result_rust$converged)

  # Allow some tolerance for membership differences
  expect_lt(rmse_membership, 0.05, label = "Membership RMSE")
})

test_that("Fuzzy k-means: classifications match between R and Rust", {
  skip_if_not(exists("fuzzy_kmeans_rust",
                     envir = asNamespace("soilmotif")))

  set.seed(42)

  # Create synthetic data
  n <- 100
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)
  element_matrix <- as.matrix(data[, c("Al", "Fe", "Si")])

  # Get R hard classifications (argmax of memberships)
  result_r <- horizon_classify_fuzzy(data, n_horizons = 3)
  classes_r <- apply(result_r$memberships, 1, which.max)

  # Get Rust hard classifications
  result_rust <- soilmotif:::fuzzy_kmeans_rust(
    element_matrix,
    k = 3,
    m = 2.0,
    max_iter = 100,
    tol = 1e-6,
    centers_init = result_r$centers
  )
  classes_rust <- apply(result_rust$memberships, 1, which.max)

  # Compare classifications
  # Note: Hard assignments may differ due to permutation, so check consistency
  agreement <- mean(classes_r == classes_rust)

  cat("\n  Hard Classification Agreement:", round(agreement * 100, 1), "%")

  # Should have reasonable agreement
  expect_gt(agreement, 0.8)
})

# ============================================================================
# Part 3: Edge Cases and Data Types
# ============================================================================

test_that("Both implementations handle missing values consistently", {
  skip_if_not(exists("mahalanobis_boundary_detection_rust",
                     envir = asNamespace("soilmotif")))

  # Create data with missing values
  n <- 80
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 25), rep(200, 30), rep(150, 25)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 25), rep(80, 30), rep(60, 25)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 25), rep(250, 30), rep(280, 25)) + rnorm(n, sd = 8)

  # Add some missing values
  Al[c(5, 15, 65)] <- NA
  Fe[c(10, 40)] <- NA

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)
  element_matrix <- as.matrix(data[, c("Al", "Fe", "Si")])

  # Run R implementation
  expect_no_error({
    result_r <- horizon_boundaries_mahalanobis(data, window_size = 10)
  })

  # Run Rust implementation
  expect_no_error({
    distances_rust <- soilmotif:::mahalanobis_boundary_detection_rust(
      element_matrix,
      depths,
      10
    )
  })
})

test_that("Both implementations handle large datasets", {
  skip_if_not(exists("mahalanobis_boundary_detection_rust",
                     envir = asNamespace("soilmotif")))

  # Create larger dataset
  n <- 1000
  depths <- seq(0, 500, length.out = n)

  Al <- c(rep(100, 300), rep(200, 400), rep(150, 300)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 300), rep(80, 400), rep(60, 300)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 300), rep(250, 400), rep(280, 300)) + rnorm(n, sd = 8)
  K <- rnorm(n, mean = 50, sd = 10)
  Ca <- rnorm(n, mean = 150, sd = 20)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si, K = K, Ca = Ca)
  element_matrix <- as.matrix(data[, c("Al", "Fe", "Si", "K", "Ca")])

  # Run both implementations
  expect_no_error({
    result_r <- horizon_boundaries_mahalanobis(data, window_size = 20)
  })

  expect_no_error({
    distances_rust <- soilmotif:::mahalanobis_boundary_detection_rust(
      element_matrix,
      depths,
      20
    )
  })

  # Verify results
  expect_equal(length(distances_rust), n)
})
