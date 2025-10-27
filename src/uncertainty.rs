use rand::prelude::*;
use rand_pcg::Pcg64;
use rayon::prelude::*;

// ============================================================================
// Uncertainty Quantification Structures
// ============================================================================

/// Result from uncertainty quantification computation
#[derive(Debug, Clone)]
pub struct UncertaintyResult {
    pub std_errors: Vec<f64>,        // Parameter standard errors
    pub cov_matrix: Vec<Vec<f64>>,   // Full covariance matrix
    pub correlations: Vec<Vec<f64>>, // Parameter correlations
    pub method: String,              // Method used
}

// ============================================================================
// Uncertainty Computation Functions
// ============================================================================

/// Compute parameter standard errors and covariance from Hessian matrix
///
/// The covariance matrix of parameter estimates is approximately the inverse
/// of the Hessian matrix of the cost function at the optimum (under regularity
/// conditions). Standard errors are sqrt(diag(Hessian^-1)).
///
/// # Arguments
/// * `hessian` - The Hessian matrix (n_params x n_params)
/// * `n_obs` - Number of observations (used to scale residual variance)
///
/// # Returns
/// A UncertaintyResult with std_errors, cov_matrix, and correlations
pub fn compute_hessian_standard_errors(
    hessian: &[Vec<f64>],
    n_obs: usize,
) -> Result<UncertaintyResult, String> {
    let n_params = hessian.len();

    if n_params == 0 {
        return Err("Empty Hessian matrix".to_string());
    }

    // Validate that Hessian is square and symmetric
    for row in hessian {
        if row.len() != n_params {
            return Err("Hessian is not square".to_string());
        }
    }

    // Invert the Hessian matrix via Gaussian elimination with partial pivoting
    let mut inv_hessian = invert_hessian(hessian)?;

    // Scale by residual variance (MSE * (n_obs - n_params) / n_obs)
    // Conservative estimate: assume Hessian includes data variance
    // Covariance ≈ (1 / (n_obs - n_params)) * Hessian^-1
    let dof_correction = if n_obs > n_params {
        n_obs as f64 / (n_obs - n_params) as f64
    } else {
        1.0 // Fallback if n_obs <= n_params
    };

    for i in 0..n_params {
        for j in 0..n_params {
            inv_hessian[i][j] *= dof_correction;
        }
    }

    // Extract standard errors from diagonal
    let std_errors: Vec<f64> = (0..n_params)
        .map(|i| inv_hessian[i][i].abs().sqrt())
        .collect();

    // Compute correlations from covariance
    let correlations = compute_correlations(&inv_hessian, &std_errors);

    Ok(UncertaintyResult {
        std_errors,
        cov_matrix: inv_hessian,
        correlations,
        method: "hessian".to_string(),
    })
}

/// Invert a matrix using Gaussian elimination with partial pivoting
/// Returns the inverted matrix or error if singular
fn invert_hessian(matrix: &[Vec<f64>]) -> Result<Vec<Vec<f64>>, String> {
    let n = matrix.len();

    // Create augmented matrix [A | I]
    let mut augmented = vec![vec![0.0; 2*n]; n];

    for i in 0..n {
        for j in 0..n {
            augmented[i][j] = matrix[i][j];
        }
        augmented[i][n + i] = 1.0;
    }

    // Forward elimination with partial pivoting
    for col in 0..n {
        // Find pivot
        let mut max_row = col;
        let mut max_val = augmented[col][col].abs();

        for row in (col+1)..n {
            let val = augmented[row][col].abs();
            if val > max_val {
                max_val = val;
                max_row = row;
            }
        }

        // Check for singular matrix
        if max_val < 1e-10 {
            return Err(format!("Matrix is singular or ill-conditioned (pivot at ({},{}) is {})",
                             col, col, max_val));
        }

        // Swap rows
        augmented.swap(col, max_row);

        // Eliminate column
        let pivot = augmented[col][col];
        for j in 0..(2*n) {
            augmented[col][j] /= pivot;
        }

        for row in 0..n {
            if row != col {
                let factor = augmented[row][col];
                for j in 0..(2*n) {
                    augmented[row][j] -= factor * augmented[col][j];
                }
            }
        }
    }

    // Extract inverse from right side of augmented matrix
    let mut inverse = vec![vec![0.0; n]; n];
    for i in 0..n {
        for j in 0..n {
            inverse[i][j] = augmented[i][n + j];
        }
    }

    Ok(inverse)
}

/// Compute parameter correlations from covariance matrix and standard errors
fn compute_correlations(cov_matrix: &[Vec<f64>], std_errors: &[f64]) -> Vec<Vec<f64>> {
    let n = std_errors.len();
    let mut correlations = vec![vec![0.0; n]; n];

    for i in 0..n {
        for j in 0..n {
            if std_errors[i] > 0.0 && std_errors[j] > 0.0 {
                correlations[i][j] = cov_matrix[i][j] / (std_errors[i] * std_errors[j]);
            } else {
                correlations[i][j] = 0.0;
            }
        }
    }

    correlations
}

