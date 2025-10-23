//! Shape function implementations
//!
//! Each shape function maps a depth vector to normalized `[0, 1]` values.
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
/// * `params` - [level] where level is `[0, 1]`
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
/// Vector of values ranging `[0, 1]`
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
/// Vector of `[0, 1]` values
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
/// * `ascending` - If true, S-curve (0->1); else reverse S (1->0)
///
/// # Returns
/// Vector of `[0, 1]` values
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
/// * `ascending` - If true, 0->1 at transition; else 1->0
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
/// Vector of `[0, 1]` values with maximum at 1.0 (or 0.0 if valley)
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
/// Vector of `[0, 1]` values with two local maxima
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

/// Monotone Cubic Spline (Fritsch-Carlson method)
///
/// Ensures strictly monotonic interpolation through control points.
///
/// # Arguments
/// * `x` - Evaluation depths (typically 1..200)
/// * `control_points` - Flattened vector [depth1, val1, depth2, val2, ...]
///   Must be even length and depths must be sorted
///
/// # Returns
/// Interpolated values at depths x, maintaining strict monotonicity
pub fn monotone_cubic_spline(x: &[f64], control_points: &[f64]) -> Result<Vec<f64>, String> {
    if control_points.is_empty() {
        return Err("control_points cannot be empty".to_string());
    }
    if control_points.len() % 2 != 0 {
        return Err(format!("control_points length must be even, got {}", control_points.len()));
    }

    // Extract depths and values from flattened vector
    let n = control_points.len() / 2;
    let mut depths = Vec::with_capacity(n);
    let mut values = Vec::with_capacity(n);
    
    for i in 0..n {
        depths.push(control_points[2 * i]);
        values.push(control_points[2 * i + 1]);
    }

    // Validate that depths are sorted
    for i in 1..n {
        if depths[i] <= depths[i - 1] {
            return Err(format!(
                "control point depths must be strictly sorted (depth[{}]={} <= depth[{}]={})",
                i - 1, depths[i - 1], i, depths[i]
            ));
        }
    }

    if x.is_empty() {
        return Ok(vec![]);
    }

    // Compute slopes between consecutive points
    let mut slopes = Vec::with_capacity(n - 1);
    for i in 0..(n - 1) {
        let slope = (values[i + 1] - values[i]) / (depths[i + 1] - depths[i]);
        slopes.push(slope);
    }

    // Compute tangents using Fritsch-Carlson method
    let mut tangents = vec![0.0; n];
    
    // At endpoints, use one-sided derivatives
    tangents[0] = slopes[0];
    tangents[n - 1] = slopes[n - 2];

    // At interior points, use weighted average of neighboring slopes
    for i in 1..(n - 1) {
        let h_prev = depths[i] - depths[i - 1];
        let h_next = depths[i + 1] - depths[i];
        let w_prev = 2.0 * h_next + h_prev;
        let w_next = h_next + 2.0 * h_prev;

        if slopes[i - 1] * slopes[i] > 0.0 {
            // Same sign: use weighted harmonic mean
            tangents[i] = (w_prev + w_next) / (w_prev / slopes[i - 1] + w_next / slopes[i]);
        } else {
            // Different sign: use zero (monotonicity requires it)
            tangents[i] = 0.0;
        }
    }

    // Interpolate at each evaluation point
    let mut result = Vec::with_capacity(x.len());
    
    for &xi in x {
        // Find interval containing xi
        let val = if xi <= depths[0] {
            values[0]
        } else if xi >= depths[n - 1] {
            values[n - 1]
        } else {
            // Binary search for interval
            let mut idx = 0;
            for (i, &d) in depths.iter().enumerate() {
                if d <= xi {
                    idx = i;
                } else {
                    break;
                }
            }

            if idx >= n - 1 {
                idx = n - 2;
            }

            // Hermite interpolation in interval [depths[idx], depths[idx+1]]
            let h = depths[idx + 1] - depths[idx];
            let t = (xi - depths[idx]) / h;
            let t2 = t * t;
            let t3 = t2 * t;

            let y0 = values[idx];
            let y1 = values[idx + 1];
            let m0 = tangents[idx];
            let m1 = tangents[idx + 1];

            // Hermite basis functions
            let h00 = 2.0 * t3 - 3.0 * t2 + 1.0;
            let h10 = t3 - 2.0 * t2 + t;
            let h01 = -2.0 * t3 + 3.0 * t2;
            let h11 = t3 - t2;

            h00 * y0 + h10 * h * m0 + h01 * y1 + h11 * h * m1
        };

        result.push(val);
    }

    Ok(result)
}

