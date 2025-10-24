# Weathering Indices from Elemental Data

# ============================================================================
# Helper Functions
# ============================================================================

#' Internal: Validate weathering data
#'
#' @param data data.frame with element columns
#' @param element_cols character vector of column names to use
#' @return List of validated data and element names
#' @noRd
.validate_weathering_data <- function(data, element_cols = NULL) {
  if (!is.data.frame(data) && !is.matrix(data)) {
    stop("data must be a data.frame or matrix")
  }

  # Convert to data.frame if matrix
  if (is.matrix(data)) {
    data <- as.data.frame(data)
  }

  # Auto-detect element columns if not specified
  if (is.null(element_cols)) {
    common_elements <- c("Al", "Fe", "Si", "K", "Ca", "Na", "Mg", "Ti", "Zr",
                         "Mn", "P")
    element_cols <- intersect(common_elements, names(data))

    # Also look for oxide column names
    oxide_to_element <- list(
      Al2O3 = "Al",
      Fe2O3 = "Fe", Fe3O4 = "Fe",
      SiO2 = "Si",
      K2O = "K",
      CaO = "Ca",
      Na2O = "Na",
      MgO = "Mg",
      TiO2 = "Ti",
      ZrO2 = "Zr",
      Mn2O3 = "Mn", Mn3O4 = "Mn",
      P2O5 = "P"
    )

    oxide_cols <- intersect(names(oxide_to_element), names(data))
    if (length(oxide_cols) > 0) {
      # Rename oxide columns to element names
      for (oxide_col in oxide_cols) {
        elem_name <- oxide_to_element[[oxide_col]]
        names(data)[names(data) == oxide_col] <- elem_name
      }
      element_cols <- unique(c(element_cols,
                               as.character(oxide_to_element[oxide_cols])))
    }

    # Also handle columns with _ppm suffix (e.g., Zr_ppm -> Zr, Ti_ppm -> Ti)
    ppm_cols <- names(data)[grepl("_ppm$", names(data))]
    if (length(ppm_cols) > 0) {
      for (ppm_col in ppm_cols) {
        elem_name <- sub("_ppm$", "", ppm_col)
        if (!(elem_name %in% names(data))) {
          names(data)[names(data) == ppm_col] <- elem_name
          element_cols <- unique(c(element_cols, elem_name))
        }
      }
    }

    if (length(element_cols) == 0) {
      stop("Could not auto-detect element columns. ",
           "Please specify element_cols parameter.")
    }

    message("Auto-detected element columns: ",
            paste(element_cols, collapse = ", "))
  }

  # Check that all specified columns exist
  missing_cols <- setdiff(element_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing columns: ", paste(missing_cols, collapse = ", "))
  }

  list(data = data, element_cols = element_cols)
}

#' Internal: Convert ppm to oxide weight percent
#'
#' Converts elemental concentrations (ppm) to oxide weight percentages
#' using standard atomic weights and oxide formulas.
#'
#' @param element character. Element symbol (Al, Fe, Si, K, Ca, Na, Mg, Ti, Zr)
#' @param ppm_value numeric. Concentration in ppm
#'
#' @return numeric. Concentration in oxide wt%
#' @noRd
.ppm_to_oxide <- function(element, ppm_value) {
  # Conversion factors: (atomic_weight_of_oxide / atomic_weight_of_element) * 100
  # Based on common oxides: Al2O3, Fe2O3, SiO2, K2O, CaO, Na2O, MgO, TiO2, ZrO2

  conversion_factors <- list(
    Al = 1.8895,    # Al -> Al2O3 (101.96 / 53.96)
    Fe = 1.4297,    # Fe -> Fe2O3 (159.69 / 111.69)
    Si = 2.1393,    # Si -> SiO2 (60.09 / 28.09)
    K = 1.2046,     # K -> K2O (94.20 / 78.20)
    Ca = 1.3992,    # Ca -> CaO (56.08 / 40.08)
    Na = 1.3480,    # Na -> Na2O (61.98 / 45.98)
    Mg = 1.6579,    # Mg -> MgO (40.30 / 24.31)
    Ti = 1.6681,    # Ti -> TiO2 (79.87 / 47.87)
    Zr = 1.3514     # Zr -> ZrO2 (123.22 / 91.22)
  )

  if (!(element %in% names(conversion_factors))) {
    stop(paste("Unknown element:", element))
  }

  # ppm to wt% = (ppm / 10000)
  # Then multiply by oxide conversion
  (ppm_value / 10000) * conversion_factors[[element]]
}

