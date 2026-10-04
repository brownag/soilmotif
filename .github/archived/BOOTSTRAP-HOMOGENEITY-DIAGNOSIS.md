# Deep Diagnosis: Bootstrap Parameter Homogeneity Root Cause

**Investigation Date:** October 26, 2025  
**Issue:** Bootstrap parameter samples show zero variation (all identical across replicates)  
**Expected:** Parameter samples should vary as synthetic datasets are resampled  

## The Problem

When running `sm_optim_bootstrap()` on the clay_spline example from README:

```
#> Warning: Bootstrap parameter samples appear corrupted or degenerate: 
#> parameters 1, 2 have identical values across all 1000 successful bootstrap replicates.
#> This suggests either Rust FFI returned corrupt data or all optimizations 
#> converged to the same point.
```

All 1000 bootstrap replicates converge to identical parameters `c(-76.41, 163.62)`, with zero variance across the samples.

## Investigating the Root Cause

### Theory 1: Rust FFI Data Corruption ❌
The Rust code correctly collects `parameter_samples` by appending each optimization result. This would only fail if Rust never enters the parameter collection loop (all optimizations fail) or returns malformed data.

**Verdict:** Code inspection shows proper collection. FFI likely working correctly.

### Theory 2: All Optimizations Converge to Same Point ✓✓ LIKELY CAUSE
Given the same initial parameters and very similar synthetic datasets, the Nelder-Mead optimizer could converge to the same local minimum repeatedly.

**Why this happens:**
1. Bootstrap resamples residuals: `synthetic_obs = fitted + resampled_residuals`
2. If residuals are small/white-noise, all resampled versions are VERY SIMILAR to original
3. If resampled datasets are nearly identical, optimizer converges to same spot
4. Result: All bootstrap parameter samples identical

### Theory 3: Proportional Scaling Forcing Asymptotes ✓ CONTRIBUTING FACTOR
If the fitted line is forced to span exactly [min(obs), max(obs)], it over-constrains optimization:

1. Sigmoid naturally asymptotes at ~[0.07, 0.93]
2. If output forced to [6, 50], optimization has only ONE valid solution
3. All bootstrap iterations have same constraint
4. Result: All converge to same parameters

## The Actual Problem: TWO-FOLD ISSUE

### Problem #1: Scaling Forces Output to Extrema (DESIGN ISSUE)

**Current behavior (proportional scaling):**
- Shape function range: [~0.07, ~0.93] 
- Observed data range: [6, 50]
- Scaling maps shape range → data range: [6, ~44]
- BUT: Because the min/max of shape are used, it FORCES output to [6, 50]

**Why this is a problem:**
```
Sigmoid naturally asymptotes at 0.07 and 0.93
Observed data is [6, 50]

Current scaling does:
  scaled = 6 + (shape - 0.07)/(0.93 - 0.07) * 44
  
Result: Fitted line goes from ~6 to ~44
BUT: This FORCES asymptotes to observed extrema
If observed data actually has natural asymptotes != data extrema,
  the fit is over-constrained!
```

**Evidence:** The blue fitted line in README goes from min to max of observed data, not preserving sigmoid's natural asymptotes.

### Problem #2: Residuals Are Too Small / White Noise (DATA ISSUE)

If the initial fit is excellent and residuals are white noise with minimal structure:

1. **Residual statistics:**
   - Small variance: residuals might be [±5] from a signal of [6, 50]
   - White noise: ACF near zero, so AR(1) phi ≈ 0
   - No structure: All resampled residuals very similar

2. **Bootstrap consequence:**
   - Synthetic observed ≈ fitted + tiny random noise
   - All synthetic datasets look nearly identical to original
   - Optimizer finds same minimum for all

3. **AR(1) model consequence:**
   - If phi ≈ 0 (white noise), AR(1) essentially does random resampling
   - With white noise residuals, this produces nearly identical synthetic data

## Proposed Root Cause Chain

```
Proportional scaling forces output to [min(obs), max(obs)]
    ↓
Over-constrains optimization problem
    ↓
Each bootstrap iteration has SAME constraints as original fit
    ↓
Resampled data is similar to original (residuals small/white-noise)
    ↓
All optimizations converge to SAME parameters
    ↓
Bootstrap shows ZERO variation
```

## The Fitted Line Issue

**Current behavior:**
- Fitted line appears to go from exactly min(observed) to max(observed)
- This suggests output is being clipped/forced to data extrema
- Expected: Natural sigmoid asymptotes should be preserved

**Why this matters:**
- If asymptotes forced to data range, optimization becomes highly constrained
- Bootstrap has no room to vary (one unique solution dominates)
- All resamples converge to same fit

## Diagnostics to Run

1. **Check residual structure:**
   ```r
   source("inst/debug-bootstrap.R")
   # This will show AR(1) coefficient and residual statistics
   # If phi ≈ 0, residuals are white noise
   ```

2. **Check fitted line asymptotes:**
   ```r
   opt <- sm_optim(clay_spline, c(25, 100), scale_method = "proportional")
   min(opt$fitted)  # Should be > min(clay_spline) if asymptotes preserved
   max(opt$fitted)  # Should be < max(clay_spline) if asymptotes preserved
   ```

