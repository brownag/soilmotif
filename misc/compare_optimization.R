#!/usr/bin/env Rscript
# Compare R vs Rust optimization results visually
# This script demonstrates the parameter differences and fit quality

library(soilmotif)

# Create test data - use the exact same data from integration tests
# This creates a step-like profile: 10 for first 50, ramp 10-40 over next 100, 40 for last 50
depth <- 1:200
observed <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))

# Initial parameters for optimization - use different starting points
initial_params <- c(100, 20)  # Same as integration tests

# Initial parameters for optimization - use different starting points
initial_params <- c(40, 60)  # Different from true values to test convergence

cat("=== Optimization Comparison: R vs Rust ===\n")
cat("Test data: step profile (10→40) with initial params:", paste(initial_params, collapse = ", "), "\n\n")

# Run R optimization
cat("Running R optimization...\n")
r_start <- Sys.time()
r_result <- sm_optim(observed, initial_params, FUN = sm_shape_wetting_front, use_rust = FALSE)
r_time <- difftime(Sys.time(), r_start, units = "secs")
r_params <- attr(r_result, 'par')
r_rmse <- sm_optim_rmse(r_result, observed)

cat(sprintf("R Results:\n"))
cat(sprintf("  Parameters: %.2f, %.2f\n", r_params[1], r_params[2]))
cat(sprintf("  RMSE: %.4f\n", r_rmse))
cat(sprintf("  Time: %.3f seconds\n\n", as.numeric(r_time)))

# Run Rust optimization
cat("Running Rust optimization...\n")
rust_start <- Sys.time()
rust_result <- sm_optim(observed, initial_params, FUN = sm_shape_wetting_front, use_rust = TRUE)
rust_time <- difftime(Sys.time(), rust_start, units = "secs")
rust_params <- attr(rust_result, 'par')
rust_rmse <- sm_optim_rmse(rust_result, observed)

cat(sprintf("Rust Results:\n"))
cat(sprintf("  Parameters: %.2f, %.2f\n", rust_params[1], rust_params[2]))
cat(sprintf("  RMSE: %.4f\n", rust_rmse))
cat(sprintf("  Time: %.3f seconds\n\n", as.numeric(rust_time)))

# Calculate differences
param_diff <- abs(r_params - rust_params)
rmse_diff <- abs(r_rmse - rust_rmse)
speedup <- as.numeric(r_time) / as.numeric(rust_time)

cat("Comparison:\n")
cat(sprintf("  Parameter differences: %.2f, %.2f\n", param_diff[1], param_diff[2]))
cat(sprintf("  RMSE difference: %.4f\n", rmse_diff))
cat(sprintf("  Speedup: %.1fx\n\n", speedup))

# Create visualization
cat("Creating comparison plot...\n")

# Set up the plot
png("optimization_comparison.png", width = 1200, height = 800, res = 100)

# Create a 2x2 layout
par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))

# Plot 1: Data and fits
plot(depth, observed, type = "l", col = "gray40", lwd = 2,
     xlab = "Depth", ylab = "Property Value",
     main = "Optimization Results Comparison",
     ylim = range(c(observed, r_result, rust_result)))
lines(depth, r_result, col = "blue", lwd = 2)
lines(depth, rust_result, col = "red", lwd = 2)

legend("bottomright",
       legend = c("Observed data", "R fit", "Rust fit"),
       col = c("gray40", "blue", "red"),
       lty = c(1, 1, 1), lwd = c(2, 2, 2),
       cex = 0.8)

# Plot 2: Residuals comparison
r_residuals <- observed - r_result
rust_residuals <- observed - rust_result

plot(depth, r_residuals, type = "l", col = "blue",
     xlab = "Depth", ylab = "Residuals",
     main = "Fit Residuals",
     ylim = range(c(r_residuals, rust_residuals)))
lines(depth, rust_residuals, col = "red")
abline(h = 0, lty = 2, col = "gray")
legend("topright",
       legend = c("R residuals", "Rust residuals"),
       col = c("blue", "red"), lty = 1, cex = 0.8)

# Plot 3: Parameter comparison
param_names <- c("Start Depth", "End Depth")
barplot(rbind(r_params, rust_params, initial_params),
        beside = TRUE,
        names.arg = param_names,
        col = c("blue", "red", "gray"),
        main = "Parameter Comparison",
        ylab = "Parameter Value")
legend("topright",
       legend = c("R optimized", "Rust optimized", "Initial values"),
       fill = c("blue", "red", "gray"), cex = 0.8)

# Plot 4: Performance comparison
methods <- c("R", "Rust")
times <- c(as.numeric(r_time), as.numeric(rust_time))
rmses <- c(r_rmse, rust_rmse)

barplot(rbind(times, rmses),
        beside = TRUE,
        names.arg = methods,
        col = c("lightblue", "lightcoral"),
        main = "Performance Comparison",
        ylab = "Value")
legend("topright",
       legend = c("Time (seconds)", "RMSE"),
       fill = c("lightblue", "lightcoral"), cex = 0.8)

# Add text annotations
text(2.5, max(times) * 0.8,
     sprintf("Speedup: %.1fx", speedup),
     cex = 1.2, font = 2)
text(2.5, max(rmses) * 0.9,
     sprintf("RMSE diff: %.4f", rmse_diff),
     cex = 1.0)

dev.off()

cat("Plot saved as 'optimization_comparison.png'\n")

# Print summary table
cat("\n=== Summary Table ===\n")
cat(sprintf("%-10s %-15s %-15s %-10s %-10s\n", "Method", "Param1", "Param2", "RMSE", "Time(s)"))
cat(sprintf("%-10s %-15s %-15s %-10s %-10s\n", "Initial", sprintf("%.2f", initial_params[1]), sprintf("%.2f", initial_params[2]), "-", "-"))
cat(sprintf("%-10s %-15s %-15s %-10s %-10s\n", "R", sprintf("%.2f", r_params[1]), sprintf("%.2f", r_params[2]), sprintf("%.4f", r_rmse), sprintf("%.3f", as.numeric(r_time))))
cat(sprintf("%-10s %-15s %-15s %-10s %-10s\n", "Rust", sprintf("%.2f", rust_params[1]), sprintf("%.2f", rust_params[2]), sprintf("%.4f", rust_rmse), sprintf("%.3f", as.numeric(rust_time))))

cat("\nAnalysis complete!\n")