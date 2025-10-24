# 03m: Bivariate Coupled Shapes with Generic Constraint Framework

## Objective
Implement a generic constraint architecture for coupled soil property depth functions. Three initial constraints (anticorrelation, texture triangle, coupled depth) will be hard-coded within this extensible framework, enabling modeling of interdependent pedogenic processes. This lays groundwork for future constraints (mineralogy ratios, oxidation states, moisture-dependent changes).

## Current State
- 7 basic shapes + 2 spline shapes implemented independently
- No coupling between properties (each optimized separately)
- No constraint-based framework
- No mechanism for derived properties (e.g., silt = 1 - sand - clay)

## Design Principles

### 1. Generic Constraint Architecture
The framework must be extensible to support:
- **Equality constraints**: `property_b = f(property_a)` (e.g., anticorrelation)
- **Sum constraints**: `prop_a + prop_b + prop_c = 1.0` (e.g., particle size)
- **Coupling constraints**: `depth_param_a = depth_param_b` (e.g., horizon boundaries)
- **Ratio constraints**: `prop_a / prop_b = constant` (e.g., weathering ratios, future phase)

### 2. Optimization Strategy
- **Fit primary shape**: Optimize all parameters for `shape_a`
- **Derive secondary**: Compute `shape_b` analytically from constraint and `shape_a` output
- **Single objective**: Combine residuals from both properties into unified cost function
- **Batch compatibility**: Support multi-profile fitting with constraints

### 3. Parameter Encoding Strategy
For optimization, the parameter vector will encode:
- Constraint type identifier (string or enum)
- Primary shape type and parameters
- Secondary shape type and parameters (where applicable)
- Constraint-specific parameters (e.g., coupling depth)

Format: **Structured string configuration** passed through `eval_shape()` dispatch
```
"bivariate:constraint_type:shape_a:params_a:shape_b:params_b:extra_config"
```

Example:
```
"bivariate:anticorrelated:exponential:100:50:sigmoid:75:25:unused"
"bivariate:texture_triangle:gradational:50:150:exponential:80:30:unused"
"bivariate:coupled_depth:sigmoid:60:20:sigmoid:90:15:peak_depth=75"
```

## Deliverables

### D1: Generic Constraint Framework (Rust Foundation)
**Files:** `src/shape_functions.rs`

1. **Constraint Trait/Enum (Foundation for future extensibility):**
   ```rust
   #[derive(Debug, Clone)]
   pub enum ConstraintType {
       Anticorrelated,        // shape_b = 1.0 - shape_a
       TextureTriangle,       // third_component = 1.0 - comp_a - comp_b
       CoupledDepth,          // peak_depth_a = peak_depth_b
   }
   
   // Future additions (Phase 3+ planning):
   // MineralRatio,          // Si/Al, Ti/Zr ratios (Phase 3i)
   // OxidationState,        // Fe2+/Fe3+ coupling
   // MoistureDependent,     // Properties coupled through water availability
   ```

2. **Constraint Logic Trait (for future extension):**
   ```rust
   pub trait ConstraintLogic {
       fn apply_constraint(
           &self,
           shape_a: &[f64],
           params_a: &[f64],
           params_b: &[f64],
       ) -> (Vec<f64>, Vec<f64>);  // (shape_a, shape_b)
       
       fn constraint_name(&self) -> &'static str;
   }
   ```
   - Implement for each constraint type
   - Enables adding new constraints without modifying dispatcher

3. **Soft coupling architecture (for future robustness):**
   - Store constraint metadata: type, parameters, metadata
   - Enable constraint versioning (e.g., `CoupledDepth_v1`, `CoupledDepth_v2`)
   - Design for configuration-file-based constraint definitions (future phase)

### D2: Three Core Constraint Implementations
**Files:** `src/shape_functions.rs`

1. **Anticorrelation Constraint:**
   ```rust
   pub fn anticorrelated_shapes(
       x: &[f64],
       shape_a_type: &str,
       params_a: &[f64],
       shape_b_type: &str,
       params_b: &[f64],
   ) -> Result<(Vec<f64>, Vec<f64>), String>
   ```
   - Logic: Fit `shape_a` normally; compute `shape_b = 1.0 - shape_a`
   - Use case: Clay vs. porosity, organic matter vs. mineral content
   - Parameter validation:
     - Shape A parameters must be valid for shape_a_type
     - Shape B parameters are largely ignored (only used if shape_b != derived)
     - Values must fall in [0, 1]

