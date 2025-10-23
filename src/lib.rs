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
pub mod uncertainty;
pub mod horizons;

// Test function to check if Robj return type works
#[extendr]
fn test_robj_return(x: f64) -> Robj {
    // list! returns List, convert to Robj by taking ownership
    Robj::from(list!(result = x * 2.0, message = "test"))
}

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

/// Minimal List->List test to validate extendr wrapper generation
#[extendr]
fn test_list_roundtrip(input: List) -> List {
    // Build a new named list by copying existing entries and appending a diagnostic field
    let mut names: Vec<String> = Vec::new();
    let mut values: Vec<Robj> = Vec::new();

    for entry in input {
        let (name, val) = entry;
        names.push(name.to_string());
        values.push(val);
    }

    names.push("_echoed_by_rust".to_string());
    values.push(Robj::from("test_list_roundtrip"));

    // Pass owned Vec<String> directly to transfer ownership to the List.
    // This is safe because the List now owns the name data.
    List::from_names_and_values(names, values).unwrap()
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
        optimizer::AlgorithmType::ParticleSwarm => "particle_swarm".to_string(),
        optimizer::AlgorithmType::SimulatedAnnealing => "simulated_annealing".to_string(),
        optimizer::AlgorithmType::NewtonCG => "newton_cg".to_string(),
    }
}

/// Test function to check if extendr generates wrappers for multi-parameter functions
///
/// @param _a First vector parameter
/// @param _b Second vector parameter
/// @param _c Third vector parameter
/// @param d Numeric scalar parameter (returned)
///
/// @return Numeric scalar (value of d)
///
/// @keywords internal
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
        "particle_swarm" | "pso" => optimizer::AlgorithmType::ParticleSwarm,
        "simulated_annealing" | "sa" => optimizer::AlgorithmType::SimulatedAnnealing,
        "newton_cg" | "newton-cg" | "newtoncg" => optimizer::AlgorithmType::NewtonCG,
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

/// Parametric bootstrap engine (Rust implementation)
/// 
/// Called via R: `.Call("bootstrap_engine_rust", observed, depths, initial_params, config, PACKAGE = "soilmotif")`
/// 
/// The `config` parameter is an R list with fields:
/// - shape_type: character
/// - objective_name: character
/// - optimizer_name: character
/// - n_bootstrap: integer
/// - seed: integer (negative for random)
/// - fallback: logical
/// - method: character ("parametric" or "sieve")
/// - sieve_threshold: integer (for auto method selection)
/// - max_retries: integer
/// - parallel: logical
#[extendr]
fn bootstrap_engine_rust(
    observed: Vec<f64>,
    depths: Vec<f64>,
    initial_params: Vec<f64>,
    config: List
) -> List {
    
    // Extract configuration from the R list with sensible defaults
    let mut shape_type = "sigmoid".to_string();
    let mut objective_name = "rmse".to_string();
    let mut optimizer_name = "auto".to_string();
    let mut n_bootstrap = 100usize;
    let mut seed = -1i32;
    let mut fallback = true;
    let mut method = "parametric".to_string();
    let mut max_retries = 3usize;
    let mut parallel = false;

    // Iterate over the list entries to extract by name
    for (name, value) in config {
        match name {
            "shape_type" => {
                // Extract string from Robj
                if let Ok(s) = <String>::try_from(value) {
                    shape_type = s;
                }
            }
            "objective_name" => {
                if let Ok(s) = <String>::try_from(value) {
                    objective_name = s;
                }
            }
            "optimizer_name" => {
                if let Ok(s) = <String>::try_from(value) {
                    optimizer_name = s;
                }
            }
            "n_bootstrap" => {
                if let Ok(v) = <i32>::try_from(value) {
                    n_bootstrap = v as usize;
                }
            }
            "seed" => {
                if let Ok(v) = <i32>::try_from(value) {
                    seed = v;
                }
            }
            "fallback" => {
                if let Ok(v) = <i32>::try_from(value) {
                    fallback = v != 0;
                }
            }
            "method" => {
                if let Ok(s) = <String>::try_from(value) {
                    method = s;
                }
            }
            "max_retries" => {
                if let Ok(v) = <i32>::try_from(value) {
                    max_retries = v as usize;
                }
            }
            "parallel" => {
                if let Ok(v) = <i32>::try_from(value) {
                    parallel = v != 0;
                }
            }
            _ => {}
        }
    }
    
    // Convert R-friendly seed to Rust-friendly Option<u64>
    let seed_opt = if seed < 0 { None } else { Some(seed as u64) };

    // Call the appropriate bootstrap method
    let result_struct = match method.as_str() {
        "sieve" => {
            // Sieve bootstrap
            match crate::uncertainty::sieve_bootstrap(
                &observed,
                &depths,
                &initial_params,
                &shape_type,
                &objective_name,
                &optimizer_name,
                n_bootstrap,
                seed_opt,
                if fallback { "auto" } else { "strict" },
                max_retries,
                parallel,
                fallback,  // use_fallback parameter
            ) {
                Ok(res) => res,
                Err(e) => {
                    return list!(Error::from(e.to_string()));
                }
            }
        }
        "parametric" | _ => {
            // Parametric bootstrap (default)
            match crate::uncertainty::parametric_bootstrap(
                &observed,
                &depths,
                &initial_params,
                &shape_type,
                &objective_name,
                &optimizer_name,
                n_bootstrap,
                seed_opt,
                if fallback { "auto" } else { "strict" },
                max_retries,
                parallel,
            ) {
                Ok(res) => res,
                Err(e) => {
                    return list!(Error::from(e.to_string()));
                }
            }
        }
    };

    // Compute n_successful and n_failed from the results (before moving parameter_samples)
    let n_successful = result_struct.parameter_samples.len() as i32;
    let n_failed = result_struct.failed_indices.len() as i32;

    // Convert parameter samples to R list format
    let parameter_samples_robj: Vec<Robj> = result_struct.parameter_samples
        .into_iter()
        .map(|v| v.into_robj())
        .collect();

    // Convert Option<f64> to R scalar (NA if None)
    let ar1_coef_robj = match result_struct.ar1_coef {
        Some(val) => Robj::from(val),
        None => Robj::from(f64::NAN),
    };

    // Build and return the result list
    list!(
        success_rate = result_struct.success_rate,
        parameter_samples = parameter_samples_robj,
        rmse_samples = result_struct.rmse_samples,
        r2_samples = result_struct.r2_samples,
        aic_samples = result_struct.aic_samples,
        failed_indices = result_struct.failed_indices,
        n_successful = n_successful,
        n_failed = n_failed,
        message = result_struct.message,
        ar1_coef = ar1_coef_robj
    )
}

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


