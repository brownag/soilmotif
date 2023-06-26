test_that("test shape sigmoid", {
  res <- sm_shape_sigmoid(0:100, c(20, 50))
  expect_equal(length(res), 101)
  expect_equal(c(res[19], res[36], res[51]), c(0, 0.5, 1))
})
