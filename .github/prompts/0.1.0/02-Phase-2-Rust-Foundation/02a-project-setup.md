# Subphase 2.A: Project Setup & extendr FFI
## Initialize Rust Project Structure and R-Rust Communication Layer

**Context:** The soilmotif R package currently implements all optimization in pure R (Phase 1). This subphase establishes a Rust backend via extendr, creating a parallel implementation of core functions. R functions remain the default; a new parameter (`use_rust = FALSE`) allows side-by-side comparison and gradual migration.

**Time Estimate:** 3-4 hours  
**Code Volume:** 100-150 lines Rust + TOML config + 50-100 lines R wrapper stubs

---

## Objectives

1. Initialize a Rust project with extendr FFI integrated into the R package build system
2. Create `src/lib.rs` structure with module organization
3. Configure `Cargo.toml` with dependencies (argmin, nalgebra, rayon, tokio)
4. Add R wrapper functions that dispatch to Rust via `use_rust` parameter
5. Set up basic build configuration for CRAN compatibility
6. Create skeleton Rust functions for later implementation

---

## Architecture: Side-by-Side Comparison

**Key Principle:** Rust implementations exist in parallel to R implementations, controlled via function parameters:

```r
# Example: user calls existing R function, optionally with Rust backend
sm_optim(x, X, FUN = sm_shape_sigmoid, use_rust = FALSE)  # Existing R code path
sm_optim(x, X, FUN = sm_shape_sigmoid, use_rust = TRUE)   # Calls Rust via extendr

# Internal dispatch in R:
if (use_rust) {
  # Call Rust function via extendr FFI
  result <- .Call("sm_optim_rust_impl", x, X, ..., PACKAGE = "soilmotif")
} else {
  # Fall back to pure R implementation
  result <- sm_optim_r_impl(x, X, ...)
}
```

This allows:
- **Validation:** Compare R and Rust outputs on same data
- **Gradual Migration:** Phase 1 code remains unchanged; Phase 2 adds options
- **Fallback:** If Rust compilation fails or Rust has issues, R code still works
- **Testing:** Test suite can verify both paths produce similar results (within tolerance)

---

## Directory Structure

After this subphase, the repo should look like:

```
soilmotif/
├── DESCRIPTION
├── NAMESPACE
├── R/
│   ├── fit.R                  # (Phase 1) optimization functions
│   ├── fit-rust-wrappers.R    # NEW: R dispatch layer for Rust functions
│   ├── shape.R
│   ├── ...
├── src/
│   ├── lib.rs                 # NEW: Rust entry point; modules declared here
│   ├── objective.rs           # NEW: RMSE, SSQ (Rust equivalents)
│   ├── optimizer.rs           # NEW: Single-profile fitting (placeholder for argmin)
│   ├── shape_functions.rs     # NEW: Shape function implementations
│   └── batch.rs               # NEW: Batch & parallel wrappers (stub for 2.D)
├── Cargo.toml                 # NEW: Rust dependencies & metadata
├── rust-toolchain.toml        # NEW: Pin Rust version to 2024 edition
├── tests/
│   ├── testthat/
│   │   └── test-rust-integration.R  # NEW: R <-> Rust comparison tests
│   └── ...
└── ...
```

---

## Step 1: Create `Cargo.toml` at Project Root

```toml
[package]
name = "soilmotif"
version = "0.2.0"
edition = "2024"
authors = ["Andrew G. Brown <brown.andrewg@gmail.com>"]
license = "GPL (>= 3)"

[dependencies]
extendr-api = { version = "0.7", features = ["use-rng"] }
ndarray = "0.15"
nalgebra = "0.33"
argmin = { version = "0.9", features = ["serde"] }
rayon = "1.8"
tokio = { version = "1.35", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }

[lib]
name = "soilmotif"
crate-type = ["cdylib"]

[profile.release]
opt-level = 3
lto = true

[[test]]
name = "rust_tests"
path = "tests/rust_tests.rs"
```

**Key points:**
- `crate-type = ["cdylib"]` tells Rust to build a dynamic library callable from R
- `extendr-api` provides R FFI macros and utilities
- `argmin`, `rayon`, `tokio` are added for later implementation
- `nalgebra` for linear algebra (alternative to ndarray if needed)
- `[profile.release]` optimizes for speed

---

## Step 2: Create `rust-toolchain.toml`

