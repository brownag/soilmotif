test_that("sm_prepare step method works with data.frame", {
  data <- data.frame(
    id = c("P1", "P1", "P1"),
    top = c(0, 20, 50),
    bottom = c(20, 50, 100),
    clay = c(10, 30, 25)
  )

  result <- sm_prepare(data, property = "clay", method = "step")

  expect_type(result, "list")
  expect_named(result, "clay")
  expect_type(result$clay, "list")
  expect_named(result$clay, "P1")

  # Check length: depth_range c(1,200) with resolution 1 = 200 points
  expect_equal(length(result$clay$P1), 200)

  # Check values
  expect_equal(result$clay$P1[1:20], rep(10, 20))  # 1-20 cm
  expect_equal(result$clay$P1[21:50], rep(30, 30))  # 21-50 cm
  expect_equal(result$clay$P1[51:200], rep(25, 150))  # 51-200 cm (extended)
})

test_that("sm_prepare linear method works with data.frame", {
  data <- data.frame(
    id = "P1",
    top = c(0, 50, 100),
    bottom = c(50, 100, 200),
    clay = c(10, 30, 20)
  )

  result <- sm_prepare(data, property = "clay", method = "linear")

  expect_type(result, "list")
  expect_named(result, "clay")
  expect_equal(length(result$clay$P1), 200)

  # Check some interpolated values
  expect_equal(result$clay$P1[25], 10)  # At mid of first horizon
  expect_equal(result$clay$P1[50], 20)  # Interpolated at boundary
  expect_lt(abs(result$clay$P1[75] - 30), 0.1)  # Near mid of second
  expect_lt(abs(result$clay$P1[150] - 20), 0.1)  # Near mid of third
  expect_equal(result$clay$P1[200], 20)  # Extended
})

test_that("sm_prepare handles multiple properties", {
  data <- data.frame(
    id = "P1",
    top = c(0, 50),
    bottom = c(50, 100),
    clay = c(10, 30),
    sand = c(80, 60)
  )

  result <- sm_prepare(data, property = c("clay", "sand"), method = "step")

  expect_named(result, c("clay", "sand"))
  expect_equal(length(result$clay$P1), 200)
  expect_equal(length(result$sand$P1), 200)
})

test_that("sm_prepare auto-detects properties", {
  data <- data.frame(
    id = "P1",
    top = c(0, 50),
    bottom = c(50, 100),
    clay = c(10, 30),
    sand = c(80, 60)
  )

  result <- sm_prepare(data, method = "step")

  expect_named(result, c("clay", "sand"))
})

test_that("sm_prepare handles custom depth range and resolution", {
  data <- data.frame(
    id = "P1",
    top = c(0, 50),
    bottom = c(50, 100),
    clay = c(10, 30)
  )

  result <- sm_prepare(data, property = "clay", method = "step",
                       depth_range = c(0, 100), resolution = 2)

  # 0 to 100 with resolution 2 = 51 points
  expect_equal(length(result$clay$P1), 51)
})

test_that("sm_prepare handles missing values", {
  data <- data.frame(
    id = c("P1", "P1"),
    top = c(0, 50),
    bottom = c(50, 100),
    clay = c(10, NA)
  )

  result <- sm_prepare(data, property = "clay", method = "step")

  expect_equal(result$clay$P1[1:50], rep(10, 50))
  expect_equal(result$clay$P1[51:200], rep(0, 150))  # Default for missing, no extension
})

test_that("sm_prepare works with CSV input", {
  # Create temporary CSV
  data <- data.frame(
    id = c("P1", "P1"),
    top = c(0, 50),
    bottom = c(50, 100),
    clay = c(10, 30)
  )

  temp_file <- tempfile(fileext = ".csv")
  write.csv(data, temp_file, row.names = FALSE)

  result <- sm_prepare(temp_file, property = "clay", method = "step")

  expect_named(result, "clay")
  expect_equal(length(result$clay$P1), 200)

  unlink(temp_file)
})

test_that("sm_prepare integrates with sm_motif", {
  data <- data.frame(
    id = "P1",
    top = c(0, 50, 100),
    bottom = c(50, 100, 200),
    clay = c(10, 30, 20)
  )

  prep <- sm_prepare(data, property = "clay", method = "step")
  x <- prep$clay$P1

  fit <- sm_motif(x, c(50, 100), FUN = sm_shape_peak)
  expect_equal(length(fit), 200)
})

test_that("sm_prepare handles multiple profiles", {
  data <- data.frame(
    id = c("P1", "P1", "P2", "P2"),
    top = c(0, 50, 0, 30),
    bottom = c(50, 100, 30, 100),
    clay = c(10, 30, 15, 25)
  )

  result <- sm_prepare(data, property = "clay", method = "step")

  expect_named(result$clay, c("P1", "P2"))
  expect_equal(length(result$clay$P1), 200)
  expect_equal(length(result$clay$P2), 200)
})

test_that("sm_prepare spline method falls back to linear when mpspline2 unavailable", {
  skip_if(requireNamespace("mpspline2", quietly = TRUE), "mpspline2 available")

  data <- data.frame(
    id = "P1",
    top = c(0, 50),
    bottom = c(50, 100),
    clay = c(10, 30)
  )

  expect_warning(
    result <- sm_prepare(data, property = "clay", method = "spline"),
    "mpspline2 not available"
  )

  expect_named(result, "clay")
  expect_equal(length(result$clay$P1), 201)
})

test_that("sm_prepare validates inputs", {
  data <- data.frame(id = "P1", top = 0, bottom = 50, clay = 10)

  expect_error(sm_prepare(data, method = "invalid"), "method must be")
  expect_error(sm_prepare(data, depth_range = c(100, 50)), "depth_range")
  expect_error(sm_prepare(data, resolution = 0), "resolution must be positive")

  bad_data <- data.frame(id = "P1", clay = 10)  # Missing top/bottom
  expect_error(sm_prepare(bad_data), "Missing required columns")
})

test_that("sm_prepare handles SoilProfileCollection input", {
  skip_if_not_installed("aqp")

  library(aqp)

  # Create a simple SoilProfileCollection
  data <- data.frame(
    id = c("P1", "P1", "P2"),
    top = c(0, 50, 0),
    bottom = c(50, 100, 100),
    clay = c(10, 30, 20)
  )

  spc <- data
  depths(spc) <- id ~ top + bottom

  result <- sm_prepare(spc, property = "clay", method = "step")

  expect_named(result, "clay")
  expect_true(length(result$clay) >= 1)
})