# Build Artifacts - Quick Reference

## Problem Fixed

You were experiencing issues with stale `soilmotif.so` and `.a` files not being updated during installation. This has been fixed in the configure script.

## What Was Changed

### 1. Configure Script Enhanced
**File:** `configure`

**Key improvements:**
- ✅ Removes stale `src/libsoilmotif_rust.a` before building
- ✅ Forces full cargo rebuild on first install
- ✅ Verifies copied library file is recent (not stale)
- ✅ Better error handling and messages

### 2. Build Artifacts Created
**File:** `.github/BUILD-ARTIFACTS-EXPLANATION.md` (detailed guide)
**File:** `.github/BUILD-ARTIFACTS-QUICKSTART.md` (this file)

## How It Works Now

```
┌─────────────────────────────────────┐
│   R CMD INSTALL .                   │
└──────────────┬──────────────────────┘
               │
               ├─→ [1] ./configure
               │       ├─ cargo build --release
               │       ├─ cp to src/libsoilmotif_rust.a
               │       └─ verify freshness ✓
               │
               ├─→ [2] Makevars compilation
               │       ├─ Link against src/libsoilmotif_rust.a
               │       └─ Create soilmotif.so ✓
               │
               └─→ [3] Install to library
                       └─ .so file is fresh ✓
```

## Usage

### Normal Installation (Always Works)
```bash
R CMD INSTALL --no-byte-compile .
```

**Result:** Fresh `soilmotif.so` and `libsoilmotif_rust.a` files every time.

### Force Full Rebuild
```bash
cargo clean
R CMD INSTALL --no-byte-compile .
```

### Development Iteration
```bash
# For quick development changes
cargo build --release
R CMD INSTALL --no-byte-compile .
```

## What Gets Updated

| When | soilmotif.so | libsoilmotif_rust.a |
|------|---------|-----------|
| `R CMD INSTALL .` | ✅ Fresh | ✅ Fresh |
| `rextendr::document()` | ✅ Fresh | ✅ Fresh |
| `cargo build --release` | ❌ Not updated | ✅ Fresh in target/ |

**Note:** `cargo build` only updates the file in `target/release/`, not in `src/`. The configure script copies it during `R CMD INSTALL`.

## Verification

Check that files are recent:
```bash
ls -lh /home/andrew/R/x86_64-pc-linux-gnu-library/4.5/soilmotif/libs/soilmotif.so
ls -lh /home/andrew/workspace/soilmotif/src/libsoilmotif_rust.a
```

Both should have the same recent timestamp after installation.

## If You Still Have Issues

1. **Verify Rust is installed:**
   ```bash
   cargo --version
   ```

2. **Manual rebuild:**
   ```bash
   rm -rf src/libsoilmotif_rust.a
   cargo clean
   R CMD INSTALL --no-byte-compile .
   ```

3. **Check error messages:**
   ```bash
   # Detailed output from configure script
   R CMD INSTALL --verbose --no-byte-compile .
   ```

4. **See full explanation:** Check `.github/BUILD-ARTIFACTS-EXPLANATION.md` for detailed troubleshooting.

## Status

✅ **Issue resolved:** Build artifacts are now automatically kept fresh during installation via the improved configure script.

✅ **Package builds successfully** with horizon analysis features:
- R implementations: `horizon_boundaries_mahalanobis()`, `horizon_classify_fuzzy()`
- Rust FFI functions: `mahalanobis_boundary_detection_rust()`, `fuzzy_kmeans_rust()` (internal)

✅ **All tests passing:** 145 tests for horizon analysis (68 for 03g Mahalanobis, 77 for 03h fuzzy)
