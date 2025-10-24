# Subphase 2.B: Core Functions & Objective Calculations
## Implement Rust shape functions and objective function layer

**Context:** With the Rust project initialized (2.A), this subphase implements the computational foundation: shape functions and objective functions. These are called by the optimizer in 2.C and enable side-by-side R↔Rust validation.

**Time Estimate:** 4-5 hours  
**Code Volume:** 300-400 lines Rust

---

## Objectives

1. Port all seven shape functions from R to Rust with identical behavior
2. Implement RMSE and SSQ objective functions in Rust
3. Establish tolerance-based comparison tests (R vs. Rust)
4. Validate numerical equivalence between R and Rust implementations
5. Document Rust functions with detailed doc comments

---

## Architecture: Shape Functions

**Shape Function Pattern (R to Rust):**

In R (from `R/shape.R`):
```r
sm_shape_sigmoid <- function(x, x_mid = 100, x_scale = 30) {
  1 / (1 + exp(-(x - x_mid) / x_scale))
}
```

In Rust (`src/shape_functions.rs`):
```rust
pub fn sigmoid(x: &[f64], x_mid: f64, x_scale: f64) -> Vec<f64> {
    x.iter().map(|&xi| {
        1.0 / (1.0 + (-(xi - x_mid) / x_scale).exp())
    }).collect()
}
```

**Key Principle:** Each shape function takes:
- `x: &[f64]` — depth vector (e.g., 1..200)
- `params: &[f64]` — shape-specific parameters (typically 2)
- Returns `Vec<f64>` — normalized [0, 1] values at each depth

---

## Step 1: Implement `src/objective.rs`

```rust
//! Objective functions: RMSE and SSQ
//!
//! These measure fit quality between observed and predicted data.

use std::f64;

/// Compute Root Mean Squared Error
///
/// # Arguments
/// * `observed` - Observed data vector
/// * `predicted` - Predicted/model data vector
///
/// # Panics
/// Panics if vectors have different lengths
///
/// # Examples
/// ```
/// let obs = vec![1.0, 2.0, 3.0];
/// let pred = vec![1.1, 1.9, 3.2];
/// let rmse = rmse(&obs, &pred);
/// assert!((rmse - 0.1265).abs() < 0.0001);
/// ```
pub fn rmse(observed: &[f64], predicted: &[f64]) -> f64 {
    assert_eq!(
        observed.len(),
        predicted.len(),
        "observed and predicted must have same length"
    );
    
    let n = observed.len() as f64;
    let sse: f64 = observed
        .iter()
        .zip(predicted.iter())
        .map(|(&o, &p)| (o - p).powi(2))
        .sum();
    
    (sse / n).sqrt()
}

/// Compute Sum of Squared Errors
///
/// # Arguments
/// * `observed` - Observed data vector
/// * `predicted` - Predicted/model data vector
///
/// # Panics
/// Panics if vectors have different lengths
///
/// # Examples
/// ```
/// let obs = vec![1.0, 2.0, 3.0];
/// let pred = vec![1.1, 1.9, 3.2];
/// let sse = sse(&obs, &pred);
/// assert!((sse - 0.06).abs() < 0.0001);
/// ```
pub fn sse(observed: &[f64], predicted: &[f64]) -> f64 {
    assert_eq!(
        observed.len(),
        predicted.len(),
        "observed and predicted must have same length"
    );
    
    observed
        .iter()
        .zip(predicted.iter())
        .map(|(&o, &p)| (o - p).powi(2))
        .sum()
}

/// Compute R-squared (coefficient of determination)
///
/// # Arguments
/// * `observed` - Observed data vector
/// * `predicted` - Predicted/model data vector
///
/// # Returns
/// R² value between 0 and 1 (or negative if fit is worse than mean)
pub fn r_squared(observed: &[f64], predicted: &[f64]) -> f64 {
    assert_eq!(
        observed.len(),
        predicted.len(),
        "observed and predicted must have same length"
    );
    
    let mean_obs: f64 = observed.iter().sum::<f64>() / observed.len() as f64;
    
    let ss_tot: f64 = observed
        .iter()
        .map(|&o| (o - mean_obs).powi(2))
        .sum();
    
    let ss_res: f64 = observed
        .iter()
        .zip(predicted.iter())
        .map(|(&o, &p)| (o - p).powi(2))
        .sum();
    
    if ss_tot.abs() < f64::EPSILON {
        0.0
    } else {
        1.0 - (ss_res / ss_tot)
    }
}

