# Tests for Bayesian integration functions
#
# Tests the sm_to_priors and related Bayesian helper functions.
# These functions work without Bayesian packages installed.

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
    n_bootstrap = 10
  )
  boot
}

# ============================================================================
# Tests for sm_to_priors
# ============================================================================

test_that("sm_to_priors works with optimization result", {
  fit <- create_test_fit()

  expect_warning(
    priors <- sm_to_priors(fit),
    "No parameter uncertainty available"
  )

  # Check structure
  expect_type(priors, "list")
  expect_named(priors, c("parameters", "location", "scale", "distribution", "note"))

  # Check content
  expect_equal(priors$parameters, c("param_1", "param_2"))
  expect_equal(length(priors$location), 2)
  expect_equal(length(priors$scale), 2)
  expect_equal(priors$distribution, "normal")
  expect_type(priors$note, "character")

  # Check that scale is reasonable (based on coefficient of variation)
  expect_true(all(priors$scale > 0))
  expect_true(all(priors$scale < abs(priors$location) * 0.5))  # Less than 50% CV
})

test_that("sm_to_priors works with bootstrap result", {
  skip_if_not(rust_backend_available(), "Rust backend required for bootstrap")

  boot <- create_test_bootstrap()

  priors <- sm_to_priors(boot)

  # Check structure
  expect_type(priors, "list")
  expect_named(priors, c("parameters", "location", "scale", "distribution", "note"))

  # Check content
  expect_equal(priors$parameters, c("param_1", "param_2"))
  expect_equal(length(priors$location), 2)
  expect_equal(length(priors$scale), 2)
  expect_equal(priors$distribution, "normal")

  # Check that scale is based on bootstrap SD
  expect_true(all(priors$scale > 0))
})

test_that("sm_to_priors handles prior_sd_factor", {
  skip_if_not(rust_backend_available(), "Rust backend required for bootstrap")

  boot <- create_test_bootstrap()

  # Test different prior_sd_factor values
  priors_05 <- sm_to_priors(boot, prior_sd_factor = 0.5)
  priors_10 <- sm_to_priors(boot, prior_sd_factor = 1.0)
  priors_20 <- sm_to_priors(boot, prior_sd_factor = 2.0)

  # Scale should be proportional to prior_sd_factor
  expect_equal(priors_10$scale, priors_05$scale * 2)
  expect_equal(priors_20$scale, priors_05$scale * 4)
})

test_that("sm_to_priors handles invalid input", {
  expect_error(sm_to_priors("not a result"), "must be a soilmotif_optimization or bootstrap_result object")

  # Empty bootstrap result
  empty_boot <- list(param_samples = matrix(numeric(0), 0, 2), n_successful = 0)
  class(empty_boot) <- "bootstrap_result"
  expect_error(sm_to_priors(empty_boot), "No successful bootstrap samples found")
})

# ============================================================================
# Tests for sm_to_brms_priors
# ============================================================================

test_that("sm_to_brms_priors works", {
  fit <- create_test_fit()

  expect_warning(
    prior_strings <- sm_to_brms_priors(fit),
    "No parameter uncertainty available"
  )

  # Check structure
  expect_type(prior_strings, "character")
  expect_length(prior_strings, 2)

  # Check format (should be brms prior strings)
  expect_match(prior_strings[1], "prior\\(normal\\(.*\\), coef = 'b_param_1'\\)")
  expect_match(prior_strings[2], "prior\\(normal\\(.*\\), coef = 'b_param_2'\\)")
})

test_that("sm_to_brms_priors handles custom prefix", {
  fit <- create_test_fit()

  expect_warning(
    prior_strings <- sm_to_brms_priors(fit, prefix = ""),
    "No parameter uncertainty available"
  )

  expect_match(prior_strings[1], "coef = 'param_1'")
  expect_match(prior_strings[2], "coef = 'param_2'")
})

# ============================================================================
# Tests for sm_to_stan_priors
# ============================================================================

test_that("sm_to_stan_priors works", {
  fit <- create_test_fit()

  expect_warning(
    stan_code <- sm_to_stan_priors(fit),
    "No parameter uncertainty available"
  )

  # Check structure
  expect_type(stan_code, "character")
  expect_length(stan_code, 1)  # Single string with newlines

  # Check format (should be Stan prior statements)
  lines <- strsplit(stan_code, "\n")[[1]]
  expect_length(lines, 2)
  expect_match(lines[1], "param_1 ~ normal\\(.*\\);")
  expect_match(lines[2], "param_2 ~ normal\\(.*\\);")
})

test_that("sm_to_stan_priors handles custom parameter names", {
  fit <- create_test_fit()

  expect_warning(
    stan_code <- sm_to_stan_priors(fit, param_names = c("beta1", "beta2")),
    "No parameter uncertainty available"
  )

  lines <- strsplit(stan_code, "\n")[[1]]
  expect_match(lines[1], "beta1 ~ normal\\(.*\\);")
  expect_match(lines[2], "beta2 ~ normal\\(.*\\);")
})

test_that("sm_to_stan_priors validates parameter names", {
  fit <- create_test_fit()

  expect_warning(
    expect_error(
      sm_to_stan_priors(fit, param_names = c("beta1")),  # Wrong length
      "param_names must have the same length"
    ),
    "No parameter uncertainty available"
  )
})

# ============================================================================
# Integration tests
# ============================================================================

test_that("Bayesian functions work with bootstrap uncertainty", {
  skip_if_not(rust_backend_available(), "Rust backend required for bootstrap")

  boot <- create_test_bootstrap()

  # All functions should work
  priors <- sm_to_priors(boot)
  brms_priors <- sm_to_brms_priors(boot)
  stan_priors <- sm_to_stan_priors(boot)

  expect_type(priors, "list")
  expect_type(brms_priors, "character")
  expect_type(stan_priors, "character")

  # Check that bootstrap provides more realistic priors
  expect_true(all(priors$scale > 0))  # Should have meaningful uncertainty
})

test_that("Bayesian functions provide reasonable prior widths", {
  fit <- create_test_fit()

  expect_warning(
    priors <- sm_to_priors(fit),
    "No parameter uncertainty available"
  )

  # For optimization results, priors should be reasonably wide
  # but not ridiculously so
  cv <- priors$scale / abs(priors$location)
  expect_true(all(cv > 0.1))  # At least 10% CV
  expect_true(all(cv < 1.0))  # Less than 100% CV
})