2. **Texture Triangle Constraint (Ternary Closure):**
   ```rust
   pub fn texture_triangle_shapes(
       x: &[f64],
       sand_type: &str,
       sand_params: &[f64],
       clay_type: &str,
       clay_params: &[f64],
   ) -> Result<(Vec<f64>, Vec<f64>, Vec<f64>), String>  // (sand, clay, silt)
   ```
   - Logic: Fit sand and clay independently; derive `silt = 1.0 - sand - clay`
   - Constraint checking:
     - At each depth: `sand + clay + silt = 1.0` within floating-point tolerance
     - All components in [0, 1]
     - Warn if silt < 0 (indicates infeasible sand/clay fit)
   - Use case: Full particle size distribution (PSD) modeling
   - Implementation strategy:
     - Fit sand and clay as independent shapes
     - Clamp silt to [0, 1] at each depth to maintain ternary closure
     - Residuals calculated from all three components

3. **Coupled Depth Constraint (Shared Horizon Markers):**
   ```rust
   pub fn coupled_depth_shapes(
       x: &[f64],
       shape_a_type: &str,
       params_a: &[f64],
       shape_b_type: &str,
       params_b: &[f64],
       coupling_info: &CouplingInfo,  // Specifies which params to couple
   ) -> Result<(Vec<f64>, Vec<f64>), String>
   ```
   - Structure: `CouplingInfo` encodes which parameters are coupled:
     ```rust
     pub struct CouplingInfo {
         // For peak/minimax shapes: couple the "peak_depth" parameter
         coupled_param_name: String,  // e.g., "depth", "peak_depth"
         coupling_ratio: f64,  // e.g., 1.0 (equal), 0.5 (B = 0.5*A)
     }
     ```
   - Logic:
     - Extract `coupled_param` from params_a
     - Apply ratio to get coupled_param for shape_b
     - Adjust params_b accordingly before calling eval_shape()
   - Use case: Iron and clay maxima align at same depth (polygenesis marker)
   - Parameter structure:
     - First depth param is the "primary" coupling anchor
     - Secondary shape's equivalent param is derived: `param_b = ratio * param_a`

4. **Anticorrelation variants (extensibility preview):**
   - Perfect anticorrelation: `shape_b = 1.0 - shape_a`
   - Offset anticorrelation: `shape_b = offset - shape_a` (future)
   - Scaled anticorrelation: `shape_b = scale * (1.0 - shape_a)` (future)

### D3: Dispatch & Parameter Parsing Integration
**Files:** `src/shape_functions.rs`, `src/lib.rs`

1. **String Config Parser (in Rust):**
   ```rust
   pub struct BivariatConfig {
       constraint_type: ConstraintType,
       shape_a: String,
       params_a: Vec<f64>,
       shape_b: String,
       params_b: Vec<f64>,
       extra: std::collections::HashMap<String, String>,  // For future extensions
   }
   
   pub fn parse_bivariate_config(config_str: &str) -> Result<BivariatConfig, String>
   ```
   - Parse format: `"bivariate:CONSTRAINT:shape_a:params_a:shape_b:params_b:extra"`
   - Params are stored as comma-separated floats: `"100,50,25"` or `"[100, 50, 25]"`
   - Handle edge cases:
     - Escaped colons in parameter strings
     - Variable-length parameter lists per shape
     - Optional extra config (key=value pairs)

2. **Extended eval_shape() Dispatch:**
   ```rust
   // Add to eval_shape() match statement:
   "bivariate" => {
       let config = parse_bivariate_config(config_str)?;
       // Route to appropriate constraint implementation
       match config.constraint_type {
           ConstraintType::Anticorrelated => 
               anticorrelated_shapes(...).map(|(a, _)| a),
           ConstraintType::TextureTriangle => 
               // Return primary (sand); handle multi-output separately
               texture_triangle_shapes(...).map(|(s, _, _)| s),
           ConstraintType::CoupledDepth => 
               coupled_depth_shapes(...).map(|(a, _)| a),
       }
   }
   ```
   - Single output (primary shape) for optimizer compatibility
   - Secondary shapes must be evaluated separately if needed

3. **Multi-output handling (for R layer):**
   - Design `get_bivariate_secondary()` function to retrieve coupled/derived properties
   - Called after primary optimization to extract full multi-property profile
   - Example:
     ```rust
     pub fn get_bivariate_secondary(
         config: &BivariatConfig,
         shape_a: &[f64],
         x: &[f64],
     ) -> Result<Vec<f64>, String>
     ```

### D4: Gradient Support for Bivariate Shapes
**Files:** `src/shape_functions.rs`

1. **Analytical Gradients (Where Feasible):**
   - **Anticorrelation**: Straightforward
     ```
     d(shape_b)/d(params_a) = -d(shape_a)/d(params_a)
     d(shape_b)/d(params_b) = 0  (no direct dependence)
     ```
   
   - **Texture Triangle**: Chain rule
     ```
     d(sand)/d(params_sand) = direct gradient
     d(silt)/d(params_sand) = -d(sand)/d(params_sand)  (from closure)
     d(silt)/d(params_clay) = -d(clay)/d(params_clay)
     ```
   
   - **Coupled Depth**: Depends on coupling type
     ```
     d(shape_b)/d(coupled_param_a) = 
         d(shape_b)/d(coupled_param_b) * d(coupled_param_b)/d(coupled_param_a)
     ```

