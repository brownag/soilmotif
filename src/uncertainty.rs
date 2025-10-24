use rand::prelude::*;
use rand_pcg::Pcg64;
use rayon::prelude::*;

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

    let mut innovations = Vec::with_capacity(n_obs);

    // First innovation
    if !centered.is_empty() {
        innovations.push(centered[0]);
    }

    // Subsequent innovations using residual from AR model
    for i in 1..n_obs.min(centered.len()) {
        let predicted = ar1_model.phi * centered[i - 1];
        let residual = centered[i] - predicted;
        innovations.push(residual);
    }

    // If we need more residuals than we have, resample innovations
    while innovations.len() < n_obs {
        innovations.push(*innovations.choose(rng).unwrap_or(&0.0));
    }

    innovations
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

    // Step 1: Initial optimization
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

    // Compute fitted values and residuals
    let fitted = match crate::shape_functions::eval_shape(
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

                // Re-optimize
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

                // Re-optimize
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

    // Step 1: Initial optimization
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

    // Compute fitted values and residuals
    let fitted = match crate::shape_functions::eval_shape(
        shape_family,
        observed, // depths are assumed to be 1..=observed.len()
        &initial_fit.params,
        false, // ascending
    ) {
        Ok(f) => f,
        Err(e) => {
            result.message = format!("Failed to compute fitted values: {}", e);
            return Ok(result);
        }
    };

    let residuals: Vec<f64> = observed
        .iter()
        .zip(fitted.iter())
        .map(|(o, f)| o - f)
        .collect();

    // Step 2: Bootstrap resampling
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
                    initial_params,
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
                    initial_params,
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

fn perform_initial_optimization(
    observed: &[f64],
    depths: &[f64],
    initial_params: &[f64],
    shape_family: &str,
    objective: &str,
    optimizer: &str,
    fallback_strategy: &str,
    max_retries: usize,
) -> std::result::Result<OptimizationResult, String> {
    // Use the existing optimizer with fallback
    let opt_result = optimize_with_fallback(
        observed,
        depths,
        initial_params,
        shape_family,
        objective,
        optimizer,
        fallback_strategy,
        max_retries,
    )?;

    // Compute diagnostics
    let fitted = crate::shape_functions::eval_shape(
        shape_family,
        depths,
        &opt_result.params,
        false,
    )?;

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

    // Re-optimize
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

#[derive(Debug, Clone)]
struct OptimizationResultInternal {
    params: Vec<f64>,
}

fn optimize_with_fallback(
    observed: &[f64],
    depths: &[f64],
    initial_params: &[f64],
    shape_family: &str,
    objective: &str,
    optimizer: &str,
    fallback_strategy: &str,
    max_retries: usize,
) -> std::result::Result<OptimizationResultInternal, String> {
    let algorithms = match fallback_strategy {
        "auto" => vec!["nelder_mead", "lbfgs", "particle_swarm", "simulated_annealing"],
        "explicit" => vec![optimizer],
        "strict" => vec![optimizer],
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