//! Single-profile optimization with pluggable objective functions
//!
//! Provides a trait-based architecture where different objective functions
//! (RMSE, SSE, MAE, R²) can be plugged in without modifying optimizer code.
//! 
//! # Architecture
//!
//! - `ObjectiveFunction` trait: Any type implementing cost(&[f64]) -> f64
//! - Concrete implementations: `RmseObjective`, `SseObjective`, `MaeObjective`, `R2Objective`
//! - Optimizer: Custom optimization with argmin framework prepared for Phase 3
//! - Flexibility: New objectives can be added without touching optimizer code

use crate::objective::{rmse, sse, mae, r_squared};
use crate::shape_functions::{eval_shape, eval_shape_gradient};
use argmin::core::*;
use argmin::solver::neldermead::NelderMead;
use argmin::solver::simulatedannealing::{SimulatedAnnealing, SATempFunc};
use argmin::solver::quasinewton::LBFGS;
use argmin::solver::particleswarm::ParticleSwarm;
use rand::Rng;
use std::f64;
use std::sync::Arc;

// Implement required math traits for Vec<f64> to work with argmin solvers
// Note: argmin provides native support for Vec<f64>, so no custom wrapper needed

/// Algorithm types available for optimization
#[derive(Debug, Clone, PartialEq)]
pub enum AlgorithmType {
    /// Nelder-Mead simplex method (gradient-free, robust)
    NelderMead,
    /// Simulated Annealing (probabilistic, escapes local minima)
    SimulatedAnnealing,
    /// L-BFGS quasi-Newton method (gradient-based, fast convergence)
    LBFGS,
    /// Particle Swarm Optimization (population-based, global search)
    ParticleSwarm,
}

/// Parameters for configuring objective functions
#[derive(Debug, Clone)]
pub enum ObjectiveParams {
    /// Basic objectives without parameters (RMSE, SSE, MAE, R2)
    Basic,
    /// Depth-weighted RMSE with Gaussian weighting
    Weighted { target_depth: f64, weight_factor: f64 },
    /// Ordinal error with asymmetric penalties
    Ordinal { underpredict_penalty: f64, overpredict_penalty: f64 },
    /// Bounded error with penalties for out-of-bounds predictions
    Bounded { obs_min: f64, obs_max: f64, penalty_factor: f64 },
    /// Huber loss for robust regression
    Huber { delta: f64 },
    /// Quantile loss for quantile regression
    Quantile { quantile: f64 },
}

/// Result of optimization attempt
#[derive(Debug, Clone)]
pub struct OptimResult {
    pub params: Vec<f64>,
    pub final_cost: f64,
    pub iterations: u64,
    pub converged: bool,
    pub method: String,
    pub lower_bounds: Option<Vec<f64>>,
    pub upper_bounds: Option<Vec<f64>>,
}

/// Wrapper to implement argmin::CostFunction for shape optimization
///
/// Holds the observed data, shape parameters, and objective function
/// to enable argmin-based optimization.
#[derive(Clone)]
struct ShapeCostFunction {
    observed: Vec<f64>,
    x: Vec<f64>,
    shape_type: String,
    ascending: bool,
    objective: Arc<dyn ObjectiveFunction>,
}

impl CostFunction for ShapeCostFunction {
    type Param = Vec<f64>;
    type Output = f64;

    fn cost(&self, param: &Self::Param) -> Result<Self::Output, Error> {
        match eval_shape(&self.shape_type, &self.x, param, self.ascending) {
            Ok(predicted) => Ok(self.objective.cost(&self.observed, &predicted, &self.x)),
            Err(e) => Err(Error::msg(format!("Shape evaluation error: {}", e))),
        }
    }
}

/// Implement Gradient trait for gradient-based optimization
impl Gradient for ShapeCostFunction {
    type Param = Vec<f64>;
    type Gradient = Vec<f64>;

    fn gradient(&self, param: &Self::Param) -> Result<Self::Gradient, Error> {
        // Get shape gradients: ∂shape/∂params
        let shape_gradients = eval_shape_gradient(&self.shape_type, &self.x, param, self.ascending)
            .map_err(|e| Error::msg(format!("Gradient evaluation error: {}", e)))?;

        // Get predicted values
        let predicted = eval_shape(&self.shape_type, &self.x, param, self.ascending)
            .map_err(|e| Error::msg(format!("Shape evaluation error: {}", e)))?;

        // Compute gradient of cost function using chain rule
        // For RMSE: ∂RMSE/∂θ = (1/n) * Σ[(predicted - observed) * ∂predicted/∂θ]
        let n = self.observed.len() as f64;
        let mut grad = vec![0.0; param.len()];

        for j in 0..param.len() {
            let mut sum = 0.0;
            for i in 0..self.observed.len() {
                let residual = predicted[i] - self.observed[i];
                // shape_gradients[i][j] = ∂shape(x[i])/∂param[j]
                sum += residual * shape_gradients[i][j];
            }
            // For RMSE gradient
            let current_cost = self.cost(param).unwrap_or(1.0);
            grad[j] = if current_cost > 1e-10 {
                sum / (n * current_cost)
            } else {
                sum / n
            };
        }

        Ok(grad)
    }
}

