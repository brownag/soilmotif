# 03g: Horizon Boundary Detection via Mahalanobis Distance

## Objective
Implement objective horizon boundary identification from multivariate soil data (pXRF) using moving-window Mahalanobis distance.

## Design Principles
- **R Implementation First**: Develop and test in R, then optimize in Rust
- **Pure Base R**: Use stats package only (no tidyr/dplyr dependencies)
- **Extensible Peak Detection**: User-selectable boundary identification methods
- **S3 Class Structure**: Return `horizon_boundaries` object with methods
- **Depth-based Windows**: Window size in depth units (cm), not observation count
- **Optional Motif Integration**: Can utilize fitted curves for interpolation/guidance

## Current State
- soilmotif focuses on univariate depth functions
- No multivariate horizon delineation
- No boundary detection algorithms
- Horizon boundaries currently manual
- Phase 3f visualization infrastructure ready (plot.R)

## Deliverables

### D1: Mahalanobis Distance Calculation [R Implementation]
**Files:** `R/horizons.R` (new file)

1. **Internal helper using stats::mahalanobis():**
   ```r
   # Internal function (not exported)
   .compute_mahalanobis_window <- function(window_data, reference_center = NULL,
                                            reference_cov = NULL) {
       # window_data: matrix (rows = depths, cols = elements)
       # reference_center: optional mean vector for comparison
       # reference_cov: optional covariance matrix for comparison
       #
       # If reference_* NULL: compute center/cov from window_data itself
       # Returns: scalar Mahalanobis distance or vector if comparing points to center

       if (is.null(reference_center)) {
           reference_center <- colMeans(window_data, na.rm = TRUE)
       }
       if (is.null(reference_cov)) {
           reference_cov <- stats::cov(window_data, use = "complete.obs")
       }

       # Use stats::mahalanobis() - base R, no dependencies
       stats::mahalanobis(window_data, center = reference_center,
                          cov = reference_cov, inverted = FALSE)
   }
   ```

2. **Features:**
   - Uses base R stats package only
   - Handles multivariate soil element concentrations (Al, Fe, Si, K, Ca, Ti, Zr, Mn, etc.)
   - Automatic covariance computation per window
   - Robust to different measurement units via Mahalanobis metric
   - Missing value handling via complete.obs

3. **Note for future Rust implementation:**
   - Current R implementation serves as reference/test baseline
   - Rust version (nalgebra for linear algebra) can be added later for performance
   - FFI interface will mirror this R API

### D2: Moving-Window Boundary Detection
**Files:** `R/horizons.R`

1. **Main user-facing function:**
   ```r
   #' Detect horizon boundaries using Mahalanobis distance
   #'
   #' @param data data.frame with depth and element concentration columns
   #' @param depth_col character. Name of depth column (default: "depth")
   #' @param element_cols character vector. Element column names. If NULL, uses all
   #'   numeric columns except depth_col. User is responsible for subsetting data
   #'   if only specific elements should be used.
   #' @param window_size numeric. Moving window size in DEPTH UNITS (e.g., 10 = 10 cm),
   #'   not number of observations. Default: 10.
   #' @param threshold numeric. Mahalanobis distance threshold for boundary detection.
   #'   Absolute threshold (e.g., 2.0 means distance > 2.0 indicates boundary).
   #'   Default: 2.0
   #' @param method character. Peak detection method: "threshold", "local_maxima",
   #'   "changepoint". Default: "local_maxima"
   #' @param min_horizon_depth numeric. Minimum horizon thickness in depth units.
   #'   Boundaries closer than this are merged. Default: 5
   #' @param window_type character. Window positioning: "centered", "forward", "backward".
   #'   Default: "centered"
   #' @return Object of class "horizon_boundaries" (S3)
   #' @export
   horizon_boundaries_mahalanobis <- function(data,
                                               depth_col = "depth",
                                               element_cols = NULL,
                                               window_size = 10,
                                               threshold = 2.0,
                                               method = "local_maxima",
                                               min_horizon_depth = 5,
                                               window_type = "centered") {

       # Algorithm:
       # 1. Extract depth and element data
       # 2. If element_cols NULL: use all numeric columns except depth_col
       # 3. Sort by depth (ascending)
       # 4. Create moving windows based on depth_col and window_size
       # 5. For each consecutive pair of windows:
       #    - Compute Mahalanobis distance between window centers
       # 6. Apply peak detection method to distance profile
       # 7. Filter boundaries by min_horizon_depth
       # 8. Return horizon_boundaries object
   }
   ```

