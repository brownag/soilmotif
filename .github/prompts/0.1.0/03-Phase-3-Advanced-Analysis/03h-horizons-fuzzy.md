# 03h: Fuzzy k-means Horizon Classification

## Objective
Implement soil horizon classification using fuzzy k-means clustering on multivariate soil data.

## Design Principles
- **R Implementation First**: Develop vanilla R reference implementation, then Rust
- **Minimal Dependencies**: Allow base R kmeans() and cluster package for validation
- **Pure Base R Core**: Reference implementation uses only base R
- **Rust for Performance**: Parallel implementation with nalgebra/ndarray
- **Consistent Interface**: Matches 03g patterns (element_cols auto-detection, S3 class)
- **Full Membership Storage**: Store complete membership matrix for interpretability

## Current State
- Phase 3g implements objective boundary detection
- No fuzzy classification system
- No horizon type assignment
- Manual horizon nomenclature common
- Phase 3f visualization infrastructure ready (plot.R)

## Motivation
- Fuzzy membership more realistic than hard assignments
- Soil horizons are gradational, not discrete
- Membership scores (entropy) indicate classification confidence
- Enables horizon type probability matrices
- Identifies transitional zones where boundaries are uncertain

## Deliverables

### D1: Fuzzy k-means Algorithm [R Reference Implementation]
**Files:** `R/horizons.R` (extend from 03g)

1. **Internal R implementation (reference/test baseline):**
   ```r
   # Internal function (not exported)
   .fuzzy_kmeans_r <- function(data_matrix, k, m = 2.0,
                                max_iter = 100, tol = 1e-4,
                                init_method = "kmeans",
                                convergence = "membership") {
       # data_matrix: numeric matrix (rows = depths, cols = elements)
       # k: number of clusters (horizons)
       # m: fuzziness exponent (> 1.0, typically 1.5-3.0)
       # init_method: "kmeans" (use base R kmeans()), "random"
       # convergence: "membership", "centers", "both"
       #
       # Algorithm:
       # 1. Initialize centers using base R kmeans() or random selection
       # 2. Repeat until convergence:
       #    a. Update membership matrix U:
       #       u_ij = 1 / sum_l((d_ij / d_lj)^(2/(m-1)))
       #       where d_ij = ||x_i - c_j||
       #    b. Update centers:
       #       c_j = sum_i(u_ij^m * x_i) / sum_i(u_ij^m)
       #    c. Check convergence (membership change or center change < tol)
       # 3. Compute entropy: -sum(u * log(u)) per depth (normalized)
       #
       # Returns: list(
       #   centers = matrix(k x p),
       #   memberships = matrix(n x k),
       #   entropy = numeric(n),
       #   iterations = integer,
       #   converged = logical
       # )
   }
   ```

2. **Design notes:**
   - Pure base R (no external dependencies in core algorithm)
   - Uses base R `kmeans()` for initialization (calls compiled C code)
   - Distance calculations via base R matrix operations
   - Membership matrix normalized so rows sum to 1
   - Entropy normalized to [0, 1] scale: entropy / log(k)
   - Convergence default: membership change (max absolute difference < tol)

3. **Fuzziness exponent (m) guidance:**
   - m must be > 1.0 (enforce with validation)
   - m = 1.5: harder boundaries (more crisp)
   - m = 2.0: DEFAULT (good general choice)
   - m = 3.0: softer boundaries (more gradational)
   - Higher m → more gradational/fuzzy membership
   - Test multiple values to determine optimal for soil data

### D2: User-Facing R Interface
**Files:** `R/horizons.R`

