
<!-- README.md is generated from README.Rmd. Please edit that file -->

# {soilmotif}

<!-- badges: start -->

<!-- badges: end -->

The goal of {soilmotif} is to provide an easy way to fit generalized
shape functions to soil property data that vary over depth. The
parameters of shape functions are designed to provide simple terminology
and intuitive descriptors for comparing the depth distributions of
properties found in soils of different areas and as predicted by
different types of models.

## Installation

You can install the development version of {soilmotif} like so:

``` r
remotes::install_github("brownag/soilmotif")
```

### Building from Source

{soilmotif} includes a high-performance Rust backend. For detailed
installation instructions, platform-specific troubleshooting, and Rust
compiler setup, see [inst/INSTALL.md](inst/INSTALL.md).

You will need:

- C compiler (included with Rtools, Xcode, or build-essential)

- Rust toolchain (`rustc`, `cargo`):
  <https://www.rust-lang.org/tools/install/>

## Example

This is a basic example which shows you how to fit a sigmoidal depth
distribution model to a step and spline representations of some soil
property data as a function of depth.

The sample data comes from the {aqp} `jacobs2000` dataset. We are using
just select horizon data from the first profile in that
`SoilProfileCollection` object.

``` r
library(soilmotif)

# from aqp::jacobs2000, profile 1
x <- data.frame(
  id = "jacobs2000_1",
  top = c(0, 18, 43, 79, 130, 153, 156),
  bottom = c(18, 43, 79, 130, 153, 156, 200),
  clay = c(7, 6, 39, 41, 51, 50, 47),
  depletion_pct = c(0, 0, 0, 0, 2, 0, 15)
)
```

# Step-wise Horizon-level Depletion Percentage Example

Common morphologic descriptions of soils by genetic horizon can be made
continuous by assuming they represent a “step” function. Repeat the
horizon-level property value as many times as each horizon is thick (in
centimeters, or whatever unit you are interested in).

Here, we convert the percentage of the matrix occupied by depletions
`depletion_pct` into a continuous step-function representation, then
attempt to fit a sigmoid model to the distribution using `sm_motif()`.
After inspection, we use `sm_optim()` to optimize a model based on our
first guess (that the depletions appear around 40 cm and peak by 60 cm).

``` r
depl_step <- rep(x$depletion_pct, x$bottom - x$top)

plot(rep(c(0, 20), 100), 1:200, ylim = c(200, 0), type = "n",
     xlab = "Depletion %", ylab = "Depth, cm")
points(depl_step, 1:200, pch = "+")

# visualize what the "first guess" looks like
lines(sm_motif(depl_step, c(40, 60)), 1:200, col = "red", lty = 2)

# find an optimized model
opt_result <- sm_optim(depl_step, c(40, 60))
lines(opt_result$fitted, 1:200, col = "blue")
opt_result$params
#> [1] 156.6496 156.7814

legend("topright", c("Input", "Initial", "Optimized"),
       pch = c("+", NA, NA),
       lty = c(NA, 2, 1),
       col = c("BLACK","RED","BLUE"))
```

<img src="man/figures/README-unnamed-chunk-2-1.png" width="100%" />

We find that the blue line (the optimized model) captures the
transition, and best-fit parameters indicate a rapid increase at 156 cm
depth, mirroring the increase from the input data.

# Continuous Spline Clay Content Example

The results can be more interesting when the depth function is more
complicated. The simplified shapes can be used to group and generalize
patterns, while ideally capturing the same types of major transitions
across depth.

The following is a mass-preserving spline created using {mpspline2},
with values rounded to integers for compression into `"rle"` object for
minimal example:

``` r
clay_spline <- inverse.rle(structure(list(
  lengths = c(19, 8, 5, 3, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 3, 4, 
              17, 7, 37, 5, 2, 2, 1, 1, 1, 2, 2, 6, 6, 6, 3, 5, 38),
  values = c(7, 6, 7, 8, 9, 10, 12, 13, 15, 17, 19, 23, 26, 28, 30, 32, 33, 35,
             36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 50,
             49, 48, 47)), class = "rle"
))

plot(rep(c(0, 50), 100), 1:200, ylim = c(200, 0), type = "n",
     xlab = "Clay %", ylab = "Depth, cm")
points(clay_spline, 1:200, pch = "+")
lines(sm_motif(clay_spline, c(25, 100)), 1:200, col = "red", lty = 2)
opt_result <- sm_optim(clay_spline, c(25, 100))
lines(opt_result$fitted, 1:200, col = "blue")
# Display optimized parameters (note: parameters can fall outside typical [0,1] range)
cat("Optimized Parameters:", opt_result$params, "\n")
#> Optimized Parameters: -23.47231 140.3907

legend("bottomleft", c("Input", "Initial", "Optimized"),
       pch = c("+", NA, NA),
       lty = c(NA, 2, 1),
       col = c("BLACK","RED","BLUE"))
```

<img src="man/figures/README-unnamed-chunk-3-1.png" width="100%" />

In this case we find that the optimized parameters result in a steeper
gradient of property increase than was initially guessed with parameters
`c(25, 100)`. The optimized curve fits the data more closely with a
smoother transition zone centered around 45 cm. Note that the optimized
parameters can fall outside the typical \[0,1\] range for shape
parameters—this is expected behavior as the optimization algorithm
selects parameter values that best fit the observed data, even if they
represent extreme sigmoid transformations.

## Uncertainty Quantification via Bootstrap

{soilmotif} provides multiple bootstrap methods to estimate confidence
intervals for fitted parameters. Each method handles autocorrelation
differently:

- **Parametric Bootstrap**: Resamples residuals independently. Fast and
  simple, suitable when autocorrelation is weak or negligible.
- **Block Bootstrap**: Resamples contiguous blocks of residuals with
  replacement. Preserves local autocorrelation naturally without model
  fitting. Recommended for depth-ordered data with unknown correlation
  structure.
- **Sieve Bootstrap**: Fits an AR(1) model to residuals and resamples
  innovations. More efficient when autocorrelation follows AR(1)
  dynamics exactly.

### Parametric Bootstrap (Independence Assumption)

For the clay spline example, we use parametric bootstrap which assumes
residuals are independent:

``` r
library(soilmotif)

# Parametric bootstrap - assumes independent residuals
result_param <- sm_optim_bootstrap(
  observed = clay_spline,
  depths = 1:200,
  initial_params = c(25, 100),
  shape_family = "sigmoid",
  n_bootstrap = 100,
  method = "parametric",
  seed = 42
)

cat("Parametric Bootstrap Results:\n")
#> Parametric Bootstrap Results:
cat("Param 1 (position): ",
    sprintf("%.2f +/- %.2f", result_param$summary$param_mean[1],
                            result_param$summary$param_sd[1]), "\n")
#> Param 1 (position):  92.28 +/- 6.78
cat("Param 2 (steepness): ",
    sprintf("%.2f +/- %.2f", result_param$summary$param_mean[2],
                            result_param$summary$param_sd[2]), "\n")
#> Param 2 (steepness):  2.90 +/- 6.81
```

### Block Bootstrap (Preserves Autocorrelation)

For the same data, block bootstrap preserves depth autocorrelation by
resampling contiguous blocks:

``` r
# Block bootstrap - preserves autocorrelation through block resampling
result_block <- sm_optim_bootstrap(
  observed = clay_spline,
  depths = 1:200,
  initial_params = c(25, 100),
  shape_family = "sigmoid",
  n_bootstrap = 100,
  method = "block",
  seed = 42
)

cat("Block Bootstrap Results:\n")
#> Block Bootstrap Results:
cat("Param 1 (position): ",
    sprintf("%.2f +/- %.2f", result_block$summary$param_mean[1],
                           result_block$summary$param_sd[1]), "\n")
#> Param 1 (position):  92.52 +/- 16.15
cat("Param 2 (steepness): ",
    sprintf("%.2f +/- %.2f", result_block$summary$param_mean[2],
                           result_block$summary$param_sd[2]), "\n")
#> Param 2 (steepness):  4.54 +/- 14.00

# Block bootstrap typically gives wider confidence intervals due to autocorrelation
cat("\nUncertainty Ratio (Block / Parametric):\n")
#> 
#> Uncertainty Ratio (Block / Parametric):
cat("Param 1:", sprintf("%.2f", result_block$summary$param_sd[1] / result_param$summary$param_sd[1]), "\n")
#> Param 1: 2.38
cat("Param 2:", sprintf("%.2f", result_block$summary$param_sd[2] / result_param$summary$param_sd[2]), "\n")
#> Param 2: 2.06
```