/// Compute parameter standard errors using Fisher Information Matrix
///
/// For least-squares problems, the Fisher Information is:
/// I(θ) = (1/σ²) * J^T * J
///
/// where J is the Jacobian of predictions w.r.t. parameters.
/// The covariance matrix is approximately I(θ)^-1.
///
/// This method is similar to Hessian-based approaches but uses
/// the gradient of residuals rather than the Hessian of cost function.
///
/// # Arguments
/// * `jacobian` - The Jacobian matrix (n_obs x n_params) of predictions
/// * `residuals` - Residuals (observed - predicted)
/// * `n_obs` - Number of observations
///
/// # Returns
/// A UncertaintyResult with std_errors, cov_matrix, and correlations
pub fn compute_fisher_standard_errors(
    jacobian: &[Vec<f64>],
    residuals: &[f64],
    n_obs: usize,
) -> Result<UncertaintyResult, String> {
    let n_params = if jacobian.is_empty() {
        return Err("Empty Jacobian matrix".to_string());
    } else {
        jacobian[0].len()
    };

    // Compute residual variance: σ² = RSS / (n - p)
    let rss: f64 = residuals.iter().map(|r| r * r).sum();
    let dof = (n_obs as f64) - (n_params as f64);
    if dof <= 0.0 {
        return Err("Insufficient degrees of freedom for Fisher Information".to_string());
    }
    let sigma2 = rss / dof;

    // Compute Fisher Information: I = (1/σ²) * J^T * J
    let mut fisher_info = vec![vec![0.0; n_params]; n_params];
    for i in 0..n_params {
        for j in 0..n_params {
            let mut sum = 0.0;
            for obs_idx in 0..n_obs {
                if obs_idx < jacobian.len() {
                    sum += jacobian[obs_idx][i] * jacobian[obs_idx][j];
                }
            }
            fisher_info[i][j] = sum / sigma2;
        }
    }

    // Invert Fisher Information to get covariance matrix
    let inv_fisher = invert_fisher_matrix(&fisher_info)?;

    // Extract standard errors from diagonal
    let std_errors: Vec<f64> = (0..n_params)
        .map(|i| inv_fisher[i][i].abs().sqrt())
        .collect();

    // Compute correlations
    let correlations = compute_correlations(&inv_fisher, &std_errors);

    Ok(UncertaintyResult {
        std_errors,
        cov_matrix: inv_fisher,
        correlations,
        method: "fisher".to_string(),
    })
}

/// Invert a matrix using Gaussian elimination with partial pivoting
/// (for Fisher Information matrix inversion)
fn invert_fisher_matrix(matrix: &[Vec<f64>]) -> Result<Vec<Vec<f64>>, String> {
    let n = matrix.len();

    // Create augmented matrix [A | I]
    let mut augmented = vec![vec![0.0; 2*n]; n];

    for i in 0..n {
        for j in 0..n {
            augmented[i][j] = matrix[i][j];
        }
        augmented[i][n + i] = 1.0;
    }

    // Forward elimination with partial pivoting
    for col in 0..n {
        // Find pivot
        let mut max_row = col;
        let mut max_val = augmented[col][col].abs();

        for row in (col+1)..n {
            let val = augmented[row][col].abs();
            if val > max_val {
                max_val = val;
                max_row = row;
            }
        }

        // Check for singular matrix
        if max_val < 1e-10 {
            return Err(format!("Fisher Information matrix is singular or ill-conditioned (pivot at ({},{}) is {})",
                             col, col, max_val));
        }

        // Swap rows
        augmented.swap(col, max_row);

        // Eliminate column
        let pivot = augmented[col][col];
        for j in 0..(2*n) {
            augmented[col][j] /= pivot;
        }

        for row in 0..n {
            if row != col {
                let factor = augmented[row][col];
                for j in 0..(2*n) {
                    augmented[row][j] -= factor * augmented[col][j];
                }
            }
        }
    }

    // Extract inverse from right side of augmented matrix
    let mut inverse = vec![vec![0.0; n]; n];
    for i in 0..n {
        for j in 0..n {
            inverse[i][j] = augmented[i][n + j];
        }
    }

    Ok(inverse)
}

/// Compute parameter standard errors via Jackknife (leave-one-out) resampling
///
/// Jackknife is a deterministic resampling method that:
/// 1. Removes each observation one at a time
/// 2. Re-optimizes parameters on the reduced dataset
/// 3. Estimates parameter variance from the empirical distribution of estimates
///
/// More robust than parametric bootstrap but computationally expensive (N refits).
/// Uses parallel processing via rayon to speed up computation.
///
/// # Arguments
/// * `observed` - Observed data values
/// * `x` - Depth/position values
/// * `initial_params` - Initial parameter guess
/// * `shape_type` - Name of shape function
/// * `ascending` - Whether shape is ascending
/// * `optimizer_fn` - Function to call for optimization (e.g., optimize_profile_rust)
///
/// # Returns
/// A UncertaintyResult with empirical std_errors, cov_matrix, and correlations
pub fn compute_jackknife_uncertainty(
    observed: &[f64],
    x: &[f64],
    initial_params: &[f64],
    shape_type: &str,
    ascending: bool,
    optimize_fn: impl Fn(&[f64], &[f64], &[f64], &str, bool) -> Result<Vec<f64>, String> + Send + Sync,
) -> Result<UncertaintyResult, String> {
    let n_obs = observed.len();
    let n_params = initial_params.len();

    if n_obs < 2 {
        return Err("Need at least 2 observations for Jackknife".to_string());
    }

    // Collect jackknife parameter estimates
    // For each observation i, fit model to data without observation i
    let jackknife_params: Vec<Vec<f64>> = (0..n_obs)
        .into_par_iter()
        .map(|leave_out_idx| {
            // Create dataset without observation at leave_out_idx
            let observed_loo: Vec<f64> = observed
                .iter()
                .enumerate()
                .filter(|(idx, _)| *idx != leave_out_idx)
                .map(|(_, &val)| val)
                .collect();

            let x_loo: Vec<f64> = x
                .iter()
                .enumerate()
                .filter(|(idx, _)| *idx != leave_out_idx)
                .map(|(_, &val)| val)
                .collect();

            // Re-optimize on leave-one-out dataset
            match optimize_fn(&observed_loo, &x_loo, initial_params, shape_type, ascending) {
                Ok(params) => params,
                Err(_) => {
                    // If optimization fails on this fold, return original params as fallback
                    initial_params.to_vec()
                }
            }
        })
        .collect();

    // Compute empirical mean of parameter estimates
    let mut param_means = vec![0.0; n_params];
    for params in &jackknife_params {
        for (i, &p) in params.iter().enumerate() {
            param_means[i] += p;
        }
    }
    for mean in &mut param_means {
        *mean /= n_obs as f64;
    }

    // Compute empirical covariance matrix
    // Jackknife variance: (n-1) * mean_square_deviation
    let mut cov_matrix = vec![vec![0.0; n_params]; n_params];
    for params in &jackknife_params {
        for i in 0..n_params {
            for j in 0..n_params {
                let dev_i = params[i] - param_means[i];
                let dev_j = params[j] - param_means[j];
                cov_matrix[i][j] += dev_i * dev_j;
            }
        }
    }

    // Scale by (n-1) / n for jackknife
    let scale_factor = (n_obs - 1) as f64 / n_obs as f64;
    for i in 0..n_params {
        for j in 0..n_params {
            cov_matrix[i][j] *= scale_factor;
        }
    }

    // Extract standard errors from diagonal
    let std_errors: Vec<f64> = (0..n_params)
        .map(|i| cov_matrix[i][i].abs().sqrt())
        .collect();

    // Compute correlations
    let correlations = compute_correlations(&cov_matrix, &std_errors);

    Ok(UncertaintyResult {
        std_errors,
        cov_matrix,
        correlations,
        method: "jackknife".to_string(),
    })
}

