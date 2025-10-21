//! Single-profile optimization with pluggable objective functions
//!
//! Provides a trait-based architecture where different objective functions
//! (RMSE, SSE, MAE, R²) can be plugged in without modifying optimizer code.
//! 
//! # Architecture
//!
//! - `ObjectiveFunction` trait: Any type implementing cost(&[f64]) -> f64
//! - Concrete implementations: `RmseObjective`, `SseObjective`, `MaeObjective`, `R2Objective`
//! - Optimizer: Direct implementation using simple descent + grid search fallback
//! - Flexibility: New objectives can be added without touching optimizer code

use crate::objective::{rmse, sse, mae, r_squared};
use crate::shape_functions::eval_shape;
use std::f64;
use std::sync::Arc;

/// Result of optimization attempt
#[derive(Debug, Clone)]
pub struct OptimResult {
    pub params: Vec<f64>,
    pub final_cost: f64,
    pub iterations: u64,
    pub converged: bool,
    pub method: String,
}

/// Trait for pluggable objective functions
///
/// Any type implementing this trait can be used with the optimizer.
/// This allows swapping between RMSE, SSE, MAE, R², and custom objectives
/// without modifying optimizer code.
pub trait ObjectiveFunction: Send + Sync {
    /// Compute objective (cost) for given predicted vs observed data
    ///
    /// Lower cost is better (for minimization problems)
    fn cost(&self, observed: &[f64], predicted: &[f64]) -> f64;
    
    /// Get name of objective for logging/diagnostics
    fn name(&self) -> &'static str;
}

/// RMSE (Root Mean Squared Error) objective
pub struct RmseObjective;

impl ObjectiveFunction for RmseObjective {
    fn cost(&self, observed: &[f64], predicted: &[f64]) -> f64 {
        rmse(observed, predicted)
    }
    
    fn name(&self) -> &'static str {
        "RMSE"
    }
}

/// SSE (Sum of Squared Errors) objective
pub struct SseObjective;

impl ObjectiveFunction for SseObjective {
    fn cost(&self, observed: &[f64], predicted: &[f64]) -> f64 {
        sse(observed, predicted)
    }
    
    fn name(&self) -> &'static str {
        "SSE"
    }
}

/// MAE (Mean Absolute Error) objective
pub struct MaeObjective;

impl ObjectiveFunction for MaeObjective {
    fn cost(&self, observed: &[f64], predicted: &[f64]) -> f64 {
        mae(observed, predicted)
    }
    
    fn name(&self) -> &'static str {
        "MAE"
    }
}

/// R² (Coefficient of Determination) objective
/// 
/// Note: For maximization, cost is (1.0 - r2) so we can minimize
pub struct R2Objective;

impl ObjectiveFunction for R2Objective {
    fn cost(&self, observed: &[f64], predicted: &[f64]) -> f64 {
        // Convert to minimization: minimize (1 - r²)
        1.0 - r_squared(observed, predicted)
    }
    
    fn name(&self) -> &'static str {
        "R2-inverse"
    }
}

/// Create objective function by name
///
/// # Arguments
/// * `objective_name` - Name of objective: "rmse", "sse", "mae", "r2"
///
/// # Returns
/// Arc-wrapped trait object, or error for unknown objective
pub fn create_objective(objective_name: &str) -> Result<Arc<dyn ObjectiveFunction>, String> {
    match objective_name.to_lowercase().as_str() {
        "rmse" => Ok(Arc::new(RmseObjective)),
        "sse" => Ok(Arc::new(SseObjective)),
        "mae" => Ok(Arc::new(MaeObjective)),
        "r2" => Ok(Arc::new(R2Objective)),
        _ => Err(format!("Unknown objective: {}", objective_name)),
    }
}