/// Mahalanobis distance boundary detection (Rust implementation)
///
/// @param element_matrix Matrix of element concentrations (n_depths x n_elements)
/// @param depths Vector of depth values
/// @param window_size Window size in depth units
///
/// @return Vector of Mahalanobis distances at each depth
///
/// @keywords internal
#[extendr]
fn mahalanobis_boundary_detection_rust(
    element_matrix: RMatrix<f64>,
    depths: Vec<f64>,
    window_size: f64,
) -> Vec<f64> {
    // Convert RMatrix to Array2
    let nrows = element_matrix.nrows();
    let ncols = element_matrix.ncols();

    let mut data = Vec::with_capacity(nrows * ncols);
    for i in 0..nrows {
        for j in 0..ncols {
            data.push(element_matrix[[i, j]]);
        }
    }

    let arr = ndarray::Array2::from_shape_vec((nrows, ncols), data)
        .expect("Failed to create Array2");

    let depths_arr = ndarray::Array1::from_vec(depths);

    // Call Rust implementation
    let distances = horizons::mahalanobis_boundary_detection(&arr, &depths_arr, window_size);

    // Convert back to Vec
    distances.to_vec()
}

/// Fuzzy k-means clustering (Rust implementation)
///
/// @param data Data matrix (n_samples x n_features)
/// @param k Number of clusters
/// @param m Fuzziness exponent
/// @param max_iter Maximum iterations
/// @param tol Convergence tolerance
/// @param centers_init Initial cluster centers
///
/// @return List with centers, memberships, entropy, converged, iterations
///
/// @keywords internal
#[extendr]
fn fuzzy_kmeans_rust(
    data: RMatrix<f64>,
    k: i32,
    m: f64,
    max_iter: i32,
    tol: f64,
    centers_init: RMatrix<f64>,
) -> List {
    let k_usize = k as usize;
    let max_iter_usize = max_iter as usize;

    // Convert data to Array2
    let nrows = data.nrows();
    let ncols = data.ncols();

    let mut data_vec = Vec::with_capacity(nrows * ncols);
    for i in 0..nrows {
        for j in 0..ncols {
            data_vec.push(data[[i, j]]);
        }
    }

    let data_arr = ndarray::Array2::from_shape_vec((nrows, ncols), data_vec)
        .expect("Failed to create data Array2");

    // Convert centers_init to Array2
    let k_rows = centers_init.nrows();
    let p_cols = centers_init.ncols();

    let mut centers_vec = Vec::with_capacity(k_rows * p_cols);
    for i in 0..k_rows {
        for j in 0..p_cols {
            centers_vec.push(centers_init[[i, j]]);
        }
    }

    let centers_init_arr = ndarray::Array2::from_shape_vec((k_rows, p_cols), centers_vec)
        .expect("Failed to create centers Array2");

    // Call Rust implementation
    let (centers, memberships, converged, iterations) = horizons::fuzzy_kmeans(
        &data_arr,
        k_usize,
        m,
        max_iter_usize,
        tol,
        &centers_init_arr,
    );

    // Compute entropy
    let entropy = horizons::compute_entropy(&memberships);

    // Convert results to R types
    let centers_flat: Vec<f64> = centers.iter().copied().collect();
    let memberships_flat: Vec<f64> = memberships.iter().copied().collect();
    let entropy_vec: Vec<f64> = entropy.to_vec();

    // Create RMatrix from flat vectors
    let centers_rmatrix = RMatrix::new_matrix(k_usize, ncols, |i, j| centers_flat[i * ncols + j]);
    let memberships_rmatrix = RMatrix::new_matrix(nrows, k_usize, |i, j| memberships_flat[i * k_usize + j]);

    // Build result list
    list!(
        centers = centers_rmatrix,
        memberships = memberships_rmatrix,
        entropy = entropy_vec,
        converged = converged,
        iterations = iterations as f64
    )
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
    fn recommend_optimizer_rust;
    fn shape_eval_rust;
    fn optimize_profile_rust;
    fn optimize_profile_rust_flexible;
    fn batch_optimize_profiles_rust;
    fn bootstrap_engine_rust;
    fn mahalanobis_boundary_detection_rust;
    fn fuzzy_kmeans_rust;
}
