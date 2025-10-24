````markdown
# Phase 3: Advanced Optimization & Pedogenic Analysis
## Phase Overview & Extended Soil Science Capabilities

**Duration:** Q1-Q3 2026 (after Phase 2 foundation complete)  
**Goal:** Extend soilmotif with domain-specific optimization objectives, advanced algorithms, advanced pedogenic analysis methods (horizon boundaries, fuzzy clustering, weathering indices), and uncertainty quantification.

**Deliverables (Optimization Track):**
- Domain-specific objective functions (depth-weighted, ordinal, bounded, Huber, quantile)
- Advanced optimization algorithms (simulated annealing, PSO, genetic, differential evolution)
- Custom geometric transformations (monotone splines, bivariate shapes, threshold-activated)
- Uncertainty quantification (bootstrap CI, sensitivity analysis)
- R ecosystem integration (tidyverse, Bayesian, visualization)

**Deliverables (Analysis Track):**
- Horizon boundary detection via Mahalanobis distance (moving window)
- Fuzzy k-means clustering for soil horizon classification
- Weathering indices (SiO_2/Al_2O_3, Ti/Zr ratios)
- Index of Profile Anisotropy (IPA)
- Novel spatial data products (horizon depth maps, weathering indices rasters)

---

## Phase 3 Tracks

Phase 3 expands soilmotif in **two complementary directions**:

| Track | Focus | Timeline | Impact |
|-------|-------|----------|---------|
| **Optimization** | Custom objectives, algorithms, uncertainty | Q1-Q3 2026 | Better model fitting for diverse use cases |
| **Analysis** | Horizon detection, indices, spatial products | Q1-Q2 2026 | Novel pedogenic insights from fitted profiles |

Both tracks use Phase 2's pluggable architecture as foundation. Parallel implementation recommended.

---

## Subphase Dependencies

### Optimization Track (Phase 3-OPT)

```
3-OPT.A (Domain Objectives: weighted, ordinal, bounded, Huber, quantile)
    v
3-OPT.B (Advanced Algorithms: SA, PSO, GA, DE, auto-selection)
    v
3-OPT.C (Custom Shapes: splines, bivariate, threshold) <- can run in parallel with B
    v
3-OPT.D (Uncertainty: bootstrap CI, sensitivity analysis)
    v
3-OPT.E (R Integration: tidyverse, Bayesian, visualization)
```

### Analysis Track (Phase 3-ANAL)

```
3-ANAL.A (Horizon Boundaries)
    v
3-ANAL.B (Fuzzy k-means) <- can run in parallel with 3-ANAL.A
    v
3-ANAL.C (Weathering Indices) <- independent
    v
3-ANAL.D (Profile Anisotropy) <- independent
```

Both tracks can proceed in parallel after Phase 2.

---

## OPTIMIZATION TRACK (Phase 3-OPT)

### **Argmin Framework Integration**
**Foundation:** Leverage existing `argmin` crate for pluggable optimization algorithms and objectives  
**Objective:** Replace custom optimization code with battle-tested `argmin` library, enabling extensible optimization schemes  
**Key Insight:** `argmin` provides the pluggable trait architecture needed for Phase 3-OPT deliverables  

**Framework Benefits:**
- **Pluggable Objectives:** Easy implementation of domain-specific loss functions (weighted, ordinal, bounded, Huber, quantile)
- **Algorithm Library:** Access to proven algorithms (Nelder-Mead, L-BFGS, Newton methods) without custom implementation
- **Parameter Bounds:** Native support for constrained optimization (critical for soil property bounds)
- **Extensibility:** User-designed optimization schemes can leverage `argmin`'s trait system
- **Performance:** Optimized implementations with better convergence than custom code

