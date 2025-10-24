# 03d: Custom Geometric Transformations & Complex Shapes

## Objective
Extend the `soilmotif` shape function library with three advanced families: monotone and restricted cubic splines, bivariate coupled shapes with a generic constraint foundation, and threshold-activated piecewise functions. This will enable modeling of complex, polygenetic, and constrained soil profiles.

## Current State
- 7 basic shape functions are implemented in `src/shape_functions.rs`.
- All shapes are normalized to and belong to fixed parameterized families.
- The existing system has no support for data-driven splines, multi-property constraints, or piecewise profiles.

## Deliverables

### D1: Advanced Spline Shapes
**Files:** `src/shape_functions.rs`, `R/shape.R`

1.  **Dual Spline Implementation:** Implement two distinct spline types to handle different soil property behaviors.
    *   **Monotone Cubic Spline:** Use a robust algorithm like the **Fritsch-Carlson or Steffen method** to ensure strict monotonicity. This is for properties like compaction where non-monotonic behavior is physically impossible.
    *   **Restricted Cubic Spline (RCS):** Implement RCS to provide a flexible fit for non-monotonic properties (e.g., pH, organic carbon) while preventing erratic, unrealistic extrapolations at the profile's upper and lower boundaries.

2.  **Rust Interface:**
    ```rust
    pub fn monotone_cubic_spline(
        x: &[f64],           // depths
        control_points: &[(f64, f64)],  // (depth, value) pairs
        ascending: bool,
    ) -> Result<Vec<f64>, String>
    
    pub fn restricted_cubic_spline(
        x: &[f64],           // depths
        control_points: &[(f64, f64)],  // knots for the spline
    ) -> Result<Vec<f64>, String>
    ```

3.  **R Interface (`sm_shape_spline`):** Create a single R evaluation function that dispatches to the correct Rust implementation. This function is for **evaluation**, not direct fitting.
    ```r
    # R evaluation function
    sm_shape_spline <- function(depths, control_points, type = "rcs", 
                                strict = TRUE, ascending = TRUE) {
        # 'type' can be "rcs" or "monotone"
        # Calls the appropriate Rust implementation
    }
    ```

4.  **Strict & Flexible Modes (`strict` flag):**
    *   **`strict = TRUE` (Default):** The function will be strict and throw informative errors if `control_points` are invalid (out-of-order depths, duplicate depths, or y-values that violate `ascending` for monotone splines).
    *   **`strict = FALSE`:** The function will attempt to clean the inputs:
        *   Sort control points by depth.
        *   Average the `y-values` for any duplicate depths.
        *   After cleaning, it will still validate and error if the `y-values` violate the monotonicity required by the monotone spline.

### D2: Bivariate Coupled Shapes
**Files:** `src/shape_functions.rs`, `R/shape.R`

1.  **Generic Constraint Architecture:** Implement the bivariate logic with a generic internal framework that can be extended in the future. For this phase, implement three specific, hard-coded constraints using this new infrastructure.
    *   **Anticorrelation:** Fit `shape_a` and derive `shape_b` directly as `1.0 - value_a`.
    *   **Texture Triangle:** Implement as a bivariate function that fits two components (e.g., sand and clay); the third (silt) is calculated by difference (`1.0 - sand - clay`).
    *   **Coupled Depth:** Ensure two different shapes share a common depth parameter (e.g., their peaks align).

2.  **Rust Interface:** The function will internally call `eval_shape()` for each component shape.
    ```rust
    pub fn bivariate_coupled(
        x: &[f64],
        // Parameters for shape_a, shape_b, and constraint logic
        // ...
    ) -> Result<(Vec<f64>, Vec<f64>), String>
    ```

3.  **R Interface:** Provide a low-level **evaluation** function.
    ```r
    sm_shape_bivariate <- function(depths, shape_a, shape_b, params_a, params_b,
                                   constraint_type = "anticorrelated", ...) {
       # Evaluates the coupled shape based on parameters
    }
    ```

### D3: Threshold-Activated Piecewise Shapes
**Files:** `src/shape_functions.rs`, `R/shape.R`

1.  **Implementation:** Create a function that joins two different standard shape functions at a specified depth.
    *   Use a **logistic function** to create a smooth transition between the `shape_above` and `shape_below` within the `transition_width` zone.

2.  **Rust Interface:**
    ```rust
    pub fn threshold_activated(
        x: &[f64],
        shape_above: (&str, &[f64]),   // (type, params)
        shape_below: (&str, &[f64]),   // (type, params)
        threshold_depth: f64,
        transition_width: f64,
    ) -> Result<Vec<f64>, String>
    ```

3.  **R Interface:** Provide a low-level **evaluation** function.
    ```r
    sm_shape_threshold <- function(depths, shape_above, shape_below, 
                                   params_above, params_below,
                                   threshold, transition_width) {
        # Evaluates the piecewise shape
    }
    ```

### D4: Dispatch, Parameters, and Optimization Integration
**Files:** `src/shape_functions.rs`, `src/lib.rs`

1.  **Parameter Encoding:**
    *   **Splines:** Control points will be passed from R to Rust as a flattened vector: `[depth1, val1, depth2, val2, ...]`.
    *   **Threshold:** `threshold_depth` and `transition_width` will be passed as part of the parameter vector for optimization.
    *   **Bivariate:** The parameter vector for optimization will encode the types, parameters, and constraint information for both shapes.

2.  **Optimizer Compatibility:**
    *   **Full Support:** All new shapes must be compatible with all 5 optimization algorithms (Nelder-Mead, SA, LBFGS, PSO, Newton-CG) and the batch processing system (`src/batch.rs`). Handle any incompatibilities with clear, informative error messages.
    *   **Gradient Support:** Implement `eval_shape_gradient()` for all new shape types where feasible, including the derivatives for splines, coupling constraints, and the logistic blending function. If any are too complex for this phase, document this and ensure they work correctly with gradient-free optimizers.

### D5: R Integration, Documentation & Testing
**Files:** `R/shape.R`, `vignettes/`, `tests/testthat/`

1.  **R Functions:** Create the new low-level evaluation functions: `sm_shape_spline()`, `sm_shape_bivariate()`, `sm_shape_threshold()`. The primary fitting interface remains `sm_optim()`.
2.  **Documentation:** Provide comprehensive Roxygen comments for each new function, with clear soil science examples and guidance on parameter structure.
3.  **Vignette:** Add a new section titled "Modeling Complex Profiles" demonstrating use cases for splines, coupled, and piecewise shapes.
4.  **Testing Strategy:**
    *   Use **synthetic data** that emulates realistic soil profile challenges (e.g., multiple accumulation zones, sharp boundaries).
    *   For threshold shapes, test a wide range of `transition_width` values, from sharp/step-like to very gradual.
    *   Test a representative set of combinations for the underlying shapes in the threshold function.

## Success Criteria
- [ ] All 3 new shape families are implemented, compiling, and tested in Rust.
- [ ] Low-level R evaluation wrappers (`sm_shape_*`) are created for each new shape type.
- [ ] New shapes are fully compatible with `sm_optim()` and the batch processing framework.
- [ ] Gradient computation is implemented where feasible.
- [ ] The `strict = TRUE/FALSE` logic for splines is implemented correctly.
- [ ] The generic constraint foundation for bivariate shapes is in place.
- [ ] Comprehensive unit tests and documentation are delivered.
- [ ] The new vignette section is complete.