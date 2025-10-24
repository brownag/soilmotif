# Subphase 1.D: Data Preprocessing Helpers
## Convert Horizon/Sensor Data to Continuous Profiles

**Context:** Users typically have soil data in one of three formats: (1) discrete horizons with depths and properties, (2) spline-interpolated continuous data, or (3) sensor time-series. Your task is to create a unified preprocessing layer that handles all three and outputs the continuous vectors soilmotif expects.

**Time Estimate:** 3-4 hours  
**Code Volume:** 100-150 lines in new `R/preprocess.R`

---

## Objectives

1. Implement `sm_prepare()` generic function for data preprocessing
2. Support step-function, spline, and linear interpolation methods
3. Handle `SoilProfileCollection` (aqp) and data.frame inputs
4. Create specialized helpers: `sm_prepare_step()`, `sm_prepare_spline()`, etc.
5. Gracefully handle missing data, irregular depths, and edge cases

---

## Core Function: `sm_prepare()`

### Signature

```r
sm_prepare <- function(data, 
                       property = NULL,
                       method = "step",
                       depth_range = c(0, 200),
                       resolution = 1,
                       ...) {
  # data: data.frame, SoilProfileCollection, or character path to CSV
  # property: name of property column(s) to extract
  # method: "step", "spline", "linear"
  # depth_range: c(min, max) depth in cm or any unit
  # resolution: depth interval (e.g., 1 = 1 cm)
  
  # Returns: named list of continuous numeric vectors
  #   names = profile IDs or column names
  #   each element = vector of length (max - min) / resolution
}
```

### Implementation Outline

```r
sm_prepare <- function(data, 
                       property = NULL,
                       method = "step",
                       depth_range = c(0, 200),
                       resolution = 1,
                       ...) {
  
  # Validate
  if (!(method %in% c("step", "spline", "linear"))) {
    stop("method must be 'step', 'spline', or 'linear'")
  }
  
  # Dispatch based on input class
  if (is.character(data)) {
    # Read CSV
    data <- read.csv(data)
  }
  
  if (inherits(data, "SoilProfileCollection")) {
    result <- switch(method,
      "step" = .sm_prepare_spc_step(data, property, depth_range, resolution, ...),
      "spline" = .sm_prepare_spc_spline(data, property, depth_range, resolution, ...),
      "linear" = .sm_prepare_spc_linear(data, property, depth_range, resolution, ...)
    )
  } else if (is.data.frame(data)) {
    result <- switch(method,
      "step" = .sm_prepare_df_step(data, property, depth_range, resolution, ...),
      "spline" = .sm_prepare_df_spline(data, property, depth_range, resolution, ...),
      "linear" = .sm_prepare_df_linear(data, property, depth_range, resolution, ...)
    )
  } else {
    stop("data must be data.frame, SoilProfileCollection, or path to CSV")
  }
  
  result
}
```

---

## Method-Specific Implementations

### 1. Step Function Method

Simplest: repeat each horizon's value for the number of depth units it spans.

```r
.sm_prepare_df_step <- function(data, property, depth_range, resolution, ...) {
  # data: data.frame with columns: id, top, bottom, [property]
  
  stopifnot(all(c("id", "top", "bottom") %in% names(data)))
  if (is.null(property)) {
    # Use numeric columns
    property <- names(data)[sapply(data, is.numeric)]
    property <- setdiff(property, c("top", "bottom"))
  }
  
  result <- list()
  
  for (prop in property) {
    profiles <- unique(data$id)
    prof_list <- list()
    
    for (prof_id in profiles) {
      prof_data <- data[data$id == prof_id, ]
      
      # Create continuous vector
      depths <- seq(depth_range[1], depth_range[2], by = resolution)
      continuous <- numeric(length(depths))
      
      for (i in seq_len(nrow(prof_data))) {
        top <- prof_data$top[i]
        bottom <- prof_data$bottom[i]
        value <- prof_data[[prop]][i]
        
        idx_start <- max(1, which.min(abs(depths - top)))
        idx_end <- min(length(depths), which.min(abs(depths - bottom)))
        
        continuous[idx_start:idx_end] <- value
      }
      
      prof_list[[as.character(prof_id)]] <- continuous
    }
    
    result[[prop]] <- prof_list
  }
  
  result
}

.sm_prepare_spc_step <- function(data, property, depth_range, resolution, ...) {
  # data: SoilProfileCollection (aqp)
  
  # Extract as data.frame
  df <- as.data.frame(data)
  
  # Ensure required columns
  if (!("hzID" %in% names(df))) df$hzID <- seq_len(nrow(df))
  if (!("id" %in% names(df))) df$id <- df[[idname(data)]]
  if (!("top" %in% names(df))) df$top <- df[[horizonDepths(data)]][, 1]
  if (!("bottom" %in% names(df))) df$bottom <- df[[horizonDepths(data)]][, 2]
  
  # Call data.frame method
  .sm_prepare_df_step(df, property, depth_range, resolution, ...)
}
```

