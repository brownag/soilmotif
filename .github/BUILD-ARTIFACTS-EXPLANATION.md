# Build Artifacts Explanation

## Overview

The soilmotif package uses a Rust backend compiled via extendr for R integration. This document explains how the build artifacts (`.so` and `.a` files) are generated and ensured to be up-to-date.

## Build Process Flow

### 1. Configure Script (`configure`)

When you run `R CMD INSTALL .`, R executes the `configure` script first:

```bash
# Location: /soilmotif/configure
# Responsibilities:
# 1. Check for cargo (Rust compiler)
# 2. Clean previous build artifacts from src/ directory
# 3. Run: cargo build --release --target-dir target
# 4. Copy: target/release/libsoilmotif.a -> src/libsoilmotif_rust.a
# 5. Verify the copied file is recent (not stale)
```

**Key improvements in the configure script:**
- Removes stale `.a` files before building to prevent old binaries being linked
- Cleans cargo cache on first build to ensure fresh compilation
- Verifies the copied library file is recent (modified within last 1 minute)
- Provides verbose error messages if build fails

### 2. Makevars (`src/Makevars`)

The `Makevars` file tells R how to compile and link the package:

```makefile
SOURCES = entrypoint.c
OBJECTS = entrypoint.o
PKG_LIBS = libsoilmotif_rust.a
```

This configuration:
- Links against the Rust static library (`libsoilmotif_rust.a`) prepared by the configure script
- Compiles a minimal C entrypoint that calls the Rust code
- The resulting shared object (`soilmotif.so`) is what R loads at runtime

### 3. Build Artifacts

Two key files are generated and need to stay synchronized:

| File | Location | Purpose | Created By |
|------|----------|---------|------------|
| `libsoilmotif_rust.a` | `src/libsoilmotif_rust.a` | Static library from Rust code | `configure` script (via cargo) |
| `soilmotif.so` | `libs/soilmotif.so` (after install) | Shared library loaded by R | `R CMD INSTALL` (via Makevars) |

## Ensuring Fresh Builds

### Problem: Stale `.so` and `.a` Files

If you were experiencing stale build artifacts, it was likely due to:

1. **Old Rust library not being cleaned** - The `src/libsoilmotif_rust.a` was copied once but not updated on subsequent builds
2. **Cargo incremental compilation** - Cargo might not recompile Rust code if timestamps indicate no changes
3. **Makevars linking old static library** - R would link against whatever `.a` file existed, even if it was outdated

### Solution: Improved Configure Script

The updated `configure` script now:

```bash
# 1. Clean previous artifacts
rm -f src/libsoilmotif_rust.a

# 2. Force rebuild on first install
if [ ! -d target/release ]; then
    cargo clean  # Force full rebuild
fi

# 3. Build with cargo
cargo build --release --target-dir target

# 4. Verify and copy
cp -f target/release/libsoilmotif.a src/libsoilmotif_rust.a

# 5. Check freshness
LIB_AGE=$(find src/libsoilmotif_rust.a -mmin -1 | wc -l)
if [ "$LIB_AGE" -eq 0 ]; then
    echo "Warning: Copied library may be stale"
fi
```

## When .so and .a Files Get Updated

| Operation | Updates Files? | Details |
|-----------|-----------------|---------|
| `cargo build --release` | Updates `target/release/libsoilmotif.a` only | Rust build output in cargo directory |
| `R CMD INSTALL .` | **YES**, both files | Runs configure (copies `.a` to `src/`), then R compile (creates `.so` in `libs/`) |
| `rextendr::document()` | **YES**, both files | Calls `R CMD INSTALL` internally |
| `cargo clean` | No (clears cache) | Forces rebuild next time |

## Workflow: Fresh Install

```bash
# Always results in fresh build artifacts:
R CMD INSTALL --no-byte-compile .
```

This command:
1. ✅ Runs `configure` script
   - Cleans `src/libsoilmotif_rust.a`
   - Runs `cargo build --release`
   - Copies fresh `libsoilmotif.a` to `src/libsoilmotif_rust.a`
2. ✅ Compiles with Makevars
   - Links against fresh `src/libsoilmotif_rust.a`
   - Creates fresh `soilmotif.so` in installed library

## Troubleshooting

### Symptom: Changes to Rust code not reflecting in package

**Solution:**
```bash
# Force full rebuild
cargo clean
R CMD INSTALL --no-byte-compile .
```

### Symptom: Build fails with "Rust library not found"

**Check:**
1. Is Rust installed? `cargo --version`
2. Does `target/release/libsoilmotif.a` exist after running `cargo build --release`?
3. Check `configure` script output for errors

**Solution:**
```bash
# Manual rebuild
cargo build --release
R CMD INSTALL --no-byte-compile .
```

### Symptom: .so file is old but .a file is new

**This should not happen** with the improved configure script, as it verifies freshness. If it does:

```bash
# Clean and reinstall
rm -f src/libsoilmotif_rust.a
R CMD INSTALL --no-byte-compile .
```

## FFI Function Registration

After adding new `#[extendr]` functions in Rust:

1. **Update `src/lib.rs`:**
   - Add function with `#[extendr]` attribute
   - Register in `extendr_module!` block

2. **Generate R wrappers:**
   ```bash
   R --vanilla -q -e "rextendr::document()"
   ```

3. **Manually add to `R/extendr-wrappers.R`** if auto-generation doesn't pick them up:
   ```r
   my_function_rust <- function(arg1, arg2) .Call(wrap__my_function_rust, arg1, arg2)
   ```

4. **Reinstall:**
   ```bash
   R CMD INSTALL --no-byte-compile .
   ```

## Environment Variables

No special environment variables are required. The build process automatically:
- Detects Rust toolchain
- Uses default release profile (optimized)
- Links against system libraries as needed

## Performance Notes

- **First build**: ~15-30 seconds (compiles all Rust dependencies)
- **Incremental builds**: ~1-2 seconds (only changed files recompiled)
- **After `cargo clean`**: ~15-30 seconds (rebuilds everything)

The `--release` profile ensures optimized performance for the installed package.
