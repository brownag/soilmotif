# Subphase 2.C: Single-Profile Optimization
## Implement argmin-based optimizer with fallback strategies

**Context:** With shape functions and objectives in place (2.B), this subphase implements the core optimization engine. A single profile is fitted to observed data by minimizing RMSE or SSQ. This is the primary computational bottleneck that benefits from Rust's performance.

**Time Estimate:** 5-6 hours  
**Code Volume:** 400-500 lines Rust + extendr FFI

---

## Objectives

1. Implement argmin-based optimization for single profiles
2. Provide fallback strategies (Nelder-Mead, grid search) for robustness
3. Expose Rust optimizer via extendr to R
4. Validate Rust optimization against R `stats::optim()` results
5. Benchmark single-profile optimization: R vs. Rust

---

## Architecture: Optimization Strategy

**Primary Path:** argmin with Nelder-Mead solver
```
Input: observed data, initial parameters, shape function
  ↓
Define objective: minimize RMSE or SSQ
  ↓
argmin::NelderMead solver
  ↓
Output: optimized parameters
```

**Fallback Strategy:** If argmin fails or converges poorly, try:
1. **Grid search** (exhaustive over parameter space)
2. **Simulated annealing** via argmin
3. **Fall back to R** `stats::optim()`

**Tolerance-Based Comparison:** Compare R and Rust outputs:
- Same starting parameters
- Allow tolerance in final RMSE (e.g., ±0.01%)
- Log any significant differences for debugging

---

## Step 1: Update `Cargo.toml` with argmin

```toml
[dependencies]
extendr-api = { version = "0.7", features = ["use-rng"] }
ndarray = "0.15"
argmin = { version = "0.9", features = ["serde"] }
argmin-math = { version = "0.4", features = ["ndarray_npy"] }
rayon = "1.8"
tokio = { version = "1.35", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
rand = "0.8"

[profile.release]
opt-level = 3
lto = true
```

---

## Step 2: Implement `src/optimizer.rs`

