# Boundary Distinctness Interpolation - Quick Reference

## The Problem

Field-described horizons have **constant property values** within each layer:
```
Horizon A (0-30 cm): Al = 10, Fe = 5
Horizon B (30-70 cm): Al = 25, Fe = 15
Horizon C (70-100 cm): Al = 15, Fe = 8
```

Mahalanobis distance detection **requires smooth variation** (non-singular covariance).
Without interpolation, constant values → singular matrix → no boundary detection.

## The Solution

Create smooth depth functions that:
1. **Maintain layer averages** (integral over horizon = field value)
2. **Transition according to distinctness class** (field observation)
3. **Connect to adjacent horizons** (realistic composition)

## Standard Distinctness Classes

| Class | Transition Distance | Soil Contact Type |
|-------|-------------------|---|
| **Very Abrupt** | < 0.5 cm | Sharp, nearly instantaneous contact |
| **Abrupt** | < 2.5 cm | Distinct boundary, narrow transition |
| **Clear** | 2.5-5 cm | Typical horizon boundary *(default)* |
| **Gradual** | 5-15 cm | Diffuse boundary, broad transition |
| **Diffuse** | > 15 cm | Very gradual, fuzzy boundary |

## How It Works: Step by Step

### 1. Define Transition Zone

For each horizon boundary at depth `d_boundary`:

```
transition_distance = 5 cm (for "clear")
transition_top = d_boundary - 2.5 cm
transition_bottom = d_boundary + 2.5 cm
```

The transition is **centered on the boundary**.

### 2. Interpolate Within Transition Zone

Simple linear interpolation from horizon above to horizon below:

```
At depth d (within transition zone):
  alpha = (d - transition_top) / transition_distance
  value = (1 - alpha) * value_above + alpha * value_below
```

**Example at 30 cm boundary (clear = 5 cm zone):**
```
Depth 27.5 cm: Al = 10.0 (horizon A)
Depth 28.0 cm: Al = 12.0 (0.4 into transition)
Depth 29.0 cm: Al = 14.0 (0.6 into transition)
Depth 30.0 cm: Al = 17.5 (1.0 into transition, at boundary)
Depth 31.0 cm: Al = 21.0 (0.6 into transition from other side)
Depth 32.5 cm: Al = 25.0 (horizon B)
```

### 3. Handle All Boundaries

Repeat for each horizon boundary, creating complete smooth profile.

### 4. Grid Output

Interpolate to regular depth intervals (0.5 or 1 cm) for analysis.

## Key Principles

### Principle 1: Average Preservation

The average value over a horizon should match the field-described value:

```
mean(interpolated[top:bottom]) ≈ field_value
```

Linear interpolation automatically satisfies this.

### Principle 2: Boundary Distinctness → Transition Width

Field observation directly maps to interpolation parameter:
- Geologist says "clear boundary" → 5 cm transition
- Geologist says "gradual boundary" → 10-15 cm transition
- Geologist says "abrupt boundary" → 2.5 cm transition

### Principle 3: Centered Transitions

Transitions are **centered on the described boundary**, not above or below:

```
Very Abrupt (0.5 cm):
    Horizon A | XXXX | Horizon B   (X = transition, 0.25 cm on each side)

Abrupt (2.5 cm):
    Horizon A | XXXXXXXXX | Horizon B   (1.25 cm on each side)

Clear (5 cm):
    Horizon A | XXXXXXXXXXXXXXXXXXX | Horizon B   (2.5 cm on each side)

Gradual (10 cm):
    Horizon A | XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX | Horizon B   (5 cm on each side)
```

## Input Data Format

```r
horizons <- data.frame(
  horizon_id = c("A", "B", "C"),
  top = c(0, 30, 70),
  bottom = c(30, 70, 100),
  distinctness = c("clear", "gradual", NA),  # Field observations
  Al = c(10, 25, 15),
  Fe = c(5, 15, 8),
  Si = c(60, 45, 65)
)
```

**Note**: `distinctness` refers to the boundary between that horizon and the one below.
- Horizon A: distinctness to boundary with B
- Horizon B: distinctness to boundary with C
- Horizon C: no distinctness specified (bottom of profile)

## Output Data Format

```r
interpolated <- data.frame(
  depth = seq(0, 100, by = 0.5),    # Regular grid
  Al = numeric(201),                 # Interpolated values
  Fe = numeric(201),
  Si = numeric(201)
)
```

## Effect of Distinctness on Mahalanobis Detection

Different distinctness classes affect boundary detection sensitivity:

### Sharp Boundary (Abrupt, 2.5 cm)
```
Mahalanobis distance:
    ▲
    │     ╱╲╱╲
    │    ╱  ╲  ╲     ← Narrow, sharp peaks
    │   ╱    ╲  ╲    ← Easy to detect
    └────────────────► depth
      29  31
```
Narrow transition zone → sharp distance peaks → easy boundary detection

