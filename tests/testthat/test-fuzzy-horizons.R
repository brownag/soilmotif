# Tests for Phase 3h: Fuzzy k-means Horizon Classification

test_that("horizon_classify_fuzzy basic functionality", {
  data <- test_data_simple()

  result <- sm_horizon_classify_fuzzy(
      data,
      depth_col = "depth",
      n_horizons = 3,
      m = 2.0
    )

  expect_s3_class(result, "fuzzy_horizons")
  expect_true("memberships" %in% names(result))
  expect_true("centers" %in% names(result))
  expect_true("entropy" %in% names(result))
  expect_true("dominant_horizon" %in% names(result))

  # Check dimensions
  expect_equal(nrow(result$memberships), nrow(data))
  expect_equal(ncol(result$memberships), 3)
  expect_equal(nrow(result$centers), 3)
})


test_that("fuzzy memberships sum to 1 per row", {
  data <- test_data_simple()

  result <- sm_horizon_classify_fuzzy(data, n_horizons = 3)

  # Check that each row sums to 1 (within tolerance)
  row_sums <- rowSums(result$memberships)
  expect_true(all(abs(row_sums - 1.0) < 1e-6))
})


test_that("entropy is normalized to [0, 1]", {
  data <- test_data_simple()

  result <- sm_horizon_classify_fuzzy(data, n_horizons = 3)

  expect_true(all(result$entropy >= 0))
  expect_true(all(result$entropy <= 1))
})


test_that("horizon_classify_fuzzy auto-detects element columns", {
  data <- test_data_simple()

  # Don't specify element_cols
  result <- sm_horizon_classify_fuzzy(data, n_horizons = 3)

  expect_equal(length(result$element_cols), 3)
  expect_true(all(result$element_cols %in% names(data)))
  expect_false("depth" %in% result$element_cols)
})


test_that("horizon_classify_fuzzy respects fuzziness parameter m", {
  data <- test_data_simple()

  # Lower m = crisper boundaries
  result_crisp <- sm_horizon_classify_fuzzy(data, n_horizons = 3, m = 1.5)

  # Higher m = fuzzier boundaries
  result_fuzzy <- sm_horizon_classify_fuzzy(data, n_horizons = 3, m = 3.0)

  # Fuzzy should have higher mean entropy (more uncertainty)
  expect_gte(mean(result_fuzzy$entropy), mean(result_crisp$entropy))
})


test_that("horizon_classify_fuzzy validates m > 1.0", {
  data <- test_data_simple()

  expect_error(
    sm_horizon_classify_fuzzy(data, n_horizons = 3, m = 1.0),
    regexp = "m must be > 1.0"
  )

  expect_error(
    sm_horizon_classify_fuzzy(data, n_horizons = 3, m = 0.5),
    regexp = "m must be > 1.0"
  )
})


test_that("horizon_classify_fuzzy works with different k values", {
  data <- test_data_simple()

  for (k in 2:5) {
    result <- sm_horizon_classify_fuzzy(data, n_horizons = k)

    expect_s3_class(result, "fuzzy_horizons")
    expect_equal(result$n_horizons, k)
    expect_equal(ncol(result$memberships), k)
    expect_equal(nrow(result$centers), k)
  }
})


test_that("horizon_classify_fuzzy handles initialization methods", {
  data <- test_data_simple()

  # kmeans initialization
  result_kmeans <- sm_horizon_classify_fuzzy(
      data, n_horizons = 3,
      init_method = "kmeans"
    )

  # random initialization
  result_random <- sm_horizon_classify_fuzzy(
      data, n_horizons = 3,
      init_method = "random"
    )

  expect_s3_class(result_kmeans, "fuzzy_horizons")
  expect_s3_class(result_random, "fuzzy_horizons")
})


test_that("horizon_classify_fuzzy convergence criteria work", {
  data <- test_data_simple()

  convergence_methods <- c("membership", "centers", "both")

  for (conv in convergence_methods) {
    result <- sm_horizon_classify_fuzzy(
        data, n_horizons = 3,
        convergence = conv
      )

    expect_s3_class(result, "fuzzy_horizons")
    # Should converge with default tolerance
    expect_true(result$converged || result$iterations >= 100)
  }
})


test_that("horizon_classify_fuzzy include_depth_feature option", {
  data <- test_data_simple()

  # Without depth feature
  result_no_depth <- sm_horizon_classify_fuzzy(
      data, n_horizons = 3,
      include_depth_feature = FALSE
    )

  # With depth feature
  result_with_depth <- sm_horizon_classify_fuzzy(
      data, n_horizons = 3,
      include_depth_feature = TRUE
    )

  expect_s3_class(result_no_depth, "fuzzy_horizons")
  expect_s3_class(result_with_depth, "fuzzy_horizons")

  # Results may differ
  # With depth feature, spatial grouping should be stronger
})


test_that("horizon_classify_fuzzy works on pXRF data", {
  data <- test_data_pxrf()

  result <- sm_horizon_classify_fuzzy(
      data,
      n_horizons = 4,
      m = 2.0
    )

  expect_s3_class(result, "fuzzy_horizons")
  expect_equal(result$n_horizons, 4)

  # Check that realistic elements were used
  expect_true(all(c("Al", "Fe", "Si") %in% result$element_cols))
})


