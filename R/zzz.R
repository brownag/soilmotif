#' Package initialization and startup hooks
#'
#' Internal functions for package startup and configuration.
#'
#' @keywords internal
.onLoad <- function(libname, pkgname) {
  # The Rust backend library is automatically loaded by R via useDynLib in NAMESPACE
  # No manual initialization needed - the extendr registration happens via
  # the R_init_soilmotif wrapper that's defined in extendr_registration.c
  invisible()
}


