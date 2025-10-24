# SoilMotif Documentation Index

Comprehensive guide to soilmotif repository documentation structure. This index helps navigate the various `.md` files across the `.github` folder and `.github/prompts` subfolders.

## 🎯 Start Here

**For first-time contributors**: Read `copilot-instructions.md` first  
**For users**: Read `SIEVE-BOOTSTRAP-QUICK-REFERENCE.md` for latest features  
**For AI agents**: This index + `copilot-instructions.md`

---

## Core Guidance Documents (`.github/` root)

These are the primary guidance documents for working on soilmotif.

### 📋 `copilot-instructions.md`

**Purpose**: Comprehensive guide for AI coding agents working on soilmotif  
**Status**: ✅ Active & Maintained  
**Last Updated**: October 23, 2025  
**Covers**:
- Purpose and current status of project
- Critical rules (Unicode, git, ambiguity handling)
- Architecture overview (R layer, Rust layer, FFI)
- Quick setup & common commands
- Repository layout and file responsibilities
- Key concepts and conventions
- Optimization strategy
- Data handling
- Phase 3 integration points
- Testing and documentation workflow
- Example workflows
- **NEW**: FFI type conversion patterns
- **NEW**: Sieve bootstrap documentation
- When you're uncertain (decision-making framework)

**Use When**:
- Starting new work on soilmotif
- Need to understand architecture
- Implementing new Rust or R features
- Questions about development process

---

## Technical Deep Dives (`.github/` root)

Reference documents for specific technical issues and solutions.

### 🐛 `PHASE-3E-FFI-DEBUGGING-GUIDE.md`

**Purpose**: Comprehensive debugging guide for Rust FFI type conversions  
**Status**: ✅ Complete (Created Oct 23, 2025)  
**Covers**:
- The AR(1) coefficient bug (what happened, why, how fixed)
- FFI type conversion patterns
  - Option<f64> → Robj
  - Option<Vec<T>> → R list
  - Option<String> → Robj
- Prevention checklist for future FFI work
- Debugging strategy and tools
- Test coverage patterns
- Related FFI conversions
- Documentation implications

**Critical Content**:
- **Problem**: Option<T> passed directly to extendr `list!()` macro loses data
- **Solution**: Explicit match with `Robj::from()` conversion
- **Lesson**: Just because Rust computation succeeds doesn't mean data reaches R

**Use When**:
- Adding new FFI functions that return Option<T>
- Debugging data loss during FFI marshalling
- Writing tests for FFI type conversion
- Maintaining extendr integration

---

### 📊 `SIEVE-BOOTSTRAP-QUICK-REFERENCE.md`

**Purpose**: User-facing quick reference for bootstrap functionality  
**Status**: ✅ Complete & Tested  
**Last Updated**: October 22, 2025  
**Covers**:
- What is sieve bootstrap?
- Quick start (3-line example)
- Method comparison table (parametric vs sieve)
- Function signature with all parameters
- Common use cases (4 detailed examples)
- Understanding the output
- AR(1) model interpretation
- Fallback behavior
- Performance notes
- Threshold customization
- Troubleshooting
- Related functions
- References & further reading

**Use When**:
- Learning how to use sm_optim_bootstrap()
- Choosing between parametric and sieve methods
- Interpreting AR(1) coefficients
- Debugging bootstrap issues
- Building examples

---

### ✅ `PHASE-3E-COMPLETION-FINAL.md`

**Purpose**: Summary of Phase 3-03e (Uncertainty Quantification) completion  
**Status**: ✅ Complete (Created Oct 23, 2025)  
**Covers**:
- Executive summary
- What works (parametric, sieve, auto-selection, integration)
- What was fixed (AR(1) FFI bug with full investigation narrative)
- Architecture overview
- Key implementation details
- Documentation changes
- Test results (380/381 passing)
- Lessons learned (5 key takeaways)
- Known issues (seed isolation, performance)
- Completeness checklist
- Phase 4 roadmap

**Use When**:
- Reviewing what's complete in Phase 3-03e
- Understanding the AR(1) bug investigation process
- Learning lessons from this phase
- Planning Phase 4 work

---

## Other Reference Documents (`.github/` root)

Supplementary reference materials (mostly complete or archived).

### 📝 `03E-DOCUMENTATION-INDEX.md`
Index of 03e-specific documentation  
Status: Reference (superseded by this document)