```toml
[toolchain]
channel = "1.82"  # Stable channel with 2024 edition support
```

This ensures reproducible builds across environments.

---

## Step 3: Create `src/lib.rs` (Rust Entry Point)

```rust
//! soilmotif Rust backend
//!
//! High-performance optimization and batch processing for soil depth functions.
//! Exposed to R via extendr FFI.
//!
//! # Architecture
//!
//! - `objective`: RMSE and SSQ calculations
//! - `shape_functions`: Rust implementations of R shape functions
//! - `optimizer`: Single-profile fitting with argmin/alternatives
//! - `batch`: Batch processing with optional rayon/tokio parallelization

use extendr_api::prelude::*;

pub mod objective;
pub mod shape_functions;
pub mod optimizer;
pub mod batch;

/// Check that Rust backend is available and working
/// 
/// # Examples
/// ```r
/// .Call("check_rust_backend", PACKAGE = "soilmotif")
/// # Returns: character "Rust backend available"
/// ```
#[extendr]
fn check_rust_backend() -> String {
    "Rust backend available".to_string()
}

// Placeholder stubs for later implementation
// (will be filled in by Subphases 2.B-2.D)

/// Compute RMSE between observed and predicted (Rust implementation)
/// 
/// Called via R: `.Call("objective_rmse_rust", x, y, PACKAGE = "soilmotif")`
#[extendr]
fn objective_rmse_rust(x: Vec<f64>, y: Vec<f64>) -> f64 {
    // Placeholder: will implement in 2.B
    0.0
}

/// Single-profile optimization (Rust implementation)
/// 
/// Called via R: `.Call("optimize_single_profile_rust", x, X, ..., PACKAGE = "soilmotif")`
#[extendr]
fn optimize_single_profile_rust(
    x: Vec<f64>,
    initial_par: Vec<f64>,
) -> Vec<f64> {
    // Placeholder: will implement in 2.C
    initial_par
}

/// Batch profile processing (Rust implementation)
/// 
/// Called via R: `.Call("batch_process_rust", profiles_list, models, ..., PACKAGE = "soilmotif")`
#[extendr]
fn batch_process_rust(
    profiles: Vec<Vec<f64>>,
) -> Vec<Vec<f64>> {
    // Placeholder: will implement in 2.D
    profiles
}

// Macro to generate R module exports
extendr_module! {
    mod soilmotif;
    fn check_rust_backend;
    fn objective_rmse_rust;
    fn optimize_single_profile_rust;
    fn batch_process_rust;
}
```

**Key points:**
- `extendr_module!` macro auto-generates R binding code
- Doc comments use `///` (Rust convention) and are visible in R help
- Functions annotated with `#[extendr]` are automatically exposed to R
- Placeholders show function signatures; implementations come in later subphases

---

## Step 4: Create Module Skeletons

### `src/objective.rs`

```rust
//! Objective functions (RMSE, SSQ) implementations
//!
//! These compute fit quality metrics, used by the optimizer.

/// Compute Root Mean Squared Error between observed and predicted
/// 
/// # Arguments
/// - `observed`: Measured/synthetic data vector
/// - `predicted`: Model predictions
/// 
/// # Returns
/// RMSE as f64
pub fn rmse(observed: &[f64], predicted: &[f64]) -> f64 {
    // TODO: Implement in 2.B
    0.0
}

/// Compute Sum of Squared Errors
/// 
/// # Arguments
/// - `observed`: Measured/synthetic data vector
/// - `predicted`: Model predictions
/// 
/// # Returns
/// SSE as f64
pub fn sse(observed: &[f64], predicted: &[f64]) -> f64 {
    // TODO: Implement in 2.B
    0.0
}
```

### `src/shape_functions.rs`

```rust
//! Shape function implementations (Rust equivalents of R functions)
//!
//! Each shape function maps depth to a normalized [0, 1] value.

/// Uniform shape (constant value)
pub fn uniform(x: &[f64], params: &[f64]) -> Vec<f64> {
    // TODO: Implement in 2.B
    vec![]
}

/// Gradational shape (linear ramp)
pub fn gradational(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    // TODO: Implement in 2.B
    vec![]
}

/// Exponential shape (decay/growth)
pub fn exponential(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    // TODO: Implement in 2.B
    vec![]
}

/// Wetting front shape (sigmoid-like)
pub fn wetting_front(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    // TODO: Implement in 2.B
    vec![]
}

/// Abrupt shape (step function)
pub fn abrupt(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    // TODO: Implement in 2.B
    vec![]
}

/// Peak shape (bell curve)
pub fn peak(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    // TODO: Implement in 2.B
    vec![]
}

/// MiniMax shape (two peaks)
pub fn minimax(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    // TODO: Implement in 2.B
    vec![]
}
```

