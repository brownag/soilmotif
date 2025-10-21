// Wrapper for extendr-generated R initialization
// This ensures R looks for and finds the extendr init function

#include <R.h>
#include <Rinternals.h>

// Forward declare the extendr-generated init function
void R_init_soilmotif_extendr(DllInfo *dll);

// R will look for this function based on the package name
void R_init_soilmotif(DllInfo *dll) {
    // Call the extendr-generated initialization
    R_init_soilmotif_extendr(dll);
}

