# Tests for broom method integration
#
# Tests the tidy/glance/augment S3 methods for soilmotif optimization results.
# These methods work without broom installed but integrate when broom is available.

library(soilmotif)

# ============================================================================
# Test data setup
# ============================================================================

# Create test optimization result
create_test_fit <- function() {
  # Create synthetic clay data
  depths <- 1:200
  true_params <- c(40, 60)
  clay_data <- sm_motif(depths, true_params) + rnorm(200, 0, 3)

  # Fit the model
  fit <- sm_optim(clay_data, c(35, 65), use_rust = TRUE)
  fit
}

# Create test bootstrap result
create_test_bootstrap <- function() {
  depths <- 1:200
  true_params <- c(40, 60)
  clay_data <- sm_motif(depths, true_params) + rnorm(200, 0, 3)

  boot <- sm_optim_bootstrap(
    observed = clay_data,
    depths = depths,
    initial_params = c(35, 65),
    shape_family = "sigmoid",
    n_bootstrap = 10  # Small for testing
  )
  boot
}

# ============================================================================
# Tests for optimization result methods
# ============================================================================

test_that("tidy.soilmotif_optimization works", {
  fit <- create_test_fit()

  # Test basic functionality
  tidy_result <- tidy(fit)

  # Check structure
  expect_s3_class(tidy_result, "data.frame")
  expect_named(tidy_result, c("term", "estimate", "std.error", "statistic", "p.value"))
  expect_equal(nrow(tidy_result), 2)  # Two parameters

  # Check content
  expect_equal(tidy_result$term, c("param_1", "param_2"))
  expect_type(tidy_result$estimate, "double")
  expect_true(all(is.na(tidy_result$std.error)))  # No uncertainty for basic fit
  expect_true(all(is.na(tidy_result$statistic)))
  expect_true(all(is.na(tidy_result$p.value)))
})

test_that("glance.soilmotif_optimization works", {
  fit <- create_test_fit()

  # Test basic functionality
  glance_result <- glance(fit)

  # Check structure
  expect_s3_class(glance_result, "data.frame")
  expect_named(glance_result, c("rmse", "r.squared", "nobs", "npar", "aic"))
  expect_equal(nrow(glance_result), 1)

  # Check content
  expect_equal(glance_result$nobs, 200)
  expect_equal(glance_result$npar, 2)
  # Other values may be NA for now (placeholder implementation)
})

test_that("augment.soilmotif_optimization works", {
  fit <- create_test_fit()

  # Test basic functionality
  augment_result <- augment(fit)

  # Check structure
  expect_s3_class(augment_result, "data.frame")
  expect_named(augment_result, c(".depth", ".observed", ".fitted", ".resid"))
  expect_equal(nrow(augment_result), 200)

  # Check content
  expect_equal(augment_result$.depth, 1:200)
  expect_type(augment_result$.observed, "double")
  expect_type(augment_result$.fitted, "double")
  expect_type(augment_result$.resid, "double")
})

test_that("broom methods handle missing parameter info", {
  # Create result with class but missing params
  bad_result <- list(
    fitted = 1:200,
    params = NULL,  # Missing params
    observed = 1:200,
    depths = 1:200,
    shape_family = "sigmoid",
    objective = "rmse",
    algorithm = "auto",
    converged = TRUE,
    message = "Test"
  )
  class(bad_result) <- "soilmotif_optimization"

  expect_error(tidy(bad_result), "Expected object of class")
  expect_error(glance(bad_result), "Expected object of class")
  expect_error(augment(bad_result), "Expected object of class")
})

# ============================================================================
# Tests for bootstrap result methods
# ============================================================================

test_that("tidy.bootstrap_result works", {
  skip_if_not(sm_rust_backend_available(), "Rust backend required for bootstrap")

  boot <- create_test_bootstrap()

  # Test basic functionality
  tidy_result <- tidy(boot)

  # Check structure
  expect_s3_class(tidy_result, "data.frame")
  expect_named(tidy_result, c("term", "estimate", "std.error", "statistic", "p.value", "conf.low", "conf.high"))
  expect_equal(nrow(tidy_result), 2)  # Two parameters

  # Check content
  expect_equal(tidy_result$term, c("param_1", "param_2"))
  expect_type(tidy_result$estimate, "double")
  expect_type(tidy_result$std.error, "double")
  expect_type(tidy_result$statistic, "double")
  expect_type(tidy_result$p.value, "double")
  expect_type(tidy_result$conf.low, "double")
  expect_type(tidy_result$conf.high, "double")

  # Check confidence intervals make sense
  expect_true(all(tidy_result$conf.low <= tidy_result$estimate))
  expect_true(all(tidy_result$estimate <= tidy_result$conf.high))
})