/// Simple derivative-free optimization using Nelder-Mead-like descent
/// 
/// Simplified Nelder-Mead that works without external dependencies,
/// suitable for low-dimensional problems (2-4 parameters)
pub fn optimize_nelder_mead(
    observed: &[f64],
    x: &[f64],
    initial_params: &[f64],
    shape_type: &str,
    ascending: bool,
    objective: Arc<dyn ObjectiveFunction>,
    max_iters: u64,
    tol: f64,
) -> Result<OptimResult, String> {
    if observed.len() != x.len() {
        return Err("observed and x must have same length".to_string());
    }
    if initial_params.is_empty() {
        return Err("initial_params cannot be empty".to_string());
    }

    // Build initial simplex
    let n = initial_params.len();
    let mut simplex = vec![initial_params.to_vec(); n + 1];
    
    // Perturb each coordinate
    let step = 0.1;
    for i in 1..=n {
        simplex[i][i - 1] += step;
    }

    // Evaluate initial simplex
    let mut costs: Vec<f64> = simplex
        .iter()
        .map(|params| {
            match eval_shape(shape_type, x, params, ascending) {
                Ok(pred) => objective.cost(observed, &pred),
                Err(_) => f64::INFINITY,
            }
        })
        .collect();

    let mut best_cost = *costs
        .iter()
        .min_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal))
        .unwrap_or(&f64::INFINITY);
    let mut best_params = simplex[0].clone();
    let mut iterations = 0u64;

    // Nelder-Mead iterations
    for iter in 0..max_iters {
        iterations = iter + 1;

        // Sort simplex by cost
        let mut indices: Vec<usize> = (0..n + 1).collect();
        indices.sort_by(|&a, &b| {
            costs[a]
                .partial_cmp(&costs[b])
                .unwrap_or(std::cmp::Ordering::Equal)
        });

        // Check convergence
        let worst = costs[indices[n]];
        let best = costs[indices[0]];
        if (worst - best).abs() < tol {
            best_params = simplex[indices[0]].clone();
            best_cost = best;
            break;
        }

        // Compute centroid (excluding worst point)
        let mut centroid = vec![0.0; n];
        for i in 0..n {
            for j in 0..n {
                centroid[j] += simplex[indices[i]][j];
            }
        }
        for j in 0..n {
            centroid[j] /= n as f64;
        }

        // Reflection
        let mut reflected = centroid.clone();
        for j in 0..n {
            reflected[j] = centroid[j] + (centroid[j] - simplex[indices[n]][j]);
        }
        let reflected_cost = match eval_shape(shape_type, x, &reflected, ascending) {
            Ok(pred) => objective.cost(observed, &pred),
            Err(_) => f64::INFINITY,
        };

        if reflected_cost < best {
            // Expansion
            let mut expanded = centroid.clone();
            for j in 0..n {
                expanded[j] = centroid[j] + 2.0 * (reflected[j] - centroid[j]);
            }
            let expanded_cost = match eval_shape(shape_type, x, &expanded, ascending) {
                Ok(pred) => objective.cost(observed, &pred),
                Err(_) => f64::INFINITY,
            };

            if expanded_cost < reflected_cost {
                simplex[indices[n]] = expanded;
                costs[indices[n]] = expanded_cost;
            } else {
                simplex[indices[n]] = reflected;
                costs[indices[n]] = reflected_cost;
            }
        } else if reflected_cost < costs[indices[n - 1]] {
            simplex[indices[n]] = reflected;
            costs[indices[n]] = reflected_cost;
        } else {
            // Contraction
            let mut contracted = centroid.clone();
            for j in 0..n {
                contracted[j] = centroid[j] + 0.5 * (simplex[indices[n]][j] - centroid[j]);
            }
            let contracted_cost = match eval_shape(shape_type, x, &contracted, ascending) {
                Ok(pred) => objective.cost(observed, &pred),
                Err(_) => f64::INFINITY,
            };

            if contracted_cost < costs[indices[n]] {
                simplex[indices[n]] = contracted;
                costs[indices[n]] = contracted_cost;
            } else {
                // Shrink
                for i in 1..=n {
                    for j in 0..n {
                        simplex[indices[i]][j] =
                            simplex[indices[0]][j] + 0.5 * (simplex[indices[i]][j] - simplex[indices[0]][j]);
                    }
                }
                for i in 1..=n {
                    costs[indices[i]] = match eval_shape(shape_type, x, &simplex[indices[i]], ascending)
                    {
                        Ok(pred) => objective.cost(observed, &pred),
                        Err(_) => f64::INFINITY,
                    };
                }
            }
        }

        // Track best found
        let current_best = *costs
            .iter()
            .min_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal))
            .unwrap_or(&f64::INFINITY);
        if current_best < best_cost {
            best_cost = current_best;
            let best_idx = costs
                .iter()
                .position(|&c| (c - current_best).abs() < 1e-15)
                .unwrap_or(0);
            best_params = simplex[best_idx].clone();
        }
    }

    Ok(OptimResult {
        params: best_params,
        final_cost: best_cost,
        iterations,
        converged: (iterations as i64) < max_iters as i64,
        method: "Nelder-Mead-Simplified".to_string(),
    })
}