2. **Fallback Strategy:**
   - Analytical gradients preferred; if not available, use finite difference
   - Flag complexity in implementation notes for future phase refinement

3. **FFI Export:**
   ```rust
   pub fn eval_bivariate_gradient(
       x: &[f64],
       config_str: &str,
   ) -> Result<Vec<Vec<f64>>, String>
   ```
   - Returns gradient matrix for primary shape

### D5: Batch Processing Compatibility
**Files:** `src/batch.rs`

1. **Constraint-aware batch fitting:**
   - Each profile in batch can have same constraint type (e.g., all anticorrelated)
   - Or different constraint types (advanced; deferred to Phase 3f)
   - Constraint type specified once; parameters vary per profile

2. **Example batch structure:**
   ```r
   batch_fit_bivariate(
       data = soil_profiles,
       id_col = "site_id",
       constraint = "anticorrelated",
       shape_a = "sigmoid",
       shape_b_derived = TRUE,  # Compute from shape_a
       ...
   )
   ```

3. **Parallel handling:**
   - rayon parallelization over profiles
   - Constraint logic thread-safe (no mutable state)

### D6: Error Handling & Validation
**Files:** `src/shape_functions.rs`

1. **Config Parsing Errors:**
   - Invalid constraint type name → clear error message
   - Mismatched parameter counts → detail expected vs. provided
   - Malformed config string → suggest correct format

2. **Constraint Logic Errors:**
   - Infeasible constraint (e.g., sand > 1.0 after fitting) → warning
   - Coupling parameter not found in shape → error with suggestion
   - Singular/near-singular system (for future ratio constraints) → numerical warning

3. **Gradient Computation Errors:**
   - Undefined gradients at boundaries → document behavior
   - NaN/Inf propagation → check and report in error handling

## Implementation Steps

1. **Phase 3m Planning** (Current sessions):
   - Design constraint trait and enum structure
   - Specify parameter encoding format (strings, parsing)
   - Document three constraint implementations in detail
   - Plan gradient computations (analytical derivations)
   - Create test data and scenarios for validation

2. **Phase 3m Implementation** (Next implementation cycle):
   - Implement `ConstraintType` enum and `ConstraintLogic` trait
   - Code anticorrelation shapes
   - Code texture triangle with ternary closure logic
   - Code coupled depth with parameter extraction
   - Write string parser for config format
   - Integrate into `eval_shape()` dispatch
   - Implement gradients (analytical + finite difference fallback)
   - Implement batch compatibility

3. **Phase 3m Testing**:
   - Unit tests for each constraint type
   - Parser tests (valid/invalid configs)
   - Gradient verification (analytical vs. finite difference)
   - Batch fit tests with multiple profiles
   - Integration tests with all 5 optimizers

4. **Phase 3m Documentation & R Integration** (D5-D6, Phase 3m-adjacent):
   - R wrappers: `sm_shape_bivariate()` with dispatch
   - Roxygen documentation with constraint examples
   - Vignette section: "Coupled Soil Properties"
   - Example: clay-silt texture with texture triangle
   - Example: iron-clay with coupled depth

## Success Criteria
- [ ] Generic constraint framework (enum, trait) implemented
- [ ] Three core constraints working and tested
- [ ] String config parser handles all formats correctly
- [ ] `eval_shape()` dispatch extended for "bivariate" type
- [ ] Analytical gradients where feasible; finite difference fallback
- [ ] Batch processing compatible and tested
- [ ] Error messages clear and actionable
- [ ] Backward compatible (no breaking changes to existing shapes)
- [ ] Comprehensive unit tests (≥95% code coverage)
- [ ] R wrappers created and documented
- [ ] All 5 optimizers work with constrained shapes
- [ ] Vignette section complete

## Known Limitations & Future Enhancements

### Phase 3m Scope (Current)
- Three hard-coded constraints only
- No runtime constraint registration (planned Phase 3m+)
- Anticorrelation assumes perfect inverse (1.0 - value)
- Texture triangle assumes three-component closure
- Coupled depth only supports one coupling per shape pair

### Future Extensions (Phase 3+)
- **Phase 3m+**: User-defined constraint registration via trait impl
- **Phase 3i**: Mineralogy ratios (Si/Al, Ti/Zr from weathering indices)
- **Phase 3i+**: Oxidation state coupling (Fe2+/Fe3+)
- **Phase 3k**: Temporal constraints (coupled through hydrological cycles)
- **Phase 3k+**: Causal networks (correlation ← inferred causality)
- **Fully General**: Algebraic constraint solver (sparse matrix approach)

