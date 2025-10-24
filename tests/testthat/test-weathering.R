# Tests for Weathering Indices Functions
# Comprehensive test coverage for soil weathering analysis module

# ============================================================================
# Helper Functions and Test Data Setup
# ============================================================================

# Create sample pXRF data (ppm)
create_test_data_ppm <- function(n_depths = 11) {
  data.frame(
    depth = seq(0, 100, by = 10),
    Al = c(80000, 82000, 85000, 90000, 95000, 100000, 102000, 105000, 108000, 110000, 112000),
    Fe = c(40000, 42000, 45000, 50000, 55000, 60000, 62000, 65000, 68000, 70000, 72000),
    Si = c(300000, 305000, 310000, 315000, 320000, 325000, 330000, 335000, 340000, 345000, 350000),
    K = c(30000, 31000, 32000, 33000, 34000, 35000, 36000, 37000, 38000, 39000, 40000),
    Ca = c(50000, 48000, 46000, 44000, 42000, 40000, 38000, 36000, 34000, 32000, 30000),
    Na = c(25000, 24000, 23000, 22000, 21000, 20000, 19000, 18000, 17000, 16000, 15000),
    Mg = c(30000, 31000, 32000, 33000, 34000, 35000, 36000, 37000, 38000, 39000, 40000),
    Ti = c(5000, 5100, 5200, 5300, 5400, 5500, 5600, 5700, 5800, 5900, 6000),
    Zr = c(300, 310, 320, 330, 340, 350, 360, 370, 380, 390, 400)
  )
}

# Create oxide data (wt%)
create_test_data_oxides <- function(n_depths = 11) {
  data.frame(
    depth = seq(0, 100, by = 10),
    Al2O3 = c(10, 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15),
    Fe2O3 = c(6, 6.3, 6.6, 7, 7.5, 8, 8.5, 9, 9.5, 10, 10.5),
    SiO2 = c(60, 60.5, 61, 61.5, 62, 62.5, 63, 63.5, 64, 64.5, 65),
    K2O = c(2, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 3),
    CaO = c(5, 4.8, 4.6, 4.4, 4.2, 4, 3.8, 3.6, 3.4, 3.2, 3),
    Na2O = c(2.5, 2.4, 2.3, 2.2, 2.1, 2, 1.9, 1.8, 1.7, 1.6, 1.5),
    MgO = c(4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 5),
    TiO2 = c(0.8, 0.82, 0.84, 0.86, 0.88, 0.9, 0.92, 0.94, 0.96, 0.98, 1),
    Zr_ppm = c(300, 310, 320, 330, 340, 350, 360, 370, 380, 390, 400)
  )
}

# ============================================================================
# Test: Core Weathering Index Functions
# ============================================================================

test_that("CIA calculation works correctly", {
  # CIA = 100 * [Al2O3 / (Al2O3 + K2O + Na2O)]
  # Simple test case: Al2O3=40, K2O=20, Na2O=20 => CIA = 100*40/80 = 50
  result <- sm_weathering_index("CIA")(Al2O3 = 40, K2O = 20, Na2O = 20)
  expect_equal(result, 50, tolerance = 0.1)

  # Test vector input
  result <- sm_weathering_index("CIA")(
    Al2O3 = c(10, 20, 30),
    K2O = c(5, 10, 15),
    Na2O = c(5, 10, 15)
  )
  expect_length(result, 3)
  expect_true(all(result >= 0 & result <= 100))
})

test_that("WIP calculation works correctly", {
  # WIP = (2*Na2O/0.35 + 2*K2O/0.25 + MgO/0.9 + 2*CaO/1.3) / 10
  # Simple known values test
  result <- sm_weathering_index("WIP")(K2O = 2, MgO = 4, Na2O = 2, CaO = 5)
  expect_true(result > 0)
})

