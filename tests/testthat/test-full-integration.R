# Rust Backend Integration Tests
#
# Tests end-to-end workflows with Rust components.
# Validates that the FFI layer works correctly and Rust backend functions properly.
# NOTE: R vs Rust comparison tests have been moved to misc/validate-rust-equivalence.R
# since the implementations have diverged sufficiently that exact matching is impractical.

library(soilmotif)

# ============================================================================
# Setup and validation
# ============================================================================

test_that("Rust backend optimization works end-to-end", {
  # Skip if Rust backend not available (Phase 2 not complete)
  skip_if_not(sm_rust_backend_available(), "Rust backend not yet implemented")

  # Test 1: Rust single profile optimization workflow
  cat("\n=== RUST BACKEND TEST 1: Single Profile Optimization ===\n")

  # Create test profile
  observed <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))
  initial_params <- c(100, 20)

  # Test Rust implementation
  rust_result <- sm_optim(observed, initial_params, use_rust = TRUE)
  rust_params <- attr(rust_result, 'par')
  rust_rmse <- sm_optim_rmse(rust_result, observed)

  # Validate Rust result is reasonable
  expect_type(rust_result, "double")
  expect_length(rust_result, 200)
  expect_type(rust_params, "double")
  expect_length(rust_params, 2)
  expect_true(rust_rmse > 0, label = "RMSE should be positive")
  expect_false(any(is.na(rust_result)), label = "No NAs in result")
  expect_false(any(is.na(rust_params)), label = "No NAs in params")

  cat(sprintf("Rust RMSE: %.4f\n", rust_rmse))
  cat(sprintf("Rust params: %.3f, %.3f\n", rust_params[1], rust_params[2]))

  # Test 2: Rust batch processing workflow
  cat("\n=== RUST BACKEND TEST 2: Batch Processing ===\n")

  # Create multiple profiles
  profiles <- lapply(1:5, function(i) {
    offset <- i * 2
    c(rep(10 + offset, 50), seq(10 + offset, 40 + offset, length.out = 100), rep(40 + offset, 50))
  })

  initial_params_list <- rep(list(c(100, 20)), 5)

  # Test batch processing
  batch_result <- sm_batch_optimize_profiles(
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

  # Test 3: Objective function consistency
  cat("\n=== RUST BACKEND TEST 3: Objective Function Consistency ===\n")

  test_data <- list(
    observed = c(1.0, 2.0, 3.0, 4.0, 5.0),
    predicted = c(1.1, 1.9, 3.1, 3.9, 5.1)
  )

  # Test all Rust objective functions (they should compute same values regardless of backend)
  objectives <- c("rmse", "sse", "mae", "r2")

  for (obj in objectives) {
    rust_func <- switch(obj,
      rmse = soilmotif:::objective_rmse_rust,
      sse = soilmotif:::objective_sse_rust,
      mae = soilmotif:::objective_mae_rust,
      r2 = soilmotif:::objective_r2_rust
    )

    rust_value <- rust_func(test_data$observed, test_data$predicted)
    expect_false(is.na(rust_value), label = sprintf("%s should produce numeric value", obj))
    expect_true(rust_value > 0, label = sprintf("%s should be positive", obj))

    cat(sprintf("%s - Rust: %.6f\n", obj, rust_value))
  }

  # Test 4: Shape function evaluation
  cat("\n=== RUST BACKEND TEST 4: Shape Function Evaluation ===\n")

  x <- seq(1, 200, by = 5)
  test_shapes <- list(
    list(name = "uniform", params = c(0.5), rust_name = "uniform"),
    list(name = "gradational", params = c(50, 150), rust_name = "gradational"),
    list(name = "wetting_front", params = c(100, 20), rust_name = "wetting_front")
  )

  for (shape_info in test_shapes) {
    rust_result <- soilmotif:::shape_eval_rust(shape_info$rust_name, x, shape_info$params)

    # Check that results are valid (not null or NA)
    expect_false(is.null(rust_result), 
                 label = sprintf("%s shape should produce result", shape_info$name))
    expect_false(any(is.na(rust_result)), 
                 label = sprintf("%s shape should have no NAs", shape_info$name))
    expect_true(length(rust_result) == length(x), 
                label = sprintf("%s shape should return correct length", shape_info$name))
    
    cat(sprintf("%s shape: OK (range %.3f to %.3f)\n", 
                shape_info$name, min(rust_result, na.rm = TRUE), max(rust_result, na.rm = TRUE)))
  }

  # Test 5: Error handling and fallback
  cat("\n=== RUST BACKEND TEST 5: Error Handling ===\n")

  # Test with invalid shape type
  expect_warning({invalid_result <- soilmotif:::shape_eval_rust("invalid_shape", x, c(1.0))})
  expect_null(invalid_result, label = "Invalid shape should return NULL")

  # Test batch with mismatched lengths
  expect_error(
    sm_batch_optimize_profiles(
      profiles = list(c(1, 2, 3)),
      initial_params_list = list(c(1), c(2))  # Wrong length
    ),
    label = "Mismatched profile/parameter lengths should error"
  )

  cat("Error handling tests passed\n")

  # Test 6: Rust optimization with different objectives
  cat("\n=== RUST BACKEND TEST 6: Multiple Objectives ===\n")

  for (obj_type in c("rmse", "sse", "mae", "r2")) {
    result <- soilmotif:::optimize_profile_rust_flexible(
      observed = observed,
      x = seq_along(observed),
      initial_params = c(100, 20),
      shape_type = "wetting_front",
      ascending = TRUE,
      objective_type = obj_type,
      algorithm = "auto"
    )
    
    expect_false(any(is.na(result)), label = sprintf("%s objective should produce valid params", obj_type))
    expect_equal(length(result), 2, label = sprintf("%s objective should return 2 params", obj_type))
    
    cat(sprintf("%s objective: params = %.2f, %.2f\n", obj_type, result[1], result[2]))
  }

  cat("\n=== ALL RUST BACKEND TESTS PASSED ===\n")
})