/// Implement Anneal trait for Simulated Annealing
impl argmin::solver::simulatedannealing::Anneal for ShapeCostFunction {
    type Param = Vec<f64>;
    type Output = Vec<f64>;
    type Float = f64;

    fn anneal(&self, param: &Self::Param, extent: Self::Float) -> Result<Self::Output, Error> {
        // Perturb each parameter by a random amount scaled by extent
        let mut rng = rand::thread_rng();
        let perturbed: Vec<f64> = param
            .iter()
            .map(|&p| {
                // Random perturbation in range [-extent, +extent]
                let delta = (rng.gen::<f64>() - 0.5) * 2.0 * extent;
                // Ensure parameters stay positive (most soil parameters are positive)
                (p + delta).max(0.1)
            })
            .collect();
        Ok(perturbed)
    }
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
    fn cost(&self, observed: &[f64], predicted: &[f64], depths: &[f64]) -> f64;
    
    /// Get name of objective for logging/diagnostics
    fn name(&self) -> &'static str;
}

/// RMSE (Root Mean Squared Error) objective
pub struct RmseObjective;

impl ObjectiveFunction for RmseObjective {
    fn cost(&self, observed: &[f64], predicted: &[f64], _depths: &[f64]) -> f64 {
        rmse(observed, predicted)
    }
    
    fn name(&self) -> &'static str {
        "RMSE"
    }
}

/// SSE (Sum of Squared Errors) objective
pub struct SseObjective;

impl ObjectiveFunction for SseObjective {
    fn cost(&self, observed: &[f64], predicted: &[f64], _depths: &[f64]) -> f64 {
        sse(observed, predicted)
    }
    
    fn name(&self) -> &'static str {
        "SSE"
    }
}

/// MAE (Mean Absolute Error) objective
pub struct MaeObjective;

impl ObjectiveFunction for MaeObjective {
    fn cost(&self, observed: &[f64], predicted: &[f64], _depths: &[f64]) -> f64 {
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
    fn cost(&self, observed: &[f64], predicted: &[f64], _depths: &[f64]) -> f64 {
        // Convert to minimization: minimize (1 - r²)
        1.0 - r_squared(observed, predicted)
    }
    
    fn name(&self) -> &'static str {
        "R2-inverse"
    }
}

/// Depth-weighted RMSE with Gaussian weighting centered on target depth
#[derive(Clone, Debug)]
pub struct WeightedRMSE {
    pub target_depth: f64,
    pub weight_factor: f64,
}

impl ObjectiveFunction for WeightedRMSE {
    fn cost(&self, observed: &[f64], predicted: &[f64], depths: &[f64]) -> f64 {
        assert_eq!(observed.len(), predicted.len(), "observed and predicted must have same length");
        assert_eq!(observed.len(), depths.len(), "observed and depths must have same length");
        
        let _n = observed.len() as f64;
        let mut weighted_sum_sq = 0.0;
        let mut sum_weights = 0.0;
        
        for i in 0..observed.len() {
            let weight = (-self.weight_factor * (depths[i] - self.target_depth).powi(2)).exp();
            let residual_sq = (observed[i] - predicted[i]).powi(2);
            weighted_sum_sq += weight * residual_sq;
            sum_weights += weight;
        }
        
        if sum_weights > 0.0 {
            (weighted_sum_sq / sum_weights).sqrt()
        } else {
            0.0
        }
    }
    
    fn name(&self) -> &'static str {
        "WeightedRMSE"
    }
}

/// Ordinal error with asymmetric penalties for over/under prediction
#[derive(Clone, Debug)]
pub struct OrdinalError {
    pub underpredict_penalty: f64,
    pub overpredict_penalty: f64,
}

impl ObjectiveFunction for OrdinalError {
    fn cost(&self, observed: &[f64], predicted: &[f64], _depths: &[f64]) -> f64 {
        assert_eq!(observed.len(), predicted.len(), "observed and predicted must have same length");
        
        let n = observed.len() as f64;
        let mut total_cost = 0.0;
        
        for i in 0..observed.len() {
            let residual = observed[i] - predicted[i];
            if residual > 0.0 {
                // Under-prediction: predicted < observed
                total_cost += self.underpredict_penalty * residual.abs();
            } else {
                // Over-prediction: predicted > observed
                total_cost += self.overpredict_penalty * residual.abs();
            }
        }
        
        total_cost / n
    }
    
    fn name(&self) -> &'static str {
        "OrdinalError"
    }
}

/// Bounded error with penalties for predictions outside physical bounds
#[derive(Clone, Debug)]
pub struct BoundedError {
    pub obs_min: f64,
    pub obs_max: f64,
    pub penalty_factor: f64,
}

impl ObjectiveFunction for BoundedError {
    fn cost(&self, observed: &[f64], predicted: &[f64], _depths: &[f64]) -> f64 {
        assert_eq!(observed.len(), predicted.len(), "observed and predicted must have same length");
        
        let n = observed.len() as f64;
        let mut total_cost = 0.0;
        
        for i in 0..observed.len() {
            let residual = observed[i] - predicted[i];
            let residual_sq = residual.powi(2);
            
            // Check if prediction is out of bounds
            let pred = predicted[i];
            if pred < self.obs_min || pred > self.obs_max {
                // Apply penalty for out-of-bounds prediction
                total_cost += self.penalty_factor * residual_sq;
            } else {
                // Normal squared error
                total_cost += residual_sq;
            }
        }
        
        (total_cost / n).sqrt()
    }
    