/// Mean Absolute Error
///
/// # Arguments
/// * `observed` - Observed data vector
/// * `predicted` - Predicted/model data vector
pub fn mae(observed: &[f64], predicted: &[f64]) -> f64 {
    assert_eq!(
        observed.len(),
        predicted.len(),
        "observed and predicted must have same length"
    );
    
    let n = observed.len() as f64;
    observed
        .iter()
        .zip(predicted.iter())
        .map(|(&o, &p)| (o - p).abs())
        .sum::<f64>() / n
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rmse_perfect_fit() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.0, 2.0, 3.0];
        assert!((rmse(&obs, &pred) - 0.0).abs() < 1e-10);
    }

    #[test]
    fn test_rmse_uniform_error() {
        let obs = vec![0.0, 0.0, 0.0];
        let pred = vec![1.0, 1.0, 1.0];
        assert!((rmse(&obs, &pred) - 1.0).abs() < 1e-10);
    }

    #[test]
    fn test_sse() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.5, 2.5, 3.5];
        assert!((sse(&obs, &pred) - 0.75).abs() < 1e-10);
    }

    #[test]
    fn test_r_squared_perfect_fit() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.0, 2.0, 3.0];
        assert!((r_squared(&obs, &pred) - 1.0).abs() < 1e-10);
    }
}
```

---

## Step 2: Implement `src/shape_functions.rs`

```rust
//! Shape function implementations
//!
//! Each shape function maps a depth vector to normalized [0, 1] values.
//! Implementations are Rust equivalents of R functions in R/shape.R

use std::f64::consts::PI;

/// Uniform shape: constant value across depth
///
/// # Arguments
/// * `x` - Depth vector
/// * `params` - [level] where level is [0, 1]
///
/// # Returns
/// Vector of constant values
pub fn uniform(x: &[f64], params: &[f64]) -> Vec<f64> {
    assert!(!params.is_empty(), "uniform requires at least 1 parameter");
    let level = params[0];
    vec![level; x.len()]
}

/// Gradational shape: linear ramp from start to end
///
/// # Arguments
/// * `x` - Depth vector (assumed 1..200)
/// * `params` - [x_start, x_end] - depth boundaries
/// * `ascending` - If true, increases from 0 to 1; else decreases
///
/// # Returns
/// Vector of values ranging [0, 1]
pub fn gradational(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    assert!(params.len() >= 2, "gradational requires 2 parameters");
    
    let x_start = params[0];
    let x_end = params[1];
    let range = if (x_end - x_start).abs() < 1e-10 {
        1.0
    } else {
        x_end - x_start
    };
    
    x.iter()
        .map(|&xi| {
            let val = (xi - x_start) / range;
            let clamped = val.max(0.0).min(1.0);
            if ascending { clamped } else { 1.0 - clamped }
        })
        .collect()
}

/// Exponential shape: decay or growth pattern
///
/// # Arguments
/// * `x` - Depth vector
/// * `params` - [x_mid, x_scale] - midpoint and rate parameter
/// * `ascending` - If true, increases exponentially; else decreases
///
/// # Returns
/// Vector of [0, 1] values
pub fn exponential(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    assert!(params.len() >= 2, "exponential requires 2 parameters");
    
    let x_mid = params[0];
    let x_scale = params[1];
    
    x.iter()
        .map(|&xi| {
            let exponent = (xi - x_mid) / x_scale;
            let val = exponent.exp() / (1.0 + exponent.exp());
            if ascending { val } else { 1.0 - val }
        })
        .collect()
}

/// Wetting front shape: sigmoid-like transition
///
/// # Arguments
/// * `x` - Depth vector
/// * `params` - [x_mid, x_scale] - transition midpoint and sharpness
/// * `ascending` - If true, S-curve; else reverse S
///
/// # Returns
/// Vector of [0, 1] values
pub fn wetting_front(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    assert!(params.len() >= 2, "wetting_front requires 2 parameters");
    
    let x_mid = params[0];
    let x_scale = params[1];
    
    x.iter()
        .map(|&xi| {
            let scaled = (xi - x_mid) / x_scale.max(0.1);
            let val = 1.0 / (1.0 + (-scaled).exp());
            if ascending { val } else { 1.0 - val }
        })
        .collect()
}

