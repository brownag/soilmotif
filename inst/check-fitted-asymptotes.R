#' Quick Check: Fitted Line Asymptotes
#' 
#' Verify whether proportional scaling is forcing fitted values to 
#' observed min/max or preserving natural asymptotes
#'
#' Run: Rscript inst/check-fitted-asymptotes.R

library(soilmotif)

# Recreate the clay spline example from README
clay_spline <- inverse.rle(structure(list(
  lengths = c(19, 8, 5, 3, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 3, 4, 
              17, 7, 37, 5, 2, 2, 1, 1, 1, 2, 2, 6, 6, 6, 3, 5, 38),
  values = c(7, 6, 7, 8, 9, 10, 12, 13, 15, 17, 19, 23, 26, 28, 30, 32, 33, 35,
             36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 50,
             49, 48, 47)), class = "rle"
))

depths <- 1:200

cat("=============================================================================\n")
cat("CHECK: FITTED LINE ASYMPTOTES\n")
cat("=============================================================================\n\n")

cat("Observed data range: [", min(clay_spline), ", ", max(clay_spline), "]\n", sep = "")
cat("Observed mean:      ", round(mean(clay_spline), 2), "\n\n", sep = "")

# Fit with proportional scaling
opt_result <- sm_optim(
  clay_spline,
  c(25, 100),
  depths = depths,
  scale_method = "proportional"
)

fitted <- opt_result$fitted

cat("Fitted line range:  [", min(fitted), ", ", max(fitted), "]\n", sep = "")
cat("Fitted line mean:   ", round(mean(fitted), 2), "\n\n", sep = "")

cat("Optimized parameters: [", paste(round(opt_result$params, 4), collapse = ", "), "]\n\n", sep = "")

# Calculate what the natural sigmoid asymptotes would be
# Sigmoid naturally asymptotes at approximately [0.07, 0.93] in [0,1] space
# So the fitted values should asymptote at approximately:
# lower_asymptote ≈ min(obs) + 0.07 * (max(obs) - min(obs))
# upper_asymptote ≈ min(obs) + 0.93 * (max(obs) - min(obs))

obs_min <- min(clay_spline)
obs_max <- max(clay_spline)
obs_range <- obs_max - obs_min

expected_lower_asymptote <- obs_min + 0.07 * obs_range
expected_upper_asymptote <- obs_min + 0.93 * obs_range

cat("Expected asymptotes (if preserving sigmoid's [0.07, 0.93]):\n")
cat("  Lower: ", round(expected_lower_asymptote, 2), "\n", sep = "")
cat("  Upper: ", round(expected_upper_asymptote, 2), "\n\n", sep = "")

cat("Actual asymptotes (min/max of fitted line):\n")
cat("  Lower: ", round(min(fitted), 2), "\n", sep = "")
cat("  Upper: ", round(max(fitted), 2), "\n\n", sep = "")

# Compare
diff_lower <- abs(min(fitted) - expected_lower_asymptote)
diff_upper <- abs(max(fitted) - expected_upper_asymptote)

cat("Difference from expected:\n")
cat("  Lower: ", round(diff_lower, 2), " (expected ~", round(expected_lower_asymptote, 2), 
    ", got ", round(min(fitted), 2), ")\n", sep = "")
cat("  Upper: ", round(diff_upper, 2), " (expected ~", round(expected_upper_asymptote, 2), 
    ", got ", round(max(fitted), 2), ")\n\n", sep = "")

cat("Interpretation:\n")
if (abs(min(fitted) - obs_min) < 1 && abs(max(fitted) - obs_max) < 1) {
  cat("❌ FORCED TO EXTREMA: Fitted line spans observed min/max\n")
  cat("   This suggests asymptotes are FORCED to data range, not preserved.\n")
} else if (diff_lower < 2 && diff_upper < 2) {
  cat("✓ ASYMPTOTES PRESERVED: Fitted line respects sigmoid asymptotes\n")
  cat("   Natural asymptotes (~0.07, ~0.93) are preserved.\n")
} else {
  cat("? UNCLEAR: Fitted line doesn't match either pattern\n")
}

cat("\n")
cat("=============================================================================\n")

# Also check the raw sigmoid output before scaling
cat("\nRAW SIGMOID OUTPUT (before scaling):\n")
cat("-----------------------------------------\n\n")

raw_sigmoid <- sm_shape_sigmoid(depths, opt_result$params)
cat("Raw sigmoid range: [", round(min(raw_sigmoid), 4), ", ", round(max(raw_sigmoid), 4), "]\n", sep = "")
cat("Raw sigmoid asymptotes: approximately [0.07, 0.93]\n\n")

# Verify the scaling formula manually
cat("Manual scaling verification:\n")
raw_min <- min(raw_sigmoid)
raw_max <- max(raw_sigmoid)
manually_scaled <- obs_min + (raw_sigmoid - raw_min) / (raw_max - raw_min) * obs_range

cat("  Raw min: ", round(raw_min, 4), "\n", sep = "")
cat("  Raw max: ", round(raw_max, 4), "\n", sep = "")
cat("  Raw range span in data coords: [", round(obs_min + 0 * obs_range, 2), ", ", 
    round(obs_min + 1 * obs_range, 2), "]\n", sep = "")
cat("  Actual raw range span: [", round(obs_min + raw_min * obs_range, 2), ", ",
    round(obs_min + raw_max * obs_range, 2), "]\n\n", sep = "")

cat("Fitted values match manual scaling: ",
    max(abs(fitted - manually_scaled)) < 1e-10, "\n\n", sep = "")

cat("CONCLUSION:\n")
cat("If fitted line min/max match observed min/max → asymptotes FORCED to extrema\n")
cat("If fitted line min/max match expected asymptotes → asymptotes PRESERVED\n")
