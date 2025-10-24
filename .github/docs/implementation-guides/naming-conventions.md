================================================================================
SOILMOTIF PARAMETER NAMING ANALYSIS - QUICK REFERENCE
================================================================================

ANALYSIS DATE: 2025-10-24
SCOPE: 19 R files, ~6000+ lines analyzed
FINDING: 3 major inconsistency issues identified

================================================================================
1. CRITICAL ISSUE: x PARAMETER OVERLOADING
================================================================================

PROBLEM: The parameter 'x' means different things in different contexts:

  Context A - Shape Functions (shape.R):
    sm_shape_sigmoid(x, params)      <- x is DEPTHS (1:200 cm)
    sm_shape_uniform(x, params)      <- x is DEPTHS
    sm_shape_peak(x, params)         <- x is DEPTHS
    
  Context B - Optimization Functions (fit.R):
    sm_optim(x, X, ...)              <- x is OBSERVED VALUES (clay %, etc)
    sm_motif(x, X, ...)              <- x is OBSERVED VALUES
    fit_motif_auto(x, ...)           <- x is OBSERVED VALUES

CURRENT STATUS: INCONSISTENT (breaking cross-module usage)

RECOMMENDATION: 
  Shape functions: rename 'x' → 'depth' (more descriptive)
  Optimization: rename 'x' → 'observed' (more semantic)

IMPACT: 9 shape functions + 3 optimization functions affected
        Estimated 50+ call sites affected
        BREAKING CHANGE - requires version bump

================================================================================
2. SECONDARY ISSUE: PARAMETER VECTOR NAMING
================================================================================

PROBLEM: Model parameters named inconsistently:

  sm_motif(x, X, ...)              <- capital X (confusing)
  sm_optim(x, X, ...)              <- capital X (non-idiomatic in R)
  sm_optim_bootstrap(..., initial_params, ...)  <- explicit (better)
  shape_family output: params      <- generic (documented)

CURRENT STATUS: INCONSISTENT (capital X violates R style guide)

RECOMMENDATION:
  Everywhere: rename 'X' → 'params' (lowercase, clearer)
  Bootstrap: keep 'initial_params' (semantic - indicates starting values)
  
RATIONALE:
  - R style guides prefer lowercase
  - Avoids confusion with matrix operations
  - More intuitive for users
  - Better matches bootstrap function naming

IMPACT: 3 core functions + multiple call sites
        BREAKING CHANGE - requires version bump

================================================================================
3. TERTIARY ISSUE: DEPTH VECTOR HANDLING
================================================================================

PROBLEM: Depth handling varies across functions:

  Shape functions:
    sm_shape_sigmoid(x = 1:200, params)  <- assumes uniform spacing
    No explicit depths parameter
    
  Bootstrap functions:
    sm_optim_bootstrap(observed, depths, ...)  <- explicit depths
    Supports irregular spacing
    
  Optimization:
    sm_optim(x, X, ...)                  <- NO explicit depths
    Assumes: seq_along(x) internally
    Internal dispatch constructs: depth_vector

CURRENT STATUS: PARTIALLY INCONSISTENT (some functions explicit, others implicit)

RECOMMENDATION:
  sm_optim: Add optional 'depths' parameter (default: seq_along(observed))
  sm_motif: Document that uniform 1-cm spacing is assumed
  All shape functions: Clarify that first parameter is depths
  
IMPACT: Core optimization functions, documentation updates
        BREAKING CHANGE if depths parameter is required
        NON-BREAKING if depths parameter is optional with default

================================================================================
SUMMARY BY FILE (19 FILES ANALYZED)
================================================================================

HIGH PRIORITY CHANGES NEEDED:
  ✗ shape.R (9 functions)       - All use 'x' for depth (confusing)
  ✗ fit.R (core functions)      - Uses capital 'X', inconsistent with bootstrap

MEDIUM PRIORITY CHANGES NEEDED:
  ⚠ model-selection.R           - Uses 'x' instead of 'observed'

ACCEPTABLE (NO CHANGES NEEDED):
  ✓ preprocess.R                - Clear 'data' usage for data.frames
  ✓ uncertainty.R               - Good: 'observed, depths, initial_params'
  ✓ horizons.R                  - Good: explicit parameter naming
  ✓ weathering.R                - Good: element-specific naming
  ✓ bayesian.R                  - OK: 'x' is fitted object
  ✓ 10 other files              - Minor or internal functions

================================================================================
FUNCTIONS NEEDING RENAMING (TOP 14 PRIORITIES)
================================================================================

