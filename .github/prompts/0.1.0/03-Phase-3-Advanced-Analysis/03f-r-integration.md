# 03f: R Ecosystem Integration & Visualization

## Objective
Integrate optimization results with tidyverse ecosystem (broom, ggplot2, purrr) and enable Bayesian workflows, interactive visualization, and complex data pipelines.

## Design Principles
- **Minimal Dependencies**: Keep broom, ggplot2, purrr, tidyr, dplyr in **Suggests**, NOT Imports
- **Base R First**: Primary visualization interface uses base R plotting
- **S3 Compatibility**: Provide S3 methods (tidy/glance/augment) that work with or without broom installed
- **Graceful Degradation**: All functions check for optional packages using `requireNamespace()` pattern
- **Optional Enhancement**: ggplot2 helpers available but not required for core functionality

## Current State
- Basic R interface in `R/fit.R`
- No broom methods (tidy/glance/augment)
- No ggplot2 extensions
- No Bayesian integration
- Batch workflows not streamlined for dplyr
- Phase 3e (uncertainty/bootstrap) complete and available

## Deliverables

### D1: broom Methods for Optimization Results [ESSENTIAL - Priority 1]
**Files:** `R/broom-methods.R` (new file), `R/util.R` (helper function)

1. **Add package check helper to R/util.R:**
   ```r
   # Internal helper for suggested package dependencies
   # Follows existing pattern in R/preprocess.R and R/spline.R
   .require_package <- function(pkg, reason = "this functionality") {
       if (!requireNamespace(pkg, quietly = TRUE)) {
           stop(sprintf("Package '%s' is required for %s.\nInstall with: install.packages('%s')",
                        pkg, reason, pkg),
                call. = FALSE)
       }
   }
   ```

2. **Implement S3 methods in R/broom-methods.R:**
   ```r
   # These methods are ALWAYS defined (no conditional registration)
   # They check for dependencies at runtime

   #' Tidy a soilmotif optimization result
   #'
   #' @param x A soilmotif_optimization object
   #' @param ... Additional arguments (unused)
   #' @return A data.frame with columns: term, estimate, std.error, statistic, p.value
   #' @export
   tidy.soilmotif_optimization <- function(x, ...) {
       # Return base R data.frame (no tibble dependency)
       data.frame(
           term = names(x$params),
           estimate = x$params,
           std.error = if (!is.null(x$param_se)) x$param_se else NA_real_,
           statistic = if (!is.null(x$param_se)) x$params / x$param_se else NA_real_,
           p.value = if (!is.null(x$param_se)) {
               2 * pnorm(abs(x$params / x$param_se), lower.tail = FALSE)
           } else NA_real_,
           row.names = NULL,
           stringsAsFactors = FALSE
       )
   }

   #' Glance at a soilmotif optimization result
   #'
   #' @param x A soilmotif_optimization object
   #' @param ... Additional arguments (unused)
   #' @return A data.frame with model summary statistics
   #' @export
   glance.soilmotif_optimization <- function(x, ...) {
       data.frame(
           rmse = x$rmse,
           r.squared = if (!is.null(x$r2)) x$r2 else NA_real_,
           nobs = length(x$observed),
           npar = length(x$params),
           iterations = if (!is.null(x$iterations)) x$iterations else NA_integer_,
           converged = if (!is.null(x$converged)) x$converged else NA,
           algorithm = if (!is.null(x$algorithm)) x$algorithm else NA_character_,
           row.names = NULL,
           stringsAsFactors = FALSE
       )
   }

   #' Augment data with model predictions and residuals
   #'
   #' @param x A soilmotif_optimization object
   #' @param newdata Optional new depth values; if NULL, uses original data
   #' @param ... Additional arguments (unused)
   #' @return A data.frame with observed, predicted, and residual values
   #' @export
   augment.soilmotif_optimization <- function(x, newdata = NULL, ...) {
       if (is.null(newdata)) {
           newdata <- seq_along(x$observed)
       }

       data.frame(
           depth = newdata,
           .observed = x$observed,
           .fitted = x$predicted,
           .resid = x$observed - x$predicted,
           row.names = NULL,
           stringsAsFactors = FALSE
       )
   }
   ```

