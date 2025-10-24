# Development Prompts

This directory contains sequential implementation guides and specifications for the soilmotif package development roadmap.

## Quick Start

- **New agent?** Start with [`0.1.0/00-index.md`](0.1.0/00-index.md)
- **Continuing work?** Check progress in `0.1.0/XX-Phase-N/PHASE_STATUS.md`
- **Need agent instructions?** See `..agent-instructions.md`

## Structure

Each version (currently 0.1.0) contains:

- **00-start-here.md** - Master implementation guide (read first)
- **00-index.md** - Complete navigation index
- **01-Phase-1-R-Core/** - R foundation tasks (phases 1.A - 1.E)
- **02-Phase-2-Rust-Foundation/** - Rust backend tasks (phases 2.A - 2.E)
- **03-Phase-3-Advanced-Analysis/** - Advanced features (phases 3.A - 3.L)
- **04-Phase-4-Interpolation/** - Interpolation methods
- **05-Phase-5-Polish-Release/** - Release preparation

## How to Use

1. **Pick your phase** from the index
2. **Read the phase overview** document
3. **Read the specific subphase action prompt**
4. **Implement** according to specifications
5. **Update PHASE_STATUS.md** in your phase folder
6. **Hand off** to next phase/agent

## Versions

Currently only 0.1.0 is active. Future versions (0.2.0, etc.) will have their own directories with updated prompts for new phases of development.

## Related Resources

- **Agent Instructions**: `../agent-instructions.md`
- **Technical Documentation**: `../docs/`
- **Archive**: `../archived/`

---

For detailed navigation, see `0.1.0/00-index.md`
