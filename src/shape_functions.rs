//! Shape function implementations
//!
//! Each shape function maps a depth vector to normalized [0, 1] values.
//! Implementations are Rust equivalents of R functions in R/shape.R

use std::f64::consts::PI;
use std::f64;

/// Compute standard normal probability density function (Gaussian curve)
/// 
/// Used by peak and minimax shapes. Approximate implementation of R's dnorm.
fn norm_density(x: f64, mean: f64, sd: f64) -> f64 {
    if sd <= 0.0 {
        if (x - mean).abs() < 1e-10 { 1.0 } else { 0.0 }
    } else {
        let z = (x - mean) / sd;
        (-z * z / 2.0).exp() / (sd * (2.0 * PI).sqrt())
    }
}

/// Uniform shape: constant value across depth
///
/// Models a constant value at all depths. Useful for undeveloped or mixed soils
/// where the property doesn't change significantly with depth.
///
/// # Arguments
/// * `x` - Depth vector (typically 1..200)
/// * `params` - [level] where level is [0, 1]
///
/// # Returns
/// Vector of constant values
///
/// # Examples
/// ```
/// let x = vec![1.0, 100.0, 200.0];
/// let params = vec![0.5];
/// let result = uniform(&x, &params);
/// assert_eq!(result.len(), 3);
/// ```
pub fn uniform(x: &[f64], params: &[f64]) -> Vec<f64> {
    assert!(!params.is_empty(), "uniform requires at least 1 parameter");
    vec![params[0]; x.len()]
}

/// Gradational shape: linear ramp from start to end
///
/// Models a linear change with depth. Useful for steady accumulation processes
/// like clay or organic matter development.
///
/// # Arguments
/// * `x` - Depth vector
/// * `params` - [start_depth, end_depth] - depth boundaries
/// * `ascending` - If true, increases from 0 to 1; else decreases
///
/// # Returns
/// Vector of values ranging [0, 1]
pub fn gradational(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    assert!(params.len() >= 2, "gradational requires 2 parameters");
    
    let start_depth = params[0];
    let end_depth = params[1];
    let range = if (end_depth - start_depth).abs() < 1e-10 {
        1.0
    } else {
        end_depth - start_depth
    };
    
    x.iter()
        .map(|&xi| {
            let val = (xi - start_depth) / range;
            let clamped = val.max(0.0).min(1.0);
            if ascending { clamped } else { 1.0 - clamped }
        })
        .collect()
}

/// Exponential shape: decay or growth pattern
///
/// Models rapid change at surface with asymptotic behavior at depth.
/// Useful for organic matter, roots, and surface-driven processes.
///
/// # Arguments
/// * `x` - Depth vector
/// * `params` - [C0, k] where C0 is surface value, k is decay rate
/// * `ascending` - If true, high at surface, low at depth; else inverted
///
/// # Returns
/// Vector of [0, 1] values
pub fn exponential(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    assert!(params.len() >= 2, "exponential requires 2 parameters");
    
    let c0 = params[0];
    let k = params[1];
    
    // Compute exponential decay across all depths
    let values: Vec<f64> = x.iter()
        .map(|&xi| c0 * (-k * xi).exp())
        .collect();
    
    // Find min and max for normalization
    let min_val = values.iter().cloned().fold(f64::INFINITY, f64::min);
    let max_val = values.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    
    // Normalize to [0, 1]
    let range = if (max_val - min_val).abs() < 1e-10 {
        1.0
    } else {
        max_val - min_val
    };
    
    values
        .iter()
        .map(|&val| {
            let normalized = (val - min_val) / range;
            if ascending {
                normalized
            } else {
                1.0 - normalized
            }
        })
        .collect()
}

/// Wetting front shape: sigmoid-like S-curve transition
///
/// Models smooth S-shaped curves typical of wetting fronts, reaction fronts,
/// and gradual pedogenic changes. Smooth transition between shallow and deep zones.
///
/// # Arguments
/// * `x` - Depth vector
/// * `params` - [start_depth, end_depth] - transition zone boundaries
/// * `ascending` - If true, S-curve (0→1); else reverse S (1→0)
///
/// # Returns
/// Vector of [0, 1] values
pub fn wetting_front(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    assert!(params.len() >= 2, "wetting_front requires 2 parameters");
    
    let start = params[0];
    let end = params[1];
    let midpoint = (start + end) / 2.0;
    let range = end - start;
    
    x.iter()
        .map(|&xi| {
            // Piecewise quadratic (matches R implementation)
            let val = if xi < midpoint {
                let norm = (xi - start) / range;
                let clamped_norm = norm.max(0.0).min(1.0);
                2.0 * clamped_norm * clamped_norm
            } else {
                let norm = (xi - end) / range;
                let clamped_norm = norm.max(-1.0).min(0.0);
                1.0 - 2.0 * clamped_norm * clamped_norm
            };
            
            // Clamp to [0, 1]
            let final_val = val.max(0.0).min(1.0);
            
            if ascending {
                final_val
            } else {
                1.0 - final_val
            }
        })
        .collect()
}

