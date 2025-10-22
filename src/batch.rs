//! Batch processing for multiple soil profiles
//!
//! Provides efficient batch optimization with optional parallelization via rayon.
//! Sequential implementation is always available; parallel paths are optional.
//!
//! # Raster Grid Cell Use Cases
//!
//! For spatial data (e.g., raster stacks where each grid cell has depth-profile data):
//! - Can optimize many independent profiles efficiently
//! - rayon parallelization leverages multi-core for independent cells
//! - Error collection supports spatial debugging (identify problematic cells)
//!
//! # Architecture
//!
//! Separate component functions allow flexible result composition:
//! - `batch_optimize_sequential()` - core processing (always available)
//! - `batch_optimize_parallel_rayon()` - parallel variant (optional, behind cfg)
//! - Component accessors: params, rmse, converged, method per result
//! - `BatchResultBuilder` for convenient struct creation from components

use crate::optimizer::optimize_with_fallback;
use std::sync::Arc;

/// Result of batch optimization for a single profile
#[derive(Debug, Clone)]
pub struct ProfileOptimResult {
    pub profile_id: usize,
    pub params: Option<Vec<f64>>,
    pub final_rmse: f64,
    pub converged: bool,
    pub error: Option<String>,
}

/// Aggregated batch optimization results
///
/// Can be built incrementally or via BatchResultBuilder
#[derive(Debug, Clone)]
pub struct BatchResult {
    pub profile_ids: Vec<usize>,
    pub params: Vec<Option<Vec<f64>>>,
    pub rmse_values: Vec<f64>,
    pub converged: Vec<bool>,
    pub errors: Vec<Option<String>>,
    pub method: String,
    pub failed_count: usize,
}

impl BatchResult {
    /// Get successfully optimized profiles (without errors)
    pub fn successful_ids(&self) -> Vec<usize> {
        self.profile_ids
            .iter()
            .zip(self.errors.iter())
            .filter_map(|(id, err)| if err.is_none() { Some(*id) } else { None })
            .collect()
    }

    /// Get failed profile IDs and their errors
    pub fn failed_profiles(&self) -> Vec<(usize, String)> {
        self.profile_ids
            .iter()
            .zip(self.errors.iter())
            .filter_map(|(id, err)| {
                err.as_ref().map(|e| (*id, e.clone()))
            })
            .collect()
    }

    /// Summary statistics
    pub fn summary(&self) -> String {
        format!(
            "Batch result: {} profiles, {} successful, {} failed, method: {}",
            self.profile_ids.len(),
            self.successful_ids().len(),
            self.failed_count,
            self.method
        )
    }
}

/// Builder for convenient BatchResult construction
pub struct BatchResultBuilder {
    profile_ids: Vec<usize>,
    params: Vec<Option<Vec<f64>>>,
    rmse_values: Vec<f64>,
    converged: Vec<bool>,
    errors: Vec<Option<String>>,
    method: String,
}

impl BatchResultBuilder {
    pub fn new() -> Self {
        Self {
            profile_ids: Vec::new(),
            params: Vec::new(),
            rmse_values: Vec::new(),
            converged: Vec::new(),
            errors: Vec::new(),
            method: String::from("Sequential"),
        }
    }

    pub fn add_success(
        mut self,
        profile_id: usize,
        params: Vec<f64>,
        rmse: f64,
    ) -> Self {
        self.profile_ids.push(profile_id);
        self.params.push(Some(params));
        self.rmse_values.push(rmse);
        self.converged.push(true);
        self.errors.push(None);
        self
    }

    pub fn add_failure(
        mut self,
        profile_id: usize,
        error: String,
    ) -> Self {
        self.profile_ids.push(profile_id);
        self.params.push(None);
        self.rmse_values.push(f64::NAN);
        self.converged.push(false);
        self.errors.push(Some(error));
        self
    }

    pub fn method(mut self, method: &str) -> Self {
        self.method = method.to_string();
        self
    }

    pub fn build(self) -> BatchResult {
        let failed_count = self.errors.iter().filter(|e| e.is_some()).count();
        BatchResult {
            profile_ids: self.profile_ids,
            params: self.params,
            rmse_values: self.rmse_values,
            converged: self.converged,
            errors: self.errors,
            method: self.method,
            failed_count,
        }
    }
}