3. **Use cases:**
   - Works immediately with base R (returns data.frame, not tibble)
   - If user has broom installed, methods integrate seamlessly with broom workflows
   - `tidy(fit)` → parameter table for reporting
   - `glance(fit)` → summary statistics
   - `augment(fit)` → residual diagnostics

4. **Testing:**
   - Core functionality tests in main test suite (no broom required)
   - Integration tests in `tests/testthat/test-broom-integration.R` with `skip_if_not_installed("broom")`

### D2: Base R Visualization (Primary Interface) [ESSENTIAL - Priority 1]
**Files:** `R/plot.R` (new file)

1. **Core plotting functions using base R:**
   ```r
   #' Plot soil profile optimization results
   #'
   #' @param x A soilmotif_optimization object
   #' @param bootstrap_result Optional: bootstrap uncertainty result
   #' @param depths Depth sequence for plotting (default: 1:200)
   #' @param xlim Property value limits
   #' @param ylim Depth limits (reversed by default for soil convention)
   #' @param col Color for fitted line
   #' @param ci_col Color for confidence interval bands
   #' @param add Logical; add to existing plot?
   #' @param ... Additional graphical parameters
   #' @export
   plot.soilmotif_optimization <- function(x,
                                            bootstrap_result = NULL,
                                            depths = NULL,
                                            xlim = NULL,
                                            ylim = NULL,
                                            col = "blue",
                                            ci_col = adjustcolor(col, alpha.f = 0.3),
                                            add = FALSE,
                                            ...) {
       # Base R implementation with no dependencies
       # - Plot observed data as points
       # - Overlay fitted curve
       # - Add confidence bands if bootstrap_result provided
       # - Follow soil science convention (depth increases downward)
   }

   #' Plot horizon boundaries
   #'
   #' @param boundary_result Result from horizon_boundaries_mahalanobis() (03g)
   #' @param element_data Original element concentration data
   #' @param which Which plots to show: "all", "elements", "distance", "horizons"
   #' @export
   plot_horizon_boundaries <- function(boundary_result,
                                        element_data = NULL,
                                        which = "all",
                                        ...) {
       # Base R multi-panel plot:
       # Panel 1: Element concentration profiles
       # Panel 2: Mahalanobis distance profile with threshold
       # Panel 3: Identified horizons as horizontal bands
   }

   #' Plot fuzzy horizon classification
   #'
   #' @param fuzzy_result Result from horizon_classify_fuzzy() (03h)
   #' @param type Type of plot: "heatmap", "profiles", "centers"
   #' @export
   plot_fuzzy_horizons <- function(fuzzy_result,
                                     type = "heatmap",
                                     ...) {
       # Base R visualization of fuzzy membership
       # Uses image() or similar for heatmap representation
   }
   ```

2. **Helper functions for custom plotting:**
   ```r
   #' Prepare data for custom soil profile plots
   #'
   #' @param optimization_result A soilmotif_optimization object
   #' @param bootstrap_result Optional bootstrap result for confidence intervals
   #' @return A list with components: depths, observed, fitted, ci_lower, ci_upper
   #' @export
   extract_plot_data <- function(optimization_result, bootstrap_result = NULL) {
       # Returns structured data suitable for custom plotting
       # Can be used with ggplot2, plotly, or base R
   }
   ```

### D3: ggplot2 Helpers (Optional Enhancement) [MEDIUM - Priority 2]
**Files:** `R/ggplot-helpers.R` (new file), `.github/examples/ggplot2-examples.md` (non-vignette)

1. **Data preparation helpers (NOT custom geoms):**
   ```r
   #' Prepare optimization results for ggplot2
   #'
   #' Returns data.frame ready for standard ggplot2 geoms
   #' @param x A soilmotif_optimization object
   #' @param bootstrap_result Optional bootstrap result
   #' @return data.frame with columns: depth, observed, fitted, ci_lower, ci_upper
   #' @export
   prepare_ggplot_data <- function(x, bootstrap_result = NULL) {
       .require_package("ggplot2", "ggplot2 visualization helpers")

       # Return data.frame suitable for:
       # geom_point(aes(x = observed, y = depth))
       # geom_line(aes(x = fitted, y = depth))
       # geom_ribbon(aes(xmin = ci_lower, xmax = ci_upper, y = depth))
   }

   #' Prepare horizon data for ggplot2
   #'
   #' @param boundary_result Result from horizon detection
   #' @return data.frame for geom_rect() or geom_hline()
   #' @export
   prepare_horizon_ggplot <- function(boundary_result) {
       .require_package("ggplot2", "ggplot2 visualization helpers")

       # Returns data.frame with: horizon_id, top, bottom, etc.
       # For use with: geom_rect(aes(ymin = top, ymax = bottom, ...))
   }
   ```

