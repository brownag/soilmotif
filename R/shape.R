# select from a set of pre-determined shape models
# or define your own custom function/parameters

#' @importFrom stats dnorm plogis
#' @title Sigmoid Shape Function
#' @description Models an S-shaped curve with smooth transition between depths. Useful for wetting fronts, reaction fronts, and gradual pedogenic changes.
#'
#' @param x numeric. Depth vector (typically 1 to 200 cm, increasing downward).
#' @param params numeric. Parameters: c(depth_inflection_start, depth_inflection_end).
#'   - depth_inflection_start: Upper depth (cm) where transition begins (typically 20-80 cm)
#'   - depth_inflection_end: Lower depth (cm) where transition completes (typically 40-150 cm)
#'   Both depths should be within the range of x and depth_inflection_start < depth_inflection_end.
#' @param ascending logical. If TRUE, property increases with depth (e.g., clay accumulation in Bt horizon).
#'   If FALSE, property decreases with depth (e.g., carbonate leaching).
#'
#' @return numeric vector in the range 0 to 1 representing the shape function, where 0 indicates
#'   minimal expression of the property and 1 indicates maximal expression.
#' @details
#' The sigmoid shape represents gradual transitions typical of pedogenic processes where
#' soil-forming factors change smoothly over depth. Common applications include:
#'
#' \strong{Soil Science Context:}
#' - \strong{Wetting fronts:} Moisture redistribution creating smooth chemical gradients
#' - \strong{Clay translocation:} Illuvial clay accumulation (Bt horizons) with gradual boundaries
#' - \strong{Carbonate leaching:} Progressive dissolution of carbonates with depth
#' - \strong{Redoximorphic features:} Gradual changes in reduction/oxidation zones
#'
#' \strong{Parameter Interpretation:}
#' - The inflection zone (between start and end depths) represents the active pedogenic layer
#' - Steeper transitions (smaller depth range) indicate more abrupt soil changes
#' - Shallower transitions suggest surface-influenced processes
#' - Deeper transitions indicate groundwater or saprolite influences
#'
#' \strong{Valid Ranges:} Depth parameters should be within soil profile depth (typically 0-200 cm).
#' Parameter order matters: start_depth < end_depth for ascending profiles.
#' @export
#' @seealso \code{\link{sm_motif}}, \code{\link{sm_optim}}, \code{\link{sm_shape_wetting_front}}
#' @examples
#' # Clay accumulation in Bt horizon (typical argillic horizon)
#' depths <- 1:150
#' clay_profile <- sm_shape_sigmoid(depths, c(40, 90))  # Transition 40-90 cm
#' plot(clay_profile, depths, ylim = c(150, 0), type = "l",
#'      xlab = "Clay Content", ylab = "Depth (cm)",
#'      main = "Argillic Horizon Clay Accumulation")
#'
#' # Carbonate leaching front (decreasing with depth)
#' carbonate_profile <- sm_shape_sigmoid(depths, c(30, 80), ascending = FALSE)
#' plot(carbonate_profile, depths, ylim = c(150, 0), type = "l",
#'      xlab = "Carbonate Content", ylab = "Depth (cm)",
#'      main = "Carbonate Leaching Zone")
sm_shape_sigmoid <- function(x, params, ascending = TRUE) {
  num2 <- sum(params) / 2
  num <- vector("numeric", length(x))
  num[x < num2] <- (2 * ((x[x < num2] - params[1]) / (params[2] - params[1])) ^ 2)
  num[x >= num2] <- 1 - (2 * ((x[x >= num2] - params[2]) / (params[2] - params[1])) ^ 2)
  num[x < params[1]] <- 0
  num[x > params[2]] <- 1
  if (!ascending)
    return(1 - num)
  num
}

