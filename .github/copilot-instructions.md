Purpose
-------
Actionable guidance for AI coding agents working on soilmotif: an R package for fitting and analyzing soil depth functions with a Rust backend for high-performance optimization and pedogenic analysis.

Current Status: Phase 2 (Rust Core) Complete; Phase 3 (Advanced Analysis & Optimization) Preparation Underway
See .github/prompts/0.1.0/03-Phase-3-Advanced-Analysis/ for detailed Phase 3 roadmap.

CRITICAL RULES - ALWAYS FOLLOW
------------------------------
1. NEVER use Unicode characters. Use ASCII equivalents only (R^2 not superscript 2, " not smart quotes, etc.)
   - Applies to: R/, src/*, man/, vignettes/, tests/, .github, DESCRIPTION, NAMESPACE, *.md
   - Before finalizing any edit, run the Unicode detection script (see "No-Unicode Rule" section)
2. NEVER commit anything to git (even test commits)
3. NEVER push any local changes to the remote git repository
4. When a prompt/request is ambiguous, ASK QUESTIONS and provide options rather than guessing
   - Help guide user responses with clear alternatives and tradeoffs
   - Example: "I see you want to optimize profiles. Should I (a) use L-BFGS for fast convergence, or (b) add uncertainty quantification with bootstrap?"

Architecture Overview
---------------------
soilmotif uses a **two-layer architecture**:
- **R layer** (user-facing): R/*, man/, vignettes/
  - Provides friendly APIs: sm_*() functions
  - Handles input validation, preprocessing, tidyverse integration
  - Manages uncertainty quantification, visualization, reporting
- **Rust layer** (computation): src/*.rs
  - High-performance optimization (50+ times faster than R)
  - Trait-based design for pluggable objectives, algorithms, shape functions
  - FFI: extendr for R <-> Rust communication
  - Current FFI is STABLE; internal refactoring OK, exports unchanged

Quick Setup & Common Commands
-----------------------------
1. Install dependencies (from project root):
```bash
R -e 'if (!requireNamespace("remotes")) install.packages("remotes"); remotes::install_deps(dependencies = TRUE)'
```

2. Compile Rust backend + build R package:
```bash
R CMD INSTALL --no-multiarch --with-keep.source .
```

3. Run test suite (testthat):
```bash
R -e 'if (!requireNamespace("devtools")) install.packages("devtools"); devtools::test()'
```

4. Run single test file:
```bash
R -e "testthat::test_file('tests/testthat/test-fit.R')"
```

5. Local package check (fast, no vignettes):
```bash
R CMD check --no-build-vignettes --as-cran .
```

6. Detect non-ASCII characters in modified files:
```bash
python3 - <<'PY'
import os, re
for root, dirs, files in os.walk('.'):
  for fn in files:
    if fn.endswith(('.R', '.Rd', '.md', '.Rmd', 'DESCRIPTION', 'NAMESPACE')):
      p = os.path.join(root, fn)
      try:
        s = open(p, encoding='utf-8').read()
      except Exception:
        continue
      if re.search(r'[^\x00-\x7F]', s):
        print(p)
PY
```

No-Unicode Rule (Mandatory)
---------------------------
All source code, documentation, examples, and metadata MUST use only ASCII characters.
- Equivalents: use `R^2` instead superscript 2, use `"` not fancy quotes, use `->` not arrows
- Check these files especially: DESCRIPTION, NAMESPACE, man/*.Rd, R/*.R, vignettes/, tests/testthat/
- ALWAYS run the Unicode detection script before finalizing changes
- Include this check in any CI/testing you write

Repository Layout & Responsibilities
-----------------------------------
```
soilmotif/
|-- R/                          # R layer (user-facing)
|   |-- soilmotif-package.R     # Package exports
|   |-- fit.R                   # Core: sm_optim(), optimization dispatch, Rust wrappers
|   |-- fit-rust-wrappers.R     # Low-level Rust interface (batch functions, FFI calls)
|   |-- shape.R                 # Shape functions: sm_shape_sigmoid(), etc. (7 families)
|   |-- batch-wrappers.R        # Batch processing: fit multiple profiles in parallel
|   |-- spline.R                # Preprocessing: sm_spline() mass-preserving interpolation
|   |-- preprocess.R            # Data QC: sm_prepare(), validation
|   |-- model-selection.R       # Auto model selection: fit_motif_auto()
|   |-- util.R                  # Helpers: .scaleprop(), .validate_*, etc.
|   `-- zzz.R                   # .onLoad() for Rust backend initialization
|
|-- src/                        # Rust layer (computation backend)
|   |-- lib.rs                  # Main library + FFI exports (STABLE)
|   |-- optimizer.rs            # argmin-based optimization (Phase 3 refactor target)
|   |-- shape_functions.rs      # 7 shape families + future custom shapes
|   |-- objective.rs            # Cost functions: RMSE, SSE, MAE (extending to domain-specific in Phase 3)
|   |-- batch.rs                # Parallel batch processing via rayon
|   `-- entrypoint.c            # R integration glue code
|
|-- tests/testthat/             # Test suite (testthat edition 3)
|   |-- test-shape.R            # Shape function correctness
|   |-- test-fit.R              # Optimization basics
|   |-- test-rust-*.R           # Rust-specific tests
|   |-- test-integration.R      # End-to-end workflows
|   |-- test-full-integration.R # Complex batch scenarios
|   `-- test-model-selection.R  # Auto-selection logic
|
|-- man/                        # roxygen2 documentation (auto-generated)
|-- vignettes/                  # User guides and tutorials
|-- README.Rmd/README.md        # Package overview + examples
|-- DESCRIPTION                 # Package metadata (no Unicode!)
|-- NAMESPACE                   # Exports (auto-generated by roxygen2)
|
|-- .github/prompts/0.1.0/03-Phase-3-Advanced-Analysis/  # Detailed Phase 3 planning
|   |-- 00-phase-3-index.md          # Phase 3 roadmap + dependencies
|   |-- 03a-argmin-integration.md    # Argmin framework integration (FOUNDATION)
|   |-- 03b-domain-objectives.md     # Weighted/ordinal/Huber/quantile loss
|   |-- 03c-algorithms.md            # L-BFGS, Newton, SA, PSO, GA, DE, auto-select
|   |-- 03d-complex-shapes.md        # Monotone splines, bivariate, threshold
|   |-- 03e-uncertainty.md           # Bootstrap CI, sensitivity analysis
|   |-- 03f-r-integration.md         # Tidyverse, Bayesian, visualization
|   |-- 03g-horizons-mahalanobis.md  # Objective horizon delineation
|   |-- 03h-horizons-fuzzy.md        # Fuzzy k-means clustering
|   |-- 03i-weathering-indices.md    # Element ratios, weathering quantification
|   |-- 03j-correlation-networks.md  # Multivariate correlation + causal inference
|   |-- 03k-temporal-spatial.md      # Pedogenic rates, catena, kriging
|   `-- 03l-case-studies.md          # Integrated workflows + validation
|
`-- Cargo.toml                  # Rust dependencies
```

Current Architecture (Phase 2)
-----------------------------
**Optimization Dispatch (R -> Rust):**
```
sm_optim(observed, initial_params, ...)
  `-> [R layer validation/preprocessing]
      `-> optimize_profile_rust() or optimize_profile_rust_flexible()
          `-> [Rust via extendr-api]
              |- Parse shape family
              |- Set up objective (RMSE/SSE/MAE)
              |- Run Nelder-Mead (argmin-backed in Phase 3)
              `- Return optimized parameters
      `-> [R layer post-processing]
          |- Sort parameters
          |- Compute diagnostics (RMSE, R^2, AIC)
          `- Return optimization_result object
```

**Batch Fitting (Parallel):**
```
batch_fit_profiles(data, ...)
  `-> [R layer: dplyr/tidyr unnesting]
      `-> fit_batch_profiles_rust() [Rust via rayon parallelization]
          |- Each profile independently optimized
          `- Aggregated results
      `-> [R layer: tibble assembly + diagnostics]
```

Key Concepts & Conventions
---------------------------
1. **Function Naming:**
   - User functions: `sm_*()` prefix (e.g., `sm_optim`, `sm_shape_sigmoid`)
   - Internal R helpers: `.helper_name()` prefix (e.g., `.scaleprop`, `.validate_depths`)
   - Rust wrappers: `*_rust()` suffix (e.g., `optimize_profile_rust`)
   - See NAMESPACE for all exports

2. **Depth Axis Defaults:**
   - Default range: 1-200 cm (one-unit resolution)
   - Assumption: continuous depth from top to bottom
   - Plotting convention: depth increasing downward (use `scale_y_reverse()` or `ylim = c(200, 1)`)
   - Be careful when changing defaults; many examples/tests assume 1-200

3. **Shape Functions (7 families):**
   - `sm_shape_uniform()` - flat property across depth
   - `sm_shape_gradational()` - smooth linear change
   - `sm_shape_exponential()` - exponential decay/growth
   - `sm_shape_sigmoid()` - S-curve wetting front (3-parameter family)
   - `sm_shape_wetting_front()` - alias for sigmoid
   - `sm_shape_abrupt()` - sharp boundary
   - `sm_shape_peak()` - subsurface maximum
   - `sm_shape_minimax()` - alternating min/max (2 zones)
   All implemented in Rust (shape_functions.rs) with R wrappers in shape.R

4. **Input/Output Conventions:**
   - `sm_motif(x, params)`: Evaluate a shape at given parameters
     - x: numeric vector (1-cm depth resolution)
     - params: named numeric vector or list (shape-specific)
     - Returns: numeric vector (fitted values at each depth)
   - `sm_optim(observed, initial_params, ...)`: Optimize shape to fit data
     - observed: numeric vector
     - initial_params: seed for optimizer
     - Returns: list with class "optimization_result" (params, rmse, r2, aic, etc.)
   - Batch functions return data.frame/tibble with results per profile

5. **Optimization Strategy:**
   - **Phase 2 (Current):** Custom Nelder-Mead implementation (working, tested)
   - **Phase 3 (Planned):** Argmin integration with L-BFGS, Newton, Simulated Annealing, PSO, GA, DE
   - All wrapped through unified R interface: `sm_optim(..., algorithm = "auto"|"nelder_mead"|"lbfgs")`
   - Parameter bounds supported (physical constraints: pH 3-10, texture 0-100, etc.)

6. **Scaling & Data Handling:**
   - `.scaleprop()` (R/util.R): Clamps fitted values to observed property range
   - Missing values: handled in preprocessing, propagate through carefully
   - Depth normalization: handled internally for arbitrary input ranges
   - Data must be 1-unit resolution after preprocessing (sm_prepare())

Integration Points & Phase 3 Preparation
----------------------------------------
**Current (Phase 2) Integration:**
- R/Rust communication: extendr-api (stable FFI)
- Batch processing: rayon parallelization in Rust
- Uncertainty: basic diagnostics (RMSE, R^2, AIC) only
- Visualization: base R plots in examples

**Phase 3 Integration Points (Prepare for):**
- **Optimization Track (3a-3f):**
  - 03a: argmin replaces custom Nelder-Mead (src/optimizer.rs refactor)
  - 03b: domain-specific objectives (src/objective.rs extended)
  - 03c: algorithm selection exposed (R interface sm_optim(..., algorithm = "lbfgs"))
  - 03d: custom shape families (src/shape_functions.rs extended)
  - 03e: uncertainty quantification (new R/uncertainty.R + Rust bootstrap trait)
  - 03f: R ecosystem integration (broom methods, tidyverse, Bayesian, visualization)
- **Analysis Track (3g-3l):**
  - 03g-3h: horizon detection (new src/horizons.rs + R/horizons.R)
  - 03i: weathering indices (new R/weathering.R, element ratios)
  - 03j: correlation networks (new R/networks.R, community detection)
  - 03k: temporal/spatial analysis (new R/temporal.R, R/spatial.R)
  - 03l: case studies + integrated workflows (vignettes/)

**What This Means for Agents:**
- Expect new Rust modules (horizons.rs, etc.) during Phase 3
- R API may expand (new functions in fit.R, preprocess.R, new files for 03f-03l)
- FFI stable; internal refactoring of optimizer.rs/objective.rs is OK
- Batch processing infrastructure ready for parallel Phase 3 analyses
- Trait patterns will extend (ObjectiveFunction, Analyzer, etc.)

Tests & Documentation Workflow
------------------------------
1. **Tests:** Live in tests/testthat/, use testthat edition 3
   - Run full suite: `R -e 'devtools::test()'`
   - Run specific file: `R -e "testthat::test_file('tests/testthat/test-fit.R')"`
   - Target: 100% Phase 2 regression (all existing tests pass)
   - Phase 3 tests: Add new files (test-horizons.R, test-uncertainty.R, etc.)

2. **Documentation:**
   - roxygen2 comments in R/ files -> auto-generate man/*.Rd + NAMESPACE
   - After editing exported functions: `R -e 'devtools::document()'`
   - Examples in roxygen comments: tested automatically, must be ASCII-only
   - Check: All man/*.Rd, DESCRIPTION, NAMESPACE remain ASCII

3. **Vignettes:**
   - Location: vignettes/
   - Format: .Rmd (ASCII only, render to HTML)
   - Current: fitting-motifs.Rmd
   - Phase 3: Will add 3-5 new vignettes (see 03f-r-integration.md, 03l-case-studies.md)

4. **README:**
   - README.Rmd (source) -> README.md (rendered)
   - Examples in README are runnable; keep them ASCII and maintainable

Example Workflows
----------------
**Basic Workflow (Phase 2):**
```r
library(soilmotif)

# Load data
data(example_profile)  # or read your own

# Prepare
prepared <- sm_prepare(data, depths = 1:200)

# Fit single profile
fit <- sm_optim(prepared$clay, initial_params = c(100, 20), use_rust = TRUE)
print(fit)  # Parameters, RMSE, R^2, AIC
cat("Parameters:", fit$params, "\n")

# Evaluate shape at new depths
depths_new <- seq(1, 200, by = 5)
fitted_vals <- sm_motif(depths_new, fit$params)

# Auto-select best model
auto_fit <- fit_motif_auto(prepared$clay, use_rust = TRUE)
```

**Batch Workflow (Phase 2):**
```r
# Multiple profiles
profiles_df <- read.csv("soil_profiles.csv")
# Columns: site_id, depth, clay, silt, sand

fits <- batch_fit_profiles(
    profiles_df,
    id_col = "site_id",
    depth_col = "depth",
    property_col = "clay",
    initial_params = c(100, 20),
    use_rust = TRUE,
    parallel = TRUE
)

# Results: site_id | param_1 | param_2 | rmse | r2 | aic | ...
head(fits)
```

**Phase 3 Preview (Optimization Track):**
```r
# Weighted objective (03b)
fit_weighted <- sm_optim(
    clay, c(100, 20),
    objective = "weighted_rmse",
    weight_depths = 60,  # emphasize argillic horizon
    use_rust = TRUE
)

# Domain-specific loss (03b)
fit_bounded <- sm_optim(
    texture, c(50, 20),
    objective = "bounded",
    bounds = c(0, 100),  # texture constraint
    use_rust = TRUE
)

# Bootstrap uncertainty (03e)
fit_boot <- sm_optim_bootstrap(
    clay, initial_params = c(100, 20),
    n_bootstrap = 1000
)
ci_lower <- fit_boot$param_ci_lower
ci_upper <- fit_boot$param_ci_upper
```

**Phase 3 Preview (Analysis Track):**
```r
# Objective horizon delineation (03g)
multivar_data <- matrix(c(pxrf_al, pxrf_fe, pxrf_si), nrow = 200)
boundaries <- horizon_boundaries_mahalanobis(multivar_data, window_size = 5)

# Fuzzy classification (03h)
horizons <- fuzzy_kmeans_horizons(multivar_data, k = 3)

# Weathering indices (03i)
silica_al_ratio <- weathering_index_si_al(pxrf_si, pxrf_al)
ti_zr_ratio <- weathering_index_ti_zr(pxrf_ti, pxrf_zr)

# Soil development (03j)
ipa <- index_of_profile_anisotropy(
    clay_fit = clay_optimization,
    silt_fit = silt_optimization
)
```

What to Watch For When Editing
------------------------------
1. **Preserve API stability:**
   - Current exports in NAMESPACE must remain (sm_optim, sm_motif, etc.)
   - If changing argument names/order, update tests and roxygen comments
   - FFI functions (optimize_profile_rust, etc.) are STABLE; internal refactoring OK

2. **Default depth ranges (1-200):**
   - Many examples and tests assume this range
   - If you need to change defaults, also update:
     - Tests: grep -r "c(1, 200)" tests/
     - Examples in roxygen comments
     - Vignettes and README

3. **Unicode compliance:**
   - CRITICAL: Run Unicode detection before finalizing changes
   - Affects: R files, Rust docs (if adding), man/*.Rd, DESCRIPTION, NAMESPACE

4. **Rust backend changes:**
   - Internal refactoring (src/optimizer.rs, src/objective.rs) is OK
   - Do NOT change FFI exports in src/lib.rs (breaks R interface)
   - Phase 3 will ADD new modules (src/horizons.rs, etc.), not replace

5. **Documentation regeneration:**
   - After editing roxygen comments: `devtools::document()`
   - Commit separately from code changes if using version control
   - Remember: NO COMMITS from agents (user only)

6. **Test expectations:**
   - Phase 2 test baseline: 250+ passing tests (maintain 100% pass rate)
   - Phase 3 will add more tests; initial Phase 3 tests may be stubs
   - Batch tests (test-rust-batch.R) are performance-sensitive; don't break them

Common Pitfalls
---------------
1. Forgetting to run Unicode detection before finalizing edits
2. Changing default ylim (c(1, 200)) without updating all dependents
3. Modifying FFI exports in src/lib.rs (breaks R interface)
4. Not regenerating docs with devtools::document()
5. Assuming Rust modules exist before Phase 3 (only batch.rs, optimizer.rs, objective.rs, shape_functions.rs exist now)
6. Forgetting that sm_prepare() must be called before optimization for data validation

When You're Uncertain
--------------------
If a request is ambiguous or unclear, DO NOT GUESS. Instead:

1. **Ask clarifying questions** and provide options. Example:
   ```
   I see you want to add a new objective function. Should I:
   (a) Add it to src/objective.rs as a new variant (quick, limited flexibility)
   (b) Create a trait-based system in Phase 3-03b style (more flexible, requires more work)
   (c) Something else? Let me know which approach fits your vision.
   ```

2. **Outline tradeoffs:**
   - Performance impact
   - Code complexity/maintainability
   - Scope (Phase 2 vs Phase 3)
   - Breaking changes (API, FFI)

3. **Provide context:**
   - Related Phase 3 prompts (if relevant)
   - Existing patterns in codebase
   - Test coverage implications

Phase 3 Preparation Checklist
----------------------------
As you implement Phase 3, prepare for:
- [ ] Argmin integration (03a): Framework prepared; full integration deferred to Phase 3
- [ ] Domain objectives (03b): Will extend src/objective.rs; trait-based design
- [ ] Algorithm selection (03c): Will add algorithm parameter to sm_optim(); auto-selection logic
- [ ] Custom shapes (03d): Will extend src/shape_functions.rs; backward compatible
- [ ] Uncertainty (03e): Will add new R functions; bootstrap infrastructure in Rust
- [ ] R integration (03f): Will add broom methods, tidyverse helpers, Bayesian integration
- [ ] Horizon delineation (03g): Will add src/horizons.rs, R/horizons.R
- [ ] Fuzzy clustering (03h): Will add clustering functions to R/horizons.R
- [ ] Weathering indices (03i): Will add R/weathering.R
- [ ] Networks (03j): Will add R/networks.R
- [ ] Temporal/spatial (03k): Will add R/temporal.R, R/spatial.R
- [ ] Case studies (03l): Will add vignettes/, inst/extdata/

Resources
---------
- Package README: README.md (high-level overview)
- Phase 3 roadmap: .github/prompts/0.1.0/03-Phase-3-Advanced-Analysis/00-phase-3-index.md
- Detailed Phase 3 plans: 03a-03l prompts in same directory
- Optimization base: See fit.R, fit-rust-wrappers.R for R layer patterns
- Rust layer: src/optimizer.rs, src/objective.rs, src/shape_functions.rs
- Tests: tests/testthat/ (copy patterns from existing tests)
- Vignettes: vignettes/fitting-motifs.Rmd (style guide)
- argmin docs: https://docs.rs/argmin/latest/argmin/

Questions & Feedback
------------------
If anything above is unclear or needs expansion, ask which area to elaborate:
- Architecture (R vs Rust responsibilities)
- Phase 3 integration points
- Specific coding patterns
- Testing approach
- Documentation standards
- Unicode compliance
- CI/build process