1. **Main classification function:**
   ```r
   #' Classify soil horizons using fuzzy k-means clustering
   #'
   #' @param data data.frame with depth and element concentration columns
   #' @param depth_col character. Name of depth column (default: "depth")
   #' @param element_cols character vector. Element column names. If NULL, uses all
   #'   numeric columns except depth_col. Depth is NOT used as a clustering feature.
   #'   User is responsible for subsetting if only specific elements desired.
   #' @param n_horizons integer. Number of horizon clusters (k). Default: 5
   #' @param m numeric. Fuzziness exponent (must be > 1.0). Higher = softer boundaries.
   #'   Default: 2.0. Range: 1.5-3.0
   #' @param max_iter integer. Maximum iterations. Default: 100
   #' @param tolerance numeric. Convergence tolerance. Default: 1e-4
   #' @param convergence character. Convergence criterion: "membership" (default),
   #'   "centers", "both"
   #' @param init_method character. Initialization: "kmeans" (base R kmeans++),
   #'   "random". Default: "kmeans"
   #' @param include_depth_feature logical. Include depth as clustering feature?
   #'   Default: FALSE (cluster by element composition only). Set TRUE for noisy
   #'   data to encourage spatial grouping.
   #' @param use_rust logical. Use Rust implementation? Default: TRUE (when available)
   #' @return Object of class "fuzzy_horizons" (S3)
   #' @export
   horizon_classify_fuzzy <- function(data,
                                       depth_col = "depth",
                                       element_cols = NULL,
                                       n_horizons = 5,
                                       m = 2.0,
                                       max_iter = 100,
                                       tolerance = 1e-4,
                                       convergence = "membership",
                                       init_method = "kmeans",
                                       include_depth_feature = FALSE,
                                       use_rust = TRUE) {

       # Algorithm:
       # 1. Extract depth and element data
       # 2. If element_cols NULL: use all numeric except depth_col
       # 3. Optionally include depth as feature if include_depth_feature = TRUE
       # 4. Sort by depth (for output organization)
       # 5. Call .fuzzy_kmeans_r() or Rust backend
       # 6. Compute normalized entropy per depth
       # 7. Return fuzzy_horizons object
   }
   ```

2. **S3 class structure:**
   ```r
   # Object of class "fuzzy_horizons"
   # List with components:
   # - call: original function call
   # - depths: numeric vector (depth values, sorted)
   # - element_cols: character vector (elements used)
   # - centers: matrix (k x p) - cluster centers (horizon typology)
   # - memberships: matrix (n x k) - membership values [0, 1], rows sum to 1
   # - entropy: numeric(n) - normalized entropy [0, 1] per depth
   #            0 = certain (one dominant horizon)
   #            1 = maximum uncertainty (equal membership across all horizons)
   # - dominant_horizon: integer(n) - which horizon has max membership per depth
   # - n_horizons: integer (k)
   # - m: fuzziness exponent used
   # - iterations: integer (actual iterations to convergence)
   # - converged: logical
   # - method: "r" or "rust"

   # S3 methods to implement:
   # - print.fuzzy_horizons()
   # - summary.fuzzy_horizons()
   # - plot.fuzzy_horizons() [integrates with 03f plot.R]
   ```

3. **Design notes:**
   - Depth NOT included as feature by default (cluster by composition)
   - include_depth_feature = TRUE for noisy data (spatial regularization)
   - Full membership matrix stored (not sparse) for interpretability
   - Entropy identifies transitional zones (high entropy = uncertain assignment)

### D3: Basic Horizon Naming [MINIMAL - Lower Priority]
**Files:** `R/horizons.R`

1. **Simple naming function:**
   ```r
   #' Add basic horizon names to fuzzy classification
   #'
   #' @param fuzzy_result Object of class "fuzzy_horizons"
   #' @param method character. "numeric" (H1, H2, ...) or "depth" (based on position)
   #' @return Modified fuzzy_horizons object with horizon_names component
   #' @export
   name_fuzzy_horizons <- function(fuzzy_result, method = "numeric") {
       # Simple naming schemes:
       # - "numeric": H1, H2, H3, ...
       # - "depth": Name by vertical position (Surface, Upper, Middle, Lower, Deep)
       #
       # Returns: fuzzy_result with added component:
       #   horizon_names: character vector (one per cluster)
   }
   ```

