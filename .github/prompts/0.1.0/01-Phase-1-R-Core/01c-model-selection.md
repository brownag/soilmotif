# Subphase 1.C: Model Selection Engine
## Automated Fitting and Ranking of Multiple Motif Types

**Context:** With all seven shape functions working and a generalized optimization framework in place, you now build the killer feature: `fit_motif_auto()`. This function automatically fits all motif types to input data and ranks them by goodness-of-fit metrics (AIC, BIC, RMSE, R^2).

**Time Estimate:** 4-5 hours  
**Code Volume:** 150-200 lines (mostly in new `R/model-selection.R`)

---

## Objectives

1. Implement `fit_motif_auto(x, models = "all", criterion = "AIC", ...)`
2. Fit all seven motif types with smart initial parameter selection
3. Calculate fit statistics (RMSE, SSQ, AIC, BIC, R^2) for each
4. Rank models by specified criterion
5. Return detailed comparison object with visualizations
6. Handle edge cases (short data, failed fits, tied scores)

---

## Core Function: `fit_motif_auto()`

### Signature

```r
fit_motif_auto <- function(x, 
                           models = "all",
                           criterion = "AIC",
                           depth_range = c(1, 200),
                           ...) {
  # x: numeric vector (soil property profile, 1 unit resolution)
  # models: "all" or character vector of motif names
  #         c("uniform", "gradational", "exponential", "wetting_front", 
  #           "abrupt", "peak", "minimax")
  # criterion: "AIC" | "BIC" | "RMSE" | "R2" (default "AIC")
  # depth_range: c(min_depth, max_depth)
  # ...: additional arguments passed to sm_optim()
  
  # Returns: list with classes c("fit_motif_auto", "list")
  #   - $fits: list of fitted motifs for each model
  #   - $stats: data.frame with fit statistics
  #   - $best: name of best model by criterion
  #   - $ranking: ordered data.frame of all models ranked
}
```

### Implementation Outline

```r
fit_motif_auto <- function(x, 
                           models = "all",
                           criterion = "AIC",
                           depth_range = c(1, 200),
                           ...) {
  
  # Validate inputs
  if (!is.numeric(x)) stop("x must be numeric")
  if (length(x) < 10) warning("x is very short; fitting may be unreliable")
  if (!(criterion %in% c("AIC", "BIC", "RMSE", "R2"))) {
    stop("criterion must be one of 'AIC', 'BIC', 'RMSE', 'R2'")
  }
  
  # Determine which models to fit
  all_models <- c("uniform", "gradational", "exponential", "wetting_front",
                  "abrupt", "peak", "minimax")
  if (identical(models, "all")) {
    models_to_fit <- all_models
  } else {
    models_to_fit <- intersect(models, all_models)
    if (length(models_to_fit) == 0) 
      stop("No valid models specified")
  }
  
  # Fit each model
  fits <- list()
  stats <- data.frame(
    model = character(),
    rmse = numeric(),
    aic = numeric(),
    bic = numeric(),
    r2 = numeric()
  )
  
  for (model_name in models_to_fit) {
    tryCatch({
      # Get initial parameters
      initial_par <- .suggest_initial_params(x, model_name)
      
      # Get shape function
      shape_fun <- get(paste0("sm_shape_", model_name))
      
      # Fit
      fit_result <- sm_optim(x, initial_par, FUN = shape_fun, ...)
      
      # Calculate statistics
      rmse <- sm_optim_rmse(x, fit_result)
      residuals <- x - fit_result
      ss_res <- sum(residuals^2)
      ss_tot <- sum((x - mean(x))^2)
      r2 <- 1 - (ss_res / ss_tot)
      n <- length(x)
      k <- length(attr(fit_result, 'par'))
      aic <- n * log(ss_res / n) + 2 * k
      bic <- n * log(ss_res / n) + log(n) * k
      
      fits[[model_name]] <- fit_result
      stats <- rbind(stats, data.frame(
        model = model_name,
        rmse = rmse,
        aic = aic,
        bic = bic,
        r2 = r2
      ))
    }, error = function(e) {
      warning(paste0("Failed to fit ", model_name, ": ", e$message))
    })
  }
  
  # Rank by criterion
  if (criterion == "AIC") {
    ranking <- stats[order(stats$aic), ]
  } else if (criterion == "BIC") {
    ranking <- stats[order(stats$bic), ]
  } else if (criterion == "RMSE") {
    ranking <- stats[order(stats$rmse), ]
  } else if (criterion == "R2") {
    ranking <- stats[order(stats$r2, decreasing = TRUE), ]
  }
  
  best_model <- ranking$model[1]
  
  # Return object with S3 class
  result <- list(
    fits = fits,
    stats = stats,
    ranking = ranking,
    best = best_model,
    criterion = criterion,
    input_length = length(x)
  )
  class(result) <- c("fit_motif_auto", "list")
  result
}
```

### S3 Methods for Output

