// Horizon boundary detection and classification
// Phase 3g: Mahalanobis distance boundary detection
// Phase 3h: Fuzzy k-means classification

use nalgebra as na;
use ndarray::{Array1, Array2};
use rayon::prelude::*;

/// Compute Mahalanobis distance between two multivariate distributions
///
/// # Arguments
/// * `x` - First sample (center of first distribution)
/// * `y` - Second sample (center of second distribution)
/// * `cov_inv` - Inverse of pooled covariance matrix
///
/// # Returns
/// Mahalanobis distance between x and y
fn mahalanobis_distance(
    x: &na::DVector<f64>,
    y: &na::DVector<f64>,
    cov_inv: &na::DMatrix<f64>,
) -> f64 {
    let diff = y - x;
    let mahal_sq = diff.transpose() * cov_inv * &diff;
    mahal_sq[(0, 0)].sqrt()
}

/// Compute mean of matrix rows
fn compute_mean(data: &na::DMatrix<f64>) -> na::DVector<f64> {
    let n = data.nrows() as f64;
    data.row_sum().transpose().column(0).clone_owned() / n
}

/// Compute covariance matrix from data matrix
fn compute_covariance(data: &na::DMatrix<f64>) -> Option<na::DMatrix<f64>> {
    let n = data.nrows();
    if n < 2 {
        return None;
    }

    let mean = compute_mean(data);
    let centered = data
        .row_iter()
        .map(|row| row.transpose() - &mean)
        .collect::<Vec<_>>();

    let mut cov = na::DMatrix::zeros(data.ncols(), data.ncols());
    for centered_row in &centered {
        cov += centered_row * centered_row.transpose();
    }

    cov /= (n - 1) as f64;
    Some(cov)
}

/// Detect horizon boundaries using split-window Mahalanobis distance
///
/// # Arguments
/// * `element_matrix` - Matrix of element concentrations (n_depths x n_elements)
/// * `depths` - Vector of depth values
/// * `window_size` - Window size in depth units
///
/// # Returns
/// Vector of Mahalanobis distances at each depth
pub fn mahalanobis_boundary_detection(
    element_matrix: &Array2<f64>,
    depths: &Array1<f64>,
    window_size: f64,
) -> Array1<f64> {
    let n_depths = depths.len();
    let mut distances = Array1::from_elem(n_depths, f64::NAN);

    // Parallel processing over depths
    let dist_vec: Vec<(usize, f64)> = (0..n_depths)
        .into_par_iter()
        .filter_map(|i| {
            let center_depth = depths[i];

            // Define windows before and after this depth
            let before_indices: Vec<usize> = (0..n_depths)
                .filter(|&j| {
                    depths[j] >= (center_depth - window_size) && depths[j] < center_depth
                })
                .collect();

            let after_indices: Vec<usize> = (0..n_depths)
                .filter(|&j| depths[j] > center_depth && depths[j] <= (center_depth + window_size))
                .collect();

            if before_indices.len() < 2 || after_indices.len() < 2 {
                return None;
            }

            // Extract data for each window
            let before_data = extract_rows(element_matrix, &before_indices);
            let after_data = extract_rows(element_matrix, &after_indices);

            // Compute centers
            let before_center = compute_mean(&before_data);
            let after_center = compute_mean(&after_data);

            // Compute covariances
            let before_cov = compute_covariance(&before_data)?;
            let after_cov = compute_covariance(&after_data)?;

            // Pooled covariance
            let pooled_cov = (&before_cov + &after_cov) / 2.0;

            // Invert covariance matrix
            let cov_inv = pooled_cov.clone().try_inverse()?;

            // Compute Mahalanobis distance
            let dist = mahalanobis_distance(&before_center, &after_center, &cov_inv);

            Some((i, dist))
        })
        .collect();

    // Fill in computed distances
    for (idx, dist) in dist_vec {
        distances[idx] = dist;
    }

    distances
}

/// Extract specified rows from Array2 and convert to DMatrix
fn extract_rows(arr: &Array2<f64>, indices: &[usize]) -> na::DMatrix<f64> {
    let n_rows = indices.len();
    let n_cols = arr.ncols();

    let mut data = Vec::with_capacity(n_rows * n_cols);
    for &i in indices {
        for j in 0..n_cols {
            data.push(arr[[i, j]]);
        }
    }

    na::DMatrix::from_row_slice(n_rows, n_cols, &data)
}