#' Internal: Check if element columns are in ppm or oxide wt%
#'
#' @param data data.frame with element columns
#' @param element_cols character vector of element names
#'
#' @return Character. Either "ppm" or "oxide"
#' @noRd
.detect_units <- function(data, element_cols) {
  # If any value > 10, likely already in wt% form (ppm would be huge)
  # pXRF typically reports major elements in wt% (range 0-100)
  # Minor elements might be in ppm (range 0-10000)

  values <- as.numeric(unlist(data[element_cols]))
  values <- values[!is.na(values)]

  if (length(values) == 0) {
    return("unknown")
  }

  max_val <- max(values, na.rm = TRUE)

  # If max value > 20, likely already oxide wt%
  if (max_val > 20) {
    return("oxide")
  } else {
    return("ppm")
  }
}

# ============================================================================
# Core Weathering Index Functions
# ============================================================================

#' Internal: Calculate Chemical Index of Alteration (CIA)
#'
#' @param Al2O3 numeric. Al2O3 concentration (wt%)
#' @param K2O numeric. K2O concentration (wt%)
#' @param Na2O numeric. Na2O concentration (wt%)
#'
#' @return numeric. CIA value (0-100)
#' @noRd
.calculate_CIA <- function(Al2O3, K2O, Na2O) {
  denominator <- Al2O3 + K2O + Na2O

  # Handle zeros in denominator
  cia <- ifelse(denominator > 0,
    (Al2O3 / denominator) * 100,
    NA_real_
  )

  # Clamp to valid range
  cia <- pmin(pmax(cia, 0), 100)
  cia
}

#' Internal: Calculate Weathering Index of Parker (WIP)
#'
#' @param K2O numeric. K2O concentration (wt%)
#' @param Na2O numeric. Na2O concentration (wt%)
#' @param CaO numeric. CaO concentration (wt%)
#' @param MgO numeric. MgO concentration (wt%)
#'
#' @return numeric. WIP value (0-100+, typically 20-100)
#' @noRd
.calculate_WIP <- function(K2O, Na2O, CaO, MgO) {
  # Modified formula using oxide values
  # WIP = [2*Na2O/0.35 + 2*K2O/0.25 + MgO/0.9 + 2*CaO/1.3] / 10

  wip <- (2 * Na2O / 0.35 + 2 * K2O / 0.25 + MgO / 0.9 + 2 * CaO / 1.3) / 10

  # Handle NaN/Inf from division
  wip <- pmax(wip, 0)
  wip[is.infinite(wip) | is.na(wip)] <- NA_real_
  wip
}

#' Internal: Calculate Plagioclase Index of Alteration (PIA)
#'
#' @param Al2O3 numeric. Al2O3 concentration (wt%)
#' @param Na2O numeric. Na2O concentration (wt%)
#' @param K2O numeric. K2O concentration (wt%)
#' @param CaO numeric. CaO concentration (wt%)
#'
#' @return numeric. PIA value (0-100)
#' @noRd
.calculate_PIA <- function(Al2O3, Na2O, K2O, CaO) {
  numerator <- Al2O3 - K2O
  denominator <- Al2O3 + CaO - K2O

  pia <- ifelse(denominator > 0,
    (numerator / denominator) * 100,
    NA_real_
  )

  # Clamp to valid range
  pia <- pmin(pmax(pia, 0), 100)
  pia
}

