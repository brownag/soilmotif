# Batch processing tests for Rust backend
#
# Tests sequential batch processor, error collection, result validation, and correctness

test_that("batch_optimize_profiles requires Rust backend", {
  skip_if(!rust_backend_available())
  
  profile <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))
  result <- batch_optimize_profiles(
    profiles = list(profile),
    initial_params_list = list(c(100, 20)),
    shape_type = "wetting_front"
  )
  
  expect_is(result, "batch_result")
})

test_that("batch_optimize_profiles rejects empty profiles", {
  skip_if(!rust_backend_available())
  
  expect_error(
    batch_optimize_profiles(profiles = list()),
    "non-empty"
  )
})

test_that("batch_optimize_profiles handles single profile", {
  skip_if(!rust_backend_available())
  
  profile <- rep(0.5, 200)
  result <- batch_optimize_profiles(
    profiles = list(profile),
    initial_params_list = list(c(100, 20)),
    shape_type = "uniform"
  )
  
  expect_equal(length(result$profile_ids), 1)
  expect_equal(length(result$params), 1)
  expect_equal(length(result$rmse_values), 1)
  expect_equal(length(result$converged), 1)
  expect_equal(length(result$errors), 1)
})

test_that("batch_optimize_profiles handles multiple profiles", {
  skip_if(!rust_backend_available())
  
  profiles <- lapply(1:5, function(i) {
    c(
      rep(10 + i * 0.1, 30),
      seq(10 + i * 0.1, 40 + i * 0.05, length.out = 100),
      rep(40 + i * 0.05, 70)
    )
  })
  
  result <- batch_optimize_profiles(
    profiles = profiles,
    initial_params_list = list(c(100, 20)),  # Recycled
    shape_type = "gradational"
  )
  
  expect_equal(length(result$profile_ids), 5)
  expect_equal(length(result$params), 5)
  expect_equal(result$failed_count, 0)
})

test_that("batch_optimize_profiles recycles single parameter set", {
  skip_if(!rust_backend_available())
  
  profiles <- list(rep(0.5, 200), rep(0.6, 200))
  params_list <- list(c(100, 20))  # Only 1, but 2 profiles - should be recycled
  
  result <- batch_optimize_profiles(
    profiles = profiles,
    initial_params_list = params_list,
    shape_type = "uniform"
  )
  
  expect_equal(result$failed_count, 0)
  expect_equal(length(result$params), 2)  # Both profiles should have been optimized
})

test_that("batch_optimize_profiles uses default parameters when NULL", {
  skip_if(!rust_backend_available())
  
  profile <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))
  
  result <- batch_optimize_profiles(
    profiles = list(profile),
    initial_params_list = NULL,  # Use defaults
    shape_type = "wetting_front"
  )
  
  expect_is(result, "batch_result")
  expect_equal(result$failed_count, 0)
})

test_that("batch_optimize_profiles returns correct S3 class", {
  skip_if(!rust_backend_available())
  
  profile <- rep(0.5, 200)
  result <- batch_optimize_profiles(
    profiles = list(profile),
    shape_type = "uniform"
  )
  
  expect_true(inherits(result, "batch_result"))
  expect_true(inherits(result, "list"))
})

test_that("batch_get_successful extracts only successful profiles", {
  skip_if(!rust_backend_available())
  
  profiles <- lapply(1:3, function(i) rep(0.5, 200))
  result <- batch_optimize_profiles(
    profiles = profiles,
    shape_type = "uniform"
  )
  
  successful <- batch_get_successful(result)
  expect_is(successful, "data.frame")
  expect_equal(nrow(successful), 3)  # All should succeed for uniform
  expect_true("profile_id" %in% names(successful))
  expect_true("params" %in% names(successful))
})

test_that("batch_get_failed returns empty if all succeed", {
  skip_if(!rust_backend_available())
  
  profiles <- lapply(1:3, function(i) rep(0.5, 200))
  result <- batch_optimize_profiles(
    profiles = profiles,
    shape_type = "uniform"
  )
  
  failed <- batch_get_failed(result)
  expect_is(failed, "data.frame")
  expect_equal(nrow(failed), 0)
})

test_that("batch_get extracts components correctly", {
  skip_if(!rust_backend_available())
  
  profile <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))
  result <- batch_optimize_profiles(
    profiles = list(profile),
    initial_params_list = list(c(100, 20)),
    shape_type = "wetting_front"
  )
  
  # Extract each component
  params <- batch_get(result, "params")
  expect_is(params, "list")
  expect_equal(length(params), 1)
  
  rmse <- batch_get(result, "rmse")
  expect_is(rmse, "numeric")
  expect_equal(length(rmse), 1)
  
  converged <- batch_get(result, "converged")
  expect_is(converged, "logical")
  expect_equal(length(converged), 1)
})

