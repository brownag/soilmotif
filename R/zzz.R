#' Package initialization and startup hooks
#'
#' Internal functions for package startup and configuration.
#'
#' @keywords internal
.onLoad <- function(libname, pkgname) {
  # Load the Rust backend library
  # The extendr cdylib contains both the wrapper functions and R_init_soilmotif_extendr
  
  dll_name <- paste0("soilmotif", .Platform$dynlib.ext)
  
  # Try location 1: installed package location (after configure copies to src/)
  dll_file <- file.path(libname, pkgname, "libs", dll_name)
  
  # Try location 2: development location (inst/libs or src/)
  if (!file.exists(dll_file)) {
    dll_file <- file.path(libname, pkgname, "inst", "libs", dll_name)
  }
  if (!file.exists(dll_file)) {
    dll_file <- file.path(libname, pkgname, "src", dll_name)
  }
  
  if (file.exists(dll_file)) {
    tryCatch({
      dyn.load(dll_file)
    }, error = function(e) {
      # Silent failure - R fallback implementations will be used
    })
  }
  
  invisible()
}


