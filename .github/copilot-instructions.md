Purpose
-------
Short, actionable guidance for AI coding agents working on the soilmotif R package.

Quick setup & common commands
-----------------------------
- Install package development dependencies (from project root):

```bash
R -e 'if (!requireNamespace("remotes")) install.packages("remotes"); remotes::install_deps(dependencies = TRUE)'
```

- Run the test suite (uses testthat):

```bash
R -e 'if (!requireNamespace("devtools")) install.packages("devtools"); devtools::test()'
```

- Run a single test file quickly:

```bash
R -e "testthat::test_file('tests/testthat/test-shape.R')"
```

- Run a local package check (fast):

```bash
R CMD check --no-build-vignettes --as-cran .
```

No-Unicode Rule
---------------
- All source code, documentation, examples, and package metadata MUST use only ASCII characters.
- Prefer ASCII equivalents for common symbols (e.g. use `R^2` instead of `R?`, use `"` not smart quotes).  
- Avoid non-ASCII punctuation or symbols in `DESCRIPTION`, `NAMESPACE`, `man/`, `R/`, `vignettes/`, and `tests/`.
- Before finalizing edits, run a quick scan to detect non-ASCII characters and replace them:

```bash
# list files that contain non-ASCII characters
python3 - <<'PY'
import os, re
for root, dirs, files in os.walk('.'):
  for fn in files:
    if fn.endswith(('.R', '.Rd', '.md', '.Rmd', 'DESCRIPTION', 'NAMESPACE')):
      p = os.path.join(root, fn)
      try:
        s = open(p, encoding='utf-8').read()
      except Exception:
        continue
      if re.search(r'[^\x00-\x7F]', s):
        print(p)
PY
```

Add the same check to CI or as a pre-commit hook if desired.

Repository layout & big picture
------------------------------
- This is a small R package whose core is in `R/` and documentation in `man/`.
- High-level responsibilities:
  - `R/spline.R` -- mass-preserving spline wrappers around `mpspline2` / `aqp` inputs.
  - `R/shape.R` -- seven shape functions for soil depth function typologies: uniform, gradational, exponential, wetting_front (sigmoid), abrupt, peak, minimax. See `sm_shape_sigmoid()` and related functions.
  - `R/fit.R` -- motif fitting and optimization (`sm_motif()`, `sm_optim()`).
  - `R/util.R` -- small helpers (e.g. `.scaleprop()`).
- `README.Rmd`/`README.md` contains runnable examples you can reuse in tests or reproductions.

Project-specific conventions & gotchas
-----------------------------------
- Naming: exported functions are prefixed with `sm_` (e.g. `sm_motif`, `sm_optim`). Check `NAMESPACE`.
- Depth axis: many functions assume a 1..200 depth axis by default (`ylim = c(1, 200)`) and plotting uses depth increasing downward (plots often use `ylim = c(200, 0)`). Be careful when changing the default range.
- Input shapes:
  - `sm_spline()` accepts a data.frame (id/top/bottom/var), a `SoilProfileCollection` (via `aqp`) or a numeric vector. It uses `requireNamespace()` checks -- safe to call even when `aqp`/`mpspline2` are not installed.
  - `sm_motif()` expects a continuous numeric vector (1-unit resolution) representing a soil property over depth.
- Optimization: `sm_optim()` calls `stats::optim()` and then returns `sm_motif(..., sort(fit$par))` -- note it sorts optimizer parameters before producing the final motif.
- Scaling: `.scaleprop()` (in `R/util.R`) clamps outputs to the observed property bounds; understand it before changing scaling behavior.

Tests & docs workflow
---------------------
- Tests live in `tests/testthat/` and the project uses testthat edition 3 (see `DESCRIPTION`).
- After editing exported functions or docs, regenerate docs/NAMESPACE with roxygen2:

```r
# in R console
if (!requireNamespace('devtools')) install.packages('devtools')
devtools::document()
```

Integration points & external deps
---------------------------------
- Uses `mpspline2` and `aqp` for spline conversions in `sm_spline()` -- these are optional and guarded by `requireNamespace()`.
- Uses `stats::optim()` for parameter optimization. Keep objective functions in `R/fit.R` (`sm_optim_rmse`, `sm_optim_ssq`).

Concrete examples agents can use or modify
---------------------------------------
- Fit a sigmoid motif to a numeric vector `x`:

```r
library(soilmotif)
model <- sm_motif(x, c(40, 60))
opt <- sm_optim(x, c(40, 60))
attr(opt, 'par')  # optimized parameters
```

- Convert simple data.frame to spline and fit:

```r
# d should have id/top/bottom/prop columns
sp <- sm_spline(d, var_name = 'prop')
sm_motif(sp[[1]]$est_1cm, c(25, 100))
```

What to watch for when editing
------------------------------
- Preserve argument ordering and default `ylim` semantics -- many examples and tests rely on `c(1,200)`.
- Keep requireNamespace guards in `sm_spline()` so local tests remain lightweight when optional packages are missing.
- If you change exported APIs, update roxygen comments in `R/` and run `devtools::document()` so `man/` and `NAMESPACE` remain in sync.

If anything above is unclear or you need more details (CI, additional dev scripts, or desired test fixtures) tell me which area to expand and I will iterate.
