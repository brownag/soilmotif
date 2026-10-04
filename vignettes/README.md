# Bootstrap Visualization Vignettes

This directory contains executable R scripts demonstrating how to visualize bootstrap results from uncertainty quantification in soil profile fitting.

## Quick Start

### 1. Simple Bootstrap Visualization (5 minutes)
```bash
Rscript bootstrap_quickstart_viz.R
```

**What it shows:**
- Parameter distribution histograms
- Fitted curve with 95% confidence band
- Parameter correlation scatter plot
- Summary statistics table

**Best for:** Learning the basics of visualizing bootstrap results

---

## Detailed Vignettes

### 2. Comprehensive Bootstrap Analysis (10 minutes)
```bash
Rscript bootstrap_visualization.R
```

**What it shows:**
- Side-by-side parameter distributions for parametric and block bootstrap
- Confidence interval width comparisons
- Fitted curves with uncertainty envelopes
- Parameter correlation and confidence box

**Key visualizations:**
1. 2x2 grid of parameter distributions
2. Confidence interval comparison bars
3. Fitted curve with bootstrap confidence band
4. Parameter scatter plot with CI box

**Best for:** Understanding uncertainty quantification in detail

---

### 3. Bootstrap Methods Comparison (15 minutes)
```bash
Rscript bootstrap_methods_comparison.R
```

**What it shows:**
- Side-by-side comparison of parametric, block, and sieve bootstrap
- Confidence interval width ratios
- AR(1) coefficient estimation (sieve method)
- Uncertainty amplification relative to parametric bootstrap

**Key visualizations:**
1. 3x2 grid comparing parameter distributions
2. CI width bars for each method
3. Summary statistics table
4. Uncertainty ratios (relative to parametric)

**Best for:** Deciding which bootstrap method to use for your data

---

## Understanding the Visualizations

### Parameter Distributions
- **Histograms** show the empirical distribution of bootstrap parameter samples
- **Red dashed line** indicates the mean parameter value
- **Wide distributions** indicate large parameter uncertainty
- **Multimodal distributions** may indicate identification issues

### Confidence Intervals
- **[CI Lower, CI Upper]** define the 95% confidence interval
- **Block bootstrap** intervals are typically 2-3x wider than parametric
- **Narrower intervals** don't necessarily mean better—they may underestimate real uncertainty

### Fitted Curves with Confidence Bands
- **Data points** show observed values
- **Blue line** shows mean fitted curve
- **Shaded region** shows 95% confidence envelope
- **Width of envelope** reflects parameter uncertainty

### Parameter Correlation Plots
- **Each point** represents one bootstrap sample
- **Red diamond** shows the mean parameters
- **Red box** shows 95% confidence region
- **Scatter pattern** reveals parameter correlations (diagonal = positive correlation)

---

## When to Use Each Visualization

| Question | Visualization |
|----------|---|
| What is the mean and SD of my parameters? | Parameter distributions (hist) |
| How wide are my confidence intervals? | CI comparison bars |
| How much uncertainty in predictions? | Fitted curve with band |
| Do parameters correlate? | Parameter scatter plot |
| Which bootstrap method should I use? | Methods comparison |

---

## Customizing the Visualizations

You can modify these scripts to:
1. Change the number of bootstrap iterations (`n_bootstrap = 100`)
2. Use different shape families (`shape_family = "sigmoid"` or `"exponential"`)
3. Compare different data scenarios
4. Export results to publication-quality figures

---

## Example Outputs

### Block Bootstrap (Recommended for Soil Data)
```
Parameter 1 (Position):  174.12 +/- 18.01
Parameter 2 (Steepness): 16.50 +/- 19.16
Success rate: 100/100
```

### Parametric Bootstrap (Baseline)
```
Parameter 1 (Position):  182.28 +/- 8.13
Parameter 2 (Steepness): 6.99 +/- 8.55
Success rate: 100/100
```

**Key observation:** Block bootstrap gives 2-3x wider confidence intervals, accounting for depth autocorrelation that parametric bootstrap ignores.

---

## Troubleshooting

### Script takes too long
- Reduce `n_bootstrap` from 100 to 50
- The bottleneck is the `bootstrap_methods_comparison.R` script (3 methods × 100 iterations)

### Plots look strange
- Ensure you're using the correct `initial_params` for your data
- Check that observed values are in reasonable range (not extreme outliers)

### Method comparison shows degenerate results
- This can happen with certain data + method combinations
- Block bootstrap is more robust across different data types
- See README.md in main directory for guidance

---

## References

- Kunsch, H.R. (1989). "The Jackknife and the Bootstrap for General Stationary Observations", Annals of Statistics
- Lahiri, S.N. (1999). "Theoretical Comparisons of Block Bootstrap for Dependent Data", Annals of Statistics
- For soil science applications, see the main package README

---

## See Also

- `README.md` - Main package README with bootstrap theory
- `.github/BLOCK-BOOTSTRAP-IMPLEMENTATION.md` - Detailed technical documentation
- `?sm_optim_bootstrap` - R function documentation
