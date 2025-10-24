# 03i: Weathering Indices from Elemental Data

## Objective
Implement soil weathering intensity indices from pXRF elemental measurements for characterizing soil maturity, pedogenesis stage, and landscape-scale weathering trends.

## Current State
- Phase 3g/3h process multivariate elemental data
- No weathering quantification
- No standardized indices
- Manual interpretation common

## Motivation
- pXRF provides Al, Fe, Si, K, Ca, Ti, Zr fast/inexpensively
- Weathering indices synthesize multi-element information
- Enable quantitative weathering characterization
- Useful for landscape modeling, paleoclimate inference

## Deliverables

### D1: Core Weathering Indices
**Files:** `R/weathering.R` (new file)

1. **Implement standard indices:**

   **Chemical Index of Alteration (CIA):**
   ```r
   CIA <- function(Al2O3_mol, K2O_mol, Na2O_mol, CaO_mol) {
       # CIA = Al2O3 / (Al2O3 + K2O + Na2O) * 100
       # Range: 50 (unweathered) to 100 (fully weathered)
   }
   ```

   **Weathering Index of Parker (WIP):**
   ```r
   WIP <- function(K_mol, Na_mol, Ca_mol, Mg_mol) {
       # WIP = (K/(K+Na) + Na/(K+Na) + 2*Ca/(Ca+Mg)) * 100
       # Accounts for element mobility
   }
   ```

   **Plagioclase Index of Alteration (PIA):**
   ```r
   PIA <- function(Al2O3_mol, Na2O_mol, K2O_mol, CaO_mol) {
       # PIA = (Al2O3 - K2O) / (Al2O3 + CaO - K2O) * 100
       # Focuses on feldspar weathering
   }
   ```

   **Silica-Alumina Index (SAR):**
   ```r
   SAR <- function(SiO2_mol, Al2O3_mol) {
       # SAR = SiO2 / Al2O3
       # Higher values = more primary minerals
   }
   ```

   **Zirconium-Titanium Ratio (ZrTi):**
   ```r
   ZrTi <- function(Zr_ppm, Ti_ppm) {
       # ZrTi = Zr / Ti
       # Both immobile; ratio indicates fractionation during weathering
   }
   ```

   **Iron Accumulation Index (FAR):**
   ```r
   FAR <- function(Fe_ppm, parent_Fe_ppm = 50000) {
       # FAR = Fe_present / Fe_parent
       # Indicates Fe enrichment (lateritization)
   }
   ```

2. **Input format:**
   ```r
   weathering_indices <- function(data,
                                   element_cols = NULL,
                                   indices = "all",
                                   convert_to_oxides = TRUE,
                                   parent_composition = NULL) {
       # data: data.frame or matrix with depth, elements
       # element_cols: which columns to use (auto-detect if NULL)
       # indices: vector of indices to compute ("CIA", "WIP", "PIA", "SAR", "ZrTi", "FAR", "all")
       # convert_to_oxides: if ppm → oxide weight%
       # parent_composition: reference material for normalization
       
       # Return: data.frame with depth + all requested indices
   }
   ```

### D2: Derived Index Combinations
**Files:** `R/weathering.R`

1. **Multivariate weathering scores:**

   **Integrated Weathering Index (IWI):**
   ```r
   integrated_weathering_index <- function(CIA, WIP, PIA) {
       # Combine major indices into single 0-1 score
       # Normalize each to [0,1], average
       # Higher = more weathered
   }
   ```

   **Stage-based classification:**
   ```r
   weathering_stage <- function(CIA, WIP, parent_composition = NULL) {
       # Return factor: "fresh", "slightly_altered", "moderate", "intense", "laterite"
       # Based on threshold logic on CIA/WIP values
   }
   ```

2. **Landscape interpretation:**
   ```r
   weathering_interpretation <- function(indices_df, climate = "temperate") {
       # climate: "tropical", "temperate", "arid", "cold"
       # Return: list(stage, climate_match, mineral_residue, recommendations)
       # e.g., "CIA=80 + WIP=65 suggests strong hydrolysis, tropical/subtropical"
   }
   ```

### D3: Elemental Depletion/Enrichment
**Files:** `R/weathering.R`

1. **Depletion trends:**
   ```r
   element_depletion <- function(data, element_cols = NULL,
                                  parent_composition = NULL,
                                  immobile_element = "Zr") {
       # Normalize moveable elements to immobile (Zr, Ti)
       # Depletion factor = present_conc / parent_conc * (parent_immobile / present_immobile)
       # Return: data.frame(depth, element, depletion_factor)
   }
   ```

2. **Clay-rich accumulation:**
   ```r
   clay_accumulation_index <- function(data, element_cols = NULL) {
       # Based on Al accumulation (clay indicator)
       # And depletion of mobile elements (K, Na, Ca, Mg)
       # Return: depth profile of accumulation intensity
   }
   ```