### 📝 `03E-REMAINING-ITEMS-SUMMARY.md`
Summary of items still needed in Phase 3-03e  
Status: Reference (most items now complete)

### 📝 `PHASE-3E-COMPLETION-STATUS.md`
Earlier status update for Phase 3-03e  
Status: Reference (see PHASE-3E-COMPLETION-FINAL.md for latest)

### 📝 `SCALING-BUGS-FIXED.md`
Documentation of scaling-related bugs encountered  
Status: Reference

### 📝 `VIGNETTE-FIXES-SUMMARY.md`
Summary of vignette-related fixes  
Status: Reference (improvements made in Oct 23)

### 📝 `VIGNETTE-INVESTIGATION-REPORT.md`
Detailed investigation of vignette issues  
Status: Reference

---

## Phase-Specific Documentation (`.github/prompts/0.1.0/`)

Organized by development phase. These directories contain detailed roadmaps and implementation guides.

### 📂 `01-Phase-1-R-Core/`
Phase 1 R core functionality (DO NOT ALTER)

### 📂 `02-Phase-2-Rust-Foundation/`
Phase 2 Rust backend (DO NOT ALTER)

### 📂 `03-Phase-3-Advanced-Analysis/`
Phase 3 advanced features (DO NOT ALTER)  
Contains: 03a through 03l detailed implementation guides

### 📂 `04-Phase-4-Polish-Release/`
Phase 4 polish & release (DO NOT ALTER)

### 📝 `00-COMPLETION-SUMMARY.md`
Overview of all phases

### 📝 `INDEX.md`
Master index for Phase-based organization

### 📝 `README.md`
README for the prompts folder

### 📝 `QUICK_REFERENCE.md`
Quick reference guide (legacy)

### 📝 `PHASE-1-QUICK-REFERENCE.md`
Phase 1 quick reference

### 📝 `PHASE-1-REVIEW-SUMMARY.md`
Phase 1 review summary

---

## Top-Level Prompts Folder (`.github/prompts/`)

Transition documentation between phases.

### 📝 `PHASE-2-VALIDATION-SUMMARY.md`
Phase 2 validation status

### 📝 `SESSION-SUMMARY-PHASE-2-POLISH.md`
Session summary for Phase 2 polish work

### 📝 `SIEVE-BOOTSTRAP-IMPLEMENTATION-COMPLETE.md`
Sieve bootstrap implementation summary

### 📝 `SIEVE-BOOTSTRAP-IMPLEMENTATION-ROADMAP.md`
Sieve bootstrap implementation roadmap

### 📝 `TEST-FIX-SUMMARY-R-VS-RUST-DIVERGENCE.md`
Summary of test fixes for R vs Rust divergence

---

## Reading Guide by Role

### 👨‍💻 For AI Code Agents

1. **First Time**: Read `copilot-instructions.md` completely
2. **Before FFI Work**: Read `PHASE-3E-FFI-DEBUGGING-GUIDE.md`
3. **Before Editing Vignettes**: Check `PHASE-3E-COMPLETION-FINAL.md` for current status
4. **Complex Decisions**: Review `When You're Uncertain` section in copilot-instructions.md

### 👤 For Users/Package Users

1. **Getting Started**: `SIEVE-BOOTSTRAP-QUICK-REFERENCE.md`
2. **Examples**: Examples in vignette: `vignettes/fitting-motifs.Rmd`
3. **Help**: Function help: `?sm_optim_bootstrap`
4. **Learning**: Read quick start then common use cases in quick reference

### 👨‍🔬 For Researchers/Developers

1. **Architecture**: `copilot-instructions.md` architecture section
2. **Phase Planning**: Appropriate phase directory in `.github/prompts/0.1.0/`
3. **Technical Details**: `PHASE-3E-FFI-DEBUGGING-GUIDE.md` for systems understanding
4. **Integration Points**: `copilot-instructions.md` integration section

### 🧪 For QA/Testing

1. **Test Strategy**: `copilot-instructions.md` testing section
2. **Known Issues**: `PHASE-3E-COMPLETION-FINAL.md` known issues section
3. **Vignette Validation**: `PHASE-3E-COMPLETION-FINAL.md` vignette validation
4. **Specific Features**: Test files in `tests/testthat/`

---

## Key Concepts Navigation

### Bootstrap Methods

**Parametric Bootstrap**
- Quick ref: `SIEVE-BOOTSTRAP-QUICK-REFERENCE.md` method comparison table
- Implementation: `R/uncertainty.R`, `src/uncertainty.rs`
- Tests: `tests/testthat/test-uncertainty.R`

