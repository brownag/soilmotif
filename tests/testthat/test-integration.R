test_that("Full workflow: raw data → preprocess → fit → select model", {
  # Create raw horizon data
  data <- data.frame(
    id = c("P1", "P1", "P1", "P2", "P2"),
    top = c(0, 20, 50, 0, 30),
    bottom = c(20, 50, 100, 30, 100),
    clay = c(10, 30, 25, 15, 35),
    sand = c(80, 60, 65, 75, 55)
  )

  # 1. Preprocess
  prep <- sm_prepare(data, property = "clay", method = "step")
  expect_type(prep, "list")
  expect_named(prep, "clay")
  expect_length(prep$clay, 2)  # Two profiles

  # 2. Fit motif
  x <- prep$clay$P1
  fit <- sm_motif(x, c(50, 100), FUN = sm_shape_peak)
  expect_length(fit, 200)
  expect_true(all(fit >= min(x) & fit <= max(x)))

  # 3. Select model
  result <- fit_motif_auto(x, models = c("uniform", "gradational", "peak"), criterion = "AIC")
  expect_s3_class(result, "fit_motif_auto")
  expect_named(result, c("fits", "stats", "ranking", "best", "criterion", "input_length"))
  expect_type(result$best, "character")
  expect_true(result$best %in% c("uniform", "gradational", "peak"))
})

test_that("Multiple profiles handled consistently", {
  # Create 3 synthetic profiles
  profiles <- list()
  for (i in 1:3) {
    # Create different patterns
    if (i == 1) x <- rep(25, 200)  # Uniform
    if (i == 2) x <- seq(10, 40, length.out = 200)  # Gradational
    if (i == 3) x <- c(rep(15, 80), rep(35, 40), rep(20, 80))  # Peak-like

    profiles[[paste0("P", i)]] <- x
  }

  # Fit each
  results <- lapply(profiles, function(x) {
    fit_motif_auto(x, models = "all", criterion = "AIC")
  })

  # Check consistency
  expect_length(results, 3)
  for (result in results) {
    expect_s3_class(result, "fit_motif_auto")
    expect_type(result$best, "character")
  }

  # Different profiles should potentially have different best models
  best_models <- sapply(results, `[[`, "best")
  expect_true(length(unique(best_models)) >= 1)  # At least one unique model
  expect_true(all(best_models %in% c("uniform", "gradational", "exponential", "wetting_front", "abrupt", "peak", "minimax")))
})

test_that("Integration with sm_optim and sm_motif", {
  # Create synthetic peak data
  x <- sm_motif(1:200, c(100, 30), FUN = sm_shape_peak)

  # Optimize
  opt_result <- sm_optim(x, c(80, 40), FUN = sm_shape_peak)
  expect_length(opt_result, 200)
  expect_true(!is.null(attr(opt_result, 'par')))

  # Compare with original parameters
  fitted_par <- attr(opt_result, 'par')
  expect_length(fitted_par, 2)
  expect_true(abs(fitted_par[1] - 100) < 20)  # Should be close to original
  expect_true(abs(fitted_par[2] - 30) < 10)
})

test_that("Cross-compatibility: preprocess output works with all fitting functions", {
  # Create horizon data
  data <- data.frame(
    id = "P1",
    top = c(0, 50, 100),
    bottom = c(50, 100, 200),
    clay = c(10, 30, 20)
  )

  # Preprocess with different methods
  methods <- c("step", "linear")
  for (method in methods) {
    prep <- sm_prepare(data, property = "clay", method = method)
    x <- prep$clay$P1

    # Should work with sm_motif
    fit <- sm_motif(x, c(50, 100), FUN = sm_shape_gradational)
    expect_length(fit, 200)

    # Should work with fit_motif_auto
    result <- fit_motif_auto(x, models = c("uniform", "gradational"), criterion = "RMSE")
    expect_s3_class(result, "fit_motif_auto")
  }
})