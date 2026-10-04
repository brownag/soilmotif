# soilmotif 0.1.0 (Current Development)

## Phase 3 Features (Advanced Analysis)
* **Uncertainty Quantification (Phase 3e)**:
  - Added block bootstrap for autocorrelated residuals (preserves depth-ordered structure)
  - Added parametric bootstrap for independent residuals
  - Added sieve bootstrap for AR(1) autocorrelated data
  - Full integration with Rust optimization backend
  - Bootstrap methods for all 7 shape families

* **Ecosystem Integration (Phase 3f)**:
  - Full broom methods (tidy, glance, augment) for R ecosystem compatibility
  - Enhanced ggplot2 integration with data preparation helpers
  - Bayesian workflow support with prior generation for Stan and brms
  - Complete visualization system for bootstrap results

* **Weathering Indices Analysis**:
  - Comprehensive element ratio calculations
  - Depth-integrated weathering metrics
  - Element mobility and depletion quantification
  - Weathering stage classification

* **Visualization Improvements**:
  - Base R plotting with bootstrap uncertainty bands
  - Domain-specific weathering visualization functions
  - Dual-mode visualization (base R and ggplot2)
  - Interactive horizon and fuzzy clustering plots

## Previous Release Highlights (0.1.0 Initial)

* Major release with automated model selection and data preprocessing
* Added `fit_motif_auto()` for automatic fitting and ranking of all 7 motif types
* Added `sm_prepare()` for converting horizon data to continuous profiles (step/linear/spline methods)
* Added comprehensive integration tests for end-to-end workflows
* Enhanced documentation with pedogenic interpretations for shape functions
* Added vignette "Fitting Multiple Motif Types"
* Improved parameter initialization with `.suggest_initial_params()`
* Added support for SoilProfileCollection objects via aqp package
* Enhanced error handling and validation throughout

# soilmotif 0.0.4

* Added minimax shape function
* Improved parameter clamping in shape functions
* Added comprehensive test suite

# soilmotif 0.0.3

* Added peak shape function with skewness parameter
* Enhanced optimization with better initial parameter suggestions

# soilmotif 0.0.2

* Added abrupt and exponential shape functions
* Improved documentation and examples

# soilmotif 0.0.1

* Initial package structure, added NEWS.md
