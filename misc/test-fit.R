library(aqp)
library(mpspline2)
library(soilmotif)

# from aqp::jacobs2000, profile 1
x <- data.frame(
  id = 1,
  top = c(0, 18, 43, 79, 130, 153, 156),
  bottom = c(18, 43, 79, 130, 153, 156, 213),
  clay = c(7L, 6L, 39L, 41L, 51L, 50L, 47L),
  depletion_pct = c(0, 0, 0, 0, 2, 0, 15)
)

x$midpoint <- (x$top + x$bottom) / 2
y <- mpspline2::mpspline(x, var_name = "clay")
spc <- x

depths(spc) <- id ~ top + bottom
spc2 <- rebuildSPC(dice(spc))
spcs <- spc2mpspline(spc2,
  var_name = "clay",
  method = "est_dcm",
  d = seq(0, 200, 1)
)
z <- horizons(spcs)
plot(1:200 ~ y[[1]]$est_1cm, ylim = c(200, 0), type = "n")
lines(x$midpoint ~ x$clay, col = "blue")
lines((z$top + z$bottom) / 2 ~ z$clay_spline, col = "red")
lines(sm_optim(z$clay_spline, c(40, 60)), 1:200, lty = 2)