**Integration Strategy:**
1. **Refactor Phase 2 Optimizer:** Replace custom Nelder-Mead with `argmin::NelderMeadSolver`
2. **Expose Algorithm Selection:** Allow users to choose from `argmin`'s algorithm library
3. **Custom Objectives as Traits:** Implement domain objectives as `argmin::CostFunction` traits
4. **Bounds Support:** Use `argmin` bounds for physical constraints (pH 3-10, texture 0-100%)
5. **User Extension Points:** Provide trait interfaces for user-designed algorithms/objectives

**Deliverable Impact:**
- **3-OPT.A Objectives:** All 5 domain objectives implemented as pluggable `CostFunction` traits
- **3-OPT.B Algorithms:** Access `argmin`'s algorithm library instead of custom implementations
- **3-OPT.C Shapes:** Custom shapes work with any `argmin` algorithm via unified interface
- **3-OPT.D Uncertainty:** Bootstrap and sensitivity analysis work with any `argmin` result
- **3-OPT.E Integration:** R interface exposes `argmin` algorithm selection and custom objectives

**Exit Criteria for Argmin Integration:**
- [ ] Custom optimizer replaced with `argmin::NelderMeadSolver` (maintains Phase 2 API)
- [ ] Algorithm selection exposed: `sm_optim(..., algorithm = "nelder_mead|lbfgs|newton")`
- [ ] Custom objectives work with any algorithm: `sm_optim(..., objective = "huber_loss")`
- [ ] Parameter bounds functional: `sm_optim(..., lower = c(0,0), upper = c(200,200))`
- [ ] User extension interface: `custom_algorithm <- make_argmin_solver(my_solver)`
- [ ] Performance improved vs Phase 2 (better convergence, same or better speed)

---

### **3-OPT.A: Domain-Specific Objectives**
**Objective:** Extend single-profile optimizer with soil science-relevant loss functions  
**Prompt:** `03-opt-a-domain-objectives.md`  
**Estimated Time:** 1-2 weeks  
**Est. Rust Code:** 300-400 lines  
**Est. R Code:** 100-150 lines  

**Subdeliverables:**

**3-OPT.A.1: Depth-Weighted RMSE**
- Problem: Standard RMSE treats all depths equally; soil science often prioritizes deep diagnostic horizons
- Solution: Gaussian weight function centered on key depths (e.g., clay accumulation zone)
- Implementation: `argmin::CostFunction` trait with weighted residual calculation
- R Interface: `weight_by_depth(depths, target_depth, weight_factor)`

**3-OPT.A.2: Ordinal Error (Direction-Aware)**
- Problem: Over/under-predicting may have asymmetric consequences
- Solution: Allow separate penalties for positive vs negative residuals
- Example: Argillic horizon classification prefers underestimation (conservative)
- Implementation: `OrdinalCost { underpredict_penalty, overpredict_penalty }` as `CostFunction`
- R Interface: `sm_optim(..., objective = "ordinal", under_penalty = 1.5, over_penalty = 1.0)`

**3-OPT.A.3: Bounded Error (Range-Constrained)**
- Problem: Some properties must stay within physical bounds (pH 3-10, texture 0-100%)
- Solution: Large penalty for out-of-bounds predictions + `argmin` parameter bounds
- Implementation: `BoundedCost { min_val, max_val, penalty_factor }` as `CostFunction`
- R Interface: `sm_optim(..., objective = "bounded", bounds = c(0, 100), penalty = 100)`

**3-OPT.A.4: Huber Loss (Robust to Outliers)**
- Problem: Measurement outliers (especially in clay, Fe, pXRF) distort RMSE fits
- Solution: Smooth transition from quadratic (small residuals) to linear (large residuals)
- Implementation: `HuberCost { delta: f64 }` as `CostFunction` (delta = 1.35 × MAD)
- R Interface: `sm_optim(..., objective = "huber", delta = 1.35 * mad(observed))`

**3-OPT.A.5: Quantile Loss (L-q Regression)**
- Problem: Sometimes we want conservative (90th percentile) vs aggressive (10th percentile) fits
- Solution: Fit arbitrary quantiles, not just the mean
- Implementation: `QuantileCost { quantile: f64 }` as `CostFunction`
- R Interface: `sm_optim(..., objective = "quantile", quantile = 0.9)`
- Application: Uncertainty bands (fit 10th, 50th, 90th simultaneously)