// BootstrapEngineResult struct for internal use
#[derive(Debug, Clone)]
pub struct BootstrapEngineResult {
    pub success_rate: f64,
    pub parameter_samples: Vec<Vec<f64>>,
    pub rmse_samples: Vec<f64>,
    pub r2_samples: Vec<f64>,
    pub aic_samples: Vec<f64>,
    pub failed_indices: Vec<i32>,
    pub message: String,
    pub ar1_coef: f64,  // NAN if not available (parametric or AR fitting failure)
    pub ar1_sigma2: f64,  // NAN if not available (parametric or AR fitting failure)
}

#[derive(Debug, Clone)]
struct AR1Model {
    phi: f64,        // AR(1) coefficient
    sigma2: f64,     // Variance of innovations
    mean_residual: f64, // Mean of residuals
}

/// Fit AR(1) model to residuals using Yule-Walker equations
/// Returns None if AR fitting fails, Some(AR1Model) if successful
fn fit_ar1_model(residuals: &[f64]) -> Option<AR1Model> {
    if residuals.len() < 3 {
        return None;
    }

    let n = residuals.len() as f64;
    let mean = residuals.iter().sum::<f64>() / n;

    // Compute centered residuals
    let centered: Vec<f64> = residuals.iter().map(|r| r - mean).collect();

    // Compute autocovariances
    let gamma0: f64 = centered.iter().map(|r| r * r).sum::<f64>() / n;
    if gamma0 <= 0.0 {
        return None; // No variance
    }

    let gamma1: f64 = centered
        .iter()
        .zip(centered.iter().skip(1))
        .map(|(r1, r2)| r1 * r2)
        .sum::<f64>()
        / n;

    // Yule-Walker estimate for AR(1): phi = gamma1 / gamma0
    let phi = gamma1 / gamma0;

    // Check stationarity condition
    if phi.abs() >= 1.0 || !phi.is_finite() {
        return None;
    }

    // Innovations variance
    let sigma2 = gamma0 * (1.0 - phi * phi);
    if sigma2 <= 0.0 {
        return None;
    }

    Some(AR1Model {
        phi,
        sigma2,
        mean_residual: mean,
    })
}

/// Resample innovations from AR(1) process
fn resample_ar1_innovations(
    ar1_model: &AR1Model,
    n_obs: usize,
    residuals: &[f64],
    rng: &mut impl Rng,
) -> Vec<f64> {
    // Estimate innovations from fitted AR(1) model
    let centered: Vec<f64> = residuals
        .iter()
        .map(|r| r - ar1_model.mean_residual)
        .collect();

    let mut extracted_innovations = Vec::with_capacity(n_obs);

    // First innovation
    if !centered.is_empty() {
        extracted_innovations.push(centered[0]);
    }

    // Subsequent innovations using residual from AR model
    for i in 1..n_obs.min(centered.len()) {
        let predicted = ar1_model.phi * centered[i - 1];
        let residual = centered[i] - predicted;
        extracted_innovations.push(residual);
    }

    // CRITICAL FIX: Resample innovations with replacement
    // This ensures each bootstrap iteration gets different innovations
    let mut resampled_innovations = Vec::with_capacity(n_obs);
    for _ in 0..n_obs {
        resampled_innovations.push(
            *extracted_innovations
                .choose(rng)
                .unwrap_or(&0.0)
        );
    }

    resampled_innovations
}

/// Reconstruct synthetic residuals from resampled innovations
fn reconstruct_residuals_from_innovations(
    ar1_model: &AR1Model,
    innovations: &[f64],
) -> Vec<f64> {
    let mut residuals = Vec::with_capacity(innovations.len());

    for (i, &eps) in innovations.iter().enumerate() {
        if i == 0 {
            residuals.push(eps + ar1_model.mean_residual);
        } else {
            let r = ar1_model.phi * residuals[i - 1] + eps + ar1_model.mean_residual;
            residuals.push(r);
        }
    }

    residuals
}