2. **Design notes:**
   - **Skip complex pedological inference** (dataset/application specific)
   - Basic distinctions only: numeric or position-based
   - Future enhancement: User-provided naming function or trained model
   - Advanced naming would require:
     - Training data with labeled horizons
     - Element signature databases
     - Soil taxonomy knowledge base
   - Leave this extensibility for users to implement custom logic

### D4: Visualization [Base R - Integrates with 03f]
**Files:** `R/plot.R` (extend from 03f/03g)

1. **S3 plot method:**
   ```r
   #' Plot fuzzy horizon classification results
   #'
   #' @param x Object of class "fuzzy_horizons"
   #' @param which character. Which plot: "heatmap", "entropy", "profiles", "centers"
   #' @param element_data Optional: original data for element profiles
   #' @param col_palette character. Color palette name for hcl.colors(). Default: "viridis"
   #' @param ... Additional graphical parameters
   #' @export
   plot.fuzzy_horizons <- function(x,
                                     which = "heatmap",
                                     element_data = NULL,
                                     col_palette = "viridis",
                                     ...) {
       # Base R plotting (no ggplot2)
       # Use base R hcl.colors() - default "viridis" palette

       switch(which,
           heatmap = {
               # Use image() or filled.contour()
               # X-axis: horizon types (H1, H2, ...)
               # Y-axis: depth (reversed, increasing downward)
               # Color: membership strength [0, 1]
               # Optionally sort rows by dominant_horizon
           },
           entropy = {
               # Plot entropy profile
               # X-axis: normalized entropy [0, 1]
               # Y-axis: depth (reversed)
               # Highlight high-entropy zones (transitional boundaries)
           },
           profiles = {
               # If element_data provided:
               # Multi-panel: element profiles colored by dominant horizon
               # Show membership strength via alpha/intensity
           },
           centers = {
               # Radar/spider plot of cluster centers
               # Use polygon() with base R
               # One polygon per horizon
               # Shows element signature for each horizon type
           }
       )
   }
   ```

2. **Data extraction for external plotting:**
   ```r
   #' Extract data for custom plotting
   #'
   #' @param fuzzy_result Object of class "fuzzy_horizons"
   #' @param format character. "long" or "wide" for membership matrix
   #' @return data.frame formatted for ggplot2/plotly/other packages
   #' @export
   extract_fuzzy_plot_data <- function(fuzzy_result, format = "long") {
       # Returns data.frame suitable for:
       # - ggplot2: geom_tile() for heatmap
       # - plotly: heatmap plots
       # - Other visualization packages
       #
       # "long" format: depth, horizon_id, membership, entropy
       # "wide" format: depth, H1, H2, H3, ..., entropy
   }
   ```

3. **Base R implementation notes:**
   - Use `hcl.colors(n, palette = "viridis")` for color palettes (base R)
   - `image()` for heatmaps (simple, fast)
   - `filled.contour()` for smoother heatmaps (with legend)
   - `polygon()` for radar plots (implement custom layout)
   - Data wrangling to long/wide formats for external packages

### D5: Optimal Cluster Selection [HIGH PRIORITY]
**Files:** `R/horizons.R`