```r
#' @export
print.fit_motif_auto <- function(x, ...) {
  cat("Automated Motif Fitting Results\n")
  cat("================================\n")
  cat("Input length:", x$input_length, "\n")
  cat("Criterion:", x$criterion, "\n")
  cat("Best model:", x$best, "\n\n")
  cat("Ranking (ordered by", x$criterion, "):\n")
  print(x$ranking)
}

#' @export
plot.fit_motif_auto <- function(x, ...) {
  # Create a multi-panel plot showing:
  # 1. Best fit overlaid on data
  # 2. Ranking bar chart (RMSE or AIC)
  # 3. Residuals for best model
  
  par(mfrow = c(1, 2))
  
  # Panel 1: Data + best fit
  best_name <- x$best
  best_fit <- x$fits[[best_name]]
  plot(1:length(best_fit), 1:200, ylim = c(200, 0), type = "n",
       xlab = paste(best_name, "value"), ylab = "Depth (cm)")
  # Add original data points and best fit line
  
  # Panel 2: Ranking bar chart
  barplot(x$ranking[[tolower(x$criterion)]], 
          names.arg = x$ranking$model,
          main = paste("Models ranked by", x$criterion))
}

#' @export
summary.fit_motif_auto <- function(object, ...) {
  cat("=== Motif Fitting Summary ===\n")
  cat("Best model:", object$best, "\n")
  cat("\nTop 3 models:\n")
  print(head(object$ranking, 3))
  cat("\n(Full ranking available in $ranking slot)\n")
}
```

---

## Helper Functions

### Fit Statistics Calculator

```r
.calc_fit_stats <- function(x, fitted, n_params) {
  # x: observed values
  # fitted: fitted values
  # n_params: number of parameters in model
  
  residuals <- x - fitted
  ss_res <- sum(residuals^2)
  ss_tot <- sum((x - mean(x))^2)
  rmse <- sqrt(mean(residuals^2))
  r2 <- 1 - (ss_res / ss_tot)
  
  n <- length(x)
  aic <- n * log(ss_res / n) + 2 * n_params
  bic <- n * log(ss_res / n) + log(n) * n_params
  
  list(rmse = rmse, aic = aic, bic = bic, r2 = r2)
}
```

---

## Acceptance Criteria

### Functionality
- [x] `fit_motif_auto()` successfully fits all 7 motif types
- [x] Returns ranked list with AIC, BIC, RMSE, R^2 statistics
- [x] Criterion parameter (`"AIC"`, `"BIC"`, `"RMSE"`, `"R2"`) works correctly
- [x] Gracefully handles fitting failures (warnings, not errors)
- [x] Works with synthetic and real data

### S3 Methods
- [x] `print()` method shows ranking table
- [x] `plot()` method visualizes results
- [x] `summary()` method shows quick overview

### Testing
- [x] Unit tests for each criterion type
- [x] Integration tests with synthetic data (known best model)
- [x] Edge case tests (short data, uniform data, NAs)
- [x] `devtools::test()` passes all tests

### Performance
- [x] Single 200-point profile across 7 models: <2 seconds
- [x] Handles 100 profiles in batch: <50 seconds

### Documentation
- [x] Roxygen2 comments on main function and S3 methods
- [x] Example: `fit_motif_auto(x, criterion = "AIC")`
- [x] Vignette: "Model Selection with soilmotif"

---

## Test Examples

```r
# Test 1: Synthetic data with known best fit
test_that("fit_motif_auto identifies correct best model", {
  # Create synthetic peak profile
  peak_profile <- sm_motif(1:200, c(100, 30), FUN = sm_shape_peak)
  
  result <- fit_motif_auto(peak_profile, criterion = "AIC")
  expect_equal(result$best, "peak")
})

# Test 2: Criterion comparison
test_that("Different criteria produce different rankings", {
  x <- rnorm(200, mean = 30, sd = 10)
  
  result_aic <- fit_motif_auto(x, criterion = "AIC")
  result_rmse <- fit_motif_auto(x, criterion = "RMSE")
  
  # Expect at least some difference in rankings
  expect_false(identical(result_aic$ranking$model, result_rmse$ranking$model))
})

# Test 3: Print/plot methods
test_that("S3 methods work without error", {
  x <- rnorm(200, mean = 30, sd = 10)
  result <- fit_motif_auto(x, models = c("uniform", "gradational", "peak"))
  
  expect_silent(print(result))
  expect_silent(plot(result))
  expect_silent(summary(result))
})
```

---

## Implementation Checklist

- [ ] Create `R/model-selection.R` with `fit_motif_auto()`
- [ ] Implement fit statistics calculation (`.calc_fit_stats()`)
- [ ] Implement S3 methods (print, plot, summary)
- [ ] Add comprehensive unit tests in `tests/testthat/test-model-selection.R`
- [ ] Test with synthetic data for each motif type
- [ ] Test with real soil data (README examples)
- [ ] Performance benchmark: <2 sec for 7 models on 200 points
- [ ] Verify `devtools::test()` passes
- [ ] Verify `R CMD check` passes
- [ ] Commit: `Phase 1.C: Add automated model selection engine`
- [ ] Update `PHASE_STATUS.md`

---

## Integration Notes

- Depends on: Phase 1.A (all 7 shape functions), Phase 1.B (generalized optim)
- Used by: Phase 1.D (data preprocessing examples), Phase 2 (batch processing in Rust)
- Feeds into: Phase 3 (model comparison for horizon detection)

---

**Next Step:** Parallel with 1.D (Data Preprocessing), then 1.E (Testing & Documentation)
