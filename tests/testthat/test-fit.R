test_that("sm_optim works with all motif types", {
  # Synthetic data with known structure
  x <- c(rep(10, 50), rep(35, 100), rep(15, 50))  # Gradational pattern
  
  # Test each motif type
  motif_types <- c("uniform", "gradational", "exponential", "wetting_front", "abrupt", "peak", "minimax")
  funs <- list(sm_shape_uniform, sm_shape_gradational, 
               sm_shape_exponential, sm_shape_wetting_front,
               sm_shape_abrupt, sm_shape_peak, sm_shape_minimax)
  
  for (i in seq_along(motif_types)) {
    FUN <- funs[[i]]
    motif_type <- motif_types[i]
    initial_par <- .suggest_initial_params(x, motif_type)
    result <- sm_optim(x, initial_par, FUN = FUN)
    
    # Basic checks
    expect_length(result, 200)
    expect_true(all(result >= min(x) & result <= max(x)))
    expect_true(!is.null(attr(result, 'par')))
  }
})

test_that("sm_motif returns consistent output for repeated calls", {
  x <- rnorm(200, mean = 30, sd = 10)
  
  result1 <- sm_motif(x, c(50, 100), FUN = sm_shape_peak)
  result2 <- sm_motif(x, c(50, 100), FUN = sm_shape_peak)
  
  expect_equal(result1, result2)
})

test_that("parameter sorting is conditional", {
  x <- rnorm(200, mean = 30, sd = 10)
  
  # For wetting_front, should sort
  result_wf <- sm_optim(x, c(100, 50), FUN = sm_shape_wetting_front)
  expect_true(attr(result_wf, 'par')[1] <= attr(result_wf, 'par')[2])
  
  # For others, should not force sort
  result_grad <- sm_optim(x, c(35, 10), FUN = sm_shape_gradational)
  # Note: optim may sort internally, but we don't force it
  expect_length(attr(result_grad, 'par'), 2)
})