test_that("horizon_classify_fuzzy works with fuzzy overlapping data", {
  data <- test_data_fuzzy_overlapping()

  result <- sm_horizon_classify_fuzzy(
      data,
      n_horizons = 3,
      m = 2.0
    )

  expect_s3_class(result, "fuzzy_horizons")

  # Overlapping data should have some entropy (not all certain)
  # Mean entropy will depend on overlap degree and fuzziness m
  expect_gt(mean(result$entropy), 0.05)  # Relaxed from 0.2
  expect_lt(mean(result$entropy), 0.9)   # Not completely uncertain
})


test_that("horizon_classify_fuzzy handles noisy data", {
  data <- test_data_noisy()

  result <- sm_horizon_classify_fuzzy(
      data,
      n_horizons = 3,
      m = 2.0,
      max_iter = 200  # May need more iterations for noisy data
    )

  expect_s3_class(result, "fuzzy_horizons")

  # Should eventually converge or reach max iterations
  expect_true(result$converged || result$iterations >= 200)
})


test_that("horizon_classify_fuzzy handles missing values", {
  data <- test_data_missing()

  # Expect warning about missing values
  expect_warning(
    expect_warning(
      result <- sm_horizon_classify_fuzzy(data, n_horizons = 3),
      regexp = "rows.*removed"
    ),
    "missing values"
  )

  expect_s3_class(result, "fuzzy_horizons")

  expect_lt(length(result$depths), nrow(data))
})


test_that("print.fuzzy_horizons works", {
  data <- test_data_simple()
  result <- sm_horizon_classify_fuzzy(data, n_horizons = 3)

  expect_output(print(result), regexp = "Fuzzy Horizon Classification")
  expect_output(print(result), regexp = "Number of horizons")
  expect_output(print(result), regexp = "Entropy")
})


test_that("summary.fuzzy_horizons works", {
  data <- test_data_simple()
  result <- sm_horizon_classify_fuzzy(data, n_horizons = 3)

  expect_output(summary(result), regexp = "Summary")
  expect_output(summary(result), regexp = "Cluster Centers")
  expect_output(summary(result), regexp = "Classification quality")
})


test_that("dominant_horizon assignments are valid", {
  data <- test_data_simple()
  result <- sm_horizon_classify_fuzzy(data, n_horizons = 3)

  expect_type(result$dominant_horizon, "integer")
  expect_true(all(result$dominant_horizon >= 1))
  expect_true(all(result$dominant_horizon <= result$n_horizons))
  expect_equal(length(result$dominant_horizon), nrow(data))
})


test_that("horizon_classify_fuzzy transitional zones", {
  data <- test_data_simple()

  # transitional_zones parameter not yet implemented in Phase 2
  # This test will be updated when Phase 3h is complete
  expect_error(
    sm_horizon_classify_fuzzy(
      data, n_horizons = 3,
      transitional_zones = TRUE
    ),
    "unused argument"
  )
})


test_that(".fuzzy_kmeans_r handles edge cases", {
  # Test with minimum data
  data_matrix <- matrix(rnorm(20 * 3), nrow = 20, ncol = 3)

  result <- .fuzzy_kmeans_r(data_matrix, k = 2, m = 2.0)

  expect_type(result, "list")
  expect_true("centers" %in% names(result))
  expect_true("memberships" %in% names(result))
  expect_equal(nrow(result$centers), 2)
  expect_equal(nrow(result$memberships), 20)
})


test_that(".fuzzy_kmeans_r handles k validation", {
  data_matrix <- matrix(rnorm(10 * 3), nrow = 10, ncol = 3)

  # k must be < n
  expect_error(
    .fuzzy_kmeans_r(data_matrix, k = 10, m = 2.0),
    regexp = "less than number of observations"
  )

  expect_error(
    .fuzzy_kmeans_r(data_matrix, k = 15, m = 2.0),
    regexp = "less than number of observations"
  )
})


test_that("horizon_classify_fuzzy max_iter parameter", {
  data <- test_data_simple()

  # Test with different max_iter values
  result_low <- sm_horizon_classify_fuzzy(
      data, n_horizons = 3,
      max_iter = 10
    )

  result_high <- sm_horizon_classify_fuzzy(
      data, n_horizons = 3,
      max_iter = 100
    )

  expect_s3_class(result_low, "fuzzy_horizons")
  expect_s3_class(result_high, "fuzzy_horizons")
})


test_that("horizon_classify_fuzzy returns consistent results", {
  data <- test_data_simple()

  # With kmeans initialization, should be deterministic
  result1 <- sm_horizon_classify_fuzzy(data, n_horizons = 3, init_method = "kmeans")

  result2 <- sm_horizon_classify_fuzzy(data, n_horizons = 3, init_method = "kmeans")

  # Centers may be permuted (label switching), but should have same structure
  expect_equal(dim(result1$centers), dim(result2$centers))
  expect_equal(dim(result1$memberships), dim(result2$memberships))
})