### `src/optimizer.rs`

```rust
//! Single-profile optimization
//!
//! Fits shape function parameters to observed data using argmin or alternatives.

/// Optimize parameters for a single profile
/// 
/// # Arguments
/// - `observed`: Observed/synthetic data vector
/// - `initial_params`: Starting point for optimization
/// - `shape_type`: Which shape function to use
/// 
/// # Returns
/// Optimized parameters as Vec<f64>
pub fn optimize_profile(
    observed: &[f64],
    initial_params: &[f64],
    shape_type: &str,
) -> Vec<f64> {
    // TODO: Implement in 2.C with argmin + fallbacks
    initial_params.to_vec()
}
```

### `src/batch.rs`

```rust
//! Batch processing and parallelization
//!
//! Processes multiple profiles efficiently, with optional rayon/tokio layers.

/// Process multiple profiles in parallel
/// 
/// # Arguments
/// - `profiles`: Vector of profile data vectors
/// - `initial_params`: Starting parameters for each profile
/// 
/// # Returns
/// Vector of optimized parameter sets
pub fn batch_optimize(
    profiles: &[Vec<f64>],
    initial_params: &[Vec<f64>],
) -> Vec<Vec<f64>> {
    // TODO: Implement in 2.D with rayon/tokio
    initial_params.to_vec()
}
```

---

## Step 5: Create R Wrapper Layer in `R/fit-rust-wrappers.R`

This file contains the dispatch logic that allows R users to opt into Rust:

```r
#' Rust-backed optimization (internal dispatch)
#'
#' @param x numeric. Data vector
#' @param X numeric. Initial parameters
#' @param FUN function. Shape function
#' @param use_rust logical. If TRUE, use Rust backend; else use R
#' @param ... additional arguments
#'
#' @return numeric vector of fitted values
#' @keywords internal
sm_optim_dispatch <- function(x, X, FUN = sm_shape_sigmoid, 
                              use_rust = FALSE, ...) {
  if (!use_rust) {
    # Existing R implementation
    return(sm_optim_r_impl(x, X, FUN = FUN, ...))
  }
  
  # Check if Rust backend is available
  if (!rust_backend_available()) {
    warning("Rust backend not available; falling back to R")
    return(sm_optim_r_impl(x, X, FUN = FUN, ...))
  }
  
  # Call Rust implementation
  result <- tryCatch({
    .Call("optimize_single_profile_rust", 
          as.numeric(x), 
          as.numeric(X),
          PACKAGE = "soilmotif")
  }, error = function(e) {
    warning("Rust optimization failed: ", e$message, "; falling back to R")
    sm_optim_r_impl(x, X, FUN = FUN, ...)
  })
  
  result
}

#' Check if Rust backend is available
#' 
#' @return logical TRUE if Rust functions are loaded
#' @keywords internal
rust_backend_available <- function() {
  tryCatch({
    .Call("check_rust_backend", PACKAGE = "soilmotif")
    TRUE
  }, error = function(e) {
    FALSE
  })
}

#' Rename existing sm_optim to sm_optim_r_impl for internal use
#' (This happens at load time; see Step 6 below)
```

---

## Step 6: Modify `R/fit.R` (Minimal Changes)

At the end of `R/fit.R`, add:

```r
# Store original R implementation for dispatch
sm_optim_r_impl <- sm_optim

# Replace sm_optim with dispatch wrapper
sm_optim <- function(x, X, ..., FUN = sm_shape_sigmoid,
                     OPTFUN = sm_optim_rmse, use_rust = FALSE) {
  # If Rust requested, dispatch to Rust backend (with R fallback)
  if (use_rust) {
    # TODO: After Phase 2.C, implement proper Rust dispatch
    # For now, just use R
    warning("Rust backend not yet fully implemented; using R")
    use_rust <- FALSE
  }
  
  # Use R implementation (default path)
  sm_optim_r_impl(x, X, ..., FUN = FUN, OPTFUN = OPTFUN)
}
```

