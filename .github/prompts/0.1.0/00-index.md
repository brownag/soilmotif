# soilmotif 0.1.0 Development Prompts - Master Index

**Version**: 1.0
**Date**: October 2025
**Status**: Ready for sequential agent implementation

Complete navigation and coordination guide for all soilmotif development phases.

## Quick Navigation by Phase

### Phase 1: R Core Foundation
- **Overview**: [01-Phase-1-R-Core/01-phase-1.md](01-Phase-1-R-Core/01-phase-1.md)
- **1A Shape Functions**: [01-Phase-1-R-Core/01a-shape-functions.md](01-Phase-1-R-Core/01a-shape-functions.md)
- **1B Optimization**: [01-Phase-1-R-Core/01b-optimization-framework.md](01-Phase-1-R-Core/01b-optimization-framework.md)
- **1C Model Selection**: [01-Phase-1-R-Core/01c-model-selection.md](01-Phase-1-R-Core/01c-model-selection.md)
- **1D Preprocessing**: [01-Phase-1-R-Core/01d-data-preprocessing.md](01-Phase-1-R-Core/01d-data-preprocessing.md)
- **1E Testing**: [01-Phase-1-R-Core/01e-testing-documentation.md](01-Phase-1-R-Core/01e-testing-documentation.md)
- **Status**: [01-Phase-1-R-Core/PHASE_STATUS.md](01-Phase-1-R-Core/PHASE_STATUS.md)

### Phase 2: Rust Backend Foundation
- **Overview**: [02-Phase-2-Rust-Foundation/02-phase-2.md](02-Phase-2-Rust-Foundation/02-phase-2.md)
- **2A Project Setup**: [02-Phase-2-Rust-Foundation/02a-project-setup.md](02-Phase-2-Rust-Foundation/02a-project-setup.md)
- **2B Core Functions**: [02-Phase-2-Rust-Foundation/02b-core-functions.md](02-Phase-2-Rust-Foundation/02b-core-functions.md)
- **2C Single Profile**: [02-Phase-2-Rust-Foundation/02c-single-profile.md](02-Phase-2-Rust-Foundation/02c-single-profile.md)
- **2D Batch Processing**: [02-Phase-2-Rust-Foundation/02d-batch-processing.md](02-Phase-2-Rust-Foundation/02d-batch-processing.md)
- **2E R Integration**: [02-Phase-2-Rust-Foundation/02e-r-integration.md](02-Phase-2-Rust-Foundation/02e-r-integration.md)
- **Status**: [02-Phase-2-Rust-Foundation/PHASE_STATUS.md](02-Phase-2-Rust-Foundation/PHASE_STATUS.md)

### Phase 3: Advanced Analysis
- **Overview**: [03-Phase-3-Advanced-Analysis/03-phase-3.md](03-Phase-3-Advanced-Analysis/03-phase-3.md)
- **3A Argmin Integration**: [03-Phase-3-Advanced-Analysis/03a-argmin-integration.md](03-Phase-3-Advanced-Analysis/03a-argmin-integration.md)
- **3B Domain Objectives**: [03-Phase-3-Advanced-Analysis/03b-domain-objectives.md](03-Phase-3-Advanced-Analysis/03b-domain-objectives.md)
- **3C Algorithms**: [03-Phase-3-Advanced-Analysis/03c-algorithms.md](03-Phase-3-Advanced-Analysis/03c-algorithms.md)
- **3D Complex Shapes**: [03-Phase-3-Advanced-Analysis/03d-complex-shapes.md](03-Phase-3-Advanced-Analysis/03d-complex-shapes.md)
- **3E Uncertainty**: [03-Phase-3-Advanced-Analysis/03e-bootstrap.md](03-Phase-3-Advanced-Analysis/03e-bootstrap.md) (see `/docs/feature-guides/bootstrap-uncertainty.md` for user guide)
- **3F R Integration**: [03-Phase-3-Advanced-Analysis/03f-r-integration.md](03-Phase-3-Advanced-Analysis/03f-r-integration.md)
- **3G Horizons Mahalanobis**: [03-Phase-3-Advanced-Analysis/03g-horizons-mahalanobis.md](03-Phase-3-Advanced-Analysis/03g-horizons-mahalanobis.md)
- **3H Horizons Fuzzy**: [03-Phase-3-Advanced-Analysis/03h-horizons-fuzzy.md](03-Phase-3-Advanced-Analysis/03h-horizons-fuzzy.md)
- **3I Weathering Indices**: [03-Phase-3-Advanced-Analysis/03i-weathering-indices.md](03-Phase-3-Advanced-Analysis/03i-weathering-indices.md)
- **3J Networks**: [03-Phase-3-Advanced-Analysis/03j-correlation-networks.md](03-Phase-3-Advanced-Analysis/03j-correlation-networks.md)
- **3K Temporal/Spatial**: [03-Phase-3-Advanced-Analysis/03k-temporal-spatial.md](03-Phase-3-Advanced-Analysis/03k-temporal-spatial.md)
- **3L Case Studies**: [03-Phase-3-Advanced-Analysis/03l-case-studies.md](03-Phase-3-Advanced-Analysis/03l-case-studies.md)
- **Status**: [03-Phase-3-Advanced-Analysis/README.md](03-Phase-3-Advanced-Analysis/README.md)