### Sieve Bootstrap (AR(1) Modeling)

Sieve bootstrap is effective when residuals follow strong AR(1) trends.
This works best when you have data with clear autoregressive structure:

``` r
# Create synthetic data with strong AR(1) trend (phi = 0.7)
set.seed(42)
depths_ar <- 1:200
# Start with sigmoid shape
base_clay <- sm_motif(depths_ar, c(25, 100))

# Add AR(1) residuals (phi = 0.7 means strong positive autocorrelation)
phi <- 0.7
sigma <- 3
residuals_ar1 <- numeric(length(depths_ar))
residuals_ar1[1] <- rnorm(1, 0, sigma)
for (i in 2:length(depths_ar)) {
  residuals_ar1[i] <- phi * residuals_ar1[i-1] + rnorm(1, 0, sigma)
}
clay_ar1 <- base_clay + residuals_ar1

# Sieve bootstrap with AR(1) structure
result_sieve <- sm_optim_bootstrap(
  observed = clay_ar1,
  depths = depths_ar,
  initial_params = c(25, 100),
  shape_family = "sigmoid",
  n_bootstrap = 100,
  method = "sieve",
  seed = 42
)

cat("Sieve Bootstrap Results (AR(1) data, phi = 0.7):\n")
#> Sieve Bootstrap Results (AR(1) data, phi = 0.7):
cat("Estimated AR(1) coefficient: ", sprintf("%.4f", result_sieve$ar1_coef), "\n")
#> Estimated AR(1) coefficient:  0.9807
cat("Param 1: ", sprintf("%.2f +/- %.2f", result_sieve$summary$param_mean[1],
                                         result_sieve$summary$param_sd[1]), "\n")
#> Param 1:  87.12 +/- 34.14
cat("Param 2: ", sprintf("%.2f +/- %.2f", result_sieve$summary$param_mean[2],
                                         result_sieve$summary$param_sd[2]), "\n")
#> Param 2:  33.58 +/- 27.50
```

### Comparison: Which Method to Use?

**Use Parametric Bootstrap if:** - Residuals appear to be white noise
(uncorrelated) - You need maximum computational speed - Data size is
small (n \< 50)

**Use Block Bootstrap if:** - You have depth-ordered or
spatially-ordered data - Autocorrelation structure is unknown - You want
a robust, parameter-free method - ✓ Recommended for most soil profile
data

**Use Sieve Bootstrap if:** - You’ve verified AR(1) structure in
residuals (plot ACF) - Autocorrelation is moderate to strong and
persistent - You want slightly narrower intervals for well-behaved AR(1)
data

## Rust Backend (High-Performance)

{soilmotif} includes an optional high-performance Rust backend for
single-profile and batch optimization. When available, Rust
implementations are typically **10-30x faster** than pure R.

### Usage

``` r
library(soilmotif)

# Check if Rust backend is available
sm_rust_backend_available()
#> [1] TRUE

# Single profile optimization with Rust
profile <- c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50))
result <- sm_optim(profile, c(100, 20), use_rust = TRUE)

# Batch processing (ideal for raster grid cells)
profiles <- list(
  c(rep(10, 50), seq(10, 40, length.out = 100), rep(40, 50)),
  c(rep(15, 50), seq(15, 45, length.out = 100), rep(45, 50))
)
batch_result <- sm_batch_optimize_profiles(profiles)
batch_result
#> 
#> === Batch Optimization Result ===
#> Batch result: 2 profiles, 2 successful, 0 failed, method: Sequential 
#> Method: Sequential 
#> 
#> All profiles converged successfully.
```
