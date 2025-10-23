# Rust FFI Debugging & Type Conversion Guide

## Critical Issue: Option<T> Type Conversions in FFI

### The Bug (October 22-23, 2025)

**Symptom**: AR(1) coefficient in sieve bootstrap returning `NA` despite successful computation in Rust.

**Root Cause**: `Option<f64>` was being passed directly to extendr's `list!()` macro without explicit conversion to R-compatible `Robj`.

**Impact**: The computed AR(1) coefficient (φ ≈ 0.9268) was being lost during FFI marshalling, breaking the sieve bootstrap method and making vignette examples incorrect.

### The Fix

**File**: `src/lib.rs` (lines ~443-457)

**Before** (broken):
```rust
// This doesn't work: Option<f64> not automatically converted by extendr
list!(
    success_rate = result_struct.success_rate,
    ar1_coef = result_struct.ar1_coef,  // ← Returns None/NA in R
    // ...
)
```

**After** (fixed):
```rust
// Explicit conversion: Option<f64> -> Robj
let ar1_coef_robj = match result_struct.ar1_coef {
    Some(val) => Robj::from(val),        // Scalar numeric in R
    None => Robj::from(f64::NAN),        // NA in R
};

list!(
    success_rate = result_struct.success_rate,
    ar1_coef = ar1_coef_robj,            // ✓ Now works
    // ...
)
```

### When This Matters

**FFI Type Conversions Required**:
- `Option<f64>` → `Robj` (must match `Some(val)` and `None`)
- `Option<String>` → `Robj` (same pattern)
- `Option<Vec<T>>` → R list with NA for failures
- Any `Option<>` type returned via FFI

**Types That Auto-Convert** (extendr handles):
- `f64`, `i32`, `String`, `Vec<f64>`, `Vec<i32>`, `Vec<String>` ✓
- Most primitives and standard containers ✓

### Prevention Checklist

When adding new FFI functions that return `Option<T>`:

1. ☑️ **Identify Option types** in return structs
   ```rust
   pub struct BootstrapEngineResult {
       pub ar1_coef: Option<f64>,  // ← Needs conversion
       pub phi: f64,                // ← Auto-converts
   }
   ```

2. ☑️ **Create explicit conversion before list!()** 
   ```rust
   let ar1_coef_robj = match result_struct.ar1_coef {
       Some(val) => Robj::from(val),
       None => Robj::from(f64::NAN),  // or String, etc
   };
   ```

3. ☑️ **Test round-trip** in R
   ```r
   result <- bootstrap_engine_rust(...)
   cat("Type of ar1_coef:", typeof(result$ar1_coef), "\n")
   cat("Value:", result$ar1_coef, "\n")
   # Should show: double (numeric), not NULL
   ```

4. ☑️ **Check vignettes/examples** render correctly
   ```bash
   R -e "rmarkdown::render('vignettes/fitting-motifs.Rmd', quiet = TRUE)"
   ```

### Debugging Strategy

If Option<T> values disappear in R:

1. **Add debug output in Rust** before conversion
   ```rust
   eprintln!("[DEBUG] Before conversion: ar1_coef = {:?}", result_struct.ar1_coef);
   let ar1_coef_robj = match result_struct.ar1_coef { ... };
   eprintln!("[DEBUG] After conversion: ar1_coef_robj = {:?}", ar1_coef_robj);
   ```

2. **Verify in R** immediately after calling FFI
   ```r
   result <- bootstrap_engine_rust(...)
   cat("R sees ar1_coef as:", typeof(result$ar1_coef), "\n")
   cat("Value:", result$ar1_coef, "\n")
   ```

3. **Check extendr documentation** for alternative patterns
   - Use `Robj::from(Option::Some(val))` vs `Robj::from(val)` if needed
   - Some types may have special handling

### Related FFI Conversions

**Pattern 1**: Option<Vec<T>>
```rust
let params_list_r: Vec<Robj> = result.params
    .iter()
    .map(|opt_params| {
        match opt_params {
            Some(params) => Robj::from(params.clone()),
            None => Robj::from(vec![f64::NAN]),  // NA vector
        }
    })
    .collect();
```