#' Internal: Calculate Silica-Alumina Ratio (SAR)
#'
#' @param SiO2 numeric. SiO2 concentration (wt%)
#' @param Al2O3 numeric. Al2O3 concentration (wt%)
#'
#' @return numeric. SAR value (typically 3-8)
#' @noRd
.calculate_SAR <- function(SiO2, Al2O3) {
  sar <- SiO2 / Al2O3
  sar[Al2O3 == 0] <- NA_real_
  sar
}

#' Internal: Calculate Zirconium-Titanium Ratio (ZrTi)
#'
#' @param Zr_ppm numeric. Zirconium concentration (ppm)
#' @param Ti_ppm numeric. Titanium concentration (ppm)
#'
#' @return numeric. ZrTi ratio (typically 0.01-0.1)
#' @noRd
.calculate_ZrTi <- function(Zr_ppm, Ti_ppm) {
  zrti <- Zr_ppm / Ti_ppm
  zrti[Ti_ppm == 0] <- NA_real_
  zrti
}

#' Internal: Calculate Iron Accumulation Ratio (FAR)
#'
#' @param Fe_ppm numeric. Iron concentration (ppm) in soil
#' @param parent_Fe_ppm numeric. Reference Fe concentration in parent material (ppm)
#'
#' @return numeric. FAR value (typically 0.5-3.0)
#' @noRd
.calculate_FAR <- function(Fe_ppm, parent_Fe_ppm = 50000) {
  far <- Fe_ppm / parent_Fe_ppm
  far
}

# ============================================================================
# Main Weathering Indices Function
# ============================================================================

