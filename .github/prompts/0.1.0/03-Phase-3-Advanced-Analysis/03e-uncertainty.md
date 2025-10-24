### **`# 03e: Uncertainty Quantification (Final Technical Prompt)`**

## Objective
Implement a high-performance, adaptive uncertainty quantification engine in Rust, exposed to R. The framework will leverage the existing `argmin`-based optimization suite and support the full range of objective functions. It will adapt its statistical methodology based on data resolution, using a **Parametric Bootstrap** for sparse data and a **Sieve Bootstrap** for high-resolution data.

## Core Architecture
The R functions will serve as a user-friendly API that orchestrates calls to a powerful Rust backend. The entire bootstrap process—including the initial optimization, resampling, and parallel re-optimization—will be executed in Rust via `rayon` for maximum performance.

-   **R Layer**: `sm_optim_bootstrap()` function for the user, input validation, `auto` method logic, and formatting of the final result object.
-   **Rust Layer**: `bootstrap_engine_rust()` function containing all core numeric computations.

### Supported Methods & Dispatcher Pattern

The R wrapper accepts user choices for optimization algorithms, objective functions, and shape functions as parameters. These are passed to the Rust engine as strings and dispatched to existing implementations.

**Optimizers** (parameter: `optimizer` in `sm_optim_bootstrap`):
- Supported values: "nelder_mead", "lbfgs", "pso", "simulated_annealing", "newton_cg"
- Routing: Dispatch in Rust via `match optimizer_type { ... }` to `src/optimizer.rs`
- Invalid input: Rust returns error; R wraps with helpful message

**Objective Functions** (parameter: `OPTFUN` in `sm_optim_bootstrap`):
- Supported values: "rmse", "sse", "mae", "r2"
- Routing: Dispatch in Rust via `match objective_type { ... }` to `src/objective.rs`
- Invalid input: Rust returns error; R wraps with helpful message

**Shape Functions** (parameter: `FUN` in `sm_optim_bootstrap`):
- Supported values: All shapes in `src/shape_functions.rs` and R/shape.R (e.g., "sigmoid", "exponential", "spline_monotone", "spline_restricted_cubic", etc.)
- Routing: Dispatch in Rust via `match shape_type { ... }` to `src/shape_functions.rs`
- Invalid input: Rust returns error; R wraps with helpful message

**R Wrapper Validation**:
- Before calling Rust, `sm_optim_bootstrap` validates that optimizer, objective, and shape choices are recognized.
- Early validation prevents unnecessary Rust calls and improves error messages.

### Reproducibility & Seed Handling

To ensure reproducible bootstrap results across runs:

**R Layer**:
- If `seed` parameter is provided to `sm_optim_bootstrap`, set R's RNG via `set.seed(seed)`
- This ensures reproducible resampling of residuals/innovations in Rust

**Rust Layer**:
- Parallel rayon loop uses Rust's default PRNG
- For Phase 1: Reproducibility is R-side only (residual resampling becomes deterministic via R seed)

**User Example**:
```r
# Reproducible run
result1 <- sm_optim_bootstrap(observed, initial_params, seed = 42, n_bootstrap = 1000)
result2 <- sm_optim_bootstrap(observed, initial_params, seed = 42, n_bootstrap = 1000)
# result1 and result2 will be identical
```

## Deliverables

### D1: Adaptive Bootstrap Engine (Rust Core & R Wrapper)
**Files:** `R/uncertainty.R` (new), `src/uncertainty.rs` (new), `src/lib.rs` (modify)

1.  **Implement the primary R wrapper function:**
    ```r
    sm_optim_bootstrap <- function(observed, x, initial_params, 
                                    FUN = sm_shape_sigmoid,
                                    OPTFUN = sm_optim_rmse,
                                    optimizer = "lbfgs", # Supports existing optimizers
                                    n_bootstrap = 1000,
                                    ci = 0.95,
                                    method = c("auto", "parametric", "sieve"),
                                    sieve_threshold = 20, # User-tunable threshold
                                    strict = FALSE,       # Controls fallback behavior
                                    seed = NULL) {
        # 1. Input validation in R.
        # 2. Logic for 'auto' method selection based on `sieve_threshold`.
        # 3. Call the Rust backend, passing data and control parameters as strings/primitives.
        # 4. Receive a named list from Rust and assemble the final S3 'BootstrapResult' object.
        # 5. Convert the list of parameter samples to a matrix, handling NaNs.
    }
    ```

### Input Validation & Error Handling (R Layer)

The R wrapper function performs comprehensive validation before calling Rust:

**Data Validation**:
- `observed`: Must be numeric vector, length >= 1, no NaN values (or NaN positions flagged with clear error message)
- `initial_params`: Must be numeric vector of correct length for the specified shape_type
- `x` (depth positions): Must be numeric vector, same length as `observed`

**Parameter Validation**:
- `n_bootstrap`: Must be integer > 0, recommend < 10,000 (warn if > 5,000 for performance)
- `ci`: Must be numeric in (0, 1); typical values are 0.95, 0.90
- `method`: Must be one of "auto", "parametric", "sieve"; case-insensitive recommended
- `sieve_threshold`: Must be positive integer, typically 15-50 depending on data density
- `strict`: Must be logical
- `seed`: If provided, must be integer; triggers R-side RNG seed setting for reproducibility
- `optimizer`: Must match one of the supported optimizer types (validated via lookup table)