test_that("glance.bootstrap_result works", {
  skip_if_not(sm_rust_backend_available(), "Rust backend required for bootstrap")

  boot <- create_test_bootstrap()

  # Test basic functionality
  glance_result <- glance(boot)

  # Check structure
  expect_s3_class(glance_result, "data.frame")
  expect_named(glance_result, c("n_bootstrap", "n_successful", "n_failed", "success_rate",
                                "method_used", "ar1_coef", "ar1_sigma2", "rmse_mean", "rmse_sd",
                                "r2_mean", "r2_sd", "aic_mean", "aic_sd"))
  expect_equal(nrow(glance_result), 1)

  # Check content
  expect_equal(glance_result$n_bootstrap, 10)
  expect_type(glance_result$n_successful, "integer")
  expect_type(glance_result$success_rate, "double")
  expect_true(glance_result$success_rate >= 0 && glance_result$success_rate <= 1)
})

test_that("augment.bootstrap_result works", {
  skip_if_not(sm_rust_backend_available(), "Rust backend required for bootstrap")

  boot <- create_test_bootstrap()

  # Test basic functionality
  augment_result <- augment(boot)

  # Check structure
  expect_s3_class(augment_result, "data.frame")
  expect_named(augment_result, c(".depth", ".fitted", ".lower", ".upper"))
  expect_equal(nrow(augment_result), 200)  # Same as original depths

  # Check content
  expect_equal(augment_result$.depth, 1:200)
  expect_type(augment_result$.fitted, "double")
  # Note: .lower and .upper may be NA in current placeholder implementation
})

test_that("bootstrap methods handle empty results", {
  # Create empty bootstrap result
  empty_boot <- list(
    param_samples = matrix(numeric(0), 0, 2),
    settings = list(n_bootstrap = 10)
  )
  class(empty_boot) <- "bootstrap_result"

  expect_error(tidy(empty_boot), "No successful bootstrap samples found")
  expect_error(augment(empty_boot), "No successful bootstrap samples found")
})

# ============================================================================
# Integration tests (require broom if available)
# ============================================================================

test_that("broom methods work with broom package", {
  skip_if_not_installed("broom")

  fit <- create_test_fit()

  # These should work identically with or without broom loaded
  tidy_result <- tidy(fit)
  glance_result <- glance(fit)
  augment_result <- augment(fit)

  # Check that results are data.frames (not tibbles, to maintain base R compatibility)
  expect_s3_class(tidy_result, "data.frame")
  expect_s3_class(glance_result, "data.frame")
  expect_s3_class(augment_result, "data.frame")

  # Verify no tibble conversion
  expect_false(inherits(tidy_result, "tbl_df"))
  expect_false(inherits(glance_result, "tbl_df"))
  expect_false(inherits(augment_result, "tbl_df"))
})

# ============================================================================
# Error handling and edge cases
# ============================================================================

test_that("methods handle edge cases gracefully", {
  # Single parameter fit - use R implementation to avoid Rust edge case issues
  single_param_data <- rep(40, 100)

  # Fit constant data - should complete without warnings (improved behavior)
  single_fit <- sm_optim(single_param_data, 40, use_rust = FALSE)

  tidy_single <- tidy(single_fit)

  expect_equal(nrow(tidy_single), 1)
  expect_equal(tidy_single$term, "param_1")

  # Very small dataset - use R implementation to avoid Rust edge case issues
  small_data <- c(10, 20, 30)
  small_fit <- sm_optim(small_data, c(15, 25), use_rust = FALSE)

  tidy_small <- tidy(small_fit)
  expect_equal(nrow(tidy_small), 2)
  expect_equal(tidy_small$term, c("param_1", "param_2"))
})