    fn name(&self) -> &'static str {
        "BoundedError"
    }
}

/// Huber loss for robust regression with smooth transition between quadratic and linear
#[derive(Clone, Debug)]
pub struct HuberLoss {
    pub delta: f64,
}

impl ObjectiveFunction for HuberLoss {
    fn cost(&self, observed: &[f64], predicted: &[f64], _depths: &[f64]) -> f64 {
        assert_eq!(observed.len(), predicted.len(), "observed and predicted must have same length");
        
        let n = observed.len() as f64;
        let mut total_cost = 0.0;
        
        for i in 0..observed.len() {
            let residual = (observed[i] - predicted[i]).abs();
            if residual <= self.delta {
                // Quadratic loss for small residuals
                total_cost += 0.5 * residual.powi(2);
            } else {
                // Linear loss for large residuals
                total_cost += self.delta * residual - 0.5 * self.delta.powi(2);
            }
        }
        
        total_cost / n
    }
    
    fn name(&self) -> &'static str {
        "HuberLoss"
    }
}

/// Quantile loss for quantile regression (asymmetric penalty based on quantile)
#[derive(Clone, Debug)]
pub struct QuantileLoss {
    pub quantile: f64,
}

impl ObjectiveFunction for QuantileLoss {
    fn cost(&self, observed: &[f64], predicted: &[f64], _depths: &[f64]) -> f64 {
        assert_eq!(observed.len(), predicted.len(), "observed and predicted must have same length");
        assert!(self.quantile > 0.0 && self.quantile < 1.0, "quantile must be between 0 and 1");
        
        let n = observed.len() as f64;
        let mut total_cost = 0.0;
        
        for i in 0..observed.len() {
            let residual = observed[i] - predicted[i];
            if residual > 0.0 {
                // Under-prediction penalty
                total_cost += self.quantile * residual;
            } else {
                // Over-prediction penalty
                total_cost += (1.0 - self.quantile) * residual.abs();
            }
        }
        
        total_cost / n
    }
    
    fn name(&self) -> &'static str {
        "QuantileLoss"
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
    create_objective_with_params(objective_name, &ObjectiveParams::Basic)
}

/// Create objective function with parameters
///
/// # Arguments
/// * `objective_name` - Name of objective type
/// * `params` - Parameters for the objective function
///
/// # Returns
/// Arc-wrapped trait object, or error for unknown objective or invalid params
pub fn create_objective_with_params(objective_name: &str, params: &ObjectiveParams) -> Result<Arc<dyn ObjectiveFunction>, String> {
    match (objective_name.to_lowercase().as_str(), params) {
        ("rmse", ObjectiveParams::Basic) => Ok(Arc::new(RmseObjective)),
        ("sse", ObjectiveParams::Basic) => Ok(Arc::new(SseObjective)),
        ("mae", ObjectiveParams::Basic) => Ok(Arc::new(MaeObjective)),
        ("r2", ObjectiveParams::Basic) => Ok(Arc::new(R2Objective)),
        ("weighted_rmse", ObjectiveParams::Weighted { target_depth, weight_factor }) => {
            Ok(Arc::new(WeightedRMSE { target_depth: *target_depth, weight_factor: *weight_factor }))
        },
        ("ordinal", ObjectiveParams::Ordinal { underpredict_penalty, overpredict_penalty }) => {
            Ok(Arc::new(OrdinalError { underpredict_penalty: *underpredict_penalty, overpredict_penalty: *overpredict_penalty }))
        },
        ("bounded", ObjectiveParams::Bounded { obs_min, obs_max, penalty_factor }) => {
            Ok(Arc::new(BoundedError { obs_min: *obs_min, obs_max: *obs_max, penalty_factor: *penalty_factor }))
        },
        ("huber", ObjectiveParams::Huber { delta }) => {
            Ok(Arc::new(HuberLoss { delta: *delta }))
        },
        ("quantile", ObjectiveParams::Quantile { quantile }) => {
            Ok(Arc::new(QuantileLoss { quantile: *quantile }))
        },
        _ => Err(format!("Unknown objective: {} with given parameters", objective_name)),
    }
}

