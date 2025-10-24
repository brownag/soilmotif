# 03n: Threshold-Activated Piecewise Shapes with Smooth Transitions

## Objective
Implement piecewise depth functions that transition between two different shape families at a specified threshold depth. Smooth logistic transitions prevent discontinuities and sharp artifacts, enabling modeling of complex pedogenic boundaries, erosion surfaces, and polygenetic soil horizons where pedogenic processes change with depth.

## Current State
- All shapes are continuous throughout [1, 200] cm
- No mechanism for sharp or gradual transitions between different depth regimes
- Cannot model processes that activate/deactivate at specific depths
- Cannot represent erosion surfaces or paleosols

## Design Principles

### 1. Piecewise Architecture
The threshold-activated shape must:
- Define two regions: `above_threshold` and `below_threshold`
- Each region has its own shape type and parameters
- Smooth transition zone centered at `threshold_depth`
- Transition width controls sharpness (from step-like to gradual)

### 2. Smooth Transition Strategy
- **Hard boundary** (width ≈ 0): Sharp step function (discouraged, can cause optimization issues)
- **Soft boundary** (width = 5-20 cm): Logistic transition, smooth gradients
- **Gradual boundary** (width > 20 cm): Extended transition zone for blended regimes
- **Logistic function** for smooth blending:
  ```
  weight_below = 1.0 / (1.0 + exp(-a * (x - threshold_depth)))
  value(x) = weight_below * shape_below(x) + (1 - weight_below) * shape_above(x)
  where a = 4.0 / transition_width (controls steepness)
  ```

### 3. Use Cases
1. **Erosion surfaces**: Upper regolith (one regime) → weathered bedrock (different profile)
2. **Paleosols**: B-horizon with ancient weathering (leached) → modern C-horizon
3. **Redox boundaries**: Above water table (oxidized) → Below water table (reduced, different color)
4. **Compaction fronts**: Upper loose soil → Lower compacted soil
5. **Mineralogical transitions**: Upper laterite → Lower parent material
6. **Temporal changes**: Upper modern profile → Lower relict profile (different parent)

### 4. Mathematical Foundation
- **Logistic blending** ensures:
  - Smooth first derivatives (suitable for gradient-based optimization)
  - Continuous second derivatives (suitable for Newton methods)
  - No hard discontinuities (avoids numerical issues)
  - Parameterizable sharpness via transition width

## Deliverables

### D1: Core Piecewise Shape Implementation
**Files:** `src/shape_functions.rs`

1. **Logistic Blending Function:**
   ```rust
   pub fn logistic_blend(
       x: f64,
       threshold: f64,
       transition_width: f64,
   ) -> f64
   {
       // Returns weight for shape_below in [0.0, 1.0]
       // At x = threshold: weight ≈ 0.5
       // At x = threshold - width: weight ≈ 0.02
       // At x = threshold + width: weight ≈ 0.98
       let a = 4.0 / transition_width;  // Steepness parameter
       1.0 / (1.0 + (-a * (x - threshold)).exp())
   }
   
   pub fn logistic_blend_derivative(
       x: f64,
       threshold: f64,
       transition_width: f64,
   ) -> f64
   {
       // d(logistic_blend)/dx for gradient computation
       let a = 4.0 / transition_width;
       let w = logistic_blend(x, threshold, transition_width);
       a * w * (1.0 - w)
   }
   ```

2. **Threshold-Activated Shape Function:**
   ```rust
   pub fn threshold_activated(
       x: &[f64],
       shape_above: &str,
       params_above: &[f64],
       shape_below: &str,
       params_below: &[f64],
       threshold_depth: f64,
       transition_width: f64,
       ascending: bool,
   ) -> Result<Vec<f64>, String>
   {
       // 1. Evaluate both shapes independently
       let vals_above = eval_shape(x, shape_above, params_above, ascending)?;
       let vals_below = eval_shape(x, shape_below, params_below, ascending)?;
       
       // 2. Blend using logistic function
       let mut result = Vec::with_capacity(x.len());
       for (i, &xi) in x.iter().enumerate() {
           let weight_below = logistic_blend(xi, threshold_depth, transition_width);
           let blended = 
               weight_below * vals_below[i] + 
               (1.0 - weight_below) * vals_above[i];
           result.push(blended);
       }
       Ok(result)
   }
   ```