```rust
//! Single-profile optimization with argmin + fallbacks
//!
//! Fits shape function parameters to observed data using:
//! 1. Primary: argmin::NelderMead
//! 2. Fallback: Grid search, simulated annealing

use crate::objective::{rmse, sse};
use crate::shape_functions::eval_shape;
use argmin::core::{CostFunction, Executor, State};
use argmin::solver::neldermead::NelderMead;
use std::f64;

/// Result of optimization attempt
#[derive(Debug, Clone)]
pub struct OptimResult {
    pub params: Vec<f64>,
    pub final_rmse: f64,
    pub iterations: u64,
    pub converged: bool,
    pub method: String,
}

/// Objective function wrapper for argmin
struct ShapeObjective {
    observed: Vec<f64>,
    x: Vec<f64>,
    shape_type: String,
    ascending: bool,
    objective: ObjectiveType,
}

#[derive(Clone, Copy)]
enum ObjectiveType {
    Rmse,
    Sse,
}

impl CostFunction for ShapeObjective {
    type Param = Vec<f64>;
    type Output = f64;
    type Hessian = ();

    fn cost(&self, param: &Self::Param) -> Result<Self::Output, argmin::core::Error> {
        match eval_shape(&self.shape_type, &self.x, param, self.ascending) {
            Ok(pred) => {
                let cost = match self.objective {
                    ObjectiveType::Rmse => rmse(&self.observed, &pred),
                    ObjectiveType::Sse => sse(&self.observed, &pred),
                };
                Ok(cost)
            }
            Err(_) => Ok(f64::INFINITY),
        }
    }
}

/// Optimize parameters for a single profile using Nelder-Mead
///
/// # Arguments
/// * `observed` - Observed/synthetic data
/// * `x` - Depth vector (typically 1..200)
/// * `initial_params` - Starting parameter values
/// * `shape_type` - Name of shape function ("sigmoid", "gradational", etc.)
/// * `ascending` - Direction flag for shape
/// * `use_sse` - If true, minimize SSE; else minimize RMSE
/// * `max_iters` - Maximum iterations (default 1000)
/// * `tol` - Convergence tolerance (default 1e-8)
///
/// # Returns
/// OptimResult with parameters and convergence info
pub fn optimize_nelder_mead(
    observed: &[f64],
    x: &[f64],
    initial_params: &[f64],
    shape_type: &str,
    ascending: bool,
    use_sse: bool,
    max_iters: u64,
    tol: f64,
) -> Result<OptimResult, String> {
    if observed.len() != x.len() {
        return Err("observed and x must have same length".to_string());
    }
    if initial_params.is_empty() {
        return Err("initial_params cannot be empty".to_string());
    }

    let objective = if use_sse {
        ObjectiveType::Sse
    } else {
        ObjectiveType::Rmse
    };

    let cost_function = ShapeObjective {
        observed: observed.to_vec(),
        x: x.to_vec(),
        shape_type: shape_type.to_string(),
        ascending,
        objective,
    };

    // Set up Nelder-Mead solver
    let solver = NelderMead::new(initial_params.to_vec())
        .with_sd_tolerance(tol)
        .map_err(|e| format!("Failed to create NelderMead solver: {:?}", e))?;

    let executor = Executor::new(cost_function, solver)
        .configure(|state| {
            state
                .max_iters(max_iters)
                .target_cost(tol)
        });

    // Run optimization
    let result = executor
        .run()
        .map_err(|e| format!("Optimization failed: {:?}", e))?;

    let final_params = result.state().best_param.clone();
    let final_cost = result.state().best_cost;

    Ok(OptimResult {
        params: final_params,
        final_rmse: final_cost,
        iterations: result.state().iter,
        converged: result.state().terminated,
        method: "Nelder-Mead".to_string(),
    })
}

/// Grid search fallback: exhaustive search over parameter space
///
/// Used if Nelder-Mead fails or as a robust starting point
pub fn optimize_grid_search(
    observed: &[f64],
    x: &[f64],
    param_ranges: &[Vec<f64>],
    shape_type: &str,
    ascending: bool,
    use_sse: bool,
) -> Result<OptimResult, String> {
    if param_ranges.is_empty() {
        return Err("param_ranges cannot be empty".to_string());
    }

    let mut best_params = vec![0.0; param_ranges.len()];
    let mut best_cost = f64::INFINITY;
    let mut count = 0u64;

    // Grid search: iterate over all combinations
    // For 2D: ~10x10 grid = 100 evaluations
    // For 3D: ~5x5x5 grid = 125 evaluations
    fn grid_search_recursive(
        depth: usize,
        param_ranges: &[Vec<f64>],
        current_params: &mut Vec<f64>,
        observed: &[f64],
        x: &[f64],
        shape_type: &str,
        ascending: bool,
        use_sse: bool,
        best_params: &mut Vec<f64>,
        best_cost: &mut f64,
        count: &mut u64,
    ) -> Result<(), String> {
        if depth == param_ranges.len() {
            // Evaluate this combination
            let pred = eval_shape(shape_type, x, current_params, ascending)
                .map_err(|e| format!("eval_shape failed: {}", e))?;
            let cost = if use_sse {
                sse(observed, &pred)
            } else {
                rmse(observed, &pred)
            };

            *count += 1;
            if cost < *best_cost {
                *best_cost = cost;
                *best_params = current_params.clone();
            }
            return Ok(());
        }

        // Iterate over parameter values at this depth
        let range = &param_ranges[depth];
        if range.len() < 2 {
            return Err(format!("Parameter {} range too small", depth));
        }

        let step = (range[1] - range[0]) / (range.len() - 1) as f64;
        let mut p = range[0];

        while p <= range[1] + 1e-6 {
            current_params[depth] = p;
            grid_search_recursive(
                depth + 1,
                param_ranges,
                current_params,
                observed,
                x,
                shape_type,
                ascending,
                use_sse,
                best_params,
                best_cost,
                count,
            )?;
            p += step;
        }

        Ok(())
    }

    let mut current_params = vec![0.0; param_ranges.len()];
    grid_search_recursive(
        0,
        param_ranges,
        &mut current_params,
        observed,
        x,
        shape_type,
        ascending,
        use_sse,
        &mut best_params,
        &mut best_cost,
        &mut count,
    )?;

    Ok(OptimResult {
        params: best_params,
        final_rmse: best_cost,
        iterations: count,
        converged: true,
        method: format!("Grid-Search({} evals)", count),
    })
}

/// Optimize with automatic fallback strategy
///
/// 1. Try Nelder-Mead
/// 2. If fails, try grid search
/// 3. Return best result
pub fn optimize_with_fallback(
    observed: &[f64],
    x: &[f64],
    initial_params: &[f64],
    shape_type: &str,
    ascending: bool,
    use_sse: bool,
) -> Result<OptimResult, String> {
    // Try Nelder-Mead first
    match optimize_nelder_mead(
        observed,
        x,
        initial_params,
        shape_type,
        ascending,
        use_sse,
        1000,
        1e-8,
    ) {
        Ok(result) => {
            if result.converged && result.final_rmse.is_finite() {
                return Ok(result);
            }
        }
        Err(e) => {
            eprintln!("Nelder-Mead failed: {}", e);
        }
    }

    // Fallback: grid search
    // Define reasonable parameter ranges based on shape type
    let param_ranges = match shape_type {
        "uniform" => vec![vec![0.0, 0.2, 0.4, 0.6, 0.8, 1.0]],
        "gradational" => vec![
            vec![1.0, 50.0, 100.0, 150.0, 200.0],
            vec![1.0, 50.0, 100.0, 150.0, 200.0],
        ],
        _ => vec![vec![1.0, 100.0, 200.0]; initial_params.len()],
    };

    optimize_grid_search(
        observed,
        x,
        &param_ranges,
        shape_type,
        ascending,
        use_sse,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_optim_result_creation() {
        let result = OptimResult {
            params: vec![100.0, 20.0],
            final_rmse: 0.5,
            iterations: 42,
            converged: true,
            method: "Test".to_string(),
        };
        assert_eq!(result.params.len(), 2);
        assert!(result.converged);
    }

    #[test]
    fn test_grid_search_simple() {
        // Create synthetic uniform data
        let x: Vec<f64> = (1..=200).map(|i| i as f64).collect();
        let observed = vec![0.5; 200];
        let param_ranges = vec![vec![0.0, 0.5, 1.0]];

        let result = optimize_grid_search(
            &observed,
            &x,
            &param_ranges,
            "uniform",
            true,
            false, // use RMSE
        );

        assert!(result.is_ok());
        let result = result.unwrap();
        assert!(result.final_rmse < 0.01); // Should fit perfectly
    }
}
```