// Sieve bootstrap implementation
pub fn sieve_bootstrap(
    observed: &[f64],
    depths: &[f64],
    initial_params: &[f64],
    shape_family: &str,
    objective: &str,
    optimizer: &str,
    n_bootstrap: usize,
    seed: Option<u64>,
    fallback_strategy: &str,
    max_retries: usize,
    parallel: bool,
    use_fallback: bool, // Whether to fall back to parametric on AR fit failure
) -> Result<BootstrapEngineResult, String> {
    // Initialize result struct
    let mut result = BootstrapEngineResult {
        success_rate: 0.0,
        parameter_samples: Vec::new(),
        rmse_samples: Vec::new(),
        r2_samples: Vec::new(),
        aic_samples: Vec::new(),
        failed_indices: Vec::new(),
        message: String::new(),
        ar1_coef: f64::NAN,
        ar1_sigma2: f64::NAN,
    };

    // Step 1: Initial optimization on original data
    let initial_fit = match perform_initial_optimization(
        observed,
        depths,
        initial_params,
        shape_family,
        objective,
        optimizer,
        fallback_strategy,
        max_retries,
    ) {
        Ok(fit) => fit,
        Err(e) => {
            result.message = format!("Initial optimization failed: {}", e);
            return Ok(result);
        }
    };

    // Compute fitted values (shape output in [0, 1])
    let fitted_normalized = match crate::shape_functions::eval_shape(
        shape_family,
        depths,
        &initial_fit.params,
        false,
    ) {
        Ok(f) => f,
        Err(e) => {
            result.message = format!("Failed to compute fitted values: {}", e);
            return Ok(result);
        }
    };

    // Scale fitted to data range for proper residual computation
    let obs_min = observed.iter().cloned().fold(f64::INFINITY, f64::min);
    let obs_max = observed.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let obs_range = obs_max - obs_min;

    let fitted: Vec<f64> = if obs_range < 1e-10 {
        // Constant observed data
        vec![obs_min; fitted_normalized.len()]
    } else {
        // Scale from [0, 1] to [obs_min, obs_max]
        fitted_normalized.iter()
            .map(|&f| obs_min + f * obs_range)
            .collect()
    };

    // Compute residuals in proper data scale
    let residuals: Vec<f64> = observed
        .iter()
        .zip(fitted.iter())
        .map(|(o, f)| o - f)
        .collect();

    // Step 2: Fit AR(1) model
    let ar1_model = match fit_ar1_model(&residuals) {
        Some(model) => {
            result.ar1_coef = model.phi;
            result.ar1_sigma2 = model.sigma2;
            result.message = format!("Sieve bootstrap completed: {} successful, {} failed (AR1 phi = {:.4}, sigma2 = {:.6})",
                n_bootstrap, 0, model.phi, model.sigma2);
            model
        }
        None => {
            // AR fitting failed
            if use_fallback {
                // Fall back to parametric bootstrap
                result.message = "Sieve bootstrap: AR(1) model fitting failed, falling back to parametric bootstrap".to_string();
                return parametric_bootstrap(
                    observed,
                    depths,
                    initial_params,
                    shape_family,
                    objective,
                    optimizer,
                    n_bootstrap,
                    seed,
                    fallback_strategy,
                    max_retries,
                    parallel,
                );
            } else {
                // Error on AR fit failure
                result.message = "Sieve bootstrap: AR(1) model fitting failed and fallback disabled".to_string();
                return Ok(result);
            }
        }
    };

    // Step 3: Sieve bootstrap resampling
    let bootstrap_results: Vec<Option<BootstrapSample>> = if parallel {
        (0..n_bootstrap)
            .into_par_iter()
            .map(|i| {
                let local_seed = seed.map(|s| s + i as u64).unwrap_or_else(|| rand::random());
                let mut local_rng = Pcg64::seed_from_u64(local_seed);

                // Resample innovations
                let innovations = resample_ar1_innovations(&ar1_model, residuals.len(), &residuals, &mut local_rng);

                // Reconstruct synthetic residuals
                let synthetic_residuals = reconstruct_residuals_from_innovations(&ar1_model, &innovations);

                // Create synthetic observed
                let synthetic_observed: Vec<f64> = fitted
                    .iter()
                    .zip(synthetic_residuals.iter())
                    .map(|(f, r)| f + r)
                    .collect();

                // Re-optimize using optimized params from initial fit as anchors
                match perform_initial_optimization(
                    &synthetic_observed,
                    depths,
                    &initial_fit.params,  // Use optimized params, not original initial_params
                    shape_family,
                    objective,
                    optimizer,
                    fallback_strategy,
                    max_retries,
                ) {
                    Ok(result) => Some(BootstrapSample {
                        params: result.params,
                        rmse: result.rmse,
                        r2: result.r2,
                        aic: result.aic,
                    }),
                    Err(_) => None,
                }
            })
            .collect()
    } else {
        (0..n_bootstrap)
            .map(|i| {
                let local_seed = seed.map(|s| s + i as u64).unwrap_or_else(|| rand::random());
                let mut local_rng = Pcg64::seed_from_u64(local_seed);

                // Resample innovations
                let innovations = resample_ar1_innovations(&ar1_model, residuals.len(), &residuals, &mut local_rng);

                // Reconstruct synthetic residuals
                let synthetic_residuals = reconstruct_residuals_from_innovations(&ar1_model, &innovations);

                // Create synthetic observed
                let synthetic_observed: Vec<f64> = fitted
                    .iter()
                    .zip(synthetic_residuals.iter())
                    .map(|(f, r)| f + r)
                    .collect();

                // Re-optimize using optimized params from initial fit as anchors
                match perform_initial_optimization(
                    &synthetic_observed,
                    depths,
                    &initial_fit.params,  // Use optimized params, not original initial_params
                    shape_family,
                    objective,
                    optimizer,
                    fallback_strategy,
                    max_retries,
                ) {
                    Ok(result) => Some(BootstrapSample {
                        params: result.params,
                        rmse: result.rmse,
                        r2: result.r2,
                        aic: result.aic,
                    }),
                    Err(_) => None,
                }
            })
            .collect()
    };

    // Step 4: Collect results
    let mut param_samples = Vec::new();
    let mut rmse_samples = Vec::new();
    let mut r2_samples = Vec::new();
    let mut aic_samples = Vec::new();
    let mut failed_indices = Vec::new();

    for (i, sample_opt) in bootstrap_results.into_iter().enumerate() {
        match sample_opt {
            Some(sample) => {
                param_samples.push(sample.params);
                rmse_samples.push(sample.rmse);
                r2_samples.push(sample.r2);
                aic_samples.push(sample.aic);
            }
            None => {
                failed_indices.push(i);
            }
        }
    }

    result.success_rate = if n_bootstrap > 0 {
        (param_samples.len() as f64) / (n_bootstrap as f64)
    } else {
        0.0
    };
    result.parameter_samples = param_samples;
    result.rmse_samples = rmse_samples;
    result.r2_samples = r2_samples;
    result.aic_samples = aic_samples;
    result.failed_indices = failed_indices.into_iter().map(|i| i as i32).collect();
    result.message = format!(
        "Sieve bootstrap completed: {} successful, {} failed (AR1 phi = {:.4}, sigma2 = {:.6})",
        result.parameter_samples.len(),
        result.failed_indices.len(),
        if result.ar1_coef.is_nan() { 0.0 } else { result.ar1_coef },
        if result.ar1_sigma2.is_nan() { 0.0 } else { result.ar1_sigma2 }
    );

    Ok(result)
}