#' Calculate Multiple Weathering Indices from Elemental Data
#'
#' Main entry point for calculating weathering indices from pXRF elemental
#' measurements. Computes multiple indices simultaneously and returns a
#' data.frame with results.
#'
#' @param data data.frame with depth and element concentration columns
#' @param depth_col Character. Name of depth column (default: "depth")
#' @param element_cols character vector of element column names to use.
#'        If NULL (default), auto-detects common elements (Al, Fe, Si, K, Ca, Na, Mg, Ti, Zr)
#' @param indices Character vector of indices to compute. Options:
#'        "CIA", "WIP", "PIA", "SAR", "ZrTi", "FAR", or "all" (default)
#' @param convert_to_oxides Logical. If TRUE (default) and units appear to be ppm,
#'        converts to oxide wt% using standard conversion factors
#' @param parent_Fe_ppm numeric. Reference Fe concentration (ppm) for FAR calculation.
#'        Default 50000 (granitic parent). Use 110000 for basaltic.
#'
#' @return data.frame with columns including depth and calculated indices.
#'   Columns correspond to all requested indices as numeric columns.
#'
#' @details
#' This function:
#' 1. Validates input data and auto-detects element columns
#' 2. Converts units if needed (ppm → oxide wt%)
#' 3. Calculates requested weathering indices
#' 4. Returns results aligned with original depth column
#'
#' Missing values (NA) are propagated through calculations.
#'
#' @examples
#' \dontrun{
#' # Create synthetic pXRF data
#' pxrf_data <- data.frame(
#'   depth = seq(0, 100, length.out = 20),
#'   Al = rnorm(20, 80000, 5000),    # ppm
#'   Fe = rnorm(20, 40000, 3000),    # ppm
#'   Si = rnorm(20, 300000, 10000),  # ppm
#'   K = rnorm(20, 30000, 2000),     # ppm
#'   Ca = rnorm(20, 50000, 5000)     # ppm
#' )
#'
#' # Calculate all indices (will auto-convert from ppm to oxides)
#' weather_results <- sm_weathering(pxrf_data)
#'
#' # View results
#' head(weather_results)
#'
#' # Calculate specific indices only
#' weather_results <- sm_weathering(pxrf_data, indices = c("CIA", "SAR"))
#' }
#'
#' @export
sm_weathering <- function(data,
                          depth_col = "depth",
                          element_cols = NULL,
                          indices = "all",
                          convert_to_oxides = TRUE,
                          parent_Fe_ppm = 50000) {

  # Validate input
  validated <- .validate_weathering_data(data, element_cols)
  data <- validated$data
  element_cols <- validated$element_cols

  # Check depth column
  if (!(depth_col %in% names(data))) {
    stop("Depth column '", depth_col, "' not found in data")
  }

  depths <- data[[depth_col]]

  # Detect units
  units <- .detect_units(data, element_cols)
  message("Detected units: ", units)

  # Convert to oxides if needed
  if (convert_to_oxides && units == "ppm") {
    message("Converting from ppm to oxide wt%...")

    for (elem in element_cols) {
      data[[elem]] <- .ppm_to_oxide(elem, data[[elem]])
    }
  }

  # Initialize result data.frame with depth
  result <- data.frame(depth = depths)

  # Validate requested indices
  valid_indices <- c("CIA", "WIP", "PIA", "SAR", "ZrTi", "FAR")
  if (identical(indices, "all")) {
    indices_to_calc <- valid_indices
  } else {
    invalid <- setdiff(indices, valid_indices)
    if (length(invalid) > 0) {
      stop("Invalid indices: ", paste(invalid, collapse = ", "))
    }
    indices_to_calc <- indices
  }

  # Calculate requested indices
  if ("CIA" %in% indices_to_calc) {
    if (all(c("Al", "K", "Na") %in% element_cols)) {
      result$CIA <- .calculate_CIA(data$Al, data$K, data$Na)
    } else {
      warning("Skipping CIA: Al, K, Na columns required")
    }
  }

  if ("WIP" %in% indices_to_calc) {
    if (all(c("K", "Na", "Ca", "Mg") %in% element_cols)) {
      result$WIP <- .calculate_WIP(data$K, data$Na, data$Ca, data$Mg)
    } else {
      warning("Skipping WIP: K, Na, Ca, Mg columns required")
    }
  }

  if ("PIA" %in% indices_to_calc) {
    if (all(c("Al", "Na", "K", "Ca") %in% element_cols)) {
      result$PIA <- .calculate_PIA(data$Al, data$Na, data$K, data$Ca)
    } else {
      warning("Skipping PIA: Al, Na, K, Ca columns required")
    }
  }

  if ("SAR" %in% indices_to_calc) {
    if (all(c("Si", "Al") %in% element_cols)) {
      result$SAR <- .calculate_SAR(data$Si, data$Al)
    } else {
      warning("Skipping SAR: Si, Al columns required")
    }
  }

  if ("ZrTi" %in% indices_to_calc) {
    if (all(c("Zr", "Ti") %in% element_cols)) {
      result$ZrTi <- .calculate_ZrTi(data$Zr, data$Ti)
    } else {
      warning("Skipping ZrTi: Zr, Ti columns required")
    }
  }

  if ("FAR" %in% indices_to_calc) {
    if ("Fe" %in% element_cols) {
      result$FAR <- .calculate_FAR(data$Fe, parent_Fe_ppm)
    } else {
      warning("Skipping FAR: Fe column required")
    }
  }

  class(result) <- c("weathering_indices", "data.frame")
  result
}

