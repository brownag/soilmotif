#!/usr/bin/env Rscript

# Bootstrap visualization examples
# Shows parameter distributions, confidence intervals, and method comparisons

library(soilmotif)
library(graphics)

set.seed(42)
depths <- 1:200

# =========================================================================
# Setup: Create test data
# =========================================================================

# Synthetic clay data with moderate autocorrelation
base_shape <- sm_motif(depths, c(50, 150))
phi <- 0.5
sigma <- 2
residuals <- numeric(200)
residuals[1] <- rnorm(1, 0, sigma)
for (i in 2:200) {
  residuals[i] <- phi * residuals[i-1] + rnorm(1, 0, sigma)
}
clay_data <- base_shape + residuals

# Run bootstrap with block method
result_block <- sm_optim_bootstrap(
  observed = clay_data,
  depths = depths,
  initial_params = c(50, 150),
  shape_family = "sigmoid",
  n_bootstrap = 100,
  method = "block",
  seed = 42
)

# Run bootstrap with parametric method
result_param <- sm_optim_bootstrap(
  observed = clay_data,
  depths = depths,
  initial_params = c(50, 150),
  shape_family = "sigmoid",
  n_bootstrap = 100,
  method = "parametric",
  seed = 42
)

# =========================================================================
# Visualization 1: Parameter Distributions (Histogram + Density)
# =========================================================================

par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))

# Param 1 - Block Bootstrap
hist(result_block$param_samples[, 1],
     main = "Block Bootstrap: Parameter 1 Distribution",
     xlab = "Parameter 1 (Position)",
     ylab = "Frequency",
     col = "steelblue",
     border = "white",
     breaks = 20)
abline(v = result_block$summary$param_mean[1],
       col = "red", lwd = 2, lty = 2,
       label = paste0("Mean = ", round(result_block$summary$param_mean[1], 2)))
legend("topright",
       c(paste0("Mean = ", round(result_block$summary$param_mean[1], 2)),
         paste0("SD = ", round(result_block$summary$param_sd[1], 2))),
       bty = "n", cex = 0.9)

# Param 2 - Block Bootstrap
hist(result_block$param_samples[, 2],
     main = "Block Bootstrap: Parameter 2 Distribution",
     xlab = "Parameter 2 (Steepness)",
     ylab = "Frequency",
     col = "steelblue",
     border = "white",
     breaks = 20)
abline(v = result_block$summary$param_mean[2],
       col = "red", lwd = 2, lty = 2)
legend("topright",
       c(paste0("Mean = ", round(result_block$summary$param_mean[2], 2)),
         paste0("SD = ", round(result_block$summary$param_sd[2], 2))),
       bty = "n", cex = 0.9)

# Param 1 - Parametric Bootstrap
hist(result_param$param_samples[, 1],
     main = "Parametric Bootstrap: Parameter 1 Distribution",
     xlab = "Parameter 1 (Position)",
     ylab = "Frequency",
     col = "coral",
     border = "white",
     breaks = 20)
abline(v = result_param$summary$param_mean[1],
       col = "red", lwd = 2, lty = 2)
legend("topright",
       c(paste0("Mean = ", round(result_param$summary$param_mean[1], 2)),
         paste0("SD = ", round(result_param$summary$param_sd[1], 2))),
       bty = "n", cex = 0.9)

# Param 2 - Parametric Bootstrap
hist(result_param$param_samples[, 2],
     main = "Parametric Bootstrap: Parameter 2 Distribution",
     xlab = "Parameter 2 (Steepness)",
     ylab = "Frequency",
     col = "coral",
     border = "white",
     breaks = 20)
abline(v = result_param$summary$param_mean[2],
       col = "red", lwd = 2, lty = 2)
legend("topright",
       c(paste0("Mean = ", round(result_param$summary$param_mean[2], 2)),
         paste0("SD = ", round(result_param$summary$param_sd[2], 2))),
       bty = "n", cex = 0.9)

# =========================================================================
# Visualization 2: Confidence Intervals Comparison
# =========================================================================

par(mfrow = c(1, 1), mar = c(6, 8, 3, 2))

# Create comparison data
methods <- c("Block", "Parametric")
param1_means <- c(result_block$summary$param_mean[1], result_param$summary$param_mean[1])
param1_lower <- c(result_block$summary$param_ci_lower[1], result_param$summary$param_ci_lower[1])
param1_upper <- c(result_block$summary$param_ci_upper[1], result_param$summary$param_ci_upper[1])

y_pos <- 1:length(methods)
plot(NULL,
     xlim = c(min(param1_lower) - 10, max(param1_upper) + 10),
     ylim = c(0.5, length(methods) + 0.5),
     xlab = "Parameter 1 (Position)",
     ylab = "",
     main = "95% Confidence Intervals: Parameter 1 Comparison",
     yaxt = "n",
     bty = "n")

