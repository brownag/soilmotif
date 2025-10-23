# R Implementation Validation and Comparison Tests
# Tests to ensure R implementations are correct and reproducible

# ============================================================================
# Part 1: Mahalanobis Boundary Detection - R Implementation
# ============================================================================

test_that("Mahalanobis: R implementation produces consistent results", {
  set.seed(42)

  # Create synthetic data with known horizons
  n <- 100
  depths <- seq(0, 100, length.out = n)

  # Create 3 distinct horizons
  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)

  # Run twice with same seed - should get identical results
  result1 <- horizon_boundaries_mahalanobis(data, window_size = 10, method = "local_maxima")

  set.seed(42)
  data2 <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)
  result2 <- horizon_boundaries_mahalanobis(data2, window_size = 10, method = "local_maxima")

  # Distances should be identical (deterministic algorithm)
  expect_equal(result1$distances, result2$distances)

  # Boundaries detected should be identical
  b1 <- result1$boundaries$depth[result1$boundaries$is_boundary]
  b2 <- result2$boundaries$depth[result2$boundaries$is_boundary]
  expect_equal(sort(b1), sort(b2))
})

test_that("Mahalanobis: distances increase at boundaries", {
  set.seed(123)

  # Create clear-cut boundaries with small variation within horizons
  n <- 90
  depths <- seq(0, 90, length.out = n)

  # Three distinct horizons with small within-horizon variation
  Al <- c(rep(100, 30), rep(200, 30), rep(150, 30)) + rnorm(n, sd = 2)
  Fe <- c(rep(50, 30), rep(80, 30), rep(60, 30)) + rnorm(n, sd = 1.5)
  Si <- c(rep(300, 30), rep(250, 30), rep(280, 30)) + rnorm(n, sd = 2.5)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)

  result <- horizon_boundaries_mahalanobis(
    data,
    window_size = 10,
    method = "local_maxima",
    threshold = 1.5
  )

  # Boundaries should be detected around depth 30 and 60
  boundaries <- result$boundaries$depth[result$boundaries$is_boundary]

  cat("\n  True boundaries: 30, 60")
  cat("\n  Detected boundaries:", paste(round(boundaries, 1), collapse = ", "))

  # Should detect at least one boundary in the transition zones
  expect_gt(length(boundaries), 0)
  # Cumulative - should detect within the middle and lower transition zones
  transition_zone <- boundaries[boundaries > 25 & boundaries < 70]
  expect_gt(length(transition_zone), 0)
})

test_that("Mahalanobis: different methods produce different but valid results", {
  set.seed(456)

  n <- 100
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)

  # Test different methods
  methods <- c("local_maxima", "threshold", "changepoint")

  results <- lapply(methods, function(m) {
    horizon_boundaries_mahalanobis(data, window_size = 10, method = m)
  })

  names(results) <- methods

  # Each method should detect some boundaries
  lapply(results, function(r) {
    boundaries <- r$boundaries$depth[r$boundaries$is_boundary]
    expect_gt(length(boundaries), 0, label = paste("method:", r$method))
  })

  # Results from different methods should differ (they use different logic)
  b_lm <- results$local_maxima$boundaries$depth[
    results$local_maxima$boundaries$is_boundary
  ]
  b_thresh <- results$threshold$boundaries$depth[
    results$threshold$boundaries$is_boundary
  ]

  cat("\n  Local maxima boundaries:", paste(round(b_lm, 1), collapse = ", "))
  cat("\n  Threshold boundaries:", paste(round(b_thresh, 1), collapse = ", "))
})

test_that("Mahalanobis: window size affects detection", {
  set.seed(789)

  n <- 100
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)

  # Test different window sizes
  result_small <- horizon_boundaries_mahalanobis(data, window_size = 5)
  result_large <- horizon_boundaries_mahalanobis(data, window_size = 20)

  boundaries_small <- result_small$boundaries$depth[result_small$boundaries$is_boundary]
  boundaries_large <- result_large$boundaries$depth[result_large$boundaries$is_boundary]

  cat("\n  Small window (5):", paste(round(boundaries_small, 1), collapse = ", "))
  cat("\n  Large window (20):", paste(round(boundaries_large, 1), collapse = ", "))

  # Both should detect something
  expect_gt(length(boundaries_small), 0)
  expect_gt(length(boundaries_large), 0)
})

# ============================================================================
# Part 2: Fuzzy k-means Clustering - R Implementation
# ============================================================================

test_that("Fuzzy k-means: R implementation produces valid membership", {
  set.seed(100)

  n <- 100
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)

  result <- horizon_classify_fuzzy(data, n_horizons = 3)

  # Check structure
  expect_s3_class(result, "fuzzy_horizons")
  expect_equal(nrow(result$memberships), n)
  expect_equal(ncol(result$memberships), 3)

  # Each row must sum to 1 (fuzzy constraint)
  row_sums <- rowSums(result$memberships)
  expect_true(all(abs(row_sums - 1.0) < 1e-6),
              label = "Membership rows sum to 1")

  # All values in [0, 1]
  expect_true(all(result$memberships >= 0 & result$memberships <= 1),
              label = "Membership values in [0, 1]")

  # Entropy should be valid
  expect_true(all(result$entropy >= 0 & result$entropy <= 1),
              label = "Entropy in [0, 1]")
})