#' Uniform Shape Function
#'
#' Models a constant value at all depths. Useful for undeveloped or mixed soils.
#'
#' @param x numeric. Depth vector (cm, increasing downward).
#' @param params numeric. Parameters: c(mean_value).
#'   - mean_value: Constant property value (0-1 range, where 0 = minimal, 1 = maximal expression).
#' @param ascending logical. If FALSE, inverts the constant value (1 - mean_value).
#'
#' @return numeric vector with constant value in the range 0 to 1 representing uniform property distribution.
#' @details
#' The uniform shape represents soils with minimal pedogenic differentiation or consistent
#' properties throughout the profile. Common applications include:
#'
#' \strong{Soil Science Context:}
#' - \strong{Undeveloped soils:} Young soils with minimal horizon differentiation (Entisols)
#' - \strong{Mixed profiles:} Anthropogenically mixed soils (Anthrosols)
#' - \strong{Homogeneous parent materials:} Uniform bedrock or sediment
#' - \strong{Reference profiles:} Baseline for comparison with differentiated soils
#'
#' \strong{Parameter Interpretation:}
#' - High values (near 1) indicate strong expression of the property throughout
#' - Low values (near 0) indicate minimal expression of the property
#' - The uniform shape serves as a null model for pedogenic processes
#'
#' \strong{Valid Ranges:} mean_value should be in the range 0 to 1. Use ascending=FALSE to invert the interpretation.
#' @export
#' @seealso \code{\link{sm_motif}}, \code{\link{sm_optim}}
#' @examples
#' # Well-mixed anthropogenic soil (constant properties)
#' depths <- 1:100
#' mixed_soil <- sm_shape_uniform(depths, 0.7)  # 70% clay throughout
#' plot(mixed_soil, depths, ylim = c(100, 0), type = "l",
#'      xlab = "Clay Content", ylab = "Depth (cm)",
#'      main = "Anthropogenic Mixing")
#'
#' # Minimal clay content throughout (sandy soil)
#' sandy_soil <- sm_shape_uniform(depths, 0.1)  # 10% clay throughout
#' plot(sandy_soil, depths, ylim = c(100, 0), type = "l",
#'      xlab = "Clay Content", ylab = "Depth (cm)",
#'      main = "Sandy Entisol")
sm_shape_uniform <- function(x, params, ascending = TRUE) {
  shape <- rep(params[1], length(x))
  if (!ascending) {
    shape <- 1 - shape
  }
  shape
}

#' Gradational Shape Function
#'
#' Models a linear or smooth change with depth. Useful for steady accumulation processes.
#'
#' @param x numeric. Depth vector (cm, increasing downward).
#' @param params numeric. Parameters: c(start_depth, end_depth).
#'   - start_depth: Upper depth (cm) where property begins changing (typically 0-100 cm)
#'   - end_depth: Lower depth (cm) where property reaches final value (typically 50-200 cm)
#' @param ascending logical. If TRUE, property increases linearly from 0 at start_depth to 1 at end_depth.
#'   If FALSE, decreases from 1 at start_depth to 0 at end_depth.
#' @param type character. "linear" (default) or "smooth" (polynomial).
#'
#' @return numeric vector in the range 0 to 1 representing linear property change with depth.
#' @details
#' The gradational shape represents steady, directional changes typical of many pedogenic
#' processes. Common applications include:
#'
#' \strong{Soil Science Context:}
#' - \strong{Organic matter decrease:} Steady decline from surface to depth
#' - \strong{Clay increase:} Gradual accumulation through illuviation
#' - \strong{pH changes:} Progressive acidification or alkalinization
#' - \strong{Texture changes:} Gradual fining or coarsening of particles
#'
#' \strong{Parameter Interpretation:}
#' - The depth range (end_depth - start_depth) indicates the thickness of the active zone
#' - Steeper gradients (smaller depth ranges) suggest more intense pedogenesis
#' - Shallower transitions indicate surface-controlled processes
#' - The direction (ascending/descending) reflects the pedogenic mechanism
#'
#' \strong{Valid Ranges:} start_depth < end_depth, both within profile depth (0-200 cm typically).
#' Parameter order matters for correct gradient direction.
#' @export
#' @seealso \code{\link{sm_motif}}, \code{\link{sm_optim}}
#' @examples
#' # Organic matter decline with depth (typical A horizon)
#' depths <- 1:100
#' om_profile <- sm_shape_gradational(depths, c(0, 50), ascending = FALSE)
#' plot(om_profile, depths, ylim = c(100, 0), type = "l",
#'      xlab = "Organic Matter", ylab = "Depth (cm)",
#'      main = "Surface Organic Matter Decline")
#'
#' # Clay increase through B horizon (illuviation)
#' clay_profile <- sm_shape_gradational(depths, c(20, 80), ascending = TRUE)
#' plot(clay_profile, depths, ylim = c(100, 0), type = "l",
#'      xlab = "Clay Content", ylab = "Depth (cm)",
#'      main = "Clay Illuviation")
sm_shape_gradational <- function(x, params, ascending = TRUE, type = "linear") {
  start_depth <- params[1]
  end_depth <- params[2]
  range <- end_depth - start_depth
  if (abs(range) < 1e-10) range <- 1.0
  
  val <- (x - start_depth) / range
  shape <- pmax(0, pmin(1, val))
  
  if (!ascending) {
    shape <- 1 - shape
  }
  shape
}

