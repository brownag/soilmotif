//! Objective functions: RMSE, SSQ, MAE, and R-squared
//!
//! These compute fit quality metrics between observed and predicted data.
//! Used by the optimizer to evaluate motif fit quality.

use std::f64;

/// Compute Root Mean Squared Error
///
/// Measures average magnitude of prediction errors. Lower RMSE indicates better fit.
///
/// # Arguments
/// * `observed` - Observed/measured data vector
/// * `predicted` - Predicted/model data vector
///
/// # Panics
/// Panics if vectors have different lengths
///
/// # Examples
/// ```
/// let obs = vec![1.0, 2.0, 3.0];
/// let pred = vec![1.1, 1.9, 3.2];
/// let rmse = rmse(&obs, &pred);
/// assert!((rmse - 0.1265).abs() < 0.0001);
/// ```
pub fn rmse(observed: &[f64], predicted: &[f64]) -> f64 {
    assert_eq!(
        observed.len(),
        predicted.len(),
        "observed and predicted must have same length"
    );
    
    let n = observed.len() as f64;
    let sse: f64 = observed
        .iter()
        .zip(predicted.iter())
        .map(|(&o, &p)| (o - p).powi(2))
        .sum();
    
    (sse / n).sqrt()
}

/// Compute Sum of Squared Errors
///
/// Total squared error; useful as raw objective function for optimization.
///
/// # Arguments
/// * `observed` - Observed/measured data vector
/// * `predicted` - Predicted/model data vector
///
/// # Panics
/// Panics if vectors have different lengths
///
/// # Examples
/// ```
/// let obs = vec![1.0, 2.0, 3.0];
/// let pred = vec![1.1, 1.9, 3.2];
/// let sse = sse(&obs, &pred);
/// assert!((sse - 0.06).abs() < 0.0001);
/// ```
pub fn sse(observed: &[f64], predicted: &[f64]) -> f64 {
    assert_eq!(
        observed.len(),
        predicted.len(),
        "observed and predicted must have same length"
    );
    
    observed
        .iter()
        .zip(predicted.iter())
        .map(|(&o, &p)| (o - p).powi(2))
        .sum()
}

/// Compute R-squared (coefficient of determination)
///
/// Fraction of variance in data explained by model. 1.0 = perfect fit, 0.0 = mean predictor.
/// Can be negative if fit is worse than simply predicting the mean.
///
/// # Arguments
/// * `observed` - Observed/measured data vector
/// * `predicted` - Predicted/model data vector
///
/// # Returns
/// R² value (typically 0 to 1, can be negative for poor fits)
///
/// # Examples
/// ```
/// let obs = vec![1.0, 2.0, 3.0];
/// let pred = vec![1.0, 2.0, 3.0];
/// let r2 = r_squared(&obs, &pred);
/// assert!((r2 - 1.0).abs() < 1e-10);
/// ```
pub fn r_squared(observed: &[f64], predicted: &[f64]) -> f64 {
    assert_eq!(
        observed.len(),
        predicted.len(),
        "observed and predicted must have same length"
    );
    
    let mean_obs: f64 = observed.iter().sum::<f64>() / observed.len() as f64;
    
    let ss_tot: f64 = observed
        .iter()
        .map(|&o| (o - mean_obs).powi(2))
        .sum();
    
    let ss_res: f64 = observed
        .iter()
        .zip(predicted.iter())
        .map(|(&o, &p)| (o - p).powi(2))
        .sum();
    
    if ss_tot.abs() < f64::EPSILON {
        0.0
    } else {
        1.0 - (ss_res / ss_tot)
    }
}

/// Compute Mean Absolute Error
///
/// Average magnitude of prediction errors without squaring.
/// More robust to outliers than RMSE.
///
/// # Arguments
/// * `observed` - Observed/measured data vector
/// * `predicted` - Predicted/model data vector
///
/// # Returns
/// MAE value (same units as input data)
///
/// # Examples
/// ```
/// let obs = vec![1.0, 2.0, 3.0];
/// let pred = vec![1.5, 2.5, 3.5];
/// let mae = mae(&obs, &pred);
/// assert!((mae - 0.5).abs() < 1e-10);
/// ```
pub fn mae(observed: &[f64], predicted: &[f64]) -> f64 {
    assert_eq!(
        observed.len(),
        predicted.len(),
        "observed and predicted must have same length"
    );
    
    let n = observed.len() as f64;
    observed
        .iter()
        .zip(predicted.iter())
        .map(|(&o, &p)| (o - p).abs())
        .sum::<f64>() / n
}

