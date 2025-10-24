# .github Directory Organization

This directory contains AI agent instructions, developer documentation, and implementation prompts for the soilmotif package.

## Quick Navigation

- **[agent-instructions.md](agent-instructions.md)** - Start here if you're an AI agent
- **[docs/](docs/)** - Developer reference documentation
- **[prompts/](prompts/)** - Sequential implementation guides for agents
- **[archived/](archived/)** - Historical documentation and session summaries
- **[working/](working/)** - Temporary workspace (gitignored)

## For AI Agents

1. Read [agent-instructions.md](agent-instructions.md) first
2. Check [prompts/0.1.0/](prompts/0.1.0/) for implementation tasks
3. Use [docs/](docs/) for technical reference
4. Create temporary files in [working/](working/) (not committed)

## For Developers

- Technical guides: [docs/](docs/)
- Quick references: [docs/quick-references/](docs/quick-references/)
- Implementation history: [archived/](archived/)

## Directory Purpose

| Directory | Purpose | Committed? |
|-----------|---------|------------|
| `docs/` | Persistent technical documentation | Yes |
| `prompts/` | Version-specific agent instructions | Yes |
| `archived/` | Historical/completed work | Yes |
| `working/` | Temporary agent workspace | No (gitignored) |

## Document Organization

### docs/ - Developer Reference (Persistent)

- **build-and-deployment/** - Build artifacts, FFI integration
- **implementation-guides/** - Naming conventions, parameter analysis, code examples
- **feature-guides/** - Bootstrap, horizons, broom integration
- **troubleshooting/** - FFI debugging, error resolution
- **quick-references/** - Quick lookup guides by phase/topic

### prompts/ - Agent Instructions (Version-Specific)

Organized by version (currently 0.1.0) and then by sequential phases:
- Phase 1: R Core Foundation
- Phase 2: Rust Backend
- Phase 3: Advanced Analysis
- Phase 4: Interpolation Methods
- Phase 5: Polish & Release

### archived/ - Historical Records

Contains completed phase documentation and session summaries with dates.
Provides historical context and lessons learned.

### working/ - Temporary Workspace

For AI agents creating temporary documents during sessions.
Entire directory is gitignored and Rbuildignored.
