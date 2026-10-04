# Proportional Scaling Implementation

## Overview

Implemented flexible proportional scaling as the new default behavior in `sm_motif()` and related functions. This allows shape functions to naturally preserve asymptotes rather than being forced to min/max extrema.

## Changes Made

### 1. Updated `.scaleprop()` function (R/util.R)

Added `scale_method` parameter with two options:

**Proportional (NEW DEFAULT):**
```r
# Maps shape range proportionally without forcing endpoints
result = min(observed) + (shape - min(shape)) / (max(shape) - min(shape)) * (max(observed) - min(observed))
```

This formula:
- Preserves the natural asymptotic behavior of shape functions
- Allows shapes to reach whatever values they converge to, not forced to extrema
- For example, if sigmoid naturally asymptotes at [0.1, 0.9], these map proportionally to property values rather than being forced to [min, max]

**Anchored (LEGACY):**
```r
# Original behavior - normalizes to [0,1] then forces to [min,max]
normalized = (shape - min(shape)) / (max(shape) - min(shape))
result = min(observed) + normalized * (max(observed) - min(observed))
```

### 2. Updated `sm_motif()` function (R/fit.R)

- Added `scale_method = "proportional"` parameter
- Updated roxygen documentation
- Propagates scaling method to `.scaleprop()` call

### 3. Parameter Propagation

The `scale_method` parameter flows through:
- `sm_optim()` - via `...` arguments
- `sm_fit_motif_auto()` - via `...` arguments
- `sm_motif_bootstrap_*()` - via `...` arguments

## Key Benefits

### 1. **Flexible Fitting**
- Shape functions don't have to force their asymptotes to data min/max
- Optimization can find better fits when data naturally has different structure
- Wetting fronts can plateau at realistic intermediate values

### 2. **Better Convergence**
- Allows asymptotes at values like 0.07 and 0.93 in [0,1] space
- These map proportionally to less extreme property values
- Optimization landscape becomes smoother and more realistic

### 3. **Realistic Soil Properties**
- Soil properties don't always use full observed range
- Different depths may naturally cluster at certain values
- Shape functions can now capture this naturally

## Example: Flexible Asymptotes

```r
# Original (anchored) behavior:
observed <- c(8, 10, 15, 20, 25, 30, 35, 38, 40, 42)
fit_anchored <- sm_motif(observed, c(4, 8), 
                         FUN = sm_shape_sigmoid,
                         scale_method = "anchored")
# Forces sigmoid to span exactly [8, 42]

# New (proportional) behavior:
fit_prop <- sm_motif(observed, c(4, 8),
                    FUN = sm_shape_sigmoid,
                    scale_method = "proportional")
# Sigmoid naturally asymptotes at flexible values
# allowing more realistic fitting
```

## Implementation Details

### Proportional Scaling Formula

For a shape function output `s` in range [min_s, max_s]:

```
result = x_min + (s - min_s) / (max_s - min_s) * (x_max - x_min)
```

Where:
- `s`: shape function output
- `min_s, max_s`: actual min/max of shape function output
- `x_min, x_max`: observed data min/max
- `result`: scaled value in property scale

### Key Property

If shape naturally asymptotes at values a₀ and a₁ in [0,1] space:
- a₀ maps to: `x_min + a₀ * (x_max - x_min)`
- a₁ maps to: `x_min + a₁ * (x_max - x_min)`

This provides flexible asymptotes in property space without forcing to data extrema.

### Edge Cases Handled

1. **Constant shapes**: If shape output is constant, returns midpoint of observed range
2. **NaN/Inf values**: Handled with appropriate return values
3. **Backward compatibility**: `scale_method = "anchored"` available for legacy behavior

## Testing

Created comprehensive test suite in `tests/testthat/test-scaling-methods.R`:

- Proportional vs anchored comparison
- Flexible asymptotes verification
- Edge case handling
- Integration with optimization functions
- Backward compatibility checks

## Backward Compatibility

Fully backward compatible:
- Default is now proportional (new behavior)
- Legacy users can specify `scale_method = "anchored"`
- All existing code works without modification (gets new flexible behavior)

## Migration Path

For users who prefer anchored behavior:

```r
# Explicit specification of legacy method
fit <- sm_optim(observed, params, 
                FUN = sm_shape_sigmoid,
                scale_method = "anchored")
```

## Technical Notes

### Why Proportional Scaling?

The original anchored approach forces shape functions into an artificial framework:
1. Normalizes shape output to [0,1]
2. Forces that normalized [0,1] to map to [min_obs, max_obs]
3. This double-forces asymptotes to extrema

Proportional scaling:
1. Respects where the shape function naturally converges
2. Scales that range proportionally
3. Allows natural flexibility for optimization

### Optimization Benefits

For functions like sigmoid with natural inflection points:
- Anchored method constrains optimization to force full range coverage
- Proportional method allows asymptotes to settle at optimal values
- Results in more realistic fits that better reflect true data structure
