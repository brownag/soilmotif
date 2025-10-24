# 03j: Correlation Networks and Pattern Analysis

## Objective
Implement multivariate correlation analysis and graph-based pattern discovery from fitted soil motifs and elemental data to identify soil property relationships and pedogenic processes.

## Current State
- Phase 3a-3e focus on single-profile optimization and uncertainty
- Phase 3g-3i analyze elemental data (boundaries, fuzzy classification, weathering)
- No cross-property correlation analysis
- No network-based pattern discovery
- No element-property relationship characterization

## Motivation
- Soil properties correlated through shared pedogenic processes
- Graph representation reveals process pathways
- Element concentrations drive clay/Fe/carbonate accumulation
- Community detection identifies co-varying property groups
- Enables predictive modeling (see Phase 4: 04a)

## Deliverables

### D1: Correlation Matrix Computation
**Files:** `R/correlation.R` (new file)

1. **Multivariate correlation:**
   ```r
   compute_correlation_matrix <- function(data,
                                           var_cols = NULL,
                                           method = "pearson",
                                           use = "complete.obs") {
       # data: data.frame with multiple depth functions/properties
       # var_cols: columns to correlate (auto-detect if NULL)
       # method: "pearson", "spearman", "kendall"
       # use: "complete.obs", "pairwise.complete.obs"
       
       # Return: list(
       #   correlation: matrix of correlations
       #   p_values: matrix of p-values
       #   n_obs: matrix of n per pair
       # )
   }
   ```

2. **Depth-stratified correlation:**
   ```r
   correlation_by_horizon <- function(data, horizon_assignments,
                                       var_cols = NULL) {
       # Compute correlations separately for each horizon
       # Return: list of correlation matrices (one per horizon)
   }
   ```

### D2: Network Construction
**Files:** `R/correlation.R`

1. **Graph from correlation:**
   ```r
   correlation_to_network <- function(corr_matrix,
                                       p_values = NULL,
                                       threshold_r = 0.5,
                                       threshold_p = 0.05,
                                       min_strength = 0.01) {
       # Create igraph network from correlation matrix
       # Nodes: soil properties/elements
       # Edges: correlations (weight = |r|, color = sign)
       # Threshold: only include |r| > threshold_r and p < threshold_p
       
       # Return: igraph object with attributes
       #   - edge$weight: correlation strength
       #   - edge$sign: "positive" or "negative"
       #   - node$type: "property" vs "element"
       #   - node$category: "clay", "iron", "element", etc.
   }
   ```

2. **Network statistics:**
   ```r
   network_statistics <- function(network) {
       # Return: list(
       #   n_nodes: number of properties
       #   n_edges: number of correlations
       #   density: (n_edges) / (n_nodes * (n_nodes-1) / 2)
       #   avg_degree: mean connections per node
       #   clustering_coefficient: local clustering
       #   modularity: community structure strength
       #   connected_components: number of separate subgraphs
       # )
   }
   ```

### D3: Community Detection
**Files:** `R/correlation.R`

1. **Identify property groups:**
   ```r
   detect_communities <- function(network, algorithm = "louvain") {
       # algorithm: "louvain" (default, fast), "walktrap", "infomap"
       # Identify communities (co-varying property groups)
       # Community = properties that vary together
       
       # Return: data.frame(node, community_id, modularity_contribution)
   }
   ```

2. **Interpret communities:**
   ```r
   interpret_communities <- function(communities, network) {
       # For each community:
       # - List member nodes
       # - Identify shared variance drivers
       # - Suggest pedogenic process
       #
       # Example:
       # Community 1: Clay, Al, Fe, CEC
       #   → "Clay-metal accumulation (B horizon processes)"
       # Community 2: K, Na, pH
       #   → "Base saturation (weathering stage)"
   }
   ```

### D4: Network Visualization
**Files:** `R/visualization.R`

1. **Interactive network plot:**
   ```r
   plot_correlation_network <- function(network, communities = NULL,
                                         layout = "fr", node_size = "degree") {
       # Nodes: soil properties (size = degree, color = community)
       # Edges: correlations (thickness = |r|, color = positive/negative)
       # Layout: Fruchterman-Reingold or Spring (physics-based)
       # Interactive: hover for correlation value, click for details
   }
   ```

2. **Correlation heatmap:**
   ```r
   plot_correlation_heatmap <- function(corr_matrix,
                                         order_by = "hierarchical",
                                         threshold_p = 0.05) {
       # Heatmap: color-coded correlations
       # Order: hierarchical clustering or custom
       # Mark non-significant correlations (p >= threshold)
       # Include p-values as text overlay (option)
   }
   ```