#' Exponential Shape Function
#'
#' Models rapid change at surface with asymptotic behavior. Useful for OM, roots, surface-driven processes.
#'
#' @param x numeric. Depth vector (cm, increasing downward).
#' @param params numeric. Parameters: c(C0_surface_value, k_decay_rate).
#'   - C0_surface_value: Initial value at surface (0-1 range, relative scale)
#'   - k_decay_rate: Decay constant (> 0, typically 0.01-0.5). Higher values = faster decay.
#' @param ascending logical. If TRUE, high at surface, approaches 0 with depth.
#'   If FALSE, low at surface, approaches maximum with depth.
#'
#' @return numeric vector in the range 0 to 1 representing exponential decay/growth from surface.
#' @details
#' The exponential shape represents surface-controlled processes that decrease rapidly
#' near the surface and approach asymptotic values at depth. Common applications include:
#'
#' \strong{Soil Science Context:}
#' - \strong{Organic matter:} Rapid decomposition near surface, stable at depth
#' - \strong{Root density:} Exponential decline with soil depth
#' - \strong{Surface amendments:} Fertilizer or contaminant concentration gradients
#' - \strong{Biological activity:} Microbial populations decreasing with depth
#'
#' \strong{Parameter Interpretation:}
#' - C0 indicates the intensity of surface processes or inputs
#' - k reflects the rate of change (higher k = more rapid transition)
#' - Small k values indicate deep influence of surface processes
#' - Large k values indicate processes confined to near-surface
#'
#' \strong{Valid Ranges:} C0 in the range 0 to 1, k > 0 (typically 0.01-0.5 for soil profiles).
#' @export
#' @seealso \code{\link{sm_motif}}, \code{\link{sm_optim}}
#' @examples
#' # Organic matter decline (typical surface horizon)
#' depths <- 1:100
#' om_profile <- sm_shape_exponential(depths, c(1.0, 0.08))  # High OM at surface
#' plot(om_profile, depths, ylim = c(100, 0), type = "l",
#'      xlab = "Organic Matter", ylab = "Depth (cm)",
#'      main = "Organic Matter Decline")
#'
#' # Root density decrease
#' root_profile <- sm_shape_exponential(depths, c(0.9, 0.15))  # Dense near surface
#' plot(root_profile, depths, ylim = c(100, 0), type = "l",
#'      xlab = "Root Density", ylab = "Depth (cm)",
#'      main = "Root Distribution")
sm_shape_exponential <- function(x, params, ascending = TRUE) {
  C0 <- params[1]
  k <- params[2]
  shape <- C0 * exp(-k * x)
  # Normalize to [0, 1]
  shape <- (shape - min(shape)) / (max(shape) - min(shape))
  if (!ascending) {
    shape <- 1 - shape
  }
  shape
}

