# Phase 2: Rust Foundation & Performance Layer
## Phase Overview & High-Performance Optimization Engine

**Duration:** ~3 weeks (concurrent/after Phase 1)  
**Goal:** Build a high-performance Rust backend for motif fitting and batch processing, replacing or supplementing the R optimization layer for large-scale analyses.

**Deliverables:**
- Rust project structure with Cargo.toml and extendr setup
- Core objective functions (RMSE, SSQ) in Rust
- Single-profile optimization in Rust (integration with R via extendr)
- Batch profile processing with parallel execution
- Integration tests between R and Rust layers

---

## Subphase Dependencies

```
2.A (Project Setup)
    v
2.B (Core Functions) <- depends on 2.A
    v
2.C (Single Profile) <- depends on 2.B
    v
2.D (Batch Processing) <- depends on 2.C
    v
2.E (R Integration) <- depends on all above
```

---

## Subphase Breakdown

### **2.A: Project Setup**
**Deliverable:** Functional Rust project with extendr FFI  
**Prompt:** `02a-project-setup.md` (stub; to be expanded)  
**Estimated Time:** 2-3 hours  
**Est. Lines of Code:** 50-100 Rust + TOML

**Key Outputs:**
- Cargo project structure
- extendr dependencies and macros
- R function stubs to call Rust functions
- Test infrastructure (both Rust and R sides)

---

### **2.B: Core Functions**
**Deliverable:** RMSE, SSQ, and parametric fitting primitives  
**Prompt:** `02b-core-functions.md` (stub)  
**Estimated Time:** 3-4 hours  
**Est. Lines of Code:** 200-300 Rust

**Key Outputs:**
- `compute_rmse()` in Rust
- `compute_ssq()` in Rust
- Shape function generators (replicate R versions)
- Optimization wrapper (wraps argmin or similar)

---

### **2.C: Single-Profile Optimization**
**Deliverable:** R-callable Rust optimizer for one profile  
**Prompt:** `02c-single-profile.md` (stub)  
**Estimated Time:** 4-5 hours  
**Est. Lines of Code:** 300-400 Rust

**Key Outputs:**
- `optimize_single_profile()` exposed to R
- Parameter passing and return
- Error handling (NaNs, convergence failures)
- Performance benchmarks vs. R `stats::optim`

---

### **2.D: Batch Processing**
**Deliverable:** Parallel fitting for profile collections  
**Prompt:** `02d-batch-processing.md` (stub)  
**Estimated Time:** 3-4 hours  
**Est. Lines of Code:** 150-200 Rust

**Key Outputs:**
- Rayon-based parallelization
- `fit_profiles_parallel()` function
- Load balancing and progress reporting
- Memory efficiency for large datasets

---

### **2.E: R Integration**
**Deliverable:** Seamless R <-> Rust communication layer  
**Prompt:** `02e-r-integration.md` (stub)  
**Estimated Time:** 3-4 hours  
**Est. Lines of Code:** 150-200 R

**Key Outputs:**
- R function wrappers (`sm_optim_rust()`, `fit_motif_batch_rust()`)
- Performance comparison framework
- Fallback logic (Rust error -> use R)
- Complete integration tests

---

## Phase 2 Exit Criteria

When Phase 2 is complete:

[x] Rust project compiles without errors  
[x] Single-profile optimization runs in <10 ms (vs. ~100 ms in R)  
[x] Batch processing (1000 profiles) completes in <1 sec  
[x] R <-> Rust FFI tested and working  
[x] All integration tests pass  
[x] README notes performance improvements  

---

## Key Technologies

| Component | Library | Purpose |
|-----------|---------|---------|
| FFI | extendr | R <-> Rust function calls |
| Optimization | argmin / nalgebra | Parameter optimization |
| Parallelization | rayon | Multi-threaded batch processing |
| Build | cargo | Rust package management |

---

## Performance Targets

| Benchmark | Current (R) | Target (Rust) | Speedup |
|-----------|------------|---------------|---------|
| 1 profile, 1 model | ~100 ms | <10 ms | 10x |
| 100 profiles, 1 model | ~10 sec | <100 ms | 100x |
| 1000 profiles, all 7 models | N/A | <10 sec | -- |

---

## Handoff Checklist

**Phase 2 Complete When:**
- [ ] Rust project structure created
- [ ] Extendr FFI working
- [ ] Single-profile optimization 10x faster than R
- [ ] Batch processing tested with 1000+ profiles
- [ ] R integration layer complete
- [ ] All tests passing
- [ ] Performance benchmarks documented
- [ ] Git: `Phase-2: Add Rust optimization backend`

---

## Known Challenges

1. **Parameter Space Dimensionality:** Some motifs have 5+ parameters; optimization landscape complex
2. **Convergence Guarantees:** Rust optimizer may diverge differently than R's `optim`; need fallback strategy
3. **Memory/Speed Tradeoff:** Parallelization benefits depend on profile size and number
4. **Build Complexity:** Rust FFI adds build steps; must not break user experience

---

## Resources

- extendr documentation: https://extendr.github.io/
- argmin documentation: https://argmin-rs.github.io/
- rayon documentation: https://docs.rs/rayon/

---

**Phase 2 Lead:** [Agent Name / TBD]  
**Phase 2 Start Date:** [After Phase 1 completion]  
**Phase 2 Target Completion:** [TBD + 3 weeks]  
**Phase 2 Status:** NOT STARTED
