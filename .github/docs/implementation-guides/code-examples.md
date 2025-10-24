# Parameter Naming Conventions - Code Examples

## 1. INPUT DATA PARAMETER NAMING

### Pattern A: Shape Functions Use `x` for DEPTHS (Confusing!)

**File: R/shape.R - Lines 51-61**
```r
sm_shape_sigmoid <- function(x, params, ascending = TRUE) {
  # HERE: x is DEPTHS (e.g., 1:200 cm)
  # params is shape parameters
  num2 <- sum(params) / 2
  num <- vector("numeric", length(x))  # Creating vector same length as depths
  num[x < num2] <- (2 * ((x[x < num2] - params[1]) / (params[2] - params[1])) ^ 2)
  # ... rest of function
}

# Usage:
depths <- 1:200
clay_profile <- sm_shape_sigmoid(depths, c(40, 60))  # x param is depths!
```

### Pattern B: Optimization Functions Use `x` for VALUES (Also Confusing!)

**File: R/fit.R - Lines 73-82**
```r
sm_motif <- function(x, X,
                     FUN = sm_shape_sigmoid,
                     ..., ylim = .DEFAULT_DEPTH_RANGE,
                     as_function = FALSE) {
  # HERE: x is OBSERVED VALUES (clay %, soil properties)
  # X is PARAMETERS (shape parameters)
  .fun <- \(Y) .scaleprop(FUN(Y, X, ...), c(min(x), max(x)))
  # ... rest of function
}

# Usage:
clay_data <- c(10, 12, 15, 20, 25, 28, 30, 31, 32, 32, 31, 30, ...)
fitted <- sm_motim(clay_data, c(40, 60))  # x is observations!
```

### Pattern C: Bootstrap Functions Use `observed` (Clear!)

**File: R/uncertainty.R - Lines 99-114**
```r
sm_optim_bootstrap <- function(
  observed,      # ← CLEAR: This is the observed data
  depths,        # ← CLEAR: This is the depth vector
  initial_params,# ← CLEAR: These are starting parameters
  shape_family = "sigmoid",
  objective = "rmse",
  optimizer = "auto",
  n_bootstrap = 1000L,
  # ...
) {
  # Usage makes semantic sense
  if (length(observed) != length(depths)) {
    stop("observed and depths must have the same length")
  }
  # ...
}

# Usage:
clay_obs <- c(10, 12, 15, 20, 25, ..., 31)
depths_vec <- seq(1, 200, by = 1)
boot <- sm_optim_bootstrap(
  observed = clay_obs,
  depths = depths_vec,
  initial_params = c(40, 60)
)
```

### Pattern D: Preprocessing Uses `data` (Good for data.frames)

**File: R/preprocess.R - Lines 40-45**
```r
sm_prepare <- function(data,              # ← data.frame or SoilProfileCollection
                       property = NULL,
                       method = "step",
                       depth_range = c(1, 200),
                       resolution = 1,
                       ...) {
  
  # Check that data is the right type
  if (inherits(data, "SoilProfileCollection")) {
    # ...
  } else if (is.data.frame(data)) {
    # ...
  }
  # ...
}

# Usage:
soil_profile_df <- data.frame(
  id = c("P1", "P1", "P1"),
  top = c(0, 20, 50),
  bottom = c(20, 50, 100),
  clay = c(10, 30, 25)
)
result <- sm_prepare(soil_profile_df, property = "clay", method = "step")
```

---

## 2. MODEL PARAMETER NAMING

### Pattern A: Core Functions Use Capital `X` (Non-idiomatic, confusing)

**File: R/fit.R - Lines 218-226**
```r
sm_optim <- function(x, X, ...,        # ← Capital X (unusual in R!)
                     FUN = sm_shape_sigmoid,
                     OPTFUN = sm_optim_rmse) {
  method <- if (length(X) == 1) "Brent" else "Nelder-Mead"
  lower <- if (length(X) == 1) 0 else -Inf
  upper <- if (length(X) == 1) 1 else Inf

  fit <- suppressWarnings(stats::optim(X, function(Y) OPTFUN(sm_motif(x, Y, FUN = FUN, ...), x),
                      method = method, lower = lower, upper = upper))
  
  # ...
}

# Usage - confusing!
sm_optim(clay_data, c(40, 60), FUN = sm_shape_sigmoid)
#         ^data    ^params (capital!)
```