### Phase 4: Interpolation Methods
- **Overview**: [04-Phase-4-Interpolation/04a-boundary-distinctness-interpolation.md](04-Phase-4-Interpolation/04a-boundary-distinctness-interpolation.md)
- **Quick Ref**: [04-Phase-4-Interpolation/04a-distinctness-quick-reference.md](04-Phase-4-Interpolation/04a-distinctness-quick-reference.md)

### Phase 5: Polish & Release
- **Overview**: [05-Phase-5-Polish-Release/04-phase-4.md](05-Phase-5-Polish-Release/04-phase-4.md)

## How to Use This Structure

### For AI Agents
1. Start with this file (you are here)
2. Read the phase overview for your assignment
3. Read the specific subphase action prompt
4. Implement according to specifications
5. Update PHASE_STATUS.md in your phase folder
6. Hand off to next agent/phase

### For Managers/Coordinators
1. Check each phase's PHASE_STATUS.md for progress
2. Refer to overview documents for dependency information
3. Use action prompts to brief agents on specific tasks

## Document Types

- **Master Guides** (00-*): High-level roadmap and principles
- **Phase Overviews** (*-phase-*.md): Phase-level coordination and dependencies
- **Action Prompts** (*a-*h, *i, etc): Detailed implementation specifications
- **Status Trackers** (PHASE_STATUS.md): Progress checklists and handoff notes
- **Examples** (example files): Working code samples

## Key Information Quick Reference

### The Seven Shape Types

| Type | Pedogenic Process | Use When |
|------|-------------------|----------|
| Uniform | No development | Flat profiles |
| Gradational | Steady accumulation | Linear trends |
| Exponential | Surface-driven (OM, roots) | Organic matter, roots |
| Sigmoid | Reaction fronts | Wetting fronts, translocation |
| Abrupt | Lithologic change | Hard boundaries |
| Peak | Accumulation zone | Argillic Bt, spodic Bh |
| MiniMax | Multi-process | Two competing processes |

### Phase Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| 1: R Core | 3 weeks | COMPLETE |
| 2: Rust Backend | 3 weeks | COMPLETE |
| 3: Advanced Analysis | 2 weeks | IN PROGRESS |
| 4: Interpolation | 1 week | PENDING |
| 5: Polish & Release | 1 week | PENDING |

### Design Principles

1. **Naming**: sm_* (exported), . (internal)
2. **Depth Axis**: 1-200 cm default
3. **Scaling**: [0,1] internal, scaled to data range
4. **Optimization**: R's optim() or argmin-backed
5. **Optional Dependencies**: Guarded by requireNamespace()

## Related Resources

### Technical Documentation
See `/docs/` for:
- Build artifacts and FFI integration
- Implementation guides (naming, parameters, examples)
- Feature guides (bootstrap, horizons, broom)
- Troubleshooting (FFI debugging, etc.)
- Quick references by topic

### Archive
See `/archived/` for:
- Session summaries and notes
- Completed phase documentation
- Historical lessons and decisions

### Agent Instructions
See `/agent-instructions.md` for:
- Critical rules (no Unicode, no commits, no pushes)
- Architecture overview
- Common commands
- Phase 3 preparation checklist

---

**Ready to begin?** Pick your phase above and start reading!

---

**Document Version**: 1.0
**Last Updated**: October 2025
**Next Review**: After Phase 1 completion