2. **S3 class structure:**
   ```r
   # Object of class "horizon_boundaries"
   # List with components:
   # - call: original function call
   # - boundaries: data.frame(depth, mahal_distance, is_boundary)
   # - horizons: data.frame(horizon_id, top, bottom, thickness)
   # - raw_distances: numeric vector (Mahalanobis distance at each depth)
   # - method: peak detection method used
   # - threshold: threshold value used
   # - element_cols: which columns were analyzed
   # - window_size: window size in depth units

   # S3 methods to implement:
   # - print.horizon_boundaries()
   # - summary.horizon_boundaries()
   # - plot.horizon_boundaries() [integrates with 03f plot.R]
   ```

3. **Use cases:**
   - Objective delineation without manual interpretation
   - pXRF profiles: Al, Fe, Si, Ti, Zr show lithologic/weathering changes
   - Horizon correlation across sites
   - Identify transitions for targeted sampling

### D3: Window and Peak Detection Methods
**Files:** `R/horizons.R`

1. **Internal window function:**
   ```r
   # Internal helper (not exported)
   .create_depth_windows <- function(depths, element_matrix, window_size,
                                      window_type = "centered") {
       # depths: numeric vector of depth values
       # element_matrix: matrix of element concentrations (rows = depths)
       # window_size: window size in DEPTH UNITS
       # window_type: "centered", "forward", "backward"
       #
       # Returns: list of windows, each with:
       #   - center_depth: numeric (depth at window center)
       #   - depth_range: numeric(2) (min, max depth in window)
       #   - data: matrix subset for this window
       #   - indices: integer vector (row indices in original data)

       # Window types:
       # - centered: d ± (window_size/2)
       # - forward: d to d + window_size
       # - backward: d - window_size to d
   }
   ```

2. **Peak detection methods (extensible):**
   ```r
   # Internal helper (not exported)
   .detect_boundaries <- function(distances, depths, method, threshold,
                                   min_separation) {
       # distances: numeric vector of Mahalanobis distances
       # depths: corresponding depth values
       # method: "threshold", "local_maxima", "changepoint"
       # threshold: numeric threshold value
       # min_separation: minimum distance between peaks (min_horizon_depth)
       #
       # Returns: integer vector of indices where boundaries detected

       switch(method,
           threshold = {
               # Simple: distance > threshold
               which(distances > threshold)
           },
           local_maxima = {
               # Find local maxima above threshold
               # Use base R: diff() to find sign changes in gradient
               # Filter by threshold and min_separation
           },
           changepoint = {
               # Statistical change point detection
               # Could use simple approach or more sophisticated algorithms
               # E.g., PELT, Binary Segmentation (implement simple version)
           },
           stop("Unknown method: ", method)
       )
   }
   ```

3. **Design notes:**
   - Extensible: adding new methods requires only updating .detect_boundaries()
   - Pure base R: no external dependencies
   - Window size in depth units (cm) not observation count
   - User responsible for data quality (regular depth intervals recommended)

### D4: Visualization of Boundaries [Base R - Integrates with 03f]
**Files:** `R/plot.R` (add to existing file from 03f)

