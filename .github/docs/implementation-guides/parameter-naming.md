# R Package Parameter Naming Analysis - soilmotif

## Executive Summary

This analysis reviews parameter naming conventions across 19 R source files in the soilmotif package. The codebase shows **significant inconsistency** in parameter naming, particularly for three key parameter categories:

1. **Input data parameters** (values to analyze)
2. **Model parameter vectors** (optimization parameters)
3. **Depth vector parameters** (depth coordinate arrays)

---

## 1. INPUT DATA PARAMETERS

### Current Naming Conventions Found

| Parameter Name | Functions | Context | Frequency |
|---|---|---|---|
| `x` | sm_motif, sm_optim, sm_optim_rmse, sm_optim_ssq, fit_motif_auto, all shape functions | Primary soil property vector | **MOST COMMON** |
| `observed` | sm_optim_bootstrap, uncertainty functions, bootstrapping | Observed soil property data | Moderate |
| `data` | sm_prepare, preprocess functions, horizon_*, weathering_* | DataFrame/SoilProfileCollection | Moderate |
| `data.frame` | Many internal helpers | Explicit type specification | Less common |
| `data_matrix` | Internal horizon functions | Matrix representation | Less common |
| `element_matrix` | horizon_boundaries_mahalanobis, horizon_classify_fuzzy | Element concentration matrices | Less common |

### Analysis

**Most Used Convention: `x`**
- Shape functions (sigmoid, uniform, gradational, exponential, abrupt, peak, minimax): ALL use `x`
- Core optimization functions (sm_optim, sm_motif): Use `x`
- Objective functions (sm_optim_rmse, sm_optim_ssq): Use `x, y`
- Model selection (fit_motif_auto): Uses `x`

**Secondary Convention: `observed`**
- Bootstrap functions: sm_optim_bootstrap uses `observed`
- Uncertainty quantification functions: Use `observed`
- More explicit and semantically meaningful than `x`

**Tertiary Convention: `data`**
- Data preprocessing: sm_prepare, weathering_indices, horizon_* functions
- Generic data.frame parameter
- Used when input is tabular with multiple columns

### Issues & Inconsistencies

1. **sm_optim vs sm_optim_bootstrap**: 
   - sm_optim uses: `sm_optim(x, X, ...)`
   - sm_optim_bootstrap uses: `sm_optim_bootstrap(observed, depths, initial_params, ...)`
   - **Problem**: Same underlying data represented differently

2. **preprocess.R inconsistency**:
   - sm_prepare uses: `sm_prepare(data, property, ...)`
   - Internal helpers use: `.sm_prepare_df_step(data, property, ...)`
   - But variable names inside: `prof_data`, `element_matrix`, etc.

3. **Objective functions ambiguity**:
   - `x` and `y` parameters in sm_optim_rmse/ssq unclear which is observed vs predicted
   - Documentation says: "x = observed, y = predicted" but R convention is often reversed

4. **Horizon detection**:
   - Uses both `data` and `element_matrix`
   - No consistent preference

---

## 2. MODEL PARAMETER VECTORS

### Current Naming Conventions Found

| Parameter Name | Functions | Context | Frequency |
|---|---|---|---|
| `X` (capital) | sm_motif, sm_optim, sm_optim_r_impl | Shape parameters for optimization | **MOST COMMON** |
| `params` | Shape functions param documentation, internal | Generic parameter vector | Moderate |
| `initial_params` | sm_optim_bootstrap, uncertainty functions | Starting parameters for bootstrap | Common |
| `control_points` | sm_shape_spline | Spline knot points | Specialized |
| `param_names` | sm_to_stan_priors, other priors | Parameter name labels | Less common |
| `centers` | Clustering functions (fuzzy horizon) | Cluster center vectors | Domain-specific |

### Analysis