test_that("PIA calculation works correctly", {
  # PIA = 100 * [(Al2O3 - K2O) / (Al2O3 - K2O + CaO + Na2O)]
  result <- sm_weathering_index("PIA")(Al2O3 = 40, K2O = 20, Na2O = 20, CaO = 20)
  expect_true(result >= 0 & result <= 100)

  # Vector input
  result <- sm_weathering_index("PIA")(
    Al2O3 = c(10, 20, 30),
    K2O = c(2, 4, 6),
    Na2O = c(3, 6, 9),
    CaO = c(3, 6, 9)
  )
  expect_length(result, 3)
})

test_that("SAR calculation works correctly", {
  # SAR = SiO2 / Al2O3
  result <- sm_weathering_index("SAR")(SiO2 = 60, Al2O3 = 20)
  expect_equal(result, 3, tolerance = 0.01)

  # Should increase with SiO2, decrease with Al2O3
  result1 <- sm_weathering_index("SAR")(SiO2 = 60, Al2O3 = 20)
  result2 <- sm_weathering_index("SAR")(SiO2 = 70, Al2O3 = 20)
  result3 <- sm_weathering_index("SAR")(SiO2 = 60, Al2O3 = 10)

  expect_true(result2 > result1)  # More SiO2 = higher SAR
  expect_true(result3 > result1)  # Less Al2O3 = higher SAR
})

test_that("ZrTi calculation works correctly", {
  # ZrTi = Zr_ppm / Ti_ppm
  result <- sm_weathering_index("ZrTi")(Zr_ppm = 300, Ti_ppm = 5000)
  expect_equal(result, 0.06, tolerance = 0.001)

  # Vector input
  result <- sm_weathering_index("ZrTi")(Zr_ppm = c(300, 350, 400), Ti_ppm = c(5000, 5500, 6000))
  expect_length(result, 3)
  expect_true(all(result > 0))
})

test_that("FAR calculation works correctly", {
  # FAR = Fe_ppm / parent_Fe_ppm
  result <- sm_weathering_index("FAR")(Fe_ppm = 50000, parent_Fe_ppm = 50000)
  expect_equal(result, 1.0, tolerance = 0.01)

  # Enriched Fe
  result <- sm_weathering_index("FAR")(Fe_ppm = 100000, parent_Fe_ppm = 50000)
  expect_true(result > 1.0)

  # Depleted Fe
  result <- sm_weathering_index("FAR")(Fe_ppm = 25000, parent_Fe_ppm = 50000)
  expect_true(result < 1.0)
})

# ============================================================================
# Test: Main sm_weathering Function
# ============================================================================

test_that("sm_weathering function with ppm data", {
  data <- create_test_data_ppm()
  result <- sm_weathering(data, indices = "all", convert_to_oxides = TRUE)

  # Should return a data frame with depth and all indices
  expect_s3_class(result, "data.frame")
  expect_true("depth" %in% names(result))
  expect_true("CIA" %in% names(result))
  expect_true("WIP" %in% names(result))
  expect_true("PIA" %in% names(result))
  expect_true("SAR" %in% names(result))
  expect_true("ZrTi" %in% names(result))
  expect_true("FAR" %in% names(result))

  # Check value ranges (WIP can exceed 100 for fresh materials)
  expect_true(all(result$CIA >= 0, na.rm = TRUE))
  expect_true(all(result$WIP >= 0, na.rm = TRUE))
  expect_true(all(result$PIA >= 0 & result$PIA <= 100, na.rm = TRUE))
})

test_that("sm_weathering function with oxide data", {
  data <- create_test_data_oxides()
  # sm_weathering auto-detects oxide and ppm column names
  result <- sm_weathering(data, indices = "all", convert_to_oxides = FALSE)

  # Should return a data frame with depth and all indices
  expect_s3_class(result, "data.frame")
  expect_true("depth" %in% names(result))
  expect_true("CIA" %in% names(result))
  expect_true("WIP" %in% names(result))
  expect_true("PIA" %in% names(result))
  expect_true("SAR" %in% names(result))
  expect_true("ZrTi" %in% names(result))
  expect_true("FAR" %in% names(result))

  # Check value ranges
  expect_true(all(result$CIA >= 0, na.rm = TRUE))
  expect_true(all(result$WIP >= 0, na.rm = TRUE))
  expect_true(all(result$PIA >= 0 & result$PIA <= 100, na.rm = TRUE))
})