1. **S3 plot method:**
   ```r
   #' Plot horizon boundary detection results
   #'
   #' @param x Object of class "horizon_boundaries"
   #' @param element_data Optional: original data.frame with element concentrations
   #' @param which character. Which plots to show: "all", "distance", "boundaries"
   #' @param elements character. Which elements to plot (if element_data provided)
   #' @param ... Additional graphical parameters
   #' @export
   plot.horizon_boundaries <- function(x,
                                        element_data = NULL,
                                        which = "all",
                                        elements = NULL,
                                        ...) {
       # Base R multi-panel plot (no ggplot2/plotly)

       # If which = "all" and element_data provided:
       #   Panel 1 (left): Element concentration profiles (depth vs concentration)
       #            Multiple elements as different colored lines
       #   Panel 2 (right): Mahalanobis distance profile with threshold line
       #            Mark detected boundaries with vertical lines or points
       #            Shade identified horizons

       # If which = "distance":
       #   Single plot: Mahalanobis distance vs depth with boundaries

       # If which = "boundaries":
       #   Horizons as horizontal bands with labels

       # Use base R: plot(), lines(), abline(), polygon(), mtext()
       # Follow soil convention: depth increases downward (ylim reversed)
   }
   ```

2. **Helper for adding boundaries to existing plots:**
   ```r
   #' Add horizon boundaries to an existing plot
   #'
   #' @param boundary_result Object of class "horizon_boundaries"
   #' @param col Color for boundary lines
   #' @param lty Line type
   #' @param ... Additional graphical parameters
   #' @export
   add_horizon_boundaries <- function(boundary_result, col = "red", lty = 2, ...) {
       # Add horizontal lines at boundary depths to current plot
       # Useful for overlaying on sm_optim() plots
   }
   ```

3. **Integration note:**
   - No plotly/interactive visualization in initial implementation (base R only)
   - Consistent with 03f design principles
   - Future: ggplot2 helper in prepare_horizon_ggplot() (03f-D3)

### D5: Parameter Guidance and Data Quality
**Files:** `R/horizons.R`

1. **Parameter suggestion function:**
   ```r
   #' Suggest optimal parameters for boundary detection
   #'
   #' @param data data.frame with depth and element columns
   #' @param depth_col character. Depth column name
   #' @param element_cols character vector. Element columns (NULL = auto-detect)
   #' @param quantile numeric. Quantile for threshold suggestion (default: 0.90)
   #' @return List with suggested parameters and diagnostic information
   #' @export
   suggest_boundary_params <- function(data,
                                        depth_col = "depth",
                                        element_cols = NULL,
                                        quantile = 0.90) {

       # Analysis steps:
       # 1. Check data quality (missing values, depth resolution)
       # 2. Compute preliminary Mahalanobis distances with default window
       # 3. Suggest threshold based on quantile of distance distribution
       # 4. Suggest window_size based on depth resolution
       # 5. Return list with suggestions and warnings

       # Returns:
       # list(
       #     window_size = suggested_value,
       #     threshold = suggested_value,  # based on quantile
       #     threshold_quantile = quantile_used,
       #     depth_resolution = median depth increment,
       #     n_elements = number of element columns,
       #     missing_pct = percentage of missing values,
       #     warnings = character vector of warnings,
       #     notes = character vector of recommendations
       # )
   }
   ```

2. **Data quality checks (internal):**
   ```r
   # Internal validation function
   .validate_horizon_data <- function(data, depth_col, element_cols) {
       # Check and warn:
       # - Missing values (warn if >10% in any element)
       # - Non-numeric element columns
       # - Irregular depth spacing (recommend sm_prepare() if needed)
       # - Too few depths for window_size
       # - Depth column not sorted (will be sorted internally)
       # - Duplicate depths (error)

       # Returns: list(valid = TRUE/FALSE, warnings = character(), errors = character())
   }
   ```

3. **Usage pattern:**
   ```r
   # User workflow:
   params <- suggest_boundary_params(my_data, depth_col = "depth")
   print(params)  # Review suggestions

   # Use suggestions:
   boundaries <- horizon_boundaries_mahalanobis(
       my_data,
       window_size = params$window_size,
       threshold = params$threshold
   )
   ```

