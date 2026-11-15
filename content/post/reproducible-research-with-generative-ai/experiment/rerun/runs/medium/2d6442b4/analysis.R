# Semantic priming effect in lexical decision (correct responses only).
# Priming effect = RT(unrelated) - RT(related), in milliseconds.
#
# Model: linear mixed-effects model on raw RT (so the effect is in ms),
# with crossed random effects for participants and items. Prime is
# within-participant and within-item, so the maximal structure includes
# by-participant and by-item random slopes for prime (Barr et al., 2013).
# Target frequency (a between-item covariate) is included, centred.
# The CI uses Satterthwaite degrees of freedom (lmerTest).

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
})

d <- read.csv("data.csv", stringsAsFactors = FALSE)

stopifnot(all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)))
d <- d[!is.na(d$rt), ]
d$participant <- factor(d$participant)
d$item        <- factor(d$item)
d$prime       <- factor(d$prime, levels = c("related", "unrelated"))

# Centred numeric contrast: related = -0.5, unrelated = +0.5, so the
# coefficient is the unrelated - related difference at average frequency.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)
d$freq_c  <- d$frequency - mean(d$frequency)

cat("Observations:", nrow(d), " participants:", nlevels(d$participant),
    " items:", nlevels(d$item), "\n")
cat("Condition means (ms):\n")
print(round(tapply(d$rt, d$prime, mean), 1))

ctrl <- lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))

# Maximal model; if it is singular, drop the random correlations, then
# fall back to intercepts plus slopes only where variance is supported.
fit_model <- function(formula) {
  lmer(formula, data = d, REML = TRUE, control = ctrl)
}
formulas <- list(
  rt ~ prime_c + freq_c + (1 + prime_c | participant) + (1 + prime_c | item),
  rt ~ prime_c + freq_c + (1 + prime_c || participant) + (1 + prime_c || item),
  rt ~ prime_c + freq_c + (1 + prime_c || participant) + (1 | item),
  rt ~ prime_c + freq_c + (1 | participant) + (1 | item)
)
for (f in formulas) {
  m <- fit_model(f)
  if (!isSingular(m)) break
}
cat("\nSelected model:", deparse(formula(m), width.cutoff = 500L), "\n")
print(summary(m))

co  <- summary(m)$coefficients["prime_c", ]
est <- unname(co["Estimate"])
se  <- unname(co["Std. Error"])
df  <- unname(co["df"])
tcrit <- qt(0.975, df)
lower <- est - tcrit * se
upper <- est + tcrit * se

cat(sprintf("\nPriming effect (unrelated - related): %.1f ms, 95%% CI [%.1f, %.1f], t(%.1f) = %.2f, p = %.4g\n",
            est, lower, upper, df, est / se, unname(co["Pr(>|t|)"])))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, lower, upper))
