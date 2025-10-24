# Vignette & Documentation Fixes - Summary

## Issues Found & Fixed

### 1. ❌ Incorrect Parameter: `ci = 0.95`
**Problem**: The vignette examples used `ci = 0.95` parameter, but `sm_optim_bootstrap()` doesn't have a `ci` parameter.

**Why**: Confidence intervals are automatically calculated at 95%, 90%, etc. levels during result post-processing. The CI level is not a user parameter.

**Fix**: Removed `ci` parameter from all examples. Confidence intervals are now accessed via `boot_result$summary$param_ci_lower` and `boot_result$summary$param_ci_upper`.

### 2. ❌ Missing Required Parameter: `depths`
**Problem**: The vignette examples didn't pass the required `depths` parameter.

**Why**: The function signature requires `depths` (depth positions corresponding to observations) for proper modeling of spatial autocorrelation.

**Fix**: Added `depths = depths` to all `sm_optim_bootstrap()` calls in the vignette.

### 3. ❌ Missing Required Parameter: `optimizer`
**Problem**: Examples used default `optimizer = "auto"`, but Rust backend doesn't support algorithm auto-selection yet.

**Why**: The auto-selection feature requires a `recommend_algorithm()` function that hasn't been implemented yet.

**Fix**: Changed all examples to explicitly use `optimizer = "lbfgs"` (L-BFGS-B algorithm, suitable for most optimization problems).

### 4. ⚠️ Validation Function Vector Handling
**Problem**: The validation function was rejecting vector-type default parameters.

**Why**: The function signature has vector defaults for `method` and `fallback_strategy` (e.g., `method = c("auto", "parametric", "sieve")`), but the validation logic didn't properly handle this case.

**Fix**: Updated `.validate_bootstrap_inputs()` in `R/uncertainty.R` to properly handle both:
- Vector defaults (from function signature)
- Single string values (from user input)

## Files Updated

### 1. `/home/andrew/workspace/soilmotif/vignettes/fitting-motifs.Rmd`
**Changes**:
- Added `optimizer = "lbfgs"` to both bootstrap examples
- Added `depths = depths` to both bootstrap examples
- Removed `ci = 0.95` parameter
- Updated result access patterns to use `boot_result$summary$*`
- Adjusted example expectations for output structure
- Reduced `n_bootstrap` from 1000 to 100 for faster vignette rendering

**Lines Changed**: ~40 lines in bootstrap section

### 2. `/home/andrew/workspace/soilmotif/R/uncertainty.R`
**Changes**:
- Updated `fallback_strategy` validation in `.validate_bootstrap_inputs()` to handle vector defaults
- Added explicit handling for `length(fallback_strategy) > 1` case

**Lines Changed**: 7 lines in validation function

## Validation

✅ **Tests Pass**: `devtools::test()` → 381/381 tests passing  
✅ **Vignette Renders**: `rmarkdown::render('vignettes/fitting-motifs.Rmd')` → SUCCESS  
✅ **Bootstrap Works**: All vignette examples execute without errors  
✅ **Package Builds**: `R CMD INSTALL` → SUCCESS  

## Updated Documentation Index

Users seeking bootstrap examples should now:

1. **Quick Start**: `.github/SIEVE-BOOTSTRAP-QUICK-REFERENCE.md`
2. **Tutorial with Working Examples**: `vignettes/fitting-motifs.Rmd` (NOW FIXED)
3. **Function Reference**: `?sm_optim_bootstrap`
4. **Technical Details**: `.github/SIEVE-BOOTSTRAP-IMPLEMENTATION-COMPLETE.md`

## Next Steps

⏭️ **Future Enhancement** (Not blocking 03e):
- Implement `recommend_algorithm()` function in Rust to enable true `optimizer = "auto"` mode
- This would allow automatic algorithm selection based on problem size/characteristics

## Summary

All vignette examples now work correctly and reflect the actual API:
- ✅ Proper parameter passing (depths, optimizer)
- ✅ Correct result access patterns
- ✅ Validation functions handle all input types correctly
- ✅ 381/381 tests still passing
- ✅ Vignette renders successfully

Phase 3-03e documentation is now **fully corrected and production-ready**.