#' Wetting Front Shape Function
#'
#' Models an S-shaped curve; smooth transition between depths. Useful for reaction fronts, leaching.
#'
#' @param x numeric. Depth vector (cm, increasing downward).
#' @param params numeric. Parameters: c(depth_inflection_start, depth_inflection_end).
#'   - depth_inflection_start: Upper depth (cm) where wetting front begins (typically 30-100 cm)
#'   - depth_inflection_end: Lower depth (cm) where wetting front stabilizes (typically 60-150 cm)
#' @param ascending logical. If TRUE, property increases with depth through wetting front.
#'   If FALSE, decreases with depth (uncommon for wetting fronts).
#'
#' @return numeric vector in the range 0 to 1 representing wetting front progression.
#' @details
#' The wetting front shape is identical to the sigmoid but emphasizes hydrological
#' and chemical transport processes. Common applications include:
#'
#' \strong{Soil Science Context:}
#' - \strong{Wetting fronts:} Moisture movement creating reaction zones
#' - \strong{Salt accumulation:} Evaporation-driven solute concentration
#' - \strong{Calcium carbonate:} Precipitation fronts in arid soils
#' - \strong{Redox boundaries:} Changes in oxidation state with water table
#'
#' \strong{Parameter Interpretation:}
#' - The inflection zone represents the active wetting front depth
#' - Narrow fronts (small depth range) indicate sharp hydrologic boundaries
#' - Wide fronts suggest diffuse moisture movement or slow drainage
#' - Position reflects water table depth or irrigation patterns
#'
#' \strong{Valid Ranges:} Depth parameters within soil profile (0-200 cm typically).
#' This is an alias for sm_shape_sigmoid() with identical behavior.
#' @export
#' @seealso \code{\link{sm_motif}}, \code{\link{sm_optim}}, \code{\link{sm_shape_sigmoid}}
#' @examples
#' # Soil moisture wetting front after irrigation
#' depths <- 1:120
#' moisture_profile <- sm_shape_wetting_front(depths, c(40, 70))
#' plot(moisture_profile, depths, ylim = c(120, 0), type = "l",
#'      xlab = "Soil Moisture", ylab = "Depth (cm)",
#'      main = "Wetting Front Propagation")
#'
#' # Salt accumulation in arid soil (evaporation front)
#' salt_profile <- sm_shape_wetting_front(depths, c(30, 60))
#' plot(salt_profile, depths, ylim = c(120, 0), type = "l",
#'      xlab = "Salt Concentration", ylab = "Depth (cm)",
#'      main = "Salt Accumulation Zone")
sm_shape_wetting_front <- function(x, params, ascending = TRUE) {
  sm_shape_sigmoid(x, params, ascending)
}

#' Abrupt Shape Function
#'
#' Models a sharp step-like discontinuity at a single depth. Useful for lithologic changes.
#'
#' @param x numeric. Depth vector (cm, increasing downward).
#' @param params numeric. Parameters: c(depth_discontinuity, transition_width).
#'   - depth_discontinuity: Depth (cm) of the sharp boundary (typically 30-150 cm)
#'   - transition_width: Width (cm) of transition zone (0 for hard boundary, >0 for gradual).
#'     Optional, defaults to 0 (sharp discontinuity).
#' @param ascending logical. If TRUE, property = 0 above discontinuity, 1 below.
#'   If FALSE, property = 1 above discontinuity, 0 below.
#'
#' @return numeric vector in the range 0 to 1 representing step function with optional smoothing.
#' @details
#' The abrupt shape represents sharp boundaries between soil materials or conditions.
#' Common applications include:
#'
#' \strong{Soil Science Context:}
#' - \strong{Lithologic discontinuities:} Changes in parent material or texture
#' - \strong{Horizon boundaries:} Sharp transitions between soil horizons
#' - \strong{Water table fluctuations:} Rapid changes at saturation boundaries
#' - \strong{Anthropogenic layers:} Construction or fill boundaries
#'
#' \strong{Parameter Interpretation:}
#' - depth_discontinuity indicates the boundary position
#' - transition_width = 0 creates hard boundaries (lithologic discontinuities)
#' - transition_width > 0 creates diffuse boundaries (pedogenic mixing)
#' - The direction reflects which material has higher property values
#'
#' \strong{Valid Ranges:} depth_discontinuity within profile (0-200 cm), transition_width >= 0.
#' @export
#' @seealso \code{\link{sm_motif}}, \code{\link{sm_optim}}
#' @examples
#' # Lithologic discontinuity (sharp textural change)
#' depths <- 1:150
#' texture_profile <- sm_shape_abrupt(depths, c(80, 0))  # Hard boundary at 80 cm
#' plot(texture_profile, depths, ylim = c(150, 0), type = "l",
#'      xlab = "Clay Content", ylab = "Depth (cm)",
#'      main = "Lithologic Discontinuity")
#'
#' # Gradual horizon boundary (pedogenic mixing)
#' clay_profile <- sm_shape_abrupt(depths, c(60, 15))  # 15 cm transition zone
#' plot(clay_profile, depths, ylim = c(150, 0), type = "l",
#'      xlab = "Clay Content", ylab = "Depth (cm)",
#'      main = "Diffuse Horizon Boundary")
sm_shape_abrupt <- function(x, params, ascending = TRUE) {
  depth_disc <- params[1]
  transition_width <- if (length(params) > 1) params[2] else 0
  
  # Clamp parameters to valid ranges
  depth_disc <- max(min(x), min(max(x), depth_disc))  # within x range
  transition_width <- max(1e-6, transition_width)  # positive small value
  
  if (transition_width <= 1e-6) {
    shape <- as.numeric(x >= depth_disc)
  } else {
    # Smooth step using logistic
    shape <- plogis(x, location = depth_disc, scale = transition_width)
  }
  
  if (!ascending) {
    shape <- 1 - shape
  }
  shape
}