**Error Messages**:
- All validation errors should provide specific guidance (e.g., "sieve_threshold must be >= 1, got -5")

2.  **Create the Rust bootstrap engine (`bootstrap_engine_rust`):**
    *   The function will accept `shape_type`, `objective_type`, and `optimizer_type` as strings to leverage the existing dispatch mechanisms.
    *   It will **always perform an initial optimization** using the specified methods to ensure consistency.
    *   It will contain a `match` statement to dispatch to the correct bootstrap implementation (`parametric` or `sieve`).
    *   **Failed iterations** during the bootstrap loop will be handled by storing a vector of `f64::NAN` values for the parameter samples of that iteration.

3.  **Implement the Sieve Bootstrap Logic in Rust:**
    *   **Model Fitting**: Fit an **AR(1)** model to the residuals of the initial fit.
    *   **Solver**: Use the **`ndarray-linalg`** crate to solve the Yule-Walker equations for the AR(1) coefficient.
    *   **Error Handling & AR Model Validation**:
        *   After solving Yule-Walker equations, validate the AR(1) coefficient:
            *   Valid range: -1 < φ < 1 (stationarity condition)
            *   If φ outside valid range: Treat as AR fit failure, apply fallback logic
        *   Potential failure modes:
            *   Singular Toeplitz matrix (weak autocorrelation or numerical precision)
            *   ndarray-linalg solver convergence failure
            *   Insufficient residual variance (flat profile)
        *   For each failure: Follow fallback logic detailed below
    *   **Resampling**: **Directly resample the calculated innovations** from the AR model fit (non-parametric).
    *   **Fallback Logic & Method Dispatch**:
        *   The `strict` parameter controls fallback behavior during Sieve bootstrap:
            *   `strict = FALSE` (default): If AR model fit fails, fall back to Parametric bootstrap with a user-visible warning.
            *   `strict = TRUE`: If AR model fit fails, return an error.
        *   **Important**: The above applies ONLY when `method = "auto"`.
            *   If user explicitly requests `method = "sieve"`, and AR fit fails, the function ALWAYS errors, regardless of `strict` setting.
            *   Rationale: Explicit method choice indicates user intent; failure should be transparent.
            *   If user requests `method = "parametric"`, no AR fitting occurs; no fallback logic applies.

4.  **Implement the FFI Data Transfer:**
    *   The Rust `BootstrapEngineResult` struct will be exposed to R via `extendr`.
    *   The `#[extendr]` macro will handle the conversion of the struct to a **named R `list`**.
    ```rust
    // In src/uncertainty.rs
    use extendr_api::prelude::*;

    #[derive(Debug, Clone)]
    #[extendr]
    pub struct BootstrapEngineResult {
        pub param_samples: Vec<Vec<f64>>, // Can contain f64::NAN
        pub original_params: Vec<f64>,
        pub original_cost: f64,
        pub convergence: Vec<bool>,
        pub errors: Vec<Option<String>>,
    }
    ```

*(Deliverables D2 through D6 for Prediction Intervals, Sensitivity Analysis, Convergence Diagnostics, and R Integration remain conceptually the same and will be built in R on top of the results from this Rust engine.)*

---

## Final Specification Summary

| Feature | Decision |
| :--- | :--- |
| **Methodology** | Dual: **Parametric** (`n <= sieve_threshold`) & **Sieve** (`n > sieve_threshold`). |
| **Architecture** | **Rust Core** for computation, **R Wrapper** for user interface. |
| **AR Model (Sieve)** | Order **p=1**, using **`ndarray-linalg`** for Yule-Walker, **direct resampling** of innovations. |
| **Fallback Behavior** | `strict = FALSE` (default): Sieve auto-falls back to Parametric with warning if AR fit fails. `strict = TRUE`: Sieve errors if AR fit fails. **If method="sieve" explicitly requested, ALWAYS error on AR fit failure, regardless of strict setting.** |
| **Method Dispatch** | Supports "auto", "parametric", "sieve" modes. String-based dispatcher for optimizers, objectives, and shapes reuses existing dispatch logic in `src/optimizer.rs`, `src/objective.rs`, `src/shape_functions.rs`. |
| **Dependencies** | **Full integration** with existing `argmin` optimizers, objective functions, and shape functions. All via string-based dispatcher pattern. |
| **Initial Fit** | **Always re-optimized in Rust** for consistency using the specified optimizer and objective function. |
| **FFI Structure** | Rust `struct` exposed as a **named R `list`** via `extendr`. |
| **Failed Iterations** | Stored as a row of **`NaN`** values in the parameter samples matrix. |
| **Auto-Method Threshold**| User-configurable via the `sieve_threshold` R parameter (defaulting to 20). If `n <= sieve_threshold`, method defaults to "parametric"; if `n > sieve_threshold`, defaults to "sieve". |
| **Reproducibility** | R-side seed handling via `set.seed(seed)` for deterministic resampling. |
| **Validation** | Comprehensive R-layer input validation for data, parameters, and method choices; clear error messages for invalid inputs. |
| **Explicit Method Behavior** | When user explicitly requests method="sieve" (not "auto"), AR fit failure always results in error, providing transparency about method availability. |

This finalized prompt provides a clear and comprehensive plan. It is technically robust, leverages the existing strengths of your codebase, and includes user-centric features like tunable thresholds, safe fallback behaviors, and explicit vs. auto method semantics. The path to implementation is now clearly defined.