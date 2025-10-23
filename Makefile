# Makefile for soilmotif R package development
#
# This Makefile contains common development workflows for the soilmotif R package.
# It is ignored by .Rbuildignore and should not be included in package builds.

.PHONY: help install test check docs clean all ffi-document ffi-install ffi-test

# Default target
help:
	@echo "Available targets:"
	@echo ""
	@echo "Development Workflow:"
	@echo "  all          - Full development cycle (docs + test + check)"
	@echo "  install      - Install package with R CMD INSTALL"
	@echo "  test         - Run test suite"
	@echo "  check        - Run R CMD check"
	@echo "  build        - Run R CMD build"
	@echo "  docs         - Generate documentation with roxygen2"
	@echo "  clean        - Clean build artifacts"
	@echo ""
	@echo "FFI Development (Rust-R Integration):"
	@echo "  ffi-document - Regenerate R wrappers from Rust FFI (rextendr)"
	@echo "  ffi-install  - Full FFI build+install with verification"
	@echo "  ffi-test     - Verify all registered FFI functions are callable"
	@echo ""
	@echo "For FFI function additions, see: .github/FFI-ADDITION-CHECKLIST.md"
	@echo "For FFI issues, see: .github/RUST-R-FFI-DEBUGGING-GUIDE.md"
	@echo ""
	@echo "  help         - Show this help"

# Full development cycle
all: clean docs test check
	@echo "Full development cycle completed!"

# Install dependencies
install:
	@echo "Installing package and dependencies..."
	R -e "if (!requireNamespace('remotes')) install.packages('remotes'); remotes::install_local(force = TRUE)"

# Run tests
test:
	@echo "Running test suite..."
	R -e "if (!requireNamespace('devtools')) install.packages('devtools'); devtools::test()"

# Run fast check
check:
	@echo "Running fast R CMD check..."
	R CMD check --as-cran .

build:
	@echo "Building package tarball..."
	R CMD build .

# Generate documentation
docs:
	@echo "Generating documentation..."
	R -e "if (!requireNamespace('devtools')) install.packages('devtools'); devtools::check_man()"

# Clean artifacts
clean:
	@echo "Cleaning build artifacts..."
	R -e "if (!requireNamespace('devtools')) install.packages('devtools'); devtools::clean_dll()"
	cargo clean
	rm -rf *.tar.gz *.Rcheck

# FFI Development Targets

# Regenerate R FFI wrappers from Rust definitions using rextendr
ffi-document:
	@echo "Regenerating R FFI wrappers from Rust code..."
	@echo "This regenerates R/extendr-wrappers.R from src/lib.rs #[extendr] definitions"
	R -e "if (!requireNamespace('rextendr')) install.packages('rextendr'); rextendr::document()"
	@echo "✓ FFI wrappers regenerated"
	@echo "Next: Run 'make install' to build with updated wrappers"

# Full FFI build+install with verification
# This is the recommended target for FFI development
ffi-install: ffi-document
	@echo "Building and installing with FFI support..."
	@echo "Step 1: Regenerating documentation..."
	$(MAKE) docs
	@echo "Step 2: Running R CMD INSTALL..."
	R CMD INSTALL --no-byte-compile .
	@echo "Step 3: Running basic FFI verification..."
	$(MAKE) ffi-test
	@echo "FFI installation complete and verified"

# Test that all registered FFI functions are callable from R
ffi-test:
	@echo "Testing FFI function registration..."
	@echo "Checking that all registered Rust functions are callable from R..."
	R -e "library(soilmotif); \
	if (!rust_backend_available()) { \
		cat('FAILED: Rust backend not available\n'); \
		quit(status=1) \
	}; \
	cat('✓ Rust backend is available\n'); \
	funcs <- c('check_rust_backend', 'test_multi_param_rust', 'objective_rmse_rust', \
	           'objective_sse_rust', 'objective_mae_rust', 'objective_r2_rust', \
	           'objective_weighted_rmse_rust', 'objective_ordinal_rust', \
	           'objective_bounded_rust', 'objective_huber_rust', \
	           'objective_quantile_rust', 'recommend_optimizer_rust', \
	           'shape_eval_rust', 'optimize_profile_rust', \
	           'optimize_profile_rust_flexible', 'batch_optimize_profiles_rust', \
	           'bootstrap_engine_rust', 'mahalanobis_boundary_detection_rust', \
	           'fuzzy_kmeans_rust'); \
	missing <- funcs[!sapply(funcs, exists)]; \
	if (length(missing) > 0) { \
		cat('FAILED: Missing functions:', paste(missing, collapse=', '), '\n'); \
		quit(status=1) \
	}; \
	cat(' All', length(funcs), 'FFI functions are callable from R\n'); \
	cat(' FFI verification passed\n')"
	@echo "FFI test complete"
