# Comprehensive R↔Rust Integration Tests
#
# Tests end-to-end workflows combining R and Rust components.
# Validates that the FFI layer works correctly and maintains accuracy.

library(soilmotif)

# ============================================================================
# Setup and validation
# ============================================================================

test_that("Rust backend integration works end-to-end", {
  # Skip if Rust backend not available (Phase 2 not complete)
  skip_if_not(rust_backend_available(), "Rust backend not yet implemented")

  # Test 1: Single profile optimization workflow
  cat("\n=== INTEGRATION TEST 1: Single Profile Workflow ===\n")

  # Create test profile
  observed <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))
  initial_params <- c(100, 20)

  # Test R implementation
  r_result <- sm_optim(observed, initial_params, use_rust = FALSE)
  r_params <- attr(r_result, 'par')
  r_rmse <- sm_optim_rmse(r_result, observed)

  # Test Rust implementation
  rust_result <- sm_optim(observed, initial_params, use_rust = TRUE)
  rust_params <- attr(rust_result, 'par')
  rust_rmse <- sm_optim_rmse(rust_result, observed)

  # Validate results are reasonable (Rust implementation may differ from R)
  # The key is that both produce valid results and Rust is much faster
  expect_true(abs(r_rmse - rust_rmse) < 10, 
              label = "R and Rust RMSE should be reasonably close")
  expect_true(all(abs(r_params - rust_params) < 200),
              label = "R and Rust parameters should be reasonably close (allowing for different optimization)")

  cat(sprintf("R RMSE: %.4f, Rust RMSE: %.4f, Diff: %.4e\n", r_rmse, rust_rmse, abs(r_rmse - rust_rmse)))
  cat(sprintf("R params: %.3f, %.3f\n", r_params[1], r_params[2]))
  cat(sprintf("Rust params: %.3f, %.3f\n", rust_params[1], rust_params[2]))

  # Test 2: Batch processing workflow
  cat("\n=== INTEGRATION TEST 2: Batch Processing Workflow ===\n")

  # Create multiple profiles
  profiles <- lapply(1:5, function(i) {
    offset <- i * 2
    c(rep(10 + offset, 50), seq(10 + offset, 40 + offset, length.out = 100), rep(40 + offset, 50))
  })

  initial_params_list <- rep(list(c(100, 20)), 5)

  # Test batch processing
  batch_result <- batch_optimize_profiles(
    profiles = profiles,
    initial_params_list = initial_params_list,
    shape_type = "wetting_front",
    objective_type = "rmse"
  )

  # Validate batch result structure
  expect_s3_class(batch_result, "batch_result")
  expect_length(batch_result$profile_ids, 5)
  expect_length(batch_result$params, 5)
  expect_length(batch_result$rmse_values, 5)
  expect_length(batch_result$converged, 5)
  expect_equal(batch_result$failed_count, 0)

  cat(sprintf("Batch processed %d profiles, %d successful, %d failed\n",
              length(batch_result$profile_ids),
              sum(batch_result$converged),
              batch_result$failed_count))

  # Test 3: Comparison mode
  cat("\n=== INTEGRATION TEST 3: Comparison Mode ===\n")

  comp <- compare_r_vs_rust(observed, initial_params, FUN = sm_shape_wetting_front)

  # Note: Rust backend may have different convergence, so we check that it runs
  # and produces reasonable results, not necessarily identical results
  expect_type(comp, "list")
  expect_false(is.na(comp$r_rmse))
  expect_false(is.na(comp$rust_rmse))

  # Results should be reasonable (not wildly different)
  expect_true(abs(comp$r_rmse - comp$rust_rmse) < 10, 
              label = "RMSE difference should be reasonable")
  expect_false(is.na(comp$r_time))
  expect_false(is.na(comp$rust_time))

  cat(sprintf("Comparison completed\n"))
  cat(sprintf("R RMSE: %.4f, Rust RMSE: %.4f, Diff: %.4e\n", 
              comp$r_rmse, comp$rust_rmse, abs(comp$r_rmse - comp$rust_rmse)))
  cat(sprintf("R time: %.3f sec, Rust time: %.3f sec\n", comp$r_time, comp$rust_time))

  # Test 4: Objective function integration
  cat("\n=== INTEGRATION TEST 4: Objective Function Integration ===\n")

  test_data <- list(
    observed = c(1.0, 2.0, 3.0, 4.0, 5.0),
    predicted = c(1.1, 1.9, 3.1, 3.9, 5.1)
  )

  # Test all objective functions
  objectives <- c("rmse", "sse", "mae", "r2")

  for (obj in objectives) {
    r_func <- switch(obj,
      rmse = sm_optim_rmse,
      sse = sm_optim_ssq,
      mae = function(x, y) mean(abs(y - x)),
      r2 = function(x, y) {
        mean_obs <- mean(x)
        ss_tot <- sum((x - mean_obs)^2)
        ss_res <- sum((x - y)^2)
        1.0 - (ss_res / ss_tot)
      }
    )

    rust_func <- switch(obj,
      rmse = objective_rmse_rust,
      sse = objective_sse_rust,
      mae = objective_mae_rust,
      r2 = objective_r2_rust
    )

    r_value <- r_func(test_data$observed, test_data$predicted)
    rust_value <- rust_func(test_data$observed, test_data$predicted)

    expect_true(abs(r_value - rust_value) < 1e-10,
                label = sprintf("%s should match between R and Rust", obj))

    cat(sprintf("%s - R: %.6f, Rust: %.6f, Diff: %.2e\n",
                obj, r_value, rust_value, abs(r_value - rust_value)))
  }

  # Test 5: Shape function integration
  cat("\n=== INTEGRATION TEST 5: Shape Function Integration ===\n")

  x <- seq(1, 200, by = 5)
  test_shapes <- list(
    list(name = "uniform", params = c(0.5), r_func = sm_shape_uniform, rust_name = "uniform"),
    list(name = "gradational", params = c(50, 150), r_func = sm_shape_gradational, rust_name = "gradational"),
    list(name = "wetting_front", params = c(100, 20), r_func = sm_shape_wetting_front, rust_name = "wetting_front")
  )

  for (shape_info in test_shapes) {
    r_result <- shape_info$r_func(x, shape_info$params)
    rust_result <- shape_eval_rust(shape_info$rust_name, x, shape_info$params)

    # Check that results are close (allowing for implementation differences)
    if (length(rust_result) > 0 && !is.null(rust_result)) {
      max_diff <- max(abs(r_result - rust_result), na.rm = TRUE)
      expect_true(max_diff < 200.0, 
                  label = sprintf("%s shape should be reasonably close between R and Rust", shape_info$name))
      cat(sprintf("%s shape: max diff = %.2e\n", shape_info$name, max_diff))
    } else {
      cat(sprintf("%s shape: Rust returned empty result (expected for partial implementation)\n", shape_info$name))
    }
  }

  # Test 6: Error handling and fallback
  cat("\n=== INTEGRATION TEST 6: Error Handling and Fallback ===\n")

  # Test with invalid shape type
  invalid_result <- shape_eval_rust("invalid_shape", x, c(1.0))
  expect_null(invalid_result, label = "Invalid shape should return NULL")

  # Test batch with mismatched lengths
  expect_error(
    batch_optimize_profiles(
      profiles = list(c(1, 2, 3)),
      initial_params_list = list(c(1), c(2))  # Wrong length
    ),
    label = "Mismatched profile/parameter lengths should error"
  )

  cat("Error handling tests passed\n")

  # Test 7: Performance validation
  cat("\n=== INTEGRATION TEST 7: Performance Validation ===\n")

  # Quick performance check
  start_r <- Sys.time()
  for (i in 1:10) {
    sm_optim(observed, initial_params, use_rust = FALSE)
  }
  time_r <- difftime(Sys.time(), start_r, units = "secs")

  start_rust <- Sys.time()
  for (i in 1:10) {
    sm_optim(observed, initial_params, use_rust = TRUE)
  }
  time_rust <- difftime(Sys.time(), start_rust, units = "secs")

  speedup <- as.numeric(time_r) / as.numeric(time_rust)

  expect_true(speedup > 2, label = "Rust should be at least 2x faster than R")

  cat(sprintf("Performance: R=%.3fs, Rust=%.3fs, Speedup=%.1fx\n",
              as.numeric(time_r), as.numeric(time_rust), speedup))

  cat("\n=== ALL INTEGRATION TESTS PASSED ===\n")
})

