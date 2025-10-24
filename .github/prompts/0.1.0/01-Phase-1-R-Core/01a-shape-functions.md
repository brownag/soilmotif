# Subphase 1.A: Shape Functions
## Implement Seven Soil Depth Function Typologies

**Context:** The current `soilmotif` package has only one shape function: `sm_shape_sigmoid()`. Your task is to implement the remaining six functions to support all seven typologies from the book chapter. These functions form the foundation for all downstream optimization and model selection work.

**Time Estimate:** 4-5 hours  
**Code Volume:** 150-200 lines of R (mostly in `R/shape.R`)

---

## Objectives

1. **Implement six new shape functions** that match the book chapter typologies
2. **Preserve backward compatibility** with existing `sm_shape_sigmoid()`
3. **Ensure consistent API** across all seven functions
4. **Provide initial parameter suggestions** to users
5. **Add unit tests** covering all shapes with diverse inputs

---

## Background: The Seven Typologies

Reference the main roadmap document for detailed descriptions. Quick summary:

| Type | Behavior | Parameters | Pedogenic Process |
|------|----------|------------|--------------------|
| **Uniform** | Constant value at all depths | `mean` | Undeveloped/mixed soil |
| **Gradational** | Linear or smooth change with depth | `start_value`, `end_value` | Steady accumulation |
| **Exponential** | Rapid change at surface, asymptotic behavior | `C_0` (surface), `k` (decay rate) | OM, roots, surface-driven |
| **Wetting Front** | S-shaped curve; already partially implemented as sigmoid | `upper`, `lower`, `inflection_depth`, `slope` | Reaction fronts, leaching |
| **Abrupt** | Sharp step-like discontinuity at single depth | `value_above`, `value_below`, `depth` | Lithologic change |
| **Peak** | Bell-shaped; maximum at specific depth | `depth_max`, `max_value`, `width`, `skewness` | Accumulation/illuviation (Bt horizon) |
| **MiniMax** | Two peaks; minimum then maximum | `depth_min`, `value_min`, `depth_max`, `value_max`, `width_*` | Complex multi-process |

---

## API Contract for Shape Functions

All shape functions **must** follow this contract:

```r
sm_shape_<typename>(x, xlim, ascending = TRUE, ...)

# Arguments:
#   x       : numeric vector of depths (or values; context-dependent)
#   xlim    : numeric vector of parameters controlling the shape
#   ascending : logical; should output increase (TRUE) or decrease (FALSE)?
#   ...     : additional arguments (may vary per function)

# Returns:
#   numeric vector of same length as x
#   Values in range [0, 1] (pre-scaling; scaling happens in sm_motif())
#   Interpretation: 0 = low/absent, 1 = high/present
```

### Parameter Semantics for Each Type

#### 1. **Uniform**
```r
sm_shape_uniform(x, xlim, ascending = TRUE)
# xlim: numeric length 1, the constant value (will be scaled to [0, 1])
# Returns: rep(xlim[1], length(x)) normalized to [0, 1]
```

#### 2. **Gradational**
```r
sm_shape_gradational(x, xlim, ascending = TRUE, type = "linear")
# xlim: numeric length 2, c(start_value, end_value)
# type: "linear" (default) or "smooth" (optional polynomial)
# Returns: linear interpolation from xlim[1] at x[1] to xlim[2] at x[end]
# ascending: if FALSE, reverses the direction
```

#### 3. **Exponential**
```r
sm_shape_exponential(x, xlim, ascending = TRUE)
# xlim: numeric length 2, c(C0_surface_value, k_decay_rate)
# Formula: C(z) = exp(-k * z) * C0 (for ascending; reversed for descending)
# Returns: values in [0, 1] after normalization
# ascending: if FALSE, inverts the curve (less at surface, more at depth)
```

#### 4. **Wetting Front** (Sigmoidal)
```r
sm_shape_wetting_front(x, xlim, ascending = TRUE)
# xlim: numeric length 2, c(depth_inflection_start, depth_inflection_end)
# (This may parallel the current sm_shape_sigmoid logic)
# Returns: S-shaped curve, smooth transition between depths
```