### Pattern B: Bootstrap Uses `initial_params` (Semantic!)

**File: R/uncertainty.R - Lines 99-114**
```r
sm_optim_bootstrap <- function(
  observed,
  depths,
  initial_params,      # ← Semantic: these are starting parameters!
  shape_family = "sigmoid",
  # ...
) {
  # ...
  config <- list(
    shape_type = shape_family,
    # ...
    n_bootstrap = as.integer(n_bootstrap),
    seed = if (is.null(seed)) -1L else as.integer(seed),
    # ...
  )
  # ...
}
```

### Pattern C: Documentation Uses `params` (Generic but clear)

**File: R/fit.R - Lines 34-55 (Documentation)**
```r
#' Fit a Soil Property Shape Function
#'
#' @param x A continuous vector representing a soil property
#' @param X Parameters for the shape function `FUN`
#' @param FUN Shape function. Defaults to `sm_shape_sigmoid()`
#' @param ylim numeric. Length 2 vector representing `Y` (depth) limits.
#' @param OPTFUN Objective function. Defaults to `sm_optim_rmse()`.
#' @param as_function Return function that takes `Y` (depth) vector as input?
#'
#' @section Parameter Semantics by Motif Type:
#' - **Uniform:** Single constant value
#' - **Gradational:** c(start_value, end_value); order matters
#' - **Exponential:** c(surface_value, decay_rate); order matters
```

---

## 3. DEPTH VECTOR NAMING

### Pattern A: Shape Functions - Implicit Depths (Assumes uniform 1-cm spacing)

**File: R/shape.R - Lines 51-61**
```r
sm_shape_sigmoid <- function(x, params, ascending = TRUE) {
  # x is treated as if it's a depth vector (0, 1, 2, ..., 200)
  # The function doesn't care about actual depth values
  # It assumes x represents evenly spaced depths
  
  num2 <- sum(params) / 2
  num <- vector("numeric", length(x))
  num[x < num2] <- ...  # Treats x as numeric values (depths)
  num[x >= num2] <- ...
  # ...
}

# Real-world usage - user must understand x is depths:
depths <- 1:200
clay_trend <- sm_shape_sigmoid(depths, c(40, 60))

# PROBLEM: User could do this without error:
fake_clay <- c(5, 10, 15, 20, 25, 30, 35, 40, ...)
weird <- sm_shape_sigmoid(fake_clay, c(40, 60))  # Wrong interpretation!
```

### Pattern B: Explicit Depths in Bootstrap (Clear separation)

**File: R/uncertainty.R - Lines 99-114**
```r
sm_optim_bootstrap <- function(
  observed,        # ← Observations (clay %, etc.)
  depths,          # ← Explicit depths (can be irregular!)
  initial_params,
  # ...
) {
  # Input validation
  if (length(observed) != length(depths)) {
    stop("observed and depths must have the same length")
  }
  if (length(observed) < 3) {
    stop("Need at least 3 observations for bootstrap")
  }

  # Store original depths before any processing
  original_depths <- depths  # ← Preserved for later use
  
  # ...
  
  # Call Rust bootstrap engine
  tryCatch({
    result <- bootstrap_engine_rust(
      as.numeric(observed),
      as.numeric(depths),    # ← Explicit depth vector
      as.numeric(initial_params),
      config
    )
  })
}

# Usage - very clear:
clay_obs <- c(10, 12, 15, 20, 25, 28, 30, 31, 32, 32, 31, 30)
depths_cm <- seq(1, length(clay_obs))  # OR irregular: c(0, 5, 10, 20, 50, ...)
boot <- sm_optim_bootstrap(
  observed = clay_obs,
  depths = depths_cm
)
```

### Pattern C: Column-based Depths in Data.frames

