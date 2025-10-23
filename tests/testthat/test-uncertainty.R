library(testthat)
library(soilmotif)

# Test data - use fixed seed for reproducibility
set.seed(42)
test_depths <- 1:200
test_params <- c(100, 20, 0.1, 50)
test_observed <- sm_motif(test_depths, test_params) + rnorm(200, 0, 2)

context("Parametric Bootstrap Uncertainty Quantification")

test_that("sm_optim_bootstrap basic functionality", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  result <- sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    n_bootstrap = 10  # Small for speed
  )

  expect_s3_class(result, "bootstrap_result")
  expect_true(is.matrix(result$param_samples))
  expect_equal(ncol(result$param_samples), length(test_params))
  expect_true(result$n_successful <= 10)
  expect_equal(result$n_successful + result$n_failed, 10)
  expect_true(is.list(result$summary))
  expect_true(is.list(result$settings))
})

test_that("sm_optim_bootstrap input validation", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  # Test missing arguments
  expect_error(sm_optim_bootstrap(), "argument \"observed\" is missing")

  # Test invalid observed
  expect_error(sm_optim_bootstrap(
    observed = "not numeric",
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid"
  ), "observed must be a numeric vector")

  # Test mismatched lengths
  expect_error(sm_optim_bootstrap(
    observed = test_observed[1:10],
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid"
  ), "observed and depths must have the same length")

  # Test invalid shape family
  expect_error(sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "invalid_shape"
  ), "shape_family must be one of")

  # Test invalid objective
  expect_error(sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    objective = "invalid_objective"
  ), "objective must be one of")

  # Test invalid optimizer
  expect_error(sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    optimizer = "invalid_optimizer"
  ), "optimizer must be one of")

  # Test invalid n_bootstrap
  expect_error(sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    n_bootstrap = -1
  ), "n_bootstrap must be a positive integer")

  # Test invalid seed
  expect_error(sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    seed = "not numeric"
  ), "seed must be NULL or a single integer")

  # Test invalid fallback_strategy
  expect_error(sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    fallback_strategy = "invalid"
  ), "fallback_strategy must be one of")

  # Test invalid max_retries
  expect_error(sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    max_retries = -1
  ), "max_retries must be a non-negative integer")

  # Test invalid parallel
  expect_error(sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    parallel = "not logical"
  ), "parallel must be a single logical value")
})

test_that("sm_optim_bootstrap reproducibility with seed", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  result1 <- sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    n_bootstrap = 5,
    seed = 123
  )

  result2 <- sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    n_bootstrap = 5,
    seed = 123
  )

  # Results should be identical with same seed
  expect_equal(result1$param_samples, result2$param_samples)
  expect_equal(result1$rmse_samples, result2$rmse_samples)
  expect_equal(result1$r2_samples, result2$r2_samples)
  expect_equal(result1$aic_samples, result2$aic_samples)
  expect_equal(result1$failed_indices, result2$failed_indices)
})

test_that("sm_optim_bootstrap different seed gives different results", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  result1 <- sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    n_bootstrap = 10,
    seed = 123
  )

  result2 <- sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    n_bootstrap = 10,
    seed = 456
  )

  # Results should be different with different seeds
  expect_false(identical(result1$param_samples, result2$param_samples))
})

test_that("sm_optim_bootstrap parallel vs sequential", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  result_parallel <- sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    n_bootstrap = 5,
    seed = 123,
    parallel = TRUE
  )

  result_sequential <- sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    n_bootstrap = 5,
    seed = 123,
    parallel = FALSE
  )

  # Both should produce valid results with same structure
  expect_s3_class(result_parallel, "bootstrap_result")
  expect_s3_class(result_sequential, "bootstrap_result")
  expect_equal(nrow(result_parallel$param_samples), result_parallel$n_successful)
  expect_equal(nrow(result_sequential$param_samples), result_sequential$n_successful)
  
  # Both should have same number of samples (same n_bootstrap)
  expect_equal(length(result_parallel$rmse_samples), length(result_sequential$rmse_samples))
  expect_equal(length(result_parallel$r2_samples), length(result_sequential$r2_samples))
  expect_equal(length(result_parallel$aic_samples), length(result_sequential$aic_samples))
  
  # Summary statistics should be similar but not identical due to rayon scheduling
  # Just verify they're computed and have sensible values
  expect_true(all(!is.na(result_parallel$summary$param_mean)))
  expect_true(all(!is.na(result_sequential$summary$param_mean)))
  expect_true(all(result_parallel$summary$param_sd >= 0, na.rm = TRUE))
  expect_true(all(result_sequential$summary$param_sd >= 0, na.rm = TRUE))
})