**Exit Criteria for 3-OPT.A:**
- [ ] All 5 objectives compiling and passing unit tests
- [ ] R wrappers functional for each objective type
- [ ] Backward compatible with Phase 2 API (RMSE as default)
- [ ] Documentation with soil science use cases
- [ ] Performance validated (no slowdown vs Phase 2)

---

### **3-OPT.B: Advanced Optimization Algorithms**
**Objective:** Leverage `argmin` algorithm library instead of custom implementations  
**Prompt:** `03-opt-b-advanced-algorithms.md`  
**Estimated Time:** 1-2 weeks (reduced from 2-3 weeks due to argmin)  
**Est. Rust Code:** 200-300 lines (reduced from 600-800)  
**Est. R Code:** 80-120 lines  

**Key Change:** Use `argmin`'s battle-tested algorithms instead of implementing custom versions

**Subdeliverables:**

**3-OPT.B.1: Nelder-Mead (via argmin)**
- Implementation: Replace custom code with `argmin::NelderMeadSolver`
- Benefits: Better convergence, parameter bounds support, proven implementation
- Parameters: `max_iters: u64, tol: f64, adaptive: bool`
- Best for: Default single-profile optimization (maintains Phase 2 compatibility)

**3-OPT.B.2: L-BFGS (Limited Memory BFGS)**
- Implementation: `argmin::LBFGS` for gradient-based optimization
- Benefits: Fast convergence for smooth objectives, memory efficient
- Best for: Large parameter spaces, smooth objective functions
- R Interface: `sm_optim(..., algorithm = "lbfgs")`

**3-OPT.B.3: Newton Methods**
- Implementation: `argmin::Newton` and `argmin::GaussNewton`
- Benefits: Quadratic convergence near optimum, handles constraints
- Best for: Well-conditioned problems, when gradients available
- R Interface: `sm_optim(..., algorithm = "newton")`

**3-OPT.B.4: Simulated Annealing (via argmin)**
- Implementation: `argmin::SimulatedAnnealing` if available, or custom wrapper
- Benefits: Escapes local minima, probabilistic acceptance
- Best for: Multi-modal landscapes, complex shapes
- R Interface: `sm_optim(..., algorithm = "simulated_annealing", temperature = 1.0)`

**3-OPT.B.5: Algorithm Auto-Selection & User Extension**
- Logic: Enhanced auto-selection using problem characteristics
  - Smooth objectives + gradients available → L-BFGS/Newton
  - Multi-modal/multi-local → Simulated Annealing
  - Small problems (≤3 params) → Nelder-Mead
  - Large problems → L-BFGS with bounds
- User Extension: `register_algorithm(name, solver_trait_impl)`
- R Interface: `sm_optim(..., algorithm = "auto")` or custom registered algorithms

**Exit Criteria for 3-OPT.B:**
- [ ] `argmin::NelderMeadSolver` replaces custom implementation
- [ ] L-BFGS and Newton methods accessible via algorithm parameter
- [ ] Simulated Annealing available for multi-modal problems
- [ ] Auto-selection logic improved with gradient/Hessian detection
- [ ] User extension interface for custom algorithms
- [ ] Performance benchmarks vs R (nlm, optim) and Phase 2
- [ ] All algorithms work with custom objectives and parameter bounds

---

### **3-OPT.C: Custom Geometric Transformations**
**Objective:** Extend shape function library beyond Phase 2's 7 families  
**Prompt:** `03-opt-c-custom-shapes.md`  
**Estimated Time:** 1-2 weeks  
**Est. Rust Code:** 200-300 lines  
**Est. R Code:** 150-200 lines  

**Subdeliverables:**