#' Access Individual Weathering Index Calculators
#'
#' Returns the function definition for a specific weathering index calculator.
#' Useful for advanced users who want to compute individual indices directly
#' on vector inputs without requiring a full data.frame workflow.
#'
#' @param index Character. Name of the weathering index to retrieve.
#'   Valid options: "CIA", "WIP", "PIA", "SAR", "ZrTi", "FAR"
#'
#' @return Function. The corresponding calculator function with signature:
#'   - CIA: `f(Al2O3, K2O, Na2O)`
#'   - WIP: `f(K2O, Na2O, CaO, MgO)`
#'   - PIA: `f(Al2O3, Na2O, K2O, CaO)`
#'   - SAR: `f(SiO2, Al2O3)`
#'   - ZrTi: `f(Zr_ppm, Ti_ppm)`
#'   - FAR: `f(Fe_ppm, parent_Fe_ppm = 50000)`
#'
#' @details
#' This function provides low-level access to individual weathering index
#' calculators. For most use cases, use `sm_weathering()` which provides
#' a high-level interface for batch calculation and automatic unit handling.
#'
#' @examples
#' # Get the CIA calculator
#' cia_fn <- sm_weathering_index("CIA")
#'
#' # Use it to calculate CIA on vector inputs
#' cia_result <- cia_fn(Al2O3 = c(14, 15, 16),
#'                      K2O = c(4.5, 4.0, 3.5),
#'                      Na2O = c(3.5, 3.2, 3.0))
#'
#' # Get the SAR calculator
#' sar_fn <- sm_weathering_index("SAR")
#' sar_result <- sar_fn(SiO2 = c(75, 65, 50),
#'                      Al2O3 = c(12, 15, 20))
#'
#' @export
sm_weathering_index <- function(index) {
  # Create registry mapping index names to calculator functions
  registry <- list(
    CIA = .calculate_CIA,
    WIP = .calculate_WIP,
    PIA = .calculate_PIA,
    SAR = .calculate_SAR,
    ZrTi = .calculate_ZrTi,
    FAR = .calculate_FAR
  )

  # Validate index name
  if (!(index %in% names(registry))) {
    stop("Invalid index: '", index, "'. Valid options: ",
         paste(names(registry), collapse = ", "))
  }

  # Return the function
  registry[[index]]
}

# ============================================================================
# Derived Indices and Classifications
# ============================================================================

#' Integrated Weathering Index (IWI)
#'
#' Combines major weathering indices (CIA, WIP, PIA) into a single
#' 0-1 weathering score.
#'
#' @param CIA numeric. Chemical Index of Alteration (0-100)
#' @param WIP numeric. Weathering Index of Parker (0-100+)
#' @param PIA numeric. Plagioclase Index of Alteration (0-100)
#'
#' @return numeric. Integrated index (0-1), where 1 = fully weathered
#'
#' @details
#' Normalization applied to each index:
#' \itemize{
#'   \item CIA: (CIA - 50) / 50 where 50=fresh, 100=weathered
#'   \item WIP: (100 - WIP) / 100 where 100=fresh, 0=weathered
#'   \item PIA: PIA / 100 where 0=fresh, 100=weathered
#' }
#'
#' IWI = mean(normalized_CIA, normalized_WIP, normalized_PIA)
#'
#' @examples
#' \dontrun{
#' sm_weathering_integrated(CIA = 75, WIP = 40, PIA = 70)
#' }
#'
#' @export
sm_weathering_integrated <- function(CIA, WIP, PIA) {
  # Normalize to 0-1 range
  cia_norm <- pmin(pmax((CIA - 50) / 50, 0), 1)
  wip_norm <- pmin(pmax((100 - WIP) / 100, 0), 1)
  pia_norm <- pmin(pmax(PIA / 100, 0), 1)

  # Average
  iwi <- (cia_norm + wip_norm + pia_norm) / 3
  iwi
}

