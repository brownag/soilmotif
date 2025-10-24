# soilmotif Installation Guide

## Overview

The `soilmotif` package includes a high-performance Rust backend for optimization and batch processing. This backend is optional but strongly recommended for production use.

## Requirements

### Required
- **R** >= 4.1.0
- **C compiler** (included with Rtools on Windows, Xcode Command Line Tools on macOS, build-essential on Linux)

### Required for Rust Backend (Recommended)
- **Rust toolchain** (Cargo >= 1.56)
  - Install from: https://www.rust-lang.org/tools/install

### Required Linear Algebra Library
- **OpenBLAS** (required for linear algebra operations)
  - Automatically detected and used from system, OR
  - Automatically compiled statically if not found system-wide
  - Optional to pre-install (but recommended for faster builds):
    - Ubuntu/Debian: `sudo apt-get install libopenblas-dev`
    - macOS: `brew install openblas`
    - Windows: Bundled in Rtools (preferred)

## Installation

### From GitHub (Development Version)

```r
# Install required package for GitHub installation
install.packages("remotes")

# Install soilmotif with Rust backend
remotes::install_github("brownag/soilmotif")
```

### Troubleshooting

#### "cargo not found" Warning

If you see a warning that `cargo` is not found during installation:

1. **Install Rust** from https://www.rust-lang.org/tools/install
2. **Verify installation**:
   ```bash
   rustc --version
   cargo --version
   ```
3. **Reinstall the package**:
   ```r
   remotes::install_github("brownag/soilmotif", force = TRUE)
   ```

#### Windows-Specific Issues

If building fails on Windows:

1. Ensure **Rtools** is installed (https://cran.r-project.org/bin/windows/Rtools/)
2. Verify Rust is installed (run `rustup self update` in PowerShell or Command Prompt)
3. Try with static OpenBLAS:
   ```r
   Sys.setenv(SOILMOTIF_OPENBLAS_STATIC = "1")
   remotes::install_github("brownag/soilmotif", force = TRUE)
   ```

#### macOS-Specific Issues

If building fails on macOS:

1. Install **Xcode Command Line Tools**:
   ```bash
   xcode-select --install
   ```
2. Install **Rust**:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   ```

#### Linux-Specific Issues

If building fails on Linux:

1. Install **build tools**:
   ```bash
   sudo apt-get install build-essential cargo rustc
   ```
2. Optionally install **OpenBLAS** for faster builds:
   ```bash
   sudo apt-get install libopenblas-dev
   ```

## Checking Backend Availability

After installation, verify that the Rust backend is available:

```r
library(soilmotif)

# Check if Rust backend loaded successfully
if (sm_rust_backend_available()) {
  cat("Rust backend is available and working!\n")
} else {
  cat("Rust backend not available. R implementations will be used.\n")
}
```

## Building from Source (Development)

### Prerequisites
- **Rust**: https://www.rust-lang.org/tools/install
- **Development tools** (see platform-specific instructions above)

### Build Steps

```bash
# Clone repository
git clone https://github.com/brownag/soilmotif.git
cd soilmotif

# Install R dependencies
R -e "remotes::install_github('brownag/soilmotif')"

# Build and test
R CMD build .
R CMD check soilmotif_*.tar.gz --as-cran
```

## Environment Variables

The following environment variables can customize the build:

| Variable | Values | Default | Purpose |
|----------|--------|---------|---------|
| `SOILMOTIF_OPENBLAS_STATIC` | `0` or `1` | Auto-detect | Use static (1) or system (0) OpenBLAS; system preferred if available |
| `RUSTFLAGS` | Rust compiler flags | None | Additional Rust compilation flags |

### About OpenBLAS Linking

The build process automatically:
1. **Checks for system OpenBLAS** using `pkg-config`
2. **Uses system version if found** (faster compilation, system-managed updates)
3. **Statically compiles if not found** (more portable, self-contained)

You can override this with `SOILMOTIF_OPENBLAS_STATIC`:

```r
# Force static build (slower compilation, more portable)
Sys.setenv(SOILMOTIF_OPENBLAS_STATIC = "1")
remotes::install_github("brownag/soilmotif")

# Force system OpenBLAS (faster compilation, system dependency)
Sys.setenv(SOILMOTIF_OPENBLAS_STATIC = "0")
remotes::install_github("brownag/soilmotif")
```

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Linux** (x86_64) | ✅ Fully Supported | GCC 7+ recommended |
| **macOS** (Intel) | ✅ Fully Supported | Xcode Command Line Tools required |
| **macOS** (ARM64/M1+) | ✅ Fully Supported | Native ARM64 Rust toolchain recommended |
| **Windows** (x86_64) | ✅ Fully Supported | Rtools and Rust required |
| **Windows** (i386) | ⚠️ Not Tested | May require additional configuration |

## Performance Notes

- **With Rust backend**: 5-10x faster optimization and batch processing
- **Without Rust backend**: R implementations provide equivalent results, slower performance
- **OpenBLAS tuning**: System OpenBLAS may provide additional 20-30% speedup on compatible systems

## Getting Help

- **Installation issues**: File an issue at https://github.com/brownag/soilmotif/issues
- **General questions**: See the package vignette: `vignette("fitting-motifs")`
- **Rust backend**: See `?sm_rust_backend_available()`

---

**Note**: The Rust backend is optional. The package includes complete R implementations of all functions. The Rust backend is primarily used for optimization and batch processing performance improvements.
