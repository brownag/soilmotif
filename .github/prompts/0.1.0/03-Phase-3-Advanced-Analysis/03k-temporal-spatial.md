# 03k: Time Series and Spatial Scaling Analysis

## Objective
Implement temporal dynamics and spatial scaling of soil profiles—modeling how soil properties change across time (pedogenic development) and space (landscape positions, catenas).

## Current State
- Phase 3a-3e optimize single-profile, single-time models
- Phase 3g-3j analyze cross-section / single-time data
- No temporal modeling (pedogenic development)
- No spatial cross-correlation (catena analysis)
- No scale-dependent property relationships

## Motivation
- Soils evolve over centuries-millennia (pedogenesis)
- Soil properties co-vary with topography (catenas)
- Scaling relationships: local properties → landscape patterns
- Enables landscape soil surveys, prediction across unmeasured sites
- Foundation for Phase 4 predictive modeling

## Deliverables

### D1: Temporal Motif Sequences
**Files:** `R/temporal.R` (new file)

1. **Model pedogenic development:**
   ```r
   temporal_motif_sequence <- function(motif_series,
                                        ages_ka = NULL,
                                        time_unit = "ka") {
       # motif_series: list of fitted motifs across different profiles/times
       # ages_ka: vector of ages (kilo-years before present, or NULL)
       # time_unit: "ka" (kilo-years), "years", "relative" (1,2,3,...)
       
       # Track how motif parameters evolve over time:
       # - Clay accumulation depth deepens over time (B horizon develops)
       # - Fe concentration increases (oxidation)
       # - pH changes (acid horizon development)
       
       # Return: data.frame(time, shape, param1, param2, ..., interpretation)
   }
   ```

2. **Time series trend analysis:**
   ```r
   estimate_pedogenic_rate <- function(property_profile_series, ages_ka) {
       # Estimate rate of property change per 1000 years
       # Example: clay at 30cm increases from 15% → 25% over 10ka
       #          rate = 1% clay per ka
       
       # Return: data.frame(property, depth, rate_per_ka, uncertainty)
   }
   ```

### D2: Catena Analysis
**Files:** `R/spatial.R` (new file)

1. **Profile positioning in landscape:**
   ```r
   position_in_catena <- function(profiles,
                                   elev_m = NULL,
                                   lon = NULL,
                                   lat = NULL,
                                   landform_position = NULL) {
       # profiles: list of SoilProfileCollection or fitted motifs
       # elev_m, lon, lat: coordinates (optional)
       # landform_position: "summit", "shoulder", "backslope", "footslope", "toeslope"
       
       # Classify each profile in landscape context
       # Return: data.frame(profile_id, position, elevation, properties, notes)
   }
   ```

2. **Cross-slope property gradients:**
   ```r
   catena_property_gradient <- function(profiles, position_order = NULL,
                                         property_cols = NULL) {
       # profiles: ordered list from summit to toeslope
       # position_order: "summit" → "toeslope"
       # property_cols: which properties to track (auto-detect if NULL)
       
       # Example: clay content typically lowest at summit, highest at toeslope
       #          due to lateral water/colluvial transport
       
       # Return: data.frame(position, depth, property, value, gradient_direction)
   }
   ```

3. **Water flow pathways:**
   ```r
   water_flow_implications <- function(catena_gradients) {
       # Interpret catena patterns in terms of water flow
       # Upslope: water loss (drying) → lower clay, higher gravel
       # Downslope: water gain (saturation) → higher clay, lower Fe (gleying)
       # Footslope: colluvial inputs → mixed properties
       
       # Return: list(pathways, saturation_zones, colluvial_areas, interpretations)
   }
   ```

### D3: Spatial Autocorrelation
**Files:** `R/spatial.R`

1. **Moran's I for properties:**
   ```r
   spatial_autocorrelation <- function(profiles, lon, lat,
                                        property_cols = NULL,
                                        max_distance_m = NULL) {
       # Compute Moran's I for each property
       # Indicates spatial clustering (I > 0) or dispersion (I < 0)
       
       # Example:
       # - Clay content: I = 0.6 (strong spatial clustering)
       # - pH: I = 0.2 (weak clustering)
       
       # Return: data.frame(property, depth, morans_i, p_value, interpretation)
   }
   ```

2. **Semi-variogram analysis:**
   ```r
   semivariogram <- function(profiles, lon, lat,
                              property_col, depth_m = NULL,
                              max_distance_m = 1000,
                              distance_bins = 10) {
       # Compute spatial semi-variance
       # Gamma(h) = 0.5 * mean((Z(x) - Z(x+h))^2)
       # Shows spatial structure scale (nugget, range, sill)
       
       # Return: data.frame(distance, semivariance, binned_count)
   }
   ```

3. **Kriging predictions:**
   ```r
   krige_soil_property <- function(profiles, lon, lat,
                                    property_col, depth_m = NULL,
                                    pred_grid = NULL) {
       # Ordinary kriging to predict property at unmeasured locations
       # Uses variogram from semivariogram()
       
       # Return: list(predictions, standard_errors, variogram_model)
   }
   ```

### D4: Profile Similarity and Clustering
**Files:** `R/spatial.R`

1. **Dissimilarity metrics:**
   ```r
   profile_dissimilarity <- function(profile_1, profile_2,
                                      depth_range = c(0, 200),
                                      metric = "DSMART") {
       # metric: "DSMART" (Default Soil Motif ARea Trimmed),
       #         "euclidean", "correlation", "shape_distance"
       
       # DSMART: combines shape + depth + intensity differences
       # Return: single dissimilarity score ∈ [0,1]
   }
   ```

