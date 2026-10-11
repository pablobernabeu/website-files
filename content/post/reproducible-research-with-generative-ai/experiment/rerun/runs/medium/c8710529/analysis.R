# Semantic priming effect in lexical decision (correct responses only).
# Estimate: unrelated minus related RT, in ms, with a 95% CI, from a linear
# mixed-effects model with crossed random effects for participants and items.

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
})

d <- read.csv("data.csv", stringsAsFactors = FALSE)

stopifnot(all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)),
          all(d$prime %in% c("related", "unrelated")),
          !anyNA(d$rt))

d$participant <- factor(d$participant)
d$item        <- factor(d$item)
d$prime       <- factor(d$prime, levels = c("related", "unrelated"))

# Sum-to-zero (+0.5 / -0.5) coding: the prime coefficient is the
# unrelated - related difference and is estimated at the grand mean.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)
# Word frequency is an item-level covariate; centred so it does not shift
# the intercept. It soaks up item variance but is not the effect of interest.
d$freq_c  <- d$frequency - mean(d$frequency)

cat("Design:", nlevels(d$participant), "participants x", nlevels(d$item),
    "items,", nrow(d), "trials\n")
cat("Cell means (ms):\n")
print(round(tapply(d$rt, d$prime, mean), 1))

# Maximal random-effects structure justified by the design (Barr et al., 2013):
# prime varies within participants and within items. Simplify only if the
# fit is singular or fails to converge.
ctrl <- lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
forms <- list(
  maximal     = rt ~ prime_c + freq_c + (1 + prime_c | participant) + (1 + prime_c | item),
  no_corr     = rt ~ prime_c + freq_c + (1 + prime_c || participant) + (1 + prime_c || item),
  intercepts  = rt ~ prime_c + freq_c + (1 | participant) + (1 | item)
)

fit <- NULL
for (nm in names(forms)) {
  m <- lmer(forms[[nm]], data = d, REML = TRUE, control = ctrl)
  conv_msgs <- m@optinfo$conv$lme4$messages
  if (!isSingular(m) && is.null(conv_msgs)) {
    fit <- m; chosen <- nm; break
  }
  cat("Model '", nm, "' singular or not converged; simplifying.\n", sep = "")
}
if (is.null(fit)) { fit <- m; chosen <- nm }
cat("Random-effects structure used:", chosen, "\n\n")
print(summary(fit, ddf = "Satterthwaite"))

# Wald-type CI with Satterthwaite degrees of freedom for the prime effect.
co  <- summary(fit, ddf = "Satterthwaite")$coefficients["prime_c", ]
est <- unname(co["Estimate"])
se  <- unname(co["Std. Error"])
df  <- unname(co["df"])
ci  <- est + c(-1, 1) * qt(0.975, df) * se

cat(sprintf("\nPriming effect (unrelated - related): %.1f ms, 95%% CI [%.1f, %.1f], t(%.1f) = %.2f, p = %.3g\n",
            est, ci[1], ci[2], df, est / se, unname(co["Pr(>|t|)"])))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, ci[1], ci[2]))