/// Restricted Cubic Spline (RCS)
///
/// Provides flexible non-monotonic interpolation while preventing erratic extrapolation.
/// Natural cubic spline with linear extrapolation beyond endpoints.
/// Suitable for properties like pH or organic carbon that may have non-monotonic behavior.
///
/// # Arguments
/// * `x` - Evaluation depths
/// * `control_points` - Flattened vector [depth1, val1, depth2, val2, ...]
///   Must be even length and depths must be sorted
///
/// # Returns
/// Interpolated values using natural cubic spline
pub fn restricted_cubic_spline(x: &[f64], control_points: &[f64]) -> Result<Vec<f64>, String> {
    if control_points.is_empty() {
        return Err("control_points cannot be empty".to_string());
    }
    if control_points.len() % 2 != 0 {
        return Err(format!("control_points length must be even, got {}", control_points.len()));
    }

    // Extract depths and values from flattened vector
    let n = control_points.len() / 2;
    let mut depths = Vec::with_capacity(n);
    let mut values = Vec::with_capacity(n);
    
    for i in 0..n {
        depths.push(control_points[2 * i]);
        values.push(control_points[2 * i + 1]);
    }

    // Validate that depths are sorted
    for i in 1..n {
        if depths[i] <= depths[i - 1] {
            return Err(format!(
                "control point depths must be strictly sorted (depth[{}]={} <= depth[{}]={})",
                i - 1, depths[i - 1], i, depths[i]
            ));
        }
    }

    if x.is_empty() {
        return Ok(vec![]);
    }

    // For 2 points or fewer, use linear interpolation
    if n <= 2 {
        return Ok(x.iter().map(|&xi| {
            if xi <= depths[0] {
                values[0]
            } else if xi >= depths[n - 1] {
                values[n - 1]
            } else {
                // Linear interpolation
                let slope = (values[1] - values[0]) / (depths[1] - depths[0]);
                values[0] + slope * (xi - depths[0])
            }
        }).collect());
    }

    // Compute differences and prepare for tridiagonal system
    let mut h = Vec::with_capacity(n - 1);
    
    for i in 0..(n - 1) {
        h.push(depths[i + 1] - depths[i]);
    }

    // Set up tridiagonal system for natural cubic spline
    // Natural boundary conditions: M[0] = M[n-1] = 0
    let mut l = vec![1.0; n];
    let mut mu = vec![0.0; n - 1];
    let mut z = vec![0.0; n];

    for i in 1..(n - 1) {
        l[i] = 2.0 * (h[i - 1] + h[i]) - h[i - 1] * mu[i - 1];
        if l[i].abs() < 1e-15 {
            l[i] = 1e-15; // Avoid division by zero
        }
        mu[i] = h[i] / l[i];
        z[i] = (6.0 * ((values[i + 1] - values[i]) / h[i] - (values[i] - values[i - 1]) / h[i - 1]) - h[i - 1] * z[i - 1]) / l[i];
    }

    // Back substitution to find second derivatives (M values)
    let mut m = vec![0.0; n];
    for i in (0..(n - 1)).rev() {
        m[i] = z[i] - mu[i] * m[i + 1];
    }

    // Interpolate at each evaluation point
    let mut result = Vec::with_capacity(x.len());
    
    for &xi in x {
        let val = if xi <= depths[0] {
            // Linear extrapolation to left
            let slope = (values[1] - values[0]) / (depths[1] - depths[0]);
            values[0] + slope * (xi - depths[0])
        } else if xi >= depths[n - 1] {
            // Linear extrapolation to right
            let slope = (values[n - 1] - values[n - 2]) / (depths[n - 1] - depths[n - 2]);
            values[n - 1] + slope * (xi - depths[n - 1])
        } else {
            // Find interval
            let mut idx = 0;
            for (i, &d) in depths.iter().enumerate() {
                if d <= xi {
                    idx = i;
                } else {
                    break;
                }
            }
            if idx >= n - 1 {
                idx = n - 2;
            }

            // Cubic Hermite interpolation using second derivatives
            let dx = xi - depths[idx];
            let h_i = h[idx];
            let a = (depths[idx + 1] - xi) / h_i;
            let b = dx / h_i;

            a * values[idx] + b * values[idx + 1] +
                (a.powi(3) - a) / 6.0 * m[idx] * h_i * h_i +
                (b.powi(3) - b) / 6.0 * m[idx + 1] * h_i * h_i
        };

        result.push(val);
    }

    Ok(result)
}