1. **Suggest optimal number of horizons:**
   ```r
   #' Suggest optimal number of horizon clusters
   #'
   #' @param data data.frame with depth and element columns
   #' @param depth_col character. Depth column name
   #' @param element_cols character vector. Element columns (NULL = auto-detect)
   #' @param k_min integer. Minimum k to test. Default: 2
   #' @param k_max integer. Maximum k to test. Default: 10
   #' @param m numeric. Fuzziness exponent. Default: 2.0
   #' @param method character. Selection criterion: "elbow", "silhouette", "both"
   #' @param plot logical. Show diagnostic plot? Default: TRUE
   #' @return List with suggested k and diagnostic information
   #' @export
   suggest_n_horizons <- function(data,
                                    depth_col = "depth",
                                    element_cols = NULL,
                                    k_min = 2,
                                    k_max = 10,
                                    m = 2.0,
                                    method = "both",
                                    plot = TRUE) {

       # Algorithm:
       # 1. Fit fuzzy k-means for k = k_min:k_max
       # 2. Compute metrics:
       #    a. Within-cluster sum of squares (WCSS):
       #       sum_j sum_i (u_ij^m * ||x_i - c_j||^2)
       #    b. Fuzzy silhouette score (if method includes "silhouette")
       # 3. Identify elbow point in WCSS curve
       # 4. Return suggested k with diagnostics

       # Returns: list(
       #   suggested_k = integer (from elbow or silhouette)
       #   wcss = numeric vector (k_min:k_max)
       #   silhouette = numeric vector (if computed)
       #   elbow_k = integer (elbow point)
       #   best_silhouette_k = integer (max silhouette)
       #   notes = character (interpretation guidance)
       # )

       # If plot = TRUE: create diagnostic plot
       #   Panel 1: WCSS vs k (with elbow point marked)
       #   Panel 2: Silhouette score vs k (if computed)
   }
   ```

2. **Silhouette score for fuzzy clustering:**
   ```r
   #' Compute fuzzy silhouette coefficient
   #'
   #' @param fuzzy_result Object of class "fuzzy_horizons"
   #' @param data Original data matrix (for distance calculations)
   #' @return List with silhouette scores and summary statistics
   #' @export
   silhouette_fuzzy <- function(fuzzy_result, data) {
       # Fuzzy silhouette score (adapted for fuzzy clustering):
       # For each point i:
       #   a(i) = weighted average distance to own cluster
       #   b(i) = weighted average distance to nearest cluster
       #   s(i) = (b(i) - a(i)) / max(a(i), b(i))
       #
       # Weights based on membership values

       # Returns: list(
       #   scores = numeric(n) - silhouette score per depth
       #   average = mean silhouette score
       #   median = median silhouette score
       #   interpretation = character (quality assessment)
       # )

       # Interpretation:
       # - avg > 0.7: strong structure
       # - avg 0.5-0.7: reasonable structure
       # - avg 0.25-0.5: weak structure
       # - avg < 0.25: no substantial structure
       # Warn if median < 0.5
   }
   ```

3. **Design notes:**
   - Elbow method: primary recommendation (fast, intuitive)
   - Silhouette: validation metric (slower for large data)
   - Both methods useful for different scenarios
   - Plot helps user make informed decision

### D6: Cross-Validation [HIGH PRIORITY]
**Files:** `R/horizons.R`

1. **k-fold cross-validation:**
   ```r
   #' Cross-validate fuzzy horizon classification
   #'
   #' @param data data.frame with depth and element columns
   #' @param depth_col character. Depth column name
   #' @param element_cols character vector. Element columns (NULL = auto-detect)
   #' @param n_horizons integer. Number of clusters
   #' @param k_folds integer. Number of CV folds. Default: 5
   #' @param m numeric. Fuzziness exponent. Default: 2.0
   #' @param ... Additional parameters passed to horizon_classify_fuzzy()
   #' @return List with CV results and diagnostics
   #' @export
   validate_fuzzy_classification <- function(data,
                                              depth_col = "depth",
                                              element_cols = NULL,
                                              n_horizons = 5,
                                              k_folds = 5,
                                              m = 2.0,
                                              ...) {

       # Algorithm:
       # 1. Split data into k folds (stratified by depth if possible)
       # 2. For each fold:
       #    a. Train on k-1 folds
       #    b. Predict membership for held-out fold
       #       (assign to nearest center, compute membership)
       #    c. Compute metrics:
       #       - Mean entropy of predictions
       #       - Disagreement with full-data classification
       # 3. Aggregate results across folds

       # Returns: list(
       #   cv_entropy = numeric vector (mean entropy per fold)
       #   cv_entropy_mean = mean across folds
       #   cv_entropy_sd = sd across folds
       #   disagreement = proportion of different dominant assignments
       #   folds = list of fold results (for inspection)
       #   interpretation = character (quality assessment)
       # )
   }
   ```

