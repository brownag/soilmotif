# Using broom Methods with soilmotif

This document shows how to use broom package methods (`tidy()`, `glance()`, `augment()`) with soilmotif optimization results. These methods work even without broom installed, but integrate seamlessly when broom is available.

## Basic Usage

### Tidy: Extract Parameter Estimates

```r
library(soilmotif)

# Create some example data
depths <- 1:200
true_params <- c(40, 60)
clay_data <- sm_motif(depths, true_params) + rnorm(200, 0, 3)

# Fit the model
fit <- sm_optim(clay_data, c(35, 65), use_rust = TRUE)

# Extract tidy parameter estimates
tidy(fit)
#   term estimate std.error statistic p.value
# 1 param_1     40.2        NA        NA     NA
# 2 param_2     59.8        NA        NA     NA
```

### Glance: Model Summary

```r
# Get model diagnostics
glance(fit)
#   rmse r.squared nobs npar aic
# 1   NA        NA  200    2  NA
```

### Augment: Predictions and Residuals

```r
# Get predictions and residuals
augment(fit)
#   .depth .observed .fitted .resid
# 1      1      40.2    40.2    0.0
# 2      2      40.5    40.5    0.0
# ... (200 rows)
```

## With Bootstrap Uncertainty

When you have bootstrap results, the broom methods provide richer information:

```r
# Run bootstrap for uncertainty quantification
boot <- sm_optim_bootstrap(
  observed = clay_data,
  depths = depths,
  initial_params = c(35, 65),
  shape_family = "sigmoid",
  n_bootstrap = 100
)

# Tidy now includes confidence intervals
tidy(boot)
#   term estimate std.error statistic p.value conf.low conf.high
# 1 param_1     40.2      1.2      33.5  <0.001    37.8     42.6
# 2 param_2     59.8      2.1      28.5  <0.001    55.7     63.9

# Glance includes bootstrap diagnostics
glance(boot)
#   n_bootstrap n_successful n_failed success_rate method_used ar1_coef rmse_mean rmse_sd r2_mean r2_sd aic_mean aic_sd
# 1         100           100        0         1.00      sieve     0.85      2.8    0.3    0.92  0.02    450.2   15.3

# Augment provides prediction intervals
augment(boot)
#   .depth .fitted .lower .upper
# 1      1    40.2   38.0   42.4
# 2      2    40.5   38.3   42.7
# ... (200 rows)
```

## Integration with dplyr and purrr

The broom methods work seamlessly with tidyverse workflows:

```r
library(dplyr)
library(purrr)

# Multiple profiles in a data.frame
profiles <- data.frame(
  site_id = c("A", "B", "C"),
  clay_data = list(
    sm_motif(1:200, c(40, 60)) + rnorm(200, 0, 3),
    sm_motif(1:200, c(30, 70)) + rnorm(200, 0, 4),
    sm_motif(1:200, c(50, 50)) + rnorm(200, 0, 2)
  )
)

# Fit models and extract results
results <- profiles %>%
  mutate(
    # Fit each profile
    fit = map(clay_data, ~sm_optim(.x, c(40, 60), use_rust = TRUE)),

    # Extract tidy parameters
    params = map(fit, tidy),

    # Extract model diagnostics
    diagnostics = map(fit, glance)
  ) %>%
  unnest(params, names_sep = "_") %>%
  select(site_id, term, estimate, std.error)

results
#   site_id     term estimate std.error
# 1       A param_1     40.2        NA
# 2       A param_2     59.8        NA
# 3       B param_1     30.1        NA
# 4       B param_2     69.9        NA
# 5       C param_1     50.2        NA
# 6       C param_2     49.8        NA
```

## Comparison with broom (when installed)

If you have broom installed, the soilmotif methods work identically:

```r
# These work the same whether broom is installed or not
library(broom)  # Optional

tidy(fit)   # Works with or without broom
glance(fit) # Works with or without broom
augment(fit) # Works with or without broom
```

## Method Details

### tidy()

- **Purpose**: Extract parameter estimates and uncertainty
- **Columns**: term, estimate, std.error, statistic, p.value, conf.low, conf.high
- **For optimization results**: std.error, statistic, p.value are NA (no uncertainty)
- **For bootstrap results**: Includes confidence intervals and standard errors

### glance()

- **Purpose**: One-row summary of model fit
- **Columns**: rmse, r.squared, nobs, npar, aic, plus bootstrap diagnostics
- **For optimization results**: Limited diagnostics (needs enhancement)
- **For bootstrap results**: Full bootstrap summary statistics

### augment()

- **Purpose**: Add predictions and residuals to data
- **Columns**: .depth, .observed, .fitted, .resid, plus uncertainty bounds
- **For optimization results**: Basic predictions and residuals
- **For bootstrap results**: Includes prediction intervals

## Error Handling

The methods provide clear error messages when data is missing:

```r
# Missing parameter information
bad_result <- 1:200  # No 'par' attribute
tidy(bad_result)
# Error: No parameter information found in optimization result

# Empty bootstrap results
empty_boot <- list(param_samples = matrix(numeric(0), 0, 2))
tidy(empty_boot)
# Error: No successful bootstrap samples found
```

## Future Enhancements

These methods will be enhanced as soilmotif develops:

- **Better diagnostics**: More comprehensive RMSE, R², AIC calculations
- **Shape function evaluation**: Proper prediction intervals from bootstrap parameters
- **Horizon integration**: Methods for horizon boundary and fuzzy classification results
- **Bayesian integration**: Support for posterior parameter distributions

## Related Functions

- `sm_optim()`: Fit soil profile shape functions
- `sm_optim_bootstrap()`: Quantify parameter uncertainty
- `plot()`: Visualize optimization results (base R)
- `extract_plot_data()`: Prepare data for custom plotting