/// Compute analytical gradient of monotone cubic spline
///
/// Returns the derivative at each evaluation point
pub fn monotone_cubic_spline_gradient(
    x: &[f64],
    control_points: &[f64],
) -> Result<Vec<Vec<f64>>, String> {
    if control_points.is_empty() {
        return Err("control_points cannot be empty".to_string());
    }
    if control_points.len() % 2 != 0 {
        return Err(format!("control_points length must be even, got {}", control_points.len()));
    }

    let n = control_points.len() / 2;
    let mut depths = Vec::with_capacity(n);
    let mut values = Vec::with_capacity(n);
    
    for i in 0..n {
        depths.push(control_points[2 * i]);
        values.push(control_points[2 * i + 1]);
    }

    if x.is_empty() {
        return Ok(vec![]);
    }

    // Compute slopes
    let mut slopes = Vec::with_capacity(n - 1);
    for i in 0..(n - 1) {
        let slope = (values[i + 1] - values[i]) / (depths[i + 1] - depths[i]);
        slopes.push(slope);
    }

    // Compute tangents (same as in monotone_cubic_spline)
    let mut tangents = vec![0.0; n];
    tangents[0] = slopes[0];
    tangents[n - 1] = slopes[n - 2];

    for i in 1..(n - 1) {
        let h_prev = depths[i] - depths[i - 1];
        let h_next = depths[i + 1] - depths[i];
        let w_prev = 2.0 * h_next + h_prev;
        let w_next = h_next + 2.0 * h_prev;

        if slopes[i - 1] * slopes[i] > 0.0 {
            tangents[i] = (w_prev + w_next) / (w_prev / slopes[i - 1] + w_next / slopes[i]);
        } else {
            tangents[i] = 0.0;
        }
    }

    // Compute derivatives at each point
    let mut result = Vec::with_capacity(x.len());
    
    for &xi in x {
        let deriv = if xi <= depths[0] || xi >= depths[n - 1] {
            0.0 // Derivative at endpoints is constant
        } else {
            // Find interval
            let mut idx = 0;
            for (i, &d) in depths.iter().enumerate() {
                if d <= xi {
                    idx = i;
                } else {
                    break;
                }
            }
            if idx >= n - 1 {
                idx = n - 2;
            }

            // Derivative of Hermite interpolation
            let h = depths[idx + 1] - depths[idx];
            let t = (xi - depths[idx]) / h;
            
            let y0 = values[idx];
            let y1 = values[idx + 1];
            let m0 = tangents[idx];
            let m1 = tangents[idx + 1];

            // Derivatives of basis functions w.r.t. t
            let dh00_dt = 6.0 * t * (t - 1.0);
            let dh10_dt = 3.0 * t * t - 4.0 * t + 1.0;
            let dh01_dt = 6.0 * t * (1.0 - t);
            let dh11_dt = 3.0 * t * t - 2.0 * t;

            // Chain rule: df/dx = df/dt * dt/dx = df/dt * (1/h)
            (dh00_dt * y0 + dh10_dt * h * m0 + dh01_dt * y1 + dh11_dt * h * m1) / h
        };

        result.push(vec![deriv]);
    }

    Ok(result)
}