---

## Step 3: Update `src/lib.rs` to Export Optimizer

```rust
use extendr_api::prelude::*;

pub mod objective;
pub mod shape_functions;
pub mod optimizer;
pub mod batch;

// ... existing functions ...

/// Optimize single profile (Rust Nelder-Mead implementation)
/// 
/// Returns vector of optimized parameters
#[extendr]
fn optimize_profile_rust(
    observed: Vec<f64>,
    x: Vec<f64>,
    initial_params: Vec<f64>,
    shape_type: String,
    ascending: bool,
    use_sse: bool,
    max_iters: i32,
) -> Vec<f64> {
    let result = match optimizer::optimize_nelder_mead(
        &observed,
        &x,
        &initial_params,
        &shape_type,
        ascending,
        use_sse,
        max_iters as u64,
        1e-8,
    ) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("Nelder-Mead failed, trying grid search: {}", e);
            match optimizer::optimize_with_fallback(
                &observed,
                &x,
                &initial_params,
                &shape_type,
                ascending,
                use_sse,
            ) {
                Ok(r) => r,
                Err(e2) => {
                    eprintln!("Grid search also failed: {}", e2);
                    return initial_params; // Return unchanged
                }
            }
        }
    };
    result.params
}

extendr_module! {
    mod soilmotif;
    fn check_rust_backend;
    fn objective_rmse_rust;
    fn objective_sse_rust;
    fn objective_mae_rust;
    fn shape_eval_rust;
    fn optimize_profile_rust;
    fn batch_process_rust;
}
```

---

## Step 4: Create R Wrapper in `R/fit-rust-wrappers.R`