2. **Documentation in .github/examples/ggplot2-examples.md:**
   - NOT a vignette (avoids ggplot2 dependency in build process)
   - Shows example code using prepare_*() functions
   - User can copy/paste examples if they have ggplot2 installed
   - Demonstrates integration with tidyverse workflows

3. **Example usage (documented in examples file):**
   ```r
   # Example code (not in package, in documentation)
   library(ggplot2)
   library(soilmotif)

   # Basic profile plot
   plot_data <- prepare_ggplot_data(fit_result, bootstrap_result)

   ggplot(plot_data, aes(y = depth)) +
       geom_ribbon(aes(xmin = ci_lower, xmax = ci_upper), fill = "blue", alpha = 0.3) +
       geom_line(aes(x = fitted), color = "blue", linewidth = 1) +
       geom_point(aes(x = observed), alpha = 0.5) +
       scale_y_reverse() +
       labs(x = "Clay (%)", y = "Depth (cm)") +
       theme_minimal()
   ```

### D4: Batch Fitting Pipelines [MEDIUM - Priority 2]
**Files:** `R/batch-wrappers.R` (already exists; extend), `.github/examples/tidyverse-workflows.md`

1. **Document tidyverse workflows (examples file, NOT vignette initially):**
   - Provide example code showing integration with purrr, dplyr, tidyr
   - Users can use existing broom methods + base R batch functions
   - No new code required initially; document existing capabilities

2. **Example workflow documentation:**
   ```r
   # Documented in .github/examples/tidyverse-workflows.md
   library(dplyr)
   library(purrr)
   library(tidyr)
   library(soilmotif)

   # Batch fitting with tidyverse
   profiles <- read.csv("profiles.csv")

   results <- profiles %>%
       nest(data = -site_id) %>%
       mutate(
           # Use existing sm_optim()
           fit = map(data, ~sm_optim(.x$clay, c(100, 20), use_rust = TRUE)),

           # Use broom methods from D1
           params = map(fit, tidy),
           summary = map(fit, glance),

           # Bootstrap uncertainty
           bootstrap = map(data, ~sm_optim_bootstrap(.x$clay, n_bootstrap = 1000))
       ) %>%
       unnest(params, names_sep = "_")
   ```

3. **Future enhancement (optional):**
   - If demand exists, add convenience wrapper `batch_fit_profiles_tidy()`
   - But prioritize documentation of existing functionality first

### D5: Bayesian Integration (stan/brms) [OUT OF SCOPE - Document Only]
**Files:** Vignette only (wait until Phase 3f complete)

**Note:** Bayesian integration will be approached from Rust side in future work. For Phase 3f, document workflows only.

1. **Helper function for prior specification:**
   ```r
   #' Convert optimization results to Bayesian priors
   #'
   #' @param x A soilmotif_optimization object (preferably from bootstrap)
   #' @param prior_sd_factor Scale factor for prior standard deviations
   #' @return List with structured prior information for brms/rstan
   #' @export
   sm_to_priors <- function(x, prior_sd_factor = 0.5) {
       # Does NOT require rstan/brms at runtime
       # Returns structured list that can be used if user has those packages

       if (is.null(x$param_se)) {
           warning("No parameter uncertainty available. Consider using sm_optim_bootstrap().")
       }

       params <- x$params
       param_sds <- if (!is.null(x$param_se)) {
           x$param_se * prior_sd_factor
       } else {
           rep(NA_real_, length(params))
       }

       # Return list compatible with brms prior specification
       list(
           parameters = names(params),
           location = params,
           scale = param_sds,
           distribution = "normal",
           # Include metadata for user reference
           note = "Use these as informative priors in Bayesian models"
       )
   }
   ```