### D4: Visualization of Weathering Trends
**Files:** `R/visualization.R`

1. **Depth profile plot:**
   ```r
   plot_weathering_indices <- function(indices_df, facet_indices = TRUE) {
       # Multiple lines (one per index) vs depth
       # Or faceted (each index in separate panel)
       # Highlight weathering stages as horizontal bands
   }
   ```

2. **Ternary/scatter relationships:**
   ```r
   plot_weathering_ternary <- function(CIA, WIP, PIA) {
       # Ternary plot showing sample positions
       # Colored by depth or horizon
       # Reference weathering trend lines
   }
   
   plot_CIA_WIP <- function(indices_df) {
       # Scatter: CIA vs WIP
       # Regions: weathering pathways
       # Label field regions: feldspar, mica, clay minerals
   }
   ```

3. **Element mobility diagram:**
   ```r
   plot_element_mobility <- function(depletion_df) {
       # Heatmap: depth vs element depletion factor
       # Color intensity = depletion (cooler = depleted, hotter = enriched)
   }
   ```

### D5: Benchmark Comparisons
**Files:** `R/weathering.R`

1. **Reference parent materials:**
   ```r
   parent_materials <- tibble::tribble(
       ~name, ~SiO2, ~Al2O3, ~K2O, ~Na2O, ~CaO, ~MgO, ~Fe2O3,
       "granitic", 72, 14, 4.5, 3.5, 1.5, 0.8, 2.5,
       "basaltic", 50, 15, 0.5, 2.0, 10, 8, 12,
       "sedimentary", 65, 15, 3, 2.5, 3, 2.5, 5,
   )
   
   normalize_to_parent <- function(data, element_cols = NULL,
                                    parent_name = "granitic") {
       # Normalize observed concentrations to parent material
       # Return: depletion factors relative to parent
   }
   ```

### D6: Integration with Horizons (Phase 3g/3h)
**Files:** `R/weathering.R`

1. **Assign indices to classified horizons:**
   ```r
   weathering_by_horizon <- function(indices_df, fuzzy_classifications) {
       # For each horizon (from 03h):
       # Aggregate weathering indices (mean/median within horizon)
       # Return: summary by horizon type
   }
   ```

2. **Vertical weathering progression:**
   ```r
   weathering_progression <- function(indices_df) {
       # Describe vertical trend in CIA/WIP/etc
       # Return: "decreasing" (younger parent material with depth),
       #         "increasing" (more intense weathering at surface),
       #         "stable" (homogeneous weathering)
   }
   ```

### D7: Export and Reporting
**Files:** `R/weathering.R`

1. **Summary report:**
   ```r
   weathering_summary <- function(indices_df, fuzzy_classifications = NULL,
                                   title = "Soil Weathering Analysis") {
       # Return: tibble with key statistics
       # - Surface CIA, WIP, stage
       # - Subsurface CIA, WIP, stage
       # - Weathering progression
       # - Clay enrichment
       # - Recommendations for interpretation
   }
   ```

## Implementation Steps

1. Implement core weathering index formulas (CIA, WIP, PIA, SAR, ZrTi, FAR)
2. Create multivariate combinations (IWI, staging)
3. Implement element depletion calculations
4. Create visualization functions
5. Add reference parent materials
6. Integrate with phase 3h fuzzy classification
7. Test on pXRF reference soils (known weathering stages)
8. Add roxygen documentation with pedologic context
9. Create vignette: "Soil Weathering from pXRF"
10. Run full test suite

## Success Criteria
- [ ] Core indices correctly computed
- [ ] Multivariate combinations sensible
- [ ] Depletion factors reasonable
- [ ] Visualizations clear and interpretable
- [ ] Parent material normalization working
- [ ] Horizon integration functional
- [ ] Documentation with soil examples
- [ ] Reference database included
- [ ] Vignette demonstrates workflow
- [ ] All tests passing

## Files to Review
- Phase 3g: Mahalanobis boundaries
- Phase 3h: Fuzzy classification
- R/visualization.R (for plotting patterns)

## Pedologic Context

**CIA values:**
- 50-60: Fresh, minimal weathering
- 60-75: Moderate weathering
- 75-85: Strong weathering
- 85-100: Intense weathering, laterite

**WIP values:**
- 100: No weathering (primary minerals only)
- 60-80: Moderate weathering
- 20-60: Strong weathering
- <20: Intense weathering

**Climate interpretation:**
- Tropical: CIA rises rapidly (strong hydrolysis)
- Temperate: CIA moderate increase (slow weathering)
- Arid: CIA low throughout (minimal weathering)
- Cold: CIA low (physical weathering > chemical)

## Related Prompts
- 03g: Mahalanobis Boundaries (uses same element data)
- 03h: Fuzzy Classification (uses same element data)