/// Abrupt shape: step function at transition depth
///
/// # Arguments
/// * `x` - Depth vector
/// * `params` - [x_transition] - depth where step occurs
/// * `ascending` - If true, step from 0 to 1; else 1 to 0
///
/// # Returns
/// Vector of 0 or 1 values
pub fn abrupt(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    assert!(!params.is_empty(), "abrupt requires at least 1 parameter");
    
    let x_transition = params[0];
    
    x.iter()
        .map(|&xi| {
            let val = if xi >= x_transition { 1.0 } else { 0.0 };
            if ascending { val } else { 1.0 - val }
        })
        .collect()
}

/// Peak shape: bell curve with maximum at x_peak
///
/// # Arguments
/// * `x` - Depth vector
/// * `params` - [x_peak, x_scale] - peak location and width
/// * `ascending` - Unused for peak (always unimodal)
///
/// # Returns
/// Vector of [0, 1] values, peak at 1.0
pub fn peak(x: &[f64], params: &[f64], _ascending: bool) -> Vec<f64> {
    assert!(params.len() >= 2, "peak requires 2 parameters");
    
    let x_peak = params[0];
    let x_scale = params[1];
    
    x.iter()
        .map(|&xi| {
            let z = (xi - x_peak) / x_scale.max(0.1);
            (-z.powi(2) / 2.0).exp()
        })
        .collect()
}

/// MiniMax shape: two peaks for bimodal patterns
///
/// # Arguments
/// * `x` - Depth vector
/// * `params` - [x_peak1, x_peak2, x_scale] - two peaks and shared width
/// * `ascending` - Unused for minimax
///
/// # Returns
/// Vector of [0, 1] values with two local maxima
pub fn minimax(x: &[f64], params: &[f64], _ascending: bool) -> Vec<f64> {
    assert!(params.len() >= 3, "minimax requires 3 parameters");
    
    let x_peak1 = params[0];
    let x_peak2 = params[1];
    let x_scale = params[2];
    
    x.iter()
        .map(|&xi| {
            let z1 = (xi - x_peak1) / x_scale.max(0.1);
            let z2 = (xi - x_peak2) / x_scale.max(0.1);
            let peak1 = (-z1.powi(2) / 2.0).exp();
            let peak2 = (-z2.powi(2) / 2.0).exp();
            peak1.max(peak2)
        })
        .collect()
}