/// Optimize using argmin's Nelder-Mead solver
/// 
/// Uses argmin's battle-tested Nelder-Mead implementation instead of custom code
pub fn optimize_nelder_mead(
    observed: &[f64],
    x: &[f64],
    initial_params: &[f64],
    shape_type: &str,
    ascending: bool,
    objective: Arc<dyn ObjectiveFunction>,
    max_iters: u64,
    _tol: f64,
) -> Result<OptimResult, String> {
    if observed.len() != x.len() {
        return Err("observed and x must have same length".to_string());
    }
    if initial_params.is_empty() {
        return Err("initial_params cannot be empty".to_string());
    }

    // Create the cost function wrapper
    let cost_fn = ShapeCostFunction {
        observed: observed.to_vec(),
        x: x.to_vec(),
        shape_type: shape_type.to_string(),
        ascending,
        objective: objective.clone(),
    };

    // Create proper initial simplex for Nelder-Mead
    // Need n+1 points for n-dimensional optimization
    let n_params = initial_params.len();
    let mut simplex = Vec::with_capacity(n_params + 1);
    
    // First simplex point: the initial parameters
    simplex.push(initial_params.to_vec());
    
    // Remaining points: perturbed versions (standard Nelder-Mead initialization)
    for i in 0..n_params {
        let mut point = initial_params.to_vec();
        point[i] += 0.1 * (initial_params[i].abs().max(1.0));
        simplex.push(point);
    }

    // Create Nelder-Mead solver with the full simplex
    let solver = NelderMead::<Vec<f64>, f64>::new(simplex);

    // Set up executor - crucially, sync the state with the solver's initial point
    let executor = Executor::new(cost_fn, solver)
        .configure(|state| {
            state
                .param(initial_params.to_vec())
                .max_iters(max_iters as u64)
        });

    // Run optimization
    let result = executor.run()
        .map_err(|e| format!("Optimization failed: {:?}", e))?;

    // Extract results safely - use correct argmin state accessors
    let state = result.state();
    let best_param = state.get_best_param()
        .cloned()
        .unwrap_or_else(|| initial_params.to_vec());
    let final_cost = state.get_best_cost();
    
    // Correctly extract iteration count from argmin state
    // For convergence: if we got a result with finite cost, consider it converged
    let iterations = state.get_iter();
    let converged = final_cost.is_finite();

    Ok(OptimResult {
        params: best_param,
        final_cost,
        iterations,
        converged,
        method: "NelderMead-argmin".to_string(),
        lower_bounds: None,
        upper_bounds: None,
    })
}

/// Recommend optimization algorithm based on problem characteristics
///
/// # Arguments
/// * `n_params` - Number of parameters to optimize
/// * `n_obs` - Number of observations
/// * `objective_type` - Type of objective function ("rmse", "weighted_rmse", etc.)
///
/// # Returns
/// Recommended AlgorithmType
///
/// # Selection Logic
/// - **1 param**: Nelder-Mead (simple, grid search fallback available)
/// - **2-3 params, smooth objective**: L-BFGS (fast gradient-based convergence)
/// - **2-3 params, complex objective**: Nelder-Mead (robust gradient-free)
/// - **4 params, smooth objective**: L-BFGS (scales well with gradients)
/// - **4 params, complex objective**: Particle Swarm (global population-based search)
/// - **5+ params, any objective**: Particle Swarm (handles high-dimensional spaces)
pub fn recommend_algorithm(n_params: usize, _n_obs: usize, objective_type: &str) -> AlgorithmType {
    // Check for complex objectives that might have multiple local minima
    let is_complex_objective = matches!(
        objective_type.to_lowercase().as_str(),
        "huber" | "quantile" | "ordinal" | "bounded"
    );

    // Selection logic based on problem characteristics
    match (n_params, is_complex_objective) {
        // 1D problems: Use Nelder-Mead (has grid search fallback in optimize_with_fallback)
        (1, _) => AlgorithmType::NelderMead,

        // 2-3 params with smooth objectives: L-BFGS for fast convergence
        (2..=3, false) => AlgorithmType::LBFGS,

        // 2-3 params with complex objectives: Nelder-Mead is robust
        (2..=3, true) => AlgorithmType::NelderMead,

        // 4 params with smooth objectives: L-BFGS scales well
        (4, false) => AlgorithmType::LBFGS,

        // 4 params with complex objectives: Particle Swarm for global search
        (4, true) => AlgorithmType::ParticleSwarm,

        // 5+ params: Particle Swarm handles high-dimensional spaces well
        (5.., _) => AlgorithmType::ParticleSwarm,

        // Default fallback
        _ => AlgorithmType::NelderMead,
    }
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
            let cost = objective.cost(observed, &pred, x);

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
        lower_bounds: None,
        upper_bounds: None,
    })
}

/// Optimize using L-BFGS quasi-Newton method
///
/// L-BFGS uses gradient information for fast convergence on smooth objectives
pub fn optimize_lbfgs(
    observed: &[f64],
    x: &[f64],
    initial_params: &[f64],
    shape_type: &str,
    ascending: bool,
    objective: Arc<dyn ObjectiveFunction>,
    max_iters: u64,
) -> Result<OptimResult, String> {
    if observed.len() != x.len() {
        return Err("observed and x must have same length".to_string());
    }
    if initial_params.is_empty() {
        return Err("initial_params cannot be empty".to_string());
    }

    // Create the cost function wrapper
    let cost_fn = ShapeCostFunction {
        observed: observed.to_vec(),
        x: x.to_vec(),
        shape_type: shape_type.to_string(),
        ascending,
        objective: objective.clone(),
    };

    // Create L-BFGS solver
    // m = 7 is a common choice for memory size (number of past gradients to store)
    let linesearch = argmin::solver::linesearch::MoreThuenteLineSearch::new();
    let solver = LBFGS::new(linesearch, 7);

    // Set up executor
    let executor = Executor::new(cost_fn, solver)
        .configure(|state| {
            state
                .param(initial_params.to_vec())
                .max_iters(max_iters)
        });

    // Run optimization
    let result = executor.run()
        .map_err(|e| format!("L-BFGS optimization failed: {:?}", e))?;

    // Extract results
    let state = result.state();
    let best_param = state.get_best_param()
        .cloned()
        .unwrap_or_else(|| initial_params.to_vec());
    let final_cost = state.get_best_cost();
    let iterations = state.get_iter();
    let converged = final_cost.is_finite();

    Ok(OptimResult {
        params: best_param,
        final_cost,
        iterations,
        converged,
        method: "L-BFGS".to_string(),
        lower_bounds: None,
        upper_bounds: None,
    })
}