**3-OPT.C.1: Monotone Cubic Spline Shapes**
- Problem: Natural soil profiles sometimes too complex for 7 standard shapes
- Solution: Piecewise smooth monotonic curves (user-supplied control points)
- Method: Monotone cubic spline (preserves ordering)
- Example: Clay profile with multiple accumulation zones
- Rust: struct `MonotoneSplineShape { control_points, depths }`
- R Interface: `sm_fit_monotone_spline(observed_depths, observed_values, new_depths)`

**3-OPT.C.2: Bivariate Shapes (Coupled Profiles)**
- Problem: Soil properties often inversely correlated (e.g., clay ↑ = silt ↓)
- Solution: Fit two properties simultaneously with correlation constraint
- Example: Texture triangle constraint (sand + silt + clay = 100%)
- Rust: struct `BivariateShape { shape_a, shape_b, correlation: f64 }`
- R Interface: `sm_fit_bivariate(observed_clay, observed_silt, depths, correlation_type = "anticorrelated")`

**3-OPT.C.3: Threshold-Activated Shapes (Piecewise)**
- Problem: Different soil processes dominate above/below certain depths
- Solution: Use different shape functions above/below threshold (with smooth transition)
- Example: Saturated vs unsaturated zone, frost depth transition
- Rust: struct `ThresholdShape { shape_above, shape_below, threshold, transition_width }`
- R Interface: `sm_fit_threshold_shape(..., threshold = 60, transition_width = 5)`

**Exit Criteria for 3-OPT.C:**
- [ ] All 3 shape families compiling and tested
- [ ] R wrappers and examples working
- [ ] Backward compatible with existing shape parameter passing
- [ ] Performance acceptable (interpolation overhead reasonable)
- [ ] Documentation with complex profile examples

---

### **3-OPT.D: Uncertainty Quantification**
**Objective:** Move beyond point estimates to parameter + prediction uncertainty  
**Prompt:** `03-opt-d-uncertainty.md`  
**Estimated Time:** 2 weeks  
**Est. Rust Code:** 200-300 lines  
**Est. R Code:** 150-200 lines  

**Subdeliverables:**

**3-OPT.D.1: Bootstrap Confidence Intervals**
- Method: Resample observed data, refit, accumulate parameter distribution
- Output: `BootstrapResult { params, param_samples, ci_lower, ci_upper }`
- R Interface: `sm_optim_bootstrap(observed, x, initial_params, n_bootstrap = 1000, ci = 0.95)`
- Interpretation: Parameter uncertainty ranges, classification stability

**3-OPT.D.2: Prediction Uncertainty Bands**
- Method: Generate confidence intervals around fitted curve
- Output: Depth-wise prediction intervals (lower, median, upper)
- Visualization: `plot_profile_with_ci(predictions, ci_lower, ci_upper)`
- Application: Uncertainty in diagnostic criteria decisions

**3-OPT.D.3: Global Sensitivity Analysis (Sobol Indices)**
- Question: Which parameters most affect fit quality?
- Method: Sobol/Morris indices for parameter importance ranking
- Output: `SensitivityResult { param_names, sensitivity_indices, importance_ranking }`
- R Interface: `sm_sensitivity_analysis(observed, x, baseline_params, n_samples = 1000)`
- Application: Data collection prioritization, model simplification

**3-OPT.D.4: Local Sensitivity (Parameter Perturbation)**
- Method: Small perturbations around optimal parameters
- Output: Parameter elasticity (% change in cost per % change in parameter)
- Application: Understanding parameter influence on fit

**Exit Criteria for 3-OPT.D:**
- [ ] Bootstrap implementation working and validated
- [ ] Sensitivity analysis indices matching reference (e.g., SALib)
- [ ] R visualization functions for uncertainty bands
- [ ] Documentation with interpretation guidance
- [ ] Integration tests with all objective types and algorithms

---

### **3-OPT.E: R Ecosystem Integration**
**Objective:** Seamless integration with tidyverse, Bayesian, and visualization workflows  
**Prompt:** `03-opt-e-r-integration.md`  
**Estimated Time:** 1-2 weeks  
**Est. R Code:** 250-400 lines  