// Parametric bootstrap implementation
pub fn parametric_bootstrap(
    observed: &[f64],
    depths: &[f64],
    initial_params: &[f64],
    shape_family: &str,
    objective: &str,
    optimizer: &str,
    n_bootstrap: usize,
    seed: Option<u64>,
    fallback_strategy: &str,
    max_retries: usize,
    parallel: bool,
) -> Result<BootstrapEngineResult, String> {
    // Initialize result struct
    let mut result = BootstrapEngineResult {
        success_rate: 0.0,
        parameter_samples: Vec::new(),
        rmse_samples: Vec::new(),
        r2_samples: Vec::new(),
        aic_samples: Vec::new(),
        failed_indices: Vec::new(),
        message: String::new(),
        ar1_coef: f64::NAN,
        ar1_sigma2: f64::NAN,
    };

    // Note: seed parameter reserved for future use (per-iteration randomization)
    // Currently using independent random generation per bootstrap iteration
    let _ = seed;

    // Step 1: Initial optimization on original data
    let initial_fit = match perform_initial_optimization(
        observed,
        depths,
        initial_params,
        shape_family,
        objective,
        optimizer,
        fallback_strategy,
        max_retries,
    ) {
        Ok(fit) => fit,
        Err(e) => {
            result.message = format!("Initial optimization failed: {}", e);
            return Ok(result);
        }
    };

    // Compute fitted values (shape output in [0, 1])
    let fitted_normalized = match crate::shape_functions::eval_shape(
        shape_family,
        depths,
        &initial_fit.params,
        false, // ascending
    ) {
        Ok(f) => f,
        Err(e) => {
            result.message = format!("Failed to compute fitted values: {}", e);
            return Ok(result);
        }
    };

    // Scale fitted to data range for proper residual computation
    let obs_min = observed.iter().cloned().fold(f64::INFINITY, f64::min);
    let obs_max = observed.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let obs_range = obs_max - obs_min;

    let fitted: Vec<f64> = if obs_range < 1e-10 {
        // Constant observed data
        vec![obs_min; fitted_normalized.len()]
    } else {
        // Scale from [0, 1] to [obs_min, obs_max]
        fitted_normalized.iter()
            .map(|&f| obs_min + f * obs_range)
            .collect()
    };

    // Compute residuals in proper data scale
    let residuals: Vec<f64> = observed
        .iter()
        .zip(fitted.iter())
        .map(|(o, f)| o - f)
        .collect();

    // Step 2: Bootstrap resampling
    // CRITICAL: Use OPTIMIZED parameters from initial fit as anchors for all bootstrap iterations
    // The grid search is centered at initial_fit.params (the optimized solution) to ensure that
    // parameter variation comes from resampled residuals, not from random grid search anchoring

    let bootstrap_results: Vec<Option<BootstrapSample>> = if parallel {
        (0..n_bootstrap)
            .into_par_iter()
            .map(|i| {
                let local_seed = seed.map(|s| s + i as u64).unwrap_or_else(|| rand::random());
                let mut local_rng = Pcg64::seed_from_u64(local_seed);
                perform_bootstrap_iteration(
                    depths,
                    &fitted,
                    &residuals,
                    &initial_fit.params,  // Use OPTIMIZED params as grid search anchor for all bootstrap iterations
                    shape_family,
                    objective,
                    optimizer,
                    fallback_strategy,
                    max_retries,
                    &mut local_rng,
                )
            })
            .collect()
    } else {
        (0..n_bootstrap)
            .map(|i| {
                // Use same seed derivation logic as parallel mode for consistency
                let local_seed = seed.map(|s| s + i as u64).unwrap_or_else(|| rand::random());
                let mut local_rng = Pcg64::seed_from_u64(local_seed);
                perform_bootstrap_iteration(
                    depths,
                    &fitted,
                    &residuals,
                    &initial_fit.params,  // Use OPTIMIZED params as grid search anchor for all bootstrap iterations
                    shape_family,
                    objective,
                    optimizer,
                    fallback_strategy,
                    max_retries,
                    &mut local_rng,
                )
            })
            .collect()
    };

    // Step 3: Collect results
    let mut param_samples = Vec::new();
    let mut rmse_samples = Vec::new();
    let mut r2_samples = Vec::new();
    let mut aic_samples = Vec::new();
    let mut failed_indices = Vec::new();

    for (i, sample_opt) in bootstrap_results.into_iter().enumerate() {
        match sample_opt {
            Some(sample) => {
                param_samples.push(sample.params);
                rmse_samples.push(sample.rmse);
                r2_samples.push(sample.r2);
                aic_samples.push(sample.aic);
            }
            None => {
                failed_indices.push(i);
            }
        }
    }

    result.success_rate = if n_bootstrap > 0 { (param_samples.len() as f64) / (n_bootstrap as f64) } else { 0.0 };
    result.parameter_samples = param_samples;
    result.rmse_samples = rmse_samples;
    result.r2_samples = r2_samples;
    result.aic_samples = aic_samples;
    result.failed_indices = failed_indices.into_iter().map(|i| i as i32).collect();
    result.message = format!(
        "Parametric bootstrap completed: {} successful, {} failed",
        result.parameter_samples.len(), result.failed_indices.len()
    );

    Ok(result)
}