#' Peak Shape Function
#'
#' Models a bell-shaped accumulation zone. Useful for Bt horizon, clay peaks.
#'
#' @param x numeric. Depth vector (cm, increasing downward).
#' @param params numeric. Parameters: c(depth_of_max, width, skewness).
#'   - depth_of_max: Depth (cm) of maximum property value (typically 40-120 cm)
#'   - width: Standard deviation of the peak (cm, typically 10-50 cm). Controls peak width.
#'   - skewness: Asymmetry parameter (optional, default 0 = symmetric). Not yet implemented.
#' @param ascending logical. If TRUE, creates a peak (maximum). If FALSE, creates a valley (minimum).
#'
#' @return numeric vector in the range 0 to 1 representing bell-shaped accumulation/depletion.
#' @details
#' The peak shape represents localized accumulation or depletion zones typical of
#' specific pedogenic processes. Common applications include:
#'
#' \strong{Soil Science Context:}
#' - \strong{Argillic horizons:} Clay accumulation peaks (Bt horizons)
#' - \strong{Carbonate nodules:} Localized carbonate concentrations
#' - \strong{Salt crusts:} Surface salt accumulation in arid soils
#' - \strong{Depletion zones:} Eluvial horizons with clay removal (E horizons)
#'
#' \strong{Parameter Interpretation:}
#' - depth_of_max indicates the position of maximum pedogenic activity
#' - width reflects the thickness of the active zone (narrow = intense, wide = diffuse)
#' - Peak position often corresponds to water table or maximum root activity
#' - Valley shapes (ascending=FALSE) represent eluvial zones
#'
#' \strong{Valid Ranges:} depth_of_max within profile (0-200 cm), width > 0 (typically 10-50 cm).
#' @export
#' @seealso \code{\link{sm_motif}}, \code{\link{sm_optim}}
#' @examples
#' # Clay accumulation in Bt horizon
#' depths <- 1:120
#' clay_peak <- sm_shape_peak(depths, c(70, 25))  # Peak at 70 cm, 25 cm wide
#' plot(clay_peak, depths, ylim = c(120, 0), type = "l",
#'      xlab = "Clay Content", ylab = "Depth (cm)",
#'      main = "Argillic Horizon Clay Peak")
#'
#' # Carbonate nodule zone
#' carbonate_peak <- sm_shape_peak(depths, c(50, 15))  # Narrow peak at 50 cm
#' plot(carbonate_peak, depths, ylim = c(120, 0), type = "l",
#'      xlab = "Carbonate Content", ylab = "Depth (cm)",
#'      main = "Carbonate Accumulation")
sm_shape_peak <- function(x, params, ascending = TRUE) {
  depth_max <- params[1]
  width <- params[2]
  skew <- if (length(params) > 2) params[3] else 0  # TODO: implement skewness
  
  # Clamp parameters
  depth_max <- max(min(x), min(max(x), depth_max))
  width <- max(1e-6, width)
  
  # Normal distribution
  shape <- dnorm(x, mean = depth_max, sd = width)
  shape <- shape / max(shape)  # Normalize to [0, 1]
  
  if (!ascending) {
    shape <- 1 - shape
  }
  shape
}