**File: R/preprocess.R - Lines 109-196**
```r
.sm_prepare_df_step <- function(data, property, depth_range, resolution, ...) {
  # Validate required columns
  required_cols <- c("id", "top", "bottom")  # ← Depth info as columns
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Create output depths
  depths <- seq(depth_range[1], depth_range[2], by = resolution)  # ← Constructed depths

  # ...
  
  for (i in seq_len(nrow(prof_data))) {
    top <- prof_data$top[i]      # ← Extract top depth from data
    bottom <- prof_data$bottom[i] # ← Extract bottom depth from data
    value <- prof_data[[prop]][i]

    # Find indices in output depths
    idx_start <- findInterval(top, depths)
    idx_end <- findInterval(bottom, depths)
  }
}

# Usage with data.frame:
soil_data <- data.frame(
  id = c("P1", "P1", "P1"),
  top = c(0, 20, 50),      # ← Depth info
  bottom = c(20, 50, 100), # ← Depth info
  clay = c(10, 30, 25)
)
result <- sm_prepare(soil_data, property = "clay", method = "step")
```

### Pattern D: Horizon Detection - Multiple Depth Uses

**File: R/horizons.R - Lines 458-465**
```r
horizon_boundaries_mahalanobis <- function(data,
                                            depth_col = "depth",      # ← Column name
                                            element_cols = NULL,
                                            window_size = 10,         # ← Depth units
                                            threshold = .MAHALANOBIS_DEFAULT_THRESHOLD,
                                            method = "local_maxima",
                                            min_horizon_depth = 5,    # ← Minimum depth thickness
                                            window_type = "centered") {

  # ...
  
  # Sort by depth
  data <- data[order(data[[depth_col]]), ]
  depths <- data[[depth_col]]        # ← Extract depth vector
  element_matrix <- as.matrix(data[, element_cols, drop = FALSE])

  # Create moving windows
  windows <- .create_depth_windows(depths, element_matrix,
                                     window_size, window_type)
  # ...
}

# Usage:
pxrf_data <- data.frame(
  depth = 0:100,
  Al = c(...),
  Fe = c(...)
)
boundaries <- horizon_boundaries_mahalanobis(
  pxrf_data,
  depth_col = "depth",      # ← Specify which column is depth
  element_cols = c("Al", "Fe"),
  window_size = 15
)
```

---

## 4. OBJECTIVE FUNCTION SEMANTICS

### Pattern A: Ambiguous Names

**File: R/fit.R - Lines 10-32**
```r
#' @param x numeric. Vector of "observed" values.
#' @param y numeric. Vector of "predicted" values.
#'
#' @return numeric
#' @rdname sm-objective
#' @export
#'
#' @examples
#' sm_optim_rmse(1:10, runif(10))
sm_optim_rmse <- function(x, y, ...) {
  sqrt(mean((y - x) ^ 2, ...))  # ← Documentation says x=observed
}

# BUT USAGE MIGHT BE:
sm_optim_rmse(observed, predicted)  # Clear
# OR:
sm_optim_rmse(predicted, observed)  # Unclear!
```

### Pattern B: Clear Naming

**File: R/fit.R - Lines 108-199**
```r
create_soil_objective <- function(type, ...) {
  # ...
  switch(type,
    "weighted_rmse" = {
      # ...
      function(predicted, observed) {  # ← CLEAR parameter names!
        depths <- seq_along(observed)
        # Gaussian weighting centered on target_depth
        weights <- exp(-weight_factor * (depths - target_depth)^2)
        residuals <- observed - predicted    # ← Semantic calculation
        sqrt(sum(weights * residuals^2) / sum(weights))
      }
    },
    "ordinal" = {
      # ...
      function(predicted, observed) {  # ← CLEAR parameter names!
        residuals <- observed - predicted
        total_cost <- 0
        # ...
      }
    }
  )
}

# Usage is very clear:
clay_objective <- create_soil_objective("weighted_rmse", target_depth = 100, weight_factor = 2.0)
# The returned function expects: clay_objective(predicted, observed)
```

---

## 5. PROBLEMATIC CROSS-MODULE USAGE

### The Confusion Point

```r
# In shape.R (x = depths):
clay_trend <- sm_shape_sigmoid(1:200, c(40, 60))
#                               ^x param is DEPTHS

# In fit.R (x = observed values):
fitted <- sm_optim(clay_data, c(40, 60), FUN = sm_shape_sigmoid)
#               ^x param is VALUES

# These look similar but mean completely different things!
```

### Real-world scenario causing confusion:

```r
# User might write confusing code:
depths_vector <- 1:200
clay_obs <- c(10, 12, 15, 20, 25, ...)

# Correct (but not obvious):
result1 <- sm_optim(clay_obs, c(40, 60), FUN = sm_shape_sigmoid)

# Incorrect (but syntactically identical):
result2 <- sm_optim(depths_vector, c(40, 60), FUN = sm_shape_sigmoid)

# Both work because both are numeric vectors!
# But result2 is meaningless (optimizing against depths, not observations)
```

---

## 6. RECOMMENDED PATTERNS

### Pattern A: Clear Data Input

```r
# GOOD - data type explicit:
sm_prepare(data = soil_df, property = "clay", method = "step")
weathering_indices(data = pxrf_df, depth_col = "depth")

# GOOD - vector input explicit:
sm_optim(observed = clay_values, params = c(40, 60))
sm_optim_bootstrap(observed = clay_values, depths = depth_vector, initial_params = c(40, 60))
```

### Pattern B: Clear Shape Functions

```r
# RECOMMENDED - parameter semantic:
clay_trend <- sm_shape_sigmoid(depth = 1:200, params = c(40, 60), ascending = TRUE)
clay_trend <- sm_shape_peak(depth = 1:200, params = c(70, 25), ascending = TRUE)

# CURRENTLY (confusing):
clay_trend <- sm_shape_sigmoid(1:200, c(40, 60), TRUE)
clay_trend <- sm_shape_peak(1:200, c(70, 25), TRUE)
```

### Pattern C: Clear Optimization

```r
# RECOMMENDED:
fitted <- sm_optim(
  observed = clay_obs,
  params = c(40, 60),
  FUN = sm_shape_sigmoid
)

# OR with explicit depths:
fitted <- sm_optim(
  observed = clay_obs,
  params = c(40, 60),
  depths = 1:length(clay_obs),
  FUN = sm_shape_sigmoid
)

# CURRENTLY (capital X confusing):
fitted <- sm_optim(clay_obs, c(40, 60), FUN = sm_shape_sigmoid)
```

---

## 7. WELL-NAMED FUNCTION EXAMPLES TO FOLLOW

### Excellent: Element-specific Functions

```r
# File: R/weathering.R
calculate_CIA <- function(Al2O3, K2O, Na2O) {
  # Clear element references
  denominator <- Al2O3 + K2O + Na2O
  cia <- ifelse(denominator > 0,
    (Al2O3 / denominator) * 100,
    NA_real_
  )
  # ...
}

calculate_SAR <- function(SiO2, Al2O3) {
  # Clear element references
  sar <- SiO2 / Al2O3
  sar[Al2O3 == 0] <- NA_real_
  sar
}
```

### Excellent: Horizon Classification Functions

```r
# File: R/horizons.R
horizon_boundaries_mahalanobis <- function(
  data,              # ← Input type clear
  depth_col = "depth",  # ← Depth column name
  element_cols = NULL,   # ← Element columns
  window_size = 10,      # ← Window size in depths
  threshold = .MAHALANOBIS_DEFAULT_THRESHOLD,
  method = "local_maxima",
  min_horizon_depth = 5,
  window_type = "centered"
) {
  # All parameters are semantically clear!
}

horizon_classify_fuzzy <- function(
  data,              # ← Input type clear
  depth_col = "depth",  # ← Depth column name
  element_cols = NULL,   # ← Element columns
  n_horizons = 5,
  m = .FUZZY_DEFAULT_EXPONENT,
  # ...
) {
  # All parameters are semantically clear!
}
```

### Excellent: Bootstrap Function

```r
# File: R/uncertainty.R
sm_optim_bootstrap <- function(
  observed,             # ← Observations (values to analyze)
  depths,               # ← Explicit depths
  initial_params,       # ← Starting parameters
  shape_family = "sigmoid",
  objective = "rmse",
  optimizer = "auto",
  n_bootstrap = 1000L,
  method = c("auto", "parametric", "sieve"),
  sieve_threshold = 20L,
  seed = NULL,
  fallback_strategy = c("auto", "explicit", "strict"),
  strict = FALSE,
  max_retries = 3L,
  parallel = TRUE
) {
  # All parameters are semantically clear!
}
```