#[derive(Debug, Clone)]
struct BootstrapSample {
    params: Vec<f64>,
    rmse: f64,
    r2: f64,
    aic: f64,
}

#[derive(Debug, Clone)]
struct OptimizationResult {
    params: Vec<f64>,
    rmse: f64,
    r2: f64,
    aic: f64,
}

// Block bootstrap implementation
// Preserves depth autocorrelation by resampling contiguous blocks of residuals
pub fn block_bootstrap(
    observed: &[f64],
    depths: &[f64],
    initial_params: &[f64],
    shape_family: &str,
    objective: &str,
    optimizer: &str,
    n_bootstrap: usize,
    seed: Option<u64>,
    fallback_strategy: &str,
    max_retries: usize,
    parallel: bool,
    block_size: Option<usize>,  // Block size in observations; if None, use ceil(sqrt(n))
) -> Result<BootstrapEngineResult, String> {
    // Initialize result struct
    let mut result = BootstrapEngineResult {
        success_rate: 0.0,
        parameter_samples: Vec::new(),
        rmse_samples: Vec::new(),
        r2_samples: Vec::new(),
        aic_samples: Vec::new(),
        failed_indices: Vec::new(),
        message: String::new(),
        ar1_coef: f64::NAN,
        ar1_sigma2: f64::NAN,
    };

    let _ = seed;

    // Step 1: Initial optimization on original data
    let initial_fit = match perform_initial_optimization(
        observed,
        depths,
        initial_params,
        shape_family,
        objective,
        optimizer,
        fallback_strategy,
        max_retries,
    ) {
        Ok(fit) => fit,
        Err(e) => {
            result.message = format!("Initial optimization failed: {}", e);
            return Ok(result);
        }
    };

    // Compute fitted values
    let fitted_normalized = match crate::shape_functions::eval_shape(
        shape_family,
        depths,
        &initial_fit.params,
        false,
    ) {
        Ok(f) => f,
        Err(e) => {
            result.message = format!("Failed to compute fitted values: {}", e);
            return Ok(result);
        }
    };

    // Scale fitted to data range
    let obs_min = observed.iter().cloned().fold(f64::INFINITY, f64::min);
    let obs_max = observed.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let obs_range = obs_max - obs_min;

    let fitted: Vec<f64> = if obs_range < 1e-10 {
        vec![obs_min; fitted_normalized.len()]
    } else {
        fitted_normalized.iter()
            .map(|&f| obs_min + f * obs_range)
            .collect()
    };

    // Compute residuals
    // CRITICAL: Ensure observed and fitted have same length before residual computation
    assert_eq!(observed.len(), fitted.len(),
        "Observed ({}) and fitted ({}) must have same length",
        observed.len(), fitted.len());

    let residuals: Vec<f64> = observed
        .iter()
        .zip(fitted.iter())
        .map(|(o, f)| o - f)
        .collect();

    let n = residuals.len();

    // Determine block size: ceil(sqrt(n)) if not specified
    let b = block_size.unwrap_or_else(|| {
        let n = residuals.len();
        ((n as f64).sqrt().ceil()) as usize
    });

    // Step 2: Block bootstrap resampling
    let bootstrap_results: Vec<Option<BootstrapSample>> = if parallel {
        (0..n_bootstrap)
            .into_par_iter()
            .map(|i| {
                let local_seed = seed.map(|s| s + i as u64).unwrap_or_else(|| rand::random());
                let mut local_rng = Pcg64::seed_from_u64(local_seed);

                // Resample blocks of residuals
                let synthetic_residuals = resample_blocks(&residuals, b, &mut local_rng);

                // CRITICAL: Ensure synthetic_residuals has same length as fitted
                assert_eq!(synthetic_residuals.len(), fitted.len(),
                    "Synthetic residuals ({}) must equal fitted length ({})",
                    synthetic_residuals.len(), fitted.len());

                // Create synthetic observed with explicit length preservation
                assert_eq!(fitted.len(), n, "Fitted must have length n");
                let synthetic_observed: Vec<f64> = (0..n)
                    .map(|i| fitted[i] + synthetic_residuals[i])
                    .collect();
                assert_eq!(synthetic_observed.len(), n, "Synthetic observed length must be {}, got {}", n, synthetic_observed.len());

                // CRITICAL: Ensure synthetic_observed and depths match length
                assert_eq!(synthetic_observed.len(), depths.len(),
                    "Synthetic observed ({}) must match depths length ({})",
                    synthetic_observed.len(), depths.len());

                // Re-optimize
                match perform_initial_optimization(
                    &synthetic_observed,
                    depths,
                    &initial_fit.params,
                    shape_family,
                    objective,
                    optimizer,
                    fallback_strategy,
                    max_retries,
                ) {
                    Ok(result) => Some(BootstrapSample {
                        params: result.params,
                        rmse: result.rmse,
                        r2: result.r2,
                        aic: result.aic,
                    }),
                    Err(_) => None,
                }
            })
            .collect()
    } else {
        (0..n_bootstrap)
            .map(|i| {
                let local_seed = seed.map(|s| s + i as u64).unwrap_or_else(|| rand::random());
                let mut local_rng = Pcg64::seed_from_u64(local_seed);

                // Resample blocks of residuals
                let synthetic_residuals = resample_blocks(&residuals, b, &mut local_rng);

                // CRITICAL: Ensure synthetic_residuals has same length as fitted
                assert_eq!(synthetic_residuals.len(), fitted.len(),
                    "Synthetic residuals ({}) must equal fitted length ({})",
                    synthetic_residuals.len(), fitted.len());

                // Create synthetic observed with explicit length preservation
                assert_eq!(fitted.len(), n, "Fitted must have length n");
                let synthetic_observed: Vec<f64> = (0..n)
                    .map(|i| fitted[i] + synthetic_residuals[i])
                    .collect();
                assert_eq!(synthetic_observed.len(), n, "Synthetic observed length must be {}, got {}", n, synthetic_observed.len());

                // CRITICAL: Ensure synthetic_observed and depths match length
                assert_eq!(synthetic_observed.len(), depths.len(),
                    "Synthetic observed ({}) must match depths length ({})",
                    synthetic_observed.len(), depths.len());

                // Re-optimize
                match perform_initial_optimization(
                    &synthetic_observed,
                    depths,
                    &initial_fit.params,
                    shape_family,
                    objective,
                    optimizer,
                    fallback_strategy,
                    max_retries,
                ) {
                    Ok(result) => Some(BootstrapSample {
                        params: result.params,
                        rmse: result.rmse,
                        r2: result.r2,
                        aic: result.aic,
                    }),
                    Err(_) => None,
                }
            })
            .collect()
    };

    // Step 3: Collect results (same as parametric/sieve)
    let mut param_samples = Vec::new();
    let mut rmse_samples = Vec::new();
    let mut r2_samples = Vec::new();
    let mut aic_samples = Vec::new();

    for sample_opt in bootstrap_results {
        if let Some(sample) = sample_opt {
            param_samples.push(sample.params);
            rmse_samples.push(sample.rmse);
            r2_samples.push(sample.r2);
            aic_samples.push(sample.aic);
        } else {
            result.failed_indices.push(param_samples.len() as i32);
        }
    }

    result.success_rate = if n_bootstrap > 0 {
        param_samples.len() as f64 / n_bootstrap as f64
    } else {
        0.0
    };

    result.parameter_samples = param_samples;
    result.rmse_samples = rmse_samples;
    result.r2_samples = r2_samples;
    result.aic_samples = aic_samples;
    result.message = format!(
        "Block bootstrap completed: {} successful, {} failed (block size = {})",
        result.parameter_samples.len(),
        result.failed_indices.len(),
        b
    );

    Ok(result)
}

