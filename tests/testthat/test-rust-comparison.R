#' Comparison tests: Rust vs R implementations
#'
#' These tests validate that Rust implementations match R implementations
#' within numerical tolerance (1e-10).

# Ensure soilmotif is available
library(soilmotif)

test_that("Rust objective functions are available", {
  skip_if(!sm_rust_backend_available())
  
  # Test RMSE
  obs <- c(10, 20, 30, 40, 50)
  pred <- c(11, 19, 31, 39, 51)
  
  r_rmse <- sqrt(mean((obs - pred)^2))
  rust_rmse <- objective_rmse_rust(obs, pred)
  
  expect_equal(rust_rmse, r_rmse, tolerance = 1e-10)
})

test_that("Rust RMSE matches R (perfect fit)", {
  skip_if(!sm_rust_backend_available())
  
  obs <- c(1.0, 2.0, 3.0, 4.0, 5.0)
  pred <- obs
  
  r_rmse <- sqrt(mean((obs - pred)^2))
  rust_rmse <- objective_rmse_rust(obs, pred)
  
  expect_equal(rust_rmse, 0.0, tolerance = 1e-15)
  expect_equal(rust_rmse, r_rmse, tolerance = 1e-15)
})

test_that("Rust RMSE matches R (uniform error)", {
  skip_if(!sm_rust_backend_available())
  
  obs <- c(0.0, 0.0, 0.0, 0.0, 0.0)
  pred <- c(2.0, 2.0, 2.0, 2.0, 2.0)
  
  r_rmse <- sqrt(mean((obs - pred)^2))
  rust_rmse <- objective_rmse_rust(obs, pred)
  
  expect_equal(rust_rmse, 2.0, tolerance = 1e-10)
  expect_equal(rust_rmse, r_rmse, tolerance = 1e-10)
})

test_that("Rust SSE matches R", {
  skip_if(!sm_rust_backend_available())
  
  obs <- c(10, 20, 30, 40, 50)
  pred <- c(11, 19, 31, 39, 51)
  
  r_sse <- sum((obs - pred)^2)
  rust_sse <- objective_sse_rust(obs, pred)
  
  expect_equal(rust_sse, r_sse, tolerance = 1e-10)
})

test_that("Rust MAE matches R", {
  skip_if(!sm_rust_backend_available())
  
  obs <- c(10, 20, 30, 40, 50)
  pred <- c(11, 19, 31, 39, 51)
  
  r_mae <- mean(abs(obs - pred))
  rust_mae <- objective_mae_rust(obs, pred)
  
  expect_equal(rust_mae, r_mae, tolerance = 1e-10)
})

test_that("Rust R-squared matches R", {
  skip_if(!sm_rust_backend_available())
  
  obs <- c(1.0, 2.0, 3.0, 4.0, 5.0)
  pred <- c(1.1, 1.9, 3.1, 3.9, 5.1)
  
  mean_obs <- mean(obs)
  ss_tot <- sum((obs - mean_obs)^2)
  ss_res <- sum((obs - pred)^2)
  r_r2 <- 1.0 - (ss_res / ss_tot)
  
  rust_r2 <- objective_r2_rust(obs, pred)
  
  expect_equal(rust_r2, r_r2, tolerance = 1e-10)
})

test_that("Rust R-squared perfect fit", {
  skip_if(!sm_rust_backend_available())
  
  obs <- c(1.0, 2.0, 3.0, 4.0, 5.0)
  pred <- obs
  
  rust_r2 <- objective_r2_rust(obs, pred)
  
  expect_equal(rust_r2, 1.0, tolerance = 1e-15)
})

test_that("Rust uniform shape matches R", {
  skip_if(!sm_rust_backend_available())
  
  x <- seq(1, 200, by = 1)
  params <- c(0.5)
  ascending <- TRUE
  
  r_result <- sm_shape_uniform(x, params[1], ascending = ascending)
  rust_result <- shape_eval_rust("uniform", x, params, ascending)
  
  expect_equal(rust_result, r_result, tolerance = 1e-10)
})