2. **Design notes:**
   - k-fold CV assesses stability and generalization
   - Useful for comparing different k or m values
   - Helps detect overfitting (too many clusters)
   - Spatial consideration: folds should respect depth ordering (not fully random)

### D7: Bootstrap Stability [LOWER PRIORITY - Future Integration]
**Files:** `R/horizons.R` (defer to later phase)

1. **Future integration with existing bootstrap infrastructure:**
   ```r
   #' Bootstrap stability analysis for fuzzy classification
   #'
   #' @param fuzzy_result Object of class "fuzzy_horizons"
   #' @param data Original data
   #' @param n_boot integer. Number of bootstrap samples. Default: 100
   #' @return Bootstrap stability results
   #' @export
   bootstrap_horizon_stability <- function(fuzzy_result, data, n_boot = 100) {
       # DEFER: Integrate with existing bootstrap infrastructure (Phase 3e)
       # Similar to sm_optim_bootstrap() patterns
       #
       # Algorithm:
       # 1. Resample rows with replacement
       # 2. Refit fuzzy k-means
       # 3. Match clusters across bootstrap samples (label switching problem)
       # 4. Compute stability metrics:
       #    - Average membership uncertainty
       #    - Cluster stability (Jaccard index)
       # 5. Flag unstable assignments

       # Returns: list(
       #   membership_stability = matrix (n x k) - stability scores
       #   cluster_stability = numeric(k) - per-cluster stability
       #   unstable_depths = integer vector - flagged depths
       # )
   }
   ```

2. **Implementation note:**
   - Lower priority: defer until after core functionality
   - Integrate with Phase 3e bootstrap patterns (sieve, parametric)
   - Requires solving label switching problem (match clusters across runs)
   - Consider using existing bootstrap infrastructure

### D8: Integration with Mahalanobis Boundaries [OPTIONAL]
**Files:** `R/horizons.R`

1. **Guided initialization using 03g boundaries:**
   ```r
   #' Fuzzy classification with boundary-guided initialization
   #'
   #' @param data data.frame with depth and element columns
   #' @param boundary_result Object of class "horizon_boundaries" (from 03g)
   #' @param ... Additional parameters passed to horizon_classify_fuzzy()
   #' @return Object of class "fuzzy_horizons"
   #' @export
   horizon_classify_hybrid <- function(data,
                                        boundary_result = NULL,
                                        ...) {

       # OPTIONAL enhancement - works without boundary_result

       if (is.null(boundary_result)) {
           warning("No boundary hints provided; using standard initialization")
           return(horizon_classify_fuzzy(data, ...))
       }

       # Integration strategy:
       # 1. Extract boundary depths from horizon_boundaries object
       # 2. Use horizons (between boundaries) to initialize cluster centers
       #    - Compute mean element composition within each horizon
       # 3. Pass initial centers to fuzzy k-means
       # 4. Benefits:
       #    - Faster convergence
       #    - More interpretable (aligns with detected boundaries)
       #    - Combines boundary detection + fuzzy classification

       # Returns: fuzzy_horizons object with additional fields:
       #   - boundary_guided = TRUE
       #   - boundary_alignment = measure of how well clusters align with boundaries
   }
   ```

2. **Design notes:**
   - Optional: fuzzy classification works standalone
   - Useful when both boundary detection (03g) and classification (03h) performed
   - Accelerates convergence by good initialization
   - Improves interpretability (clusters respect detected boundaries)

## Implementation Steps

**Phase 1: R Reference Implementation**
1. Create internal `.fuzzy_kmeans_r()` in R/horizons.R (extend from 03g)
   - Pure base R algorithm
   - Use base R kmeans() for initialization
   - Implement fuzzy membership update rules
   - Compute normalized entropy
   - Convergence checking (membership/centers/both)
2. Implement `horizon_classify_fuzzy()` main function
3. Implement S3 class structure:
   - `print.fuzzy_horizons()`
   - `summary.fuzzy_horizons()`
