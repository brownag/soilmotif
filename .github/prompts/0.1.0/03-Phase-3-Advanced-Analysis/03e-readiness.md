# 03e-Uncertainty Phase 1 READINESS REPORT

**Date**: October 22, 2025  
**Status**: ✅ **READY FOR IMPLEMENTATION**  
**Blocking Issues**: None  
**Required Pre-Work**: Complete

---

## Executive Summary

All 12 user answers have been reviewed, integrated, and reconciled with the 03e-uncertainty.md prompt. **No conflicts found**. The updated prompt now captures all decisions with complete clarity, including:

- ✅ AR model order (p=1 fixed)
- ✅ Yule-Walker solver (ndarray-linalg added to Cargo.toml)
- ✅ Innovation resampling (direct, non-parametric)
- ✅ Initial optimization (always re-optimize in Rust)
- ✅ Threshold parameter (user-configurable sieve_threshold)
- ✅ FFI struct design (BootstrapEngineResult approved)
- ✅ Failed iterations (store as NaN rows)
- ✅ **Fallback logic (three-tier: auto/explicit/strict)** — clarified
- ✅ **Optimizer/objective/shape dispatch** — documented
- ✅ **Reproducibility** — seed handling specified
- ✅ **Input validation** — comprehensive checklist added
- ✅ **AR failure modes** — documented with recovery strategy

---

## Updates Applied to 03e-uncertainty.md

### Update 1: Supported Methods & Dispatcher Pattern (NEW SECTION)
**Location**: After "Core Architecture"

Added explicit documentation of:
- Supported optimizers: "nelder_mead", "lbfgs", "pso", "simulated_annealing", "newton_cg"
- Supported objectives: "rmse", "sse", "mae", "r2"
- Supported shapes: All from src/shape_functions.rs + Phase 3d additions
- Routing mechanism: String-based dispatcher pattern in Rust
- Validation: R-layer validation before Rust calls

**Rationale**: Clarifies Q10, Q11, Q12 (optimizer/objective full support)

---

### Update 2: Reproducibility & Seed Handling (NEW SECTION)
**Location**: After "Supported Methods"

Added explicit documentation of:
- R-side `set.seed(seed)` for RNG control
- Rust-side PRNG for rayon parallelization
- User example showing reproducible bootstrap
- Seed parameter validation

**Rationale**: Clarifies seed parameter usage; ensures reproducibility

---

### Update 3: Input Validation & Error Handling (NEW SECTION)
**Location**: Before "Create the Rust bootstrap engine"

Added comprehensive validation checklist:
- Data validation: observed, initial_params, x vectors
- Parameter validation: n_bootstrap, ci, method, sieve_threshold, strict, seed, optimizer
- Error message guidance (specific, not generic)

**Rationale**: Ensures R layer provides strong input validation before FFI

---

### Update 4: Sieve Bootstrap Logic - AR Error Handling (EXPANDED SECTION)
**Location**: In "Implement the Sieve Bootstrap Logic" section

Added detailed AR failure modes documentation:
- Valid coefficient range check (-1 < φ < 1)
- Singular Toeplitz matrix handling
- ndarray-linalg solver failure recovery
- Insufficient variance edge case

**Rationale**: Provides implementation guidance for robust error handling

---

### Update 5: Fallback Logic & Method Dispatch (CLARIFIED SECTION)
**Location**: In "Implement the Sieve Bootstrap Logic" subsection

Replaced generic fallback logic with three-tier specification:
1. `method="auto"` + `strict=FALSE` → Fallback to Parametric with warning
2. `method="auto"` + `strict=TRUE` → Error if AR fits fails
3. `method="sieve"` (explicit) → ALWAYS error on AR fit failure, regardless of strict

**Rationale**: Clarifies Q8 user decision; distinguishes auto vs. explicit method selection

---

### Update 6: Final Specification Summary Table (EXPANDED)
**Location**: Final section

Expanded from 9 to 11 rows, adding:
- **Method Dispatch**: String-based dispatcher reuses existing logic
- **Dependencies**: Explicit mention of full argmin/objective/shape integration
- **Auto-Method Threshold**: Clarified logic (n <= sieve_threshold → parametric)
- **Reproducibility**: Explicit seed handling
- **Validation**: Input validation summary
- **Explicit Method Behavior**: Auto vs. explicit behavior distinction

**Rationale**: Comprehensive specification capturing all decisions

---

## Pre-Work Completed

### ✅ ndarray-linalg Added to Cargo.toml

```toml
[dependencies]
...
ndarray-linalg = { version = "0.16", features = ["openblas-static"] }
...
```