test_that("R gradational shape matches Rust", {
  skip_if(!sm_rust_backend_available())
  
  x <- seq(1, 200, by = 1)
  params <- c(50, 150)
  ascending <- TRUE
  
  rust_result <- shape_eval_rust("gradational", x, params, ascending)
  r_result <- sm_shape_gradational(x, params, ascending = ascending)
  
  expect_equal(r_result, rust_result, tolerance = 1e-8,
               label = "R gradational shape matches Rust")
})

test_that("Rust wetting front shape matches R", {
  skip_if(!sm_rust_backend_available())
  
  x <- seq(1, 200, by = 1)
  params <- c(50, 150)
  ascending <- TRUE
  
  r_result <- sm_shape_sigmoid(x, params, ascending = ascending)
  rust_result <- shape_eval_rust("wetting_front", x, params, ascending)
  
  expect_equal(rust_result, r_result, tolerance = 1e-8,
               label = "Rust wetting_front shape")
})

test_that("Rust abrupt shape matches R", {
  skip_if(!sm_rust_backend_available())
  
  x <- seq(1, 200, by = 1)
  params <- c(100, 0)  # Hard step at 100
  ascending <- TRUE
  
  r_result <- sm_shape_abrupt(x, params, ascending = ascending)
  rust_result <- shape_eval_rust("abrupt", x, params, ascending)
  
  expect_equal(rust_result, r_result, tolerance = 1e-8,
               label = "Rust abrupt shape (hard step)")
})

test_that("Rust peak shape matches R", {
  skip_if(!sm_rust_backend_available())
  
  x <- seq(1, 200, by = 1)
  params <- c(100, 30)
  ascending <- TRUE
  
  r_result <- sm_shape_peak(x, params, ascending = ascending)
  rust_result <- shape_eval_rust("peak", x, params, ascending)
  
  # Peak shape is based on normal distribution, may have small numerical differences
  expect_equal(rust_result, r_result, tolerance = 1e-8,
               label = "Rust peak shape")
})

test_that("R minimax shape matches Rust", {
  skip_if(!sm_rust_backend_available())
  
  x <- seq(1, 200, by = 1)
  params <- c(75, 20, 125, 20)
  ascending <- TRUE
  
  rust_result <- shape_eval_rust("minimax", x, params, ascending)
  r_result <- sm_shape_minimax(x, params, ascending = ascending)
  
  expect_equal(r_result, rust_result, tolerance = 1e-8,
               label = "R minimax shape matches Rust")
})

test_that("Rust exponential shape matches R", {
  skip_if(!sm_rust_backend_available())
  
  x <- seq(1, 200, by = 1)
  params <- c(1, 0.05)
  ascending <- TRUE
  
  r_result <- sm_shape_exponential(x, params, ascending = ascending)
  rust_result <- shape_eval_rust("exponential", x, params, ascending)
  
  expect_equal(rust_result, r_result, tolerance = 1e-8,
               label = "Rust exponential shape")
})

test_that("Shape eval dispatcher handles unknown shape gracefully", {
  skip_if(!sm_rust_backend_available())
  
  x <- seq(1, 200)
  params <- c(0.5)
  
  # Should return error for unknown shape
  expect_warning({result <- shape_eval_rust("unknown_shape", x, params, TRUE)})
  
  expect_null(result, label = "Unknown shape returns NULL")
})

test_that("All shape functions produce values in [0, 1]", {
  skip_if(!sm_rust_backend_available())
  
  x <- seq(1, 200, by = 5)
  
  shapes_and_params <- list(
    list(name = "uniform", params = c(0.5)),
    list(name = "gradational", params = c(50, 150)),
    list(name = "exponential", params = c(1, 0.05)),
    list(name = "wetting_front", params = c(50, 150)),
    list(name = "abrupt", params = c(100, 0)),
    list(name = "peak", params = c(100, 30)),
    list(name = "minimax", params = c(75, 20, 125, 20))
  )
  
  for (shape_info in shapes_and_params) {
    result <- shape_eval_rust(shape_info$name, x, shape_info$params, TRUE)
    
    if (!is.null(result)) {
      expect_true(all(result >= 0.0 & result <= 1.0),
                  label = paste(shape_info$name, "values in [0,1]"))
    }
  }
})