axis(2, at = y_pos, labels = methods, las = 1)

# Add confidence interval lines and points
for (i in 1:length(methods)) {
  # Draw CI line
  lines(c(param1_lower[i], param1_upper[i]), c(i, i),
        lwd = 3,
        col = if (methods[i] == "Block") "steelblue" else "coral")

  # Draw mean point
  points(param1_means[i], i,
         pch = 21,
         cex = 2,
         bg = if (methods[i] == "Block") "steelblue" else "coral",
         col = "black",
         lwd = 2)

  # Add text with values
  text(param1_upper[i] + 5, i,
       sprintf("%.1f +/- %.1f",
               param1_means[i],
               (param1_upper[i] - param1_lower[i]) / (2 * 1.96)),
       adj = c(0, 0.5),
       cex = 0.9)
}

# Add vertical reference line
abline(v = result_block$summary$param_mean[1], lty = 2, col = "gray", lwd = 1)

# =========================================================================
# Visualization 3: Fitted Curves with Bootstrap Uncertainty Band
# =========================================================================

par(mfrow = c(1, 1), mar = c(5, 5, 4, 2))

# Evaluate fitted curves for bootstrap samples
n_samples <- min(20, nrow(result_block$param_samples))  # Use first 20 for clarity
fitted_samples <- sapply(1:n_samples, function(i) {
  sm_motif(clay_data, result_block$param_samples[i, ])
})

# Compute bootstrap envelope
fitted_envelope_lower <- apply(result_block$param_samples, 1, function(p) {
  sm_motif(clay_data, p)
}) |> apply(1, quantile, probs = 0.025)

fitted_envelope_upper <- apply(result_block$param_samples, 1, function(p) {
  sm_motif(clay_data, p)
}) |> apply(1, quantile, probs = 0.975)

# Plot
plot(clay_data ~ depths,
     main = "Fitted Curve with Bootstrap 95% Uncertainty Band",
     xlab = "Clay %",
     ylab = "Depth (cm)",
     pch = 20,
     cex = 0.7,
     col = rgb(0, 0, 0, 0.3),
     xlim = c(0, 60),
     ylim = c(200, 0))

# Add uncertainty band
polygon(c(fitted_envelope_lower, rev(fitted_envelope_upper)),
        c(depths, rev(depths)),
        col = rgb(0.2, 0.5, 0.8, 0.2),
        border = NA)

# Add best fit line (mean)
fitted_mean <- sm_motif(clay_data, result_block$summary$param_mean)
lines(fitted_mean ~ depths, col = "steelblue", lwd = 2.5, label = "Mean fit")

# Add a few bootstrap replicates (for visualization)
for (i in 1:min(3, n_samples)) {
  lines(fitted_samples[, i] ~ depths,
        col = rgb(0.2, 0.5, 0.8, 0.3),
        lwd = 1,
        lty = 2)
}

legend("bottomleft",
       c("Observed data",
         "Mean fit",
         "95% CI envelope",
         "Bootstrap samples"),
       pch = c(20, NA, NA, NA),
       lty = c(NA, 1, NA, 2),
       lwd = c(NA, 2.5, NA, 1),
       col = c("black", "steelblue", "steelblue", "steelblue"),
       bg = "white",
       cex = 0.9)

# =========================================================================
# Visualization 4: Parameter Correlation Scatter Plot
# =========================================================================

par(mfrow = c(1, 1), mar = c(5, 5, 4, 2))

plot(result_block$param_samples,
     main = "Bootstrap Parameter Samples: Block Bootstrap",
     xlab = "Parameter 1 (Position)",
     ylab = "Parameter 2 (Steepness)",
     pch = 21,
     bg = rgb(0.2, 0.5, 0.8, 0.5),
     col = "steelblue",
     cex = 1.2)

# Add mean point
points(result_block$summary$param_mean[1], result_block$summary$param_mean[2],
       pch = 23,
       cex = 3,
       bg = "red",
       col = "darkred",
       lwd = 2)

# Add confidence ellipse (simple rectangle)
rect(result_block$summary$param_ci_lower[1], result_block$summary$param_ci_lower[2],
     result_block$summary$param_ci_upper[1], result_block$summary$param_ci_upper[2],
     border = "red", lty = 2, lwd = 2)

legend("topright",
       c("Bootstrap samples",
         "Mean (red diamond)",
         "95% CI box"),
       pch = c(21, 23, NA),
       lty = c(NA, NA, 2),
       col = c("steelblue", "darkred", "red"),
       bg = "white",
       cex = 0.9)

cat("\nVisualization complete! Check your plots.\n")