**Status**: Added with openblas-static feature for linear algebra backend

---

## 10-Question Answer Summary (Cross-Check)

| # | Question | User Decision | Prompt Status | Verification |
|---|----------|---------------|---------------|--------------|
| Q1 | AR order | p=1 fixed | ✅ Spec'd | AR(1) in Sieve section |
| Q2 | Yule-Walker | ndarray-linalg | ✅ Spec'd + Dependency added | Cargo.toml updated |
| Q3 | Innovation resampling | Direct non-param | ✅ Spec'd | "directly resample" in Sieve |
| Q4 & Q9 | Initial optimization | Always re-optimize Rust | ✅ Spec'd | "always perform initial optim" |
| Q5 | Threshold | sieve_threshold (20 default) | ✅ Spec'd | R parameter + auto logic |
| Q6 | FFI struct | BootstrapEngineResult approved | ✅ Spec'd | Exact struct definition |
| Q7 | Failed iterations | NaN rows | ✅ Spec'd | "vector of f64::NAN" |
| Q8 | Fallback behavior | Three-tier logic | ✅ Spec'd (NEW) | auto/explicit/strict documented |
| Q10, Q11, Q12 | Optimizer/objective support | Full + string dispatch | ✅ Spec'd (NEW) | Dispatcher pattern section added |

---

## Implementation Checklist (Phase 1)

### Rust Files to Create

- [ ] `src/uncertainty.rs` (new)
  - [ ] `BootstrapEngineResult` struct (extendr-exposed)
  - [ ] `bootstrap_engine_rust()` function (FFI entry point)
  - [ ] `parametric_bootstrap()` inner function
  - [ ] `sieve_bootstrap()` inner function
  - [ ] `fit_ar1_model()` helper (Yule-Walker via ndarray-linalg)
  - [ ] `resample_innovations()` helper
  - [ ] Error handling wrappers with fallback logic

### R Files to Create

- [ ] `R/uncertainty.R` (new)
  - [ ] `sm_optim_bootstrap()` wrapper function
  - [ ] Input validation logic
  - [ ] Method dispatch ("auto", "parametric", "sieve")
  - [ ] Seed handling (set.seed())
  - [ ] Rust FFI call
  - [ ] Result assembly into BootstrapResult S3 object

### Cargo.toml Updates

- [x] `ndarray-linalg = { version = "0.16", features = ["openblas-static"] }` (COMPLETED)

### Documentation Updates

- [ ] Add roxygen comments to `sm_optim_bootstrap()` in R/uncertainty.R
- [ ] Update NAMESPACE (via devtools::document())
- [ ] Add examples in roxygen comments
- [ ] Create test file: `tests/testthat/test-uncertainty.R`

### Phase 1 Testing Plan

**Unit Tests (Parametric Bootstrap)**:
- [ ] Sparse profile (n=15): Parametric bootstrap runs
- [ ] Dense profile (n=200): Auto-selects Sieve; falls back to Parametric if AR fails
- [ ] n=20 boundary: Parametric selected
- [ ] n=21 boundary: Sieve selected (if AR succeeds)
- [ ] CI coverage: 100 iterations, mean CI width reasonable
- [ ] Convergence tracking: Flags recorded for failures
- [ ] NaN handling: Matrix shape correct even with failures

**Integration Tests**:
- [ ] Different optimizers work: "lbfgs", "nelder_mead"
- [ ] Different objectives work: "rmse", "mae"
- [ ] Different shapes work: "sigmoid", "exponential"
- [ ] Seed reproducibility: Same seed → same result
- [ ] Error messages: Clear guidance on invalid inputs

**Regression Tests**:
- [ ] All 246+ existing tests pass
- [ ] No Unicode characters in new code/docs

---

## Dependency Status

### New Dependencies Added

**ndarray-linalg** (0.16 with openblas-static)
- Purpose: Solve Yule-Walker equations for AR(1) fitting
- Feature: openblas-static provides reliable linear algebra backend
- Status: ✅ Added to Cargo.toml

### Existing Dependencies Leveraged

- **rayon** (1.8): Parallel bootstrap loop via rayon::iter
- **argmin** (0.9): Existing optimizers reused
- **extendr-api** (0.8): FFI via BootstrapEngineResult struct
- **rand** (0.8): Innovation resampling
- **ndarray** (0.15): AR coefficient storage & manipulation

---

## Known Risks & Mitigations

### High Risk: AR(1) Model Instability