**Sieve Bootstrap**
- Quick ref: `SIEVE-BOOTSTRAP-QUICK-REFERENCE.md` (entire document)
- Deep dive: `PHASE-3E-FFI-DEBUGGING-GUIDE.md` AR(1) section
- Implementation: `src/uncertainty.rs` sieve functions
- FFI: `src/lib.rs` bootstrap_engine_rust()

**AR(1) Model**
- Explanation: `SIEVE-BOOTSTRAP-QUICK-REFERENCE.md` AR(1) interpretation
- Algorithm: `src/uncertainty.rs` fit_ar1_model()
- FFI Issue: `PHASE-3E-FFI-DEBUGGING-GUIDE.md` critical issue section
- Fix: `PHASE-3E-COMPLETION-FINAL.md` what was fixed section

### FFI & Type Conversions

- Core guidance: `copilot-instructions.md` FFI type conversions section
- Detailed guide: `PHASE-3E-FFI-DEBUGGING-GUIDE.md` (comprehensive)
- Applied example: `PHASE-3E-COMPLETION-FINAL.md` what was fixed
- Prevention: `PHASE-3E-FFI-DEBUGGING-GUIDE.md` prevention checklist

### Architecture

- Overview: `copilot-instructions.md` architecture section
- Current state: `PHASE-3E-COMPLETION-FINAL.md` architecture overview
- R-Rust integration: `copilot-instructions.md` repository layout
- FFI layer: `copilot-instructions.md` FFI type conversions

---

## Decision Tree: Which Doc To Read

```
Q: "How do I start contributing to soilmotif?"
A: → copilot-instructions.md

Q: "How do I use sm_optim_bootstrap()?"
A: → SIEVE-BOOTSTRAP-QUICK-REFERENCE.md

Q: "I'm getting NA for ar1_coef in my code"
A: → PHASE-3E-FFI-DEBUGGING-GUIDE.md (FFI type conversions)

Q: "What's complete in Phase 3-03e?"
A: → PHASE-3E-COMPLETION-FINAL.md

Q: "How do I convert Option<f64> in Rust FFI?"
A: → PHASE-3E-FFI-DEBUGGING-GUIDE.md

Q: "What tests do I need for my FFI function?"
A: → PHASE-3E-FFI-DEBUGGING-GUIDE.md (test coverage patterns)

Q: "Should I fall back to parametric when sieve fails?"
A: → SIEVE-BOOTSTRAP-QUICK-REFERENCE.md (fallback behavior)

Q: "What did I miss about the AR(1) bug?"
A: → PHASE-3E-COMPLETION-FINAL.md (investigation narrative)

Q: "What's the architecture of soilmotif?"
A: → copilot-instructions.md (architecture section)

Q: "What should I know before editing vignettes?"
A: → PHASE-3E-COMPLETION-FINAL.md (vignette validation)
```

---

## Document Maintenance Guidelines

### Guidelines for This Index

- Update when new `.md` files are created in `.github/`
- Keep "Start Here" section current
- Maintain "Decision Tree" when docs change focus
- Archive documents (mark as "Reference") when superseded

### Guidelines for Other Docs

- Link to this index when creating new docs
- Use consistent heading levels (## for sections, ### for subsections)
- Include "Last Updated" date
- Mark deprecated sections clearly
- Link to related docs in "References" section

### Archive Policy

- Documents > 6 months old and superseded → Move to `archived/`
- Investigation reports → Keep for historical context, mark as reference
- Implementation guides → Update or mark as Phase-specific

---

## Quick Links

| Need | Location | Status |
|------|----------|--------|
| Get started | `copilot-instructions.md` | ✅ Active |
| FFI debugging | `PHASE-3E-FFI-DEBUGGING-GUIDE.md` | ✅ Active |
| Bootstrap info | `SIEVE-BOOTSTRAP-QUICK-REFERENCE.md` | ✅ Active |
| Phase 3 status | `PHASE-3E-COMPLETION-FINAL.md` | ✅ Active |
| Phase roadmaps | `.github/prompts/0.1.0/` | ✅ Stable |
| User examples | `vignettes/fitting-motifs.Rmd` | ✅ Working |
| Tests | `tests/testthat/` | ✅ 380/381 passing |

---

**Last Updated**: October 23, 2025  
**Maintained By**: AI Assistant with human oversight  
**Status**: ✅ Current & Complete