/// Compute analytical gradient of restricted cubic spline
///
/// Returns the derivative at each evaluation point
pub fn restricted_cubic_spline_gradient(
    x: &[f64],
    control_points: &[f64],
) -> Result<Vec<Vec<f64>>, String> {
    if control_points.is_empty() {
        return Err("control_points cannot be empty".to_string());
    }
    if control_points.len() % 2 != 0 {
        return Err(format!("control_points length must be even, got {}", control_points.len()));
    }

    let n = control_points.len() / 2;
    let mut depths = Vec::with_capacity(n);
    let mut values = Vec::with_capacity(n);
    
    for i in 0..n {
        depths.push(control_points[2 * i]);
        values.push(control_points[2 * i + 1]);
    }

    if x.is_empty() {
        return Ok(vec![]);
    }

    // For 2 points, derivatives are constant slopes
    if n <= 2 {
        let slope = (values[1] - values[0]) / (depths[1] - depths[0]);
        return Ok(vec![vec![slope]; x.len()]);
    }

    // Compute h values and setup system (same as in RCS)
    let mut h = Vec::with_capacity(n - 1);
    for i in 0..(n - 1) {
        h.push(depths[i + 1] - depths[i]);
    }

    // Solve tridiagonal system for m (second derivatives)
    let mut l = vec![1.0; n];
    let mut mu = vec![0.0; n - 1];
    let mut z = vec![0.0; n];

    for i in 1..(n - 1) {
        l[i] = 2.0 * (h[i - 1] + h[i]) - h[i - 1] * mu[i - 1];
        if l[i].abs() < 1e-15 {
            l[i] = 1e-15;
        }
        mu[i] = h[i] / l[i];
        z[i] = (6.0 * ((values[i + 1] - values[i]) / h[i] - (values[i] - values[i - 1]) / h[i - 1]) - h[i - 1] * z[i - 1]) / l[i];
    }

    let mut m = vec![0.0; n];
    for i in (0..(n - 1)).rev() {
        m[i] = z[i] - mu[i] * m[i + 1];
    }

    // Compute derivatives at each point
    let mut result = Vec::with_capacity(x.len());
    
    for &xi in x {
        let deriv = if xi <= depths[0] {
            // Linear extrapolation slope to left
            (values[1] - values[0]) / (depths[1] - depths[0])
        } else if xi >= depths[n - 1] {
            // Linear extrapolation slope to right
            (values[n - 1] - values[n - 2]) / (depths[n - 1] - depths[n - 2])
        } else {
            // Find interval
            let mut idx = 0;
            for (i, &d) in depths.iter().enumerate() {
                if d <= xi {
                    idx = i;
                } else {
                    break;
                }
            }
            if idx >= n - 1 {
                idx = n - 2;
            }

            // Derivative of cubic Hermite
            let dx = xi - depths[idx];
            let h_i = h[idx];
            let a = (depths[idx + 1] - xi) / h_i;
            let b = dx / h_i;

            let da_dx = -1.0 / h_i;
            let db_dx = 1.0 / h_i;

            let slope = (values[idx + 1] - values[idx]) / h_i;
            slope + (3.0 * a * a - 1.0) / 6.0 * da_dx * m[idx] * h_i * h_i +
                (3.0 * b * b - 1.0) / 6.0 * db_dx * m[idx + 1] * h_i * h_i
        };

        result.push(vec![deriv]);
    }

    Ok(result)
}

/// Compute analytical gradient of uniform shape
///
/// f(x, level) = level
/// df/dlevel = 1
pub fn uniform_gradient(x: &[f64], _params: &[f64]) -> Vec<Vec<f64>> {
    // Gradient is constant 1.0 for all depths (single parameter)
    vec![vec![1.0]; x.len()]
}

/// Compute analytical gradient of gradational shape
///
/// f(x, start, end) = (x - start) / (end - start)
/// df/dstart = -(x - end) / (end - start)^2
/// df/dend = (x - start) / (end - start)^2
pub fn gradational_gradient(x: &[f64], params: &[f64], ascending: bool) -> Vec<Vec<f64>> {
    let start = params[0];
    let end = params[1];
    let range = end - start;
    let range_sq = range * range;

    if range.abs() < 1e-10 {
        // Degenerate case: start == end, gradients are zero
        return vec![vec![0.0, 0.0]; x.len()];
    }

    x.iter()
        .map(|&xi| {
            // Check if we're in the clamped region
            let val = (xi - start) / range;

            let (grad_start, grad_end) = if val < 0.0 {
                // Clamped to 0: gradients are 0
                (0.0, 0.0)
            } else if val > 1.0 {
                // Clamped to 1: gradients are 0
                (0.0, 0.0)
            } else {
                // Active region: compute analytical gradients
                let grad_start = -(xi - end) / range_sq;
                let grad_end = (xi - start) / range_sq;
                (grad_start, grad_end)
            };

            if ascending {
                vec![grad_start, grad_end]
            } else {
                vec![-grad_start, -grad_end]
            }
        })
        .collect()
}

/// Compute analytical gradient of wetting front shape (simplified)
///
/// For the piecewise quadratic wetting front, gradients are more complex.
/// We use finite differences as a robust approximation.
pub fn wetting_front_gradient(x: &[f64], params: &[f64], ascending: bool) -> Vec<Vec<f64>> {
    // Use finite differences for now (can implement analytical later)
    finite_difference_gradient(x, params, ascending, wetting_front)
}