#' Classify Weathering Stage
#'
#' Assigns weathering stage category based on CIA and WIP values.
#'
#' @param CIA numeric. Chemical Index of Alteration (0-100)
#' @param WIP numeric. Weathering Index of Parker (0-100+)
#'
#' @return Factor. Weathering stage with levels:
#'   "fresh", "slightly_altered", "moderate", "strong", "laterite"
#'
#' @details
#' **Stage classifications:**
#'   - Fresh: CIA < 60 & WIP > 80
#'   - Slightly altered: CIA 60-70 & WIP 60-80
#'   - Moderate: CIA 70-80 & WIP 40-60
#'   - Strong: CIA 80-90 & WIP 20-40
#'   - Laterite: CIA > 90 & WIP < 20
#'
#' @export
sm_weathering_stage <- function(CIA, WIP) {
  stage <- rep("unknown", length(CIA))

  stage[CIA < 60 & WIP > 80] <- "fresh"
  stage[CIA >= 60 & CIA < 70 & WIP >= 60 & WIP <= 80] <- "slightly_altered"
  stage[CIA >= 70 & CIA < 80 & WIP >= 40 & WIP < 60] <- "moderate"
  stage[CIA >= 80 & CIA < 90 & WIP >= 20 & WIP < 40] <- "strong"
  stage[CIA >= 90 & WIP < 20] <- "laterite"

  # Handle border cases and NAs
  stage[CIA >= 60 & CIA < 75 & (is.na(WIP) | (WIP >= 50 & WIP <= 85))] <- "moderate"
  stage[is.na(CIA) | is.na(WIP)] <- NA

  factor(stage,
    levels = c("fresh", "slightly_altered", "moderate", "strong", "laterite")
  )
}

# ============================================================================
# Element Depletion Calculations
# ============================================================================

#' Calculate Element Depletion Factors
#'
#' Normalizes element concentrations to an immobile element (typically Zr or Ti)
#' to quantify element loss during weathering.
#'
#' @param data data.frame with depth and element columns
#' @param element_cols character vector of element names to evaluate
#' @param immobile_element Character. Reference immobile element ("Zr" or "Ti")
#' @param parent_composition data.frame with parent material composition
#'
#' @return data.frame with columns:
#'   - depth
#'   - element (names of evaluated elements)
#'   - depletion_factor (present / parent normalized to immobile)
#'   - interpretation ("enriched", "depleted", "unchanged")
#'
#' @details
#' Formula:
#' DF = (C_present / C_immobile_present) / (C_parent / C_immobile_parent)
#'
#' Where:
#' - DF = 1: No change (unchanged)
#' - DF > 1: Accumulation (enriched)
#' - DF < 1: Loss (depleted)
#'
#' @examples
#' \dontrun{
#' # Calculate depletion factors using Zr as immobile reference
#' data <- data.frame(
#'   depth = 1:10,
#'   Al = c(50000, 45000, 40000, 35000, 30000, 30000, 30000, 30000, 30000, 30000),
#'   Fe = c(40000, 42000, 44000, 46000, 50000, 55000, 60000, 65000, 70000, 75000),
#'   Zr = c(190, 190, 190, 190, 190, 190, 190, 190, 190, 190)
#' )
#' depletion <- sm_weathering_depletion(data)
#' }
#'
#' @export
sm_weathering_depletion <- function(data,
                                   element_cols = NULL,
                                   immobile_element = "Zr",
                                   parent_composition = NULL) {

  validated <- .validate_weathering_data(data, element_cols)
  data <- validated$data
  element_cols <- validated$element_cols

  if (!(immobile_element %in% element_cols)) {
    stop(immobile_element, " not found in element columns")
  }

  # Default parent composition (granitic)
  if (is.null(parent_composition)) {
    parent_composition <- list(
      Zr = 190, Ti = 5000, Al = 80000, Fe = 40000,
      Si = 320000, K = 30000, Ca = 40000, Na = 30000
    )
  }

  immobile_parent <- parent_composition[[immobile_element]]
  immobile_present <- data[[immobile_element]]

  # Calculate depletion for each element
  results <- list()

  for (elem in element_cols) {
    if (elem == immobile_element) next

    element_parent <- parent_composition[[elem]]
    if (is.null(element_parent)) {
      warning("Parent composition for ", elem, " not available, skipping")
      next
    }

    element_present <- data[[elem]]

    # Depletion factor = (present/immobile_present) / (parent/immobile_parent)
    df <- (element_present / immobile_present) / (element_parent / immobile_parent)

    # Classify
    interpretation <- ifelse(is.na(df), NA,
      ifelse(df < 0.9, "depleted",
        ifelse(df > 1.1, "enriched", "unchanged")
      )
    )

    results[[elem]] <- data.frame(
      depth = data$depth,
      element = elem,
      depletion_factor = df,
      interpretation = interpretation,
      stringsAsFactors = FALSE
    )
  }

  # Combine results
  result_df <- do.call(rbind, results)
  rownames(result_df) <- NULL

  result_df
}

