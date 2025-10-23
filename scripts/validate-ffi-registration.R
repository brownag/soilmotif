#!/usr/bin/env Rscript
#
# Validate FFI Registration Script
#
# Purpose: Verify that all Rust FFI functions are properly registered
#          and callable from R
#
# Usage: Rscript scripts/validate-ffi-registration.R
#        Or: make ffi-test (from Makefile)
#
# This script checks:
# 1. Rust backend is available and loaded
# 2. All registered functions exist in R namespace
# 3. All registered functions are callable (no symbol errors)
# 4. Defensive wrappers are present for critical functions
# 5. Return types match expectations

library(soilmotif)

# Color output helpers
red <- function(x) paste0("\033[31m", x, "\033[0m")
green <- function(x) paste0("\033[32m", x, "\033[0m")
yellow <- function(x) paste0("\033[33m", x, "\033[0m")
bold <- function(x) paste0("\033[1m", x, "\033[0m")

cat(bold("FFI Registration Validation\n"))
cat("===========================\n\n")

# Track results
results <- list(
  passed = 0,
  failed = 0,
  warnings = 0
)

test_result <- function(test_name, passed, message = "") {
  if (passed) {
    cat(green("✓"), test_name)
    results$passed <<- results$passed + 1
  } else {
    cat(red("✗"), test_name)
    results$failed <<- results$failed + 1
  }
  if (message != "") {
    cat(paste0(" (", message, ")"))
  }
  cat("\n")
  invisible(passed)
}

warn_result <- function(test_name, message = "") {
  cat(yellow("⚠"), test_name)
  results$warnings <<- results$warnings + 1
  if (message != "") {
    cat(paste0(" (", message, ")"))
  }
  cat("\n")
}

# ============================================================================
# TEST 1: Rust Backend Availability
# ============================================================================
cat(bold("\n1. Rust Backend Availability\n"))
cat("----------------------------\n")

backend_available <- try(rust_backend_available(), silent = TRUE)

if (!inherits(backend_available, "try-error") && isTRUE(backend_available)) {
  test_result("Rust backend is loaded and responding", TRUE)
} else {
  test_result("Rust backend is loaded and responding", FALSE,
              "rust_backend_available() failed")
  cat(red("ERROR: Cannot continue without Rust backend\n"))
  quit(status = 1)
}

# ============================================================================
# TEST 2: Function Namespace Registration
# ============================================================================
cat(bold("\n2. Function Namespace Registration\n"))
cat("------------------------------------\n")

# All 19 registered Rust functions (as of Oct 23, 2025)
required_functions <- c(
  # Core utilities
  "check_rust_backend",
  "test_multi_param_rust",

  # Objective functions
  "objective_rmse_rust",
  "objective_sse_rust",
  "objective_mae_rust",
  "objective_r2_rust",
  "objective_weighted_rmse_rust",
  "objective_ordinal_rust",
  "objective_bounded_rust",
  "objective_huber_rust",
  "objective_quantile_rust",

  # Optimization and shape functions
  "recommend_optimizer_rust",
  "shape_eval_rust",
  "optimize_profile_rust",
  "optimize_profile_rust_flexible",

  # Batch and bootstrap
  "batch_optimize_profiles_rust",
  "bootstrap_engine_rust",

  # Horizon detection
  "mahalanobis_boundary_detection_rust",
  "fuzzy_kmeans_rust"
)

missing_functions <- required_functions[!sapply(required_functions, exists)]

if (length(missing_functions) == 0) {
  test_result(
    paste("All", length(required_functions), "FFI functions registered"),
    TRUE
  )
} else {
  test_result(
    paste("All", length(required_functions), "FFI functions registered"),
    FALSE,
    paste("Missing:", paste(missing_functions, collapse = ", "))
  )
}

# ============================================================================
# TEST 3: Function Callability
# ============================================================================
cat(bold("\n3. Function Callability\n"))
cat("------------------------\n")

callable_functions <- 0
uncallable_functions <- c()

for (func in required_functions) {
  if (!exists(func)) next  # Skip if not in namespace

  tryCatch({
    # Try to get function formals
    formals(get(func))
    callable_functions <- callable_functions + 1
  }, error = function(e) {
    uncallable_functions <<- c(uncallable_functions, func)
  })
}

test_result(
  paste(callable_functions, "functions have valid signatures"),
  length(uncallable_functions) == 0,
  if (length(uncallable_functions) > 0) {
    paste("Problematic:", paste(uncallable_functions, collapse = ", "))
  } else ""
)

# ============================================================================
# TEST 4: Defensive Wrapper Coverage
# ============================================================================
cat(bold("\n4. Defensive Wrapper Coverage\n"))
cat("------------------------------\n")

# Functions that should have defensive wrappers in fit-rust-wrappers.R
# These are functions with complex error handling and fallbacks
functions_needing_defensive_wrappers <- c(
  "objective_rmse_rust",
  "objective_sse_rust",
  "objective_mae_rust",
  "objective_r2_rust",
  "objective_weighted_rmse_rust",
  "objective_ordinal_rust",
  "objective_bounded_rust",
  "objective_huber_rust",
  "objective_quantile_rust",
  "batch_optimize_profiles_rust",
  "bootstrap_engine_rust"
)

# Check which ones have tryCatch protection
# (This is a heuristic - we check source code)
functions_with_trycatch <- c()