**Subdeliverables:**

**3-OPT.E.1: broom Methods (tidy/glance/augment)**
```r
tidy.sm_optimization <- function(x, ...) {
    # Parameter estimates + uncertainty
    tibble::tibble(
        term = names(x$params),
        estimate = x$params,
        std.error = x$param_se,
        statistic = x$params / x$param_se,
        p.value = 2 * pnorm(abs(x$params / x$param_se), lower.tail = FALSE)
    )
}

glance.sm_optimization <- function(x, ...) {
    # Model summary statistics
    tibble::tibble(rmse = x$final_rmse, nobs = length(x$observed), 
                   npar = length(x$params), iterations = x$iterations)
}

augment.sm_optimization <- function(x, ...) {
    # Predictions + residuals
    tibble::tibble(depth = x$depths, observed = x$observed, 
                   predicted = x$fitted, residual = x$observed - x$fitted)
}
```

**3-OPT.E.2: Batch Fitting Pipelines (purrr)**
```r
soils_fitted <- read_csv("profiles.csv") %>%
    group_by(site_id) %>% nest() %>%
    mutate(
        fit = map(data, ~sm_optim(.x$clay, c(100, 20), use_rust = TRUE)),
        rmse = map_dbl(fit, "final_rmse"),
        params = map(fit, "params")
    ) %>%
    unnest_wider(params, names_sep = "_")
```

**3-OPT.E.3: ggplot2 Visualization Extensions**
- `geom_motif()`: Plot fitted soil profiles with ggplot2
- `geom_motif_ci()`: Fitted curves with confidence intervals
- R Interface: `soil_data %>% ggplot(aes(x = clay, y = depth)) + geom_motif(...)`

**3-OPT.E.4: Bayesian Integration (stan/brms)**
```r
sm_to_stan <- function(optimization_result) {
    # Use optimized parameters as informative priors
    params <- optimization_result$params
    param_sds <- optimization_result$param_sds
    # Generate Stan code with prior mean/sd
}
```

**3-OPT.E.5: Interactive Visualization (shiny/plotly)**
- Exploratory tool for parameter sensitivity
- Interactive slider adjustment of shape parameters
- Real-time optimization with cost surface visualization

**Exit Criteria for 3-OPT.E:**
- [ ] All S3 methods (tidy/glance/augment) working
- [ ] Tidyverse batch pipeline documented with examples
- [ ] ggplot2 geoms functional and customizable
- [ ] Stan/brms integration example working
- [ ] Vignette: "Advanced Optimization & Uncertainty"

---

## ANALYSIS TRACK (Phase 3-ANAL)

### **3-ANAL.A: Horizon Boundary Detection**
**Deliverable:** Objective horizon boundary identification via Mahalanobis distance  
**Prompt:** `03-anal-a-horizon-boundaries.md`  
**Estimated Time:** 3-4 hours  
**Est. Lines of Code:** 150-200 R / 100-150 Rust  

**Key Outputs:**
- `horizon_boundaries_mahalanobis(data, window_size, ...)`
- `split_moving_window()` helper
- Visualization of boundary probabilities
- Integration with raster stacks

**Input:** Multivariate soil data (pXRF: Al, Fe, Si, K, Ca, Ti, Zr, Mn at 1-unit depth resolution)  
**Output:** Depth positions of significant boundaries + probability/significance values

---

### **3-ANAL.B: Fuzzy k-means Clustering**
**Deliverable:** Horizon classification via fuzzy clustering  
**Prompt:** `03-anal-b-fuzzy-kmeans.md`  
**Estimated Time:** 3-4 hours  
**Est. Lines of Code:** 150-200 R  

**Key Outputs:**
- `fuzzy_kmeans_horizons(multivar_data, k, ...)`
- Membership probability visualization
- Horizon delineation from membership curves
- Integration with multivariate soil data

