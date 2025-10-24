# Tests for ggplot2 helper functions
#
# Tests the prepare_ggplot_data and related ggplot2 helper functions.
# These functions require ggplot2 to be installed for testing.

library(soilmotif)

# ============================================================================
# Test data setup
# ============================================================================

# Create test optimization result
create_test_fit <- function() {
  depths <- 1:200
  true_params <- c(40, 60)
  clay_data <- sm_motif(depths, true_params) + rnorm(200, 0, 3)

  fit <- sm_optim(clay_data, c(35, 65), use_rust = TRUE)
  fit
}

# ============================================================================
# Tests for prepare_ggplot_data
# ============================================================================

test_that("prepare_ggplot_data works with ggplot2", {
  skip_if_not_installed("ggplot2")

  fit <- create_test_fit()

  # Test basic functionality
  plot_data <- sm_prepare_ggplot_data(fit)

  # Check structure
  expect_s3_class(plot_data, "data.frame")
  expect_named(plot_data, c("depth", "observed", "fitted", "ci_lower", "ci_upper"))
  expect_equal(nrow(plot_data), 200)

  # Check content
  expect_equal(plot_data$depth, 1:200)
  expect_type(plot_data$observed, "double")
  expect_type(plot_data$fitted, "double")
  expect_true(all(is.na(plot_data$ci_lower)))  # No bootstrap
  expect_true(all(is.na(plot_data$ci_upper)))
})

test_that("prepare_ggplot_data works with bootstrap", {
  skip_if_not_installed("ggplot2")
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
  plot_data <- sm_prepare_ggplot_data(fit, bootstrap_result = boot)

  expect_s3_class(plot_data, "data.frame")
  expect_named(plot_data, c("depth", "observed", "fitted", "ci_lower", "ci_upper"))
  expect_type(plot_data$ci_lower, "double")
  expect_type(plot_data$ci_upper, "double")
  expect_false(all(is.na(plot_data$ci_lower)))
  expect_false(all(is.na(plot_data$ci_upper)))
})

test_that("prepare_ggplot_data handles custom depths", {
  skip_if_not_installed("ggplot2")

  fit <- create_test_fit()
  custom_depths <- seq(1, 200, by = 10)

  plot_data <- sm_prepare_ggplot_data(fit, depths = custom_depths)

  expect_equal(nrow(plot_data), length(custom_depths))
  expect_equal(plot_data$depth, custom_depths)
})

# ============================================================================
# Tests for horizon ggplot helpers (placeholders)
# ============================================================================

test_that("prepare_horizon_ggplot placeholder works", {
  skip_if_not_installed("ggplot2")

  # Should show message and return empty data.frame
  expect_message(
    result <- sm_prepare_horizon_ggplot(NULL),
    "Horizon ggplot2 preparation will be available after Phase 3g implementation"
  )

  expect_s3_class(result, "data.frame")
  expect_named(result, c("horizon_id", "top", "bottom", "label"))
  expect_equal(nrow(result), 0)
})

test_that("prepare_fuzzy_ggplot placeholder works", {
  skip_if_not_installed("ggplot2")

  # Should show message and return empty data.frame
  expect_message(
    result <- sm_prepare_fuzzy_ggplot(NULL),
    "Fuzzy horizon ggplot2 preparation will be available after Phase 3h implementation"
  )

  expect_s3_class(result, "data.frame")
  expect_named(result, c("depth", "horizon", "membership"))
  expect_equal(nrow(result), 0)
})