#' Calculate Fit Statistics
#'
#' Internal function to compute RMSE, AIC, BIC, and R² for model evaluation.
#'
#' @param observed numeric. Observed values.
#' @param predicted numeric. Predicted/fitted values.
#' @param n_params integer. Number of parameters in the model.
#'
#' @return A list with rmse, aic, bic, r2.
#' @keywords internal
#' @noRd 
.calc_fit_stats <- function(observed, predicted, n_params) {
  residuals <- observed - predicted
  ss_res <- sum(residuals^2)
  ss_tot <- sum((observed - mean(observed))^2)
  rmse <- sqrt(mean(residuals^2))
  r2 <- if (ss_tot == 0) {
    if (ss_res == 0) 1 else 0
  } else {
    1 - (ss_res / ss_tot)
  }

  n <- length(observed)
  k <- n_params
  aic <- n * log(ss_res / n) + 2 * k
  bic <- n * log(ss_res / n) + log(n) * k

  list(rmse = rmse, aic = aic, bic = bic, r2 = r2)
}

#' Automated Motif Model Selection
#'
#' Fits multiple motif types to soil property data and ranks them by goodness-of-fit criteria.
#'
#' @importFrom graphics barplot par
#' @importFrom utils head
#'
#' @param x numeric. Vector of soil property values (1 unit resolution).
#' @param models character. Either "all" or a character vector of motif names to fit.
#'   Available: "uniform", "gradational", "exponential", "wetting_front", "abrupt", "peak", "minimax".
#' @param criterion character. Criterion for ranking models: "AIC", "BIC", "RMSE", or "R2".
#' @param depth_range numeric. Length 2 vector with depth range (default c(1, 200)).
#' @param ... Additional arguments passed to sm_optim().
#'
#' @return A list with class "fit_motif_auto" containing:
#'   \item{fits}{List of fitted motifs for each model.}
#'   \item{stats}{Data frame with fit statistics (rmse, aic, bic, r2).}
#'   \item{ranking}{Data frame of models ranked by the specified criterion.}
#'   \item{best}{Name of the best model by criterion.}
#'   \item{criterion}{The criterion used for ranking.}
#'   \item{input_length}{Length of input vector x.}
#'
#' @export
#' @examples
#' # Synthetic peak profile
#' x <- sm_motif(1:200, c(100, 30), FUN = sm_shape_peak)
#' result <- fit_motif_auto(x, criterion = "AIC")
#' print(result)
#' plot(result)
fit_motif_auto <- function(x,
                           models = "all",
                           criterion = "AIC",
                           depth_range = c(1, 200),
                           ...) {

  # Validate inputs
  if (!is.numeric(x)) stop("x must be numeric")
  if (length(x) < 10) warning("x is very short; fitting may be unreliable")
  if (!(criterion %in% c("AIC", "BIC", "RMSE", "R2"))) {
    stop("criterion must be one of 'AIC', 'BIC', 'RMSE', 'R2'")
  }

  # Determine which models to fit
  all_models <- c("uniform", "gradational", "exponential", "wetting_front",
                  "abrupt", "peak", "minimax")
  if (identical(models, "all")) {
    models_to_fit <- all_models
  } else {
    models_to_fit <- intersect(models, all_models)
    if (length(models_to_fit) == 0)
      stop("No valid models specified")
  }

  # Fit each model
  fits <- list()
  stats <- data.frame(
    model = character(),
    rmse = numeric(),
    aic = numeric(),
    bic = numeric(),
    r2 = numeric(),
    stringsAsFactors = FALSE
  )

  for (model_name in models_to_fit) {
    tryCatch({
      # Get initial parameters
      initial_par <- .suggest_initial_params(x, model_name)

      # Get shape function
      shape_fun <- get(paste0("sm_shape_", model_name))

      # Fit
      fit_result <- sm_optim(x, initial_par, FUN = shape_fun, ...)

      # Calculate statistics
      fit_stats <- .calc_fit_stats(x, fit_result, length(attr(fit_result, 'par')))

      fits[[model_name]] <- fit_result
      stats <- rbind(stats, data.frame(
        model = model_name,
        rmse = fit_stats$rmse,
        aic = fit_stats$aic,
        bic = fit_stats$bic,
        r2 = fit_stats$r2,
        stringsAsFactors = FALSE
      ))
    }, error = function(e) {
      warning(paste0("Failed to fit ", model_name, ": ", e$message))
    })
  }

  # Rank by criterion
  if (criterion == "AIC") {
    ranking <- stats[order(stats$aic), ]
  } else if (criterion == "BIC") {
    ranking <- stats[order(stats$bic), ]
  } else if (criterion == "RMSE") {
    ranking <- stats[order(stats$rmse), ]
  } else if (criterion == "R2") {
    ranking <- stats[order(stats$r2, decreasing = TRUE), ]
  }

  best_model <- ranking$model[1]

  # Return object with S3 class
  result <- list(
    fits = fits,
    stats = stats,
    ranking = ranking,
    best = best_model,
    criterion = criterion,
    input_length = length(x)
  )
  class(result) <- c("fit_motif_auto", "list")
  result
}

#' @export
print.fit_motif_auto <- function(x, ...) {
  cat("Automated Motif Fitting Results\n")
  cat("================================\n")
  cat("Input length:", x$input_length, "\n")
  cat("Criterion:", x$criterion, "\n")
  cat("Best model:", x$best, "\n\n")
  cat("Ranking (ordered by", x$criterion, "):\n")
  print(x$ranking)
  invisible(x)
}

#' @export
plot.fit_motif_auto <- function(x, ...) {
  if (length(x$fits) == 0) {
    warning("No successful fits to plot")
    return(invisible(NULL))
  }

  # Set up plotting area
  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par))

  par(mfrow = c(1, 2))

  # Panel 1: Best fit overlaid on data
  best_name <- x$best
  best_fit <- x$fits[[best_name]]
  depth <- seq(1, x$input_length)

  plot(best_fit, depth, ylim = c(max(depth), min(depth)),
       type = "l", col = "blue", lwd = 2,
       xlab = paste(best_name, "value"), ylab = "Depth (cm)",
       main = paste("Best fit:", best_name))

  # Panel 2: Ranking bar chart
  criterion_col <- tolower(x$criterion)
  if (criterion_col == "r2") criterion_col <- "r2"

  barplot(x$ranking[[criterion_col]],
          names.arg = x$ranking$model,
          main = paste("Models ranked by", x$criterion),
          ylab = x$criterion,
          las = 2)

  invisible(x)
}

#' @export
summary.fit_motif_auto <- function(object, ...) {
  cat("=== Motif Fitting Summary ===\n")
  cat("Best model:", object$best, "\n")
  cat("Criterion used:", object$criterion, "\n")
  cat("\nTop 3 models:\n")
  print(head(object$ranking, 3))
  cat("\n(Full ranking available in $ranking slot)\n")
  invisible(object)
}