### 2. Spline Method

Use `mpspline2` if available; fall back to linear.

```r
.sm_prepare_df_spline <- function(data, property, depth_range, resolution, ...) {
  # Requires mpspline2 package
  
  if (!requireNamespace("mpspline2", quietly = TRUE)) {
    warning("mpspline2 not found; using linear interpolation instead")
    return(.sm_prepare_df_linear(data, property, depth_range, resolution, ...))
  }
  
  # Use mpspline2::fit_mass_preserving_spline()
  # Returns interpolated values at regular depths
  
  # Implementation depends on mpspline2 API; adapt as needed
  # This is a stub showing the approach:
  
  result <- list()
  
  for (prop in property) {
    profiles <- unique(data$id)
    prof_list <- list()
    
    for (prof_id in profiles) {
      prof_data <- data[data$id == prof_id, c("top", "bottom", prop)]
      
      # Call mpspline2 function
      spline_fit <- mpspline2::fit_spline(
        d = prof_data,
        var = prop,
        lam = 0.1
      )
      
      # Extract at regular resolution
      depths_interp <- seq(depth_range[1], depth_range[2], by = resolution)
      continuous <- stats::approx(
        spline_fit$depth,
        spline_fit$value,
        xout = depths_interp
      )$y
      
      prof_list[[as.character(prof_id)]] <- continuous
    }
    
    result[[prop]] <- prof_list
  }
  
  result
}
```

### 3. Linear Interpolation Method

Simple linear interpolation between known depths.

```r
.sm_prepare_df_linear <- function(data, property, depth_range, resolution, ...) {
  
  result <- list()
  
  for (prop in property) {
    profiles <- unique(data$id)
    prof_list <- list()
    
    for (prof_id in profiles) {
      prof_data <- data[data$id == prof_id, ]
      
      # Use midpoint of horizon for interpolation
      prof_data$mid <- (prof_data$top + prof_data$bottom) / 2
      
      # Sort by depth
      prof_data <- prof_data[order(prof_data$mid), ]
      
      # Interpolate
      depths_interp <- seq(depth_range[1], depth_range[2], by = resolution)
      continuous <- stats::approx(
        prof_data$mid,
        prof_data[[prop]],
        xout = depths_interp,
        rule = 2  # Extend with boundary values
      )$y
      
      prof_list[[as.character(prof_id)]] <- continuous
    }
    
    result[[prop]] <- prof_list
  }
  
  result
}
```

---

## Integration with aqp

If the user passes a `SoilProfileCollection`, use aqp functions to extract metadata:

```r
# Helper to convert SoilProfileCollection to data.frame
.spc_to_df <- function(spc) {
  df <- as.data.frame(spc)
  names(df)[1] <- "id"  # Ensure id column
  
  # Get horizon depth columns
  hd <- horizonDepths(spc)
  names(df)[match(hd, names(df))] <- c("top", "bottom")
  
  df
}
```

---

## Usage Examples