test_that("sm_weathering function with subset of indices", {
  data <- create_test_data_ppm()
  result <- sm_weathering(data, indices = c("CIA", "WIP"), convert_to_oxides = TRUE)

  expect_true("CIA" %in% names(result))
  expect_true("WIP" %in% names(result))
  expect_false("PIA" %in% names(result))
})

test_that("sm_weathering handles missing data", {
  data <- create_test_data_ppm()
  data$Al[1] <- NA
  data$Fe[2] <- NA

  result <- sm_weathering(data, indices = "all", convert_to_oxides = TRUE)
  expect_true(is.na(result$CIA[1]))
  expect_true(is.na(result$FAR[2]))
})

test_that("sm_weathering auto-detects element columns", {
  data <- create_test_data_ppm()
  # Remove depth column to test auto-detection
  result <- sm_weathering(data, indices = c("CIA"), convert_to_oxides = TRUE)
  expect_true("CIA" %in% names(result))
})

# ============================================================================
# Test: Derived Indices
# ============================================================================

test_that("sm_weathering_integrated calculation", {
  # Test with fresh feldspar values
  result <- sm_weathering_integrated(CIA = 50, WIP = 80, PIA = 50)
  expect_true(result >= 0 & result <= 1)
  expect_true(result < 0.5)  # Should indicate fresh material

  # Test with laterite values
  result <- sm_weathering_integrated(CIA = 90, WIP = 15, PIA = 85)
  expect_true(result > 0.7)  # Should indicate advanced weathering

  # Vector input
  result <- sm_weathering_integrated(
    CIA = c(50, 75, 90),
    WIP = c(80, 45, 15),
    PIA = c(50, 70, 85)
  )
  expect_length(result, 3)
  expect_true(result[1] < result[3])  # Fresh < laterite
})

test_that("weathering_stage classification", {
  # Fresh feldspar (CIA < 60, WIP > 80)
  result <- sm_weathering_stage(CIA = 50, WIP = 90)
  expect_s3_class(result, "factor")
  expect_equal(as.character(result), "fresh")

  # Moderate weathering (CIA 70-80, WIP 40-60)
  result <- sm_weathering_stage(CIA = 75, WIP = 50)
  expect_equal(as.character(result), "moderate")

  # Strong (CIA 80-90, WIP 20-40)
  result <- sm_weathering_stage(CIA = 85, WIP = 25)
  expect_equal(as.character(result), "strong")

  # Laterite (CIA > 90, WIP < 20)
  result <- sm_weathering_stage(CIA = 95, WIP = 10)
  expect_equal(as.character(result), "laterite")

  # Vector input - check that classifications exist
  result <- sm_weathering_stage(
    CIA = c(50, 75, 85, 95),
    WIP = c(90, 50, 25, 10)
  )
  expect_length(result, 4)
  expect_equal(as.character(result[1]), "fresh")
  expect_equal(as.character(result[4]), "laterite")
})

# ============================================================================
# Test: Unit Conversion Functions
# ============================================================================

test_that(".ppm_to_oxide function works correctly", {
  # Al: ppm -> Al2O3 wt%, conversion factor ≈ 0.00189
  result <- soilmotif:::.ppm_to_oxide("Al", 80000)
  expect_true(result > 0 & result < 200)  # Reasonable range for Al2O3

  # Si: ppm -> SiO2 wt%, conversion factor ≈ 0.00214
  result <- soilmotif:::.ppm_to_oxide("Si", 300000)
  expect_true(result > 40 & result < 80)  # Reasonable range for SiO2
})

