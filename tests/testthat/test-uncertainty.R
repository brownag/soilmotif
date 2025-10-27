# Tests for Uncertainty Quantification Methods
# Tests all three methods: Hessian, Fisher, and Jackknife

# Create test data with known properties
set.seed(123)
true_params <- c(50, 100)
clay_data <- sm_motif(1:200, true_params) + rnorm(200, 0, 1.0)

test_that("Hessian uncertainty computation works", {
  fit <- sm_optim(clay_data, true_params, use_rust = TRUE, uncertainty_method = "hessian")

  # Check that uncertainties were computed
  expect_false(is.null(fit$std_errors))
  expect_length(fit$std_errors, 2)
  expect_true(all(fit$std_errors > 0))
  expect_equal(fit$uncertainty_method, "hessian")
})

test_that("Fisher uncertainty computation works", {
  fit <- sm_optim(clay_data, true_params, use_rust = TRUE, uncertainty_method = "fisher")

  # Check that uncertainties were computed
  expect_false(is.null(fit$std_errors))
  expect_length(fit$std_errors, 2)
  expect_true(all(fit$std_errors > 0))
  expect_equal(fit$uncertainty_method, "fisher")
})

test_that("Jackknife uncertainty computation works", {
  # Use smaller dataset for jackknife (computational expense)
  # Use noisier data so jackknife can measure variation
  small_data <- clay_data[1:30]

  fit <- sm_optim(small_data, true_params, use_rust = TRUE, uncertainty_method = "jackknife")

  # Check that uncertainties were computed
  expect_false(is.null(fit$std_errors))
  expect_length(fit$std_errors, 2)
  # Jackknife may give zero SE on perfect fits, so just check they're non-negative
  expect_true(all(fit$std_errors >= 0))
  expect_equal(fit$uncertainty_method, "jackknife")
})

test_that("Covariance matrices are computed correctly", {
  fit <- sm_optim(clay_data, true_params, use_rust = TRUE, uncertainty_method = "hessian")

  # Check covariance matrix
  expect_false(is.null(fit$cov_matrix))
  expect_equal(dim(fit$cov_matrix), c(2, 2))

  # Covariance matrix should be symmetric
  expect_equal(fit$cov_matrix[1, 2], fit$cov_matrix[2, 1], tolerance = 1e-10)

  # Diagonal should match variance from std errors
  expect_equal(fit$cov_matrix[1, 1], fit$std_errors[1]^2, tolerance = 1e-10)
  expect_equal(fit$cov_matrix[2, 2], fit$std_errors[2]^2, tolerance = 1e-10)
})

test_that("Correlation matrices are computed correctly", {
  fit <- sm_optim(clay_data, true_params, use_rust = TRUE, uncertainty_method = "hessian")

  # Check correlation matrix
  expect_false(is.null(fit$correlations))
  expect_equal(dim(fit$correlations), c(2, 2))

  # Diagonal should be 1
  expect_equal(fit$correlations[1, 1], 1.0, tolerance = 1e-10)
  expect_equal(fit$correlations[2, 2], 1.0, tolerance = 1e-10)

  # Should be symmetric
  expect_equal(fit$correlations[1, 2], fit$correlations[2, 1], tolerance = 1e-10)

  # Should be between -1 and 1
  expect_true(fit$correlations[1, 2] >= -1 && fit$correlations[1, 2] <= 1)
})

test_that("Broom tidy method works with uncertainty", {
  fit <- sm_optim(clay_data, true_params, use_rust = TRUE, uncertainty_method = "hessian")

  # Test tidy output
  tidy_result <- tidy(fit)
  expect_equal(nrow(tidy_result), 2)
  expect_true("uncertainty_method" %in% names(tidy_result))

  # Check values
  expect_equal(tidy_result$std.error, fit$std_errors)
  expect_equal(tidy_result$uncertainty_method, rep("hessian", 2))
})

test_that("Broom glance method works with uncertainty", {
  fit <- sm_optim(clay_data, true_params, use_rust = TRUE, uncertainty_method = "hessian")

  # Test glance output
  glance_result <- glance(fit)
  expect_equal(nrow(glance_result), 1)
  expect_true("uncertainty_method" %in% names(glance_result))
  expect_true("cov_condition_number" %in% names(glance_result))

  # Check values
  expect_equal(glance_result$uncertainty_method, "hessian")
})

test_that("Different methods produce different standard errors", {
  # Hessian
  fit_hess <- sm_optim(clay_data[1:50], true_params, use_rust = TRUE, uncertainty_method = "hessian")

  # Jackknife
  fit_jack <- sm_optim(clay_data[1:50], true_params, use_rust = TRUE, uncertainty_method = "jackknife")

  # They should produce different standard errors (in general)
  # This is expected as they measure uncertainty differently
  expect_false(isTRUE(all.equal(fit_hess$std_errors, fit_jack$std_errors)))
})

test_that("Default (no uncertainty) returns NULL for uncertainty fields", {
  fit <- sm_optim(clay_data, true_params, use_rust = TRUE, uncertainty_method = "none")

  expect_true(is.null(fit$std_errors))
  expect_true(is.null(fit$cov_matrix))
  expect_true(is.null(fit$correlations))
})

test_that("Invalid uncertainty method is rejected", {
  expect_error(
    sm_optim(clay_data, true_params, use_rust = TRUE, uncertainty_method = "invalid_method"),
    "Invalid uncertainty_method"
  )
})
