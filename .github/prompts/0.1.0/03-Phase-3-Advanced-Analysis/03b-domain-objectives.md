# 03b: Domain-Specific Optimization Objectives

## Objective
Implement pluggable domain-specific loss functions as argmin CostFunction traits: depth-weighted RMSE, ordinal error, bounded error, Huber loss, and quantile loss.

## Current State
- Basic objectives implemented in `src/objective.rs` (RMSE, SSE, MAE, R²)
- Pluggable via `ObjectiveFunction` trait
- No domain-specific variants for soil science applications
- No parameter configuration for weighted or robust objectives

## Deliverables

### D1: Depth-Weighted RMSE
**File:** `src/objective.rs`

1. **Implement WeightedRMSE:**
   ```rust
   pub struct WeightedRMSE {
       pub target_depth: f64,
       pub weight_factor: f64,  // e.g., 2.0 for 2x emphasis at target depth
   }
   
   impl CostFunction for WeightedRMSE {
       // Gaussian weights centered on target_depth
       // weight(d) = exp(-weight_factor * (d - target_depth)^2)
   }
   ```

2. **R Interface in fit.R:**
   - `sm_optim(..., objective = "weighted_rmse", target_depth = 100, weight_factor = 1.0)`
   - Use case: prioritize clay accumulation zone (e.g., depth 75-125)

3. **Testing:**
   - Verify weights centered at target depth
   - Compare to unweighted RMSE (should differ)

### D2: Ordinal Error (Direction-Aware)
**File:** `src/objective.rs`

1. **Implement OrdinalError:**
   ```rust
   pub struct OrdinalError {
       pub underpredict_penalty: f64,  // e.g., 1.5 for conservative estimates
       pub overpredict_penalty: f64,   // e.g., 1.0
   }
   
   // Separate penalties for pred < obs vs pred > obs
   ```

2. **Soil science use case:**
   - Argillic horizon: prefer underestimation (penalty_under > penalty_over)
   - Diagnostic depth classification: avoid overestimating

3. **Testing:**
   - Verify asymmetric penalties in cost calculation

### D3: Bounded Error (Range-Constrained)
**File:** `src/objective.rs`

1. **Implement BoundedError:**
   ```rust
   pub struct BoundedError {
       pub obs_min: f64,
       pub obs_max: f64,
       pub penalty_factor: f64,
   }
   
   // Large penalty if prediction outside [obs_min, obs_max]
   ```

2. **Applications:**
   - pH: constrained to 3-10
   - Texture (percent): constrained to 0-100
   - Clay accumulation: typically 0-60%

3. **Testing:**
   - Verify penalty applied for out-of-bounds predictions

### D4: Huber Loss (Robust to Outliers)
**File:** `src/objective.rs`

1. **Implement HuberLoss:**
   ```rust
   pub struct HuberLoss {
       pub delta: f64,  // transition point (e.g., 1.35 * MAD)
   }
   
   // Quadratic for |residual| <= delta, linear for larger
   ```

2. **Motivation:**
   - pXRF measurements often have measurement errors/outliers
   - Avoids RMSE inflation from single bad measurements

3. **Testing:**
   - Compare fit with/without outliers (Huber should be more stable)

### D5: Quantile Loss (L-q Regression)
**File:** `src/objective.rs`

1. **Implement QuantileLoss:**
   ```rust
   pub struct QuantileLoss {
       pub quantile: f64,  // e.g., 0.9 for 90th percentile
   }
   
   // Asymmetric penalty: higher weight for over/underestimation
   ```

2. **R Interface:**
   - `sm_optim(..., objective = "quantile", quantile = 0.5)` for median
   - `quantile = 0.9` for conservative (high) estimates
   - `quantile = 0.1` for aggressive (low) estimates

3. **Use case:**
   - Uncertainty bands: fit 10th, 50th, 90th quantiles simultaneously
   - Risk assessment: conservative vs aggressive estimates

4. **Testing:**
   - Verify 0.5 quantile approximates median
   - Verify quantile behavior on synthetic data

### D6: Objective Registry & R Interface
**Files:** `src/optimizer.rs`, `R/fit.R`

1. **Extend create_objective() to handle all new types:**
   ```rust
   pub fn create_objective_with_params(
       name: &str,
       params: &ObjectiveParams  // config struct with all options
   ) -> Result<Arc<dyn CostFunction>, String>
   ```

2. **R wrapper function in fit.R:**
   - `create_soil_objective(type, ...args)` helper
   - Validate parameter ranges (e.g., quantile in 0-1, penalties > 0)
   - Return objective object for use with `sm_optim()`

3. **Backward compatibility:**
   - Existing `objective_type = "rmse"` still works
   - New objectives require explicit opt-in

## Implementation Steps

1. Add new objective structs to `src/objective.rs`
2. Implement CostFunction trait for each
3. Update `create_objective()` to recognize new types
4. Add parameters to `ObjectiveParams` struct (or similar)
5. Create R wrapper functions in `R/fit.R`
6. Test each objective with representative soil data
7. Run full test suite: `make test`
8. Document use cases in roxygen comments

## Success Criteria
- [ ] All 5 new objectives compiling and working
- [ ] Unit tests for each objective with known data
- [ ] R interface exposes all objectives
- [ ] Backward compatible (default RMSE unchanged)
- [ ] Documentation with soil science examples
- [ ] No performance regression vs Phase 2

## Files to Review
- `src/objective.rs` - objective implementations
- `src/optimizer.rs` - objective creation/registry
- `R/fit.R` - R interface for objectives
- `tests/testthat/test-rust-comparison.R` - test patterns

## Test Scenarios
- Depth-weighted: Verify higher weights at target depth
- Ordinal: Verify different penalties for over/under
- Bounded: Verify penalties for violations
- Huber: Robust fit with outlier
- Quantile: Quantile behavior (0.5 ~ median, 0.9 ~ upper)

## Related Prompts
- 03a: Argmin Integration (prerequisite)
- 03d: Bootstrap & Uncertainty (uses these objectives)