3. **Check if proportional scaling is actually working:**
   - Compute expected range with preserved asymptotes
   - Compare to actual fitted range
   - If they don't match, scaling is forced to extrema

## Scaling Implementation Review

Current `.scaleprop()` formula:
```r
result <- xlim[1] + (x - x_min) / (x_max - x_min) * (xlim[2] - xlim[1])
```

Where:
- `x` = sigmoid output (~[0.07, 0.93])
- `x_min` = min(sigmoid output)
- `x_max` = max(sigmoid output)
- `xlim` = [min(observed), max(observed)] = [6, 50]

This DOES scale sigmoid range to data range. But the problem is:
- When `x` reaches `x_min` (0.07), result = 6 (min observed)
- When `x` reaches `x_max` (0.93), result = 50 (max observed)
- **This forces asymptotes to observed extrema!**

**The issue is conceptual:** Passing observed data range as `xlim` instead of something that represents natural bounds means asymptotes GET FORCED TO DATA RANGE.

## What "Preserve Asymptotes" Should Mean

**Option A: Preserve sigmoid natural bounds**
- Sigmoid in [0, 1] space has natural asymptotes at [0, 1]
- These should map to [min_observed, max_observed] but NOT force to them
- Instead: Map [0, 1] → [min_obs, max_obs], then evaluate sigmoid output within that range
- Result: Asymptotes end up at ~[min_obs + 0.07*(max-min), min_obs + 0.93*(max-min)]

**Option B: Current behavior (force to extrema)**
- Force sigmoid to span exactly [min_observed, max_observed]
- This is what's currently happening
- This IS correct if you want output to span data range
- But it OVER-CONSTRAINS optimization

## The Bootstrap Parameter Homogeneity Explanation

**Given:**
- Sigmoid outputs scaled to span [min(obs), max(obs)]
- Residuals are small white noise (good fit)
- All bootstrap iterations use same initial parameters

**What happens:**
1. Initial fit found optimal parameters for full data range constraint
2. Resampled data = fitted + noise, still needs to fit in [6, 50]
3. Both original AND resampled data have same over-constraint
4. Same constraint + similar data = same optimum
5. All bootstrap iterations find same parameters
6. Result: Zero variance

**This is CORRECT BEHAVIOR given the constraint!** But it's not useful for bootstrap.

## Real Root Cause

The bootstrap parameter homogeneity is NOT a bug in the Rust backend or FFI. It's the CONSEQUENCE of:

1. **Over-constrained optimization:** Output forced to exactly span [min(obs), max(obs)]
2. **Small residuals:** Good initial fit leaves little room for variation
3. **White noise residuals:** AR(1) adds randomness but within tight constraints
4. **Nelder-Mead convergence:** Given similar data, finds same minimum

## Solutions

### Solution 1: Change How Scaling Works (Design change)
Instead of forcing output to [min(obs), max(obs)], preserve natural asymptotes:
- Map sigmoid shape output range to observed range
- Don't force extremes to observed min/max
- Allow fitted values to fall within but not necessarily span range
- Result: Bootstrap has room to vary parameters

### Solution 2: Switch to Parametric Bootstrap
If residuals are white noise, parametric bootstrap works better:
- Resample residuals from normal distribution with fitted SD
- Adds MORE variation than sieve bootstrap
- May show parameter variation even with constraints
- Con: Loses AR(1) structure (but there's no structure to preserve)

### Solution 3: Validate the Asymptotes
Before concluding it's a "bug", verify:
- Is the fitted line actually going to observed extrema?
- Are the residuals actually white noise?
- Is bootstrap showing zero variation?
- Or is it working as designed given the constraints?

## Next Steps

1. **Run debug script to check:**
   - Residual structure (AR(1) coefficient)
   - Fitted line asymptotes vs. observed range
   - Whether proportional scaling is preserving asymptotes

2. **Determine correct behavior:**
   - Should asymptotes be forced to data range? (currently yes)
   - Or should they be preserved? (what documentation claims)

3. **Fix based on findings:**
   - If forcing is intentional, document it and adjust bootstrap expectations
   - If asymptotes should be preserved, fix scaling implementation

## Key Question

**Is the proportional scaling supposed to:**

A) **Force output to exactly span observed range [min, max]** (current behavior)
   - Pro: Full utilization of data range
   - Con: Over-constrains optimization, bootstrap shows no variation
   - Behavior: What's currently happening

B) **Preserve sigmoid asymptotes while fitting within range** (documented behavior)
   - Pro: Natural asym ptotes preserved, bootstrap shows variation
   - Con: May not fully utilize data range
   - Behavior: What documentation claims

The answer to this question determines whether the bootstrap homogeneity is:
- **A bug** (if intended behavior is B) → Need to fix scaling
- **Expected** (if intended behavior is A) → Bootstrap working as designed given tight constraints
- **A limitation** (either way) → Document it and recommend parametric bootstrap for this case

## Recommendation

1. **Check actual behavior:** Run `inst/debug-bootstrap.R` to see:
   - Does fitted line go to observed min/max?
   - Are residuals white noise (phi ≈ 0)?
   - Are bootstrap parameters truly all identical?

2. **Decide on asymptotes:** Clear definition of "preserve asymptotes"

3. **Implement fix:** Either change scaling or document as known limitation

4. **Update bootstrap:** Recommend parametric method for data with small residuals/white noise