#### 5. **Abrupt**
```r
sm_shape_abrupt(x, xlim, ascending = TRUE)
# xlim: numeric length 2, c(value_above, value_below) OR c(depth_discontinuity, transition_width)
# (Clarify in implementation: simple step or with smooth transition zone?)
# Returns: step function; 0 above depth, 1 below depth
# ascending: if FALSE, reverses (1 above, 0 below)
```

#### 6. **Peak**
```r
sm_shape_peak(x, xlim, ascending = TRUE)
# xlim: numeric length 3+, c(depth_of_max, width, skewness)
# Returns: bell-shaped curve centered at depth_of_max
# ascending: if FALSE, inverts to valley shape
```

#### 7. **MiniMax**
```r
sm_shape_minimax(x, xlim, ascending = TRUE)
# xlim: numeric length 6, c(depth_min, width_min, depth_max, width_max, skew_min, skew_max)
# Returns: minimum at depth_min, maximum at depth_max
# ascending: if FALSE, inverts both peaks
```

---

## Implementation Strategy

### Step 1: Review Existing `sm_shape_sigmoid()`
```r
# Current implementation in R/shape.R
sm_shape_sigmoid <- function(x, xlim, ascending = TRUE) {
  num2 <- sum(xlim) / 2
  num <- vector("numeric", length(x))
  num[x < num2] <- (2 * ((x[x < num2] - xlim[1]) / (xlim[2] - xlim[1])) ^ 2)
  num[x >= num2] <- 1 - (2 * ((x[x >= num2] - xlim[2]) / (xlim[2] - xlim[1])) ^ 2)
  num[x < xlim[1]] <- 0
  num[x > xlim[2]] <- 1
  if (!ascending)
    return(1 - num)
  num
}
```

**Understand:**
- Uses piecewise quadratic to approximate sigmoid
- `xlim` defines transition zone: `xlim[1]` to `xlim[2]`
- Returns values in [0, 1]
- `ascending = FALSE` inverts via `1 - num`

### Step 2: Create Test File (`tests/testthat/test-shape.R`)
Start with a skeleton covering all seven:

```r
# Test: shape functions return correct length and range
test_that("All shape functions return numeric [0,1] vectors", {
  x <- 1:200
  expect_equal(length(sm_shape_uniform(x, c(0.5))), 200)
  expect_true(all(sm_shape_uniform(x, c(0.5)) >= 0 & sm_shape_uniform(x, c(0.5)) <= 1))
  
  # ... repeat for gradational, exponential, wetting_front, abrupt, peak, minimax
})

# Test: ascending parameter inverts output
test_that("ascending = FALSE inverts shape", {
  x <- 1:200
  up <- sm_shape_exponential(x, c(1, 0.01), ascending = TRUE)
  down <- sm_shape_exponential(x, c(1, 0.01), ascending = FALSE)
  expect_equal(up + down, rep(1, 200), tolerance = 1e-10)
})
```

### Step 3: Implement Each Function
Write each in `R/shape.R`, with roxygen2 comments. Example template:

```r
#' Peak Shape Function
#'
#' Models an accumulation zone (Bt horizon, clay peak). Returns a bell-shaped
#' or asymmetric curve centered at `depth_of_max`.
#'
#' @param x numeric. Depth vector.
#' @param xlim numeric. Parameters: c(depth_of_max, width, [skewness]).
#'   - depth_of_max: Depth where maximum occurs
#'   - width: Controls spread of peak (SD-like)
#'   - skewness: (optional) Asymmetry; 0 = symmetric, >0 left-skewed, <0 right-skewed
#' @param ascending logical. If TRUE, peak is a maximum. If FALSE, valley.
#'
#' @return numeric vector in [0, 1] representing the shape.
#' @export
#' @examples
#' plot(sm_shape_peak(0:100, c(50, 20)), 0:100, ylim = c(100, 0))

sm_shape_peak <- function(x, xlim, ascending = TRUE) {
  # Implementation: normal distribution or Pearson-type IV
  depth_max <- xlim[1]
  width <- xlim[2]
  skew <- if (length(xlim) > 2) xlim[3] else 0
  
  # Normal distribution centered at depth_max with SD = width
  shape <- dnorm(x, mean = depth_max, sd = width)
  shape <- shape / max(shape)  # Normalize to [0, 1]
  
  if (!ascending)
    return(1 - shape)
  shape
}
```

