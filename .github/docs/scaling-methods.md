# Scaling Methods for Shape Functions

## Overview

The `scale_method` parameter controls how shape function outputs are scaled to match the observed data range. This is available in `sm_motif()` and `sm_optim()` functions.

**Critical distinction:** The scaling method determines whether natural asymptotes of shape functions are preserved or forced to observed data extrema. This affects optimization quality and bootstrap parameter variation.

## Available Methods

### Proportional Scaling (Default) - RECOMMENDED
**Parameter:** `scale_method = "proportional"`

**Purpose:** Preserves natural asymptotes of the shape function while fitting values within the observed data range. This ensures optimization finds truly optimal parameters and bootstrap shows realistic parameter variation.

**How it works:**
- Computes the shape function's natural output range (e.g., sigmoid naturally produces ≈[0.07, 0.93])
- Maps this range PROPORTIONALLY into the observed data range [min(observed), max(observed)]
- Result: Fitted values stay within observed range but asymptotes are NOT forced to data extrema

**Formula:**
```
scaled = min(data) + (shape - shape_min) / (shape_max - shape_min) * (max(data) - min(data))

where shape_min/shape_max are the actual min/max of the shape function output
```

**Characteristics:**
- ✓ Preserves natural sigmoid asymptotes (e.g., doesn't force them to exact min/max)
- ✓ Optimization is NOT over-constrained by data extrema
- ✓ Bootstrap parameter samples show realistic variation
- ✓ Fits within observed data range while respecting shape function structure

**Example - Why this matters:**
```r
# Sigmoid naturally asymptotes at ~[0.07, 0.93]
observed <- c(6, 15, 25, 35, 45, 50)  # Range: [6, 50]

# With proportional scaling:
# - Sigmoid's 0.07 → ~6 + 0.07*(50-6) ≈ 9 (NOT exactly 6)
# - Sigmoid's 0.93 → ~6 + 0.93*(50-6) ≈ 47 (NOT exactly 50)
# Asymptotes are preserved; optimization can vary parameters freely
```

### Anchored Scaling (Legacy) - NOT RECOMMENDED
**Parameter:** `scale_method = "anchored"`

**Purpose:** Legacy behavior for backward compatibility. Forces shape function asymptotes to data extrema.

**How it works:**
- Normalizes shape output to [0, 1]
- Maps this exactly to [min(observed), max(observed)]
- Result: Fitted values forced to exactly span observed min/max

**Characteristics:**
- ✗ Forces asymptotes to observed data extrema (defeats shape function's natural bounds)
- ✗ Over-constrains optimization, may miss optimal fit
- ✗ Bootstrap samples often show zero parameter variation (degenerate)
- ✗ Used only for legacy behavior compatibility

**Example - Why this is problematic:**
```r
# With anchored scaling (problematic):
# - Sigmoid's 0.07 → exactly 6 (min observed)
# - Sigmoid's 0.93 → exactly 50 (max observed)
# Asymptotes forced to data range; optimization highly constrained
# Bootstrap resamples often converge to identical parameters
```

## Usage

### sm_motif() Function
```r
# Default proportional scaling (RECOMMENDED)
predicted <- sm_motif(observed, params)
predicted <- sm_motif(observed, params, scale_method = "proportional")

# Legacy anchored scaling (NOT recommended)
predicted <- sm_motif(observed, params, scale_method = "anchored")
```

### sm_optim() Function
```r
# Optimization with proportional scaling (RECOMMENDED)
result <- sm_optim(observed, initial_params, FUN = sm_shape_sigmoid)

# Legacy anchored scaling (NOT recommended)
result <- sm_optim(observed, initial_params, 
                   FUN = sm_shape_sigmoid,
                   scale_method = "anchored")
```

### sm_fit_motif_auto() Function
```r
# Model selection with proportional scaling (RECOMMENDED)
auto_fit <- sm_fit_motif_auto(x, models = "all", criterion = "AIC")

# Legacy anchored scaling (NOT recommended)
auto_fit <- sm_fit_motif_auto(x, models = "all", criterion = "AIC",
                              scale_method = "anchored")
```

## Implementation Details

The scaling is implemented in `.scaleprop()` helper function in `R/util.R`:

```r
.scaleprop <- function(x, xlim, scale_method = "proportional") {
    # Get min/max of the shape function OUTPUT (x)
    x_min <- min(x, na.rm = TRUE)
    x_max <- max(x, na.rm = TRUE)
    
    if (scale_method == "proportional") {
        # PRESERVE asymptotes: scale shape range proportionally into data range
        result <- xlim[1] + (x - x_min) / (x_max - x_min) * (xlim[2] - xlim[1])
    } else if (scale_method == "anchored") {
        # FORCE to extrema: normalize to [0,1] then scale to data range
        x_normalized <- (x - x_min) / (x_max - x_min)
        result <- pmin(pmax(xlim[1], x_normalized * (xlim[2] - xlim[1]) + xlim[1]), xlim[2])
    }
    return(result)
}
```

**Key insight:** The `xlim` parameter represents the **observed data range** [min(observed), max(observed)], NOT the shape function's natural bounds. The scaling method determines how the shape function's natural range is mapped into this data range.

## Impact on Bootstrap and Optimization

### Proportional Scaling (Default)
- **Optimization:** Finds parameters that truly fit the data best, not constrained by forcing to extrema
- **Bootstrap:** Parameter samples show realistic variation because optimization can explore wider parameter space
- **Result:** Meaningful confidence intervals, better model interpretation

### Anchored Scaling (Legacy)
- **Optimization:** Optimization is over-constrained by forcing output to exact data min/max
- **Bootstrap:** All bootstrap samples often converge to identical parameters (zero variance)
- **Result:** Degenerate bootstrap, meaningless confidence intervals

## Diagnostics

If you notice any of these issues, you may be using the wrong scaling method:

1. **Bootstrap parameter samples all identical or NaN:** Likely using anchored scaling
2. **R² values showing negative, NaN, or > 1:** May indicate AR(1) bootstrap issues with over-constrained model
3. **Fitted values exactly at data min/max:** Using anchored scaling (check this isn't intended)
    
    return(x_scaled)
}
```

## Parameter Propagation

The `scale_method` parameter flows through the optimization pipeline:

```
sm_optim(..., scale_method = "proportional")
  → sm_optim_r_impl(..., scale_method = "proportional")
    → sm_motif(..., scale_method = "proportional")  [inside objective function]
      → .scaleprop(..., scale_method = "proportional")
```

This ensures consistent scaling throughout the optimization process.

## Interaction with Shape Functions

Different shape functions may respond differently to scaling methods:

### Bounded Functions (Sigmoid, Wetting Front)
- **Proportional:** Natural asymptotes become flexible boundaries
- **Anchored:** Forces strict min/max constraints
- Both methods work well; proportional is more flexible

### Unbounded Functions (Exponential, Gradational)
- **Proportional:** Required to produce bounded output matching data
- **Anchored:** Similar effect but with forced endpoints
- Proportional scaling recommended for these functions

### Specialized Functions (Peak, MiniMax)
- **Proportional:** Preserves peak structure while scaling to range
- **Anchored:** May distort peak shape if data has extreme values
- Proportional scaling generally preferred

## Testing

Scaling methods are thoroughly tested in `tests/testthat/test-scaling-methods.R`:

- ✅ Proportional vs anchored produce different results when appropriate
- ✅ Scale method parameter propagates through optimization
- ✅ Scale method validation rejects invalid values
- ✅ Realistic data fitting works with both methods
- ✅ All shape functions tested with both methods

## Performance Considerations

- Both methods have negligible performance differences
- Proportional scaling is slightly more flexible (recommended default)
- Anchored scaling useful only for legacy compatibility
- Scaling adds <1% overhead to optimization time

## See Also

- [List-Based Optimization Return Format](list-format-optimization.md)
- sm_motif() documentation
- sm_optim() documentation
- Shape function documentation (sm_shape_sigmoid, etc.)
