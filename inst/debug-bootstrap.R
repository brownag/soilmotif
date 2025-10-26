#' Debug Bootstrap Parameter Homogeneity
#'
#' This script diagnoses why all bootstrap parameter samples are identical
#' by examining:
#' 1. The residuals from initial fit
#' 2. The AR(1) model parameters
#' 3. The synthetic residuals being generated
#' 4. The relationship between observed data and fit quality
#'
#' Run this script to understand the root cause of degenerate bootstrap
#' Run: source("inst/debug-bootstrap.R")

cat("=============================================================================\n")
cat("DEBUG BOOTSTRAP PARAMETER HOMOGENEITY\n")
cat("=============================================================================\n\n")

library(soilmotif)

# Use the same clay spline from README
clay_spline <- inverse.rle(structure(list(
  lengths = c(19, 8, 5, 3, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 3, 4, 
              17, 7, 37, 5, 2, 2, 1, 1, 1, 2, 2, 6, 6, 6, 3, 5, 38),
  values = c(7, 6, 7, 8, 9, 10, 12, 13, 15, 17, 19, 23, 26, 28, 30, 32, 33, 35,
             36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 50,
             49, 48, 47)), class = "rle"
))

depths <- 1:200
initial_params <- c(25, 100)

cat("STEP 1: INITIAL OPTIMIZATION\n")
cat("------------------------------\n\n")

# Perform initial optimization to get fitted values
opt_result <- soilmotif::sm_optim(
  clay_spline, 
  initial_params,
  depths = depths,
  scale_method = "proportional"
)

cat("Optimized parameters:", opt_result$params, "\n")
cat("RMSE:", round(opt_result$rmse, 3), "\n\n")

# Extract fitted and residuals
fitted <- opt_result$fitted
residuals <- clay_spline - fitted

cat("Residual Statistics:\n")
cat("  Range:    [", round(min(residuals), 3), ", ", round(max(residuals), 3), "]\n", sep = "")
cat("  Mean:     ", round(mean(residuals), 3), "\n", sep = "")
cat("  Std Dev:  ", round(sd(residuals), 3), "\n", sep = "")
cat("  Variance: ", round(var(residuals), 3), "\n\n", sep = "")

# Check for significant structure in residuals
acf_vals <- acf(residuals, lag.max = 10, plot = FALSE)$acf[-1]
cat("ACF (lags 1-10):\n")
for (i in seq_along(acf_vals)) {
  cat(sprintf("  Lag %2d: %7.4f\n", i, acf_vals[i]))
}
cat("\n")

cat("STEP 2: FIT AR(1) MODEL\n")
cat("-----------------------\n\n")

# Manual AR(1) fitting to understand what Rust is doing
n <- length(residuals)
mean_res <- mean(residuals)
centered <- residuals - mean_res

gamma0 <- sum(centered^2) / n
gamma1 <- sum(centered[-n] * centered[-1]) / n
phi <- gamma1 / gamma0
sigma2 <- gamma0 * (1 - phi^2)

cat("AR(1) Model Parameters:\n")
cat("  phi (AR coef):    ", round(phi, 4), "\n", sep = "")
cat("  sigma2 (innov):   ", round(sigma2, 6), "\n", sep = "")
cat("  gamma0 (acov 0):  ", round(gamma0, 4), "\n", sep = "")
cat("  gamma1 (acov 1):  ", round(gamma1, 4), "\n\n", sep = "")

# Assess stationarity
cat("Stationarity Check:\n")
cat("  |phi| < 1: ", abs(phi) < 1, "\n", sep = "")
cat("  phi finite: ", is.finite(phi), "\n", sep = "")
cat("  sigma2 > 0: ", sigma2 > 0, "\n\n", sep = "")

cat("STEP 3: ANALYZE RESIDUAL STRUCTURE\n")
cat("------------------------------------\n\n")

# Check if residuals have meaningful structure or are nearly white noise
cat("Is residual structure degenerate?\n")
cat("  Near-zero gamma1:", abs(gamma1) < 0.001, "\n", sep = "")
cat("  Near-zero phi:   ", abs(phi) < 0.01, "\n", sep = "")
cat("  Very small sigma2:", sigma2 < 0.01, "\n", sep = "")
cat("  Residuals white noise: ", abs(phi) < 0.05, "\n\n", sep = "")

# Try resampling a few synthetic residuals manually
cat("STEP 4: SYNTHETIC RESIDUAL GENERATION\n")
cat("--------------------------------------\n\n")

set.seed(42)