4. Create synthetic test data (reuse/extend 03g data)
   - Known cluster structure
   - Overlapping clusters (gradational)
   - Noisy data
5. Write tests in tests/testthat/test-fuzzy-horizons.R
   - Validate membership matrix (rows sum to 1)
   - Test convergence criteria
   - Check entropy calculations
6. Add roxygen documentation with minimal examples

**Phase 2: Cluster Selection and Validation [HIGH PRIORITY]**
7. Implement `suggest_n_horizons()` with elbow method
8. Implement `silhouette_fuzzy()` score calculation
9. Implement `validate_fuzzy_classification()` k-fold CV
10. Test on synthetic data with varying k
11. Create diagnostic plots (base R)

**Phase 3: Visualization**
12. Add `plot.fuzzy_horizons()` to R/plot.R (from 03f/03g)
13. Implement heatmap visualization using image()/filled.contour()
14. Implement entropy profile plot
15. Implement basic radar plot for cluster centers using polygon()
16. Add `extract_fuzzy_plot_data()` for external plotting packages
17. Test visualizations with synthetic data
18. Document in .github/examples/

**Phase 4: Optional Enhancements**
19. Implement basic `name_fuzzy_horizons()` (numeric/depth naming)
20. Implement `horizon_classify_hybrid()` (boundary-guided initialization)
21. Test integration with 03g boundary detection
22. Document hybrid workflows

**Phase 5: Rust Implementation [PARALLEL with R Development]**
23. Create src/horizons.rs (if not exists from 03g)
24. Implement fuzzy k-means in Rust:
    - Use ndarray or nalgebra for matrices
    - Parallel distance calculations with rayon
    - Fuzzy membership updates (vectorized)
25. Add FFI wrappers in src/lib.rs
26. Test Rust implementation against R reference
27. Benchmark R vs Rust performance
28. Update R functions to use Rust backend when use_rust = TRUE

**Phase 6: Documentation (After Core Implementation)**
29. Create .github/examples/fuzzy-classification.md
30. Update README with fuzzy classification section
31. Prepare for vignette (combine with 03g)

**Phase 7: Bootstrap Integration [FUTURE - Lower Priority]**
32. Implement `bootstrap_horizon_stability()` (integrate with Phase 3e patterns)
33. Solve label switching problem
34. Test stability analysis

## Success Criteria

**Core Functionality (Must Have):**
- [ ] R reference implementation correct (memberships sum to 1 per row)
- [ ] Fuzzy membership update rules mathematically correct
- [ ] Normalized entropy calculated correctly [0, 1]
- [ ] Convergence criteria working (membership/centers/both)
- [ ] Base R kmeans() initialization working
- [ ] S3 class structure with print/summary methods
- [ ] Pure base R (minimal dependencies: stats only)
- [ ] Synthetic test data with known clusters
- [ ] All tests passing

**Cluster Selection (Must Have):**
- [ ] suggest_n_horizons() provides reasonable k recommendations
- [ ] Elbow method identifies inflection point
- [ ] Silhouette scores computed correctly
- [ ] Diagnostic plots clear and informative

**Validation (Must Have):**
- [ ] k-fold CV functional
- [ ] CV entropy metrics computed
- [ ] Stability assessment reasonable

**Visualization (Must Have):**
- [ ] Base R heatmap working (image() or filled.contour())
- [ ] Entropy profile plot working
- [ ] Radar plot for cluster centers (basic polygon implementation)
- [ ] extract_fuzzy_plot_data() returns proper format
- [ ] Uses hcl.colors() with viridis palette

**Rust Implementation (Must Have):**
- [ ] Rust fuzzy k-means matches R reference results
- [ ] FFI integration working
- [ ] use_rust parameter toggles between backends
- [ ] Performance improvement demonstrated (benchmark)
- [ ] Parallel processing with rayon