/// Grid search fallback: exhaustive search over parameter space
///
/// Used if Nelder-Mead fails or as a robust starting point.
pub fn optimize_grid_search(
    observed: &[f64],
    x: &[f64],
    param_ranges: &[Vec<f64>],
    shape_type: &str,
    ascending: bool,
    objective: Arc<dyn ObjectiveFunction>,
) -> Result<OptimResult, String> {
    if param_ranges.is_empty() {
        return Err("param_ranges cannot be empty".to_string());
    }

    let mut best_params = vec![0.0; param_ranges.len()];
    let mut best_cost = f64::INFINITY;
    let mut count = 0u64;

    // Grid search: iterate over all combinations recursively
    fn grid_search_recursive(
        depth: usize,
        param_ranges: &[Vec<f64>],
        current_params: &mut Vec<f64>,
        observed: &[f64],
        x: &[f64],
        shape_type: &str,
        ascending: bool,
        objective: &Arc<dyn ObjectiveFunction>,
        best_params: &mut Vec<f64>,
        best_cost: &mut f64,
        count: &mut u64,
    ) -> Result<(), String> {
        if depth == param_ranges.len() {
            // Evaluate this combination
            let pred = eval_shape(shape_type, x, current_params, ascending)
                .map_err(|e| format!("eval_shape failed: {}", e))?;
            let cost = objective.cost(observed, &pred);

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
                objective,
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
        &objective,
        &mut best_params,
        &mut best_cost,
        &mut count,
    )?;

    Ok(OptimResult {
        params: best_params,
        final_cost: best_cost,
        iterations: count,
        converged: true,
        method: format!("Grid-Search({} evals)", count),
    })
}

/// Optimize with automatic fallback strategy
///
/// 1. Try Nelder-Mead with specified objective
/// 2. If fails, try grid search
/// 3. Return best result
///
/// This is the main entry point for optimization with flexible objectives.
pub fn optimize_with_fallback(
    observed: &[f64],
    x: &[f64],
    initial_params: &[f64],
    shape_type: &str,
    ascending: bool,
    objective: Arc<dyn ObjectiveFunction>,
) -> Result<OptimResult, String> {
    // Try Nelder-Mead first
    match optimize_nelder_mead(
        observed,
        x,
        initial_params,
        shape_type,
        ascending,
        objective.clone(),
        1000,
        1e-8,
    ) {
        Ok(result) => {
            if result.converged && result.final_cost.is_finite() {
                return Ok(result);
            }
        }
        Err(e) => {
            eprintln!(
                "Nelder-Mead failed (objective: {}): {}",
                objective.name(),
                e
            );
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
        objective,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_objective_rmse() {
        let result = create_objective("rmse");
        assert!(result.is_ok());
        let obj = result.unwrap();
        assert_eq!(obj.name(), "RMSE");
    }

    #[test]
    fn test_create_objective_sse() {
        let result = create_objective("sse");
        assert!(result.is_ok());
        let obj = result.unwrap();
        assert_eq!(obj.name(), "SSE");
    }

    #[test]
    fn test_create_objective_unknown() {
        let result = create_objective("unknown_objective");
        assert!(result.is_err());
    }

    #[test]
    fn test_rmse_objective() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.1, 2.1, 3.1];
        let obj = RmseObjective;
        let cost = obj.cost(&obs, &pred);
        assert!((cost - 0.1).abs() < 1e-10);
    }

    #[test]
    fn test_sse_objective() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.1, 2.1, 3.1];
        let obj = SseObjective;
        let cost = obj.cost(&obs, &pred);
        assert!((cost - 0.03).abs() < 1e-10);
    }

    #[test]
    fn test_mae_objective() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.1, 2.1, 3.1];
        let obj = MaeObjective;
        let cost = obj.cost(&obs, &pred);
        assert!((cost - 0.1).abs() < 1e-10);
    }

    #[test]
    fn test_optim_result_creation() {
        let result = OptimResult {
            params: vec![100.0, 20.0],
            final_cost: 0.5,
            iterations: 42,
            converged: true,
            method: "Test".to_string(),
        };
        assert_eq!(result.params.len(), 2);
        assert!(result.converged);
    }

    #[test]
    fn test_grid_search_simple_rmse() {
        // Create synthetic data: uniform level 0.5
        let x: Vec<f64> = (1..=200).map(|i| i as f64).collect();
        let observed = vec![0.5; 200];
        let param_ranges = vec![vec![0.0, 0.5, 1.0]];
        let objective = create_objective("rmse").unwrap();

        let result = optimize_grid_search(
            &observed,
            &x,
            &param_ranges,
            "uniform",
            true,
            objective,
        );

        assert!(result.is_ok());
        let result = result.unwrap();
        assert!(result.final_cost < 0.01); // Should fit well
    }

    #[test]
    fn test_grid_search_simple_sse() {
        // Same test with SSE objective
        let x: Vec<f64> = (1..=200).map(|i| i as f64).collect();
        let observed = vec![0.5; 200];
        let param_ranges = vec![vec![0.0, 0.5, 1.0]];
        let objective = create_objective("sse").unwrap();

        let result = optimize_grid_search(
            &observed,
            &x,
            &param_ranges,
            "uniform",
            true,
            objective,
        );

        assert!(result.is_ok());
    }

    #[test]
    fn test_nelder_mead_simple_rmse() {
        // Create synthetic data: uniform level 0.6
        let x: Vec<f64> = (1..=200).map(|i| i as f64).collect();
        let observed = vec![0.6; 200];
        let initial_par = vec![0.3]; // Poor guess
        let objective = create_objective("rmse").unwrap();

        let result = optimize_nelder_mead(
            &observed,
            &x,
            &initial_par,
            "uniform",
            true,
            objective,
            100,
            1e-6,
        );

        assert!(result.is_ok());
        let result = result.unwrap();
        // Should find level ~0.6
        assert!((result.params[0] - 0.6).abs() < 0.01);
    }
}