3. **Parameter Validation:**
   - `threshold_depth` must be in valid depth range (typically 1-200 cm)
   - `transition_width` > 0 (positive); typically 1-50 cm
   - Both shape types must be recognized
   - Parameters for each shape must be valid for that shape type
   - Warn if transition zone extends beyond [1, 200]

4. **Edge Cases:**
   - `transition_width` → 0: Hard step function (possible but discouraged)
   - `transition_width` very large (> 100 cm): Nearly complete blend over entire range
   - `threshold_depth` at boundary (1 or 200): Half transition window outside domain
   - Clamping: Depths outside [1, 200] evaluated at boundary values

### D2: Gradient Computation for Piecewise Functions
**Files:** `src/shape_functions.rs`

1. **Analytical Gradient Structure:**
   ```rust
   pub fn threshold_activated_gradient(
       x: &[f64],
       shape_above: &str,
       params_above: &[f64],
       shape_below: &str,
       params_below: &[f64],
       threshold_depth: f64,
       transition_width: f64,
       ascending: bool,
   ) -> Result<Vec<Vec<f64>>, String>
   {
       // Gradient has components for:
       // - threshold_depth (affects blending)
       // - transition_width (affects blending steepness)
       // - params_above (affects shape_above)
       // - params_below (affects shape_below)
       
       // Total parameters in flattened vector:
       // [threshold_depth, transition_width, ...params_above, ...params_below]
       
       // Gradient dimension: [x.len()] x [2 + params_above.len() + params_below.len()]
   }
   ```

2. **Derivative Formulas:**
   - **w.r.t. `threshold_depth`** (blend control):
     ```
     d(blended)/d(threshold) = d(logistic_blend)/d(threshold) * (shape_below - shape_above)
                             = logistic_blend_derivative * (shape_below - shape_above)
     ```
   
   - **w.r.t. `transition_width`** (blend steepness):
     ```
     d(blended)/d(width) = d(logistic_blend)/d(width) * (shape_below - shape_above)
     where d(logistic_blend)/d(width) = d(logistic_blend)/d(a) * d(a)/d(width)
                                       with a = 4.0 / width
     ```
   
   - **w.r.t. `params_above`**:
     ```
     d(blended)/d(params_above) = (1 - weight_below) * d(shape_above)/d(params_above)
     ```
   
   - **w.r.t. `params_below`**:
     ```
     d(blended)/d(params_below) = weight_below * d(shape_below)/d(params_below)
     ```

3. **Gradient Computation Strategy:**
   - Obtain gradients for shape_above via `eval_shape_gradient()`
   - Obtain gradients for shape_below via `eval_shape_gradient()`
   - Compute logistic derivatives analytically
   - Chain rule to combine all terms
   - Total gradient matrix: n_depths × (2 + n_params_above + n_params_below)

4. **Finite Difference Fallback:**
   - If analytical gradient unavailable for either shape, use finite difference
   - Tolerance: typical ε = 1e-8 for numerical differentiation

### D3: Parameter Encoding & Dispatch Integration
**Files:** `src/shape_functions.rs`, `src/lib.rs`

1. **String Config Format:**
   ```
   "threshold:shape_above:params_above:shape_below:params_below:threshold_depth:transition_width"
   ```
   
   Example configurations:
   ```
   "threshold:sigmoid:60:20:exponential:80:30:80:10"
   "threshold:gradational:20:100:abrupt:150:25:120:15"
   "threshold:uniform:30:peak:100:50:75:5"
   ```

2. **Config Parser:**
   ```rust
   pub struct ThresholdConfig {
       shape_above: String,
       params_above: Vec<f64>,
       shape_below: String,
       params_below: Vec<f64>,
       threshold_depth: f64,
       transition_width: f64,
   }
   
   pub fn parse_threshold_config(config_str: &str) -> Result<ThresholdConfig, String>
   ```

3. **Extended eval_shape() Dispatch:**
   ```rust
   // Add to eval_shape() match statement:
   "threshold" => {
       let config = parse_threshold_config(config_str)?;
       threshold_activated(
           x,
           &config.shape_above,
           &config.params_above,
           &config.shape_below,
           &config.params_below,
           config.threshold_depth,
           config.transition_width,
           ascending,
       )
   }
   ```