---

## Detailed Implementation Guidance

### 1. **Uniform**
- Simplest: constant output
- `xlim[1]` is the constant value
- No depth dependence

```r
sm_shape_uniform <- function(x, xlim, ascending = TRUE) {
  rep(xlim[1], length(x))
}
```

### 2. **Gradational**
- Linear ramp from `xlim[1]` to `xlim[2]`
- Normalized to [0, 1]

```r
sm_shape_gradational <- function(x, xlim, ascending = TRUE, type = "linear") {
  if (type == "linear") {
    # Normalize x to [0, 1] range
    x_norm <- (x - min(x)) / (max(x) - min(x))
    shape <- xlim[1] + x_norm * (xlim[2] - xlim[1])
  }
  # Normalize to [0, 1]
  shape <- (shape - min(xlim)) / (max(xlim) - min(xlim))
  if (!ascending)
    shape <- 1 - shape
  shape
}
```

### 3. **Exponential**
- Exponential decay (or growth, depending on `ascending`)
- `xlim[1]` = surface value (C_0)
- `xlim[2]` = decay rate (k)

```r
sm_shape_exponential <- function(x, xlim, ascending = TRUE) {
  C0 <- xlim[1]
  k <- xlim[2]
  # Exponential decay: C(z) = C0 * exp(-k*z)
  shape <- C0 * exp(-k * x)
  # Normalize to [0, 1]
  shape <- (shape - min(shape)) / (max(shape) - min(shape))
  if (!ascending)
    shape <- 1 - shape
  shape
}
```

### 4. **Wetting Front**
- Keep close to existing sigmoid logic
- May refactor sigmoid into this function and have sigmoid call it

```r
sm_shape_wetting_front <- function(x, xlim, ascending = TRUE) {
  # Could reuse existing sigmoid logic
  sm_shape_sigmoid(x, xlim, ascending)
}
```

### 5. **Abrupt**
- Step function with optional smooth zone
- `xlim[1]` = discontinuity depth, `xlim[2]` = zone width (optional)

```r
sm_shape_abrupt <- function(x, xlim, ascending = TRUE) {
  depth_disc <- xlim[1]
  transition_width <- if (length(xlim) > 1) xlim[2] else 1
  
  # Hard step or soft transition?
  if (transition_width == 0) {
    shape <- as.numeric(x >= depth_disc)
  } else {
    # Smooth step using logistic function
    shape <- plogis(x, location = depth_disc, scale = transition_width)
  }
  
  if (!ascending)
    shape <- 1 - shape
  shape
}
```

### 6. **Peak**
- Normal distribution or Pearson-type IV
- `xlim[1]` = depth_max, `xlim[2]` = width, `xlim[3]` = skewness (optional)

```r
sm_shape_peak <- function(x, xlim, ascending = TRUE) {
  depth_max <- xlim[1]
  width <- xlim[2]
  skew <- if (length(xlim) > 2) xlim[3] else 0
  
  # For now, use normal distribution
  shape <- dnorm(x, mean = depth_max, sd = width)
  shape <- shape / max(shape)
  
  # TODO: Add Pearson-type IV for asymmetry
  
  if (!ascending)
    shape <- 1 - shape
  shape
}
```

### 7. **MiniMax**
- Two peaks: minimum at `xlim[1]`, maximum at `xlim[3]`
- Combination of two peak/valley functions