---

### **3-ANAL.C: Weathering Indices**
**Deliverable:** Chemical alteration quantification  
**Prompt:** `03-anal-c-weathering-indices.md`  
**Estimated Time:** 2-3 hours  
**Est. Lines of Code:** 100-150 R  

**Key Outputs:**
- `weathering_index_si_al()` (SiO_2/Al_2O_3 ratio)
- `weathering_index_ti_zr()` (Ti/Zr ratio for parent material homogeneity)
- Generic `calc_element_ratio()` helper
- Litholodic discontinuity detection

---

### **3-ANAL.D: Index of Profile Anisotropy**
**Deliverable:** Soil development quantification  
**Prompt:** `03-anal-d-profile-anisotropy.md`  
**Estimated Time:** 1-2 hours  
**Est. Lines of Code:** 50-100 R  

**Key Outputs:**
- `index_of_profile_anisotropy(x)` function
- Pedogenic development classification (young/moderate/strong)
- Batch calculation across profiles

---

## Integration Between Optimization & Analysis Tracks

**Workflow 1: Optimize then Analyze**
```r
# Phase 2.C: Fit individual soil properties
fit_clay <- sm_optim(clay_profile, c(100, 20), use_rust = TRUE)
fit_silt <- sm_optim(silt_profile, c(90, 30), use_rust = TRUE)

# Phase 3-OPT.E: Extract uncertainty bands
clay_ci <- sm_optim_bootstrap(clay_profile, n_bootstrap = 1000)
silt_ci <- sm_optim_bootstrap(silt_profile, n_bootstrap = 1000)

# Phase 3-ANAL: Use fits to guide boundary detection
boundaries <- horizon_boundaries_mahalanobis(
    data = pxrf_multivariate,
    ref_params = list(fit_clay$params, fit_silt$params)
)

# Phase 3-ANAL.D: Quantify development
ipa <- index_of_profile_anisotropy(fitted_motifs = list(clay = fit_clay, silt = fit_silt))
```

**Workflow 2: Multi-Objective with Uncertainty**
```r
# Phase 3-OPT.A + D: Fit with domain-specific objectives + uncertainty
fit_robust <- optimize_profile_rust_flexible(
    clay_profile,
    x = 1:200,
    initial_params = c(100, 20),
    objective_type = "huber_loss",  # Robust to outliers
    delta = 1.35 * mad(clay_profile)
)

boot_ci <- sm_optim_bootstrap(clay_profile, objective_type = "huber_loss")

# Phase 3-OPT.E: Batch fitting across landscape
landscape_fits <- soils %>%
    group_by(site_id) %>%
    nest() %>%
    mutate(
        clay_fit = map(data, ~optimize_profile_rust_flexible(
            .x$clay, objective_type = "bounded_error",
            obs_min = min(.x$clay), obs_max = max(.x$clay)
        ))
    )
```

---

## Phase 3 Exit Criteria

When Phase 3 is complete:

**Optimization Track (3-OPT):**
- [x] Argmin framework integrated: custom optimizer replaced with `argmin::NelderMeadSolver`
- [x] All 5 domain objectives implemented as `argmin::CostFunction` traits (weighted, ordinal, bounded, Huber, quantile)
- [x] Multiple algorithms accessible via `argmin` library (Nelder-Mead, L-BFGS, Newton, Simulated Annealing)
- [x] Custom shape families functional with `argmin` algorithms (splines, bivariate, threshold)
- [x] Bootstrap CI and sensitivity analysis working with `argmin` results
- [x] R ecosystem integration complete (broom, ggplot2, tidyverse, Bayesian)
- [x] User extension interface for custom algorithms and objectives
- [x] Comprehensive documentation and vignettes

**Analysis Track (3-ANAL):**
- [x] Horizon boundary detection working with multivariate data
- [x] Fuzzy k-means producing interpretable membership curves
- [x] Weathering indices matching book chapter examples
- [x] IPA producing soil development classifications
- [x] Novel spatial products (raster integration ready)
- [x] Comprehensive documentation and vignettes