/// Optimize using Particle Swarm Optimization
///
/// PSO is a population-based global optimization method that works well for multi-modal problems
pub fn optimize_particle_swarm(
    observed: &[f64],
    x: &[f64],
    initial_params: &[f64],
    shape_type: &str,
    ascending: bool,
    objective: Arc<dyn ObjectiveFunction>,
    max_iters: u64,
) -> Result<OptimResult, String> {
    if observed.len() != x.len() {
        return Err("observed and x must have same length".to_string());
    }
    if initial_params.is_empty() {
        return Err("initial_params cannot be empty".to_string());
    }

    // Create the cost function wrapper
    let cost_fn = ShapeCostFunction {
        observed: observed.to_vec(),
        x: x.to_vec(),
        shape_type: shape_type.to_string(),
        ascending,
        objective: objective.clone(),
    };

    // Define search bounds (reasonable ranges for soil parameters)
    let n_params = initial_params.len();
    let lower_bounds: Vec<f64> = initial_params.iter().map(|&p| (p * 0.1).max(0.1)).collect();
    let upper_bounds: Vec<f64> = initial_params.iter().map(|&p| (p * 3.0).max(100.0)).collect();

    // Create Particle Swarm solver
    // Population size: 10 * number of parameters (standard heuristic)
    let population_size = (10 * n_params).max(20);
    let solver = ParticleSwarm::new((lower_bounds.clone(), upper_bounds.clone()), population_size);

    // Set up executor
    let executor = Executor::new(cost_fn, solver)
        .configure(|state| {
            state.max_iters(max_iters)
        });

    // Run optimization
    let result = executor.run()
        .map_err(|e| format!("Particle Swarm optimization failed: {:?}", e))?;

    // Extract results
    let state = result.state();
    // Get the population (list of particles) and find the best one
    let population = state.get_population()
        .ok_or_else(|| "No population found".to_string())?;

    // The population is sorted, so first particle is the best
    let best_particle = population.first()
        .ok_or_else(|| "Empty population".to_string())?;

    let best_param = best_particle.position.clone();
    let final_cost = best_particle.cost;
    let iterations = state.get_iter();
    let converged = final_cost.is_finite();

    Ok(OptimResult {
        params: best_param,
        final_cost,
        iterations,
        converged,
        method: "ParticleSwarm".to_string(),
        lower_bounds: Some(lower_bounds),
        upper_bounds: Some(upper_bounds),
    })
}

/// Optimize using Simulated Annealing
///
/// SA is a probabilistic method that can escape local minima, useful for multi-modal landscapes
pub fn optimize_simulated_annealing(
    observed: &[f64],
    x: &[f64],
    initial_params: &[f64],
    shape_type: &str,
    ascending: bool,
    objective: Arc<dyn ObjectiveFunction>,
    max_iters: u64,
) -> Result<OptimResult, String> {
    if observed.len() != x.len() {
        return Err("observed and x must have same length".to_string());
    }
    if initial_params.is_empty() {
        return Err("initial_params cannot be empty".to_string());
    }

    // Create the cost function wrapper
    let cost_fn = ShapeCostFunction {
        observed: observed.to_vec(),
        x: x.to_vec(),
        shape_type: shape_type.to_string(),
        ascending,
        objective: objective.clone(),
    };

    // Create Simulated Annealing solver
    // Initial temperature based on parameter scale
    let initial_temp = initial_params.iter().map(|&p| p.abs()).sum::<f64>() / initial_params.len() as f64;
    let solver = SimulatedAnnealing::new(initial_temp.max(10.0))
        .map_err(|e| format!("Failed to create SA solver: {:?}", e))?
        .with_temp_func(SATempFunc::Exponential(0.95)); // Exponential cooling with rate 0.95

    // Set up executor
    let executor = Executor::new(cost_fn, solver)
        .configure(|state| {
            state
                .param(initial_params.to_vec())
                .max_iters(max_iters)
        });

    // Run optimization
    let result = executor.run()
        .map_err(|e| format!("Simulated Annealing optimization failed: {:?}", e))?;

    // Extract results
    let state = result.state();
    let best_param = state.get_best_param()
        .cloned()
        .unwrap_or_else(|| initial_params.to_vec());
    let final_cost = state.get_best_cost();
    let iterations = state.get_iter();
    let converged = final_cost.is_finite();

    Ok(OptimResult {
        params: best_param,
        final_cost,
        iterations,
        converged,
        method: "SimulatedAnnealing".to_string(),
        lower_bounds: None,
        upper_bounds: None,
    })
}