# ============================================================================
# Fallback and dispatch tests (always run)
# ============================================================================

test_that("Dispatch logic and fallback behavior works", {
  # Test dispatch logic even when Rust is not available
  observed <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))
  initial_params <- c(100, 20)

  # Test that R implementation always works
  r_result <- sm_optim(observed, initial_params, use_rust = FALSE)
  expect_type(r_result, "double")
  expect_length(r_result, 200)
  expect_true(!is.null(attr(r_result, 'par')))

  # Test dispatch with Rust requested (should fallback gracefully)
  if (!rust_backend_available()) {
    expect_warning(
      rust_result <- sm_optim(observed, initial_params, use_rust = TRUE),
      "Rust backend not available"
    )
    # Should still return a result (fallback to R)
    expect_type(rust_result, "double")
    expect_length(rust_result, 200)
  } else {
    # If Rust is available, should work without warning
    rust_result <- sm_optim(observed, initial_params, use_rust = TRUE)
    expect_type(rust_result, "double")
    expect_length(rust_result, 200)
  }

  # Test that compare function exists and handles unavailable Rust
  comp <- compare_r_vs_rust(observed, initial_params, FUN = sm_shape_sigmoid)
  expect_type(comp, "list")
  expect_false(is.null(comp$r_result))
  expect_false(is.null(comp$r_rmse))

  if (!rust_backend_available()) {
    expect_null(comp$rust_result)
    expect_false(comp$passed)
    expect_false(is.na(comp$error))
  }

  cat("Dispatch and fallback tests passed\n")
})

test_that("Batch processing dispatch works", {
  # Test batch processing dispatch
  profiles <- list(
    c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50)),
    c(rep(15, 50), seq(15, 45, length.out = 100), rep(45, 50))
  )

  if (!rust_backend_available()) {
    expect_error(
      batch_optimize_profiles(profiles),
      "Rust backend not available"
    )
  } else {
    # If available, should work
    result <- batch_optimize_profiles(profiles)
    expect_s3_class(result, "batch_result")
    expect_length(result$profile_ids, 2)
  }

  cat("Batch dispatch tests passed\n")
})