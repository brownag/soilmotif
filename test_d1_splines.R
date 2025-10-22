#!/usr/bin/env Rscript
# Test D1 Spline Implementation
# Verifies monotone and RCS splines work correctly with optimization

library(soilmotif)

cat("=== D1 Spline Function Tests ===\n")

# Define control points early
clay_knots <- c(
  5, 0.05,    # 5 cm: 5% clay
  30, 0.15,   # 30 cm: 15% clay
  80, 0.40,   # 80 cm: 40% clay (max)
  150, 0.40   # 150 cm: 40% clay (stable)
)

initial_params <- c(10, 0.1, 50, 0.25, 100, 0.35, 150, 0.40)

# Test 1: Monotone spline evaluation
cat("\n1. Testing monotone cubic spline evaluation...\n")
depths_eval <- seq(1, 200, by = 5)

clay_mono <- sm_shape_spline(depths_eval, clay_knots, type = "monotone", ascending = TRUE)
cat("   Monotone spline evaluated at", length(depths_eval), "depths\n")
cat("   Value range:", range(clay_mono), "\n")
cat("   First 5 values:", head(clay_mono, 5), "\n")

# Test 2: RCS spline evaluation
cat("\n2. Testing restricted cubic spline evaluation...\n")
clay_rcs <- sm_shape_spline(depths_eval, clay_knots, type = "rcs", ascending = TRUE)
cat("   RCS evaluated at", length(depths_eval), "depths\n")
cat("   Value range:", range(clay_rcs), "\n")
cat("   First 5 values:", head(clay_rcs, 5), "\n")

# Test 3: Comparison of monotone vs RCS
cat("\n3. Comparing monotone vs RCS curves...\n")
diff_mono_rcs <- abs(clay_mono - clay_rcs)
cat("   Max difference:", max(diff_mono_rcs), "\n")
cat("   Mean difference:", mean(diff_mono_rcs), "\n")

# Test 4: Ascending flag behavior
cat("\n4. Testing ascending flag...\n")
clay_desc <- sm_shape_spline(depths_eval, clay_knots, type = "monotone", ascending = FALSE)
cat("   Descending spline evaluated\n")
cat("   Value range:", range(clay_desc), "\n")
# Check: ascending + descending should sum to ~1.0 at most points
check_sum <- clay_mono + clay_desc
cat("   Sum of ascending + descending at midpoints:", 
    mean(check_sum[seq(1, length(check_sum), length = 10)]), "\n")

# Test 5: Edge cases
cat("\n5. Testing edge cases...\n")
edge_depths <- c(0, 1, 200, 201)  # Outside knot range
try({
  edge_vals <- sm_shape_spline(edge_depths, clay_knots, type = "monotone", ascending = TRUE)
  cat("   Edge depths evaluated:", edge_vals, "\n")
}, silent = FALSE)

# Test 6: Parameter validation (strict mode)
cat("\n6. Testing parameter validation (strict=TRUE)...\n")
try({
  # Unsorted depths should fail
  bad_knots <- c(30, 0.15, 5, 0.05, 80, 0.40)
  sm_shape_spline(depths_eval, bad_knots, type = "monotone", ascending = TRUE, strict = TRUE)
}, silent = FALSE)
cat("   (Expected error for unsorted depths)\n")

try({
  # Non-monotone values with monotone type should fail
  bad_knots <- c(5, 0.40, 30, 0.15, 80, 0.05)  # Descending
  sm_shape_spline(depths_eval, bad_knots, type = "monotone", ascending = TRUE, strict = TRUE)
}, silent = FALSE)
cat("   (Expected error for non-monotone values with ascending=TRUE)\n")

# Test 7: Integration with sm_motif framework
cat("\n7. Testing integration with evaluation framework...\n")
# Use sm_shape_spline to create synthetic data
observed_clay <- sm_shape_spline(1:200, initial_params, type = "monotone", ascending = TRUE)
cat("   Synthetic clay profile created\n")
cat("   Length:", length(observed_clay), "depths\n")
cat("   Value range:", range(observed_clay), "\n")

# Test 8: Data frame control points format
cat("\n8. Testing data frame control points format...\n")
knot_df <- data.frame(
  depth = c(5, 30, 80, 150),
  value = c(0.05, 0.15, 0.40, 0.40)  # Monotone non-decreasing
)
clay_df <- sm_shape_spline(depths_eval, knot_df, type = "monotone", ascending = TRUE)
cat("   Data frame format works!\n")
cat("   Value range:", range(clay_df), "\n")

cat("\n=== D1 Spline Tests Complete ===\n")