#' MiniMax Shape Function
#'
#' Models two peaks: minimum then maximum. Useful for complex multi-process soils.
#'
#' @param x numeric. Depth vector (cm, increasing downward).
#' @param params numeric. Parameters: c(depth_min, width_min, depth_max, width_max, skew_min, skew_max).
#'   - depth_min: Depth (cm) of minimum/depletion zone (typically 20-80 cm)
#'   - width_min: Width (cm) of minimum zone (typically 10-30 cm)
#'   - depth_max: Depth (cm) of maximum/accumulation zone (typically 60-150 cm)
#'   - width_max: Width (cm) of maximum zone (typically 15-40 cm)
#'   - skew_min, skew_max: Skewness parameters (optional, not yet implemented)
#' @param ascending logical. If TRUE, minimum then maximum (eluvial-illuvial sequence).
#'   If FALSE, inverted pattern.
#'
#' @return numeric vector in the range 0 to 1 representing complex two-zone pattern.
#' @details
#' The minimax shape represents soils with both depletion and accumulation zones,
#' typical of advanced pedogenesis with clay migration. Common applications include:
#'
#' \strong{Soil Science Context:}
#' - \strong{Eluvial-illuvial sequences:} E horizon depletion over Bt horizon accumulation
#' - \strong{Podzolization:} Organic matter and sesquioxides translocation
#' - \strong{Ferrallitization:} Complex weathering sequences
#' - \strong{Salinization:} Salt depletion and accumulation zones
#'
#' \strong{Parameter Interpretation:}
#' - depth_min < depth_max creates the typical E-Bt sequence
#' - The separation between min and max reflects pedogenic intensity
#' - Width parameters indicate the thickness of active zones
#' - This shape captures the complexity of polygenetic soils
#'
#' \strong{Valid Ranges:} depth_min < depth_max, both within profile (0-200 cm),
#' widths > 0 (typically 10-40 cm).
#' @export
#' @seealso \code{\link{sm_motif}}, \code{\link{sm_optim}}
#' @examples
#' # Classic E-Bt horizon sequence (clay depletion then accumulation)
#' depths <- 1:140
#' clay_profile <- sm_shape_minimax(depths, c(35, 15, 85, 30))
#' plot(clay_profile, depths, ylim = c(140, 0), type = "l",
#'      xlab = "Clay Content", ylab = "Depth (cm)",
#'      main = "Eluvial-Illuvial Sequence")
#' abline(h = c(35, 85), lty = 2, col = "red")  # Mark zone boundaries
#'
#' # Podzol profile (organic matter translocation)
#' om_profile <- sm_shape_minimax(depths, c(25, 12, 65, 25))
#' plot(om_profile, depths, ylim = c(140, 0), type = "l",
#'      xlab = "Organic Matter", ylab = "Depth (cm)",
#'      main = "Podzol Organic Matter Distribution")
sm_shape_minimax <- function(x, params, ascending = TRUE) {
  depth_min <- params[1]
  width_min <- params[2]
  depth_max <- params[3]
  width_max <- params[4]
  # skew_min <- if (length(params) > 4) params[5] else 0
  # skew_max <- if (length(params) > 5) params[6] else 0
  
  # Clamp parameters
  depth_min <- max(min(x), min(max(x), depth_min))
  depth_max <- max(min(x), min(max(x), depth_max))
  width_min <- max(1e-6, width_min)
  width_max <- max(1e-6, width_max)
  
  # Create valley and peak distributions (raw densities)
  valley_density <- dnorm(x, mean = depth_min, sd = width_min)
  peak_density <- dnorm(x, mean = depth_max, sd = width_max)
  
  # Combine: valley is inverted, then average
  valley <- 1.0 - valley_density
  combined <- (valley + peak_density) / 2.0
  
  # Normalize to [0, 1] after combining
  max_combined <- max(combined)
  if (max_combined > 1e-10) {
    shape <- combined / max_combined
  } else {
    shape <- combined
  }
  
  if (!ascending) {
    shape <- 1 - shape
  }
  shape
}
