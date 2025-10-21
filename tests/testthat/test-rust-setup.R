test_that("Rust backend loads and is callable", {
  # This will fail until we implement check_rust_backend in 2.B
  # For now, it documents the expected behavior
  skip("Rust backend not yet fully implemented")
  
  result <- tryCatch({
    .Call("check_rust_backend", PACKAGE = "soilmotif")
  }, error = function(e) {
    NA_character_
  })
  
  expect_equal(result, "Rust backend available")
})

test_that("sm_optim still works with use_rust = FALSE", {
  x <- c(rep(10, 50), rep(35, 100), rep(15, 50))
  result <- sm_optim(x, c(25, 100), FUN = sm_shape_gradational, use_rust = FALSE)
  
  expect_length(result, 200)
  expect_true(all(result >= 0))
})
