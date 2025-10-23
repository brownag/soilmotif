# Sieve Bootstrap Quick Reference

## What is Sieve Bootstrap?

Sieve bootstrap is a resampling method for uncertainty quantification that:
1. **Fits an AR(1) model** to residuals from the initial fit
2. **Non-parametrically resamples innovations** (residuals) from the AR(1) process
3. **Reconstructs residuals** respecting temporal autocorrelation
4. **Re-optimizes parameters** for each bootstrap sample to get confidence intervals

**Best for**: Dense depth profiles with spatially-correlated residuals (typical in soil science)

## Quick Start (3 lines)

```r
# Automatic method selection - uses sieve for dense data
result <- sm_optim_bootstrap(observed, initial_params = c(100, 20),
                             shape_family = "sigmoid", n_bootstrap = 1000)
```

## Method Comparison

| Feature | Parametric | Sieve |
|---------|-----------|-------|
| **When Used** | n <= 20 (sparse) | n > 20 (dense) |
| **Assumption** | Normal residuals | AR(1) autocorrelation |
| **Speed** | Faster | Slightly slower |
| **Best For** | Sparse/irregular data | High-resolution profiles |
| **AR(1) Coef** | N/A | Yes, exposed as `ar1_coef` |

## Function Signature

```r
sm_optim_bootstrap(
  observed,                    # Your data vector
  initial_params,              # Starting parameter values
  shape_family = "sigmoid",    # Shape type (sigmoid, exponential, etc.)
  n_bootstrap = 1000,          # Number of bootstrap samples
  ci = 0.95,                   # Confidence level (e.g., 0.95 for 95% CI)
  method = "auto",             # "auto", "parametric", or "sieve"
  sieve_threshold = 20,        # Threshold for auto-selection
  strict = FALSE,              # Error on AR fit failure? (vs fallback)
  seed = NULL,                 # Optional seed for reproducibility
  optimizer = "lbfgs",         # Optimization algorithm
  objective = "rmse"           # Objective function
)
```

## Common Use Cases

### 1. Dense Profile Data (Use Sieve Bootstrap)

```r
# High-resolution clay content profile (200 measurements)
clay_profile <- rep(c(10, 15, 20, 25, 30, 35, 40), length.out = 200)

result <- sm_optim_bootstrap(
  observed = clay_profile,
  initial_params = c(25, 100),
  shape_family = "sigmoid",
  n_bootstrap = 1000,
  method = "auto"  # Automatically selects sieve (n=200 > 20)
)

# View confidence intervals
print(result$param_ci_lower)  # Lower bounds
print(result$param_ci_upper)  # Upper bounds

# Check AR(1) coefficient
print(result$ar1_coef)        # Autocorrelation estimate
```

### 2. Sparse Horizon Data (Use Parametric Bootstrap)

```r
# Discrete horizon data (only 5 horizons)
horizon_clay <- c(10, 20, 35, 40, 42)

result <- sm_optim_bootstrap(
  observed = horizon_clay,
  initial_params = c(25, 10),
  shape_family = "sigmoid",
  n_bootstrap = 1000,
  method = "auto"  # Automatically selects parametric (n=5 <= 20)
)

print(result$method_used)  # Will be "parametric"
```

### 3. Explicit Method Control

```r
# Force sieve bootstrap regardless of data size
result_sieve <- sm_optim_bootstrap(
  observed = data,
  initial_params = initial,
  shape_family = "sigmoid",
  n_bootstrap = 1000,
  method = "sieve",     # Explicit choice
  strict = FALSE        # Fall back to parametric if AR fit fails
)

# Force parametric bootstrap (no AR modeling)
result_param <- sm_optim_bootstrap(
  observed = data,
  initial_params = initial,
  shape_family = "sigmoid",
  n_bootstrap = 1000,
  method = "parametric"  # No sieve, ever
)
```

### 4. Reproducible Results

```r
# Get identical results on repeated runs
result1 <- sm_optim_bootstrap(data, initial, seed = 42)
result2 <- sm_optim_bootstrap(data, initial, seed = 42)

# Confidence intervals are identical
identical(result1$param_ci_lower, result2$param_ci_lower)  # TRUE
```

## Understanding the Output

```r
result <- sm_optim_bootstrap(...)

# Key components:
result$param_estimates    # Estimated parameters from original fit
result$param_ci_lower     # 95% CI lower bounds (default)
result$param_ci_upper     # 95% CI upper bounds (default)
result$param_samples      # Matrix: 1000 rows × n_params columns
                          # (each row = one bootstrap resample)

result$original_cost      # RMSE/SSE/etc from original fit
result$method_used        # "parametric" or "sieve"
result$ar1_coef           # AR(1) coefficient (NA for parametric)

result$successful_fits    # Number of successful bootstrap iterations
result$failed_fits        # Number of failed iterations (stored as NaN)

# Print methods:
print(result)             # Summary table
summary(result)           # Detailed summary
```