/// Compute gradient via finite differences
///
/// Generic helper for shapes without simple analytical gradients
fn finite_difference_gradient<F>(
    x: &[f64],
    params: &[f64],
    ascending: bool,
    shape_fn: F,
) -> Vec<Vec<f64>>
where
    F: Fn(&[f64], &[f64], bool) -> Vec<f64>,
{
    let epsilon = 1e-6;
    let f0 = shape_fn(x, params, ascending);

    let mut gradients = vec![vec![0.0; params.len()]; x.len()];

    for j in 0..params.len() {
        let mut params_plus = params.to_vec();
        params_plus[j] += epsilon;
        let f_plus = shape_fn(x, &params_plus, ascending);

        for i in 0..x.len() {
            gradients[i][j] = (f_plus[i] - f0[i]) / epsilon;
        }
    }

    gradients
}

/// Dispatch to shape gradient by name
///
/// Computes analytical gradients (or finite difference approximation) for shape functions.
///
/// # Arguments
/// * `shape_type` - String name of shape function
/// * `x` - Depth vector
/// * `params` - Shape-specific parameters
/// * `ascending` - Direction flag
///
/// # Returns
/// Result with gradient matrix [depth][param] or error string
pub fn eval_shape_gradient(
    shape_type: &str,
    x: &[f64],
    params: &[f64],
    ascending: bool,
) -> Result<Vec<Vec<f64>>, String> {
    match shape_type {
        "uniform" => Ok(uniform_gradient(x, params)),
        "gradational" => Ok(gradational_gradient(x, params, ascending)),
        "wetting_front" => Ok(wetting_front_gradient(x, params, ascending)),
        "exponential" => Ok(finite_difference_gradient(x, params, ascending, exponential)),
        "abrupt" => Ok(finite_difference_gradient(x, params, ascending, abrupt)),
        "peak" => Ok(finite_difference_gradient(x, params, ascending, peak)),
        "minimax" => Ok(finite_difference_gradient(x, params, ascending, minimax)),
        "monotone_cubic_spline" => monotone_cubic_spline_gradient(x, params),
        "restricted_cubic_spline" => restricted_cubic_spline_gradient(x, params),
        _ => Err(format!("Unknown shape type: {}", shape_type)),
    }
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
/// Result with vector of `[0, 1]` values or error string
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
        "monotone_cubic_spline" => {
            if params.len() < 4 || params.len() % 2 != 0 {
                return Err(format!("monotone_cubic_spline requires even-length parameter vector (at least 4 for 2 control points), got {}", params.len()));
            }
            monotone_cubic_spline(x, params)
        },
        "restricted_cubic_spline" => {
            if params.len() < 4 || params.len() % 2 != 0 {
                return Err(format!("restricted_cubic_spline requires even-length parameter vector (at least 4 for 2 control points), got {}", params.len()));
            }
            restricted_cubic_spline(x, params)
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
        let params = vec![75.0, 0.0]; // width = 0 -> hard step
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

    #[test]
    fn test_uniform_gradient() {
        let x = vec![1.0, 50.0, 100.0];
        let params = vec![0.5];
        let grad = uniform_gradient(&x, &params);
        assert_eq!(grad.len(), 3);
        assert!(grad.iter().all(|g| g.len() == 1 && (g[0] - 1.0).abs() < 1e-10));
    }

    #[test]
    fn test_gradational_gradient() {
        let x = vec![50.0, 100.0, 150.0];
        let params = vec![50.0, 150.0];
        let grad = gradational_gradient(&x, &params, true);
        assert_eq!(grad.len(), 3);
        // Each gradient should have 2 components (df/dstart, df/dend)
        assert!(grad.iter().all(|g| g.len() == 2));
        // Gradients should be finite
        assert!(grad.iter().all(|g| g.iter().all(|&gi| gi.is_finite())));
    }

    #[test]
    fn test_eval_shape_gradient() {
        let x = vec![1.0, 50.0, 100.0];
        let params = vec![0.5];
        let result = eval_shape_gradient("uniform", &x, &params, true);
        assert!(result.is_ok());
        let grad = result.unwrap();
        assert_eq!(grad.len(), 3);
    }

    #[test]
    fn test_finite_difference_gradient() {
        // Test that finite differences work for complex shapes
        let x = vec![50.0, 100.0, 150.0];
        let params = vec![100.0, 30.0];
        let result = eval_shape_gradient("peak", &x, &params, true);
        assert!(result.is_ok());
        let grad = result.unwrap();
        assert_eq!(grad.len(), 3);
        assert!(grad.iter().all(|g| g.len() == 2));
        // Gradients should be finite
        assert!(grad.iter().all(|g| g.iter().all(|&gi| gi.is_finite())));
    }
}