/// Compute weighted RMSE (depth-aware)
///
/// Applies Gaussian weighting centered on target_depth.
/// Emphasizes fit quality at specific soil horizons.
///
/// # Arguments
/// * `observed` - Observed/measured data vector
/// * `predicted` - Predicted/model data vector
/// * `depths` - Depth vector corresponding to observations
/// * `target_depth` - Depth to emphasize (cm)
/// * `weight_factor` - Weight concentration factor (higher = more concentrated)
///
/// # Returns
/// Weighted RMSE value
pub fn weighted_rmse(
    observed: &[f64], 
    predicted: &[f64], 
    depths: &[f64], 
    target_depth: f64, 
    weight_factor: f64
) -> f64 {
    assert_eq!(observed.len(), predicted.len(), "observed and predicted must have same length");
    assert_eq!(observed.len(), depths.len(), "observed and depths must have same length");
    
    let mut weighted_sum_sq = 0.0;
    let mut sum_weights = 0.0;
    
    for i in 0..observed.len() {
        let weight = (-weight_factor * (depths[i] - target_depth).powi(2)).exp();
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

/// Compute ordinal error (asymmetric penalties)
///
/// Penalizes under-prediction and over-prediction differently.
/// Useful for soil properties where under/over-estimation has different costs.
///
/// # Arguments
/// * `observed` - Observed/measured data vector
/// * `predicted` - Predicted/model data vector
/// * `depths` - Depth vector (unused, kept for API consistency)
/// * `underpredict_penalty` - Penalty multiplier for under-prediction
/// * `overpredict_penalty` - Penalty multiplier for over-prediction
///
/// # Returns
/// Ordinal error value
pub fn ordinal_error(
    observed: &[f64], 
    predicted: &[f64], 
    _depths: &[f64], 
    underpredict_penalty: f64, 
    overpredict_penalty: f64
) -> f64 {
    assert_eq!(observed.len(), predicted.len(), "observed and predicted must have same length");
    
    let n = observed.len() as f64;
    let mut total_cost = 0.0;
    
    for i in 0..observed.len() {
        let residual = observed[i] - predicted[i];
        if residual > 0.0 {
            // Under-prediction: predicted < observed
            total_cost += underpredict_penalty * residual.abs();
        } else {
            // Over-prediction: predicted > observed
            total_cost += overpredict_penalty * residual.abs();
        }
    }
    
    total_cost / n
}

/// Compute bounded error (with physical constraints)
///
/// Applies penalty when predictions exceed physical bounds.
/// Ensures soil property predictions stay within realistic ranges.
///
/// # Arguments
/// * `observed` - Observed/measured data vector
/// * `predicted` - Predicted/model data vector
/// * `depths` - Depth vector (unused, kept for API consistency)
/// * `obs_min` - Minimum allowed value
/// * `obs_max` - Maximum allowed value
/// * `penalty_factor` - Penalty multiplier for out-of-bounds predictions
///
/// # Returns
/// Bounded error value (RMSE with penalties)
pub fn bounded_error(
    observed: &[f64], 
    predicted: &[f64], 
    _depths: &[f64], 
    obs_min: f64, 
    obs_max: f64, 
    penalty_factor: f64
) -> f64 {
    assert_eq!(observed.len(), predicted.len(), "observed and predicted must have same length");
    
    let n = observed.len() as f64;
    let mut total_cost = 0.0;
    
    for i in 0..observed.len() {
        let residual = observed[i] - predicted[i];
        let residual_sq = residual.powi(2);
        
        // Check if prediction is out of bounds
        let pred = predicted[i];
        if pred < obs_min || pred > obs_max {
            // Apply penalty for out-of-bounds prediction
            total_cost += penalty_factor * residual_sq;
        } else {
            // Normal squared error
            total_cost += residual_sq;
        }
    }
    
    (total_cost / n).sqrt()
}

/// Compute Huber loss (robust to outliers)
///
/// Combines squared error for small residuals with absolute error for large residuals.
/// More robust to outliers than RMSE while maintaining differentiability.
///
/// # Arguments
/// * `observed` - Observed/measured data vector
/// * `predicted` - Predicted/model data vector
/// * `depths` - Depth vector (unused, kept for API consistency)
/// * `delta` - Threshold separating quadratic and linear regions
///
/// # Returns
/// Huber loss value
pub fn huber_loss(
    observed: &[f64], 
    predicted: &[f64], 
    _depths: &[f64], 
    delta: f64
) -> f64 {
    assert_eq!(observed.len(), predicted.len(), "observed and predicted must have same length");
    
    let n = observed.len() as f64;
    let mut total_cost = 0.0;
    
    for i in 0..observed.len() {
        let residual = (observed[i] - predicted[i]).abs();
        if residual <= delta {
            // Quadratic loss for small residuals
            total_cost += 0.5 * residual.powi(2);
        } else {
            // Linear loss for large residuals
            total_cost += delta * residual - 0.5 * delta.powi(2);
        }
    }
    
    total_cost / n
}

/// Compute quantile loss (asymmetric quantile regression)
///
/// Penalizes under/over-prediction based on quantile.
/// Useful for predicting conditional quantiles of soil properties.
///
/// # Arguments
/// * `observed` - Observed/measured data vector
/// * `predicted` - Predicted/model data vector
/// * `depths` - Depth vector (unused, kept for API consistency)
/// * `quantile` - Quantile to predict (0.5 = median, 0.9 = 90th percentile)
///
/// # Returns
/// Quantile loss value
pub fn quantile_loss(
    observed: &[f64], 
    predicted: &[f64], 
    _depths: &[f64], 
    quantile: f64
) -> f64 {
    assert_eq!(observed.len(), predicted.len(), "observed and predicted must have same length");
    assert!(quantile > 0.0 && quantile < 1.0, "quantile must be between 0 and 1");
    
    let n = observed.len() as f64;
    let mut total_cost = 0.0;
    
    for i in 0..observed.len() {
        let residual = observed[i] - predicted[i];
        if residual > 0.0 {
            // Under-prediction penalty
            total_cost += quantile * residual;
        } else {
            // Over-prediction penalty
            total_cost += (1.0 - quantile) * residual.abs();
        }
    }
    
    total_cost / n
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rmse_perfect_fit() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.0, 2.0, 3.0];
        assert!((rmse(&obs, &pred) - 0.0).abs() < 1e-10);
    }

    #[test]
    fn test_rmse_uniform_error() {
        let obs = vec![0.0, 0.0, 0.0];
        let pred = vec![1.0, 1.0, 1.0];
        assert!((rmse(&obs, &pred) - 1.0).abs() < 1e-10);
    }

    #[test]
    fn test_rmse_expected_value() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.5, 2.5, 3.5];
        assert!((rmse(&obs, &pred) - 0.5).abs() < 1e-10);
    }

    #[test]
    fn test_sse() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.5, 2.5, 3.5];
        assert!((sse(&obs, &pred) - 0.75).abs() < 1e-10);
    }

    #[test]
    fn test_r_squared_perfect_fit() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.0, 2.0, 3.0];
        assert!((r_squared(&obs, &pred) - 1.0).abs() < 1e-10);
    }

    #[test]
    fn test_r_squared_mean_predictor() {
        let obs = vec![1.0, 2.0, 3.0];
        let mean = 2.0;
        let pred = vec![mean, mean, mean];
        assert!((r_squared(&obs, &pred) - 0.0).abs() < 1e-10);
    }

    #[test]
    fn test_mae() {
        let obs = vec![1.0, 2.0, 3.0];
        let pred = vec![1.5, 2.5, 3.5];
        assert!((mae(&obs, &pred) - 0.5).abs() < 1e-10);
    }

    #[test]
    #[should_panic(expected = "must have same length")]
    fn test_rmse_length_mismatch() {
        let obs = vec![1.0, 2.0];
        let pred = vec![1.0, 2.0, 3.0];
        rmse(&obs, &pred);
    }
}