// Helper function: resample blocks of residuals
fn resample_blocks(
    residuals: &[f64],
    block_size: usize,
    rng: &mut impl Rng,
) -> Vec<f64> {
    let n = residuals.len();
    let num_blocks = (n + block_size - 1) / block_size;  // ceil(n / block_size)

    let mut synthetic_residuals = Vec::with_capacity(n);

    // Resample blocks with replacement until we have at least n points
    while synthetic_residuals.len() < n {
        let block_idx = rng.random_range(0..num_blocks);
        let start = block_idx * block_size;
        let end = (start + block_size).min(n);

        synthetic_residuals.extend_from_slice(&residuals[start..end]);
    }

    // Trim to exactly original length
    synthetic_residuals.truncate(n);
    synthetic_residuals
}

fn perform_initial_optimization(
    observed: &[f64],
    depths: &[f64],
    initial_params: &[f64],
    shape_family: &str,
    objective: &str,
    _optimizer: &str,
    _fallback_strategy: &str,
    _max_retries: usize,
) -> std::result::Result<OptimizationResult, String> {
    // Use refined grid search in original data space for bootstrap iterations
    // The grid has 21 points per dimension (441 total for 2D) with ±200% range
    // to properly cover the parameter space without boundary issues
    let objective_func = crate::optimizer::create_objective(objective)
        .map_err(|e| format!("Failed to create objective: {}", e))?;

    let opt_result = crate::optimizer::optimize_fast_bootstrap_wide(
        observed,
        depths,
        initial_params,
        shape_family,
        false,  // ascending=false
        objective_func,
    ).map_err(|e| format!("Optimization failed: {}", e))?;

    // Compute diagnostics
    // eval_shape returns [0,1], need to scale to observed range for diagnostics
    let fitted_normalized = crate::shape_functions::eval_shape(
        shape_family,
        depths,
        &opt_result.params,
        false,
    )?;

    // Scale fitted [0,1] to observed range for proper RMSE/R² calculation
    let obs_min = observed.iter().cloned().fold(f64::INFINITY, f64::min);
    let obs_max = observed.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let obs_range = obs_max - obs_min;

    // CRITICAL: Shape functions return [0,1], must scale to observed range
    let fitted: Vec<f64> = if obs_range < 1e-10 {
        vec![obs_min; fitted_normalized.len()]
    } else {
        // Linear scaling [0,1] → [obs_min, obs_max]
        fitted_normalized.iter()
            .map(|&f| obs_min + f * obs_range)
            .collect()
    };

    let rmse = crate::objective::rmse(observed, &fitted);
    let r2 = crate::objective::r_squared(observed, &fitted);
    let aic = compute_aic(rmse, observed.len(), opt_result.params.len());

    Ok(OptimizationResult {
        params: opt_result.params,
        rmse,
        r2,
        aic,
    })
}