### Architectural Decisions Made
1. **String config via eval_shape() dispatch** rather than separate fn:
   - Keeps all shape types routed through single dispatcher
   - Enables future constraint composition
   - Optimizer changes minimal
   
2. **Primary shape output** from `eval_shape()`:
   - Simplifies cost function calculation
   - Secondary shapes obtained via separate call
   - Reduces optimizer state complexity

3. **Trait-based extensibility** (ConstraintLogic):
   - Future constraints added without modifying dispatcher
   - Enables user extensions in Phase 3m+
   - Follows soilmotif design patterns

## Test Scenarios

### Anticorrelation Tests
1. Clay (sigmoid) vs. porosity (1.0 - clay)
   - Verify: porosity + clay = 1.0 everywhere
   - Fit porosity; verify clay matches
   
2. Organic matter (exponential) vs. mineral (1.0 - OM)
   - Test with noise added to both
   - Verify constraint holds after optimization

### Texture Triangle Tests
1. Standard PSD: sand (gradational), clay (sigmoid), silt = 1 - sand - clay
   - Verify: each point sums to 1.0
   - Fit to real soil pit data
   
2. Edge cases:
   - All sand (fine), all clay, all silt: verify closure
   - Silt becomes negative → should be clamped or error

### Coupled Depth Tests
1. Iron oxide (peak) and clay (sigmoid) with peaks at same depth
   - Set iron peak_depth = clay peak_depth
   - Verify after fitting: both maxima at same depth
   
2. Modify coupling ratio: clay_peak_depth = 0.9 * iron_peak_depth
   - Verify slight offset is maintained

### Batch Fitting Tests
1. Multiple profiles with same constraint type
   - Fit all profiles with anticorrelation
   - Verify each profile satisfies constraint independently
   
2. Mixed constraints in batch (advanced):
   - Some profiles anticorrelated, others texture triangle
   - Deferred to Phase 3m extension

## Files to Create/Modify

### New Functions in `src/shape_functions.rs`
- `ConstraintType` enum
- `ConstraintLogic` trait
- `anticorrelated_shapes()`
- `texture_triangle_shapes()`
- `coupled_depth_shapes()`
- `parse_bivariate_config()`
- `eval_bivariate_gradient()`
- `BivariatConfig` struct
- `CouplingInfo` struct

### Modified Functions
- `eval_shape()` - add "bivariate" dispatch case
- `eval_shape_gradient()` - add "bivariate" dispatch case

### New FFI Exports in `src/lib.rs`
- `parse_bivariate_config_rust()`
- `eval_bivariate_gradient_rust()`

### R Layer (`R/shape.R`)
- `sm_shape_bivariate()` function

## Design Review Checklist
- [ ] Constraint trait design supports future extensions?
- [ ] Parameter encoding strategy clear and parseable?
- [ ] Gradient computations analytically sound?
- [ ] Batch processing strategy scalable?
- [ ] Error handling comprehensive?
- [ ] No breaking changes to existing code?
- [ ] Documentation adequate for implementation?

## Related Prompts
- **03d**: Complex Shapes (parent deliverable, D1-D2)
- **03e**: Uncertainty Quantification (needs bivariate support)
- **03f**: R Integration (full wrapper development)
- **03i**: Weathering Indices (future ratio constraints)
- **03j**: Correlation Networks (multivariate constraints)

---

## Implementation Notes (Session End)

### Design Decisions Ratified
1. **Structured string config** for bivariate shapes:
   - Chosen over separate FFI functions to keep dispatcher unified
   - Parsing in Rust for efficiency
   - Enables future constraint composition

2. **Generic trait-based architecture** for constraints:
   - ConstraintLogic trait allows adding constraints without code duplication
   - Future extensions (mineralogy, oxidation) can be added cleanly

3. **Three core constraints** prioritized by soil science value:
   - Anticorrelated (immediate: clay↔porosity, OM↔minerals)
   - Texture Triangle (immediate: PSD closure constraint)
   - Coupled Depth (medium-term: horizon markers, polygenesis)

4. **Gradient strategy**:
   - Analytical where feasible (anticorrelation, texture triangle)
   - Finite difference fallback for complex couplings
   - Enables gradient-based optimizers without requiring every constraint to implement analytical gradient

### Implementation Readiness
- [x] Architecture fully specified
- [x] Parameter formats defined
- [x] Gradient derivations completed
- [x] Three constraint implementations detailed
- [x] Error handling strategy determined
- [x] Batch processing approach outlined
- [x] Test scenarios planned

**Status**: Ready for implementation in next Phase 3m session. Code skeleton, trait definitions, and parser design ready for immediate coding.