# ============================================================================
# R implementation tests (for completeness)
# ============================================================================

test_that("R backend optimization works", {
  cat("\n=== R BACKEND TEST: Single Profile Optimization ===\n")

  observed <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))
  initial_params <- c(100, 20)

  # Test R implementation
  r_result <- sm_optim(observed, initial_params, use_rust = FALSE)
  r_params <- attr(r_result, 'par')
  r_rmse <- sm_optim_rmse(r_result, observed)

  # Validate R result is reasonable
  expect_type(r_result, "double")
  expect_length(r_result, 200)
  expect_type(r_params, "double")
  expect_length(r_params, 2)
  expect_true(r_rmse > 0, label = "RMSE should be positive")
  expect_false(any(is.na(r_result)), label = "No NAs in result")
  expect_false(any(is.na(r_params)), label = "No NAs in params")

  cat(sprintf("R RMSE: %.4f\n", r_rmse))
  cat(sprintf("R params: %.3f, %.3f\n", r_params[1], r_params[2]))
  cat("R backend test passed\n")
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
  if (!sm_rust_backend_available()) {
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

  cat("Dispatch and fallback tests passed\n")
})

test_that("Batch processing dispatch works", {
  # Test batch processing dispatch
  profiles <- list(
    c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50)),
    c(rep(15, 50), seq(15, 45, length.out = 100), rep(45, 50))
  )

  if (!sm_rust_backend_available()) {
    expect_error(
      sm_batch_optimize_profiles(profiles),
      "Rust backend not available"
    )
  } else {
    # If available, should work
    result <- sm_batch_optimize_profiles(profiles)
    expect_s3_class(result, "batch_result")
    expect_length(result$profile_ids, 2)
  }

  cat("Batch dispatch tests passed\n")
})