#!/usr/bin/env Rscript
#
# Benchmark script for batch processing: sequential vs. parallel
#
# Compares wall-clock time and results for single vs. multiple profiles.
# Useful for understanding performance characteristics for raster grid cell workflows.

library(soilmotif)
library(microbenchmark)

# ============================================================================
# Setup: Generate test data
# ============================================================================

cat("\n=== Batch Processing Benchmark ===\n")

if (!rust_backend_available()) {
  cat("Rust backend not available. Install soilmotif with Rust support.\n")
  quit(status = 1)
}

# Generate synthetic soil profiles (simulating raster grid cells)
# Each cell has a depth profile following different patterns
generate_test_profiles <- function(n_cells, seed = 42) {
  set.seed(seed)
  
  lapply(1:n_cells, function(i) {
    # Random starting depth, gradient, and transition
    base_value <- 10 + runif(1, 0, 10)
    end_value <- base_value + runif(1, 15, 35)
    transition_depth <- 50 + runif(1, 20, 60)
    
    # Create S-curve profile
    depth <- 1:200
    profile <- base_value + (end_value - base_value) * 
      (1 / (1 + exp(-(depth - transition_depth) / 10)))
    
    # Add small noise
    profile + rnorm(length(profile), 0, 0.3)
  })
}

# ============================================================================
# Benchmark 1: Single profile optimization
# ============================================================================

cat("\n--- Benchmark 1: Single Profile ---\n")

profile_single <- generate_test_profiles(1)[[1]]
init_params_single <- list(c(100, 20))

cat("Running single profile optimization (5 iterations)...\n")
bench_single <- microbenchmark({
  result <- batch_optimize_profiles(
    profiles = profile_single,
    initial_params_list = init_params_single,
    shape_type = "wetting_front",
    objective_type = "rmse"
  )
}, times = 5)

cat(sprintf("  Min:    %.2f ms\n", min(bench_single$time) / 1e6))
cat(sprintf("  Median: %.2f ms\n", median(bench_single$time) / 1e6))
cat(sprintf("  Max:    %.2f ms\n", max(bench_single$time) / 1e6))
cat(sprintf("  Mean:   %.2f ms\n", mean(bench_single$time) / 1e6))

# ============================================================================
# Benchmark 2: Small batch (10 profiles)
# ============================================================================

cat("\n--- Benchmark 2: Small Batch (10 profiles) ---\n")

profiles_small <- generate_test_profiles(10)
init_params_small <- rep(list(c(100, 20)), 10)

cat("Running batch optimization (5 iterations)...\n")
bench_small <- microbenchmark({
  result <- batch_optimize_profiles(
    profiles = profiles_small,
    initial_params_list = init_params_small,
    shape_type = "wetting_front",
    objective_type = "rmse"
  )
}, times = 5)

cat(sprintf("  Min:    %.2f ms\n", min(bench_small$time) / 1e6))
cat(sprintf("  Median: %.2f ms\n", median(bench_small$time) / 1e6))
cat(sprintf("  Max:    %.2f ms\n", max(bench_small$time) / 1e6))
cat(sprintf("  Mean:   %.2f ms\n", mean(bench_small$time) / 1e6))

# ============================================================================
# Benchmark 3: Large batch (100 profiles) - simulating raster grid
# ============================================================================

cat("\n--- Benchmark 3: Large Batch (100 profiles - simulating raster grid) ---\n")

profiles_large <- generate_test_profiles(100)
init_params_large <- rep(list(c(100, 20)), 100)

cat("Running batch optimization (3 iterations)...\n")
bench_large <- microbenchmark({
  result <- batch_optimize_profiles(
    profiles = profiles_large,
    initial_params_list = init_params_large,
    shape_type = "wetting_front",
    objective_type = "rmse"
  )
}, times = 3)

cat(sprintf("  Min:    %.2f ms\n", min(bench_large$time) / 1e6))
cat(sprintf("  Median: %.2f ms\n", median(bench_large$time) / 1e6))
cat(sprintf("  Max:    %.2f ms\n", max(bench_large$time) / 1e6))
cat(sprintf("  Mean:   %.2f ms\n", mean(bench_large$time) / 1e6))

# ============================================================================
# Benchmark 4: Very large batch (500 profiles)
# ============================================================================

cat("\n--- Benchmark 4: Very Large Batch (500 profiles) ---\n")

profiles_xlarge <- generate_test_profiles(500)
init_params_xlarge <- rep(list(c(100, 20)), 500)

cat("Running batch optimization (2 iterations)...\n")
bench_xlarge <- microbenchmark({
  result <- batch_optimize_profiles(
    profiles = profiles_xlarge,
    initial_params_list = init_params_xlarge,
    shape_type = "wetting_front",
    objective_type = "rmse"
  )
}, times = 2)