2. **Workflow documentation in vignette:**
   ```r
   # Example workflow (in vignette, requires brms)
   # if (requireNamespace("brms", quietly = TRUE)) {

   # Step 1: Fast optimization in Rust
   fit_opt <- sm_optim(clay, c(100, 20), use_rust = TRUE)

   # Step 2: Quantify uncertainty
   fit_boot <- sm_optim_bootstrap(clay, n_bootstrap = 1000)

   # Step 3: Extract prior information
   prior_info <- sm_to_priors(fit_boot, prior_sd_factor = 0.5)

   # Step 4: Use in brms (user's code)
   # priors <- c(
   #     prior(normal(prior_info$location[1], prior_info$scale[1]), coef = "param1"),
   #     prior(normal(prior_info$location[2], prior_info$scale[2]), coef = "param2")
   # )
   # fit_bayes <- brm(..., prior = priors)
   # }
   ```

3. **Documentation approach:**
   - Wait until full 03f implementation complete before creating vignette
   - Document workflow showing how optimization provides informative priors
   - Do NOT implement deep brms integration (future Rust-side work)

### D6: Interactive Visualization (plotly/shiny) [LOW PRIORITY - Future Work]
**Files:** Separate package or inst/shiny/ (deferred)

**Status:** Low priority; defer until after core 03f functionality complete.

1. **Approach:**
   - If implemented, place Shiny app in `inst/shiny/` directory
   - Launch with `shiny::runApp(system.file("shiny", package = "soilmotif"))`
   - Keeps shiny/plotly completely optional

2. **Future considerations:**
   - Interactive exploration of parameter space
   - Real-time bootstrap visualization
   - Horizon boundary adjustment interface
   - Consider as separate companion package (soilmotif.viz or similar)

### D7: Documentation & Vignettes [Wait until Phase 3f Complete]
**Files:** `vignettes/` (create after core implementation), `.github/examples/` (create during implementation)

**Implementation strategy:**
- Create `.github/examples/` documentation files DURING implementation (not vignettes)
- Convert to formal vignettes AFTER all 03f functionality is complete and tested

1. **During Implementation (non-vignette documentation):**
   - `.github/examples/broom-integration.md` - Using tidy/glance/augment methods
   - `.github/examples/ggplot2-examples.md` - ggplot2 helpers and workflows
   - `.github/examples/tidyverse-workflows.md` - purrr/dplyr batch processing
   - `.github/examples/bayesian-priors.md` - Bayesian workflow documentation

2. **After Phase 3f Complete (convert to vignettes):**

   **Vignette 1: "Tidyverse Workflows with soilmotif"**
   - Batch fitting multiple profiles
   - Nested data structures with tidyr
   - purrr mapping operations
   - Using broom methods for tidy results
   - Integration with dplyr pipelines

   **Vignette 2: "Visualization and Uncertainty"**
   - Base R plotting (primary interface)
   - Bootstrap CI interpretation
   - Plotting confidence bands
   - ggplot2 helper functions (optional)
   - Horizon boundary visualization (03g integration)
   - Fuzzy membership plots (03h integration)

   **Vignette 3: "Advanced Workflows"**
   - Bayesian prior specification from optimization results
   - Combining shape fitting with horizon detection
   - Multi-property analysis workflows
   - Comparison of optimization vs Bayesian approaches
   - Case study examples

## Implementation Steps

**Phase 1: Essential Functionality (Priority 1)**
1. Add `.require_package()` helper to R/util.R
2. Create R/broom-methods.R with tidy/glance/augment S3 methods
3. Create R/plot.R with base R visualization functions (plot.soilmotif_optimization)
4. Add tests in tests/testthat/test-broom-basic.R (no broom dependency)
5. Add integration tests in tests/testthat/test-broom-integration.R (skip_if_not_installed)
6. Write roxygen documentation for all new functions
7. Create .github/examples/broom-integration.md with usage examples

**Phase 2: Optional Enhancements (Priority 2)**
8. Create R/ggplot-helpers.R with prepare_ggplot_data() and related helpers
9. Add plot_horizon_boundaries() and plot_fuzzy_horizons() to R/plot.R (for 03g/03h)
10. Create .github/examples/ggplot2-examples.md with ggplot2 workflows
11. Create .github/examples/tidyverse-workflows.md with batch processing examples
12. Add tests in tests/testthat/test-ggplot-helpers.R (skip_if_not_installed)
13. Update README.md with tidyverse examples section

