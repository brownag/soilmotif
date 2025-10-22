# Makefile for soilmotif R package development
#
# This Makefile contains common development workflows for the soilmotif R package.
# It is ignored by .Rbuildignore and should not be included in package builds.

.PHONY: help install test check docs clean all

# Default target
help:
	@echo "Available targets:"
	@echo "  all          - Full development cycle (docs + test + check)"
	@echo "  install      - Install package"
	@echo "  test         - Run test suite"
	@echo "  check        - Run R CMD check"
	@echo "  build        - Run R CMD build"
	@echo "  docs         - Generate documentation with roxygen2"
	@echo "  clean        - Clean build artifacts"
	@echo "  help         - Show this help"

# Full development cycle
all: clean docs test check
	@echo "Full development cycle completed!"

# Install dependencies
install:
	@echo "Installing package and dependencies..."
	R -e "if (!requireNamespace('remotes')) install.packages('remotes'); remotes::install_local()"

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