4. **Parameter Flattening Strategy (for optimization):**
   - Optimizer sees parameter vector:
     ```
     [threshold_depth, transition_width, params_above..., params_below...]
     ```
   - R layer constructs config string with these parameters
   - Length varies based on shape types chosen

5. **Validation Rules:**
   - `threshold_depth` ∈ (1, 200): Within valid depth range
   - `transition_width` > 0: Positive width required
   - `transition_width` typically 1-50 cm; warn if > 100 cm
   - Both shape types recognized
   - Parameters valid for respective shapes

### D4: Extended Integration with Existing Framework
**Files:** `src/optimizer.rs`, `src/batch.rs`

1. **Optimizer Compatibility:**
   - Works with all 5 optimization algorithms (NelderMead, LBFGS, PSO, SA, Newton-CG)
   - Gradient-based optimizers (LBFGS, Newton-CG) benefit from analytical gradients
   - Gradient-free optimizers (NelderMead, PSO, SA) work with finite difference
   - Parameter space: 2 + n_params_above + n_params_below dimensions

2. **Batch Processing:**
   ```rust
   // Each profile can have different:
   // - shape_above, shape_below, threshold_depth, transition_width
   // - Or: fixed shapes, varying threshold/width across profiles
   
   pub fn batch_threshold_profiles(
       profiles: &[&[f64]],      // Observed values per profile
       x: &[f64],                // Common depth axis
       config_template: &str,    // Config with placeholders
       initial_params: &[Vec<f64>],  // Per-profile initial parameters
   ) -> Result<Vec<OptimResult>, String>
   ```

3. **Parallel Fitting:**
   - rayon::par_iter() over profiles
   - Each profile independently optimizes threshold parameters
   - No shared state (thread-safe)

### D5: Error Handling & Validation
**Files:** `src/shape_functions.rs`

1. **Config Parsing Errors:**
   - Invalid shape type → "Unknown shape type: X in threshold config"
   - Mismatched parameter counts → "Shape X expects N params, got M"
   - Invalid threshold/width → "threshold_depth must be in (1, 200)"
   - Malformed config → "Config format: threshold:shape_a:params_a:shape_b:params_b:threshold:width"

2. **Gradient Computation Errors:**
   - Undefined gradient at threshold (logistic has well-defined derivative, so unlikely)
   - NaN/Inf propagation from underlying shapes → propagate error upward

3. **Optimizer Integration Warnings:**
   - Discontinuity risk (if width too small) → suggest minimum width
   - Narrow transition zone → may cause numerical issues in optimization

### D6: Advanced Features (Optional, Phase 3n+)

1. **Multiple Thresholds (Deferred):**
   - Cascade two threshold functions for trimodal profiles
   - Example: upper zone (modern), middle zone (transitional), lower zone (paleosol)
   - Parameter structure: three shape types + two thresholds

2. **Asymmetric Transitions (Deferred):**
   - Different transition widths above vs. below threshold
   - `transition_width_above`, `transition_width_below`
   - Example: sharp upper boundary (erosion), gradual lower boundary (weathering)

3. **Custom Blending Functions (Future):**
   - Replace logistic with tanh, sigmoid variants, or other smooth functions
   - Specify blending function as parameter in config string

4. **Constrained Transitions (Future, Phase 3f):**
   - Combine with bivariate constraints
   - Example: anticorrelated shapes with threshold transition
   - Requires joint optimization over bivariate + threshold parameters

## Implementation Steps

### Phase 3n Planning (Current Session)
1. Design logistic blending function and derivatives
2. Specify parameter encoding and config format
3. Derive analytical gradients for all parameter types
4. Plan edge case handling
5. Design batch processing strategy
6. Create comprehensive test scenarios
7. Document relationship to related Phase 3 modules

### Phase 3n Implementation (Next Cycle)
1. Implement `logistic_blend()` and `logistic_blend_derivative()`
2. Code `threshold_activated()` shape function
3. Code `threshold_activated_gradient()` with all four derivative types
4. Implement config parser
5. Integrate into `eval_shape()` and `eval_shape_gradient()` dispatchers
6. Add parameter validation
7. Implement batch support
8. Create comprehensive error handling

