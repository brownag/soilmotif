#' Diagnostic Tests for Scaling, Bootstrap, and R² Issues
#'
#' This script validates three critical fixes:
#' 1. Natural asymptotes are preserved during proportional scaling
#' 2. Bootstrap parameter samples show realistic variation
#' 3. R² values stay in valid range [-Inf, 1] with no NaN or values > 1
#'
#' Run this script to verify fixes are working correctly:
#'   source("inst/diagnostic-tests.R")
#'
#' @keywords internal
#' @noRd

cat("=============================================================================\n")
cat("DIAGNOSTIC TESTS: Scaling Asymptotes, Bootstrap Parameters, and R² Validation\n")
cat("=============================================================================\n\n")

# ============================================================================
# TEST 1: Natural Asymptotes Preservation in Proportional Scaling
# ============================================================================
cat("TEST 1: NATURAL ASYMPTOTES PRESERVATION\n")
cat("-----------------------------------------\n\n")

cat("Purpose: Verify that sigmoid natural asymptotes (~0.07, ~0.93) are preserved\n")
cat("         during proportional scaling, not forced to [min(obs), max(obs)].\n\n")

# Generate synthetic data
set.seed(42)
depths <- 1:200
true_params <- c(100, 50, 0.05, 50)
observed <- soilmotif::sm_motif(depths, true_params, 
                                 FUN = soilmotif::sm_shape_sigmoid) + 
            rnorm(200, 0, 2)

cat("Data characteristics:\n")
cat("  - Observed range: [", round(min(observed), 2), ", ", round(max(observed), 2), "]\n", sep = "")
cat("  - Observed variance: ", round(var(observed), 2), "\n", sep = "")
cat("  - Natural sigmoid asymptotes: ~[0.07, 0.93] (in unscaled sigmoid space)\n\n")

# Test proportional scaling
cat("Step 1: Compute sigmoid shape function values\n")
sigmoid_vals <- soilmotif::sm_shape_sigmoid(depths, true_params)
sigmoid_range <- c(min(sigmoid_vals), max(sigmoid_vals))
cat("  - Sigmoid output range: [", round(sigmoid_range[1], 4), ", ", 
    round(sigmoid_range[2], 4), "]\n", sep = "")
cat("  - This reflects natural asymptotes + convergence\n\n")

cat("Step 2: Apply proportional scaling to observed data range\n")
# Manual scaling to verify formula
observed_range <- c(min(observed), max(observed))
scaled_proportionally <- observed_range[1] + 
  (sigmoid_vals - sigmoid_range[1]) / (sigmoid_range[2] - sigmoid_range[1]) * 
  (observed_range[2] - observed_range[1])

cat("  - Proportional scaling preserves sigmoid shape while fitting data range\n")
cat("  - Fitted range: [", round(min(scaled_proportionally), 2), ", ", 
    round(max(scaled_proportionally), 2), "]\n", sep = "")
cat("  - Expected: Slightly smaller than observed range due to preserved asymptotes\n\n")

# Verify that proportional scaling does NOT force asymptotes to extrema
tolerance <- 0.5  # Allow small numerical error
forces_to_extrema <- (abs(min(scaled_proportionally) - min(observed)) < tolerance) &&
                      (abs(max(scaled_proportionally) - max(observed)) < tolerance)

if (forces_to_extrema) {
  cat("  ❌ FAIL: Proportional scaling forced asymptotes to data extrema\n")
  cat("     This indicates the scaling is not truly preserving asymptotes.\n")
} else {
  cat("  ✓ PASS: Proportional scaling preserved natural asymptotes\n")
  cat("     (fitted range slightly smaller than observed, as expected)\n")
}

# Calculate asymptote preservation metric
asymptote_preservation <- (sigmoid_range[2] - sigmoid_range[1]) / (observed_range[2] - observed_range[1])
cat("  - Asymptote preservation ratio: ", round(asymptote_preservation, 3), 
    " (closer to 1 means better preservation)\n\n")

# ============================================================================
# TEST 2: Bootstrap Parameter Variation
# ============================================================================
cat("\nTEST 2: BOOTSTRAP PARAMETER VARIATION\n")
cat("--------------------------------------\n\n")

cat("Purpose: Verify bootstrap samples show realistic parameter variation,\n")
cat("         not zero variance (all identical or NaN values).\n\n")

cat("Step 1: Fit initial model\n")
initial_params <- c(100, 50, 0.05, 50)
opt_result <- soilmotif::sm_optim(
  observed = observed,
  params = initial_params,
  depths = depths,
  FUN = soilmotif::sm_shape_sigmoid,
  OPTFUN = soilmotif::sm_optim_rmse,
  scale_method = "proportional"
)

cat("  - Optimized parameters: [",
    paste(round(opt_result$params, 4), collapse = ", "), "]\n", sep = "")
cat("  - RMSE: ", round(opt_result$rmse, 2), "\n\n", sep = "")

cat("Step 2: Run bootstrap with modest sample size (100 replicates)\n")
# Note: Using parametric bootstrap for faster testing
boot_result <- soilmotif::sm_optim_bootstrap(
  observed = observed,
  depths = depths,
  initial_params = opt_result$params,
  shape_family = "sigmoid",
  n_bootstrap = 100,
  method = "parametric",
  seed = 42
)

cat("  - Successful bootstrap replicates: ", boot_result$n_successful, "/100\n", sep = "")
cat("  - Failed bootstrap replicates: ", boot_result$n_failed, "\n\n", sep = "")