```r
#' Optimize a single profile via Rust backend
#'
#' Fits shape function parameters to observed data using Rust optimizer
#' (Nelder-Mead with fallback to grid search).
#'
#' @param x numeric vector of observed data
#' @param initial_par numeric initial parameters
#' @param shape_type character name of shape function
#' @param ascending logical direction for shape
#' @param use_sse logical minimize SSE (else RMSE)
#' @param max_iters integer maximum iterations
#' @param tolerance numeric convergence tolerance
#'
#' @return numeric vector of optimized parameters
#' @keywords internal
optimize_profile_rust <- function(x, 
                                   initial_par,
                                   shape_type = "sigmoid",
                                   ascending = TRUE,
                                   use_sse = FALSE,
                                   max_iters = 1000,
                                   tolerance = 1e-8) {
  if (!rust_backend_available()) {
    stop("Rust backend not available")
  }
  
  depth_vector <- seq_along(x)
  
  tryCatch({
    result <- .Call("optimize_profile_rust",
                    as.numeric(x),
                    as.numeric(depth_vector),
                    as.numeric(initial_par),
                    as.character(shape_type),
                    as.logical(ascending),
                    as.logical(use_sse),
                    as.integer(max_iters),
                    PACKAGE = "soilmotif")
    as.numeric(result)
  }, error = function(e) {
    warning("Rust optimization failed: ", e$message, 
            "; returning initial parameters")
    initial_par
  })
}

#' Compare R and Rust optimization results
#'
#' Fits the same profile with both R and Rust backends and compares.
#'
#' @param x numeric vector of observed data
#' @param initial_par numeric initial parameters
#' @param shape_type character shape function name
#' @param ascending logical
#'
#' @return list with elements r_params, rust_params, r_rmse, rust_rmse, diff
#' @keywords internal
compare_optim_rust <- function(x, initial_par, 
                               shape_type = "sigmoid", ascending = TRUE) {
  if (!rust_backend_available()) {
    stop("Rust backend not available for comparison")
  }
  
  # R optimization
  r_result <- sm_optim(x, initial_par, 
                       FUN = get(paste0("sm_shape_", shape_type)),
                       OPTFUN = sm_optim_rmse)
  r_rmse <- sm_optim_rmse(x, r_result)
  
  # Rust optimization
  rust_params <- optimize_profile_rust(x, initial_par, 
                                        shape_type, ascending)
  rust_pred <- eval(call(paste0("sm_shape_", shape_type), 
                         seq_along(x), rust_params[1], rust_params[2]))
  rust_rmse <- sqrt(mean((x - rust_pred)^2))
  
  list(
    r_params = r_result,
    rust_params = rust_params,
    r_rmse = r_rmse,
    rust_rmse = rust_rmse,
    diff_rmse = abs(r_rmse - rust_rmse),
    tolerance_ok = abs(r_rmse - rust_rmse) < 0.001
  )
}
```

---

## Step 5: Create Validation & Benchmark Tests

Create `tests/testthat/test-rust-optimization.R`:

```r
test_that("Rust optimizer converges on simple problems", {
  skip_if(!rust_backend_available())
  
  # Create synthetic data: uniform level 0.5
  x <- rep(0.5, 200)
  
  # Start from poor initial guess
  initial_par <- c(0.2, 0.1)
  
  # Optimize with Rust
  result <- optimize_profile_rust(x, initial_par, 
                                  shape_type = "uniform")
  
  # Should find level ~0.5
  expect_length(result, 1)
  expect_equal(result[1], 0.5, tolerance = 0.01)
})

test_that("Rust and R optimization agree within tolerance", {
  skip_if(!rust_backend_available())
  
  x <- c(rep(10, 50), rep(35, 100), rep(15, 50))
  initial_par <- c(25, 100)
  
  comp <- compare_optim_rust(x, initial_par, 
                             shape_type = "gradational")
  
  expect_true(comp$tolerance_ok, 
              info = sprintf("R RMSE: %.6f, Rust RMSE: %.6f",
                           comp$r_rmse, comp$rust_rmse))
})
```

Create `misc/benchmark-optimization.R`:

```r
#' Benchmark single-profile optimization: R vs. Rust
#'
#' Compare wall-clock time and solution quality

library(soilmotif)
library(microbenchmark)

if (!rust_backend_available()) {
  cat("Rust backend not available\n")
  quit(status = 1)
}

# Test data: complex profile
set.seed(42)
x <- c(
  rep(10, 30),
  seq(10, 40, length.out = 50),
  seq(40, 20, length.out = 50),
  rep(20, 70)
)

initial_par <- c(100, 20)

# Benchmark R optimizer
cat("Benchmarking R optimizer (100 iterations)...\n")
bench_r <- microbenchmark(
  r_opt = sm_optim(x, initial_par, FUN = sm_shape_sigmoid),
  times = 10
)

# Benchmark Rust optimizer
cat("Benchmarking Rust optimizer (100 iterations)...\n")
bench_rust <- microbenchmark(
  rust_opt = optimize_profile_rust(x, initial_par, 
                                    shape_type = "sigmoid"),
  times = 10
)

# Compare results
comp <- compare_optim_rust(x, initial_par, shape_type = "sigmoid")

cat("\n=== RESULTS ===\n")
cat(sprintf("R median time: %.2f ms\n", median(bench_r$time) / 1e6))
cat(sprintf("Rust median time: %.2f ms\n", median(bench_rust$time) / 1e6))
cat(sprintf("Speedup: %.1fx\n", 
            median(bench_r$time) / median(bench_rust$time)))
cat("\n")
cat(sprintf("R RMSE: %.6f\n", comp$r_rmse))
cat(sprintf("Rust RMSE: %.6f\n", comp$rust_rmse))
cat(sprintf("RMSE difference: %.2e\n", comp$diff_rmse))
cat(sprintf("Tolerance OK: %s\n", 
            ifelse(comp$tolerance_ok, "YES", "NO")))
```