**Most Used Convention: `X` (capital)**
- sm_motif(x, X, FUN...): Uses capital X for shape parameters
- sm_optim(x, X, ...): Continues same convention
- Unusual choice - goes against typical R conventions (usually lowercase)
- Likely influenced by mathematical notation (capital for matrices/parameters)

**Secondary Convention: `initial_params`**
- sm_optim_bootstrap uses explicitly
- More semantically meaningful
- Clearly indicates these are starting values for optimization

**Tertiary Convention: `params`**
- Used in documentation and comments
- Generic but clear

### Issues & Inconsistencies

1. **Capital X unusual in R**:
   - Violates R style guide (tidyverse recommends lowercase)
   - Makes code less readable: `sm_motif(x, X, ...)`
   - Users might confuse with matrix operations

2. **Inconsistent in bootstrap context**:
   - sm_optim uses `X`
   - sm_optim_bootstrap uses `initial_params`
   - sm_motif output has `params` attribute
   - No unified naming strategy

3. **Documentation mismatch**:
   - fit.R comments say "Parameter Semantics by Motif Type" but function uses `X`
   - Rdoc shows both `X` and references to "parameters"

4. **Specialized parameter names**:
   - spline uses `control_points` (good - specific)
   - clustering uses `centers` (good - specific)
   - But these aren't cross-referenced with main parameter naming

---

## 3. DEPTH VECTOR PARAMETERS

### Current Naming Conventions Found

| Parameter Name | Functions | Context | Frequency |
|---|---|---|---|
| (implicit in shape functions) | sm_shape_* functions | Depth from vector position | **MOST COMMON** |
| `depths` | sm_optim_bootstrap, uncertainty, horizons | Explicit depth vector | Very Common |
| `depth` (variable) | preprocess loops, internal | Single depth value in loop | Common |
| `depth_col` | sm_prepare, horizon functions, weathering | Column name for depth | Common |
| `depth_range` | Multiple functions | (min, max) tuple for range | Specialized |
| `depth_vector` | sm_optim Rust dispatch | Explicitly constructed depth vector | Rare |
| `x` (reused!) | Shape functions | **Depth is passed as `x`** | Ambiguous |

### Analysis

**Most Common Pattern: Implicit depths from vector position**
- All shape functions: `sm_shape_sigmoid(x, params, ...)`
- Assumes `x` is a depth vector (1:200)
- No explicit depth parameter needed
- **Problem**: `x` overloaded - means "depths" in shape functions

**Explicit `depths` Convention**:
- Used in bootstrap and uncertainty quantification
- Separate from data values
- Clear and unambiguous
- **Problem**: Not used in shape functions for consistency

**Column name convention `depth_col`**:
- Used in preprocessing and horizon detection
- Specifies which column in data.frame contains depths
- **Problem**: Only for tabular data, not vectors

**Major Design Issue**:
```r
# Shape functions use x as DEPTHS:
sm_shape_sigmoid(x = depths_vector, params = c(40, 60))

# But optimization functions use x as VALUES:
sm_optim(x = values_vector, X = params, FUN = sm_shape_sigmoid)

# This is confusing!
```

### Issues & Inconsistencies

1. **`x` overloaded across module boundary**:
   - Shape functions: `x` = depths
   - Optimization functions: `x` = observed values
   - **MAJOR INCONSISTENCY**

2. **Missing explicit depths in most functions**:
   - sm_optim assumes: `seq(along.with = x)` internally
   - No way to use irregular depth spacing
   - Bootstrap corrects with explicit `depths` parameter
   - Inconsistent API

3. **`depth_range` vs `depths` ambiguity**:
   - `depth_range = c(1, 200)` is (min, max) pair
   - `depths` is full vector
   - Confusing distinction

4. **Rust backend dispatch uses `depth_vector`**:
   - fit.R line 428: `depth_vector <- seq_along(x)`
   - Only for Rust calls
   - Added complexity for internal dispatch

---

## SUMMARY TABLE

