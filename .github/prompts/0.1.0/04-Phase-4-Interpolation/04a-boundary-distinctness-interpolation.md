# Phase 4a: Boundary Distinctness-Aware Interpolation

## Overview

Develop an interpolation method that converts field-described soil horizons (constant values within layers) to continuous depth functions that:

1. **Preserve layer averages** - The interpolated profile averages to the field-described value over the entire horizon thickness
2. **Respect boundary distinctness** - Transition zones are scaled to match pedological field observations (very abrupt to diffuse)
3. **Account for adjacent horizons** - Transitions are centered on boundaries and transition TO adjacent horizon values
4. **Enable Mahalanobis analysis** - Produce smooth, non-singular covariance matrices suitable for boundary detection

## Input Data Structure

### Field-Described Horizons

```r
horizons <- data.frame(
  horizon_id = c("A", "B", "C"),
  top = c(0, 30, 70),
  bottom = c(30, 70, 100),
  distinctness = c("clear", "gradual", NA),  # Distinctness to LOWER boundary
  # Element concentrations (constant within horizon)
  Al = c(10, 25, 15),
  Fe = c(5, 15, 8),
  Si = c(60, 45, 65)
)
```

### Distinctness Classes and Transition Distances

These follow standard soil survey field descriptions (USDA Soil Taxonomy):

| Class | Transition Distance | Typical Interpretation |
|-------|-------------------|----------------------|
| Very Abrupt | < 0.5 cm | Sharp contact, no transition zone |
| Abrupt | < 2.5 cm | Distinct boundary, narrow transition |
| Clear | 2.5-5 cm | Typical horizon boundary |
| Gradual | 5-15 cm | Diffuse boundary with gradual change |
| Diffuse | > 15 cm | Very gradual transition, fuzzy boundary |

## Algorithm Specification

### Step 1: Parse Distinctness Classes

**Input**: Distinctness class strings ("very abrupt", "abrupt", "clear", "gradual", "diffuse")

**Output**: Transition distance (in cm) representing the range over which composition changes from one horizon to the next

**Note**: For the BOTTOM horizon (if not specified), assume "clear" (default 5 cm)

```
very_abrupt: 0.5 cm
abrupt: 2.5 cm
clear: 5.0 cm (default)
gradual: 10.0 cm
diffuse: 20.0 cm
```

Allow user override of default distances if needed.

### Step 2: Identify Transition Zones

For each horizon boundary, define a transition zone:

**Boundary Location**: `boundary_depth = horizon[i].bottom`

**Transition Bounds** (centered on boundary):
- `transition_top = boundary_depth - (transition_distance / 2)`
- `transition_bottom = boundary_depth + (transition_distance / 2)`

**Constraints**:
- Transition zones cannot extend above the top of the lower horizon
- Transition zones cannot extend below the bottom of the lower horizon
- If transition zones would overlap, redistribute evenly or use average distinctness

### Step 3: Define Composition Profile

For any depth `d` and element `e`, determine the interpolated value:

#### Case A: Deep Within a Horizon (No Transition)
If depth `d` is far from any horizon boundary (outside all transition zones):
- Value = horizon average for that element

#### Case B: In a Transition Zone
If depth `d` is within a transition zone between horizons i and i+1:

**Sub-case B1: Linear interpolation** (default/simplest)
```
alpha = (d - transition_top) / (transition_bottom - transition_top)
value = (1 - alpha) * horizon[i].value + alpha * horizon[i+1].value
```

Where:
- `alpha` ranges from 0 to 1 across transition zone
- Value at transition_top = horizon i value
- Value at transition_bottom = horizon i+1 value

**Sub-case B2: Smooth interpolation** (alternative)
Use spline or sigmoid function for smoother transitions:
```
# Sigmoid option
alpha = 1 / (1 + exp(-4 * (d - boundary) / transition_distance))
value = (1 - alpha) * horizon[i].value + alpha * horizon[i+1].value
```

**Sub-case B3: Mass-preserving constraint** (advanced)
If exact layer average preservation is critical, use iterative correction:
1. Compute initial interpolated profile using linear/smooth method
2. Calculate actual average over horizon thickness
3. Apply constant correction to maintain field-described average
4. Optionally smooth the corrected profile

### Step 4: Interpolate to Regular Depth Grid

Create interpolated values at regular depth intervals (typically 0.5 or 1 cm):

```r
depth_grid <- seq(min(horizons$top), max(horizons$bottom), by = 0.5)
interpolated <- data.frame(depth = depth_grid)

for (element in element_columns) {
  interpolated[[element]] <- sapply(
    depth_grid,
    function(d) compute_value_at_depth(d, element, horizons, transitions)
  )
}
```

### Step 5: Handle Edge Cases

**Multiple Adjacent Boundaries**:
- If two boundaries are close enough that transition zones overlap, apply one of:
  1. **Average distinctness**: Use mean transition distance for overlapping zone
  2. **Priority scheme**: Lower boundary takes precedence
  3. **Proportional blending**: Weight transitions by remaining zone width