### D6: Integration with Fitted Motifs [OPTIONAL Enhancement]
**Files:** `R/horizons.R`

1. **Optional motif-guided boundary detection:**
   ```r
   #' Enhance boundary detection using fitted shape functions
   #'
   #' @param boundary_result Object of class "horizon_boundaries"
   #' @param fitted_motifs List of soilmotif_optimization objects (e.g., clay, Fe)
   #' @param interpolate logical. Use fitted curves to interpolate missing depths?
   #' @param use_residuals logical. Incorporate residual patterns in detection?
   #' @return Modified horizon_boundaries object
   #' @export
   horizon_boundaries_guided <- function(boundary_result,
                                          fitted_motifs = NULL,
                                          interpolate = TRUE,
                                          use_residuals = TRUE) {

       # Optional enhancement - works standalone without motifs

       if (is.null(fitted_motifs)) {
           warning("No fitted motifs provided; returning original boundaries")
           return(boundary_result)
       }

       # Integration strategies:
       # 1. Interpolation: Use fitted curves (sm_motif) to fill depth gaps
       #    - Evaluate fitted function at all depths
       #    - Use for elements not measured at every depth

       # 2. Residual patterns: Extract residuals from fitted curves
       #    - Systematic residuals may indicate boundaries
       #    - Changes in residual variance signal transitions

       # 3. Weight boundaries: Prioritize boundaries where:
       #    - Multiple fitted properties show inflection points
       #    - Gradient changes in fitted curves align

       # 4. Generalization: Use fitted parameters to predict properties
       #    - Especially useful for sparse sampling

       # Returns: modified boundary_result with additional fields:
       #   - adjusted_boundaries (if boundaries refined)
       #   - interpolated_data (if interpolate = TRUE)
       #   - motif_support (how many motifs support each boundary)
   }
   ```

2. **Helper for extracting transition points from motifs:**
   ```r
   # Internal helper
   .extract_motif_transitions <- function(fitted_motif, depths) {
       # fitted_motif: soilmotif_optimization object
       # depths: depth sequence for evaluation
       #
       # Identify inflection points, maxima, rapid gradients in fitted curve
       # Returns: depths where transitions occur

       # Use numerical differentiation (base R: diff())
       # Find where second derivative changes sign (inflection points)
   }
   ```

3. **Design notes:**
   - OPTIONAL feature - boundary detection works without motifs
   - Enables cross-property validation (e.g., clay + Fe transitions align)
   - Useful for generalizing from fitted curves to multivariate data
   - Can interpolate properties at unmeasured depths using fitted functions

## Implementation Steps

**Phase 1: Core R Implementation (Test Foundation for Rust)**
1. Create R/horizons.R with internal helper functions:
   - `.compute_mahalanobis_window()` using stats::mahalanobis()
   - `.create_depth_windows()` for window management
   - `.detect_boundaries()` with 3 methods (threshold, local_maxima, changepoint)
   - `.validate_horizon_data()` for data quality checks
2. Implement `horizon_boundaries_mahalanobis()` main function
3. Implement S3 class structure and methods:
   - `print.horizon_boundaries()`
   - `summary.horizon_boundaries()`
4. Create synthetic test data in tests/testthat/helper-test-data.R
   - Multivariate profiles with known boundaries
   - Various scenarios: sharp transitions, gradual changes, noisy data
5. Write tests in tests/testthat/test-horizons.R
   - Test each peak detection method
   - Validate window creation logic
   - Check S3 methods
6. Add roxygen documentation with minimal examples

**Phase 2: Visualization and Parameter Guidance**
7. Add `plot.horizon_boundaries()` to R/plot.R (from 03f)
8. Add `add_horizon_boundaries()` helper
9. Implement `suggest_boundary_params()`
10. Test visualization with synthetic data
11. Document visualization in .github/examples/

**Phase 3: Optional Enhancements**
12. Implement `horizon_boundaries_guided()` (motif integration)
13. Add `.extract_motif_transitions()` helper
14. Test motif integration with existing sm_optim() results
15. Document integration workflows

