#!/usr/bin/env Rscript
#' Validate Rust implementations against R equivalents
#'
#' This script verifies that Rust and R implementations produce equivalent
#' results within numerical tolerance (1e-10). Run this after building
#' the Rust backend to ensure correctness.
#'
#' Usage: Rscript misc/validate-rust-equivalence.R

# Load the package
library(soilmotif)

cat("=" %>% paste0(rep.int(., 70), collapse = ""), "\n", sep = "")
cat("Rust Implementation Equivalence Validation\n")
cat("=" %>% paste0(rep.int(., 70), collapse = ""), "\n", sep = "")

# Check if Rust backend is available
if (!rust_backend_available()) {
  cat("\nERROR: Rust backend not available. Cannot proceed with validation.\n")
  cat("Please rebuild the package with: cargo build --release\n")
  quit(status = 1)
}

cat("\n✓ Rust backend is available and loaded\n")

# Set tolerance for floating-point comparisons
TOLERANCE <- 1e-10

# Test data generation
x <- seq(1, 200, by = 1)
obs <- sin(x / 100) + 0.5
pred <- obs + rnorm(length(x), 0, 0.01)

# ============================================================================
# OBJECTIVE FUNCTIONS VALIDATION
# ============================================================================
cat("\n" %>% paste0(rep.int("-", 70), collapse = ""), "\n", sep = "")
cat("OBJECTIVE FUNCTIONS\n")
cat("-" %>% paste0(rep.int(., 70), collapse = ""), "\n", sep = "")

# RMSE
r_rmse <- sqrt(mean((obs - pred)^2))
rust_rmse <- objective_rmse_rust(obs, pred)
diff_rmse <- abs(r_rmse - rust_rmse)
status_rmse <- if (diff_rmse < TOLERANCE) "✓ PASS" else "✗ FAIL"
cat(sprintf("RMSE:       R=%.10f, Rust=%.10f, diff=%.2e %s\n",
            r_rmse, rust_rmse, diff_rmse, status_rmse))

# SSE
r_sse <- sum((obs - pred)^2)
rust_sse <- objective_sse_rust(obs, pred)
diff_sse <- abs(r_sse - rust_sse)
status_sse <- if (diff_sse < TOLERANCE * 1e3) "✓ PASS" else "✗ FAIL"  # Higher tolerance for SSE (larger values)
cat(sprintf("SSE:        R=%.10f, Rust=%.10f, diff=%.2e %s\n",
            r_sse, rust_sse, diff_sse, status_sse))

# MAE
r_mae <- mean(abs(obs - pred))
rust_mae <- objective_mae_rust(obs, pred)
diff_mae <- abs(r_mae - rust_mae)
status_mae <- if (diff_mae < TOLERANCE) "✓ PASS" else "✗ FAIL"
cat(sprintf("MAE:        R=%.10f, Rust=%.10f, diff=%.2e %s\n",
            r_mae, rust_mae, diff_mae, status_mae))

# R-squared
mean_obs <- mean(obs)
ss_tot <- sum((obs - mean_obs)^2)
ss_res <- sum((obs - pred)^2)
r_r2 <- 1.0 - (ss_res / ss_tot)
rust_r2 <- objective_r2_rust(obs, pred)
diff_r2 <- abs(r_r2 - rust_r2)
status_r2 <- if (diff_r2 < TOLERANCE) "✓ PASS" else "✗ FAIL"
cat(sprintf("R-squared:  R=%.10f, Rust=%.10f, diff=%.2e %s\n",
            r_r2, rust_r2, diff_r2, status_r2))

# ============================================================================
# SHAPE FUNCTIONS VALIDATION
# ============================================================================
cat("\n" %>% paste0(rep.int("-", 70), collapse = ""), "\n", sep = "")
cat("SHAPE FUNCTIONS\n")
cat("-" %>% paste0(rep.int(., 70), collapse = ""), "\n", sep = "")

shapes <- list(
  list(name = "uniform", params = c(0.5), ascending = NA,
       r_fn = function(x, p) sm_shape_uniform(x, p[1])),
  list(name = "gradational", params = c(50, 150), ascending = TRUE,
       r_fn = function(x, p) sm_shape_gradational(x, p, ascending = TRUE)),
  list(name = "gradational (desc)", params = c(50, 150), ascending = FALSE,
       r_fn = function(x, p) sm_shape_gradational(x, p, ascending = FALSE)),
  list(name = "exponential", params = c(1, 0.05), ascending = TRUE,
       r_fn = function(x, p) sm_shape_exponential(x, p, ascending = TRUE)),
  list(name = "wetting_front", params = c(50, 150), ascending = TRUE,
       r_fn = function(x, p) sm_shape_sigmoid(x, p, ascending = TRUE)),
  list(name = "abrupt (hard)", params = c(100, 0), ascending = TRUE,
       r_fn = function(x, p) sm_shape_abrupt(x, p, ascending = TRUE)),
  list(name = "abrupt (smooth)", params = c(100, 5), ascending = TRUE,
       r_fn = function(x, p) sm_shape_abrupt(x, p, ascending = TRUE)),
  list(name = "peak", params = c(100, 30), ascending = TRUE,
       r_fn = function(x, p) sm_shape_peak(x, p, ascending = TRUE)),
  list(name = "minimax", params = c(75, 20, 125, 20), ascending = TRUE,
       r_fn = function(x, p) sm_shape_minimax(x, p, ascending = TRUE))
)

results <- list()

for (i, shape in enumerate(shapes)) {
  shape_name <- shape$name
  params <- shape$params
  ascending <- if (is.na(shape$ascending)) TRUE else shape$ascending
  
  # Compute R result
  r_result <- shape$r_fn(x, params)
  
  # Compute Rust result
  rust_result <- shape_eval_rust(shape_name, x, params, ascending)
  
  if (is.null(rust_result)) {
    cat(sprintf("%-20s: ✗ FAIL (Rust returned NULL)\n", shape_name))
    results[[shape_name]] <- FALSE
  } else {
    # Compute max difference
    diff <- max(abs(r_result - rust_result), na.rm = TRUE)
    status <- if (diff < TOLERANCE) "✓ PASS" else "✗ FAIL"
    cat(sprintf("%-20s: max_diff=%.2e %s\n", shape_name, diff, status))
    results[[shape_name]] <- (diff < TOLERANCE)
  }
}

# ============================================================================
# SUMMARY
# ============================================================================
cat("\n" %>% paste0(rep.int("=", 70), collapse = ""), "\n", sep = "")
cat("SUMMARY\n")
cat("=" %>% paste0(rep.int(., 70), collapse = ""), "\n", sep = "")

objective_pass <- all(c(diff_rmse, diff_sse, diff_mae, diff_r2) < 
                       c(TOLERANCE, TOLERANCE*1e3, TOLERANCE, TOLERANCE))
shape_pass <- all(unlist(results))

if (objective_pass && shape_pass) {
  cat("\n✓ All validation tests PASSED\n")
  cat("Rust implementations are equivalent to R implementations.\n\n")
  quit(status = 0)
} else {
  cat("\n✗ Some validation tests FAILED\n")
  if (!objective_pass) {
    cat("  - Objective functions: CHECK VALUES ABOVE\n")
  }
  if (!shape_pass) {
    cat("  - Shape functions: CHECK VALUES ABOVE\n")
  }
  cat("\n")
  quit(status = 1)
}
