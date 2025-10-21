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