**Integration:**
- [x] Both tracks integrated via workflow examples
- [x] Phase 2 pluggable architecture remains backbone
- [x] Backward compatibility maintained
- [x] All tests passing (Phase 2 baseline + Phase 3 additions)

---

## Data Requirements

**Optimization Track:**
- Single element time series (depth profiles)
- Format: numeric vector or data.frame with id/top/bottom/property columns
- Resolution: Ideally 1-cm but flexible
- Quality: Handles missing values and measurement error gracefully

**Analysis Track:**
- Multivariate Soil Data: Multiple elemental concentrations at 1-unit depth resolution
  - Typical: pXRF output (Al, Fe, Si, K, Ca, Ti, Zr, Mn, etc.)
  - Format: matrix or data.frame, rows = depth, columns = elements
- Soil Property Profiles: Individual elements as depth functions
  - Expected: continuous numeric vectors (1 cm resolution)

---

## Performance & Scale

### Optimization Track

| Scenario | Phase 2 (Custom) | Phase 3 (argmin) | Speedup |
|----------|------------------|------------------|---------|
| Single profile, RMSE | 5-5.5 ms | 4-5 ms (argmin Nelder-Mead) | 1.1-1.4x |
| Single profile, Huber loss | 5-5.5 ms | 4-5 ms (same algorithm, better impl) | 1.1-1.4x |
| Single profile, L-BFGS | N/A | 2-3 ms (gradient-based) | N/A |
| Single profile, Newton | N/A | 1-2 ms (quadratic convergence) | N/A |
| 100 profiles, auto-select | N/A | 1-2 sec (parallel L-BFGS) | 50-100x vs R|
| Landscape (1000 profiles) | N/A | 10-20 sec (parallel optimization) | 200-500x vs R |

### Analysis Track

| Analysis | Time (single profile) | Time (100 profiles) |
|----------|----------------------|---------------------|
| Horizon boundaries (multivariate) | <100 ms (R), <10 ms (Rust candidate) | ~1-2 sec (parallel) |
| Fuzzy k-means | 50-200 ms (R, depends on k) | 5-20 sec |
| Weathering indices | <10 ms | <1 sec |
| IPA calculation | <5 ms | <500 ms |

---

## Pedogenic Interpretation

| Analysis | What It Reveals | Use Case |
|----------|-----------------|----------|
| **Depth-weighted RMSE** | Prioritize diagnostic horizons | Diagnostic criteria classification |
| **Ordinal error** | Direction-sensitive fit | Conservative estimates (e.g., clay) |
| **Bounded error** | Physical constraints respected | pH, texture triangle constraints |
| **Huber loss** | Robust fitting | Outlier-prone measurements (pXRF, Fe) |
| **Quantile regression** | Full uncertainty distribution | Risk assessment, conservative estimates |
| **Simulated annealing** | Escape local minima | Complex multi-modal profiles |
| **Differential evolution** | Global optimization, parallelizable | Large-scale landscape fitting |
| **Bootstrap CI** | Parameter uncertainty | Diagnostic depth ranges, classification stability |
| **Sensitivity analysis** | Parameter importance ranking | Data collection priorities |
| **Monotone splines** | Complex natural patterns | Polygenetic profiles, multi-event soils |
| **Mahalanobis boundaries** | Where multivariate soil "jumps" most | Objective horizon delineation |
| **Fuzzy k-means** | Mixing zones and gradational boundaries | Understanding horizon transitions |
| **Si/Al Ratio** | Degree of silica leaching | Weathering intensity |
| **Ti/Zr Ratio** | Parent material consistency | Detecting lithologic discontinuities |
| **IPA** | Overall profile heterogeneity | Soil maturity classification |

---

## Integration with Phase 1-2

