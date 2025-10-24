# soilmotif Agent Quick Reference Card
## One-Page Cheat Sheet for Coding Agents

---

## [target] Your Task (Quick Answer)

**What am I implementing?**
- Phase 1: Seven soil depth functions + model selection + data preprocessing (R)
- Phase 2: 10x faster Rust optimizer + batch processing
- Phase 3: Horizon detection + weathering indices + soil development metrics
- Phase 4: Testing + documentation + release prep

**How long?** ~9 weeks total for full v0.1.0

---

## [book-open] What to Read

| Situation | Read This First |
|-----------|-----------------|
| I'm starting Phase 1.A (Shapes) | `01-Phase-1-R-Core/01a-shape-functions.md` |
| I'm starting Phase 1.B (Optimization) | `01-Phase-1-R-Core/01b-optimization-framework.md` |
| I'm starting Phase 1.C (Model Selection) | `01-Phase-1-R-Core/01c-model-selection.md` |
| I'm starting Phase 1.D (Preprocessing) | `01-Phase-1-R-Core/01d-data-preprocessing.md` |
| I'm starting Phase 1.E (Tests & Docs) | `01-Phase-1-R-Core/01e-testing-documentation.md` |
| I'm new to this project | `INDEX.md` then `00-implementation-guide.md` |
| I'm continuing work | `[PHASE]/PHASE_STATUS.md` |

---

## [rocket] Quick Workflow

1. **Find your subphase prompt** (e.g., `01a-shape-functions.md`)
2. **Read objectives, background, and implementation guidance**
3. **Follow the code structure** and examples provided
4. **Write tests** (look at "Test Examples" section)
5. **Run** `devtools::test()` + `R CMD check` + verify README still works
6. **Commit** with descriptive message (see below)
7. **Update** `PHASE_STATUS.md` with completion
8. **Hand off** to next agent

---

## [floppy] Git Workflow

```bash
# Before starting
git checkout -b phase-1a-shape-functions

# After implementation
git add R/shape.R tests/testthat/test-shape.R
git commit -m "Phase 1.A: Implement seven shape functions

- Added sm_shape_uniform(), sm_shape_gradational(), sm_shape_exponential()
- Added sm_shape_wetting_front(), sm_shape_abrupt(), sm_shape_peak()
- Added sm_shape_minimax()
- All functions return [0,1] values with ascending/descending parameter
- Added unit tests for all shapes"

git push origin phase-1a-shape-functions
```

---

## [test-tube] Quick Test Checklist

Before handing off, run these:

```bash
# In R console:
devtools::test()                  # All tests pass?
devtools::document()              # Roxygen2 works?
# Then in shell:
R CMD check --as-cran --no-build-vignettes .   # 0 errors/warnings?
```

Run README examples manually to verify they still work.

---

## [triangle] The Seven Functions (Reference)

| Function | Formula/Logic | Returns |
|----------|---------------|---------|
| `sm_shape_uniform(x, xlim)` | Constant: `rep(xlim[1])` | Scalar repeated |
| `sm_shape_gradational(x, xlim)` | Linear: `xlim[1] + (x-min)/range * (xlim[2]-xlim[1])` | Ramp |
| `sm_shape_exponential(x, xlim)` | Exponential: `C_0 * exp(-k*x)` | Decay curve |
| `sm_shape_wetting_front(x, xlim)` | Sigmoid: existing `sm_shape_sigmoid()` logic | S-curve |
| `sm_shape_abrupt(x, xlim)` | Step: 0 below, 1 above `xlim[1]` | Step function |
| `sm_shape_peak(x, xlim)` | Normal: `dnorm(x, mean=depth_max, sd=width)` | Bell curve |
| `sm_shape_minimax(x, xlim)` | Two peaks: valley at `xlim[1]`, peak at `xlim[3]` | Two humps |

**All return [0, 1] range. All support `ascending` parameter.**

---

## [clipboard] Files You'll Modify

### Phase 1