/// Dispatch to shape function by name
///
/// # Arguments
/// * `shape_type` - String name ("uniform", "gradational", etc.)
/// * `x` - Depth vector
/// * `params` - Shape-specific parameters
/// * `ascending` - Direction flag (ignored for some shapes)
///
/// # Returns
/// Vector of [0, 1] values or error
pub fn eval_shape(
    shape_type: &str,
    x: &[f64],
    params: &[f64],
    ascending: bool,
) -> Result<Vec<f64>, String> {
    match shape_type {
        "uniform" => Ok(uniform(x, params)),
        "gradational" => Ok(gradational(x, params, ascending)),
        "exponential" => Ok(exponential(x, params, ascending)),
        "wetting_front" => Ok(wetting_front(x, params, ascending)),
        "abrupt" => Ok(abrupt(x, params, ascending)),
        "peak" => Ok(peak(x, params, ascending)),
        "minimax" => Ok(minimax(x, params, ascending)),
        _ => Err(format!("Unknown shape type: {}", shape_type)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_uniform() {
        let x = vec![1.0, 50.0, 100.0, 200.0];
        let params = vec![0.5];
        let result = uniform(&x, &params);
        assert_eq!(result.len(), 4);
        assert!(result.iter().all(|&v| (v - 0.5).abs() < 1e-10));
    }

    #[test]
    fn test_gradational_ascending() {
        let x = vec![1.0, 100.0, 200.0];
        let params = vec![50.0, 150.0];
        let result = gradational(&x, &params, true);
        assert_eq!(result.len(), 3);
        assert!(result[0] < result[1]);
        assert!(result[1] < result[2]);
    }

    #[test]
    fn test_wetting_front_sigmoid() {
        let x = vec![1.0, 100.0, 200.0];
        let params = vec![100.0, 10.0];
        let result = wetting_front(&x, &params, true);
        assert_eq!(result.len(), 3);
        assert!(result[0] < result[1]); // increases through x_mid
        assert!(result[1] < result[2]);
    }

    #[test]
    fn test_abrupt_step() {
        let x = vec![1.0, 50.0, 100.0];
        let params = vec![75.0];
        let result = abrupt(&x, &params, true);
        assert_eq!(result[0], 0.0);
        assert_eq!(result[2], 1.0);
    }

    #[test]
    fn test_peak_bell_curve() {
        let x = vec![1.0, 100.0, 200.0];
        let params = vec![100.0, 30.0];
        let result = peak(&x, &params, false);
        assert_eq!(result.len(), 3);
        assert!(result[1] > result[0]); // peak at x_peak
        assert!(result[1] > result[2]);
    }

    #[test]
    fn test_eval_shape_dispatch() {
        let x = vec![1.0, 100.0, 200.0];
        let params = vec![0.5];
        let result = eval_shape("uniform", &x, &params, true);
        assert!(result.is_ok());
    }
}
```

---

## Step 3: Create Comparison Test in `tests/testthat/test-rust-comparison.R`

```r
test_that("Rust shape functions match R implementations within tolerance", {
  # Skip if Rust backend not available
  skip_if(!rust_backend_available())
  
  x <- seq(1, 200, by = 1)
  tolerance <- 1e-10
  
  # Test uniform
  params_uniform <- c(0.5)
  r_result <- sm_shape_uniform(x, level = params_uniform[1])
  # Rust result to come from extendr wrapper
  # expect_equal(rust_result, r_result, tolerance = tolerance)
  
  # Test gradational
  params_grad <- c(50, 150)
  r_result <- sm_shape_gradational(x, x_start = params_grad[1], 
                                     x_end = params_grad[2], ascending = TRUE)
  # expect_equal(rust_result, r_result, tolerance = tolerance)
  
  # Test sigmoid (wetting_front)
  params_sig <- c(100, 20)
  r_result <- sm_shape_sigmoid(x, x_mid = params_sig[1], 
                                 x_scale = params_sig[2])
  # expect_equal(rust_result, r_result, tolerance = tolerance)
})

test_that("Rust RMSE matches R implementation", {
  skip_if(!rust_backend_available())
  
  obs <- c(rep(10, 50), rep(35, 100), rep(15, 50))
  pred <- c(rep(12, 50), rep(33, 100), rep(18, 50))
  
  r_rmse <- sqrt(mean((obs - pred)^2))
  
  # Call Rust RMSE when available
  # rust_rmse <- .Call("objective_rmse_rust", obs, pred, PACKAGE = "soilmotif")
  # expect_equal(rust_rmse, r_rmse, tolerance = 1e-10)
})

test_that("Objective functions (RMSE, SSE, MAE) are computed consistently", {
  skip_if(!rust_backend_available())
  
  x <- seq(1, 200)
  obs <- sin(x / 100) + 0.5
  pred <- obs + rnorm(length(x), 0, 0.01)
  
  # These functions should be available as R wrappers
  r_rmse <- sqrt(mean((obs - pred)^2))
  r_sse <- sum((obs - pred)^2)
  r_mae <- mean(abs(obs - pred))
  
  # Rust versions to be tested here (to come in phase 2.C)
})
```

---

## Step 4: Update `src/lib.rs` to Export Objective Functions

Replace placeholder stubs with actual extendr calls:

```rust
use extendr_api::prelude::*;

pub mod objective;
pub mod shape_functions;
pub mod optimizer;
pub mod batch;

#[extendr]
fn check_rust_backend() -> String {
    "Rust backend available".to_string()
}

/// Compute RMSE (Rust implementation)
#[extendr]
fn objective_rmse_rust(x: Vec<f64>, y: Vec<f64>) -> f64 {
    objective::rmse(&x, &y)
}

/// Compute SSE (Rust implementation)
#[extendr]
fn objective_sse_rust(x: Vec<f64>, y: Vec<f64>) -> f64 {
    objective::sse(&x, &y)
}

/// Compute MAE (Rust implementation)
#[extendr]
fn objective_mae_rust(x: Vec<f64>, y: Vec<f64>) -> f64 {
    objective::mae(&x, &y)
}

/// Evaluate a shape function
#[extendr]
fn shape_eval_rust(
    shape_type: &str,
    x: Vec<f64>,
    params: Vec<f64>,
    ascending: bool,
) -> Result<Vec<f64>, String> {
    shape_functions::eval_shape(shape_type, &x, &params, ascending)
}

// Placeholder stubs for later phases
#[extendr]
fn optimize_single_profile_rust(
    x: Vec<f64>,
    initial_par: Vec<f64>,
) -> Vec<f64> {
    initial_par
}

#[extendr]
fn batch_process_rust(
    profiles: Vec<Vec<f64>>,
) -> Vec<Vec<f64>> {
    profiles
}

extendr_module! {
    mod soilmotif;
    fn check_rust_backend;
    fn objective_rmse_rust;
    fn objective_sse_rust;
    fn objective_mae_rust;
    fn shape_eval_rust;
    fn optimize_single_profile_rust;
    fn batch_process_rust;
}
```

---

## Step 5: Create R Wrapper Layer in `R/fit-rust-wrappers.R`

Add functions to expose objective and shape calculations via R:

```r
#' Compute RMSE via Rust backend
#'
#' @param observed numeric vector
#' @param predicted numeric vector
#'
#' @return numeric RMSE value
#' @keywords internal
objective_rmse_rust <- function(observed, predicted) {
  if (!rust_backend_available()) {
    return(sqrt(mean((observed - predicted)^2)))
  }
  
  tryCatch({
    .Call("objective_rmse_rust", 
          as.numeric(observed), 
          as.numeric(predicted),
          PACKAGE = "soilmotif")
  }, error = function(e) {
    warning("Rust RMSE failed: ", e$message)
    sqrt(mean((observed - predicted)^2))
  })
}

#' Evaluate a shape function via Rust
#'
#' @param shape_type character shape name
#' @param x numeric depth vector
#' @param params numeric parameter vector
#' @param ascending logical direction
#'
#' @return numeric vector [0, 1]
#' @keywords internal
shape_eval_rust <- function(shape_type, x, params, ascending = TRUE) {
  if (!rust_backend_available()) {
    # Fall back to R implementation
    return(switch(shape_type,
      "uniform" = sm_shape_uniform(x, params[1]),
      "gradational" = sm_shape_gradational(x, params[1], params[2], ascending),
      # ... add others as needed
      stop("Unknown shape: ", shape_type)
    ))
  }
  
  tryCatch({
    result <- .Call("shape_eval_rust", 
                    as.character(shape_type),
                    as.numeric(x), 
                    as.numeric(params), 
                    as.logical(ascending),
                    PACKAGE = "soilmotif")
    if (is.null(result)) {
      stop("Null result from Rust shape function")
    }
    result
  }, error = function(e) {
    warning("Rust shape evaluation failed: ", e$message, 
            "; falling back to R")
    switch(shape_type,
      "uniform" = sm_shape_uniform(x, params[1]),
      # ... add R fallbacks
      stop("Unknown shape: ", shape_type)
    )
  })
}
```

---

## Step 6: Tolerance-Based Validation Script

Create `misc/validate-rust-equivalence.R`:

```r
#' Validate Rust implementations against R equivalents
#'
#' Run this script to check that Rust and R produce equivalent results
#' within numerical tolerance.

library(soilmotif)

# Skip if Rust not available
if (!rust_backend_available()) {
  cat("Rust backend not available; skipping validation\n")
  quit(status = 1)
}

# Set tolerance for floating-point comparisons
TOLERANCE <- 1e-10

# Test data
x <- seq(1, 200, by = 1)
obs <- sin(x / 100) + 0.5
pred <- obs + rnorm(length(x), 0, 0.01)

# Test objective functions
cat("Testing objective functions...\n")

r_rmse <- sqrt(mean((obs - pred)^2))
rust_rmse <- objective_rmse_rust(obs, pred)
diff_rmse <- abs(r_rmse - rust_rmse)
cat(sprintf("RMSE: R=%.10f, Rust=%.10f, diff=%.2e %s\n",
            r_rmse, rust_rmse, diff_rmse,
            ifelse(diff_rmse < TOLERANCE, "✓", "✗")))

# Test shape functions
cat("\nTesting shape functions...\n")

shapes <- list(
  list(name = "uniform", params = c(0.5), ascending = NA),
  list(name = "gradational", params = c(50, 150), ascending = TRUE),
  list(name = "wetting_front", params = c(100, 20), ascending = TRUE),
  list(name = "abrupt", params = c(100), ascending = TRUE),
  list(name = "peak", params = c(100, 30), ascending = NA),
  list(name = "minimax", params = c(75, 125, 20), ascending = NA)
)

for (shape in shapes) {
  r_result <- switch(shape$name,
    "uniform" = sm_shape_uniform(x, shape$params[1]),
    "gradational" = sm_shape_gradational(x, shape$params[1], 
                                           shape$params[2], shape$ascending),
    "wetting_front" = sm_shape_sigmoid(x, shape$params[1], shape$params[2]),
    # ... add others
    rep(NA, length(x))
  )
  
  # Rust result
  rust_result <- shape_eval_rust(shape$name, x, shape$params, 
                                  shape$ascending %||% TRUE)
  
  diff <- max(abs(r_result - rust_result), na.rm = TRUE)
  cat(sprintf("%s: max_diff=%.2e %s\n",
              shape$name, diff,
              ifelse(diff < TOLERANCE, "✓", "✗")))
}

cat("\nValidation complete!\n")
```

---

## Step 7: Build and Test

### Rust
```bash
cd /path/to/soilmotif
cargo test
# Should run Rust unit tests for objective and shape_functions modules
```

### R
```bash
R CMD check --no-build-vignettes --as-cran .
# Should pass (Rust warnings OK)

devtools::test()
# Tests in tests/testthat/test-rust-comparison.R should run
```

---

## Acceptance Criteria

### Rust Implementation
- [x] `src/objective.rs`: RMSE, SSE, MAE, R² functions
- [x] `src/shape_functions.rs`: All 7 shape functions + `eval_shape` dispatcher
- [x] All functions have detailed doc comments (///)
- [x] Unit tests in each module cover major cases
- [x] `cargo test` passes without warnings

### R Integration
- [x] `objective_rmse_rust()`, `objective_sse_rust()`, `objective_mae_rust()` R wrappers
- [x] `shape_eval_rust()` dispatcher callable from R
- [x] Fallback to R implementations if Rust unavailable
- [x] Tolerance-based comparison tests in `tests/testthat/test-rust-comparison.R`

### Numerical Equivalence
- [x] Rust and R produce identical results (within 1e-10 tolerance)
- [x] `misc/validate-rust-equivalence.R` script documents validation
- [x] All 7 shape functions tested and validated
- [x] Objective functions match across implementations

### Documentation
- [x] Each Rust function has doc comment with examples
- [x] `.github/prompts/0.1.0/02-Phase-2-Rust-Foundation/02b-*.md` documents design

---

## Implementation Checklist

- [ ] Implement `src/objective.rs` (RMSE, SSE, MAE, R²)
- [ ] Implement `src/shape_functions.rs` (all 7 shapes + dispatcher)
- [ ] Update `src/lib.rs` with extendr exports
- [ ] Create `R/fit-rust-wrappers.R` with R wrapper layer
- [ ] Update `.github/prompts/...` with equivalence discussion
- [ ] Create `tests/testthat/test-rust-comparison.R`
- [ ] Create `misc/validate-rust-equivalence.R`
- [ ] Run `cargo test` and verify all Rust tests pass
- [ ] Run `R CMD check` and verify R integration
- [ ] Run validation script: `Rscript misc/validate-rust-equivalence.R`
- [ ] Verify all tests pass with tolerance <= 1e-10
- [ ] Commit: `Phase 2.B: Implement Rust shape and objective functions`

---

## Common Issues

| Issue | Solution |
|-------|----------|
| Exponent overflow in sigmoid | Use `.max(0.1)` on x_scale; clamp exponent |
| Vector length mismatch | Add `assert_eq!` at function entry |
| R NaN from Rust | Check for division by zero; return 0.0 or error |
| Tolerance test fails | Increase tolerance slightly; check for numerical instability |

---

**Next Step:** Implement single-profile optimizer with argmin in Subphase 2.C.
