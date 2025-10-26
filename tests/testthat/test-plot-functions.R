# Tests for base R plotting functions
#
# Tests the plot.soilmotif_optimization and related plotting functions.
# These functions provide base R visualization without external dependencies.

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

# ============================================================================
# Tests for plot.soilmotif_optimization
# ============================================================================

test_that("plot.soilmotif_optimization works", {
  fit <- create_test_fit()

  # Test that plotting doesn't error
  expect_silent(plot(fit))

  # Test with custom parameters
  expect_silent(plot(fit, col = "red", main = "Test Plot", xlab = "Clay %", ylab = "Depth"))

  # Test xlim/ylim parameters
  expect_silent(plot(fit, xlim = c(0, 100), ylim = c(200, 0)))
})

test_that("plot handles missing parameter info", {
  # Create result without proper attributes
  bad_result <- structure(1:200, class = "soilmotif_optimization")

  expect_error(plot(bad_result), "Expected object of class")
})

test_that("extract_plot_data works", {
  fit <- create_test_fit()

  # Test basic functionality
  plot_data <- sm_extract_plot_data(fit)

  # Check structure
  expect_s3_class(plot_data, "data.frame")
  expect_named(plot_data, c("depth", "observed", "fitted", "ci_lower", "ci_upper"))
  expect_equal(nrow(plot_data), 200)

  # Check content
  expect_equal(plot_data$depth, 1:200)
  expect_equal(plot_data$fitted, fit$fitted)
  expect_type(plot_data$observed, "double")
  # CI bounds may be NA without bootstrap
  expect_true(all(is.na(plot_data$ci_lower)))
  expect_true(all(is.na(plot_data$ci_upper)))
})

test_that("extract_plot_data handles custom depths", {
  fit <- create_test_fit()

  custom_depths <- seq(1, 200, by = 5)
  plot_data <- sm_extract_plot_data(fit, depths = custom_depths)

  expect_equal(nrow(plot_data), length(custom_depths))
  expect_equal(plot_data$depth, custom_depths)
})

# ============================================================================
# Tests for placeholder horizon plotting functions
# ============================================================================

test_that("plot_horizon_boundaries placeholder works", {
  # Should not error, just show message
  expect_message(
    sm_plot_horizon_boundaries(NULL),
    "Horizon boundary plotting will be available after Phase 3g implementation"
  )
})

test_that("plot_fuzzy_horizons placeholder works", {
  # Should not error, just show message
  expect_message(
    sm_plot_fuzzy_horizons(NULL),
    "Fuzzy horizon plotting will be available after Phase 3h implementation"
  )
})

# ============================================================================
# Integration with bootstrap (when available)
# ============================================================================

test_that("plot works with bootstrap results", {
  skip_if_not(sm_rust_backend_available(), "Rust backend required for bootstrap")

  fit <- create_test_fit()
  depths <- 1:200
  clay_data <- sm_motif(depths, c(40, 60)) + rnorm(200, 0, 3)

  # Create bootstrap result
  boot <- sm_optim_bootstrap(
    observed = clay_data,
    depths = depths,
    initial_params = c(35, 65),
    shape_family = "sigmoid",
    n_bootstrap = 5  # Small for testing
  )

  # Test plotting with bootstrap
  expect_silent(plot(fit, bootstrap_result = boot))
})

test_that("extract_plot_data works with bootstrap", {
  skip_if_not(sm_rust_backend_available(), "Rust backend required for bootstrap")

  fit <- create_test_fit()
  depths <- 1:200
  clay_data <- sm_motif(depths, c(40, 60)) + rnorm(200, 0, 3)

  boot <- sm_optim_bootstrap(
    observed = clay_data,
    depths = depths,
    initial_params = c(35, 65),
    shape_family = "sigmoid",
    n_bootstrap = 5
  )

  # Test with bootstrap
  plot_data <- sm_extract_plot_data(fit, bootstrap_result = boot)

  expect_s3_class(plot_data, "data.frame")
  expect_named(plot_data, c("depth", "observed", "fitted", "ci_lower", "ci_upper"))
  # CI bounds should be populated (even if placeholder implementation)
  expect_type(plot_data$ci_lower, "double")
  expect_type(plot_data$ci_upper, "double")
})

# ============================================================================
# Visual output validation (basic checks)
# ============================================================================

test_that("plot_bootstrap_params works", {
  skip_if_not(sm_rust_backend_available(), "Rust backend required for bootstrap")

  fit <- create_test_fit()
  depths <- 1:200
  clay_data <- sm_motif(depths, c(40, 60)) + rnorm(200, 0, 3)

  boot <- sm_optim_bootstrap(
    observed = clay_data,
    depths = depths,
    initial_params = c(35, 65),
    shape_family = "sigmoid",
    n_bootstrap = 10
  )

  # Test histogram plot
  expect_silent(sm_plot_bootstrap_params(boot, type = "histogram"))

  # Test density plot
  expect_silent(sm_plot_bootstrap_params(boot, type = "density"))

  # Test invalid type
  expect_error(sm_plot_bootstrap_params(boot, type = "invalid"), "type must be")
})

test_that("plot_bootstrap_params handles empty results", {
  empty_boot <- list(
    param_samples = matrix(numeric(0), 0, 2),
    n_successful = 0
  )
  class(empty_boot) <- "bootstrap_result"

  expect_error(sm_plot_bootstrap_params(empty_boot), "No successful bootstrap samples")
})

test_that("plot_residuals works", {
  fit <- create_test_fit()

  # Test residual plotting
  expect_silent(sm_plot_residuals(fit))
})

test_that("plot_residuals handles edge cases", {
  # Create a perfect fit (zero residuals)
  perfect_data <- sm_motif(1:200, c(40, 60))
  perfect_fit <- sm_optim(perfect_data, c(40, 60), use_rust = TRUE)

  expect_silent(sm_plot_residuals(perfect_fit))
})