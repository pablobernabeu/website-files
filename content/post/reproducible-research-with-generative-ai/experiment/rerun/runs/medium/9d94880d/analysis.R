# Semantic priming effect in lexical decision (correct responses only).
# Priming effect = RT(unrelated) - RT(related), in milliseconds.
#
# Design: 30 participants x 24 items, each item seen once per prime condition,
# so prime varies within participants and within items. The analysis is a
# linear mixed-effects model with crossed random effects for participants and
# items and by-participant and by-item random slopes for prime (the maximal
# structure justified by the design; Barr et al., 2013). Prime is coded
# -0.5 (related) / +0.5 (unrelated), so its coefficient is the priming effect
# in ms. Target frequency (Zipf, centred) is a covariate that absorbs item
# variance; it is constant within items, so it does not bias the prime effect.

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
})

d <- read.csv("data.csv", stringsAsFactors = FALSE)

stopifnot(
  all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)),
  !anyNA(d[, c("participant", "item", "prime", "frequency", "rt")]),
  setequal(unique(d$prime), c("related", "unrelated"))
)

d$participant <- factor(d$participant)
d$item        <- factor(d$item)
d$prime_c     <- ifelse(d$prime == "unrelated", 0.5, -0.5)
d$freq_c      <- d$frequency - mean(d$frequency)

cat("Observations:", nrow(d), " Participants:", nlevels(d$participant),
    " Items:", nlevels(d$item), "\n")
cat("Cell means (ms):\n")
print(round(tapply(d$rt, d$prime, mean), 1))

# Maximal model; fall back to simpler random-effects structures if it fails
# to converge or is singular.
ctrl <- lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
formulas <- list(
  rt ~ prime_c + freq_c + (1 + prime_c | participant) + (1 + prime_c | item),
  rt ~ prime_c + freq_c + (1 + prime_c || participant) + (1 + prime_c || item),
  rt ~ prime_c + freq_c + (1 + prime_c | participant) + (1 | item),
  rt ~ prime_c + freq_c + (1 | participant) + (1 | item)
)

fit <- NULL
for (f in formulas) {
  warn <- NULL
  m <- withCallingHandlers(
    lmer(f, data = d, REML = TRUE, control = ctrl),
    warning = function(w) { warn <<- conditionMessage(w); invokeRestart("muffleWarning") }
  )
  if (is.null(warn) && !isSingular(m)) { fit <- m; break }
  cat("Model not retained (", if (!is.null(warn)) warn else "singular fit",
      "):\n  ", deparse(f, width.cutoff = 500), "\n")
}
if (is.null(fit)) fit <- m  # last resort: simplest model

cat("\nRetained model:\n  ", deparse(formula(fit), width.cutoff = 500), "\n\n")
print(summary(fit, ddf = "Satterthwaite"))

# 95% CI for the priming effect from the Satterthwaite t distribution.
co  <- summary(fit, ddf = "Satterthwaite")$coefficients["prime_c", ]
est <- unname(co["Estimate"])
se  <- unname(co["Std. Error"])
df  <- unname(co["df"])
tcrit <- qt(0.975, df)
lower <- est - tcrit * se
upper <- est + tcrit * se

cat(sprintf("\nPriming effect (unrelated - related): %.1f ms, SE = %.1f, df = %.1f, 95%% CI [%.1f, %.1f]\n",
            est, se, df, lower, upper))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, lower, upper))