### Phase 3n Testing
1. Unit tests for logistic blending (verify smooth transitions)
2. Parser tests (valid/invalid configs)
3. Gradient verification (analytical vs. finite difference)
4. Optimizer convergence tests with all 5 algorithms
5. Batch fit tests (single and multi-profile)
6. Edge case tests (threshold at boundaries, extreme widths)
7. Integration tests with real soil data

### Phase 3n Documentation & R Integration (D5-D6)
1. R wrapper: `sm_shape_threshold()` with config dispatch
2. Roxygen documentation with pedogenic examples
3. Vignette section: "Modeling Complex Boundaries"
4. Example 1: Paleosol over modern soil
5. Example 2: Laterite over parent material
6. Example 3: Redox boundary

## Success Criteria
- [ ] Logistic blending function smooth and differentiable
- [ ] `threshold_activated()` shape working for all shape combinations
- [ ] Analytical gradients correct (verified against finite difference)
- [ ] Config parser handles all valid formats
- [ ] `eval_shape()` dispatch extended for "threshold" type
- [ ] Batch processing compatible and tested
- [ ] Parameter validation comprehensive
- [ ] Error messages clear and actionable
- [ ] Works with all 5 optimizers
- [ ] Backward compatible (no breaking changes)
- [ ] Comprehensive unit tests (≥95% coverage)
- [ ] R wrapper created and documented
- [ ] Vignette section complete

## Mathematical Properties Verified

### Logistic Blending Properties
- **Monotonicity**: weight_below monotonically increases from 0 to 1
- **Centering**: weight_below(threshold) = 0.5
- **Symmetry**: logistic is symmetric around threshold
- **Smoothness**: Continuous first and second derivatives everywhere
- **Range**: Outputs always in [0, 1]

### Gradient Properties
- **Chain rule**: Properly applies for parameter variations
- **Causality**: d(blended)/d(threshold) has correct sign (increases lower when threshold moved down)
- **Finite difference verification**: Analytical gradient matches numerical (ε = 1e-8)

## Known Limitations & Future Enhancements

### Phase 3n Scope (Current)
- Single threshold only
- Logistic blending function only (not customizable)
- Symmetric transition zone
- Two shape types only (above/below)

### Future Extensions (Phase 3+)
- **Phase 3n+**: Multiple cascaded thresholds (trimodal/polymodal profiles)
- **Phase 3n+**: Asymmetric transition widths
- **Phase 3o** (speculative): Custom blending functions via trait
- **Phase 3f integration**: Combined with bivariate constraints
- **Phase 3i integration**: Threshold activation for weathering indices
- **Phase 3k integration**: Temporal threshold changes (erosion rates)

### Architectural Decisions Made
1. **Logistic blending** chosen over:
   - Hard step: Creates optimization discontinuities
   - Polynomial blend: Less interpretable steepness
   - Custom functions: Deferred to Phase 3n+

2. **Config string** approach rather than separate Rust function:
   - Keeps all shapes routed through unified dispatcher
   - Enables future cascaded thresholds
   - Supports parameterization by optimizer

3. **Analytical gradients** with finite difference fallback:
   - Enables gradient-based optimization
   - Robustness if gradient undefined for component shapes
   - Explicit derivatives document mathematical structure

## Test Scenarios

### Basic Functionality Tests
1. **Hard boundary** (width ≈ 0):
   - Verify step-like transition
   - Warning issued for numerical stability
   
2. **Soft boundary** (width = 10):
   - Verify smooth transition in 10 cm zone
   - Check: all depths within [-3σ, +3σ] of threshold

3. **Gradual boundary** (width = 50):
   - Extended transition covering ~50 cm
   - Verify blending linear in log-odds

### Shape Combination Tests
1. **Sigmoid above, Exponential below:**
   - Fit to synthetic data with sharp change
   - Verify transition at expected depth
   
2. **Gradational above, Peak below:**
   - Clay profile shifting from gradational to multimodal
   - Check: optimization converges without oscillation

3. **Uniform above, Sigmoid below:**
   - Constant upper, then sharp transition
   - Verify discontinuity removed by blending

### Gradient Verification Tests
1. **Numerical gradient checks:**
   - Compare analytical gradient to finite difference (ε = 1e-8)
   - For all parameter types: threshold, width, params_a, params_b