**Phase 4: Documentation (After Implementation Complete)**
16. Create .github/examples/horizon-detection.md
17. Update README with horizon detection section
18. Prepare for vignette (wait until 03h also complete)

**Future: Rust Implementation**
19. Port to src/horizons.rs using nalgebra
20. Parallel window processing with rayon
21. FFI wrappers in src/lib.rs
22. Benchmark R vs Rust performance
23. Update R functions to use Rust backend with use_rust = TRUE parameter

## Success Criteria

**Core Functionality (Must Have):**
- [ ] Mahalanobis distance correctly computed (validate against stats::mahalanobis)
- [ ] Three peak detection methods working (threshold, local_maxima, changepoint)
- [ ] Window creation handles centered/forward/backward correctly
- [ ] S3 class structure with print/summary methods
- [ ] Pure base R (no external dependencies beyond stats)
- [ ] Synthetic test data with known boundaries
- [ ] All tests passing

**Visualization (Must Have):**
- [ ] Base R plot method functional
- [ ] Multi-panel plots show distance profile + boundaries
- [ ] Follows soil convention (depth increases downward)
- [ ] Integration with existing plot.R from 03f

**Parameter Guidance (Should Have):**
- [ ] suggest_boundary_params() provides reasonable recommendations
- [ ] Quantile-based threshold suggestion
- [ ] Data quality validation with informative warnings
- [ ] Window size suggestion based on depth resolution

**Optional Features (Nice to Have):**
- [ ] Motif integration working (horizon_boundaries_guided)
- [ ] Residual analysis from fitted curves
- [ ] Cross-property boundary validation
- [ ] Interpolation using fitted functions

**Documentation (After Core Complete):**
- [ ] Roxygen documentation complete with examples
- [ ] Examples in .github/examples/horizon-detection.md
- [ ] README updated with horizon detection workflow
- [ ] Prepared for vignette (after 03h)

## Files to Create/Modify

**New Files:**
- `R/horizons.R` - core horizon detection functions
- `tests/testthat/test-horizons.R` - comprehensive tests
- `tests/testthat/helper-horizon-data.R` - synthetic test data generators
- `.github/examples/horizon-detection.md` - usage examples

**Modified Files:**
- `R/plot.R` - add plot.horizon_boundaries() method (from 03f)
- `DESCRIPTION` - no new dependencies needed (uses stats only)
- `NAMESPACE` - exports via roxygen2
- `README.md` - add horizon detection section

**Future Files (Rust Implementation):**
- `src/horizons.rs` - Rust implementation
- `src/lib.rs` - FFI exports for horizon functions

## Test Data Strategy

**Synthetic Test Data (in tests/):**
1. **Simple case**: 3 horizons, sharp boundaries, no noise
   - Elements: Al, Fe, Si
   - Known boundary depths: 30 cm, 70 cm
   - Clean separation in Mahalanobis space

2. **Gradual transitions**: 4 horizons, smooth changes
   - Weathering gradient (Al/Si ratio changes)
   - Test local_maxima vs threshold methods

3. **Noisy data**: 3 horizons with measurement variability
   - Add realistic noise to element concentrations
   - Test robustness of detection

4. **Irregular spacing**: Non-uniform depth increments
   - Test window creation with variable depth resolution

5. **Missing values**: Sparse sampling with gaps
   - Test complete.obs handling in covariance

**Build on Existing Tests:**
- Use patterns from tests/testthat/test-fit.R
- Leverage existing sm_optim() results for motif integration tests

**Future Real Data (inst/extdata/):**
- Will curate pXRF datasets with known horizons
- Not included in initial implementation
- Used for validation and vignettes later

## Related Prompts
- **03f: R Integration** - plot.R infrastructure, base R visualization patterns
- **03h: Fuzzy k-means** - complementary horizon classification approach
- **03i: Weathering Indices** - uses same multivariate element data
- **Phase 3e: Uncertainty** - bootstrap patterns for validation