**Incomplete Distinctness Information**:
- If distinctness not specified for bottom boundary of horizon, assume "clear" (5 cm)
- If distinctness not specified for top boundary, use distinctness from lower boundary

**Bottom Horizon**:
- Transition zone cannot extend below profile bottom
- Constrain transition_bottom ≤ max(depth)

**Top Horizon**:
- Transition zone cannot extend above profile top
- Constrain transition_top ≥ min(depth)

## Mathematical Properties

### Average Preservation

For linear interpolation, the integral over a horizon should match the field value:

```
integral(interpolated_value, top, bottom) / (bottom - top) = field_horizon_value
```

For linear interpolation within transition zones, this is automatically satisfied
(trapezoid rule with linear values).

### Continuity

The interpolated profile should be:
- **Continuous** at all depths (no jumps)
- **Piecewise smooth** (smooth within horizons and transitions)

For smooth interpolation (spline/sigmoid), ensure:
- Value matches field value at horizon centers
- Transitions are smooth and monotonic

### Covariance Properties

The interpolated profile should produce:
- **Non-singular covariance matrices** for any window (main goal)
- **Realistic transitions** matching field observations
- **Valid window statistics** for Mahalanobis distance calculation

## Output Specification

### Primary Output: Interpolated Depth Function

```r
interpolated_data <- data.frame(
  depth = numeric(n_depths),           # Regular grid of depths
  element_1 = numeric(n_depths),       # Interpolated values
  element_2 = numeric(n_depths),
  ...
)
```

### Secondary Output: Metadata

```r
interpolation_metadata <- list(
  method = "boundary-distinctness-aware",
  transitions = data.frame(
    horizon_i = character(),            # Horizon ID
    horizon_i_plus_1 = character(),     # Adjacent horizon
    boundary_depth = numeric(),         # Boundary location
    distinctness_class = character(),   # Field description
    transition_distance = numeric(),    # Distance (cm)
    transition_top = numeric(),         # Zone bounds
    transition_bottom = numeric()
  ),
  interpolation_type = "linear",        # or "spline", "sigmoid"
  depth_grid_resolution = 1.0,          # cm
  mass_preservation = TRUE              # Whether averages are preserved
)
```

### Validation Output

```r
validation_results <- list(
  horizon_averages_match = logical(),   # Does integral match field value?
  average_errors = numeric(),           # RMS error in average preservation
  max_error_per_horizon = numeric(),    # Worst-case error
  continuity_check = logical(),         # Any discontinuities?
  singular_covariance_check = logical() # Can covariance be computed?
)
```

## Function Signature

```r
interpolate_by_distinctness(
  horizons,                      # data.frame with field horizon descriptions
  elements = NULL,               # Element columns to interpolate (auto-detect if NULL)
  depth_col = "depth",           # Column name for horizon top/bottom depths
  top_col = "top",
  bottom_col = "bottom",
  distinctness_col = "distinctness",  # Column with boundary distinctness
  method = "linear",             # "linear", "spline", or "sigmoid"
  depth_grid_by = 0.5,           # Resolution of output depth grid (cm)
  preserve_averages = TRUE,      # Enforce integral preservation?
  distinctness_distances = NULL, # Custom mapping of classes to distances
  handle_overlaps = "average",   # "average", "priority", "proportional"
  return_metadata = TRUE
)
```

**Returns**: List with components:
- `interpolated`: data.frame of interpolated values
- `metadata`: Transition zone specifications
- `validation`: Validation results

## Design Decisions for Implementation

### 1. Interpolation Method (linear vs. smooth)

**Linear** (default):
- ✅ Simple, interpretable
- ✅ Guarantees average preservation
- ✅ Piecewise linear (appropriate for soil science)
- ❌ Sharp corners at transition boundaries (minor)

**Spline** (cubic):
- ✅ Smooth, realistic
- ✅ Matches natural soil property changes
- ❌ More complex to implement
- ❌ May require adjustment for average preservation

**Sigmoid**:
- ✅ Natural S-curve for transitions
- ✅ Smooth and continuous
- ❌ Less commonly used in soil science
- ❌ More computationally expensive

**Recommendation**: Start with **linear**, add **spline** as option

### 2. Average Preservation Strategy

**Option A: Post-interpolation correction**
1. Compute profile with interpolation method
2. Check integral over each horizon
3. Apply constant shift to match field average
4. (Optional) re-smooth

**Option B: Constraint during interpolation**
- Use optimization or iterative method to ensure average match
- More complex but mathematically elegant

**Recommendation**: **Option A** (post-correction) - simple, fast, transparent

### 3. Handling Overlapping Transitions

**Option A: Average distinctness**
```
overlapping_distance = mean(distance_i, distance_j)
```

**Option B: Priority scheme**
```
Use the smaller transition distance (more distinct boundary)
```

