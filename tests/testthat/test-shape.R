test_that("test shape sigmoid", {
  res <- sm_shape_sigmoid(0:100, c(20, 50))
  expect_equal(length(res), 101)
  expect_equal(c(res[19], res[36], res[51]), c(0, 0.5, 1))
})

test_that("All shape functions return numeric [0,1] vectors", {
  x <- 1:200
  expect_equal(length(sm_shape_uniform(x, c(0.5))), 200)
  expect_true(all(sm_shape_uniform(x, c(0.5)) >= 0 & sm_shape_uniform(x, c(0.5)) <= 1))
  
  expect_equal(length(sm_shape_gradational(x, c(0.2, 0.8))), 200)
  expect_true(all(sm_shape_gradational(x, c(0.2, 0.8)) >= 0 & sm_shape_gradational(x, c(0.2, 0.8)) <= 1))
  
  expect_equal(length(sm_shape_exponential(x, c(1, 0.01))), 200)
  expect_true(all(sm_shape_exponential(x, c(1, 0.01)) >= 0 & sm_shape_exponential(x, c(1, 0.01)) <= 1))
  
  expect_equal(length(sm_shape_wetting_front(x, c(40, 60))), 200)
  expect_true(all(sm_shape_wetting_front(x, c(40, 60)) >= 0 & sm_shape_wetting_front(x, c(40, 60)) <= 1))
  
  expect_equal(length(sm_shape_abrupt(x, c(100))), 200)
  expect_true(all(sm_shape_abrupt(x, c(100)) >= 0 & sm_shape_abrupt(x, c(100)) <= 1))
  
  expect_equal(length(sm_shape_peak(x, c(100, 30))), 200)
  expect_true(all(sm_shape_peak(x, c(100, 30)) >= 0 & sm_shape_peak(x, c(100, 30)) <= 1))
  
  expect_equal(length(sm_shape_minimax(x, c(50, 20, 150, 25))), 200)
  expect_true(all(sm_shape_minimax(x, c(50, 20, 150, 25)) >= 0 & sm_shape_minimax(x, c(50, 20, 150, 25)) <= 1))
})

test_that("ascending = FALSE inverts shape", {
  x <- 1:200
  up <- sm_shape_exponential(x, c(1, 0.01), ascending = TRUE)
  down <- sm_shape_exponential(x, c(1, 0.01), ascending = FALSE)
  expect_equal(up + down, rep(1, 200), tolerance = 1e-10)
  
  up_abrupt <- sm_shape_abrupt(x, c(100), ascending = TRUE)
  down_abrupt <- sm_shape_abrupt(x, c(100), ascending = FALSE)
  expect_equal(up_abrupt + down_abrupt, rep(1, 200))
  
  up_peak <- sm_shape_peak(x, c(100, 30), ascending = TRUE)
  down_peak <- sm_shape_peak(x, c(100, 30), ascending = FALSE)
  expect_equal(up_peak + down_peak, rep(1, 200), tolerance = 1e-10)
})