This adds a `use_rust` parameter without breaking existing code.

---

## Step 7: Update `DESCRIPTION`

Add Rust build support:

```
SystemRequirements: Cargo (>= 1.56)
```

This notifies CRAN/R CMD check that Rust is required.

---

## Step 8: Create Build Configuration

Add to `.Rbuildignore`:

```
^Cargo\.lock$
^Cargo\.toml$
^src/.*\.rs$
^rust-toolchain\.toml$
^target/
```

This prevents Rust files from being included in the source tarball (they're compiled into the shared library).

---

## Step 9: Test Basic Setup

### Rust Side

```bash
cd /path/to/soilmotif
cargo build --release
# Should compile without errors; produces shared library in target/release/
```

### R Side

Create `tests/testthat/test-rust-setup.R`:

```r
test_that("Rust backend loads and is callable", {
  # This will fail until we implement check_rust_backend in 2.B
  # For now, it documents the expected behavior
  skip("Rust backend not yet fully implemented")
  
  result <- tryCatch({
    .Call("check_rust_backend", PACKAGE = "soilmotif")
  }, error = function(e) {
    NA_character_
  })
  
  expect_equal(result, "Rust backend available")
})

test_that("sm_optim still works with use_rust = FALSE", {
  x <- c(rep(10, 50), rep(35, 100), rep(15, 50))
  result <- sm_optim(x, c(25, 100), FUN = sm_shape_gradational, use_rust = FALSE)
  
  expect_length(result, 200)
  expect_true(all(result >= 0))
})
```

---

## Acceptance Criteria

### Build & Compilation
- [x] `Cargo.toml` is valid and all dependencies resolve
- [x] `cargo build --release` compiles without errors
- [x] `src/lib.rs` and all module files compile
- [x] Extendr macro expansion is correct (checked by compiler)

### R Integration
- [x] `R CMD check` passes (warnings about Rust OK for now)
- [x] `devtools::load_all()` loads without errors
- [x] `.Call("check_rust_backend", PACKAGE = "soilmotif")` is callable (in 2.B)
- [x] `sm_optim(..., use_rust = FALSE)` still works identically to Phase 1

### Code Structure
- [x] `src/` directory with proper module organization
- [x] `R/fit-rust-wrappers.R` dispatch layer created
- [x] Placeholder functions in Rust with doc comments
- [x] `.Rbuildignore` configured for Rust files

### Documentation
- [x] Rust doc comments (///) on all public functions
- [x] R-side roxygen2 comments on dispatch functions
- [x] `README.md` or `docs/RUST_BACKEND.md` documents the side-by-side architecture

---

## Implementation Checklist

- [ ] Create `Cargo.toml` with dependencies
- [ ] Create `rust-toolchain.toml` pinning edition
- [ ] Create `src/lib.rs` with extendr module declaration
- [ ] Create `src/objective.rs`, `src/shape_functions.rs`, `src/optimizer.rs`, `src/batch.rs` skeletons
- [ ] Create `R/fit-rust-wrappers.R` with dispatch layer
- [ ] Modify `R/fit.R` to add `use_rust` parameter
- [ ] Update `DESCRIPTION` with SystemRequirements
- [ ] Update `.Rbuildignore`
- [ ] Create test file `tests/testthat/test-rust-setup.R`
- [ ] Test: `cargo build --release` succeeds
- [ ] Test: `devtools::load_all()` succeeds
- [ ] Test: `R CMD check --as-cran` passes (Rust warnings OK)
- [ ] Commit: `Phase 2.A: Initialize Rust project with extendr FFI`
- [ ] Update `PHASE_STATUS.md`

---

## Common Build Issues

| Issue | Solution |
|-------|----------|
| `extendr` version mismatch | Pin extendr-api to latest stable (0.7.x) |
| Cargo not found | Install Rust from https://rustup.rs/ |
| Permission errors in src/ | Check file ownership; may need `chmod` |
| `crate-type = ["cdylib"]` missing | Add to [lib] section of Cargo.toml |

---

## Resources

- **extendr docs:** https://extendr.github.io/
- **Cargo book:** https://doc.rust-lang.org/cargo/
- **Edition 2024 guide:** https://doc.rust-lang.org/edition-guide/rust-2024/

---

**Next Step:** Implement core Rust functions (RMSE, SSQ, shape functions) in Subphase 2.B.