# ============================================================================
# Integration with Horizon Classification
# ============================================================================

#' Assign Weathering Indices to Horizons
#'
#' Aggregates weathering indices within horizons classified by
#' `horizon_classify_fuzzy()`.
#'
#' @param indices_df data.frame from `weathering_indices()`
#' @param fuzzy_classification result from `horizon_classify_fuzzy()`
#'
#' @return data.frame with horizon-level summaries
#'
#' @examples
#' \dontrun{
#' # Compute weathering indices and classify horizons
#' indices <- weathering_indices(soil_data)
#' horizons <- horizon_classify_fuzzy(soil_data, n_horizons = 3)
#' by_horizon <- weathering_by_horizon(indices, horizons)
#' }
#'
#' @export
sm_weathering_by_horizon <- function(indices_df, fuzzy_classification) {
  # Extract horizon membership from fuzzy classification
  # This allows mapping of depth points to horizons

  if (!inherits(fuzzy_classification, "fuzzy_horizons")) {
    stop("fuzzy_classification must be result from horizon_classify_fuzzy()")
  }

  # Get depths and horizon assignments
  depths <- fuzzy_classification$depths
  memberships <- fuzzy_classification$memberships

  # Assign each depth to dominant horizon
  dominant_horizon <- apply(memberships, 1, which.max)

  # Merge with indices
  indices_with_horizon <- cbind(
    indices_df,
    dominant_horizon = dominant_horizon
  )

  # Aggregate by horizon
  result <- aggregate(
    indices_with_horizon[, -c(1, ncol(indices_with_horizon))],
    by = list(horizon = indices_with_horizon$dominant_horizon),
    FUN = function(x) list(mean = mean(x, na.rm = TRUE), sd = sd(x, na.rm = TRUE))
  )

  result
}

#' Describe Vertical Weathering Progression
#'
#' Characterizes how weathering indices change with depth.
#'
#' @param indices_df data.frame from `weathering_indices()`
#'
#' @return Character string describing trend:
#'   "increasing" (more weathered at surface),
#'   "decreasing" (less weathered at surface),
#'   "stable" (consistent with depth)
#'
#' @examples
#' \dontrun{
#' # Analyze how weathering changes with depth
#' indices <- weathering_indices(soil_data)
#' trend <- weathering_progression(indices)
#' cat("Weathering trend:", trend, "\n")
#' }
#'
#' @export
sm_weathering_progression <- function(indices_df) {
  # Use CIA as primary indicator
  if (!("CIA" %in% names(indices_df))) {
    return("unknown (CIA not available)")
  }

  cia <- indices_df$CIA
  cia_clean <- cia[!is.na(cia)]

  if (length(cia_clean) < 3) {
    return("insufficient data")
  }

  # Divide into surface and subsurface
  n <- length(cia_clean)
  surface_mean <- mean(cia_clean[1:ceiling(n / 2)], na.rm = TRUE)
  subsurface_mean <- mean(cia_clean[(ceiling(n / 2) + 1):n], na.rm = TRUE)

  # Determine trend
  diff <- surface_mean - subsurface_mean

  if (abs(diff) < 5) {
    "stable (homogeneous weathering with depth)"
  } else if (diff > 0) {
    paste0("increasing with depth (surface CIA = ", round(surface_mean, 1),
      ", subsurface = ", round(subsurface_mean, 1), ")")
  } else {
    paste0("decreasing with depth (surface CIA = ", round(surface_mean, 1),
      ", subsurface = ", round(subsurface_mean, 1), ")")
  }
}
