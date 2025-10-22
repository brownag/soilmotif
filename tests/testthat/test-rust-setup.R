test_that("Rust backend loads and is callable", {
  # Test that the Rust backend is available and callable
  expect_true(rust_backend_available())
  
  # Test basic functionality by calling a working Rust function
  x <- c(1.0, 2.0, 3.0)
  y <- c(1.1, 1.9, 3.1)
  result <- objective_rmse_rust(x, y)
  
  # Should return a finite numeric value
  expect_type(result, "double")
  expect_true(is.finite(result))
  expect_true(result > 0)
})

test_that("sm_optim still works with use_rust = FALSE", {
  x <- c(rep(10, 50), rep(35, 100), rep(15, 50))
  result <- sm_optim(x, c(25, 100), FUN = sm_shape_gradational, use_rust = FALSE)
  
  expect_length(result, 200)
  expect_true(all(result >= 0))
})