cat("Generating 5 bootstrap synthetic residuals samples...\n\n")

for (b in 1:5) {
  # Resample innovations from AR(1)
  innovations <- sample(residuals - phi * c(0, residuals[-n]), 
                        size = n, replace = TRUE)
  
  # Reconstruct from AR(1)
  synth_res <- numeric(n)
  for (i in 1:n) {
    if (i == 1) {
      synth_res[i] <- innovations[i] + mean_res
    } else {
      synth_res[i] <- phi * synth_res[i-1] + innovations[i] + mean_res
    }
  }
  
  # Create synthetic observed
  synth_obs <- fitted + synth_res
  
  cat(sprintf("Bootstrap replicate %d:\n", b))
  cat("  Synthetic range:  [", round(min(synth_obs), 2), ", ", round(max(synth_obs), 2), "]\n", sep = "")
  cat("  Synthetic mean:   ", round(mean(synth_obs), 2), "\n", sep = "")
  cat("  Difference from original (SSE):", round(sum((synth_obs - clay_spline)^2), 2), "\n", sep = "")
  
  # What happens if we optimize this synthetic data?
  opt_test <- tryCatch(
    soilmotif::sm_optim(
      synth_obs, 
      opt_result$params,  # Start from previous optimum
      depths = depths,
      scale_method = "proportional"
    ),
    error = function(e) list(params = NA, rmse = NA)
  )
  
  cat("  Optimized params: [", paste(round(opt_test$params, 4), collapse = ", "), "]\n", sep = "")
  cat("  Optimized RMSE:   ", round(opt_test$rmse, 3), "\n\n", sep = "")
}

cat("\nSTEP 5: ACTUAL BOOTSTRAP RUN\n")
cat("----------------------------\n\n")

cat("Running actual bootstrap (10 replicates for speed)...\n\n")

boot_small <- soilmotif::sm_optim_bootstrap(
  observed = clay_spline,
  depths = depths,
  initial_params = opt_result$params,
  shape_family = "sigmoid",
  n_bootstrap = 10,
  method = "sieve",
  seed = 42
)

cat("Bootstrap Results:\n")
cat("  Successful: ", boot_small$n_successful, "\n", sep = "")
cat("  Failed:     ", boot_small$n_failed, "\n\n", sep = "")

if (boot_small$n_successful > 0) {
  cat("Parameter samples (first 10 replicates):\n")
  print(boot_small$param_samples)
  
  cat("\nParameter statistics:\n")
  for (p in 1:ncol(boot_small$param_samples)) {
    col <- boot_small$param_samples[, p]
    cat(sprintf("  Param %d: mean=%8.4f, sd=%8.6f, range=[%8.4f, %8.4f]\n",
                p, mean(col), sd(col), min(col), max(col)))
  }
  
  cat("\nRMSE samples (first 10):\n")
  print(boot_small$rmse_samples[1:10])
  
  cat("\nR² samples (first 10):\n")
  print(boot_small$r2_samples[1:10])
}

cat("\n")
cat("=============================================================================\n")
cat("ANALYSIS\n")
cat("=============================================================================\n\n")

cat("Key findings:\n\n")

if (abs(phi) < 0.05) {
  cat("❌ PROBLEM IDENTIFIED:\n")
  cat("The AR(1) coefficient is very small (near white noise). This means:\n")
  cat("  1. Residuals have minimal autocorrelation\n")
  cat("  2. Resampling produces nearly independent residuals\n")
  cat("  3. All synthetic datasets are VERY similar to original\n")
  cat("  4. Optimization converges to nearly identical parameters\n\n")
  
  cat("Root cause: The sigmoid fit is TOO GOOD or residuals are TOO SMALL.\n")
  cat("If residuals show no structure, bootstrap has nothing to work with.\n\n")
  
  cat("Possible solutions:\n")
  cat("  1. Use parametric bootstrap instead (better for small residuals)\n")
  cat("  2. Check if model is over-fitting to the data\n")
  cat("  3. Verify proportional scaling is not forcing output to extrema\n")
  cat("  4. Check if residuals are actually independent\n\n")
} else {
  cat("✓ AR(1) coefficient is reasonable: phi =", round(phi, 4), "\n")
  cat("Bootstrap should show parameter variation. Check Rust FFI.\n\n")
}

cat("Expected vs actual bootstrap behavior:\n")
cat("  Expected: Parameter samples vary across replicates\n")
cat("  Actual:   Parameter samples all identical\n")
cat("  Cause:    Either degenerate residuals OR optimizer getting stuck\n\n")

cat("=============================================================================\n")