| Subphase | Files to Modify/Create |
|----------|------------------------|
| 1.A | `R/shape.R`, `tests/testthat/test-shape.R` |
| 1.B | `R/fit.R`, `tests/testthat/test-fit.R` |
| 1.C | `R/model-selection.R` (new), `tests/testthat/test-model-selection.R` (new) |
| 1.D | `R/preprocess.R` (new), `tests/testthat/test-preprocess.R` (new) |
| 1.E | `DESCRIPTION`, `NEWS.md`, `README.md`, vignettes, regenerate docs |

---

## [magnify] Key Design Patterns

### Shape Function Template
```r
#' @param x numeric. Depth vector (1:200 typical)
#' @param xlim numeric. Parameters for this shape type
#' @param ascending logical. If TRUE, increase; if FALSE, invert
#' @return numeric [0,1] scaled values
sm_shape_TYPENAME <- function(x, xlim, ascending = TRUE) {
  # 1. Compute shape based on x and xlim
  shape <- ... # Your logic here
  
  # 2. Ensure output is in [0, 1]
  shape <- (shape - min(shape)) / (max(shape) - min(shape))
  
  # 3. Apply ascending parameter
  if (!ascending) shape <- 1 - shape
  
  shape
}
```

### Test Template
```r
test_that("sm_shape_TYPENAME returns correct properties", {
  x <- 1:200
  result <- sm_shape_TYPENAME(x, c(...), ascending = TRUE)
  
  # Checks
  expect_length(result, 200)
  expect_true(all(result >= 0 & result <= 1))
  expect_true(all(!is.na(result)))
})
```

---

## [warning] Common Pitfalls

| Problem | Solution |
|---------|----------|
| Shape returns values outside [0,1] | Normalize: `(x - min(x)) / (max(x) - min(x))` |
| `ascending = FALSE` doesn't invert | Use `1 - shape` before returning |
| Tests fail with NAs | Check for NA handling; use `na.omit()` if needed |
| README examples break | Verify backward compatibility; don't change existing function signatures |
| Roxygen2 comments missing | Add `@export` if user-facing; `@param`, `@return`, `@examples` |
| Parameter sorting wrong | Document which motifs should/shouldn't be sorted |

---

## [lightbulb] Helpful Tips

1. **Use existing code as reference:** Look at `sm_shape_sigmoid()` for patterns
2. **Test early, test often:** Run `devtools::test()` after every major change
3. **Keep parameter semantics clear:** Comment on what each parameter means
4. **Document edge cases:** What happens with empty input? Single value?
5. **Hand off cleanly:** Update PHASE_STATUS.md before committing

---

## [phone] Getting Help

**"What does this parameter do?"**
-> Read the "Implementation Strategy" or "Parameter Semantics" section in your action prompt

**"How should my function behave?"**
-> Check "Acceptance Criteria" and "Test Examples" in the action prompt

**"What do I commit?"**
-> Look at "Git Workflow" section above; use clear descriptive messages

**"What if I'm blocked?"**
-> Note it in `PHASE_STATUS.md` and alert the next agent in handoff

---

## [grad] Learning Resources

- **Book Chapter:** "Measuring and Modelling Soil Depth Functions" (sections 14.2-14.3)
- **R Guide:** `?stats::optim` for optimization; `?devtools::test` for testing
- **Package Docs:** `?aqp::SoilProfileCollection` for soil data structures
- **This Repo:** Look at `README.md`, `misc/test-fit.R` for examples

---

## [sparkle] Success = 

1. [x] **Code:** Implements the spec in the action prompt
2. [x] **Tests:** Unit tests + integration tests, all passing
3. [x] **Documentation:** Roxygen2 comments, clear variable names
4. [x] **Compatibility:** README examples still work, no breaking changes
5. [x] **Handoff:** PHASE_STATUS.md updated, git commit with clear message

---

## [target] Phase 1 Subphase Order

```
START -> 1.A (Shapes)
          v
       1.B (Optim) <- depends on 1.A
          v
       1.C (Selection) <- depends on 1.A, 1.B
    ->                          <-
1.D (Preprocess) <- independent    (can run parallel)
    <-                          ->
          1.E (Tests & Docs) <- depends on all above
             v
           END
```

---

**Good luck! You've got this.** [rocket]

*Last Updated: October 2025*
