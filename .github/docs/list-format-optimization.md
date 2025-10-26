# List-Based Optimization Return Format

## Overview

All optimization functions in soilmotif return objects of class `soilmotif_optimization`, which is a properly structured list containing optimization results and metadata.

## Return Format

```r
result <- sm_optim(observed, params)

# result is a list with class "soilmotif_optimization":
result <- list(
    fitted      = numeric(200),        # Predicted values
    params      = numeric(n),          # Optimized parameters
    observed    = numeric(200),        # Original input
    depths      = numeric(200),        # Depth coordinates
    shape_family = "sigmoid",          # Shape function name
    objective    = "rmse",             # Objective function type
    algorithm    = "nelder_mead",      # Algorithm used
    converged    = TRUE,               # Convergence success flag
    message      = "Completed..."      # Status message
)
```

## Access Patterns

### Basic Access
```r
result$fitted       # Predicted values (numeric vector)
result$params       # Optimized parameters (numeric vector)
result$observed     # Original input data
result$depths       # Depth coordinates
result$converged    # TRUE/FALSE
```

### With Broom Integration
```r
# Parameter estimates with statistics
tidy(result)        # Returns data.frame: term, estimate, std.error, ...

# Model summary statistics
glance(result)      # Returns data.frame: rmse, r.squared, nobs, npar, aic, ...

# Predictions with residuals
augment(result)     # Returns data.frame: .depth, .observed, .fitted, .resid, ...
```

### For Plotting
```r
# Extract plot-ready data
plot_data <- sm_extract_plot_data(result)

# Base R plotting
plot(result, main = "Soil Profile Fit")

# ggplot2 support
sm_prepare_ggplot_data(result) %>%
  ggplot(aes(x = fitted, y = -depth)) +
  geom_line()
```

## Functions Returning soilmotif_optimization

### Core Functions
- `sm_optim()` - Main optimization dispatcher
- `sm_optim_r_impl()` - R implementation

### Usage
All functions returning this format accept it as input for downstream operations:
- Model selection: `sm_fit_motif_auto()`
- Broom methods: `tidy()`, `glance()`, `augment()`
- Plotting: `plot()`, `sm_plot_residuals()`, `sm_extract_plot_data()`
- ggplot2: `sm_prepare_ggplot_data()`
- Bayesian priors: `sm_to_priors()`

## Implementation Details

### Rust Backend Integration
When `use_rust=TRUE`, the Rust optimization returns a parameter vector which is wrapped in the standard list format:

```r
# Rust returns: numeric(n) parameters
# These are wrapped into the standard format:
result <- list(
    fitted = sm_motif(observed, rust_params, ...),
    params = rust_params,
    # ... other fields ...
)
class(result) <- "soilmotif_optimization"
```

### Scale Method Parameter
All functions support the `scale_method` parameter:
- `"proportional"` (default): Flexible asymptotes, preserves relative structure
- `"anchored"`: Forces min/max to match data extremes

## Examples

### Basic Fitting
```r
x <- c(rep(10, 50), seq(10, 40, length.out=100), rep(40, 50))
result <- sm_optim(x, c(30, 50), FUN = sm_shape_gradational)
result$fitted   # 200 predicted values
result$params   # Optimized parameters
result$converged  # TRUE if optimization succeeded
```

### Model Selection
```r
auto_fit <- sm_fit_motif_auto(x, criterion = "AIC")
auto_fit$best   # Best model name
auto_fit$fits   # List of all fits (each is soilmotif_optimization)
```

### Integration with Tidyverse
```r
library(broom)
result <- sm_optim(x, c(30, 50))

tidy(result)        # Parameter table
glance(result)      # Model fit summary
augment(result)     # Data with predictions
```

## Migration from Earlier Versions

If transitioning from 0.0.1 (which used vector+attributes):
- Old: `result` was numeric vector, access params via `attr(result, 'par')`
- New: `result` is list, access params via `result$params`
- Fitted values are now always at `result$fitted`

## See Also

- [Scaling Methods Documentation](scaling-methods.md)
- sm_optim() function documentation
- sm_motif() function documentation
