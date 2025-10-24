# Phase 1: Expand R Package Core
## Phase Overview & Coordination Guide

**Duration:** ~3 weeks  
**Goal:** Transform soilmotif from a single-motif proof-of-concept into a comprehensive tool supporting all seven soil depth function typologies, with automated model selection and streamlined data preprocessing.

**Deliverables:**
- Seven shape functions (Uniform, Gradational, Exponential, Wetting Front, Abrupt, Peak, MiniMax)
- Generalized optimization framework compatible with all motif types
- Automated model selection engine with AIC/BIC ranking
- Data preprocessing helpers for common soil data formats
- Full test coverage and updated documentation

---

## Subphase Dependencies

```
1.A (Shape Functions)
    v
1.B (Optimization Framework) <- depends on 1.A
    v
1.C (Model Selection) <- depends on 1.A, 1.B
    v
1.D (Data Preprocessing) <- independent; can run in parallel with 1.C
    v
1.E (Testing & Documentation) <- depends on all above
```

**Can parallelize:** 1.A & 1.D can begin simultaneously if agents are available.

---

## Subphase Breakdown

### **1.A: Shape Functions**
**Deliverable:** Seven shape functions matching the book chapter typologies  
**Prompt:** `01a-shape-functions.md`  
**Estimated Time:** 4-5 hours  
**Est. Lines of Code:** 150-200 R

**Key Outputs:**
- `sm_shape_uniform()`
- `sm_shape_gradational()`
- `sm_shape_exponential()`
- `sm_shape_wetting_front()` (sigmoid; currently hard-coded, needs parameterization)
- `sm_shape_abrupt()`
- `sm_shape_peak()`
- `sm_shape_minimax()`

**Acceptance Criteria:**
- Each function accepts `x` (depth vector) and shape-specific `xlim` / parameter vector
- All functions return numeric vectors in [0, 1] range (pre-scaling)
- All functions handle `ascending` parameter for directionality
- Unit tests in `tests/testthat/test-shape.R` (expand existing)
- No breaks to existing `sm_shape_sigmoid()` behavior

---

### **1.B: Generalized Optimization Framework**
**Deliverable:** Enhanced `sm_optim()` supporting all motif types  
**Prompt:** `01b-optimization-framework.md`  
**Estimated Time:** 3-4 hours  
**Est. Lines of Code:** 100-150 R

**Key Outputs:**
- Updated `sm_motif()` to accept any shape function
- Updated `sm_optim()` to work with all seven motif types
- Helper function `..find_initial_params()` to suggest starting points
- Objective function variants for edge cases

**Acceptance Criteria:**
- `sm_optim(x, X, FUN = sm_shape_*(), ...)` works for all shape functions
- Parameter sorting logic extended to all types (or documented exceptions)
- Initial parameter suggestion framework working
- Integration tests: each shape function fits a synthetic profile
- Backward compatibility: existing code using `sm_shape_sigmoid()` unchanged

---

### **1.C: Model Selection Engine**
**Deliverable:** Automated fitting and ranking of multiple motif types  
**Prompt:** `01c-model-selection.md`  
**Estimated Time:** 4-5 hours  
**Est. Lines of Code:** 150-200 R

**Key Outputs:**
- `fit_motif_auto(x, models = "all", criterion = "AIC", ...)` function
- Model comparison framework (RMSE, AIC, BIC, R^2)
- Visualization helper for model rankings
- Multi-model fitting reports

**Acceptance Criteria:**
- `fit_motif_auto()` tests all seven models against input data
- Returns ranked list with fit statistics for each
- `criterion = "AIC"` | `"BIC"` | `"RMSE"` | `"R2"` options
- Handles edge cases (data too short, failed optimizations)
- Comprehensive tests with synthetic and real data
- Performance: 200-point profile fitted across all 7 models in <2 sec (R)

---

### **1.D: Data Preprocessing Helpers**
**Deliverable:** Functions to convert horizon/sensor data to continuous vectors  
**Prompt:** `01d-data-preprocessing.md`  
**Estimated Time:** 3-4 hours  
**Est. Lines of Code:** 100-150 R

**Key Outputs:**
- `sm_prepare(data, method = "step", ...)` for generic preprocessing
- `sm_prepare_step()` for step-function conversion
- `sm_prepare_spline()` for spline interpolation (wraps `mpspline2` if available)
- `sm_prepare_linear()` for linear interpolation
- Integration with `aqp::SoilProfileCollection` objects

**Acceptance Criteria:**
- Accepts data.frame, SoilProfileCollection, or character path to CSV
- Returns consistent output: named list of continuous vectors
- `method = "step"` | `"spline"` | `"linear"` working
- Handles missing values, irregular depths gracefully
- Optional `aqp` dependency guarded by `requireNamespace()`
- Tests with diverse input formats

---

### **1.E: Testing & Documentation**
**Deliverable:** Comprehensive tests and roxygen2 documentation  
**Prompt:** `01e-testing-documentation.md`  
**Estimated Time:** 5-6 hours  
**Est. Lines of Code:** 200-300 (test + doc code combined)

**Key Outputs:**
- Expanded `test-shape.R` with unit tests for all shape functions
- New `test-fit.R` with optimization framework tests
- New `test-model-selection.R` with `fit_motif_auto()` tests
- New `test-preprocessing.R` with data pipeline tests
- Roxygen2 documentation for all new functions
- Updated `README.md` with expanded examples
- New vignette: "Fitting Multiple Motif Types"

**Acceptance Criteria:**
- `devtools::test()` passes with 0 failures/errors
- Coverage >80% for new code
- `devtools::document()` regenerates docs without errors
- `R CMD check --as-cran --no-build-vignettes` passes
- All README examples still run
- NAMESPACE updated with new exports
- NEWS.md updated with Phase 1 summary