**Phase 3: Bayesian & Advanced (Priority 3)**
14. Create R/bayesian.R with sm_to_priors() function
15. Create .github/examples/bayesian-priors.md with workflow documentation
16. Add tests for sm_to_priors() (no brms/rstan dependency)

**Phase 4: Final Documentation (After all functionality complete)**
17. Convert .github/examples/ files to formal vignettes
18. Create vignette 1: Tidyverse Workflows
19. Create vignette 2: Visualization and Uncertainty
20. Create vignette 3: Advanced Workflows
21. Run full test suite including integration tests
22. Update DESCRIPTION with all suggested packages

## Success Criteria

**Essential (Must Have):**
- [ ] broom methods (tidy/glance/augment) working WITHOUT broom installed
- [ ] Base R plot() methods functional and documented
- [ ] Methods work with bootstrap uncertainty results (Phase 3e integration)
- [ ] Package check helpers follow existing pattern
- [ ] All core tests passing (no suggested package dependencies)
- [ ] Integration tests present with skip_if_not_installed()

**Medium Priority (Should Have):**
- [ ] ggplot2 helper functions available and documented
- [ ] Horizon visualization functions ready for 03g/03h
- [ ] Tidyverse workflow examples documented
- [ ] Examples in .github/examples/ directory
- [ ] README updated with tidyverse examples

**Lower Priority (Nice to Have):**
- [ ] Bayesian prior helper function sm_to_priors()
- [ ] Bayesian workflow documented
- [ ] 3 comprehensive vignettes complete
- [ ] All suggested packages tested in CI

**Package Integrity:**
- [ ] NO new Imports dependencies (keep only stats)
- [ ] All new packages in Suggests only
- [ ] DESCRIPTION updated: Suggests: broom, ggplot2, dplyr, tidyr, purrr, brms (or Enhances:)
- [ ] All functions gracefully handle missing suggested packages
- [ ] No Unicode violations (run detection script)

## Files to Review Before Implementation
- `R/fit.R` - existing optimization result structure (what fields are available)
- `R/uncertainty.R` - bootstrap result structure (param_se, ar1_coef, etc.)
- `R/preprocess.R` and `R/spline.R` - existing requireNamespace() patterns
- `R/util.R` - where to add .require_package() helper
- `tests/testthat/test-full-integration.R` - integration test patterns
- `DESCRIPTION` - current dependencies (Imports: stats; Suggests: aqp, mpspline2, testthat, knitr, rmarkdown)
- `.github/copilot-instructions.md` - package conventions and architecture

## Example Workflows

### Workflow 1: Basic broom Integration (No tidyverse required)
```r
library(soilmotif)

# Fit a profile
fit <- sm_optim(clay_data, c(40, 60), use_rust = TRUE)

# Extract tidy parameter estimates
params <- tidy(fit)
#   term estimate std.error statistic p.value
# 1    X1     42.3      2.1     20.14  < 0.001
# 2    X2     58.7      3.4     17.26  < 0.001

# Get model summary
summary <- glance(fit)
#   rmse r.squared nobs npar iterations converged algorithm
# 1  3.2      0.87  200    2        45      TRUE rust_impl

# Get predictions and residuals
augmented <- augment(fit)
#   depth .observed .fitted .resid
# 1     1      40.2    39.8    0.4
# 2     2      40.5    40.1    0.4
```

### Workflow 2: Batch Tidyverse Pipeline
```r
library(soilmotif)
library(dplyr)
library(purrr)
library(tidyr)

profiles %>%
    nest(data = -site_id) %>%
    mutate(
        # Fit each profile
        fit = map(data, ~sm_optim(.x$clay, c(100, 20), use_rust = TRUE)),

        # Extract bootstrap uncertainty
        boot = map(data, ~sm_optim_bootstrap(.x$clay, n_bootstrap = 1000)),

        # Use broom methods
        params = map(fit, tidy),
        summary = map(fit, glance)
    ) %>%
    unnest(params) %>%
    select(site_id, term, estimate, std.error, rmse = summary$rmse)
```

