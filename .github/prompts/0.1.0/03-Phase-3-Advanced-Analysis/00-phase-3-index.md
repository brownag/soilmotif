# Phase 3: Advanced Analysis & Optimization — Complete Prompt Index

## Overview
Phase 3 scaffolds soilmotif from single-profile optimization (Phase 2) to comprehensive soil science analysis. The work is organized into **two parallel tracks**:

### **Optimization Track (3a-3f):** Advanced fitting algorithms and R integration
### **Analysis Track (3g-3l):** Multivariate elemental data, horizon delineation, weathering, networks, temporal/spatial

All deliverables converge on **case study workflows (3l)** demonstrating integrated analysis.

---

## Optimization Track (3a-3f)

| Prompt | Title | Key Deliverable | Dependencies | Status |
|--------|-------|-----------------|--------------|--------|
| **03a** | [Argmin Integration](./03a-argmin-integration.md) | Replace custom Nelder-Mead with argmin L-BFGS/Newton; maintain trait pattern | — (foundational) | ✅ COMPLETED: Full argmin integration with ParamVec wrapper, math traits, and CostFunction implementation |
| **03b** | [Domain-Specific Objectives](./03b-domain-objectives.md) | Implement weighted RMSE, ordinal error, bounded error, Huber loss, quantile loss | 03a | Planned |
| **03c** | [Advanced Algorithms](./03c-algorithms.md) | Expose Simulated Annealing, PSO, GA, DE from argmin; auto-selection logic | 03a | Planned |
| **03d** | [Complex Shapes](./03d-complex-shapes.md) | Add monotone splines, bivariate coupled shapes, threshold-activated shapes | 03a | Planned |
| **03m** | [Bivariate Coupled Shapes](./03m-bivariate-coupled-shapes.md) | Generic constraint framework with anticorrelation, texture triangle, coupled depth | 03d (D1 splines) | Detailed Design ✅ |
| **03n** | [Threshold-Activated Shapes](./03n-threshold-activated-shapes.md) | Piecewise shapes with smooth logistic transitions; paleosols, erosion surfaces | 03d (D1 splines) | Detailed Design ✅ |
| **03e** | [Uncertainty Quantification](./03e-uncertainty.md) | Bootstrap CI, prediction intervals, Sobol sensitivity analysis | 03b, 03c | Planned |
| **03f** | [R Integration & Tidyverse](./03f-r-integration.md) | broom methods, tidyverse pipelines, ggplot2 geoms, Bayesian workflows | 03a-03e | Planned |

**Optimization Track Status:** All prompts created ✅

---

## Analysis Track (3g-3l)

| Prompt | Title | Key Deliverable | Dependencies |
|--------|-------|-----------------|--------------|
| **03g** | [Horizon Boundaries (Mahalanobis)](./03g-horizons-mahalanobis.md) | Objective boundary detection from multivariate element profiles | — (foundational) |
| **03h** | [Fuzzy Horizon Classification](./03h-horizons-fuzzy.md) | Fuzzy k-means clustering for soft horizon assignment + pedologic naming | 03g |
| **03i** | [Weathering Indices](./03i-weathering-indices.md) | CIA, WIP, PIA, SAR, ZrTi, FAR indices; weathering stage classification | 03g, 03h |
| **03j** | [Correlation Networks](./03j-correlation-networks.md) | Correlation networks, community detection, causal inference | 03i (can start earlier) |
| **03k** | [Temporal & Spatial Analysis](./03k-temporal-spatial.md) | Pedogenic rates, catena analysis, kriging, scaling relationships | 03g-3j |
| **03l** | [Case Study Synthesis](./03l-case-studies.md) | Integrated workflows, validated case studies, automated reporting | 03a-03k |

**Analysis Track Status:** All prompts created ✅

---

## Prompt Dependency Graph