2. **Cluster profiles across space:**
   ```r
   cluster_profiles_spatial <- function(profiles, lon, lat,
                                         n_clusters = 5,
                                         method = "hierarchical") {
       # method: "hierarchical", "kmeans", "dbscan"
       # Identify groups of similar profiles in space
       
       # Return: data.frame(profile_id, cluster, position, lon, lat)
       #   + heatmap showing within-cluster similarity
   }
   ```

### D5: Cross-Scale Relationships
**Files:** `R/scaling.R` (new file)

1. **Local-to-landscape scaling:**
   ```r
   extract_scaling_laws <- function(local_profiles, landscape_summary) {
       # local_profiles: detailed depth functions (cm scale)
       # landscape_summary: aggregated properties (plot/field scale)
       
       # Identify relationships:
       # - Local clay peak depth ↔ landscape relief
       # - Local Fe concentration ↔ landscape wetness index
       # - Local particle size ↔ landscape position
       
       # Return: data.frame(local_var, landscape_var, correlation, power_law_exponent)
   }
   ```

2. **Self-similar scaling:**
   ```r
   fractal_scaling <- function(property_profile) {
       # Test if profile exhibits fractal/self-similar structure
       # Compute spectral exponent from depth FFT
       # Brown noise (like soils) has exponent ≈ 1
       
       # Return: list(exponent, confidence, interpretation)
   }
   ```

### D6: Integration with Motifs and Weathering
**Files:** `R/temporal.R`, `R/spatial.R`

1. **Temporal motif evolution:**
   ```r
   motif_temporal_dynamics <- function(motif_series, ages_ka) {
       # Track shape transitions:
       # Young soil: "uniform" (little differentiation)
       # Intermediate: "gradational" (developing accumulation)
       # Old soil: "exponential" or "abrupt" (strong accumulation)
       
       # Return: transitions + timing + drivers
   }
   ```

2. **Weathering index across catena:**
   ```r
   weathering_catena_trend <- function(weathering_indices, position_order) {
       # Typical pattern:
       # Upslope: higher weathering (longer exposure to water)
       # Downslope: lower weathering (recent deposition)
       # + topographic corrections (slope aspect, relief)
       
       # Return: predicted weathering intensity vs position
   }
   ```

### D7: Export and Reporting
**Files:** `R/temporal.R`, `R/spatial.R`

1. **Temporal summary:**
   ```r
   temporal_report <- function(temporal_sequence) {
       # Return: formatted report
       # - Pedogenic rates by property
       # - Time to reach current state (model-based estimate)
       # - Uncertainty in age/timing
   }
   ```

2. **Catena summary:**
   ```r
   catena_report <- function(catena_data, weathering = NULL) {
       # Return: formatted report
       # - Profile descriptions by position
       # - Water flow interpretation
       # - Soil formation drivers
   }
   ```

3. **Spatial map:**
   ```r
   plot_spatial_properties <- function(profiles, lon, lat,
                                        property_col, depth_m = NULL,
                                        include_kriging = TRUE) {
       # Map with profile locations + measured values
       # Optional kriged surface overlay
       # Contours of predicted property values
   }
   ```

## Implementation Steps

1. Implement temporal motif sequence tracking
2. Estimate pedogenic rates from time series
3. Implement catena positioning logic
4. Implement property gradient calculation across catena
5. Implement Moran's I autocorrelation
6. Implement semivariogram and kriging (use gstat package)
7. Implement profile dissimilarity metrics (DSMART-like)
8. Implement clustering and spatial grouping
9. Implement scaling law extraction
10. Add fractal analysis (optional, experimental)
11. Create visualizations (faceted depth × position, maps, variograms)
12. Test on published catena datasets
13. Add roxygen documentation
14. Create vignette: "Pedogenesis and Landscape Soil Patterns"
15. Run full test suite

## Success Criteria
- [ ] Temporal motif sequences meaningful (consistent pedogenic trends)
- [ ] Pedogenic rates plausible (cm clay deepening per ka, etc.)
- [ ] Catena gradients correct (property trends with position)
- [ ] Water flow interpretation logical
- [ ] Spatial autocorrelation computed correctly
- [ ] Kriging predictions reasonable
- [ ] Profile clustering coherent
- [ ] Scaling laws identified
- [ ] Fractal analysis (if implemented) produces interpretable results
- [ ] Visualizations clear and publication-ready
- [ ] Documentation with soil science context
- [ ] Vignette demonstrates full workflow
- [ ] All tests passing

## Files to Review
- Phase 3a-3e (motif fitting)
- Phase 3g-3i (elemental data, weathering)
- Phase 3j (correlation networks)
- R/visualization.R (plotting patterns)

## External Dependencies
- gstat: Kriging, variogram analysis
- sp or sf: Spatial data handling
- raster: Raster operations (optional)

## Pedologic Context

**Catena concepts:**
- Upslope: eluviation (leaching), lower clay, drier
- Midslope: transition, mixed
- Downslope: illuviation (accumulation), higher clay, wetter
- Toeslope: colluvial, variable

**Temporal trends (millions of years):**
- 0-1 ka: minimal horizonation, weak B
- 1-10 ka: clear B horizon, clay accumulation starts
- 10-100 ka: strong clay enrichment, thick B
- 100+ ka: intense weathering, laterization (tropics)

**Spatial scales:**
- Pedon (1 m²): local heterogeneity
- Polypedon (10-100 m): soil series
- Catena (100-1000 m): slope sequence
- Landscape (1-10 km): regional variation

## Related Prompts
- 03e: Uncertainty (propagates into time/space predictions)
- 03i: Weathering Indices (temporal evolution)
- 03j: Correlation Networks (temporal structure)
- 04a: Predictive Modeling (uses scaling relationships)