**Optional Features (Nice to Have):**
- [ ] Basic horizon naming working
- [ ] Hybrid initialization with 03g boundaries
- [ ] Integration examples documented
- [ ] Bootstrap stability (future phase)

**Documentation (After Core Complete):**
- [ ] Roxygen documentation complete with examples
- [ ] Examples in .github/examples/fuzzy-classification.md
- [ ] README updated with fuzzy classification workflow
- [ ] Combined vignette with 03g (horizon analysis)

## Files to Create/Modify

**New Files:**
- None (extends existing R/horizons.R from 03g)
- `tests/testthat/test-fuzzy-horizons.R` - fuzzy k-means tests

**Modified Files:**
- `R/horizons.R` - add fuzzy k-means functions (extends 03g)
- `R/plot.R` - add plot.fuzzy_horizons() method
- `src/horizons.rs` - add fuzzy k-means (if not exists from 03g, create)
- `src/lib.rs` - FFI exports for fuzzy functions
- `tests/testthat/helper-horizon-data.R` - extend with fuzzy test data
- `DESCRIPTION` - no new dependencies
- `NAMESPACE` - exports via roxygen2
- `README.md` - add fuzzy classification section

## Files to Review Before Implementation
- `R/horizons.R` (from 03g) - patterns for horizon functions
- `R/plot.R` (from 03f/03g) - visualization patterns
- `src/optimizer.rs` - Rust patterns for iterative algorithms
- `R/uncertainty.R` - bootstrap patterns (for future D7)
- `tests/testthat/test-horizons.R` (from 03g) - test patterns

## Related Prompts
- **03g: Mahalanobis Distance** - boundary detection, feeds into hybrid initialization
- **03f: R Integration** - plot.R infrastructure, visualization patterns
- **03i: Weathering Indices** - uses same multivariate element data
- **Phase 3e: Uncertainty** - bootstrap patterns for stability analysis (future)

## Implementation Dependencies
- **Implement AFTER:** 03g (extends R/horizons.R, uses plot.R)
- **Implement BEFORE:** 03i (weathering indices may use fuzzy results)

## Algorithm Details

### Fuzzy k-means Algorithm
Standard fuzzy c-means (FCM) algorithm:

**Initialization:**
```
Use base R kmeans(data, centers = k) for k-means++ initialization
Extract centers from kmeans result
```

**Iterative Updates:**
```
Repeat until convergence:
  1. Update membership matrix U:
     For each depth i and cluster j:
       d_ij = ||x_i - c_j||  (Euclidean distance)
       u_ij = 1 / sum_l((d_ij / d_il)^(2/(m-1)))

  2. Normalize memberships (should sum to 1 per row)

  3. Update centers:
     For each cluster j:
       c_j = sum_i(u_ij^m * x_i) / sum_i(u_ij^m)

  4. Check convergence:
     If convergence = "membership":
       max|U_new - U_old| < tol
     If convergence = "centers":
       max||c_new - c_old|| < tol
     If convergence = "both":
       Both criteria must be met
```

**Entropy Calculation:**
```
For each depth i:
  entropy_i = -sum_j(u_ij * log(u_ij))
  normalized_entropy_i = entropy_i / log(k)  # scales to [0, 1]
```

### Parameter Guidelines

**Fuzziness Exponent (m):**
- m = 1.5: harder boundaries, closer to crisp k-means
- m = 2.0: **DEFAULT** (good general choice, standard in literature)
- m = 3.0: softer boundaries, more gradational
- m > 3.0: very fuzzy, may not provide useful distinctions
- Must validate: m > 1.0 (m = 1 is crisp k-means, undefined at m ≤ 1)
- Higher m → flatter membership distribution

**Number of Clusters (k):**
- Minimum: 2 (binary distinction)
- Typical soil profiles: 3-6 horizons
- Use suggest_n_horizons() to determine optimal k
- Avoid overfitting: k should not exceed n/10 (rule of thumb)

**Convergence:**
- Membership convergence (default): more stable, recommended
- Center convergence: faster but may oscillate
- Both: most stringent, slowest