### Current State by Category

#### Input Data
```
✗ INCONSISTENT - Mixed use of: x, observed, data
- Exported functions: prefer x (shape functions) or data (preprocessing)
- Internal functions: use data, prof_data, element_matrix
```

#### Model Parameters
```
✗ INCONSISTENT - Mixed use of: X, params, initial_params
- Core optimization: X (unusual capital letter)
- Bootstrap: initial_params (more explicit)
- Documentation: params (generic)
```

#### Depth Vectors
```
✗ MAJOR INCONSISTENCY - Mixed use of: x (implicit), depths, depth_col
- Shape functions: x is implicitly depths
- Bootstrap: explicit depths parameter
- Preprocessing: depth_col column name
- Rust dispatch: depth_vector constructed
```

---

## RECOMMENDATIONS

### PRIORITY 1: Fix `x` Overloading

**Current problematic pattern:**
```r
# These use x differently!
sm_shape_sigmoid(x = 1:200, params)         # x = depths
sm_optim(x = clay_data, X = params)         # x = observations
```

**Recommended standardization:**

For shape functions (no change needed - already good):
```r
sm_shape_sigmoid(depth, params, ascending = TRUE)  # Clear: parameter is depth
```

For optimization functions:
```r
sm_optim(observed, params, ...)              # Not just x
# OR stick with x but document clearly
```

**Affected functions to rename:**
- `sm_shape_sigmoid(x, ...)` → `sm_shape_sigmoid(depth, ...)`
- `sm_shape_uniform(x, ...)` → `sm_shape_uniform(depth, ...)`
- `sm_shape_gradational(x, ...)` → `sm_shape_gradational(depth, ...)`
- `sm_shape_exponential(x, ...)` → `sm_shape_exponential(depth, ...)`
- `sm_shape_wetting_front(x, ...)` → `sm_shape_wetting_front(depth, ...)`
- `sm_shape_abrupt(x, ...)` → `sm_shape_abrupt(depth, ...)`
- `sm_shape_peak(x, ...)` → `sm_shape_peak(depth, ...)`
- `sm_shape_minimax(x, ...)` → `sm_shape_minimax(depth, ...)`
- `sm_shape_spline(x, ...)` → `sm_shape_spline(depth, ...)`
- `fit_motif_auto(x, ...)` → `fit_motif_auto(observed, ...)`

### PRIORITY 2: Standardize Model Parameters

**Recommendation: Use `params` everywhere instead of capital `X`**

```r
# Current (confusing)
sm_optim(x, X, FUN = sm_shape_sigmoid, ...)

# Recommended
sm_optim(observed, params, FUN = sm_shape_sigmoid, ...)
sm_optim_bootstrap(..., initial_params, ...)  # Keep this one clear
```

**Affected functions:**
- `sm_motif(x, X, ...)` → `sm_motif(observed, params, ...)`
- `sm_optim(x, X, ...)` → `sm_optim(observed, params, ...)`
- `sm_optim_r_impl(x, X, ...)` → `sm_optim_r_impl(observed, params, ...)`
- `create_soil_objective(...)` - uses `observed` and `predicted` (already good!)

### PRIORITY 3: Explicit Depths in All Functions

**Recommendation: Always have explicit `depths` parameter or inherit from `observed` length**

```r
# Current - implicit assumption
sm_optim(clay_data, c(40, 60))  # Assumes depths = 1:length(clay_data)

# Recommended pattern
sm_optim(observed, params, depths = 1:length(observed), ...)
# OR at minimum document the assumption clearly
```

**Functions needing review:**
- `sm_optim()` - add explicit depths or document assumption
- `sm_motif()` - document that `x` must be uniform 1-unit spacing
- All shape functions - consistent about what `x` represents
- `fit_motif_auto()` - clarify depth handling

### PRIORITY 4: Fix Data Parameter Confusion

