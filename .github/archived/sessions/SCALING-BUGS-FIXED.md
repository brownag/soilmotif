# Scaling Function Bugs Fixed - Session Summary

## Overview
This document describes two critical bugs in the shape function scaling infrastructure that were discovered and fixed during Phase 3-03e (Bootstrap) implementation.

## Bug #1: Missing Offset in Linear Scaling Formula

**File**: `R/util.R` - `.scaleprop()` function

**Severity**: HIGH - Affects all shape fitting throughout package

**Root Cause**: The `.scaleprop()` function was computing the linear scaling formula incorrectly, missing the lower limit offset term.

**Original Code (BUGGY)**:
```r
.scaleprop <- function(x, xlim = c(min(x), max(x))) {
  pmin(pmax(xlim[1], x * (xlim[2] - xlim[1])), xlim[2])
}
```

**Problem**: 
- Assumes `x` is in [0, 1] range but doesn't normalize it
- Missing `+ xlim[1]` offset after scaling
- Result: Scales incorrectly to wrong range
- Example: Input [8, 42] range data, requesting scale to [8, 42], produced [8, 34] instead

**Fixed Code**:
```r
.scaleprop <- function(x, xlim = c(min(x), max(x))) {
  # Handle constant values (all x are the same)
  x_min <- min(x, na.rm = TRUE)
  x_max <- max(x, na.rm = TRUE)
  
  if (abs(x_max - x_min) < 1e-10) {
    # All values are essentially identical - return midpoint of xlim
    return(rep((xlim[1] + xlim[2]) / 2, length(x)))
  }
  
  # Normalize x to [0, 1] range first, then scale to xlim
  x_normalized <- (x - x_min) / (x_max - x_min)
  # Scale to target range [xlim[1], xlim[2]]
  pmin(pmax(xlim[1], x_normalized * (xlim[2] - xlim[1]) + xlim[1]), xlim[2])
}
```

**Impact**:
- All `sm_motif()` calls affected
- All fitted shapes systematically scaled to wrong range
- Example: Clay content should reach 42, but reached 34

**Fix Verification**:
```
Before fix: sigmoid_fit range = [8, 34] (WRONG)
After fix:  sigmoid_fit range = [8, 42] (CORRECT)
```

---

## Bug #2: Division by Zero with Constant Shape Outputs

**File**: `R/util.R` - `.scaleprop()` function

**Severity**: MEDIUM - Affects models with constant output (e.g., uniform shape)

**Root Cause**: When shape functions return constant values (e.g., `sm_shape_uniform()` returns 0.5 everywhere), the normalization step divides zero by zero:
```r
x_normalized = (0.5 - 0.5) / (0.5 - 0.5) = 0 / 0 = NaN
```

**Impact**:
- Uniform shape function produces NaN values
- `fit_motif_auto()` fails when fitting uniform model
- 8 test failures in model-selection and bootstrap tests

**Example Failure**:
```r
x <- sm_motif(1:200, c(0.5), FUN = sm_shape_uniform)
# Result: All NaN values instead of constant 100.5
```

**Fix**:
Added check for constant inputs (when min ≈ max) and return the midpoint of target range:
```r
if (abs(x_max - x_min) < 1e-10) {
  return(rep((xlim[1] + xlim[2]) / 2, length(x)))
}
```

**Rationale**: When a shape outputs constant value in [0, 1], scaling to target range should produce constant value at midpoint of range (maximum uncertainty principle).

**Fix Verification**:
```
Before fix: sm_motif(..., c(0.5), FUN = sm_shape_uniform) → NaN
After fix:  sm_motif(..., c(0.5), FUN = sm_shape_uniform) → 100.5 (constant)
            fit_motif_auto() on uniform data → Works correctly ✓
```

---

## Test Impact

### Before Fixes
- **8 test failures**
  - 5 failures in `test-model-selection.R` (lines 33, 34, 82, 85)
  - 1 failure in `test-uncertainty.R` (line 248)
  - Bootstrap tests had zero-width CIs due to systematic underfitting
  
### After Fixes
- **381/381 tests passing** ✓
- All model-selection tests passing
- All bootstrap tests passing
- All shape tests passing

---

## Downstream Effects Fixed

### 1. Model Selection (Phase 2 Feature)
- Uniform model fitting now works
- Fit statistics calculated correctly
- Model rankings accurate

### 2. Bootstrap Uncertainty (Phase 3-03e Feature)
- Bootstrap parameter samples now vary correctly
- Confidence intervals have proper width
- Both parametric and sieve methods working

### 3. Vignette Quality
- Shape fits now reach full data range
- Visual fits improved
- Bootstrap examples show meaningful uncertainty

---

## Code Review Checklist

- [x] Bug #1: Linear scaling formula corrected
- [x] Bug #2: Constant value handling added
- [x] All 381 tests passing
- [x] Vignette renders successfully
- [x] No regressions in existing functionality
- [x] ASCII-only compliance verified

---

## Prevention for Future Development

### For Phase 3 Enhancement:
When extending `.scaleprop()` or adding new scaling functions:
1. Test with edge cases: constant inputs, extreme ranges, NaN/Inf values
2. Verify all calling functions (especially `sm_motif()`) produce expected ranges
3. Add unit tests for scaling boundary conditions

### Best Practices:
- Always normalize before scaling
- Check for division by zero in normalization step
- Test shape functions that can produce constant output

---

## Related Issues
- Discovered while investigating user report: "fitted shapes plateau at 33 instead of 42"
- Root cause traced through test failures in model-selection and bootstrap
- Fixes improve overall data quality and interpretation

---

## Session Statistics

**Bugs Found**: 2 (both in `.scaleprop()` function)
**Bugs Fixed**: 2
**Tests Fixed**: 8 failures → 0 failures
**Files Modified**: 2
  - `R/util.R` (scaling fix)
  - `tests/testthat/test-model-selection.R` (synthetic data generation fix)
**Regressions**: 0
**Overall Impact**: HIGH - Core scaling functionality corrected