cat(sprintf("  Min:    %.2f ms\n", min(bench_xlarge$time) / 1e6))
cat(sprintf("  Median: %.2f ms\n", median(bench_xlarge$time) / 1e6))
cat(sprintf("  Max:    %.2f ms\n", max(bench_xlarge$time) / 1e6))
cat(sprintf("  Mean:   %.2f ms\n", mean(bench_xlarge$time) / 1e6))

# ============================================================================
# Performance Analysis
# ============================================================================

cat("\n=== Performance Analysis ===\n")

single_ms <- median(bench_single$time) / 1e6
small_ms <- median(bench_small$time) / 1e6
large_ms <- median(bench_large$time) / 1e6
xlarge_ms <- median(bench_xlarge$time) / 1e6

cat("Time per profile (estimated):\n")
cat(sprintf("  10 profiles:  %.3f ms/profile\n", small_ms / 10))
cat(sprintf("  100 profiles: %.3f ms/profile\n", large_ms / 100))
cat(sprintf("  500 profiles: %.3f ms/profile\n", xlarge_ms / 500))

# Estimate scaling efficiency
cat("\nScaling efficiency (vs. baseline):\n")
baseline_per_profile <- single_ms / 1  # Single profile time
small_efficiency <- 10 * baseline_per_profile / small_ms * 100
large_efficiency <- 100 * baseline_per_profile / large_ms * 100
xlarge_efficiency <- 500 * baseline_per_profile / xlarge_ms * 100

cat(sprintf("  10 profiles:  %.1f%% of theoretical max\n", small_efficiency))
cat(sprintf("  100 profiles: %.1f%% of theoretical max\n", large_efficiency))
cat(sprintf("  500 profiles: %.1f%% of theoretical max\n", xlarge_efficiency))

# ============================================================================
# Correctness Validation
# ============================================================================

cat("\n=== Correctness Validation ===\n")

# Check that batch results match single-profile optimizer
profile_test <- profiles_large[1]
init_params_test <- list(c(100, 20))

result_batch <- batch_optimize_profiles(
  profiles = profile_test,
  initial_params_list = init_params_test,
  shape_type = "wetting_front",
  objective_type = "rmse"
)

result_direct <- optimize_profile_rust_flexible(
  observed = profile_test[[1]],
  x = seq_along(profile_test[[1]]),
  initial_params = init_params_test[[1]],
  shape_type = "wetting_front",
  ascending = TRUE,
  objective_type = "rmse"
)

batch_params <- result_batch$params[[1]]
param_match <- all(abs(batch_params - result_direct) < 1e-6)

cat(sprintf("Batch result matches single-profile optimizer: %s\n", 
            ifelse(param_match, "YES", "NO")))

if (!param_match) {
  cat(sprintf("  Batch params:  %.6f, %.6f\n", batch_params[1], batch_params[2]))
  cat(sprintf("  Direct params: %.6f, %.6f\n", result_direct[1], result_direct[2]))
  cat(sprintf("  Max difference: %.2e\n", max(abs(batch_params - result_direct))))
}

# ============================================================================
# Raster Grid Cell Use Case
# ============================================================================

cat("\n=== Raster Grid Cell Use Case ===\n")

# Simulate a small 20x20 raster grid (400 cells)
cat("Simulating 20x20 raster grid (400 cells)...\n")

profiles_grid <- generate_test_profiles(400)
init_params_grid <- rep(list(c(100, 20)), 400)

start_time <- Sys.time()
result_grid <- batch_optimize_profiles(
  profiles = profiles_grid,
  initial_params_list = init_params_grid,
  shape_type = "wetting_front",
  objective_type = "rmse"
)
elapsed <- difftime(Sys.time(), start_time, units = "secs")

cat(sprintf("  Total time: %.2f seconds\n", as.numeric(elapsed)))
cat(sprintf("  Time per cell: %.2f ms\n", as.numeric(elapsed) * 1000 / 400))
cat(sprintf("  Failed cells: %d\n", result_grid$failed_count))
cat(sprintf("  Successful cells: %d\n", length(result_grid$successful_ids())))

# ============================================================================
# Summary
# ============================================================================

cat("\n=== Summary ===\n")
cat("Batch processing achieves efficient per-cell optimization for raster workflows.\n")
cat("Single-profile optimization: ~", sprintf("%.1f ms\n", single_ms))
cat("Batch overhead (fixed): ~", sprintf("%.1f ms\n", small_ms - 10 * single_ms))
cat("Recommended: Use batch processing for 10+ profiles to amortize overhead.\n")