**Recommendation: Clarify usage context**

Use `data` when:
- Input is a data.frame or SoilProfileCollection
- Contains multiple columns (depths, properties, etc.)
- Functions: sm_prepare, weathering_indices, horizon_*

Use `observed` when:
- Input is a numeric vector of observations
- Single property values from preprocessing step
- Functions: sm_optim, sm_optim_bootstrap, shape functions

Use `element_matrix` when:
- Already extracted as matrix from data.frame
- Used in internal algorithmic operations
- Keep this for clarity in multi-element analysis

---

## DETAILED FUNCTION-BY-FUNCTION RECOMMENDATIONS

### HIGH PRIORITY (Core API)

| File | Function | Current | Recommended | Rationale |
|------|----------|---------|-------------|-----------|
| shape.R | sm_shape_sigmoid | `(x, params, ascending)` | `(depth, params, ascending)` | Clarify depth parameter |
| shape.R | sm_shape_uniform | `(x, params, ascending)` | `(depth, params, ascending)` | Clarify depth parameter |
| shape.R | sm_shape_gradational | `(x, params, ascending, type)` | `(depth, params, ascending, type)` | Clarify depth parameter |
| shape.R | sm_shape_exponential | `(x, params, ascending)` | `(depth, params, ascending)` | Clarify depth parameter |
| shape.R | sm_shape_wetting_front | `(x, params, ascending)` | `(depth, params, ascending)` | Clarify depth parameter |
| shape.R | sm_shape_abrupt | `(x, params, ascending)` | `(depth, params, ascending)` | Clarify depth parameter |
| shape.R | sm_shape_peak | `(x, params, ascending)` | `(depth, params, ascending)` | Clarify depth parameter |
| shape.R | sm_shape_minimax | `(x, params, ascending)` | `(depth, params, ascending)` | Clarify depth parameter |
| shape.R | sm_shape_spline | `(x, control_points, type, ascending, strict)` | `(depth, control_points, type, ascending, strict)` | Clarify depth parameter |
| fit.R | sm_motif | `(x, X, FUN, ..., ylim, as_function)` | `(observed, params, FUN, ..., ylim, as_function)` | Consistency + avoid capital X |
| fit.R | sm_optim | `(x, X, ..., FUN, OPTFUN)` | `(observed, params, ..., FUN, OPTFUN)` | Consistency + clarity |
| fit.R | sm_optim_r_impl | `(x, X, ..., FUN, OPTFUN)` | `(observed, params, ..., FUN, OPTFUN)` | Internal consistency |
| model-selection.R | fit_motif_auto | `(x, models, criterion, depth_range, ...)` | `(observed, models, criterion, depth_range, ...)` | Clarity |

### MEDIUM PRIORITY (Supporting Functions)

| File | Function | Current | Recommended | Rationale |
|------|----------|---------|-------------|-----------|
| fit.R | sm_optim_rmse | `(x, y, ...)` | `(observed, predicted, ...)` | Much clearer |
| fit.R | sm_optim_ssq | `(x, y, ...)` | `(observed, predicted, ...)` | Much clearer |
| fit.R | .suggest_initial_params | `(x, motif_type)` | `(observed, motif_type)` | Context clarity |
| fit.R | sm_optim_bootstrap | (already uses `observed, depths, initial_params`) | ✓ KEEP | Already good! |
| horizons.R | .compute_mahalanobis_window | Uses `window_data, reference_center` | ✓ KEEP | Already explicit |
| horizons.R | .create_depth_windows | `(depths, element_matrix, window_size, ...)` | ✓ KEEP | Already explicit |
| horizons.R | horizon_boundaries_mahalanobis | `(data, depth_col, element_cols, ...)` | ✓ KEEP | Already explicit |
| horizons.R | horizon_classify_fuzzy | `(data, depth_col, element_cols, ...)` | ✓ KEEP | Already explicit |