cat("Step 3: Analyze parameter variation across bootstrap samples\n")
param_means <- boot_result$summary$param_mean
param_sds <- boot_result$summary$param_sd
param_cis_lower <- boot_result$summary$param_ci_lower
param_cis_upper <- boot_result$summary$param_ci_upper

cat("  Parameter statistics from bootstrap:\n")
for (i in seq_along(param_means)) {
  cat(sprintf("    Param %d: mean=%.4f, sd=%.4f, 95%% CI=[%.4f, %.4f]\n",
              i, param_means[i], param_sds[i], param_cis_lower[i], param_cis_upper[i]))
}

cat("\n  Checking for zero variance (corruption indicator):\n")
zero_var_params <- which(param_sds < 1e-8)
if (length(zero_var_params) > 0) {
  cat("  ❌ FAIL: Parameters with zero variance detected:", 
      paste(zero_var_params, collapse = ", "), "\n")
  cat("     This indicates bootstrap samples are identical or corrupted.\n")
} else {
  cat("  ✓ PASS: All parameters show realistic variation\n")
}

# Check if CIs are meaningful (not identical to point estimate)
zero_ci_width <- which(abs(param_cis_upper - param_cis_lower) < 1e-8)
if (length(zero_ci_width) > 0) {
  cat("  ⚠ WARNING: Parameters with zero CI width detected:", 
      paste(zero_ci_width, collapse = ", "), "\n")
}

cat("\n")

# ============================================================================
# TEST 3: R² Validity
# ============================================================================
cat("\nTEST 3: R² VALIDITY AND NUMERICAL STABILITY\n")
cat("-------------------------------------------\n\n")

cat("Purpose: Verify R² values stay in valid range [-Inf, 1] with no NaN/Inf.\n")
cat("         Negative R² indicates predictions worse than mean (valid).\n")
cat("         R² > 1 or NaN indicates numerical problems.\n\n")

cat("Step 1: Check original fit R²\n")
original_r2 <- 1 - (sum((observed - opt_result$fitted)^2) / sum((observed - mean(observed))^2))
cat("  - Original fit R²: ", round(original_r2, 4), "\n", sep = "")
cat("  - Valid range check: ", if (original_r2 <= 1 && !is.nan(original_r2)) "✓ PASS" else "❌ FAIL", "\n\n", sep = "")

cat("Step 2: Check bootstrap R² samples\n")
rmse_samples <- boot_result$rmse_samples
r2_samples <- boot_result$r2_samples

n_r2_above_1 <- sum(r2_samples > 1, na.rm = TRUE)
n_r2_nan <- sum(is.nan(r2_samples))
n_r2_inf <- sum(is.infinite(r2_samples))

cat("  - Total R² samples: ", length(r2_samples), "\n", sep = "")
cat("  - R² > 1 (invalid): ", n_r2_above_1, "\n", sep = "")
cat("  - R² = NaN (invalid): ", n_r2_nan, "\n", sep = "")
cat("  - R² = ±Inf (invalid): ", n_r2_inf, "\n", sep = "")

valid_r2_samples <- r2_samples[!is.nan(r2_samples) & !is.infinite(r2_samples) & r2_samples <= 1]
negative_r2_count <- sum(valid_r2_samples < 0, na.rm = TRUE)

cat("\n  Valid R² statistics:\n")
cat("    - Valid samples: ", length(valid_r2_samples), "\n", sep = "")
cat("    - Negative R² (worse than mean): ", negative_r2_count, "\n", sep = "")
cat("    - Mean R²: ", round(mean(valid_r2_samples, na.rm = TRUE), 4), "\n", sep = "")
cat("    - Range: [", round(min(valid_r2_samples, na.rm = TRUE), 4), ", ",
    round(max(valid_r2_samples, na.rm = TRUE), 4), "]\n", sep = "")

if (n_r2_above_1 > 0 || n_r2_nan > 0 || n_r2_inf > 0) {
  cat("\n  ❌ FAIL: Invalid R² values detected\n")
  cat("     Check AR(1) model fitting and residual structure\n")
} else {
  cat("\n  ✓ PASS: All R² values in valid range\n")
  if (negative_r2_count > 0) {
    cat("  ℹ INFO: Some bootstrap fits show negative R² (predictions worse than mean)\n")
    cat("          This is valid and indicates resampling variation.\n")
  }
}

cat("\n")

# ============================================================================
# SUMMARY
# ============================================================================
cat("=============================================================================\n")
cat("TEST SUMMARY\n")
cat("=============================================================================\n\n")

test_results <- list(
  asymptotes_preserved = !forces_to_extrema,
  bootstrap_params_vary = length(zero_var_params) == 0,
  r2_valid = n_r2_above_1 == 0 && n_r2_nan == 0 && n_r2_inf == 0
)

cat("Results:\n")
cat("  1. Natural asymptotes preserved:", if (test_results$asymptotes_preserved) "✓" else "❌", "\n")
cat("  2. Bootstrap parameter variation:", if (test_results$bootstrap_params_vary) "✓" else "❌", "\n")
cat("  3. R² validity checks:", if (test_results$r2_valid) "✓" else "❌", "\n")

cat("\n")

if (all(unlist(test_results))) {
  cat("✓ ALL TESTS PASSED\n")
  cat("The fixes for scaling, bootstrap, and R² have been successfully implemented.\n")
} else {
  cat("❌ SOME TESTS FAILED\n")
  cat("Additional investigation needed for failed checks above.\n")
}

cat("=============================================================================\n")