SHAPE FUNCTIONS (9 total) - shape.R:
  1. sm_shape_sigmoid(x, ...)           → sm_shape_sigmoid(depth, ...)
  2. sm_shape_uniform(x, ...)           → sm_shape_uniform(depth, ...)
  3. sm_shape_gradational(x, ...)       → sm_shape_gradational(depth, ...)
  4. sm_shape_exponential(x, ...)       → sm_shape_exponential(depth, ...)
  5. sm_shape_wetting_front(x, ...)     → sm_shape_wetting_front(depth, ...)
  6. sm_shape_abrupt(x, ...)            → sm_shape_abrupt(depth, ...)
  7. sm_shape_peak(x, ...)              → sm_shape_peak(depth, ...)
  8. sm_shape_minimax(x, ...)           → sm_shape_minimax(depth, ...)
  9. sm_shape_spline(x, ...)            → sm_shape_spline(depth, ...)

OPTIMIZATION FUNCTIONS (3 total) - fit.R:
  10. sm_motif(x, X, ...)               → sm_motif(observed, params, ...)
  11. sm_optim(x, X, ...)               → sm_optim(observed, params, ...)
  12. sm_optim_r_impl(x, X, ...)        → sm_optim_r_impl(observed, params, ...)

MODEL SELECTION (1 total) - model-selection.R:
  13. fit_motif_auto(x, ...)            → fit_motif_auto(observed, ...)

OBJECTIVE FUNCTIONS (1 total) - fit.R:
  14. sm_optim_rmse(x, y, ...)          → sm_optim_rmse(observed, predicted, ...)
      sm_optim_ssq(x, y, ...)           → sm_optim_ssq(observed, predicted, ...)

================================================================================
FUNCTIONS TO KEEP (WELL-NAMED)
================================================================================

EXCELLENT EXAMPLES OF CLARITY:
  ✓ sm_optim_bootstrap(observed, depths, initial_params, ...)
  ✓ horizon_boundaries_mahalanobis(data, depth_col, element_cols, ...)
  ✓ horizon_classify_fuzzy(data, depth_col, element_cols, ...)
  ✓ weathering_indices(data, depth_col, element_cols, ...)
  ✓ calculate_CIA(Al2O3, K2O, Na2O)
  ✓ sm_prepare(data, property, method, ...)

PATTERN TO ADOPT:
  - Use 'observed' for numeric vectors of observations
  - Use 'data' for data.frames/SoilProfileCollections
  - Use 'params' for parameter vectors (lowercase!)
  - Use 'depths' for explicit depth coordinates
  - Use 'depth_col' for column name in data.frames
  - Element-specific names (Al2O3, Fe, Zr) in specialized functions

================================================================================
IMPLEMENTATION ROADMAP
================================================================================

PHASE 1 (CRITICAL) - Fix x overloading:
  - Rename all shape functions x → depth
  - Update ~50+ call sites
  - Update tests and examples
  - Update documentation

PHASE 2 (HIGH) - Consolidate parameters:
  - Rename sm_optim/sm_motif X → params
  - Update downstream calls
  - Fix objective function x,y → observed,predicted

PHASE 3 (MEDIUM) - Explicit depths:
  - Add optional depths parameter to sm_optim
  - Document depth assumptions
  - Update uncertainty functions

PHASE 4 (LOW) - Documentation:
  - Create style guide
  - Update developer docs
  - Update naming conventions guide

================================================================================
VERSIONING & COMPATIBILITY NOTES
================================================================================

BREAKING CHANGES: Yes - parameter renames affect public API
SEMANTIC VERSION: Suggest x.0.0 bump (major version)
DEPRECATION: Consider lifecycle::deprecate_soft() for transition
TIMELINE: ~2-3 release cycle for phased deprecation

Estimated impact:
  - User code: ~40% of packages will need updates
  - Examples: All documentation examples need updates
  - Tests: All existing tests need parameter name updates
  - Migration path: Can provide wrapper functions during deprecation

================================================================================
MOST IMPACTFUL SINGLE CHANGE
================================================================================

If only ONE change can be made for maximum benefit:

RENAME: All shape functions 'x' parameter → 'depth'

RATIONALE:
  - Affects 9 of the most-called functions (shape functions)
  - Eliminates semantic confusion between modules
  - Improves code readability the most
  - Easiest to deprecate gradually

This single change would:
  ✓ Clarify semantic meaning
  ✓ Improve API consistency
  ✓ Enhance documentation clarity
  ✓ Reduce user confusion

================================================================================