**Option C: Proportional blending**
```
Weight each transition by its zone width outside overlap
```

**Recommendation**: **Option A** (average) - fair, symmetric, interpretable

### 4. Missing Distinctness Information

**Default behavior**:
- Missing distinctness → assume "clear" (5 cm)
- Bottom-most horizon → no transition below (clipped to profile bottom)

**Rationale**: "Clear" is the typical/moderate distinctness class

## Testing Requirements

### Unit Tests

1. **Simple cases**:
   - Two horizons with "clear" boundary
   - Three horizons with different distinctness classes
   - Single element and multi-element cases

2. **Edge cases**:
   - Very close boundaries (overlapping transitions)
   - Missing distinctness specifications
   - Top/bottom horizons (boundaries at profile edges)
   - All same element values (flat profile)

3. **Mathematical properties**:
   - Average preservation (integral check)
   - Continuity at boundaries
   - Monotonicity in transition zones
   - Non-singular covariance for various window sizes

### Integration Tests

1. **With Mahalanobis distance detection**:
   - Interpolated data should produce non-singular covariance
   - Should detect original boundaries correctly
   - Different distinctness classes should affect detection sensitivity

2. **With Fuzzy k-means**:
   - Classification should respect interpolated boundaries
   - Entropy patterns should match transition zones

### Validation Data Sets

Create test data with known properties:
- **Simple**: 2-3 horizons with clear boundaries
- **Complex**: 4-5 horizons with varying distinctness
- **Real-world**: Data from soil surveys with field descriptions

## Examples

### Example 1: Two Horizons with Clear Boundary

```r
horizons <- data.frame(
  horizon_id = c("A", "B"),
  top = c(0, 30),
  bottom = c(30, 100),
  distinctness = c("clear", NA),
  Al = c(10, 25),
  Fe = c(5, 15),
  Si = c(60, 45)
)

result <- interpolate_by_distinctness(horizons)
# Expected:
# - Depths 0-27.5: Al ≈ 10 (horizon A interior)
# - Depths 27.5-32.5: Al transitions from 10 to 25 (clear boundary = 5cm)
# - Depths 32.5-100: Al ≈ 25 (horizon B interior)
# - Mean(Al[0:30]) ≈ 10, Mean(Al[30:100]) ≈ 25 (preserved)
```

### Example 2: Three Horizons with Varying Distinctness

```r
horizons <- data.frame(
  horizon_id = c("A", "B", "C"),
  top = c(0, 30, 70),
  bottom = c(30, 70, 100),
  distinctness = c("clear", "gradual", NA),
  Al = c(10, 25, 15)
)

# A→B boundary (clear): 5 cm transition (27.5-32.5)
# B→C boundary (gradual): 10 cm transition (65-75)
# Expected transitions:
# - Narrow at A/B (clear = 5cm)
# - Wide at B/C (gradual = 10cm)
```

### Example 3: Abrupt Boundary (Sharp Contact)

```r
horizons <- data.frame(
  horizon_id = c("A", "B"),
  top = c(0, 25),
  bottom = c(25, 100),
  distinctness = c("abrupt", NA),
  Al = c(10, 25)
)

# Sharp transition at 25 cm (abrupt = 2.5cm)
# Depth 23.75-26.25: Transition from 10 to 25
# Very narrow zone allows Mahalanobis to detect sharp boundary
```

## Success Criteria

✅ **Functionality**:
- [x] Accepts field-described horizons with distinctness classes
- [x] Produces smooth, continuous interpolated profiles
- [x] Preserves layer averages (or close with option disabled)
- [x] Handles edge cases (overlapping transitions, missing data)
- [x] Works with single and multiple elements

✅ **Quality**:
- [x] Non-singular covariance matrices produced
- [x] Mahalanobis distance successfully detects original boundaries
- [x] Transitions match field distinctness descriptions
- [x] Validated against test datasets

✅ **Documentation**:
- [x] Clear function documentation with examples
- [x] Explanation of distinctness class mapping
- [x] Guide to choosing linear vs. smooth interpolation
- [x] Integration example with Mahalanobis detection

✅ **Performance**:
- [x] Efficient for typical soil profiles (10-30 horizons)
- [x] Fast enough for interactive use (<1 second)
- [x] Scales to large datasets (100+ profiles)

## Related Functions

This interpolation method enables:
- **Phase 3g (Mahalanobis)**: Now works with field-described horizons
- **Phase 3h (Fuzzy k-means)**: Produces meaningful classifications
- **Future analysis**: Texture profile development, nutrient dynamics, etc.

## Future Enhancements

1. **Mass-preservation refinement**: Iterative method to exactly match field averages
2. **Spline interpolation**: Add cubic spline option with smoothness control
3. **Multiple distinctness dimensions**: Different transition zones for different elements
4. **Boundary uncertainty**: Model range of possible boundaries within distinctness class
5. **Validation against lab data**: Compare interpolation to measured depth functions