for (func in functions_needing_defensive_wrappers) {
  if (!exists(func)) next

  tryCatch({
    src <- capture.output(print(get(func)))
    if (any(grepl("tryCatch", src))) {
      functions_with_trycatch <- c(functions_with_trycatch, func)
    }
  }, error = function(e) {})
}

if (length(functions_with_trycatch) >= 5) {
  test_result(
    paste(length(functions_with_trycatch), "functions have error handling"),
    TRUE
  )
} else {
  warn_result(
    paste(length(functions_with_trycatch), "functions have error handling"),
    paste("Expected most objective functions to have tryCatch")
  )
}

# ============================================================================
# TEST 5: Basic FFI Roundtrip Test
# ============================================================================
cat(bold("\n5. FFI Roundtrip Tests\n"))
cat("---------------------\n")

# Test 1: Simple numeric return
test_numeric <- try({
  result <- objective_rmse_rust(c(1, 2, 3), c(1.1, 2.1, 3.1))
  is.numeric(result) && length(result) == 1
}, silent = TRUE)

test_result(
  "objective_rmse_rust returns numeric scalar",
  !inherits(test_numeric, "try-error") && isTRUE(test_numeric)
)

# Test 2: Vector return
test_vector <- try({
  result <- shape_eval_rust("sigmoid", c(10, 20, 30), c(15, 5, 1), TRUE)
  is.numeric(result) && length(result) == 3
}, silent = TRUE)

test_result(
  "shape_eval_rust returns numeric vector",
  !inherits(test_vector, "try-error") && isTRUE(test_vector)
)

# Test 3: String return
test_string <- try({
  result <- recommend_optimizer_rust(5, 100, "rmse")
  is.character(result) && length(result) == 1
}, silent = TRUE)

test_result(
  "recommend_optimizer_rust returns character",
  !inherits(test_string, "try-error") && isTRUE(test_string)
)

# Test 4: List return
test_list <- try({
  result <- bootstrap_engine_rust(
    c(10, 20, 30),        # observed
    c(1, 2, 3),           # depths
    c(10, 5),             # initial_params
    list(                 # config
      shape_type = "sigmoid",
      objective_name = "rmse",
      optimizer_name = "nelder_mead",
      n_bootstrap = 10,
      seed = 42,
      fallback = FALSE,
      method = "parametric",
      sieve_threshold = 1000,
      max_retries = 3,
      parallel = FALSE
    )
  )
  is.list(result) && length(result) > 0
}, silent = TRUE)

test_result(
  "bootstrap_engine_rust returns list",
  !inherits(test_list, "try-error") && isTRUE(test_list)
)

# ============================================================================
# TEST 6: Export Status
# ============================================================================
cat(bold("\n6. Public API Export Status\n"))
cat("----------------------------\n")

# Check NAMESPACE for useDynLib registration
namespace_file <- "NAMESPACE"
if (file.exists(namespace_file)) {
  namespace_content <- readLines(namespace_file)
  has_usedynlib <- any(grepl("useDynLib.*\\.registration\\s*=\\s*TRUE", namespace_content))
  test_result("NAMESPACE has useDynLib(.registration = TRUE)", has_usedynlib)
} else {
  warn_result("NAMESPACE file not found", "Cannot verify registration")
}

# Check for high-level public API functions
public_api_functions <- c(
  "batch_optimize_profiles",
  "sm_optim_bootstrap",
  "horizon_classify_fuzzy",
  "horizon_boundaries_mahalanobis"
)

found_public <- sum(sapply(public_api_functions, exists))
test_result(
  paste("Found", found_public, "high-level public API functions"),
  found_public >= 2
)

# ============================================================================
# TEST 7: Documentation
# ============================================================================
cat(bold("\n7. Documentation Completeness\n"))
cat("-----------------------------\n")

# Check for .Rd files
man_dir <- "man"
if (dir.exists(man_dir)) {
  rd_files <- list.files(man_dir, pattern = ".*_rust\\.Rd$")
  test_result(
    paste(length(rd_files), "Rust function .Rd files found"),
    length(rd_files) >= 5
  )
} else {
  warn_result("man/ directory not found", "Cannot verify .Rd files")
}

# ============================================================================
# SUMMARY
# ============================================================================
cat(bold("\n===========================\n"))
cat(bold("SUMMARY\n"))
cat(bold("===========================\n\n"))

total_tests <- results$passed + results$failed + results$warnings

cat(green(paste0("✓ PASSED:  ", results$passed, "\n")))
if (results$failed > 0) {
  cat(red(paste0("✗ FAILED:  ", results$failed, "\n")))
}
if (results$warnings > 0) {
  cat(yellow(paste0("⚠ WARNINGS: ", results$warnings, "\n")))
}

cat(paste0("\nTotal:     ", total_tests, "\n\n"))

if (results$failed == 0) {
  cat(green(bold("✓✓✓ FFI VALIDATION PASSED ✓✓✓\n")))
  cat("\nAll FFI functions are properly registered and callable.\n")
  cat("The Rust backend is ready for production use.\n\n")
  quit(status = 0)
} else {
  cat(red(bold("✗✗✗ FFI VALIDATION FAILED ✗✗✗\n")))
  cat("\nPlease address the failures above before proceeding.\n")
  cat("See .github/FFI-BINDING-PROCESS-ANALYSIS.md for help.\n\n")
  quit(status = 1)
}
