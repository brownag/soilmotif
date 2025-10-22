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

/// Test function
#[extendr]
fn test_new_function() -> String {
    "test".to_string()
}

/// Recommend optimization algorithm based on problem characteristics
///
/// Called via R: `.Call("recommend_optimizer_rust", n_params, n_obs, objective_type, PACKAGE = "soilmotif")`
#[extendr]
fn recommend_optimizer_rust(n_params: i32, n_obs: i32, objective_type: &str) -> String {
    let algorithm = optimizer::recommend_algorithm(
        n_params as usize,
        n_obs as usize,
        objective_type
    );

    match algorithm {
        optimizer::AlgorithmType::NelderMead => "nelder_mead".to_string(),
        optimizer::AlgorithmType::LBFGS => "lbfgs".to_string(),
        optimizer::AlgorithmType::SimulatedAnnealing => "simulated_annealing".to_string(),
    }
}

/// Test function to check if extendr generates wrappers for multi-parameter functions
/// 
/// Called via R: `.Call("test_multi_param_rust", a, b, c, d, PACKAGE = "soilmotif")`
#[extendr]
fn test_multi_param_rust(_a: Vec<f64>, _b: Vec<f64>, _c: Vec<f64>, d: f64) -> f64 {
    d
}

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

/// Compute weighted RMSE (Rust implementation)
/// 
/// Called via R: `.Call("objective_weighted_rmse_rust", observed, predicted, depths, target_depth, weight_factor, PACKAGE = "soilmotif")`
#[extendr]
fn objective_weighted_rmse_rust(
    observed: Vec<f64>,
    predicted: Vec<f64>,
    depths: Vec<f64>,
    target_depth: f64,
    weight_factor: f64,
) -> f64 {
    objective::weighted_rmse(&observed, &predicted, &depths, target_depth, weight_factor)
}

/// Compute ordinal error (Rust implementation)
/// 
/// Called via R: `.Call("objective_ordinal_rust", observed, predicted, depths, under_penalty, over_penalty, PACKAGE = "soilmotif")`
#[extendr]
fn objective_ordinal_rust(
    observed: Vec<f64>,
    predicted: Vec<f64>,
    depths: Vec<f64>,
    underpredict_penalty: f64,
    overpredict_penalty: f64,
) -> f64 {
    objective::ordinal_error(&observed, &predicted, &depths, underpredict_penalty, overpredict_penalty)
}

/// Compute bounded error (Rust implementation)
/// 
/// Called via R: `.Call("objective_bounded_rust", observed, predicted, depths, obs_min, obs_max, penalty_factor, PACKAGE = "soilmotif")`
#[extendr]
fn objective_bounded_rust(
    observed: Vec<f64>,
    predicted: Vec<f64>,
    depths: Vec<f64>,
    obs_min: f64,
    obs_max: f64,
    penalty_factor: f64,
) -> f64 {
    objective::bounded_error(&observed, &predicted, &depths, obs_min, obs_max, penalty_factor)
}

/// Compute Huber loss (Rust implementation)
/// 
/// Called via R: `.Call("objective_huber_rust", observed, predicted, depths, delta, PACKAGE = "soilmotif")`
#[extendr]
fn objective_huber_rust(
    observed: Vec<f64>,
    predicted: Vec<f64>,
    depths: Vec<f64>,
    delta: f64,
) -> f64 {
    objective::huber_loss(&observed, &predicted, &depths, delta)
}

/// Compute quantile loss (Rust implementation)
/// 
/// Called via R: `.Call("objective_quantile_rust", observed, predicted, depths, quantile, PACKAGE = "soilmotif")`
#[extendr]
fn objective_quantile_rust(
    observed: Vec<f64>,
    predicted: Vec<f64>,
    depths: Vec<f64>,
    quantile: f64,
) -> f64 {
    objective::quantile_loss(&observed, &predicted, &depths, quantile)
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

/// Optimize single profile (legacy interface)
/// 
/// Called via R: `.Call("optimize_profile_rust", observed, x, initial_params, 
///                      shape_type, ascending, PACKAGE = "soilmotif")`
/// Returns Vec<f64> on success, or stops with an error message on failure
#[extendr]
fn optimize_profile_rust(
    observed: Vec<f64>,
    x: Vec<f64>,
    initial_params: Vec<f64>,
    shape_type: &str,
    ascending: bool,
) -> Vec<f64> {
    // Use RMSE objective by default for backward compatibility
    optimize_profile_rust_flexible(
        observed,
        x,
        initial_params,
        shape_type,
        ascending,
        "rmse",
        "auto",
    )
}

/// Optimize single profile with flexible algorithm selection
/// 
/// Fits shape function parameters to observed data with choice of optimization algorithm.
/// Supports flexible objective functions (RMSE, SSE, MAE, R²) and algorithms (Nelder-Mead).
///
/// Called via R: `.Call("optimize_profile_rust_flexible", observed, x, initial_params, 
///                      shape_type, ascending, objective_type, algorithm, PACKAGE = "soilmotif")`
#[extendr]
fn optimize_profile_rust_flexible(
    observed: Vec<f64>,
    x: Vec<f64>,
    initial_params: Vec<f64>,
    shape_type: &str,
    ascending: bool,
    objective_type: &str,
    algorithm: &str,
) -> Vec<f64> {
    // Create objective function by name
    let objective = match optimizer::create_objective(objective_type) {
        Ok(obj) => obj,
        Err(e) => {
            eprintln!("Failed to create objective '{}': {}", objective_type, e);
            return initial_params;
        }
    };

    // Parse algorithm
    let algorithm_type = match algorithm.to_lowercase().as_str() {
        "nelder_mead" => optimizer::AlgorithmType::NelderMead,
        "lbfgs" | "l-bfgs" => optimizer::AlgorithmType::LBFGS,
        "simulated_annealing" | "sa" => optimizer::AlgorithmType::SimulatedAnnealing,
        "auto" => {
            // Auto-select based on problem characteristics
            let n_params = initial_params.len();
            let n_obs = observed.len();
            optimizer::recommend_algorithm(n_params, n_obs, objective_type)
        }
        _ => {
            eprintln!("Unknown algorithm '{}', using Nelder-Mead", algorithm);
            optimizer::AlgorithmType::NelderMead
        }
    };

    // Try optimization with specified algorithm
    match optimizer::optimize_with_algorithm(
        &observed,
        &x,
        &initial_params,
        shape_type,
        ascending,
        objective,
        algorithm_type,
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
    fn test_multi_param_rust;
    fn objective_rmse_rust;
    fn objective_sse_rust;
    fn objective_mae_rust;
    fn objective_r2_rust;
    fn objective_weighted_rmse_rust;
    fn objective_ordinal_rust;
    fn objective_bounded_rust;
    fn objective_huber_rust;
    fn objective_quantile_rust;
    fn test_new_function;
    fn recommend_optimizer_rust;
    fn shape_eval_rust;
    fn optimize_profile_rust;
    fn optimize_profile_rust_flexible;
    fn batch_optimize_profiles_rust;
}