- **Phase 1 Foundation:** Uses fitted motifs from `fit_motif_auto()`
- **Phase 2 Backend:** 
  - Pluggable trait architecture supports Phase 3-OPT extensions
  - Parallelization ready for Phase 3 batch workflows
- **Phase 3 Optimization:** Extends single-profile (Phase 2.C) to landscape scale
- **Phase 3 Analysis:** Independent pedogenic analytical methods
- **Spatial Products:** Outputs compatible with raster/vector GIS formats (Phase 2.D integration)

---

## Implementation Timeline

| Quarter | Track | Deliverables | Estimated Effort |
|---------|-------|--------------|------------------|
| **Q1 2026** | **3-OPT** | 3-OPT.A (5 objectives) + 3-OPT.B (argmin algorithms, auto-select) | 2-3 weeks |
| | **3-ANAL** | 3-ANAL.A + 3-ANAL.B (boundaries, fuzzy k-means) | 1-2 weeks |
| **Q2 2026** | **3-OPT** | 3-OPT.C (3 shape families) + 3-OPT.D (uncertainty) | 3 weeks |
| | **3-ANAL** | 3-ANAL.C + 3-ANAL.D (indices) | 1 week |
| **Q3 2026** | **3-OPT** | 3-OPT.E (R integration, Bayesian, tidyverse) | 2 weeks |
| | **Both** | Integration examples, comprehensive vignettes | 1 week |

Both tracks can proceed in parallel. Phase 3-ANAL is independent of Phase 3-OPT optimization choices.

---

## Known Challenges

### Optimization Track

1. **Argmin Integration Benefits:** Using `argmin` provides battle-tested algorithms, parameter bounds, and extensibility without custom implementation
2. **Objective-Algorithm Compatibility:** `argmin`'s trait system ensures objectives work with any algorithm; auto-selection guides optimal combinations
3. **Parameter Bounds:** Native `argmin` bounds support eliminates need for penalty methods for physical constraints
4. **User Extensions:** `argmin`'s trait-based design enables user-designed algorithms and objectives
5. **Convergence Reliability:** Proven algorithms with better convergence than custom implementations
6. **Performance:** Optimized implementations provide speedups without sacrificing accuracy

### Analysis Track

1. **Multivariate Normalization:** Must handle different element concentration ranges
2. **Boundary Detection Sensitivity:** Moving window size and Mahalanobis threshold are critical; need guidance
3. **k-means Convergence:** Fuzzy k-means can be slow on large profiles; consider Rust acceleration
4. **Spatial Output:** GIS integration requires specific data formats

---

## Resources

- **Optimization:** `argmin` crate (already included) provides algorithms and trait system for Phase 3-OPT
- **Book chapter:** Section 14.3 (Mahalanobis distance methodology), Figure 14.11 (Fuzzy k-means)
- **Optimization:** Reference implementations (optim, nlm, ucminf) for comparison
- **Clustering:** `flexclust` R package, book chapter examples
- **Spatial:** `sp`, `raster`, `terra`, `sf` for data integration
- **Bayesian:** `stan`, `brms`, informative priors from Phase 3-OPT

---

## Handoff Checklist

**Phase 3 Complete When:**
- [ ] Optimization track: All 5 objectives + 4 algorithms + 3 shapes implemented
- [ ] Uncertainty quantification: Bootstrap CI and sensitivity analysis validated
- [ ] R integration: broom, tidyverse, Bayesian workflows functional
- [ ] Analysis track: Boundaries, fuzzy k-means, indices, IPA all working
- [ ] All tests passing (Phase 2 baseline + Phase 3 additions)
- [ ] Vignettes: "Advanced Optimization & Uncertainty" + "Advanced Analysis: Boundaries & Indices"
- [ ] Git: `Phase-3: Add optimization (objectives, algorithms, uncertainty) and pedogenic analysis`
- [ ] Performance: Validated against reference implementations
- [ ] Documentation: API docs, examples, use case guidance

---

**Phase 3 Status:** READY FOR AGENT PROMPT GENERATION