```r
sm_shape_minimax <- function(x, xlim, ascending = TRUE) {
  depth_min <- xlim[1]
  width_min <- xlim[2]
  depth_max <- xlim[3]
  width_max <- xlim[4]
  
  # Create minimum (valley) and maximum (peak)
  valley <- 1 - dnorm(x, mean = depth_min, sd = width_min)
  valley <- valley / max(valley)
  
  peak <- dnorm(x, mean = depth_max, sd = width_max)
  peak <- peak / max(peak)
  
  # Combine: use valley and peak proportionally
  shape <- (valley + peak) / 2
  shape <- shape / max(shape)
  
  if (!ascending)
    shape <- 1 - shape
  shape
}
```

---

## Acceptance Criteria

### Code Quality
- [x] All seven functions implemented in `R/shape.R`
- [x] Roxygen2 comments on every exported function
- [x] Consistent parameter naming and semantics across functions
- [x] No duplication of logic (refactor common patterns)
- [x] Edge cases handled (empty input, NA values, single element)

### Testing
- [x] New tests added to `tests/testthat/test-shape.R`
- [x] Tests for length, range [0,1], ascending/descending behavior
- [x] Tests for parameter interpretation (depth semantics)
- [x] Tests for edge cases
- [x] `devtools::test()` passes all tests

### Backward Compatibility
- [x] Existing `sm_shape_sigmoid()` behavior unchanged
- [x] Existing `sm_motif()` and `sm_optim()` still work with sigmoid
- [x] README examples produce identical output

### Documentation
- [x] Roxygen2 comments include @param, @return, @examples for each
- [x] `devtools::document()` runs without errors
- [x] Help files (`?sm_shape_*`) render correctly

---

## Testing Checklist

Run these before handing off:

```bash
# In R console:
devtools::test()  # Should pass all tests
devtools::document()  # Should regenerate docs without errors
# Then in shell:
R CMD check --as-cran --no-build-vignettes .
```

---

## Example Integration (Manual Verification)

```r
library(soilmotif)

# Use each shape with sm_motif
x <- runif(200, min = 20, max = 50)  # Synthetic data

uniform_fit <- sm_motif(x, c(35), FUN = sm_shape_uniform)
gradational_fit <- sm_motif(x, c(25, 45), FUN = sm_shape_gradational)
exponential_fit <- sm_motif(x, c(1, 0.01), FUN = sm_shape_exponential)
peak_fit <- sm_motif(x, c(100, 30), FUN = sm_shape_peak)

# All should return numeric vectors of length 200
stopifnot(length(uniform_fit) == 200)
stopifnot(all(uniform_fit >= 0 & uniform_fit <= max(x)))
```

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Function returns wrong length | Check `vector("numeric", length(x))` vs `rep()` |
| Values outside [0, 1] | Normalize: `(shape - min(shape)) / (max(shape) - min(shape))` |
| `ascending = FALSE` doesn't invert | Use `1 - shape` or `max(shape) - shape + min(shape)` |
| Parameter semantics unclear | Cross-check with book chapter; add comments |
| Tests fail on NAs | Use `na.omit()` or document NA handling |

---

## Resources

- **Book Chapter Sections:** 14.2.3-14.2.6 (Typologies with equations and figures)
- **Current Code:** `R/shape.R` (existing sigmoid for reference)
- **Test File:** `tests/testthat/test-shape.R` (scaffold from Phase 1 overview)
- **Examples:** `README.md` (clay spline example)

---

## Deliverable Checklist

Before signaling completion:

- [ ] All 7 shape functions implemented in `R/shape.R`
- [ ] Unit tests expanded in `tests/testthat/test-shape.R`
- [ ] Roxygen2 documentation comments added
- [ ] `devtools::document()` runs successfully
- [ ] `devtools::test()` passes all tests
- [ ] `R CMD check --as-cran --no-build-vignettes .` passes
- [ ] README examples still work identically
- [ ] Git commit: `Phase 1.A: Implement seven shape functions`
- [ ] Update `PHASE_STATUS.md` with completion timestamp

---

**Next Step:** Agent 2 will verify these implementations and proceed to Subphase 1.B (Optimization Framework).