### Workflow 3: Base R Visualization
```r
library(soilmotif)

# Fit with uncertainty
fit <- sm_optim(clay_data, c(40, 60), use_rust = TRUE)
boot <- sm_optim_bootstrap(clay_data, n_bootstrap = 1000)

# Plot using base R (primary interface)
plot(fit, bootstrap_result = boot,
     main = "Clay Content Profile",
     xlab = "Clay (%)", ylab = "Depth (cm)")
```

### Workflow 4: ggplot2 Integration (Optional)
```r
library(soilmotif)
library(ggplot2)

# Prepare data for ggplot2
plot_data <- prepare_ggplot_data(fit, boot)

# Use standard ggplot2 geoms
ggplot(plot_data, aes(y = depth)) +
    geom_ribbon(aes(xmin = ci_lower, xmax = ci_upper),
                fill = "blue", alpha = 0.3) +
    geom_line(aes(x = fitted), color = "blue", linewidth = 1) +
    geom_point(aes(x = observed), alpha = 0.5) +
    scale_y_reverse() +
    labs(x = "Clay (%)", y = "Depth (cm)") +
    theme_minimal()
```

### Workflow 5: Bayesian Prior Specification
```r
library(soilmotif)

# Fast optimization
fit <- sm_optim(clay_data, c(40, 60), use_rust = TRUE)

# Quantify uncertainty
boot <- sm_optim_bootstrap(clay_data, n_bootstrap = 1000)

# Extract prior information
prior_info <- sm_to_priors(boot, prior_sd_factor = 0.5)

# Use in brms (if installed)
# library(brms)
# priors <- c(
#     prior(normal(prior_info$location[1], prior_info$scale[1]), coef = "param1"),
#     prior(normal(prior_info$location[2], prior_info$scale[2]), coef = "param2")
# )
```

### Workflow 6: Horizon Visualization (After 03g/03h)
```r
library(soilmotif)

# Detect boundaries
boundaries <- horizon_boundaries_mahalanobis(element_data, window_size = 10)

# Classify horizons
fuzzy <- horizon_classify_fuzzy(element_data, n_horizons = 5)

# Plot with base R
plot_horizon_boundaries(boundaries, element_data)
plot_fuzzy_horizons(fuzzy, type = "heatmap")
```

## Related Prompts
- **03e: Uncertainty** - Bootstrap results (COMPLETE; integrate with visualization)
- **03g: Horizon Detection (Mahalanobis)** - Will need plot_horizon_boundaries() from D2
- **03h: Horizon Classification (Fuzzy)** - Will need plot_fuzzy_horizons() from D2
- **03a-03d: Optimization** - All optimization results use broom methods from D1

## Implementation Dependencies
- **Implement BEFORE:** None (03e already complete)
- **Implement AFTER 03f:** 03g, 03h (will use visualization functions created here)

## Notes for Implementation

1. **Existing Patterns:**
   - Follow `requireNamespace()` pattern from R/preprocess.R and R/spline.R
   - Use `stop()` with informative message if required package missing
   - Return base R data.frame (not tibble) from broom methods
   - Follow existing roxygen documentation style

2. **S3 Method Registration:**
   - S3 methods exported via @export in roxygen comments
   - Methods ALWAYS defined (no conditional definition)
   - Runtime checks for suggested packages where needed

3. **Testing Strategy:**
   - Core functionality tests: No suggested package dependencies
   - Integration tests: `skip_if_not_installed("package")`
   - Separate test files for each integration (test-broom-integration.R, test-ggplot-helpers.R)

4. **Documentation Locations:**
   - During implementation: .github/examples/ (markdown files)
   - After complete: Convert to vignettes/ (Rmd files)
   - This avoids vignette build issues while developing

5. **Horizon Integration:**
   - Phase 3f creates visualization infrastructure
   - Phase 3g/3h will use these functions
   - Keep visualization functions generic enough to support both

6. **Package Dependency Management:**
   - Consider using Enhances: instead of Suggests: for ggplot2/broom (they enhance functionality but aren't tested)
   - Use Suggests: for packages with test coverage (testthat, knitr, rmarkdown)
   - Document this decision in DESCRIPTION comments