/// Abrupt shape: step-like discontinuity
///
/// Models sharp boundaries typical of lithologic changes or distinct
/// layer boundaries within soil profiles.
///
/// # Arguments
/// * `x` - Depth vector
/// * `params` - [depth_transition, width] - transition depth and smoothness
/// * `ascending` - If true, 0→1 at transition; else 1→0
///
/// # Returns
/// Vector of 0 or 1 values (or smooth transition if width > 0)
pub fn abrupt(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    assert!(!params.is_empty(), "abrupt requires at least 1 parameter");
    
    let depth_transition = params[0];
    let width = if params.len() > 1 { params[1] } else { 0.0 };
    
    x.iter()
        .map(|&xi| {
            let val = if width.abs() <= 1e-6 {
                // Hard step
                if xi >= depth_transition { 1.0 } else { 0.0 }
            } else {
                // Smooth logistic transition
                let scaled = (xi - depth_transition) / width.max(0.1);
                1.0 / (1.0 + (-scaled).exp())
            };
            
            if ascending {
                val
            } else {
                1.0 - val
            }
        })
        .collect()
}

/// Peak shape: bell-shaped accumulation zone
///
/// Models unimodal distributions typical of B horizons, clay illuviation peaks,
/// or other horizons with maximum properties at intermediate depths.
///
/// # Arguments
/// * `x` - Depth vector
/// * `params` - [depth_max, width] - peak location and width
/// * `ascending` - If true, peak (ignored for shape); if false, valley
///
/// # Returns
/// Vector of [0, 1] values with maximum at 1.0 (or 0.0 if valley)
pub fn peak(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    assert!(params.len() >= 2, "peak requires 2 parameters");
    
    let depth_max = params[0];
    let width = params[1].max(1e-6); // Ensure positive
    
    // Compute normal density at each depth
    let densities: Vec<f64> = x.iter()
        .map(|&xi| norm_density(xi, depth_max, width))
        .collect();
    
    // Find maximum for normalization
    let max_density = densities.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    
    let max_val = if max_density.abs() < 1e-10 { 1.0 } else { max_density };
    
    densities
        .iter()
        .map(|&d| {
            let normalized = d / max_val;
            if ascending {
                normalized
            } else {
                1.0 - normalized
            }
        })
        .collect()
}

/// MiniMax shape: two peaks for bimodal patterns
///
/// Models bimodal distributions with two peaks at different depths.
/// Useful for complex multi-process soils or polygenetic profiles.
///
/// # Arguments
/// * `x` - Depth vector
/// * `params` - [depth_min, width_min, depth_max, width_max] - two peaks with widths
/// * `ascending` - If true, bimodal peaks; if false, inverted
///
/// # Returns
/// Vector of [0, 1] values with two local maxima
pub fn minimax(x: &[f64], params: &[f64], ascending: bool) -> Vec<f64> {
    assert!(params.len() >= 4, "minimax requires 4 parameters");
    
    let depth_min = params[0];
    let width_min = params[1].max(1e-6);
    let depth_max = params[2];
    let width_max = params[3].max(1e-6);
    
    // Create valley and peak distributions
    let mut values = Vec::new();
    for &xi in x {
        let valley_density = norm_density(xi, depth_min, width_min);
        let peak_density = norm_density(xi, depth_max, width_max);
        
        // Combine: valley is inverted, then average
        let valley = 1.0 - valley_density;
        let combined = (valley + peak_density) / 2.0;
        values.push(combined);
    }
    
    // Normalize to [0, 1]
    let max_val = values.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let max_scale = if max_val.abs() < 1e-10 { 1.0 } else { max_val };
    
    values
        .iter()
        .map(|&v| {
            let normalized = v / max_scale;
            if ascending {
                normalized
            } else {
                1.0 - normalized
            }
        })
        .collect()
}

