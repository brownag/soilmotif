#!/usr/bin/env Rscript

# Quick Start: Bootstrap Visualization
# Simple example showing how to visualize bootstrap results

library(soilmotif)
library(graphics)

set.seed(42)

# Step 1: Create test data
cat("Step 1: Creating test data...\n")
depths <- 1:200
observed <- sm_motif(depths, c(50, 150)) + rnorm(200, 0, 2.5)

# Step 2: Run bootstrap
cat("Step 2: Running block bootstrap...\n")
result <- sm_optim_bootstrap(
  observed = observed,
  depths = depths,
  initial_params = c(50, 150),
  shape_family = "sigmoid",
  n_bootstrap = 100,
  method = "block",
  seed = 42
)

cat("Step 3: Creating visualizations...\n\n")

# =========================================================================
# Visualization 1: Simple Parameter Distribution
# =========================================================================

par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))

hist(result$param_samples[, 1],
     main = "Bootstrap Parameter 1 Distribution",
     xlab = "Parameter 1 (Position)",
     ylab = "Frequency",
     col = "steelblue",
     border = "white",
     breaks = 20)
abline(v = result$summary$param_mean[1], col = "red", lwd = 2, lty = 2)
legend("topright",
       sprintf("Mean = %.2f\nSD = %.2f\nCI = [%.1f, %.1f]",
               result$summary$param_mean[1],
               result$summary$param_sd[1],
               result$summary$param_ci_lower[1],
               result$summary$param_ci_upper[1]),
       bty = "n", cex = 0.9)

hist(result$param_samples[, 2],
     main = "Bootstrap Parameter 2 Distribution",
     xlab = "Parameter 2 (Steepness)",
     ylab = "Frequency",
     col = "steelblue",
     border = "white",
     breaks = 20)
abline(v = result$summary$param_mean[2], col = "red", lwd = 2, lty = 2)
legend("topright",
       sprintf("Mean = %.2f\nSD = %.2f\nCI = [%.1f, %.1f]",
               result$summary$param_mean[2],
               result$summary$param_sd[2],
               result$summary$param_ci_lower[2],
               result$summary$param_ci_upper[2]),
       bty = "n", cex = 0.9)

# =========================================================================
# Visualization 2: Fitted Curve with Uncertainty Band
# =========================================================================

par(mfrow = c(1, 1), mar = c(5, 5, 4, 2))

# Compute uncertainty envelope
fitted_envelope_lower <- apply(result$param_samples, 1, function(p) {
  sm_motif(observed, p)
}) |> apply(1, quantile, probs = 0.025)

fitted_envelope_upper <- apply(result$param_samples, 1, function(p) {
  sm_motif(observed, p)
}) |> apply(1, quantile, probs = 0.975)

# Plot
plot(observed ~ depths,
     main = "Fit with 95% Bootstrap Uncertainty Band",
     xlab = "Property Value",
     ylab = "Depth (cm)",
     pch = 20,
     cex = 0.7,
     col = rgb(0, 0, 0, 0.3),
     ylim = c(200, 0))

# Add uncertainty band
polygon(c(fitted_envelope_lower, rev(fitted_envelope_upper)),
        c(depths, rev(depths)),
        col = rgb(0.2, 0.5, 0.8, 0.2),
        border = NA)

# Add best fit
fitted_mean <- sm_motif(observed, result$summary$param_mean)
lines(fitted_mean ~ depths, col = "steelblue", lwd = 2.5)

legend("bottomleft",
       c("Observed data", "Mean fit", "95% CI"),
       pch = c(20, NA, NA),
       lty = c(NA, 1, NA),
       lwd = c(NA, 2.5, NA),
       col = c("black", "steelblue", "steelblue"),
       bg = "white")

# =========================================================================
# Visualization 3: Parameter Correlation
# =========================================================================

par(mfrow = c(1, 1), mar = c(5, 5, 4, 2))

plot(result$param_samples,
     main = "Bootstrap Parameter Correlation",
     xlab = "Parameter 1",
     ylab = "Parameter 2",
     pch = 21,
     bg = rgb(0.2, 0.5, 0.8, 0.5),
     col = "steelblue",
     cex = 1.2)

points(result$summary$param_mean[1], result$summary$param_mean[2],
       pch = 23,
       cex = 3,
       bg = "red",
       col = "darkred",
       lwd = 2)

legend("topright",
       c("Bootstrap samples", "Mean"),
       pch = c(21, 23),
       col = c("steelblue", "darkred"),
       bg = "white")

# =========================================================================
# Print Summary
# =========================================================================

cat("\n========================================\n")
cat("Bootstrap Results Summary\n")
cat("========================================\n")
cat("Method used:    ", result$method_used, "\n")
cat("Successful:     ", result$n_successful, "/ 100\n\n")

cat("Parameter 1:\n")
cat("  Mean:         ", sprintf("%.2f", result$summary$param_mean[1]), "\n")
cat("  SD:           ", sprintf("%.2f", result$summary$param_sd[1]), "\n")
cat("  95% CI:       [", sprintf("%.2f", result$summary$param_ci_lower[1]), ", ",
                        sprintf("%.2f", result$summary$param_ci_upper[1]), "]\n\n")

cat("Parameter 2:\n")
cat("  Mean:         ", sprintf("%.2f", result$summary$param_mean[2]), "\n")
cat("  SD:           ", sprintf("%.2f", result$summary$param_sd[2]), "\n")
cat("  95% CI:       [", sprintf("%.2f", result$summary$param_ci_lower[2]), ", ",
                        sprintf("%.2f", result$summary$param_ci_upper[2]), "]\n\n")

cat("========================================\n")
cat("Visualizations complete!\n")