---

## Phase 1 Workflow for Agents

### Agent 1 (Subphase 1.A)
1. Read `01a-shape-functions.md`
2. Implement seven shape functions in `R/shape.R`
3. Ensure backward compatibility with existing sigmoid
4. Run `devtools::test()` (existing test-shape.R)
5. Commit: `Phase 1.A: Add six new shape functions`
6. Hand off to Agent 2

### Agent 2 (Subphase 1.B)
1. Read `01b-optimization-framework.md`
2. Verify all shape functions from Agent 1 work
3. Update `sm_motif()` and `sm_optim()` in `R/fit.R`
4. Write integration tests
5. Commit: `Phase 1.B: Generalize optimization framework`
6. Hand off to Agent 3 (or same agent if serial)

### Agent 3 (Subphase 1.C)
1. Read `01c-model-selection.md`
2. Verify shape functions and optimization from prior agents
3. Implement `fit_motif_auto()` in new file or `R/fit.R`
4. Write comprehensive tests
5. Commit: `Phase 1.C: Add automated model selection`
6. Hand off to Agent 4

### Agent 4 (Subphase 1.D)
1. Read `01d-data-preprocessing.md`
2. Can run in parallel with 1.C; verify dependencies
3. Implement `sm_prepare()` family in new file `R/preprocess.R`
4. Write tests for various input formats
5. Commit: `Phase 1.D: Add data preprocessing helpers`
6. Signal completion to Agent 5

### Agent 5 (Subphase 1.E)
1. Read `01e-testing-documentation.md`
2. Verify all prior code integrated
3. Expand tests, regenerate docs, update README
4. Run full `R CMD check` suite
5. Update NEWS.md
6. Commit: `Phase 1.E: Comprehensive testing and documentation`
7. Signal phase complete

---

## Communication & Handoff

### Between Subphases
- **Update `PHASE_STATUS.md`** with completion timestamp
- **Run `devtools::test()`** and confirm all pass
- **Commit to git** with descriptive message
- **Note any blockers** in PHASE_STATUS.md for next agent

### Exit Criteria for Phase 1
- [x] All subphases completed
- [x] `R CMD check --as-cran --no-build-vignettes` passes
- [x] `devtools::test()` shows 0 failures
- [x] README still works
- [x] Version bump to 0.1.0 in DESCRIPTION
- [x] Phase 1 agent signs off in PHASE_STATUS.md

---

## Key Files to Modify / Create

| File | Status | Notes |
|------|--------|-------|
| `R/shape.R` | Expand | Add 6 new shape functions |
| `R/fit.R` | Modify | Update `sm_motif()`, `sm_optim()`, add helpers |
| `R/preprocess.R` | Create | New file for `sm_prepare()` family |
| `R/model-selection.R` | Create | New file for `fit_motif_auto()` |
| `tests/testthat/test-shape.R` | Expand | Add tests for all 7 shapes |
| `tests/testthat/test-fit.R` | Expand | Add optimization framework tests |
| `tests/testthat/test-model-selection.R` | Create | Tests for model selection |
| `tests/testthat/test-preprocess.R` | Create | Tests for data preprocessing |
| `man/` | Regenerate | Roxygen2 output |
| `NAMESPACE` | Regenerate | Roxygen2 output |
| `DESCRIPTION` | Update | Version -> 0.1.0; add any new imports |
| `README.md` | Expand | New examples covering all motif types |
| `NEWS.md` | Update | Document Phase 1 changes |

---

## Testing Strategy

### Unit Tests (per subphase)
- Shape functions: inputs, ranges, directionality
- Optimization: convergence, parameter consistency
- Model selection: ranking, tie-breaking, edge cases
- Data preprocessing: format conversions, interpolation accuracy

### Integration Tests
- Full pipeline: data -> preprocessing -> fit -> compare
- Cross-compatibility: all combinations of data formats + motif types
- Backward compatibility: existing README examples unchanged

### Performance Tests (Phase 1.C)
- Single profile x 7 models: target <2 sec
- 100 profiles x 1 model: target <1 sec

---

## Common Pitfalls & How to Avoid Them

| Pitfall | Prevention |
|---------|-----------|
| Breaking existing sigmoid code | Run `devtools::test()` after each change; use feature branches |
| Parameter sorting assumptions | Document for each motif type; test with unsorted inputs |
| Depth axis confusion (1-200 vs 200-1) | Always use `ylim = c(1, 200)` in internal functions; invert for plotting |
| Scaling extrapolation artifacts | Review `.scaleprop()` logic; test with edge values |
| `aqp` dependency breaking tests | Use `requireNamespace()` guards; provide CSV fallback examples |
| AIC calculation errors | Cross-check formula against standard references; validate with synthetic data |

---

## Resources & References

### Within Repository
- `README.md` -- Current working examples
- `misc/test-fit.R` -- Prior experimentation code
- `man/` -- Existing roxygen2 documentation style

### External
- Book chapter: "Measuring and Modelling Soil Depth Functions"
- `stats::optim()` documentation for optimization details
- `mpspline2` vignette for spline interpolation
- `aqp` documentation for SoilProfileCollection structure

---

## Phase 1 Success Metrics

| Metric | Target |
|--------|--------|
| Shape functions implemented | 7/7 |
| Tests passing | 100% |
| Code coverage (new code) | >80% |
| Backward compatibility | 100% (no breaking changes) |
| Performance (7 models, 200 depths) | <2 sec |
| README examples working | 100% |
| CRAN check status | PASS |

---

**Phase 1 Lead:** [Agent Name / TBD]  
**Phase 1 Start Date:** [TBD]  
**Phase 1 Target Completion:** [TBD + 3 weeks]  
**Phase 1 Status:** NOT STARTED