/// Fuzzy k-means clustering for horizon classification
///
/// # Arguments
/// * `data` - Data matrix (n_samples x n_features)
/// * `k` - Number of clusters
/// * `m` - Fuzziness exponent (> 1.0)
/// * `max_iter` - Maximum iterations
/// * `tol` - Convergence tolerance
/// * `centers_init` - Initial cluster centers (k x n_features)
///
/// # Returns
/// Tuple of (centers, memberships, converged, iterations)
pub fn fuzzy_kmeans(
    data: &Array2<f64>,
    k: usize,
    m: f64,
    max_iter: usize,
    tol: f64,
    centers_init: &Array2<f64>,
) -> (Array2<f64>, Array2<f64>, bool, usize) {
    assert!(m > 1.0, "Fuzziness exponent m must be > 1.0");
    assert_eq!(centers_init.nrows(), k, "Initial centers must have k rows");
    assert_eq!(
        centers_init.ncols(),
        data.ncols(),
        "Centers must match data dimensions"
    );

    let n = data.nrows();
    let p = data.ncols();

    let mut centers = centers_init.clone();
    let mut memberships = Array2::zeros((n, k));

    let exp_factor = 2.0 / (m - 1.0);

    let mut converged = false;

    for iter in 0..max_iter {
        let memberships_old = memberships.clone();

        // Step 1: Update membership matrix (parallel over samples)
        let membership_rows: Vec<Vec<f64>> = (0..n)
            .into_par_iter()
            .map(|i| {
                let sample = data.row(i);
                let mut row = Vec::with_capacity(k);

                // Compute distances to all centers
                let mut distances = Vec::with_capacity(k);
                for j in 0..k {
                    let center = centers.row(j);
                    let dist = euclidean_distance(&sample, &center);
                    distances.push(dist.max(1e-10)); // Avoid division by zero
                }

                // Compute memberships
                for j in 0..k {
                    let ratio_sum: f64 = (0..k)
                        .map(|l| (distances[j] / distances[l]).powf(exp_factor))
                        .sum();
                    row.push(1.0 / ratio_sum);
                }

                row
            })
            .collect();

        // Fill membership matrix
        for (i, row) in membership_rows.iter().enumerate() {
            for (j, &val) in row.iter().enumerate() {
                memberships[[i, j]] = val;
            }
        }

        // Normalize memberships (ensure rows sum to 1)
        for i in 0..n {
            let row_sum: f64 = memberships.row(i).sum();
            if row_sum > 1e-10 {
                for j in 0..k {
                    memberships[[i, j]] /= row_sum;
                }
            }
        }

        // Step 2: Update centers (parallel over clusters)
        let center_rows: Vec<Vec<f64>> = (0..k)
            .into_par_iter()
            .map(|j| {
                let mut new_center = vec![0.0; p];
                let mut weight_sum = 0.0;

                for i in 0..n {
                    let weight = memberships[[i, j]].powf(m);
                    weight_sum += weight;

                    for d in 0..p {
                        new_center[d] += weight * data[[i, d]];
                    }
                }

                if weight_sum > 1e-10 {
                    for d in 0..p {
                        new_center[d] /= weight_sum;
                    }
                }

                new_center
            })
            .collect();

        // Update centers
        for (j, row) in center_rows.iter().enumerate() {
            for (d, &val) in row.iter().enumerate() {
                centers[[j, d]] = val;
            }
        }

        // Step 3: Check convergence (membership change)
        let max_change = memberships
            .iter()
            .zip(memberships_old.iter())
            .map(|(new, old)| (new - old).abs())
            .fold(0.0, f64::max);

        if max_change < tol {
            converged = true;
            return (centers, memberships, converged, iter + 1);
        }
    }

    (centers, memberships, converged, max_iter)
}

/// Compute Euclidean distance between two array views
fn euclidean_distance(
    a: &ndarray::ArrayView1<f64>,
    b: &ndarray::ArrayView1<f64>,
) -> f64 {
    a.iter()
        .zip(b.iter())
        .map(|(x, y)| (x - y).powi(2))
        .sum::<f64>()
        .sqrt()
}

/// Compute normalized entropy for fuzzy memberships
///
/// # Arguments
/// * `memberships` - Membership matrix (n_samples x k)
///
/// # Returns
/// Vector of normalized entropy values [0, 1] per sample
pub fn compute_entropy(memberships: &Array2<f64>) -> Array1<f64> {
    let n = memberships.nrows();
    let k = memberships.ncols();
    let log_k = (k as f64).ln();

    let entropy_vec: Vec<f64> = (0..n)
        .into_par_iter()
        .map(|i| {
            let row = memberships.row(i);
            let entropy: f64 = row
                .iter()
                .filter(|&&u| u > 1e-10)
                .map(|&u| -u * u.ln())
                .sum();
            entropy / log_k // Normalize to [0, 1]
        })
        .collect();

    Array1::from_vec(entropy_vec)
}

#[cfg(test)]
mod tests {
    use super::*;
    use ndarray::arr2;

    #[test]
    fn test_mahalanobis_distance() {
        let x = na::DVector::from_vec(vec![0.0, 0.0]);
        let y = na::DVector::from_vec(vec![1.0, 1.0]);
        let cov_inv = na::DMatrix::identity(2, 2);

        let dist = mahalanobis_distance(&x, &y, &cov_inv);
        assert!((dist - 1.414213).abs() < 0.001);
    }

    #[test]
    fn test_compute_mean() {
        let data = na::DMatrix::from_row_slice(3, 2, &[1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
        let mean = compute_mean(&data);
        assert_eq!(mean[0], 3.0);
        assert_eq!(mean[1], 4.0);
    }

    #[test]
    fn test_fuzzy_kmeans_basic() {
        // Simple 2-cluster data
        let data = arr2(&[
            [0.0, 0.0],
            [0.1, 0.1],
            [0.2, 0.2],
            [10.0, 10.0],
            [10.1, 10.1],
            [10.2, 10.2],
        ]);

        let centers_init = arr2(&[[0.0, 0.0], [10.0, 10.0]]);

        let (centers, memberships, converged, _) =
            fuzzy_kmeans(&data, 2, 2.0, 100, 1e-4, &centers_init);

        assert!(converged);
        assert_eq!(centers.nrows(), 2);
        assert_eq!(memberships.nrows(), 6);

        // Check memberships sum to 1
        for i in 0..6 {
            let row_sum: f64 = memberships.row(i).sum();
            assert!((row_sum - 1.0).abs() < 1e-6);
        }
    }

    #[test]
    fn test_compute_entropy() {
        let memberships = arr2(&[
            [1.0, 0.0, 0.0], // Certain assignment
            [0.33, 0.33, 0.34], // Maximum uncertainty
            [0.7, 0.2, 0.1], // Moderate uncertainty
        ]);

        let entropy = compute_entropy(&memberships);

        assert!(entropy[0] < 0.1); // Low entropy (certain)
        assert!(entropy[1] > 0.9); // High entropy (uncertain)
        assert!(entropy[2] > 0.4 && entropy[2] < 0.7); // Moderate
    }
}