/// Sequential batch optimization (baseline, always available)
///
/// Processes profiles one-by-one without parallelization.
/// Collects errors for each profile rather than halting on first failure.
///
/// # Arguments
/// * `profiles` - Multiple soil property depth profiles
/// * `initial_params_list` - Initial parameters for each profile (can be single shared params)
/// * `x` - Depth/position vector OR per-profile vectors (see `x_per_profile`)
/// * `shape_type` - Which shape function to fit
/// * `ascending` - Direction flag
/// * `objective` - Objective function trait object
/// * `x_per_profile` - If true, `x` is Vec<Vec<f64>>; if false, single shared vector
///
/// # Returns
/// BatchResult with all fitted parameters, RMSE values, convergence flags, and error details
pub fn batch_optimize_sequential(
    profiles: &[Vec<f64>],
    initial_params_list: &[Vec<f64>],
    x: &[f64],
    shape_type: &str,
    ascending: bool,
    objective: Arc<dyn crate::optimizer::ObjectiveFunction>,
    x_per_profile: bool,
) -> Result<BatchResult, String> {
    if profiles.is_empty() {
        return Err("profiles list is empty".to_string());
    }

    if initial_params_list.len() != profiles.len() {
        return Err(format!(
            "profiles and initial_params_list length mismatch: {} vs {}",
            profiles.len(),
            initial_params_list.len()
        ));
    }

    let mut builder = BatchResultBuilder::new().method("Sequential");

    // Process each profile
    for (i, (profile, init_params)) in profiles.iter().zip(initial_params_list).enumerate() {
        match optimize_with_fallback(
            profile,
            x,
            init_params,
            shape_type,
            ascending,
            objective.clone(),
        ) {
            Ok(result) => {
                builder = builder.add_success(i, result.params.clone(), result.final_cost);
            }
            Err(e) => {
                let error_msg = format!("Optimization failed: {}", e);
                eprintln!("Profile {}: {}", i, error_msg);
                builder = builder.add_failure(i, error_msg);
            }
        }
    }

    Ok(builder.build())
}

/// Parallel batch optimization using rayon
///
/// Processes profiles in parallel across available CPU cores.
/// Requires `rayon-support` feature (default enabled).
///
/// # Arguments
/// Same as `batch_optimize_sequential`
///
/// # Returns
/// BatchResult with results in profile order
#[cfg(feature = "rayon-support")]
pub fn batch_optimize_parallel_rayon(
    profiles: &[Vec<f64>],
    initial_params_list: &[Vec<f64>],
    x: &[f64],
    shape_type: &str,
    ascending: bool,
    objective: Arc<dyn crate::optimizer::ObjectiveFunction>,
) -> Result<BatchResult, String> {
    use rayon::prelude::*;

    if profiles.is_empty() {
        return Err("profiles list is empty".to_string());
    }

    if initial_params_list.len() != profiles.len() {
        return Err("profiles and initial_params_list length mismatch".to_string());
    }

    let x_arc = Arc::new(x.to_vec());
    let shape_type_arc = Arc::new(shape_type.to_string());

    // Parallel iterator over (profile, init_params) pairs
    let results: Vec<ProfileOptimResult> = profiles
        .par_iter()
        .zip(initial_params_list.par_iter())
        .enumerate()
        .map(|(i, (profile, init_params))| {
            match crate::optimizer::optimize_with_fallback(
                profile,
                &x_arc,
                init_params,
                &shape_type_arc,
                ascending,
                objective.clone(),
            ) {
                Ok(result) => ProfileOptimResult {
                    profile_id: i,
                    params: Some(result.params.clone()),
                    final_rmse: result.final_cost,
                    converged: result.converged,
                    error: None,
                },
                Err(e) => {
                    eprintln!("Profile {}: parallel optimization failed: {}", i, e);
                    ProfileOptimResult {
                        profile_id: i,
                        params: None,
                        final_rmse: f64::NAN,
                        converged: false,
                        error: Some(e),
                    }
                }
            }
        })
        .collect();

    // Reconstruct BatchResult from ProfileOptimResult, preserving order
    let mut builder = BatchResultBuilder::new().method("Rayon Parallel");
    for result in results {
        if let Some(params) = result.params {
            builder = builder.add_success(result.profile_id, params, result.final_rmse);
        } else if let Some(error) = result.error {
            builder = builder.add_failure(result.profile_id, error);
        }
    }

    Ok(builder.build())
}

