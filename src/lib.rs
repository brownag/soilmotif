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
    objective::rmse(&x, &y)
}

/// Compute SSE between observed and predicted (Rust implementation)
/// 
/// Called via R: `.Call("objective_sse_rust", x, y, PACKAGE = "soilmotif")`
#[extendr]
fn objective_sse_rust(x: Vec<f64>, y: Vec<f64>) -> f64 {
    objective::sse(&x, &y)
}

/// Compute MAE between observed and predicted (Rust implementation)
/// 
/// Called via R: `.Call("objective_mae_rust", x, y, PACKAGE = "soilmotif")`
#[extendr]
fn objective_mae_rust(x: Vec<f64>, y: Vec<f64>) -> f64 {
    objective::mae(&x, &y)
}

/// Compute R-squared between observed and predicted (Rust implementation)
/// 
/// Called via R: `.Call("objective_r2_rust", x, y, PACKAGE = "soilmotif")`
#[extendr]
fn objective_r2_rust(x: Vec<f64>, y: Vec<f64>) -> f64 {
    objective::r_squared(&x, &y)
}

/// Evaluate a shape function (Rust implementation)
/// 
/// Called via R: `.Call("shape_eval_rust", shape_type, x, params, ascending, PACKAGE = "soilmotif")`
/// Returns Vec<f64> on success, or stops with an error message on failure
#[extendr]
fn shape_eval_rust(
    shape_type: &str,
    x: Vec<f64>,
    params: Vec<f64>,
    ascending: bool,
) -> Vec<f64> {
    match shape_functions::eval_shape(shape_type, &x, &params, ascending) {
        Ok(result) => result,
        Err(e) => {
            extendr_api::throw_r_error(&format!("Shape evaluation error: {}", e));
        }
    }
}

/// Optimize single profile with pluggable objective function
/// 
/// Fits shape function parameters to observed data.
/// Supports flexible objective functions (RMSE, SSE, MAE, R²).
///
/// Called via R: `.Call("optimize_profile_rust", observed, x, initial_params, 
///                      shape_type, ascending, objective_type, PACKAGE = "soilmotif")`
#[extendr]
fn optimize_profile_rust(
    observed: Vec<f64>,
    x: Vec<f64>,
    initial_params: Vec<f64>,
    shape_type: &str,
    ascending: bool,
    objective_type: &str,
) -> Vec<f64> {
    // Create objective function by name
    let objective = match optimizer::create_objective(objective_type) {
        Ok(obj) => obj,
        Err(e) => {
            eprintln!("Failed to create objective '{}': {}", objective_type, e);
            return initial_params;
        }
    };

    // Try optimization with fallback strategy
    match optimizer::optimize_with_fallback(
        &observed,
        &x,
        &initial_params,
        shape_type,
        ascending,
        objective,
    ) {
        Ok(result) => result.params,
        Err(e) => {
            eprintln!("Optimization failed: {}", e);
            initial_params
        }
    }
}

/// Batch profile processing (Rust implementation)
/// 
/// Called via R: `.Call("batch_process_rust", profiles_list, models, ..., PACKAGE = "soilmotif")`
/// Note: Nested vectors require List conversion in R; implementation in Phase 2.D
#[extendr]
fn batch_process_rust() -> String {
    // Placeholder: will implement in 2.D
    // Note: extendr FFI requires custom List handling for nested vectors
    "Batch processing not yet implemented".to_string()
}

extendr_module! {
    mod soilmotif;
    fn check_rust_backend;
    fn objective_rmse_rust;
    fn objective_sse_rust;
    fn objective_mae_rust;
    fn objective_r2_rust;
    fn shape_eval_rust;
    fn optimize_profile_rust;
    fn batch_process_rust;
}