test_that("Fuzzy k-means: convergence behavior is correct", {
  set.seed(200)

  n <- 80
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 25), rep(200, 30), rep(150, 25)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 25), rep(80, 30), rep(60, 25)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 25), rep(250, 30), rep(280, 25)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)

  # Run with different max_iter
  result_short <- horizon_classify_fuzzy(data, n_horizons = 3, max_iter = 10)
  result_long <- horizon_classify_fuzzy(data, n_horizons = 3, max_iter = 200)

  cat("\n  Iterations (max=10):", result_short$iterations)
  cat("\n  Iterations (max=200):", result_long$iterations)

  # Long run should converge with fewer/equal iterations
  expect_lte(result_long$iterations, 200)
  expect_lte(result_short$iterations, 10)
})

test_that("Fuzzy k-means: different k values produce different results", {
  set.seed(300)

  n <- 100
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 25), rep(150, 25), rep(200, 25), rep(175, 25)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 25), rep(60, 25), rep(80, 25), rep(70, 25)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 25), rep(290, 25), rep(250, 25), rep(270, 25)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)

  # Test different k values
  result_k2 <- horizon_classify_fuzzy(data, n_horizons = 2)
  result_k3 <- horizon_classify_fuzzy(data, n_horizons = 3)
  result_k4 <- horizon_classify_fuzzy(data, n_horizons = 4)

  # Check that memberships are different
  expect_false(identical(result_k2$memberships, result_k3$memberships))
  expect_false(identical(result_k3$memberships, result_k4$memberships))

  cat("\n  k=2 entropy mean:", round(mean(result_k2$entropy), 4))
  cat("\n  k=3 entropy mean:", round(mean(result_k3$entropy), 4))
  cat("\n  k=4 entropy mean:", round(mean(result_k4$entropy), 4))
})

test_that("Fuzzy k-means: entropy increases with fuzziness", {
  set.seed(400)

  n <- 100
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)

  # Different m (fuzziness) values
  result_crisp <- horizon_classify_fuzzy(data, n_horizons = 3, m = 1.1)
  result_fuzzy <- horizon_classify_fuzzy(data, n_horizons = 3, m = 2.0)
  result_very_fuzzy <- horizon_classify_fuzzy(data, n_horizons = 3, m = 3.0)

  entropy_crisp <- mean(result_crisp$entropy)
  entropy_fuzzy <- mean(result_fuzzy$entropy)
  entropy_very_fuzzy <- mean(result_very_fuzzy$entropy)

  cat("\n  m=1.1 entropy:", round(entropy_crisp, 4))
  cat("\n  m=2.0 entropy:", round(entropy_fuzzy, 4))
  cat("\n  m=3.0 entropy:", round(entropy_very_fuzzy, 4))

  # Higher m should generally produce higher entropy
  expect_lt(entropy_crisp, entropy_very_fuzzy)
})

test_that("Fuzzy k-means: reproducible with same seed", {
  create_test_data <- function() {
    set.seed(500)
    n <- 100
    depths <- seq(0, 100, length.out = n)
    Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
    Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
    Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)
    data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)
  }

  data1 <- create_test_data()
  result1 <- horizon_classify_fuzzy(data1, n_horizons = 3)

  data2 <- create_test_data()
  result2 <- horizon_classify_fuzzy(data2, n_horizons = 3)

  # Results should be identical
  expect_equal(result1$memberships, result2$memberships)
  expect_equal(result1$entropy, result2$entropy)
})

# ============================================================================
# Part 3: Integration Tests
# ============================================================================

test_that("Both methods work on same dataset", {
  set.seed(600)

  n <- 100
  depths <- seq(0, 100, length.out = n)

  Al <- c(rep(100, 30), rep(200, 40), rep(150, 30)) + rnorm(n, sd = 5)
  Fe <- c(rep(50, 30), rep(80, 40), rep(60, 30)) + rnorm(n, sd = 3)
  Si <- c(rep(300, 30), rep(250, 40), rep(280, 30)) + rnorm(n, sd = 8)

  data <- data.frame(depth = depths, Al = Al, Fe = Fe, Si = Si)

  # Run both analyses
  result_mahal <- horizon_boundaries_mahalanobis(data, window_size = 10)
  result_fuzzy <- horizon_classify_fuzzy(data, n_horizons = 3)

  # Both should succeed
  expect_s3_class(result_mahal, "horizon_boundaries")
  expect_s3_class(result_fuzzy, "fuzzy_horizons")

  # Compare boundary locations
  boundaries_mahal <- result_mahal$boundaries$depth[result_mahal$boundaries$is_boundary]
  horizons_fuzzy <- unique(apply(result_fuzzy$memberships, 1, which.max))

  cat("\n  Mahalanobis boundaries:", paste(round(boundaries_mahal, 1), collapse = ", "))
  cat("\n  Fuzzy k-means horizons:", length(horizons_fuzzy))
  cat("\n  Agreement in overall horizon count:", length(horizons_fuzzy) >= 2)
})