### LOW PRIORITY (Internal/Specialized)

| File | Function | Current | Recommendation |
|------|----------|---------|-----------------|
| bayesian.R | sm_to_priors | `(x, prior_sd_factor)` | ✓ ACCEPTABLE (x is already fitted result object) |
| weathering.R | weathering_indices | `(data, depth_col, element_cols, ...)` | ✓ ACCEPTABLE |
| weathering.R | calculate_CIA | `(Al2O3, K2O, Na2O)` | ✓ ACCEPTABLE (element-specific) |
| preprocess.R | sm_prepare | `(data, property, method, ...)` | ✓ ACCEPTABLE (tabular context clear) |
| spline.R | sm_spline | `(x, ...)` | ⚠ CONSIDER: Could be `data` or `object` |

---

## BACKWARD COMPATIBILITY NOTES

### Breaking Changes Required

All changes to core shape functions and sm_optim would be breaking changes if they're exported. Need to consider:

1. **Deprecation strategy**: Use `lifecycle` package
2. **Wrapper functions**: Create old names that call new names with warning
3. **Version bump**: Semantic versioning (major bump for breaking change)

### Non-Breaking Improvements

- Documentation improvements don't require code changes
- Internal helper functions (starting with `.`) can be changed freely
- New functions should follow recommended conventions

---

## IMPLEMENTATION PRIORITY

**Phase 1 (CRITICAL)**: Fix `x` overloading in shape functions
- Rename shape function parameter from `x` to `depth`
- Update all shape function call sites
- Update all tests
- Update documentation

**Phase 2 (HIGH)**: Consolidate parameter naming
- Rename `X` to `params` in sm_optim and sm_motif
- Update downstream calls
- Update examples and tests

**Phase 3 (MEDIUM)**: Add explicit depths throughout
- Add `depths` parameter to sm_optim (optional, default seq_along)
- Update uncertainty functions to be consistent
- Document depth assumptions clearly

**Phase 4 (LOW)**: Polish and document
- Comprehensive style guide update
- Naming conventions documentation
- Developer onboarding guide

---

## FILE-BY-FILE CURRENT STATE

### shape.R - NEEDS HIGH PRIORITY CHANGES
- ✗ All functions use `x` for depth (confusing)
- ✗ `params` parameter name (good, but inconsistent with sm_optim's `X`)
- Lines affected: All shape function definitions

### fit.R - NEEDS MEDIUM-HIGH PRIORITY CHANGES
- ✗ Uses capital `X` for parameters (unusual)
- ✗ sm_optim uses `x` for observed values (conflicts with shape functions)
- ✗ sm_optim_rmse/ssq use `x, y` (ambiguous)
- ✓ Internal constants clearly named
- Lines affected: Multiple core functions

### preprocess.R - ACCEPTABLE
- ✓ Clear use of `data` for data.frame input
- ✓ `property` parameter name clear
- ✓ Internal helpers well-named
- ✓ No changes needed

### uncertainty.R - GOOD
- ✓ Uses `observed, depths, initial_params` (clear)
- ✓ Configuration object well-structured
- ✓ No changes needed

### horizons.R - ACCEPTABLE
- ✓ Uses explicit parameter names
- ✓ `element_matrix, depths` naming clear
- ✓ Internal helpers descriptive
- ✓ No changes needed

### weathering.R - ACCEPTABLE
- ✓ Element-specific functions clear (calculate_CIA, calculate_WIP, etc.)
- ✓ Uses `data, depth_col, element_cols` appropriately
- ✓ No changes needed

### bayesian.R - ACCEPTABLE
- ✓ Parameter `x` OK (it's a fitted result object)
- ✓ Output parameter naming clear
- ✓ No changes needed

### model-selection.R - NEEDS CHANGE
- ✗ Uses `x` for input data (should be `observed`)
- ✓ Fit statistics function well-named
- Line 50: Function definition needs update

---