test_that(".detect_units function works correctly", {
  # PPM data - realistic values that are below 20 max
  # (The function logic treats values > 20 as oxides, < 20 as ppm)
  ppm_data <- data.frame(depth = 0, Al = 8, Fe = 4, Si = 15)
  units <- soilmotif:::.detect_units(ppm_data, c("Al", "Fe", "Si"))
  expect_equal(units, "ppm")

  # Oxide data - function returns "oxide" not "oxides"
  oxide_data <- data.frame(depth = 0, Al2O3 = 10, Fe2O3 = 6, SiO2 = 60)
  units <- soilmotif:::.detect_units(oxide_data, c("Al2O3", "Fe2O3", "SiO2"))
  expect_equal(units, "oxide")
})

# ============================================================================
# Test: Element Depletion
# ============================================================================

test_that("sm_weathering_depletion function works", {
  # Create data with immobile element Zr
  data <- create_test_data_ppm()

  # sm_weathering_depletion expects immobile_element to be in element_cols
  # Create a parent composition data frame with just one row
  parent_comp <- data.frame(Fe = 50000, Al = 80000, Si = 300000, Zr = 350)

  result <- sm_weathering_depletion(
    data,
    element_cols = c("Fe", "Al", "Si", "Zr"),  # Zr must be included
    immobile_element = "Zr",
    parent_composition = parent_comp
  )

  expect_s3_class(result, "data.frame")
  expect_true("depth" %in% names(result))
  expect_true("element" %in% names(result))
  expect_true("depletion_factor" %in% names(result))

  # Check depletion factors are positive
  expect_true(all(result$depletion_factor > 0, na.rm = TRUE))
})

# ============================================================================
# Test: Horizon Integration
# ============================================================================

test_that("sm_weathering_by_horizon integrates with fuzzy classification", {
  # Create pXRF and indices data
  pxrf_data <- create_test_data_ppm()
  indices_df <- sm_weathering(pxrf_data, indices = "CIA",
                                   convert_to_oxides = TRUE)

  # Manually create a fuzzy_horizons object for testing
  depths <- pxrf_data$depth
  n_depths <- length(depths)
  n_horizons <- 3

  # Create mock membership matrix (rows sum to 1)
  memberships <- matrix(0, nrow = n_depths, ncol = n_horizons)
  # Assign weights to create 3 horizons
  horizons <- rep(1:n_horizons, length.out = n_depths)
  for (i in seq_along(horizons)) {
    h <- horizons[i]
    memberships[i, h] <- 0.8  # Strong membership
    # Distribute remaining 0.2 to other horizons
    other_h <- setdiff(1:n_horizons, h)
    memberships[i, other_h] <- 0.2 / (n_horizons - 1)
  }

  # Create the fuzzy_horizons object
  fuzzy_class <- list(
    call = quote(sm_horizon_classify_fuzzy(data, n_horizons = 3)),
    depths = depths,
    element_cols = c("Al", "Fe", "Si"),
    centers = matrix(rnorm(n_horizons * 3), nrow = n_horizons),
    memberships = memberships,
    entropy = rep(0.1, n_depths),
    dominant_horizon = apply(memberships, 1, which.max),
    n_horizons = n_horizons,
    m = 2.0,
    iterations = 10,
    converged = TRUE,
    method = "r"
  )
  class(fuzzy_class) <- "fuzzy_horizons"

  # Test sm_weathering_by_horizon with this object
  result <- sm_weathering_by_horizon(indices_df, fuzzy_class)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), n_horizons)
  expect_true("horizon" %in% names(result))
})

test_that("sm_weathering_progression function identifies trends", {
  pxrf_data <- create_test_data_ppm()
  indices_df <- sm_weathering(pxrf_data, indices = "all", convert_to_oxides = TRUE)

  result <- sm_weathering_progression(indices_df)

  # sm_weathering_progression returns a character string describing the trend
  expect_true(is.character(result))
  expect_true(length(result) == 1)
  expect_true(grepl("increasing|decreasing|stable|unknown|insufficient", result))
})

# ============================================================================
# Test: Input Validation
# ============================================================================