**Pattern 2**: Option<String>
```rust
let message_robj = match result.message {
    Some(msg) => Robj::from(msg),
    None => Robj::from(String::new()),  // Empty string
};
```

**Pattern 3**: Nested Option
```rust
// Option<Vec<Option<f64>>>
let values_r: Vec<Robj> = result.values
    .iter()
    .map(|opt_val| {
        match opt_val {
            Some(v) => Robj::from(*v),
            None => Robj::from(f64::NAN),
        }
    })
    .collect();
```

### Test Coverage

Add test to verify Option type conversion round-trips:

```r
# tests/testthat/test-ffi-types.R
test_that("Option<f64> converts to R numeric or NA", {
  # Call function that returns Option<f64>
  result <- bootstrap_engine_rust(...)
  
  # Must be numeric (double or NA, not NULL)
  expect_true(is.numeric(result$ar1_coef))
  
  # If Some, should be finite numeric
  if (!is.na(result$ar1_coef)) {
    expect_true(is.finite(result$ar1_coef))
    expect_true(result$ar1_coef > -1 && result$ar1_coef < 1)
  }
})
```

### Documentation Implications

**Update roxygen comments** when Option<T> is returned via FFI:

```r
#' @return
#'   List with:
#'   - ar1_coef: Numeric scalar (AR(1) coefficient), or NA if not computed
#'   - param_samples: Matrix of bootstrap parameter samples
```

## Other FFI Lessons from Phase 3-03e

### 1. Data Type Sizing

- `usize` (Rust) → `i32` (R) can overflow for large n_bootstrap
- Always cast down: `n_bootstrap as i32`
- Consider using `i64` for large counters

### 2. String Conversion Edge Cases

- Empty strings vs NULL in R: Be explicit
- UTF-8 encoding assumed by extendr
- Non-ASCII characters may silently fail (use ASCII-only as per copilot-instructions)

### 3. Parallel Execution Debugging

- Debug output (`eprintln!()`) works but may be interleaved
- Use single-threaded mode for debugging: `parallel = false`
- Timing issues can mask logic bugs in rayon code

### 4. Error Handling Through FFI

```rust
// Good: Return error message to R
match computation {
    Ok(result) => Ok(result),
    Err(e) => Err(e.to_string()),  // R sees it as Error message
}

// Bad: Panic will crash R
assert!(condition);  // ✗ Use Result instead
```

## Vignette Validation Checklist

After modifying FFI types or return structures:

- [ ] Vignette renders without errors: `rmarkdown::render('vignettes/fitting-motifs.Rmd')`
- [ ] Output displays as expected (not NA, NULL, or empty)
- [ ] Manual calculations agree with Rust results
- [ ] Examples in vignettes are executable
- [ ] All examples show correct data types

## Phase 3-03e Applied Lessons

This bug was found and fixed during:
1. Vignette rendering showed `NA` for AR(1) coefficient
2. Manual R calculation showed coefficient should be ~0.93
3. Traced through: vignette → bootstrap function → Rust FFI → extendr macro
4. Identified: `Option<f64>` not being converted
5. Solution: Explicit match with `Robj::from()`
6. Verification: Vignette now shows correct value `0.9268`

**Key Insight**: Just because computation succeeds in Rust doesn't mean data reaches R correctly. Always verify:
1. Rust debugs output shows correct computed value
2. R sees correct type (numeric, not NULL/NA inappropriately)
3. Vignettes/examples render and display correctly

## References

- **extendr Book**: https://extendr.github.io/
- **FFI Patterns**: `src/lib.rs` (examples of working conversions)
- **Test Suite**: `tests/testthat/test-ffi-types.R` (if created)
- **Incident Log**: This document

---

**Last Updated**: October 23, 2025  
**Status**: Complete & Applied  
**Severity**: Critical (data loss during FFI marshalling)  
**Resolution**: Explicit Option<T> -> Robj conversion patterns