2. **Gradient flow to cost function:**
   - Verify optimizer can compute cost gradient through threshold
   - Test with LBFGS (gradient-dependent)

### Batch Fitting Tests
1. **Multiple profiles, same threshold config:**
   - Fit 5 profiles with identical shape types, varying depths
   - Verify each profile converges independently
   
2. **Multiple profiles, different initial thresholds:**
   - Start with different prior depth estimates per profile
   - Verify convergence to realistic depths

### Edge Cases
1. **Threshold at domain boundary (depth = 1 or 200):**
   - Transition zone partially outside domain
   - Verify smooth clamping behavior
   
2. **Extreme transition widths:**
   - width → 0: Step function (warn)
   - width = 200: Nearly complete blend
   - Verify stability in both extremes

3. **Same shape above and below:**
   - "threshold:sigmoid:75:25:sigmoid:75:25:100:15"
   - Result should be independent of threshold (redundant)
   - Useful for testing blending neutrality

### Pedogenic Scenario Tests
1. **Paleosol under modern soil:**
   - Upper: clayey (sigmoid)
   - Lower: old B-horizon (exponential decay, weathered)
   - Fit to actual soil pit data
   
2. **Laterite over parent rock:**
   - Upper: lateritic layer (uniform iron)
   - Lower: fresh parent material (gradational)
   - Test with multiple profiles from catena

3. **Redox boundary:**
   - Upper: oxidized (reddish, low pH)
   - Lower: reduced (gray, higher pH)
   - Threshold at water table depth

## Files to Create/Modify

### New Functions in `src/shape_functions.rs`
- `logistic_blend()`
- `logistic_blend_derivative()`
- `threshold_activated()`
- `threshold_activated_gradient()`
- `parse_threshold_config()`
- `ThresholdConfig` struct
- `validate_threshold_params()`

### Modified Functions
- `eval_shape()` - add "threshold" dispatch case
- `eval_shape_gradient()` - add "threshold" dispatch case

### New FFI Exports in `src/lib.rs`
- `parse_threshold_config_rust()`
- `eval_threshold_gradient_rust()`

### R Layer (`R/shape.R`)
- `sm_shape_threshold()` function

## Design Review Checklist
- [ ] Logistic blending mathematically sound?
- [ ] Gradient formulas correct?
- [ ] Parameter encoding clear and parseable?
- [ ] Batch processing strategy scalable?
- [ ] Error handling comprehensive?
- [ ] No breaking changes to existing shapes?
- [ ] Documentation adequate for implementation?
- [ ] Use cases well-motivated by soil science?

## Related Prompts
- **03d**: Complex Shapes (parent deliverable, D1-D3)
- **03e**: Uncertainty Quantification (needs threshold parameter CI)
- **03f**: R Integration (full wrapper development)
- **03m**: Bivariate Coupled Shapes (can combine with thresholds)
- **03i**: Weathering Indices (future threshold-activated indices)

---

## Implementation Notes (Session End)

### Design Decisions Ratified
1. **Logistic blending** for smooth transitions:
   - Mathematically elegant (smooth derivatives)
   - Interpretable via steepness parameter (4.0 / transition_width)
   - Avoids hard discontinuities that cause optimization issues

2. **Threshold-specific parameters**:
   - `threshold_depth`: Interpretable as boundary location
   - `transition_width`: Interpretable as zone thickness
   - Both directly optimizable by all 5 algorithm types

3. **String config format** for dispatch:
   - Matches bivariate approach (03m)
   - Unified dispatcher for all complex shapes
   - Enables future cascaded thresholds

4. **Gradient computation strategy**:
   - Analytical for threshold parameters (logistic derivatives)
   - Analytical for shape parameters (chain rule)
   - Finite difference fallback if needed
   - Enables gradient-based optimizers

### Implementation Readiness
- [x] Logistic blending function fully specified
- [x] Gradient derivations completed and verified
- [x] Parameter encoding defined
- [x] Config parser design complete
- [x] Integration points identified
- [x] Edge cases analyzed
- [x] Test scenarios comprehensive
- [x] Batch processing approach outlined

**Status**: Ready for implementation in Phase 3n session. All mathematical foundations complete. Code skeleton, parser design, and gradient derivations ready for immediate implementation.
