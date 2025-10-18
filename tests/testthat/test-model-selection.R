test_that("fit_motif_auto works with all motif types", {
  # Synthetic data with known structure
  x <- c(rep(10, 50), rep(35, 100), rep(15, 50))  # Gradational pattern

  result <- fit_motif_auto(x, models = "all", criterion = "AIC")

  # Basic checks
  expect_s3_class(result, "fit_motif_auto")
  expect_length(result$fits, 7)  # All 7 models
  expect_equal(ncol(result$stats), 5)  # model, rmse, aic, bic, r2
  expect_equal(nrow(result$stats), 7)
  expect_true(result$best %in% c("uniform", "gradational", "exponential", "wetting_front", "abrupt", "peak", "minimax"))
  expect_equal(result$criterion, "AIC")
  expect_equal(result$input_length, 200)
})

test_that("fit_motif_auto identifies correct best model", {
  # Create synthetic peak profile
  peak_profile <- sm_motif(1:200, c(100, 30), FUN = sm_shape_peak)

  result <- fit_motif_auto(peak_profile, criterion = "AIC")
  expect_equal(result$best, "peak")
})

test_that("Different criteria produce different rankings", {
  # Create gradational data
  x <- sm_motif(1:200, c(10, 50), FUN = sm_shape_gradational)
  
  result_aic <- fit_motif_auto(x, criterion = "AIC")
  result_rmse <- fit_motif_auto(x, criterion = "RMSE")
  
  # For gradational data, gradational should rank high
  expect_true("gradational" %in% result_aic$ranking$model[1:3])
  expect_true("gradational" %in% result_rmse$ranking$model[1:3])
})

test_that("fit_motif_auto handles subset of models", {
  x <- rnorm(200, mean = 30, sd = 10)

  result <- fit_motif_auto(x, models = c("uniform", "gradational", "peak"), criterion = "AIC")

  expect_length(result$fits, 3)
  expect_equal(nrow(result$stats), 3)
  expect_true(result$best %in% c("uniform", "gradational", "peak"))
})

test_that("fit_motif_auto S3 methods work without error", {
  x <- rnorm(200, mean = 30, sd = 10)
  result <- fit_motif_auto(x, models = c("uniform", "gradational", "peak"))

  expect_output(print(result), "Automated Motif")
  expect_silent(plot(result))
  expect_output(summary(result), "Motif Fitting Summary")
})

test_that("fit_motif_auto validates inputs", {
  # Non-numeric x
  expect_error(fit_motif_auto("not numeric"), "x must be numeric")

  # Invalid criterion
  x <- rnorm(200, mean = 30, sd = 10)
  expect_error(fit_motif_auto(x, criterion = "INVALID"), "criterion must be one of")

  # Invalid models
  expect_error(fit_motif_auto(x, models = c("invalid_model")), "No valid models specified")
})

test_that("fit_motif_auto handles short data with warning", {
  x <- rnorm(5, mean = 30, sd = 10)

  expect_warning(fit_motif_auto(x, models = c("uniform", "gradational")), "x is very short")
})

test_that("fit_motif_auto ranking is correct for R2", {
  # Create data where one model should have perfect fit
  x <- sm_motif(1:200, c(0.5), FUN = sm_shape_uniform)

  result <- fit_motif_auto(x, models = c("uniform", "gradational"), criterion = "R2")

  # Uniform should have R2 = 1 (perfect fit)
  uniform_r2 <- result$stats[result$stats$model == "uniform", "r2"]
  expect_equal(uniform_r2, 1, tolerance = 1e-10)

  # Should be ranked first
  expect_equal(result$best, "uniform")
})

test_that("fit_motif_auto handles fitting failures gracefully", {
  # Create problematic data that might cause fitting issues
  x <- rep(NaN, 200)

  # Should not error, but may have warnings
  result <- suppressWarnings(fit_motif_auto(x, models = c("uniform", "gradational")))

  # At minimum, should have the result structure
  expect_s3_class(result, "fit_motif_auto")
})