/// Dispatch to shape function by name
///
/// Convenient way to call shape functions by string name with unified interface.
///
/// # Arguments
/// * `shape_type` - String name: "uniform", "gradational", "exponential", 
///                  "wetting_front", "abrupt", "peak", "minimax"
/// * `x` - Depth vector
/// * `params` - Shape-specific parameters
/// * `ascending` - Direction flag (ignored for some shapes like peak)
///
/// # Returns
/// Result with vector of [0, 1] values or error string
///
/// # Examples
/// ```
/// let x = vec![1.0, 50.0, 100.0, 200.0];
/// let params = vec![0.5];
/// let result = eval_shape("uniform", &x, &params, true);
/// assert!(result.is_ok());
/// ```
pub fn eval_shape(
    shape_type: &str,
    x: &[f64],
    params: &[f64],
    ascending: bool,
) -> Result<Vec<f64>, String> {
    match shape_type {
        "uniform" => {
            if params.is_empty() {
                return Err("uniform requires 1 parameter".to_string());
            }
            Ok(uniform(x, params))
        },
        "gradational" => {
            if params.len() < 2 {
                return Err("gradational requires 2 parameters".to_string());
            }
            Ok(gradational(x, params, ascending))
        },
        "exponential" => {
            if params.len() < 2 {
                return Err("exponential requires 2 parameters".to_string());
            }
            Ok(exponential(x, params, ascending))
        },
        "wetting_front" => {
            if params.len() < 2 {
                return Err("wetting_front requires 2 parameters".to_string());
            }
            Ok(wetting_front(x, params, ascending))
        },
        "abrupt" => {
            if params.is_empty() {
                return Err("abrupt requires at least 1 parameter".to_string());
            }
            Ok(abrupt(x, params, ascending))
        },
        "peak" => {
            if params.len() < 2 {
                return Err("peak requires 2 parameters".to_string());
            }
            Ok(peak(x, params, ascending))
        },
        "minimax" => {
            if params.len() < 4 {
                return Err("minimax requires 4 parameters".to_string());
            }
            Ok(minimax(x, params, ascending))
        },
        _ => Err(format!("Unknown shape type: {}", shape_type)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_uniform() {
        let x = vec![1.0, 50.0, 100.0, 200.0];
        let params = vec![0.5];
        let result = uniform(&x, &params);
        assert_eq!(result.len(), 4);
        assert!(result.iter().all(|&v| (v - 0.5).abs() < 1e-10));
    }

    #[test]
    fn test_gradational_ascending() {
        let x = vec![1.0, 100.0, 200.0];
        let params = vec![50.0, 150.0];
        let result = gradational(&x, &params, true);
        assert_eq!(result.len(), 3);
        assert!(result[0] < result[1]);
        assert!(result[1] < result[2]);
    }

    #[test]
    fn test_gradational_descending() {
        let x = vec![1.0, 100.0, 200.0];
        let params = vec![50.0, 150.0];
        let result = gradational(&x, &params, false);
        assert_eq!(result.len(), 3);
        assert!(result[0] > result[1]);
        assert!(result[1] > result[2]);
    }

    #[test]
    fn test_wetting_front_sigmoid() {
        let x = vec![1.0, 100.0, 200.0];
        let params = vec![50.0, 150.0];
        let result = wetting_front(&x, &params, true);
        assert_eq!(result.len(), 3);
        assert!(result[0] < result[1]); // increases through transition
        assert!(result[1] < result[2]);
    }

    #[test]
    fn test_abrupt_hard_step() {
        let x = vec![1.0, 50.0, 100.0];
        let params = vec![75.0, 0.0]; // width = 0 → hard step
        let result = abrupt(&x, &params, true);
        assert_eq!(result[0], 0.0);
        assert_eq!(result[2], 1.0);
    }

    #[test]
    fn test_peak_bell_curve() {
        let x = vec![1.0, 100.0, 200.0];
        let params = vec![100.0, 30.0];
        let result = peak(&x, &params, true);
        assert_eq!(result.len(), 3);
        assert!(result[1] > result[0]); // peak at x_peak
        assert!(result[1] > result[2]);
    }

    #[test]
    fn test_minimax_two_peaks() {
        let x = vec![1.0, 50.0, 100.0, 150.0, 200.0];
        let params = vec![40.0, 15.0, 160.0, 15.0];
        let result = minimax(&x, &params, true);
        assert_eq!(result.len(), 5);
        // Result should be bimodal
        assert!(result.iter().all(|&v| v >= 0.0 && v <= 1.0));
    }

    #[test]
    fn test_eval_shape_dispatch_uniform() {
        let x = vec![1.0, 100.0, 200.0];
        let params = vec![0.5];
        let result = eval_shape("uniform", &x, &params, true);
        assert!(result.is_ok());
        let values = result.unwrap();
        assert!(values.iter().all(|&v| (v - 0.5).abs() < 1e-10));
    }

    #[test]
    fn test_eval_shape_unknown() {
        let x = vec![1.0, 2.0, 3.0];
        let params = vec![];
        let result = eval_shape("unknown_shape", &x, &params, true);
        assert!(result.is_err());
    }

    #[test]
    fn test_exponential() {
        let x = vec![1.0, 50.0, 100.0];
        let params = vec![1.0, 0.05];
        let result = exponential(&x, &params, true);
        assert_eq!(result.len(), 3);
        // Exponential decay should be descending initially then level off
        assert!(result.iter().all(|&v| v >= 0.0 && v <= 1.0));
    }
}