### Computational Complexity
- Time: O(n × k × d × iter)
  - n = number of depth samples
  - k = number of clusters
  - d = number of element features
  - iter = iterations to convergence (typically 10-100)
- Space: O(n × k) for membership matrix (stored in full)

### Interpretation Guidelines

**Entropy Interpretation:**
- entropy ≈ 0: Certain assignment (one dominant horizon)
- entropy ≈ 0.3: Moderate confidence
- entropy ≈ 0.7: High uncertainty (transitional zone)
- entropy ≈ 1: Maximum uncertainty (equal membership)

**Membership Interpretation:**
- u_ij > 0.7: Strong membership to horizon j
- u_ij ≈ 0.5: Transitional between horizons
- u_ij < 0.3: Weak membership

## Example Workflows

### Basic Usage
```r
library(soilmotif)

# Load multivariate soil data
data <- read.csv("pxrf_profile.csv")
# Columns: depth, Al, Fe, Si, K, Ca, Ti, Zr

# Suggest optimal number of horizons
k_suggest <- suggest_n_horizons(data, depth_col = "depth", k_max = 10)
print(k_suggest)
# Suggests k = 4 based on elbow method

# Classify horizons
fuzzy_result <- horizon_classify_fuzzy(
    data,
    depth_col = "depth",
    n_horizons = 4,
    m = 2.0,
    use_rust = TRUE
)

# View results
print(fuzzy_result)
summary(fuzzy_result)

# Visualize membership matrix
plot(fuzzy_result, which = "heatmap")

# Visualize entropy (identify transitional zones)
plot(fuzzy_result, which = "entropy")

# View cluster centers (element signatures)
plot(fuzzy_result, which = "centers")
```

### Cross-Validation
```r
# Validate classification stability
cv_result <- validate_fuzzy_classification(
    data,
    depth_col = "depth",
    n_horizons = 4,
    k_folds = 5
)
print(cv_result)
# Low CV entropy = stable classification
```

### Comparing Different m Values
```r
# Test different fuzziness levels
m_values <- c(1.5, 2.0, 3.0)
results <- lapply(m_values, function(m) {
    horizon_classify_fuzzy(data, n_horizons = 4, m = m)
})
names(results) <- paste0("m_", m_values)

# Compare entropy profiles
par(mfrow = c(1, 3))
for (i in seq_along(results)) {
    plot(results[[i]], which = "entropy", main = names(results)[i])
}
```

### Hybrid Approach with Boundary Detection
```r
# First: Detect boundaries (03g)
boundaries <- horizon_boundaries_mahalanobis(data, window_size = 10)
plot(boundaries)

# Second: Fuzzy classification with boundary hints
fuzzy_result <- horizon_classify_hybrid(
    data,
    boundary_result = boundaries,
    m = 2.0
)

# Classification aligns with detected boundaries
plot(fuzzy_result, which = "heatmap")
```

### Extract Data for ggplot2
```r
library(ggplot2)
library(soilmotif)

# Classify
fuzzy_result <- horizon_classify_fuzzy(data, n_horizons = 4)

# Extract for ggplot2
plot_data <- extract_fuzzy_plot_data(fuzzy_result, format = "long")

# Custom ggplot2 heatmap
ggplot(plot_data, aes(x = horizon_id, y = depth, fill = membership)) +
    geom_tile() +
    scale_fill_viridis_c() +
    scale_y_reverse() +
    labs(x = "Horizon Type", y = "Depth (cm)", fill = "Membership") +
    theme_minimal()
```

### Analyzing Transitional Zones
```r
# Classify
fuzzy_result <- horizon_classify_fuzzy(data, n_horizons = 4)

# Find high-entropy depths (transitional zones)
transitional <- which(fuzzy_result$entropy > 0.7)
transitional_depths <- fuzzy_result$depths[transitional]

cat("Transitional zones at depths:", transitional_depths, "cm\n")

# These depths are uncertain - may warrant targeted sampling
```
