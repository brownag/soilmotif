//! soilmotif Rust backend
//!
//! High-performance optimization and batch processing for soil depth functions.
//! Exposed to R via extendr FFI.
//!
//! # Architecture
//!
//! - `objective`: RMSE and SSQ calculations
//! - `shape_functions`: Rust implementations of R shape functions
//! - `optimizer`: Single-profile fitting with custom optimization (argmin framework prepared)
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

/// Batch profile processing (Rust implementation, returns data.frame-like result)
/// 
/// Optimizes multiple profiles in batch with error collection and reporting.
/// Returns results as a structured list that R will process into proper format.
/// 
/// Called via R: `.Call("batch_optimize_profiles_rust", profiles_list, params_list, 
///                      x, shape_type, ascending, objective_type, PACKAGE = "soilmotif")`
/// 
/// # Arguments (from R)
/// - profiles_list: List of numeric vectors (each profile)
/// - params_list: List of numeric vectors (initial parameters for each profile)
/// - x: numeric vector (depth positions, shared across all profiles)
/// - shape_type: character shape function name
/// - ascending: logical direction flag
/// - objective_type: character objective function name ("rmse", "sse", "mae", "r2")
/// 
/// # Returns (to R)
/// List with components (ungrouped, R will reconstruct):
/// - profile_ids: integer vector of profile indices
/// - params: list of numeric vectors (single NA for failed profiles)
/// - rmse_values: numeric vector of final objective values
/// - converged: logical vector of convergence flags
/// - errors: character vector of error messages (empty for success)
/// - method: character indicating optimization method used
/// - summary: character summary string
/// - failed_count: integer number of failed profiles
#[extendr]
fn batch_optimize_profiles_rust(
    profiles_list: List,
    params_list: List,
    x: Vec<f64>,
    shape_type: &str,
    ascending: bool,
    objective_type: &str,
) -> List {
        // Convert R List of profiles to Rust Vec<Vec<f64>>
    let mut profiles_vec: Vec<Vec<f64>> = Vec::new();
    for prof_entry in profiles_list {
        let (_name, prof_robj) = prof_entry;
        if let Some(p) = prof_robj.as_real_slice() {
            profiles_vec.push(p.to_vec());
        } else {
            eprintln!("Failed to convert profile to numeric vector");
            return Robj::from(()).as_list().unwrap();
        }
    }

    // Convert R List of parameters to Rust Vec<Vec<f64>>
    let mut params_vec: Vec<Vec<f64>> = Vec::new();
    for param_entry in params_list {
        let (_name, param_robj) = param_entry;
        if let Some(p) = param_robj.as_real_slice() {
            params_vec.push(p.to_vec());
        } else {
            eprintln!("Failed to convert parameter set to numeric vector");
            return Robj::from(()).as_list().unwrap();
        }
    }

    // Create objective function
    let objective = match optimizer::create_objective(objective_type) {
        Ok(obj) => obj,
        Err(e) => {
            eprintln!("Failed to create objective '{}': {}", objective_type, e);
            return Robj::from(()).as_list().unwrap();
        }
    };

    // Call batch optimizer
    match batch::batch_optimize_sequential(
        &profiles_vec,
        &params_vec,
        &x,
        shape_type,
        ascending,
        objective,
        false,
    ) {
        Ok(result) => {
            // Convert components to R vectors/lists
            let profile_ids_f64: Vec<f64> = result.profile_ids.iter().map(|&x| x as f64).collect();
            
            // Convert Option<Vec<f64>> to R list with NA for failures
            let params_list_r: Vec<Robj> = result
                .params
                .iter()
                .map(|opt_params| {
                    match opt_params {
                        Some(params) => Robj::from(params.clone()),
                        None => Robj::from(vec![f64::NAN]),  // NA for failed profile
                    }
                })
                .collect();
            
            let rmse_vec: Vec<f64> = result.rmse_values.clone();
            let converged_bool: Vec<bool> = result.converged.clone();
            let error_strs: Vec<String> = result
                .errors
                .iter()
                .map(|err_opt| err_opt.as_ref().map(|s| s.clone()).unwrap_or_else(|| String::new()))
                .collect();
            
            let method_str = result.method.clone();
            let summary_str = result.summary();
            let failed_count_f64 = result.failed_count as f64;
            
            // Build named list using List::from_names_and_values
            let names = vec![
                "profile_ids",
                "params",
                "rmse_values",
                "converged",
                "errors",
                "method",
                "summary",
                "failed_count",
            ];
            let values = vec![
                Robj::from(profile_ids_f64),
                Robj::from(params_list_r),
                Robj::from(rmse_vec),
                Robj::from(converged_bool),
                Robj::from(error_strs),
                Robj::from(method_str),
                Robj::from(summary_str),
                Robj::from(failed_count_f64),
            ];
            
            List::from_names_and_values(names, values).unwrap()
        }
        Err(e) => {
            eprintln!("Batch optimization failed: {}", e);
            Robj::from(()).as_list().unwrap()
        }
    }
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
    fn batch_optimize_profiles_rust;
}