### Diffuse Boundary (Gradual, 10+ cm)
```
Mahalanobis distance:
    ▲
    │      ╱╲
    │    ╱    ╲
    │   ╱      ╲     ← Broad, rounded peaks
    │  ╱        ╲    ← Harder to detect
    └────────────────► depth
     25      35
```
Wide transition zone → broad distance peaks → harder boundary detection

## Common Use Cases

### Case 1: Standard Soil Profile

```r
horizons <- data.frame(
  horizon_id = c("A", "AB", "B", "BC", "C"),
  top = c(0, 15, 30, 60, 100),
  bottom = c(15, 30, 60, 100, 150),
  distinctness = c("clear", "gradual", "clear", "gradual", NA),
  Al = c(8, 12, 20, 18, 10)
)

# Mahalanobis detection should recover boundaries ~15, 30, 60, 100
```

### Case 2: Weathering-Related Changes

```r
horizons <- data.frame(
  horizon_id = c("A", "B", "C"),
  top = c(0, 20, 50),
  bottom = c(20, 50, 100),
  distinctness = c("clear", "diffuse", NA),  # C-zone is very diffuse
  Al = c(5, 50, 20)  # Strong Al accumulation in B
)

# Clear A/B boundary (sharp Al jump)
# Gradual B/C boundary (Al decreasing slowly)
```

### Case 3: Gleyed Soil (Waterlogging)

```r
horizons <- data.frame(
  horizon_id = c("A", "B", "Bg", "Cg"),
  top = c(0, 20, 40, 80),
  bottom = c(20, 40, 80, 120),
  distinctness = c("clear", "abrupt", "gradual", NA),
  Fe = c(20, 15, 80, 70),  # Fe accumulation in B/Cg
  Al = c(10, 25, 20, 12)
)

# Sharp A/B boundary (abrupt = 2.5 cm)
# Sharp B/Bg boundary (abrupt = 2.5 cm, water table transition)
# Gradual Bg/Cg boundary (diffuse lower contact)
```

## Algorithm in Pseudocode

```python
function interpolate_by_distinctness(horizons, elements):
    # Map distinctness classes to distances
    distinctness_map = {
        "very abrupt": 0.5,
        "abrupt": 2.5,
        "clear": 5.0,
        "gradual": 10.0,
        "diffuse": 20.0
    }

    # Create output grid
    depths = seq(min(top), max(bottom), by = 0.5)
    result = empty_dataframe(length(depths), length(elements))

    # For each element
    for element in elements:
        # For each depth
        for each depth d:
            # Find which horizon contains this depth
            h = find_horizon(d, horizons)

            # Check if in transition zone
            if d in transition_zone(h):
                h_below = next_horizon(h)
                alpha = (d - transition_top) / transition_distance
                value = (1 - alpha) * horizons[h][element] +
                        alpha * horizons[h_below][element]
            else:
                value = horizons[h][element]

            result[d, element] = value

    return result
```

## Common Implementation Challenges

### Challenge 1: Overlapping Transitions

**Problem**: Two boundaries close together → transition zones overlap

**Solutions**:
- Use average distinctness in overlap zone
- Or use whichever distinctness is "more distinct" (sharper)
- Or blend smoothly between the two

### Challenge 2: Edge Boundaries

**Problem**: Top/bottom horizons have boundaries at profile edges

**Solution**:
- Constrain transition zones to within profile bounds
- Clip at top = 0 and bottom = profile_bottom
- Consider asymmetric transitions if needed

### Challenge 3: Missing Distinctness

**Problem**: Geologist didn't record boundary distinctness

**Solution**:
- Assume "clear" (5 cm, the default)
- Or mark as unknown and skip that boundary
- Or infer from element change magnitude

## Testing the Interpolation

### Test 1: Average Preservation

```r
for (each horizon):
    observed_avg = mean(interpolated[horizon_top:horizon_bottom])
    expected_avg = field_value
    error = abs(observed_avg - expected_avg)
    assert error < 0.01 * expected_avg  # Within 1%
```

### Test 2: Continuity

```r
differences = diff(interpolated_values)
assert max(abs(differences)) < max_value * 0.5  # No huge jumps
```

### Test 3: Mahalanobis Detection

```r
result = horizon_boundaries_mahalanobis(interpolated)
detected_boundaries = result$boundaries$depth
expected_boundaries = horizons$bottom[1:n-1]
assert all within 5 cm of expected
```

## Performance Expectations

- **Time**: < 100 ms for typical profile (10-20 horizons)
- **Space**: O(n_horizons × n_elements × n_depths) - reasonable
- **Accuracy**: >99% average preservation, <0.1 cm boundary error

## Next Steps

1. **Implement** the basic linear interpolation method
2. **Test** on synthetic and real soil data
3. **Integrate** with `horizon_boundaries_mahalanobis()`
4. **Validate** that Mahalanobis detection works on interpolated data
5. **Extend** with spline and mass-preservation options