3. **Community-focused plots:**
   ```r
   plot_community_details <- function(network, communities, community_id) {
       # Subgraph for single community
       # Show all edges within community (strong visualization)
       # Annotate with correlation values
   }
   ```

### D5: Property Relationship Inference
**Files:** `R/correlation.R`

1. **Causal inference (observational):**
   ```r
   infer_relationship_direction <- function(network, var1, var2,
                                             confounder_candidates = NULL) {
       # Attempt to infer direction (A→B vs B→A)
       # Use: conditional independence tests
       # If A → B: then C independent of B given A
       
       # Return: list(relationship = "A→B" or "B→A" or "bidirectional",
       #              confidence = 0-1,
       #              potential_confounders = ...)
   }
   ```

2. **Mediation analysis:**
   ```r
   mediation_analysis <- function(network, independent, dependent,
                                   mediators = NULL) {
       # Decompose correlation into direct + indirect paths
       # indirect = paths through mediators
       # direct = remaining correlation
       
       # Return: data.frame(path, effect_size, pct_mediated)
   }
   ```

### D6: Integration with Motifs and Elements
**Files:** `R/correlation.R`

1. **Motif-element associations:**
   ```r
   correlate_motifs_with_elements <- function(motif_params, element_profiles,
                                               depth_col = "depth") {
       # Link fitted motif parameters to element concentrations
       # Example: sigmoid shape parameter (inflection depth) vs Fe/Al accumulation
       
       # Return: correlation matrix (motif_param x element)
   }
   ```

2. **Motif parameter network:**
   ```r
   motif_parameter_network <- function(multiple_fits) {
       # Across multiple profiles, correlate motif parameters
       # high_correlation between params → coupled processes
       # Example: clay_inflection ↔ Fe_peak (same pedogenic driver)
       
       # Return: network + interpretation
   }
   ```

### D7: Export and Reporting
**Files:** `R/correlation.R`

1. **Summary statistics:**
   ```r
   correlation_summary <- function(corr_matrix, threshold_r = 0.5,
                                    threshold_p = 0.05) {
       # Return: tibble with strongest correlations
       # Columns: var1, var2, r, p_value, n_obs, interpretation
   }
   ```

2. **Network report:**
   ```r
   network_report <- function(network, communities = NULL,
                               title = "Soil Property Network") {
       # Return: formatted report
       # - Network summary statistics
       # - Community interpretations
       # - Key correlations
       # - Recommendations for interpretation
   }
   ```

## Implementation Steps

1. Implement correlation matrix computation (standard R stats)
2. Create network from correlation (igraph)
3. Implement community detection (igraph algorithms)
4. Interpret communities (heuristic rules + manual annotation)
5. Create interactive visualizations (visNetwork or ggraph)
6. Add causal/mediation inference (experimental, with caveats)
7. Implement motif-element integration
8. Test on full case study (multiple profiles + elements)
9. Add roxygen documentation
10. Create vignette: "Correlation Networks and Pedogenic Processes"
11. Run full test suite

## Success Criteria
- [ ] Correlation matrices computed correctly
- [ ] Network construction robust (handles disconnected components)
- [ ] Community detection meaningful (high modularity)
- [ ] Visualizations clear and interactive
- [ ] Causal inference produces reasonable results (with caveats)
- [ ] Motif-element integration functional
- [ ] Documentation with pedologic examples
- [ ] Vignette demonstrates end-to-end workflow
- [ ] All tests passing

## Files to Review
- Phase 3a-3e (motif fitting, optimization)
- Phase 3g-3i (elemental data, weathering)
- R/visualization.R (plotting patterns)

## External Dependencies
- igraph: Network construction/analysis
- visNetwork or ggraph: Visualization
- tidygraph: tidyverse-friendly graph manipulation
- igraph functions: cluster_louvain, cluster_walktrap, as_tibble

## Interpretation Notes

**Property groups to expect:**
- **Clay accumulation**: Clay, CEC, Al, Fe, Si (mobile depletion)
- **Base saturation**: K, Na, pH, BS%
- **Oxidation state**: Fe2O3, Fe3O4, Mn (redox environment)
- **Weathering stage**: CIA, WIP, mineral composition
- **Horizonation**: Property variance (high within horizons, low between)

**Causal caveats:**
- Correlation ≠ causation
- Multiple pathways possible (A→B and C→A→B)
- Confounders (climate, parent material) affect all
- Use with domain knowledge for interpretation

## Related Prompts
- 03e: Uncertainty (bootstrap-driven network robustness)
- 03g-3i: Analysis track (correlation sources)
- 04a: Predictive Modeling (uses communities for feature grouping)