```
┌─────────────────────────────────────────────────────────────────┐
│                    OPTIMIZATION TRACK                           │
├─────────────────────────────────────────────────────────────────┤
│  03a (Argmin)                                                   │
│    ├→ 03b (Domain Objectives) ─────┐                          │
│    ├→ 03c (Algorithms) ────────┐    │                          │
│    └→ 03d (Complex Shapes) ─┐  │    ├→ 03e (Uncertainty)      │
│         ├→ 03m (Bivariate)  │  │    │    └→ 03f (R Integration)│
│         └→ 03n (Threshold) ─┘  │    │                          │
│                                │    │                          │
│                                └────┘                           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     ANALYSIS TRACK                              │
├─────────────────────────────────────────────────────────────────┤
│  03g (Mahalanobis Boundaries)                                   │
│    ├→ 03h (Fuzzy Classification)                               │
│    │    └→ 03i (Weathering) ────────────────┐                 │
│    └→ 03i (Weathering)                      ├→ 03j (Network) │
│         └────────────────────────────────────┘                 │
│                                                                  │
│  03j (Network) ─────────────────────────────┐                 │
│  03g-3j (all analysis) ────────────────────┼→ 03k (Temporal) │
│                                             │                   │
│                                             └→ 03l (Synthesis) │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Sequence Recommendations

### **Fast Track (Minimal Dependencies)**
For teams wanting to parallelize work:

**Phase 1 (Weeks 1-2, Parallel):**
- **03a-1**: Argmin L-BFGS integration (1 engineer)
- **03g-1**: Mahalanobis boundary detection (1 engineer)
- **03i-1**: Weathering indices (1 engineer)

**Phase 2 (Weeks 2-4, Parallel):**
- **03b**: Domain objectives (depends on 03a-1 complete)
- **03c**: Algorithms (depends on 03a-1 complete)
- **03h**: Fuzzy classification (depends on 03g-1 complete)
- **03j**: Networks (can start mid-week 3)

**Phase 3 (Weeks 4-6, Sequential):**
- **03e**: Uncertainty (needs 03b+03c)
- **03k**: Temporal/spatial (needs 03g-3j)
- **03l**: Case studies (final integration)

**Phase 4 (Weeks 6-8):**
- **03f**: R integration (final polish + Bayesian)
- Refinement + documentation + testing

### **Conservative Track (Linear Sequence)**
For teams preferring minimal switching:

1. **03a**: Argmin integration (Week 1-2)
2. **03b**: Domain objectives (Week 2-3)
3. **03c**: Algorithms (Week 3-4)
4. **03g**: Mahalanobis (Week 4-5) — can start in parallel with 03b
5. **03h**: Fuzzy classification (Week 5-6)
6. **03d**: Complex shapes (Week 6-7)
7. **03i**: Weathering (Week 7-8)
8. **03j**: Networks (Week 8-9)
9. **03e**: Uncertainty (Week 9-10)
10. **03k**: Temporal/spatial (Week 10-12)
11. **03f**: R integration (Week 12-14)
12. **03l**: Case studies + validation (Week 14-16)

**Total: 16 weeks (1 engineer) or 8 weeks (2 engineers)**

---

## Cross-Cutting Themes

### **1. argmin as Foundation (Optimization Track)**
All optimization prompts (03a-03f) build on argmin framework:
- 03a: Replace custom Nelder-Mead
- 03b: Extend with domain objectives
- 03c: Expose algorithm library
- 03d: Support complex shapes via objective wrappers
- 03e: Use algorithm outputs for uncertainty
- 03f: Expose all to R users

**Key Point:** 03a must complete successfully before 03b/03c; minimal changes to R FFI.

### **2. Multivariate Elemental Data (Analysis Track)**
All analysis prompts (03g-3l) operate on pXRF / multi-element profiles:
- 03g: Mahalanobis distance on elements
- 03h: Fuzzy k-means on elements
- 03i: Element-to-index conversion
- 03j: Correlate elements with properties + detect communities
- 03k: Track elements across time/space
- 03l: Integrate all analyses

**Key Point:** Shared data pipeline; early work on data import/QC (03g) benefits all later prompts.

### **3. Trait-Based Architecture**
Consistent Rust trait pattern across phases:
- **ObjectiveFunction** (existing, 03a) → extended in 03b
- **CostFunction** (argmin) → used in 03a-03f
- **Analyzer** (new in 03g) → extend in 03h-03j
- Enables user extension in Phase 4 (04d: User-Extensible Framework)

### **4. R Integration as Final Layer**
- 03f: Completes Optimization Track
- 03l: Completes Analysis Track
- Both converge on user-friendly APIs
- Reusable patterns for Phase 4

---

## Success Metrics

### **Per Prompt**
Each prompt has exit criteria (see individual documents). Key cross-cutting metrics:

- **Functionality**: Core algorithm correct, edge cases handled
- **Performance**: Maintains Phase 2 speed (50+× faster than R)
- **Integration**: FFI layer unchanged; internal refactoring OK
- **Testing**: All Phase 2 tests still pass (250/250 regression baseline)
- **Documentation**: roxygen comments + vignette with examples

### **Phase 3 Overall**
- ✅ All 12 prompts completed (03a-03l)
- ✅ Argmin integration (03a): Full integration completed with ParamVec wrapper and math traits
- ✅ All Phase 2 tests passing
- ⏳ 5+ case studies fully implemented
- ⏳ 3+ vignettes demonstrating workflows
- ⏳ Documentation suitable for practitioners

---

## File Structure After Phase 3

```
soilmotif/
├── .github/prompts/0.1.0/03-Phase-3-Advanced-Analysis/
│   ├── 03-phase-3.md (updated roadmap)
│   ├── 03a-argmin-integration.md ✅
│   ├── 03b-domain-objectives.md ✅
│   ├── 03c-algorithms.md ✅
│   ├── 03d-complex-shapes.md ✅
│   ├── 03m-bivariate-coupled-shapes.md ✅
│   ├── 03n-threshold-activated-shapes.md ✅
│   ├── 03e-uncertainty.md ✅
│   ├── 03f-r-integration.md ✅
│   ├── 03g-horizons-mahalanobis.md ✅
│   ├── 03h-horizons-fuzzy.md ✅
│   ├── 03i-weathering-indices.md ✅
│   ├── 03j-correlation-networks.md ✅
│   ├── 03k-temporal-spatial.md ✅
│   └── 03l-case-studies.md ✅
│
├── src/
│   ├── optimizer.rs (custom Nelder-Mead; argmin framework prepared) ← 03a (deferred)
│   ├── objectives.rs (new: domain-specific) ← 03b
│   ├── algorithms.rs (new: auto-selection) ← 03c
│   ├── shape_functions.rs (extended) ← 03d
│   ├── horizons.rs (new: Mahalanobis, fuzzy) ← 03g, 03h
│   ├── lib.rs (minimal changes, FFI stable)
│   └── ...
│
├── R/
│   ├── fit.R (minimal changes)
│   ├── horizons.R (new) ← 03g, 03h
│   ├── weathering.R (new) ← 03i
│   ├── correlation.R (new) ← 03j
│   ├── temporal.R (new) ← 03k
│   ├── spatial.R (new) ← 03k
│   ├── case-study.R (new) ← 03l
│   ├── visualization.R (extended)
│   ├── tidyverse-integration.R (new) ← 03f
│   └── ...
│
├── vignettes/
│   ├── case-study-template.Rmd ← 03l
│   ├── case-study-clay-enrichment.Rmd ← 03l
│   ├── case-study-iron-oxidation.Rmd ← 03l
│   ├── case-study-catena-mollisol.Rmd ← 03l
│   ├── case-study-weathering-chronosequence.Rmd ← 03l
│   ├── case-study-network-complex.Rmd ← 03l
│   ├── interpretation-guide.Rmd ← 03l
│   └── ...
│
├── inst/extdata/
│   ├── clay_enrichment_example.csv ← 03l
│   ├── iron_oxidation_example.csv ← 03l
│   ├── catena_mollisol_example.csv ← 03l
│   └── ...
│
├── tests/testthat/
│   ├── test-argmin-integration.R ← 03a
│   ├── test-domain-objectives.R ← 03b
│   ├── test-algorithms.R ← 03c
│   ├── test-complex-shapes.R ← 03d
│   ├── test-bivariate-shapes.R ← 03m
│   ├── test-threshold-shapes.R ← 03n
│   ├── test-uncertainty.R ← 03e
│   ├── test-horizons.R ← 03g, 03h
│   ├── test-weathering.R ← 03i
│   ├── test-networks.R ← 03j
│   ├── test-temporal-spatial.R ← 03k
│   ├── test-case-studies.R ← 03l
│   └── ...
│
│
└── Cargo.toml (minimal changes)
```

---

## Next Steps for Implementation Team

### **Immediate (Today)**
1. ✅ Review all 12 prompt files (03a-03l)
2. ✅ Clarify priority sequence with team lead
3. ✅ Identify potential parallelization (fast track recommended)
4. ✅ Assign engineers to tracks (suggest: 1 optimization, 1 analysis, 1 integration)

### **Week 1 Kickoff**
1. Create placeholder `.rs` and `.R` files for new modules
2. Set up test file stubs (one per prompt)
3. Begin 03a (argmin integration) — critical path
4. Begin 03g (Mahalanobis) — can parallelize
5. Daily standup on integration points

### **Ongoing**
1. All prompts include exit criteria; use as definition of done
2. Maintain Phase 2 test regression (250/250 passing)
3. Integrate early and often (avoid end-of-phase surprises)
4. Iterate on case studies (03l) based on learnings from 03a-3k

---

## Key Resources

- **Argmin Documentation**: https://docs.rs/argmin/latest/argmin/
- **Nalgebra Docs**: https://docs.rs/nalgebra/latest/nalgebra/
- **igraph R Package**: https://r.igraph.org/
- **gstat (kriging)**: https://r-spatial.org/pkg/gstat.html
- **Published Soil Databases**: KSSL (USDA), SoilGrids, GlobalSoilMap

---

## Questions / Clarifications

As you implement, document any:
- Ambiguities in prompt requirements
- Unexpected technical challenges
- Opportunities for simplification/enhancement
- Integration issues between prompts
- Performance/scalability concerns

These will inform **Phase 4 refinements and 04a (Predictive Modeling)**.

---

**Last Updated:** [Date Completed]  
**Status:** All Phase 3 Prompts Created ✅ (14 total: 03a-03f, 03m-03n for D2-D3, 03g-03l)  
**Ready for:** Team implementation + feedback iteration