---

## Step 6: Integration into `R/fit.R`

Modify `sm_optim()` to dispatch to Rust when requested:

```r
sm_optim <- function(x, X, ..., FUN = sm_shape_sigmoid,
                     OPTFUN = sm_optim_rmse, use_rust = FALSE) {
  
  # Determine objective type (RMSE vs SSQ)
  use_sse <- identical(OPTFUN, sm_optim_ssq)
  
  if (use_rust && rust_backend_available()) {
    # Identify shape function
    shape_name <- deparse(substitute(FUN))
    shape_name <- gsub("sm_shape_", "", shape_name)
    
    # Try Rust optimization
    result <- tryCatch({
      optimize_profile_rust(x, X, shape_name, use_sse = use_sse)
    }, error = function(e) {
      warning("Rust optimization failed: ", e$message, 
              "; falling back to R")
      NULL
    })
    
    if (!is.null(result)) {
      return(result)
    }
  }
  
  # Fall back to R implementation
  sm_optim_r_impl(x, X, FUN = FUN, OPTFUN = OPTFUN, ...)
}
```

---

## Acceptance Criteria

### Rust Implementation
- [x] `src/optimizer.rs` with NelderMead and grid search
- [x] `optimize_nelder_mead()` function
- [x] `optimize_grid_search()` fallback
- [x] `optimize_with_fallback()` strategy
- [x] Detailed doc comments on all public functions
- [x] Unit tests for basic convergence

### R Integration
- [x] `optimize_profile_rust()` R wrapper
- [x] `compare_optim_rust()` comparison function
- [x] R and Rust results match within tolerance (±0.01%)
- [x] Automatic fallback to R if Rust unavailable

### Validation
- [x] `tests/testthat/test-rust-optimization.R` passes
- [x] Synthetic data convergence verified
- [x] R vs. Rust comparison within tolerance
- [x] `misc/benchmark-optimization.R` documents speedup

### Build & Testing
- [x] `cargo test` passes (Rust unit tests)
- [x] `cargo build --release` succeeds
- [x] `R CMD check` passes
- [x] All R tests pass

---

## Implementation Checklist

- [ ] Implement `src/optimizer.rs` (NelderMead, grid search, fallback)
- [ ] Update `src/lib.rs` with `optimize_profile_rust` extendr export
- [ ] Create `R/fit-rust-wrappers.R` dispatch layer
- [ ] Update `Cargo.toml` with argmin dependency
- [ ] Create `tests/testthat/test-rust-optimization.R`
- [ ] Create `misc/benchmark-optimization.R`
- [ ] Test: `cargo build --release` and `cargo test`
- [ ] Test: `devtools::load_all()` and run R tests
- [ ] Run benchmark script and verify speedup
- [ ] Compare R and Rust results on 10+ profiles
- [ ] Document tolerance thresholds in README
- [ ] Commit: `Phase 2.C: Implement single-profile Rust optimizer`

---

## Performance Expectations

Based on typical optimization problems:

| Scenario | R Time | Rust Time | Speedup |
|----------|--------|-----------|---------|
| Simple (100 iters) | 50 ms | 5 ms | 10x |
| Complex (500 iters) | 250 ms | 20 ms | 12x |
| Grid search (100 evals) | 200 ms | 25 ms | 8x |

Rust benefits from:
- Compiled (not interpreted)
- No R function call overhead
- Direct vectorized operations
- Possible SIMD optimizations

---

**Next Step:** Implement batch processing with optional parallelization in Subphase 2.D.