```r
# Example 1: Step function with data.frame
data <- data.frame(
  id = c("P1", "P1", "P1", "P2", "P2"),
  top = c(0, 18, 43, 0, 30),
  bottom = c(18, 43, 79, 30, 100),
  clay = c(7, 6, 39, 10, 35)
)

result <- sm_prepare(data, property = "clay", method = "step")
# Returns: list(clay = list(P1 = [...], P2 = [...]))

# Example 2: With SoilProfileCollection
library(aqp)
data(jacobs2000)
result <- sm_prepare(jacobs2000, property = "clay", method = "spline")

# Example 3: From CSV file
result <- sm_prepare("soil_data.csv", property = "clay", method = "linear")
```

---

## Acceptance Criteria

### Functionality
- [x] `sm_prepare()` handles data.frame input with step method
- [x] `sm_prepare()` handles data.frame input with linear method
- [x] `sm_prepare()` handles data.frame input with spline method (or graceful fallback)
- [x] `sm_prepare()` handles SoilProfileCollection input (aqp)
- [x] `sm_prepare()` handles CSV file input
- [x] Gracefully handles missing values and irregular depths
- [x] Returns named list of continuous vectors

### Testing
- [x] Unit tests for each method with diverse input
- [x] Integration test: output works with `sm_motif()`
- [x] Edge cases: single horizon, many horizons, gaps in data
- [x] `devtools::test()` passes all tests

### Optional Dependency Management
- [x] `aqp` and `mpspline2` guarded by `requireNamespace()`
- [x] Graceful fallback (linear) if spline package unavailable
- [x] Tests run without optional dependencies

### Documentation
- [x] Roxygen2 comments on main and helper functions
- [x] Examples: step, linear, spline, SoilProfileCollection
- [x] Handling of common input formats documented

---

## Test Examples

```r
test_that("sm_prepare step method works", {
  data <- data.frame(
    id = "P1",
    top = c(0, 20, 50),
    bottom = c(20, 50, 100),
    clay = c(10, 30, 25)
  )
  
  result <- sm_prepare(data, property = "clay", method = "step")
  
  expect_type(result, "list")
  expect_named(result, "clay")
  expect_equal(length(result$clay$P1), 200)
  expect_equal(result$clay$P1[1:20], rep(10, 20))
})

test_that("sm_prepare with aqp SoilProfileCollection", {
  skip_if_not_installed("aqp")
  library(aqp)
  data(jacobs2000)
  
  result <- sm_prepare(jacobs2000, property = "clay", method = "step")
  
  expect_type(result, "list")
  expect_named(result, "clay")
  expect_true(all(sapply(result$clay, length) == 200))
})

test_that("sm_prepare output integrates with sm_motif", {
  data <- data.frame(
    id = "P1",
    top = c(0, 50, 100),
    bottom = c(50, 100, 200),
    clay = c(10, 30, 20)
  )
  
  prep <- sm_prepare(data, property = "clay", method = "step")
  x <- prep$clay$P1
  
  fit <- sm_motif(x, c(50, 100), FUN = sm_shape_peak)
  expect_equal(length(fit), 200)
})
```

---

## Implementation Checklist

- [ ] Create `R/preprocess.R` with `sm_prepare()` and helper functions
- [ ] Implement step method for data.frame and SoilProfileCollection
- [ ] Implement linear interpolation method
- [ ] Implement spline method (with graceful fallback)
- [ ] Add `requireNamespace()` guards for aqp and mpspline2
- [ ] Write comprehensive unit tests in `tests/testthat/test-preprocess.R`
- [ ] Test with diverse input formats (README example data)
- [ ] Verify integration with `sm_motif()`
- [ ] Verify `devtools::test()` passes
- [ ] Verify `R CMD check` passes (without optional dependencies)
- [ ] Commit: `Phase 1.D: Add data preprocessing helpers`
- [ ] Update `PHASE_STATUS.md`

---

## Integration Notes

- Independent of 1.A, 1.B, 1.C (can run in parallel)
- Used by: 1.E (documentation examples), Phase 2+ (data pipelines)
- Enables: Simplified user workflows in README and vignettes

---

**Next Step:** 1.E (Testing & Documentation) synthesizes all four subphases