/// Async batch optimization using tokio (exploratory)
///
/// Processes profiles asynchronously.
/// Exploratory for CPU-bound workloads; more useful for future I/O-bound scenarios.
/// Requires `tokio-support` feature.
///
/// # Arguments
/// Same as `batch_optimize_sequential`
///
/// # Note
/// This is **exploratory** and intended for future enhancements
/// (e.g., async data loading, remote optimization).
#[cfg(feature = "tokio-support")]
pub async fn batch_optimize_async_tokio(
    profiles: &[Vec<f64>],
    initial_params_list: &[Vec<f64>],
    x: &[f64],
    shape_type: &str,
    ascending: bool,
    objective: Arc<dyn crate::optimizer::ObjectiveFunction>,
) -> Result<BatchResult, String> {
    if profiles.is_empty() {
        return Err("profiles list is empty".to_string());
    }

    if initial_params_list.len() != profiles.len() {
        return Err("profiles and initial_params_list length mismatch".to_string());
    }

    // Spawn async tasks for each profile
    let mut handles = Vec::new();

    for (i, (profile, init_params)) in profiles.iter().zip(initial_params_list).enumerate() {
        let profile_clone = profile.clone();
        let init_params_clone = init_params.clone();
        let x_clone = x.to_vec();
        let shape_type_clone = shape_type.to_string();
        let objective_clone = objective.clone();

        let handle = tokio::task::spawn_blocking(move || {
            (
                i,
                crate::optimizer::optimize_with_fallback(
                    &profile_clone,
                    &x_clone,
                    &init_params_clone,
                    &shape_type_clone,
                    ascending,
                    objective_clone,
                ),
            )
        });

        handles.push(handle);
    }

    // Collect results as tasks complete
    let mut builder = BatchResultBuilder::new().method("Tokio Async (Exploratory)");

    for handle in handles {
        match handle.await {
            Ok((i, Ok(result))) => {
                builder = builder.add_success(i, result.params.clone(), result.final_cost);
            }
            Ok((i, Err(e))) => {
                builder = builder.add_failure(i, e);
            }
            Err(e) => {
                eprintln!("tokio task join error: {}", e);
                return Err(format!("tokio task failed: {}", e));
            }
        }
    }

    Ok(builder.build())
}

/// Dispatch to batch optimizer based on availability and feature flags
///
/// Priority: rayon parallel (if available) → sequential (fallback)
pub fn batch_optimize(
    profiles: &[Vec<f64>],
    initial_params_list: &[Vec<f64>],
    x: &[f64],
    shape_type: &str,
    ascending: bool,
    objective: Arc<dyn crate::optimizer::ObjectiveFunction>,
) -> Result<BatchResult, String> {
    #[cfg(feature = "rayon-support")]
    {
        return batch_optimize_parallel_rayon(
            profiles,
            initial_params_list,
            x,
            shape_type,
            ascending,
            objective,
        );
    }

    #[cfg(not(feature = "rayon-support"))]
    {
        batch_optimize_sequential(
            profiles,
            initial_params_list,
            x,
            shape_type,
            ascending,
            objective,
            false,
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;

    /// Simple test objective for testing batch processing logic
    struct TestObjective;
    impl crate::optimizer::ObjectiveFunction for TestObjective {
        fn cost(&self, observed: &[f64], predicted: &[f64]) -> f64 {
            (observed.iter().zip(predicted).map(|(o, p)| (o - p).powi(2)).sum::<f64>() / observed.len() as f64).sqrt()
        }
        fn name(&self) -> &'static str { "Test" }
    }

    #[test]
    fn test_batch_sequential_empty() {
        let profiles: Vec<Vec<f64>> = vec![];
        let init_params: Vec<Vec<f64>> = vec![];
        let x: Vec<f64> = (1..=200).map(|i| i as f64).collect();
        let objective = Arc::new(TestObjective);

        let result = batch_optimize_sequential(&profiles, &init_params, &x, "uniform", true, objective, false);
        assert!(result.is_err());
    }

    #[test]
    fn test_batch_sequential_length_mismatch() {
        let profiles = vec![vec![0.5; 200]];
        let init_params: Vec<Vec<f64>> = vec![];
        let x: Vec<f64> = (1..=200).map(|i| i as f64).collect();
        let objective = Arc::new(TestObjective);

        let result = batch_optimize_sequential(&profiles, &init_params, &x, "uniform", true, objective, false);
        assert!(result.is_err());
    }

    #[test]
    fn test_batch_result_builder_success() {
        let builder = BatchResultBuilder::new()
            .add_success(0, vec![10.0, 20.0], 0.5)
            .add_success(1, vec![15.0, 25.0], 0.6)
            .method("Test Sequential");
        
        let result = builder.build();
        assert_eq!(result.profile_ids.len(), 2);
        assert_eq!(result.failed_count, 0);
        assert_eq!(result.successful_ids().len(), 2);
    }

    #[test]
    fn test_batch_result_builder_mixed() {
        let builder = BatchResultBuilder::new()
            .add_success(0, vec![10.0], 0.5)
            .add_failure(1, "Test error".to_string())
            .add_success(2, vec![15.0], 0.6);
        
        let result = builder.build();
        assert_eq!(result.profile_ids.len(), 3);
        assert_eq!(result.failed_count, 1);
        assert_eq!(result.successful_ids().len(), 2);
        assert_eq!(result.failed_profiles().len(), 1);
    }

    #[test]
    fn test_batch_result_summary() {
        let result = BatchResultBuilder::new()
            .add_success(0, vec![10.0], 0.5)
            .add_failure(1, "Error".to_string())
            .build();
        
        let summary = result.summary();
        assert!(summary.contains("2 profiles"));
        assert!(summary.contains("1 successful"));
        assert!(summary.contains("1 failed"));
    }
}