## AR(1) Model Interpretation

When sieve bootstrap is used, the AR(1) coefficient (φ) describes residual autocorrelation:

**r_t = φ * r_(t-1) + ε_t + mean**

- **φ = 0**: No autocorrelation (independent residuals)
- **φ > 0**: Positive autocorrelation (residuals tend to persist)
- **φ < 0**: Negative autocorrelation (residuals tend to alternate)
- **|φ| < 1**: Stationary process (required for validity)

**Example**:
```r
result <- sm_optim_bootstrap(clay, initial = c(25, 100), method = "sieve")
cat("AR(1) coefficient:", result$ar1_coef, "\n")
# Output: AR(1) coefficient: 0.68
# Interpretation: Residuals show moderate positive autocorrelation
```

## Fallback Behavior

The `strict` parameter controls what happens if AR(1) fitting fails:

```r
# With strict = FALSE (default), auto-select falls back gracefully
result <- sm_optim_bootstrap(..., method = "auto", strict = FALSE)
# If AR fit fails and n > 20: Falls back to parametric + warning
# If AR fit succeeds: Uses sieve

# With strict = TRUE, auto-select errors on AR fit failure
result <- sm_optim_bootstrap(..., method = "auto", strict = TRUE)
# If AR fit fails and n > 20: ERROR
# If AR fit succeeds: Uses sieve

# With explicit method = "sieve", ALWAYS errors on AR fit failure
result <- sm_optim_bootstrap(..., method = "sieve", strict = TRUE)
# AR fit fails: ERROR (regardless of strict setting)
# Rationale: User explicitly requested sieve
```

## Performance Notes

- **Runtime**: ~3-5 seconds for 1000 samples (200 observations, 2 parameters)
- **Memory**: ~O(n_bootstrap × n_params) for parameter matrix storage
- **Parallelization**: Full rayon support across bootstrap iterations
- **Speedup vs R**: ~10-15x faster (via Rust backend)

## Threshold Customization

Default threshold for auto-selection is 20 observations:

```r
# Use sieve for data with > 50 observations
result <- sm_optim_bootstrap(..., method = "auto", sieve_threshold = 50)

# Use sieve for data with > 10 observations (more aggressive)
result <- sm_optim_bootstrap(..., method = "auto", sieve_threshold = 10)
```

## Troubleshooting

### "AR model fitting failed" Error
```r
# Occurs when: method="sieve" and AR(1) coefficient outside valid range
# Solution 1: Use fallback
result <- sm_optim_bootstrap(..., method = "auto", strict = FALSE)

# Solution 2: Check for flat profiles
plot(observed)  # Should show variation

# Solution 3: Verify stationarity of residuals
fit <- sm_optim(observed, initial)
residuals <- observed - sm_motif(observed, fit$params)
plot(residuals)  # Should show no trends
```

### Different CI Each Run
```r
# Forgot to set seed!
# Solution: Always provide seed for reproducibility
result <- sm_optim_bootstrap(..., seed = 42)
```

### Slow Runtime
```r
# Solution 1: Reduce n_bootstrap (accuracy/speed tradeoff)
result <- sm_optim_bootstrap(..., n_bootstrap = 500)  # vs 1000

# Solution 2: Use simpler shape family
result <- sm_optim_bootstrap(..., shape_family = "exponential")

# Solution 3: Check if Rust backend is available
rust_backend_available()  # Should be TRUE
```

## Related Functions

```r
# Fit single profile with optimization
sm_optim(observed, initial_params, shape_family = "sigmoid")

# Evaluate shape at parameters
sm_motif(depths, params)

# Auto model selection across all shapes
fit_motif_auto(observed)

# Batch fitting multiple profiles
batch_optimize_profiles(list_of_profiles)

# Check Rust availability
rust_backend_available()
```

## References & Further Reading

- **Implementation**: `.github/SIEVE-BOOTSTRAP-IMPLEMENTATION-COMPLETE.md`
- **Specification**: `.github/prompts/0.1.0/03-Phase-3-Advanced-Analysis/03e-uncertainty.md`
- **Vignette**: `vignette("fitting-motifs")`
- **Function Help**: `?sm_optim_bootstrap`

## Examples in Package

```r
# Run examples from help
example(sm_optim_bootstrap)

# View vignette
vignette("fitting-motifs", package = "soilmotif")

# Run tests
testthat::test_file("tests/testthat/test-uncertainty.R")
```

---

**Version**: Phase 3-03e (Complete)  
**Last Updated**: October 22, 2025  
**Status**: Production Ready ✅