/// Optimize with specified algorithm
///
/// Dispatches to the appropriate optimization algorithm based on AlgorithmType
pub fn optimize_with_algorithm(
    observed: &[f64],
    x: &[f64],
    initial_params: &[f64],
    shape_type: &str,
    ascending: bool,
    objective: Arc<dyn ObjectiveFunction>,
    algorithm: AlgorithmType,
) -> Result<OptimResult, String> {
    match algorithm {
        AlgorithmType::NelderMead => optimize_nelder_mead(
            observed, x, initial_params, shape_type, ascending, objective, 1000, 1e-8
        ),
        AlgorithmType::LBFGS => optimize_lbfgs(
            observed, x, initial_params, shape_type, ascending, objective, 1000
        ),
        AlgorithmType::ParticleSwarm => optimize_particle_swarm(
            observed, x, initial_params, shape_type, ascending, objective, 100
        ),
        AlgorithmType::SimulatedAnnealing => optimize_simulated_annealing(
            observed, x, initial_params, shape_type, ascending, objective, 1000
        ),
    }
}

/// Optimize with automatic fallback strategy
///
/// 1. For 1D problems: use grid search (argmin NelderMead has bugs with 1D)
/// 2. For N>1D: Try Nelder-Mead first
/// 3. If Nelder-Mead fails: fall back to grid search
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
    // Special case: 1-dimensional problems
    // argmin's NelderMead has issues with 1D (underflow in simplex indexing)
    // Grid search is more robust and efficient for single-parameter optimization
    if initial_params.len() == 1 {

        // Define reasonable parameter ranges for 1D grid search
        let param_ranges = match shape_type {
            // Uniform shape: single parameter typically in range [0, 1]
            "uniform" => vec![vec![0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]],
            // Other shapes: search around initial parameter
            _ => vec![vec![
                (initial_params[0] - 50.0).max(0.1),
                initial_params[0] - 25.0,
                initial_params[0],
                initial_params[0] + 25.0,
                initial_params[0] + 50.0,
            ]],
        };

        return optimize_grid_search(
            observed,
            x,
            &param_ranges,
            shape_type,
            ascending,
            objective,
        );
    }

    // For N > 1 dimensions: Try Nelder-Mead first (most robust)
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
        Err(_e) => {
            // Nelder-Mead failed, fall back to grid search
        }
    }

    // Fallback: grid search for N > 1 dimensional problems
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
        let depths = vec![1.0, 2.0, 3.0];
        let obj = RmseObjective;
        let cost = obj.cost(&obs, &pred, &depths);
        assert!((cost - 0.1).abs() < 1e-10);
    }

    #[test]
    fn test_sse_objective() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.1, 2.1, 3.1];
        let depths = vec![1.0, 2.0, 3.0];
        let obj = SseObjective;
        let cost = obj.cost(&obs, &pred, &depths);
        assert!((cost - 0.03).abs() < 1e-10);
    }

    #[test]
    fn test_mae_objective() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.1, 2.1, 3.1];
        let depths = vec![1.0, 2.0, 3.0];
        let obj = MaeObjective;
        let cost = obj.cost(&obs, &pred, &depths);
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
            lower_bounds: None,
            upper_bounds: None,
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
        // Should find level close to 0.6 (Nelder-Mead may not be exact)
        assert!((result.params[0] - 0.6).abs() < 0.05);
        assert!(result.final_cost < 0.1); // Should have low error
    }

    #[test]
    fn test_weighted_rmse() {
        let obs = vec![1.0, 2.0, 3.0, 4.0, 5.0];
        let pred = vec![1.1, 2.1, 3.1, 4.1, 5.1];
        let depths = vec![1.0, 2.0, 3.0, 4.0, 5.0];
        let obj = WeightedRMSE { target_depth: 3.0, weight_factor: 1.0 };
        let cost = obj.cost(&obs, &pred, &depths);
        // Should be approximately 0.1 (same as unweighted for this case)
        assert!((cost - 0.1).abs() < 0.01);
    }

    #[test]
    fn test_ordinal_error() {
        let obs = vec![2.0, 2.0, 2.0];
        let pred = vec![1.0, 2.0, 3.0]; // Under, exact, over
        let depths = vec![1.0, 2.0, 3.0];
        let obj = OrdinalError { underpredict_penalty: 2.0, overpredict_penalty: 1.0 };
        let cost = obj.cost(&obs, &pred, &depths);
        // Under-prediction (1.0) gets 2.0 * 1.0 = 2.0
        // Over-prediction (1.0) gets 1.0 * 1.0 = 1.0
        // Total cost = (2.0 + 0.0 + 1.0) / 3 = 1.0
        assert!((cost - 1.0).abs() < 1e-10);
    }

    #[test]
    fn test_bounded_error() {
        let obs = vec![5.0, 5.0, 5.0];
        let pred = vec![3.0, 5.0, 7.0]; // Out of bounds, in bounds, out of bounds
        let depths = vec![1.0, 2.0, 3.0];
        let obj = BoundedError { obs_min: 4.0, obs_max: 6.0, penalty_factor: 10.0 };
        let cost = obj.cost(&obs, &pred, &depths);
        // RMSE would be sqrt((4+0+4)/3) = sqrt(8/3) ≈ 1.63
        // But with penalty: sqrt((4*10 + 0 + 4*10)/3) = sqrt(80/3) ≈ 5.16
        assert!(cost > 4.0); // Should be higher due to penalty
    }

    #[test]
    fn test_huber_loss() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.5, 2.5, 3.5]; // Residuals of 0.5 each
        let depths = vec![1.0, 2.0, 3.0];
        let obj = HuberLoss { delta: 1.0 };
        let cost = obj.cost(&obs, &pred, &depths);
        // All residuals <= delta, so quadratic: 0.5 * (0.5^2 * 3) / 3 = 0.5 * 0.75 / 3 wait
        // For each: 0.5 * 0.5^2 = 0.125, total 0.375, divided by 3 = 0.125
        assert!((cost - 0.125).abs() < 1e-10);
    }

    #[test]
    fn test_quantile_loss() {
        let obs = vec![2.0, 2.0, 2.0];
        let pred = vec![1.0, 2.0, 3.0]; // Under, exact, over
        let depths = vec![1.0, 2.0, 3.0];
        let obj = QuantileLoss { quantile: 0.9 }; // Conservative (high) estimates
        let cost = obj.cost(&obs, &pred, &depths);
        // Under: 0.9 * 1.0 = 0.9
        // Over: 0.1 * 1.0 = 0.1
        // Total: (0.9 + 0.0 + 0.1) / 3 = 1.0 / 3 ≈ 0.333
        assert!((cost - (1.0 / 3.0)).abs() < 1e-10);
    }

    #[test]
    fn test_create_objective_weighted_rmse() {
        let params = ObjectiveParams::Weighted { target_depth: 100.0, weight_factor: 2.0 };
        let result = create_objective_with_params("weighted_rmse", &params);
        assert!(result.is_ok());
        let obj = result.unwrap();
        assert_eq!(obj.name(), "WeightedRMSE");
    }

    #[test]
    fn test_create_objective_ordinal() {
        let params = ObjectiveParams::Ordinal { underpredict_penalty: 1.5, overpredict_penalty: 1.0 };
        let result = create_objective_with_params("ordinal", &params);
        assert!(result.is_ok());
        let obj = result.unwrap();
        assert_eq!(obj.name(), "OrdinalError");
    }

    #[test]
    fn test_simulated_annealing_basic() {
        // Create synthetic data: uniform level 0.6
        let x: Vec<f64> = (1..=200).map(|i| i as f64).collect();
        let observed = vec![0.6; 200];
        let initial_par = vec![0.3]; // Poor guess
        let objective = create_objective("rmse").unwrap();

        let result = optimize_simulated_annealing(
            &observed,
            &x,
            &initial_par,
            "uniform",
            true,
            objective,
            500, // Reduced iterations for test speed
        );

        assert!(result.is_ok());
        let result = result.unwrap();
        // SA should find a reasonable solution (within 0.2 of target)
        assert!((result.params[0] - 0.6).abs() < 0.2);
        assert!(result.final_cost < 0.3); // Should have low error
    }

    #[test]
    fn test_recommend_algorithm() {
        // This test is deprecated - use test_recommend_algorithm_updated instead
        // Keeping for backward compatibility but updating expectations

        // 2 params, smooth objective -> L-BFGS (updated)
        assert_eq!(recommend_algorithm(2, 100, "rmse"), AlgorithmType::LBFGS);

        // 4 params, complex objective -> Particle Swarm (updated)
        assert_eq!(recommend_algorithm(4, 100, "huber"), AlgorithmType::ParticleSwarm);

        // 4 params, smooth objective -> L-BFGS (updated)
        assert_eq!(recommend_algorithm(4, 100, "rmse"), AlgorithmType::LBFGS);
    }

    #[test]
    fn test_optimize_with_algorithm() {
        // Test dispatch to different algorithms
        let x: Vec<f64> = (1..=200).map(|i| i as f64).collect();
        let observed = vec![0.5; 200];
        let initial_par = vec![0.3];
        let objective = create_objective("rmse").unwrap();

        // Test Nelder-Mead
        let result_nm = optimize_with_algorithm(
            &observed, &x, &initial_par, "uniform", true,
            objective.clone(), AlgorithmType::NelderMead
        );
        assert!(result_nm.is_ok());

        // Test Simulated Annealing
        let result_sa = optimize_with_algorithm(
            &observed, &x, &initial_par, "uniform", true,
            objective.clone(), AlgorithmType::SimulatedAnnealing
        );
        assert!(result_sa.is_ok());

        // Test L-BFGS
        let result_lbfgs = optimize_with_algorithm(
            &observed, &x, &initial_par, "uniform", true,
            objective, AlgorithmType::LBFGS
        );
        assert!(result_lbfgs.is_ok());
    }

    #[test]
    fn test_lbfgs_gradational() {
        // Test L-BFGS on 2-parameter gradational shape
        let x: Vec<f64> = (1..=200).map(|i| i as f64).collect();
        // Create gradational data: linear from 50 to 150
        let observed: Vec<f64> = x.iter().map(|&xi| {
            let val = (xi - 50.0) / 100.0;
            val.max(0.0).min(1.0)
        }).collect();

        let initial_par = vec![60.0, 140.0]; // Slightly off from true [50, 150]
        let objective = create_objective("rmse").unwrap();

        let result = optimize_lbfgs(
            &observed,
            &x,
            &initial_par,
            "gradational",
            true,
            objective,
            100,
        );

        assert!(result.is_ok());
        let result = result.unwrap();
        // Should converge close to [50, 150]
        assert!((result.params[0] - 50.0).abs() < 15.0);
        assert!((result.params[1] - 150.0).abs() < 15.0);
        assert!(result.final_cost < 0.1); // Should have low error
    }

    #[test]
    fn test_gradient_computation() {
        // Test that gradients are being computed correctly
        let x: Vec<f64> = vec![1.0, 50.0, 100.0, 150.0, 200.0];
        let observed = vec![0.5, 0.5, 0.5, 0.5, 0.5];
        let params = vec![0.6];
        let objective = create_objective("rmse").unwrap();

        let cost_fn = ShapeCostFunction {
            observed: observed.clone(),
            x: x.clone(),
            shape_type: "uniform".to_string(),
            ascending: true,
            objective,
        };

        // Compute gradient
        let grad = cost_fn.gradient(&params);
        assert!(grad.is_ok());
        let grad = grad.unwrap();
        assert_eq!(grad.len(), 1);
        // Gradient should be non-zero (parameter is slightly off from observed 0.5)
        assert!(grad[0].abs() > 0.0);
    }

    #[test]
    fn test_recommend_algorithm_updated() {
        // Test new recommendation logic with all algorithms
        // 1D problem -> Nelder-Mead
        assert_eq!(recommend_algorithm(1, 100, "rmse"), AlgorithmType::NelderMead);

        // 2-3 params, smooth -> L-BFGS
        assert_eq!(recommend_algorithm(2, 100, "rmse"), AlgorithmType::LBFGS);
        assert_eq!(recommend_algorithm(3, 100, "sse"), AlgorithmType::LBFGS);

        // 2-3 params, complex -> Nelder-Mead
        assert_eq!(recommend_algorithm(2, 100, "huber"), AlgorithmType::NelderMead);

        // 4 params, smooth -> L-BFGS
        assert_eq!(recommend_algorithm(4, 100, "rmse"), AlgorithmType::LBFGS);

        // 4 params, complex -> Particle Swarm
        assert_eq!(recommend_algorithm(4, 100, "quantile"), AlgorithmType::ParticleSwarm);

        // 5+ params -> Particle Swarm
        assert_eq!(recommend_algorithm(5, 100, "rmse"), AlgorithmType::ParticleSwarm);
        assert_eq!(recommend_algorithm(6, 100, "huber"), AlgorithmType::ParticleSwarm);
    }

    #[test]
    fn test_particle_swarm_basic() {
        // Test Particle Swarm on simple uniform shape
        let x: Vec<f64> = (1..=200).map(|i| i as f64).collect();
        let observed = vec![0.6; 200];
        let initial_par = vec![0.3]; // Poor guess
        let objective = create_objective("rmse").unwrap();

        let result = optimize_particle_swarm(
            &observed,
            &x,
            &initial_par,
            "uniform",
            true,
            objective,
            50, // Reduced iterations for test speed
        );

        assert!(result.is_ok());
        let result = result.unwrap();
        // PSO should find a reasonable solution (within 0.2 of target)
        assert!((result.params[0] - 0.6).abs() < 0.2);
        assert!(result.final_cost < 0.3); // Should have low error
    }

    #[test]
    fn test_all_algorithms_dispatch() {
        // Test that all algorithms can be dispatched
        let x: Vec<f64> = (1..=200).map(|i| i as f64).collect();
        let observed = vec![0.5; 200];
        let initial_par = vec![0.3];
        let objective = create_objective("rmse").unwrap();

        // Test Nelder-Mead
        let result_nm = optimize_with_algorithm(
            &observed, &x, &initial_par, "uniform", true,
            objective.clone(), AlgorithmType::NelderMead
        );
        assert!(result_nm.is_ok());

        // Test L-BFGS
        let result_lbfgs = optimize_with_algorithm(
            &observed, &x, &initial_par, "uniform", true,
            objective.clone(), AlgorithmType::LBFGS
        );
        assert!(result_lbfgs.is_ok());

        // Test Particle Swarm
        let result_pso = optimize_with_algorithm(
            &observed, &x, &initial_par, "uniform", true,
            objective.clone(), AlgorithmType::ParticleSwarm
        );
        assert!(result_pso.is_ok());

        // Test Simulated Annealing
        let result_sa = optimize_with_algorithm(
            &observed, &x, &initial_par, "uniform", true,
            objective, AlgorithmType::SimulatedAnnealing
        );
        assert!(result_sa.is_ok());
    }
}