test_that("sm_optim_bootstrap different shape families", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  shapes <- c("uniform", "gradational", "exponential", "sigmoid", "abrupt", "peak")

  for (shape in shapes) {
    # Adjust params for shape
    params <- switch(shape,
      "uniform" = c(0.5),
      "gradational" = c(20, 80),
      "exponential" = c(100, 0.01),
      "sigmoid" = c(100, 20, 0.1, 50),
      "abrupt" = c(20, 80, 100),
      "peak" = c(20, 100, 150, 80)
    )

    # Create observed data using the matching shape function
    shape_fun <- switch(shape,
      "uniform" = sm_shape_uniform,
      "gradational" = sm_shape_gradational,
      "exponential" = sm_shape_exponential,
      "sigmoid" = sm_shape_sigmoid,
      "abrupt" = sm_shape_abrupt,
      "peak" = sm_shape_peak
    )
    
    observed <- sm_motif(test_depths, params, FUN = shape_fun) + rnorm(200, 0, 1)

    result <- sm_optim_bootstrap(
      observed = observed,
      depths = test_depths,
      initial_params = params,
      shape_family = shape,
      n_bootstrap = 3
    )

    expect_s3_class(result, "bootstrap_result")
    expect_equal(ncol(result$param_samples), length(params))
  }
})

test_that("sm_optim_bootstrap different objectives", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  objectives <- c("rmse", "sse", "mae", "r2")

  for (obj in objectives) {
    result <- sm_optim_bootstrap(
      observed = test_observed,
      depths = test_depths,
      initial_params = test_params,
      shape_family = "sigmoid",
      objective = obj,
      n_bootstrap = 3
    )

    expect_s3_class(result, "bootstrap_result")
  }
})

test_that("sm_optim_bootstrap fallback strategies", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  strategies <- c("auto", "explicit", "strict")

  for (strategy in strategies) {
    result <- sm_optim_bootstrap(
      observed = test_observed,
      depths = test_depths,
      initial_params = test_params,
      shape_family = "sigmoid",
      fallback_strategy = strategy,
      n_bootstrap = 3
    )

    expect_s3_class(result, "bootstrap_result")
  }
})

test_that("sm_optim_bootstrap handles failed optimizations", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  # Use very poor initial params to potentially cause failures
  bad_params <- c(1000, 1000, 10, 1000)

  result <- sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = bad_params,
    shape_family = "sigmoid",
    n_bootstrap = 5,
    max_retries = 1  # Limit retries to increase failure chance
  )

  expect_s3_class(result, "bootstrap_result")
  expect_true(result$n_failed >= 0)
  expect_equal(result$n_successful + result$n_failed, 5)
})

test_that("sm_optim_bootstrap summary statistics", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  result <- sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    n_bootstrap = 10
  )

  summary <- result$summary

  expect_true(is.list(summary))
  expect_true(all(c("param_mean", "param_sd", "param_ci_lower", "param_ci_upper",
                   "rmse_mean", "rmse_sd", "r2_mean", "r2_sd", "aic_mean", "aic_sd") %in% names(summary)))

  if (result$n_successful > 0) {
    expect_true(all(is.finite(summary$param_mean)))
    expect_true(all(summary$param_sd >= 0))
    expect_true(all(summary$param_ci_lower <= summary$param_ci_upper))
  }
})

test_that("sm_optim_bootstrap print method", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  result <- sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    n_bootstrap = 5
  )

  # Should not error
  expect_output(print(result), "Parametric Bootstrap Results")
})

test_that("sm_optim_bootstrap summary method", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  result <- sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    n_bootstrap = 5
  )

  summary <- summary(result)
  expect_true(is.list(summary))
  expect_equal(names(summary), names(result$summary))
})

test_that("sm_optim_bootstrap edge cases", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  # Minimal data
  tiny_observed <- c(10, 20)
  tiny_depths <- c(1, 2)
  tiny_params <- c(15)

  result <- sm_optim_bootstrap(
    observed = tiny_observed,
    depths = tiny_depths,
    initial_params = tiny_params,
    shape_family = "uniform",
    n_bootstrap = 3
  )

  expect_s3_class(result, "bootstrap_result")

  # Large n_bootstrap (but small for testing)
  result <- sm_optim_bootstrap(
    observed = test_observed,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid",
    n_bootstrap = 20,
    parallel = TRUE
  )

  expect_s3_class(result, "bootstrap_result")
})

test_that("sm_optim_bootstrap NA handling", {
  skip_if_not(rust_backend_available(), "Rust backend not available")

  # Test NA in observed
  observed_na <- test_observed
  observed_na[10] <- NA

  expect_error(sm_optim_bootstrap(
    observed = observed_na,
    depths = test_depths,
    initial_params = test_params,
    shape_family = "sigmoid"
  ), "cannot contain NA values")

  # Test NA in depths
  depths_na <- test_depths
  depths_na[10] <- NA

  expect_error(sm_optim_bootstrap(
    observed = test_observed,
    depths = depths_na,
    initial_params = test_params,
    shape_family = "sigmoid"
  ), "cannot contain NA values")
})