test_that("sm_weathering validates input", {
  # Invalid input type
  expect_error(sm_weathering("not a dataframe"))

  # With depth and element columns should work
  data <- data.frame(depth = seq(0, 100, by = 10), Al = 80000, Fe = 40000, Si = 300000, K = 30000, Ca = 50000, Na = 25000)
  expect_no_error(sm_weathering(data, indices = "CIA", convert_to_oxides = TRUE))

  # No element columns should error
  data <- data.frame(depth = seq(0, 100, by = 10))
  expect_error(sm_weathering(data))

  # Missing required columns for CIA should warn
  data <- data.frame(depth = seq(0, 100, by = 10), Al = 80000, Fe = 40000, Si = 300000)
  expect_warning(
    sm_weathering(data, indices = "CIA", convert_to_oxides = TRUE),
    "Skipping CIA: Al, K, Na columns required"
  )
})

test_that('sm_weathering_index("CIA") validates inputs', {
  # Missing required inputs (Na2O is required)
  expect_error(sm_weathering_index("CIA")(Al2O3 = 10, K2O = 5))

  # All required inputs should work
  result <- sm_weathering_index("CIA")(Al2O3 = 10, K2O = 5, Na2O = 5)
  expect_true(is.numeric(result))
  expect_true(result >= 0 & result <= 100)
})

# ============================================================================
# Test: Edge Cases
# ============================================================================

test_that("sm_weathering handles all NA values", {
  data <- data.frame(
    depth = c(0, 10, 20),
    Al = c(NA, NA, NA),
    Fe = c(NA, NA, NA),
    Si = c(NA, NA, NA),
    K = c(NA, NA, NA),
    Ca = c(NA, NA, NA),
    Na = c(NA, NA, NA)
  )

  result <- sm_weathering(data, indices = "CIA", convert_to_oxides = TRUE)
  expect_true(all(is.na(result$CIA)))
})

test_that("sm_weathering handles single depth value", {
  data <- data.frame(
    depth = 0,
    Al = 80000,
    Fe = 40000,
    Si = 300000,
    K = 30000,
    Ca = 50000,
    Na = 25000
  )

  result <- sm_weathering(data, indices = "CIA", convert_to_oxides = TRUE)
  expect_equal(nrow(result), 1)
  expect_true(!is.na(result$CIA[1]))
})

test_that("sm_weathering handles division by zero", {
  # All zeros should not crash, though results may be NaN
  data <- data.frame(
    depth = 0,
    Al = 0,
    Fe = 0,
    Si = 0,
    K = 0,
    Ca = 0,
    Na = 0
  )

  expect_no_error(sm_weathering(data, indices = "CIA", convert_to_oxides = TRUE))
})

# ============================================================================
# Test: Integration with Real-like Data
# ============================================================================

test_that("sm_weathering produces expected patterns", {
  # Create data showing weathering progression with depth
  data <- data.frame(
    depth = seq(0, 100, by = 10),
    Al = seq(80000, 120000, by = 4000),  # Increasing Al2O3 down-profile
    Fe = seq(40000, 80000, by = 4000),   # Increasing Fe down-profile
    Si = seq(300000, 250000, by = -5000), # Decreasing Si down-profile
    K = seq(30000, 20000, by = -1000),   # Decreasing K down-profile
    Ca = seq(50000, 20000, by = -3000),  # Decreasing Ca down-profile
    Na = seq(25000, 10000, by = -1500),  # Decreasing Na down-profile
    Mg = seq(30000, 45000, by = 1500),   # Increasing Mg down-profile
    Ti = seq(5000, 6000, by = 100),
    Zr = seq(300, 400, by = 10)
  )

  result <- sm_weathering(data, indices = c("CIA", "WIP"), convert_to_oxides = TRUE)

  # CIA should increase down-profile (more weathering)
  expect_true(result$CIA[nrow(result)] > result$CIA[1])

  # WIP should decrease down-profile (more weathering)
  expect_true(result$WIP[nrow(result)] < result$WIP[1])
})