**Risk**: Singular Toeplitz matrix; weak autocorrelation; numerical precision
**Mitigation**:
- Check coefficient magnitude: |φ| < 1
- Add condition number check to ndarray-linalg solve
- Fallback to Parametric if AR fit fails (unless strict=TRUE)
- Test on synthetic AR(1) profiles with known params

**Phase 1 Action**: Implement error handling; test extensively

---

### Medium Risk: Rayon Overhead for Small n_bootstrap

**Risk**: Parallelization startup cost dominates for n_bootstrap < 100
**Mitigation**:
- Profile early in Phase 1
- Consider sequential loop for n_bootstrap < 100
- Use rayon default threadpool (global)

**Phase 1 Action**: Benchmark; document performance characteristics

---

### Medium Risk: FFI Complexity with extendr

**Risk**: Rust struct → R list conversion; debugging
**Mitigation**:
- Follow existing batch.rs patterns (already uses extendr)
- Test FFI with simple struct first (BootstrapEngineResult is straightforward)
- Write clear error messages for failed FFI calls

**Phase 1 Action**: Test FFI integration early; validate struct conversion

---

## Architecture Diagram (Phase 1)

```
R Layer (R/uncertainty.R)
├─ sm_optim_bootstrap() wrapper
├─ Input validation
├─ set.seed() call
├─ Call: bootstrap_engine_rust_with_method()
│  (via extendr)
└─ Assemble S3 BootstrapResult

                ↓ FFI

Rust Layer (src/uncertainty.rs)
├─ bootstrap_engine_rust()
│  └─ match method {
│     "parametric" → parametric_bootstrap()
│     "sieve" → sieve_bootstrap()
│       ├─ fit_ar1_model() [ndarray-linalg]
│       └─ resample_innovations()
│  }
├─ Re-optimize initial fit (via existing optimizer)
├─ Parallel rayon loop:
│  ├─ Resample residuals/innovations
│  ├─ Generate synthetic profile
│  └─ Re-optimize (call optimizer.rs)
└─ Return BootstrapEngineResult struct
   (param_samples, convergence, errors)
```

---

## Next Steps Before Phase 1 Starts

1. ✅ **Review this readiness report** — All decisions captured
2. ✅ **Confirm 03e-uncertainty.md updates** — All sections clarified
3. ✅ **Verify Cargo.toml** — ndarray-linalg added
4. [ ] **Create src/uncertainty.rs skeleton** — Define BootstrapEngineResult, FFI signature
5. [ ] **Create R/uncertainty.R skeleton** — Define sm_optim_bootstrap() wrapper
6. [ ] **Compile & test FFI** — Verify extendr macro works
7. [ ] **Implement parametric bootstrap** — Core logic in Rust
8. [ ] **Implement R wrapper** — Input validation, method dispatch
9. [ ] **Write Phase 1 tests** — Parametric bootstrap validation
10. [ ] **Benchmark performance** — Rayon overhead, typical runtime

---

## Phase 1 Deliverable (Expected)

**By end of Phase 1 (5-6 days):**
- ✅ Parametric bootstrap fully functional in Rust
- ✅ R wrapper `sm_optim_bootstrap(..., method="parametric")` works
- ✅ Input validation robust
- ✅ Seed reproducibility works
- ✅ All 246+ existing tests still pass
- ✅ Phase 1 tests pass (50+ test cases)
- ✅ Documentation complete (roxygen, examples)

**Not yet (deferred to Phase 2):**
- Sieve bootstrap (requires AR fitting; Phase 2)
- Prediction intervals & diagnostics (Phase 3)
- Sensitivity analysis (Phase 4)

---

## Final Specification

**03e-Uncertainty Phase 1 Specification: COMPLETE & UNAMBIGUOUS**

All 12 user answers integrated. Prompt updated with:
- Dispatcher pattern documentation
- Seed handling specification
- Input validation checklist
- AR failure modes & recovery
- Three-tier fallback logic (auto/explicit/strict)
- Comprehensive final specification table

**Status**: Ready to proceed with Phase 1 implementation.

---

## Sign-Off Checklist

- [x] All 12 user answers reviewed
- [x] Updated 03e-uncertainty.md with all clarifications
- [x] Created integration review document (03e-INTEGRATION-REVIEW.md)
- [x] Added ndarray-linalg to Cargo.toml
- [x] Created Phase 1 readiness report (this document)
- [x] No blocking issues or conflicts identified
- [x] Risk assessment complete with mitigations
- [x] Architecture verified against existing codebase
- [x] Dependencies checked and added
- [x] Testing strategy defined

**RECOMMENDATION: PROCEED WITH PHASE 1 IMPLEMENTATION**

