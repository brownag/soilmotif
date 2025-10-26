#' Convert optimization results to Bayesian priors
#'
#' Converts soilmotif optimization results to structured prior information
#' suitable for Bayesian modeling with brms, rstan, or other Bayesian packages.
#' Does not require Bayesian packages at runtime.
#'
#' @param x A soilmotif_optimization object (preferably from bootstrap for uncertainty)
#' @param prior_sd_factor Multiplier for prior standard deviations (default: 0.5)
#' @return A list with structured prior information:
#'   - parameters: character vector of parameter names
#'   - location: numeric vector of prior means (optimized parameter values)
#'   - scale: numeric vector of prior standard deviations
#'   - distribution: character string ("normal")
#'   - note: character string with usage guidance
#' @export
#' @examples
#' \dontrun{
#' # Basic usage with optimization result
#' clay_data <- sm_motif(1:200, c(40, 60)) + rnorm(200, 0, 3)
#' fit <- sm_optim(clay_data, c(40, 60), use_rust = TRUE)
#' priors <- sm_to_priors(fit)
#' str(priors)
#'
#' # Better: Use bootstrap uncertainty for informative priors
#' boot <- sm_optim_bootstrap(clay_data, depths = 1:200,
#'                           initial_params = c(40, 60),
#'                           shape_family = "sigmoid", n_bootstrap = 100)
#' priors <- sm_to_priors(boot, prior_sd_factor = 0.5)
#'
#' # Use with brms (requires brms package)
#' # library(brms)
#' # brm_model <- brm(
#' #   clay ~ depth_function(depth, param1, param2),
#' #   data = your_data,
#' #   prior = c(
#' #     prior(normal(priors$location[1], priors$scale[1]), coef = "param1"),
#' #     prior(normal(priors$location[2], priors$scale[2]), coef = "param2")
#' #   )
#' # )
#' }
sm_to_priors <- function(x, prior_sd_factor = 0.5) {
  # Handle both optimization and bootstrap results
  if (inherits(x, "bootstrap_result")) {
    # For bootstrap results, use parameter means and standard deviations
    if (x$n_successful == 0) {
      stop("No successful bootstrap samples found")
    }

    param_means <- colMeans(x$param_samples, na.rm = TRUE)
    param_sds <- apply(x$param_samples, 2, sd, na.rm = TRUE)

    # Apply prior_sd_factor to get reasonable prior widths
    prior_scale <- pmax(param_sds, 0.01) * prior_sd_factor

    param_names <- paste0("param_", 1:length(param_means))

  } else if (inherits(x, "soilmotif_optimization")) {
    # For optimization results
    if (!is.list(x) || is.null(x$params)) {
      stop("Expected object of class 'soilmotif_optimization'")
    }
    param_means <- x$params
    param_names <- names(param_means)

    if (is.null(param_names)) {
      param_names <- paste0("param_", 1:length(param_means))
    }

    # Use coefficient of variation for prior scale when no uncertainty available
    cv <- 0.25  # 25% coefficient of variation
    prior_scale <- abs(param_means) * cv * prior_sd_factor

    warning("No parameter uncertainty available. Consider using sm_optim_bootstrap() for more informative priors.")

  } else {
    stop("x must be a soilmotif_optimization or bootstrap_result object")
  }

  # Return structured prior information
  list(
    parameters = param_names,
    location = param_means,
    scale = prior_scale,
    distribution = "normal",
    note = paste(
      "Use these as informative priors in Bayesian models.",
      "The prior_sd_factor of", prior_sd_factor, "was used to scale uncertainties.",
      "For brms, use: prior(normal(location[i], scale[i]), coef = 'parameters[i]')"
    )
  )
}

#' Create prior string for brms models
#'
#' Generates a character vector of brms prior specifications from soilmotif results.
#' Requires brms package for actual use, but can be called without it.
#'
#' @param x A soilmotif_optimization or bootstrap_result object
#' @param prior_sd_factor Multiplier for prior standard deviations (default: 0.5)
#' @param prefix Character prefix for parameter names in brms (default: "b_")
#' @return Character vector of brms prior specifications
#' @export
#' @examples
#' \dontrun{
#' clay_data <- sm_motif(1:200, c(40, 60)) + rnorm(200, 0, 3)
#' boot <- sm_optim_bootstrap(clay_data, depths = 1:200,
#'                           initial_params = c(40, 60),
#'                           shape_family = "sigmoid", n_bootstrap = 100)
#'
#' # Get brms prior strings
#' prior_strings <- sm_to_brms_priors(boot)
#' print(prior_strings)
#'
#' # Use in brms model
#' # library(brms)
#' # model <- brm(formula, data, prior = prior_strings)
#' }
sm_to_brms_priors <- function(x, prior_sd_factor = 0.5, prefix = "b_") {
  priors <- sm_to_priors(x, prior_sd_factor)

  # Create brms prior strings
  prior_strings <- sprintf(
    "prior(normal(%g, %g), coef = '%s%s')",
    priors$location,
    priors$scale,
    prefix,
    priors$parameters
  )

  prior_strings
}

#' Create prior string for rstan models
#'
#' Generates Stan code snippets for prior specifications from soilmotif results.
#' Can be used in .stan model files or rstan model strings.
#'
#' @param x A soilmotif_optimization or bootstrap_result object
#' @param prior_sd_factor Multiplier for prior standard deviations (default: 0.5)
#' @param param_names Character vector of parameter names in Stan model (optional)
#' @return Character string of Stan prior specifications
#' @export
#' @examples
#' \dontrun{
#' clay_data <- sm_motif(1:200, c(40, 60)) + rnorm(200, 0, 3)
#' boot <- sm_optim_bootstrap(clay_data, depths = 1:200,
#'                           initial_params = c(40, 60),
#'                           shape_family = "sigmoid", n_bootstrap = 100)
#'
#' # Get Stan prior code
#' stan_priors <- sm_to_stan_priors(boot, param_names = c("param1", "param2"))
#' cat(stan_priors)
#'
#' # Use in Stan model:
#' # parameters {
#' #   real param1;
#' #   real param2;
#' # }
#' # model {
#' #   // Prior specifications
#' #   paste(stan_priors)
#' # }
#' }
sm_to_stan_priors <- function(x, prior_sd_factor = 0.5, param_names = NULL) {
  priors <- sm_to_priors(x, prior_sd_factor)

  if (is.null(param_names)) {
    param_names <- priors$parameters
  }

  if (length(param_names) != length(priors$parameters)) {
    stop("param_names must have the same length as the number of parameters")
  }

  # Create Stan prior strings
  prior_strings <- sprintf(
    "%s ~ normal(%g, %g);",
    param_names,
    priors$location,
    priors$scale
  )

  # Combine into a single string with newlines
  paste(prior_strings, collapse = "\n")
}