test_that("batch results match single-profile optimization", {
  skip_if(!rust_backend_available())
  
  profile <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))
  init_params <- c(100, 20)
  
  # Single profile via batch
  batch_result <- batch_optimize_profiles(
    profiles = list(profile),
    initial_params_list = list(init_params),
    shape_type = "wetting_front",
    objective_type = "rmse"
  )
  
  # Single profile via direct optimizer
  direct_result <- optimize_profile_rust_flexible(
    observed = profile,
    x = seq_along(profile),
    initial_params = init_params,
    shape_type = "wetting_front",
    ascending = TRUE,
    objective_type = "rmse"
  )
  
  # Parameters should match closely (within tolerance for numerical methods)
  batch_params <- batch_result$params[[1]]
  expect_equal(batch_params, direct_result, tolerance = 1e-6)
  
  # RMSE should match
  expect_equal(batch_result$rmse_values[1], 
               objective_rmse_rust(profile, 
                                   shape_eval_rust("wetting_front", 
                                                  seq_along(profile), 
                                                  direct_result, 
                                                  TRUE)),
               tolerance = 1e-6)
})

test_that("batch_optimize_profiles handles different objective types", {
  skip_if(!rust_backend_available())
  
  profile <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))
  
  for (obj_type in c("rmse", "sse", "mae", "r2")) {
    result <- batch_optimize_profiles(
      profiles = list(profile),
      initial_params_list = list(c(100, 20)),
      shape_type = "wetting_front",
      objective_type = obj_type
    )
    
    expect_is(result, "batch_result")
    expect_equal(result$failed_count, 0)
    expect_true(result$converged[1])
  }
})

test_that("batch_optimize_profiles handles ascending parameter", {
  skip_if(!rust_backend_available())
  
  profile_increasing <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))
  profile_decreasing <- c(rep(40, 50), seq(40, 10, length.out = 100), rep(10, 50))
  
  result_asc <- batch_optimize_profiles(
    profiles = list(profile_increasing),
    initial_params_list = list(c(100, 20)),
    shape_type = "wetting_front",
    ascending = TRUE
  )
  
  result_desc <- batch_optimize_profiles(
    profiles = list(profile_decreasing),
    initial_params_list = list(c(100, 20)),
    shape_type = "wetting_front",
    ascending = FALSE
  )
  
  expect_equal(result_asc$failed_count, 0)
  expect_equal(result_desc$failed_count, 0)
})

test_that("batch print method works", {
  skip_if(!rust_backend_available())
  
  profile <- rep(0.5, 200)
  result <- batch_optimize_profiles(
    profiles = list(profile),
    shape_type = "uniform"
  )
  
  # Should not error
  expect_output(print(result), "Batch Optimization Result")
})

test_that("as_summary_table creates correct structure", {
  skip_if(!rust_backend_available())
  
  profiles <- lapply(1:3, function(i) rep(0.5 + i * 0.05, 200))
  result <- batch_optimize_profiles(
    profiles = profiles,
    shape_type = "uniform"
  )
  
  summary_df <- as_summary_table(result)
  expect_is(summary_df, "data.frame")
  expect_equal(nrow(summary_df), 3)
  expect_true("profile_id" %in% names(summary_df))
  expect_true("converged" %in% names(summary_df))
  expect_true("rmse" %in% names(summary_df))
  expect_true("error" %in% names(summary_df))
  expect_true("params" %in% names(summary_df))
})

test_that("batch_optimize_profiles uses custom depth vector", {
  skip_if(!rust_backend_available())
  
  profile <- rep(0.5, 100)
  custom_x <- seq(0, 99, by = 1)
  
  result <- batch_optimize_profiles(
    profiles = list(profile),
    initial_params_list = list(c(50, 10)),
    x = custom_x,
    shape_type = "uniform"
  )
  
  expect_is(result, "batch_result")
  expect_equal(result$failed_count, 0)
})

test_that("batch_optimize_profiles infers default depth vector", {
  skip_if(!rust_backend_available())
  
  profile <- rep(0.5, 150)
  
  result <- batch_optimize_profiles(
    profiles = list(profile),
    initial_params_list = list(c(75, 15)),
    x = NULL,  # Should infer 1:150
    shape_type = "uniform"
  )
  
  expect_is(result, "batch_result")
  expect_equal(result$failed_count, 0)
})