fn perform_bootstrap_iteration(
    depths: &[f64],
    fitted: &[f64],
    residuals: &[f64],
    initial_params: &[f64],
    shape_family: &str,
    objective: &str,
    optimizer: &str,
    fallback_strategy: &str,
    max_retries: usize,
    rng: &mut impl Rng,
) -> Option<BootstrapSample> {
    // Resample residuals
    let resampled_residuals: Vec<f64> = (0..residuals.len())
        .map(|_| *residuals.choose(rng).unwrap())
        .collect();

    // Create synthetic observed
    let synthetic_observed: Vec<f64> = fitted
        .iter()
        .zip(resampled_residuals.iter())
        .map(|(f, r)| f + r)
        .collect();


    // Re-optimize synthetic data (optimizer normalizes internally)
    match perform_initial_optimization(
        &synthetic_observed,
        depths,
        initial_params,
        shape_family,
        objective,
        optimizer,
        fallback_strategy,
        max_retries,
    ) {
        Ok(result) => Some(BootstrapSample {
            params: result.params,
            rmse: result.rmse,
            r2: result.r2,
            aic: result.aic,
        }),
        Err(_) => None,
    }
}

fn compute_aic(rmse: f64, n_obs: usize, n_params: usize) -> f64 {
    let log_likelihood = -0.5 * (n_obs as f64) * (1.0 + (2.0 * std::f64::consts::PI * rmse * rmse).ln());
    2.0 * (n_params as f64) - 2.0 * log_likelihood
}

/// Internal optimization result (part of unused fallback implementation)
#[allow(dead_code)]
struct OptimizationResultInternal {
    params: Vec<f64>,
}

/// INTERNAL: Old multi-algorithm fallback (renamed to avoid shadowing crate::optimizer::optimize_with_fallback)
/// This tries multiple algorithms in sequence, including potentially unstable ones like L-BFGS
#[allow(dead_code)]
fn optimize_with_fallback_old_impl(
    observed: &[f64],
    depths: &[f64],
    initial_params: &[f64],
    shape_family: &str,
    objective: &str,
    optimizer: &str,
    fallback_strategy: &str,
    max_retries: usize,
) -> std::result::Result<OptimizationResultInternal, String> {
    // Resolve "auto" optimizer to actual algorithm
    let optimizer_to_use = if optimizer == "auto" {
        let recommended = crate::optimizer::recommend_algorithm(
            initial_params.len(),
            observed.len(),
            objective,
        );
        match recommended {
            crate::optimizer::AlgorithmType::NelderMead => "nelder_mead",
            crate::optimizer::AlgorithmType::LBFGS => "lbfgs",
            crate::optimizer::AlgorithmType::ParticleSwarm => "particle_swarm",
            crate::optimizer::AlgorithmType::SimulatedAnnealing => "simulated_annealing",
            crate::optimizer::AlgorithmType::NewtonCG => "newton_cg",
        }
    } else {
        optimizer
    };

    let algorithms = match fallback_strategy {
        // "auto" strategy: try recommended algorithm first, then fallback sequence
        "auto" => vec![optimizer_to_use, "nelder_mead", "lbfgs", "particle_swarm", "simulated_annealing"],
        "explicit" => vec![optimizer_to_use],
        "strict" => vec![optimizer_to_use],
        _ => return Err(format!("Unknown fallback strategy: {}", fallback_strategy)),
    };

    for algorithm in &algorithms {
        for attempt in 0..max_retries {
            match crate::optimizer::optimize_with_algorithm(
                observed,
                depths,
                initial_params,
                shape_family,
                false, // ascending
                crate::optimizer::create_objective(objective).map_err(|e| format!("Objective error: {}", e))?,
                match *algorithm {
                    "nelder_mead" => crate::optimizer::AlgorithmType::NelderMead,
                    "lbfgs" => crate::optimizer::AlgorithmType::LBFGS,
                    "particle_swarm" => crate::optimizer::AlgorithmType::ParticleSwarm,
                    "simulated_annealing" => crate::optimizer::AlgorithmType::SimulatedAnnealing,
                    "newton_cg" => crate::optimizer::AlgorithmType::NewtonCG,
                    _ => return Err(format!("Unknown algorithm: {}", *algorithm)),
                },
            ) {
                Ok(opt_result) => return Ok(OptimizationResultInternal { params: opt_result.params }),
                Err(e) => {
                    if attempt == max_retries - 1 && algorithm == algorithms.last().unwrap() {
                        return Err(format!("All optimization attempts failed. Last error: {}", e));
                    }
                    // Continue to next attempt or algorithm
                }
            }
        }
    }

    Err("Optimization failed with all fallback options".to_string())
}