## Implementation Dependencies
- **Implement AFTER:** 03f (need plot.R infrastructure)
- **Implement BEFORE:** 03h (horizon detection feeds into classification)

## Algorithm Details

### Mahalanobis Distance Between Windows
For two consecutive windows A and B:
```
D = sqrt((mean_A - mean_B)^T * Cov_pooled^-1 * (mean_A - mean_B))
```
Where Cov_pooled is the pooled covariance matrix.

Alternatively, compute average distance of points in window B to centroid of window A.

### Peak Detection Methods

**1. Threshold (Simple):**
- Boundary where distance > threshold
- Fast, but sensitive to threshold choice
- Good for sharp transitions

**2. Local Maxima (Recommended):**
- Find peaks in distance profile using diff()
- Require peak > threshold AND local maximum
- Apply minimum separation constraint
- More robust to noise

**3. Changepoint (Advanced):**
- Statistical change point detection
- Binary segmentation or PELT-like approach
- Can implement simple version: sliding t-test on distance profile
- Most robust but computationally intensive

### Window Size Guidance
- **Fine resolution** (1-2 cm): window_size = 5-10 cm
- **Standard** (5 cm): window_size = 10-20 cm
- **Coarse** (10 cm): window_size = 20-30 cm
- Rule of thumb: window_size ≈ 2-3x depth resolution

### Threshold Guidance
- **Absolute**: 2.0 (good default for standardized distances)
- **Quantile-based**: Use 90th percentile of distance distribution
- **Adaptive**: mean + 2*sd of distances

## Example Workflows

### Basic Usage
```r
library(soilmotif)

# Load multivariate soil data
data <- read.csv("pxrf_profile.csv")
# Columns: depth, Al, Fe, Si, K, Ca, Ti, Zr

# Get parameter suggestions
params <- suggest_boundary_params(data, depth_col = "depth")
print(params)

# Detect boundaries
boundaries <- horizon_boundaries_mahalanobis(
    data,
    depth_col = "depth",
    window_size = params$window_size,
    threshold = params$threshold,
    method = "local_maxima"
)

# View results
print(boundaries)
summary(boundaries)

# Visualize
plot(boundaries, element_data = data, which = "all")
```

### Integration with Fitted Motifs
```r
# Fit clay and Fe profiles
clay_fit <- sm_optim(data$clay, c(40, 60), use_rust = TRUE)
fe_fit <- sm_optim(data$Fe, c(2, 4), use_rust = TRUE)

# Detect boundaries from pXRF
boundaries <- horizon_boundaries_mahalanobis(data)

# Refine using fitted motifs
boundaries_guided <- horizon_boundaries_guided(
    boundaries,
    fitted_motifs = list(clay = clay_fit, Fe = fe_fit),
    interpolate = TRUE,
    use_residuals = TRUE
)

# Compare
plot(boundaries_guided)
```

### Comparing Detection Methods
```r
# Try different methods
methods <- c("threshold", "local_maxima", "changepoint")

results <- lapply(methods, function(m) {
    horizon_boundaries_mahalanobis(data, method = m)
})
names(results) <- methods

# Compare number of boundaries detected
sapply(results, function(x) nrow(x$horizons))

# Visual comparison
par(mfrow = c(1, 3))
for (i in seq_along(results)) {
    plot(results[[i]], which = "distance", main = methods[i])
}
```

### Adding Boundaries to Existing Plots
```r
# Fit a motif
fit <- sm_optim(data$clay, c(40, 60))

# Detect boundaries from pXRF
boundaries <- horizon_boundaries_mahalanobis(data)

# Plot fitted curve with boundaries
plot(fit, main = "Clay Profile with Detected Horizons")
add_horizon_boundaries(boundaries, col = "red", lty = 2)
legend("bottomright",
       legend = c("Fitted Clay", "Horizon Boundaries"),
       col = c("blue", "red"), lty = c(1, 2))
```
