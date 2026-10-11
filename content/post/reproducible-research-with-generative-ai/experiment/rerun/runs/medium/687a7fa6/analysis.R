# Semantic priming effect in lexical decision (correct responses only).
# Priming effect = mean RT after unrelated primes minus mean RT after related
# primes, estimated with a linear mixed-effects model on raw RT (ms) with
# crossed random effects for participants and items.

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
  library(emmeans)
})

d <- read.csv("data.csv", stringsAsFactors = FALSE)

stopifnot(all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)))
d <- d[!is.na(d$rt), ]
d$participant <- factor(d$participant)
d$item <- factor(d$item)
d$prime <- factor(d$prime, levels = c("related", "unrelated"))

cat("Observations:", nrow(d), " participants:", nlevels(d$participant),
    " items:", nlevels(d$item), "\n")
print(aggregate(rt ~ prime, data = d, FUN = mean))

# Sum-code prime (+0.5 unrelated, -0.5 related) so the coefficient is the
# unrelated - related difference and the intercept is the grand mean.
# Frequency is centred; it is a property of the target and varies between
# items only, so it accounts for item variability but not the prime contrast.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)
d$freq_c <- d$frequency - mean(d$frequency)

# Maximal random-effects structure justified by the design: prime varies
# within participants and within items.
m <- lmer(rt ~ prime_c + freq_c +
            (1 + prime_c | participant) + (1 + prime_c | item),
          data = d, REML = TRUE,
          control = lmerControl(optimizer = "bobyqa",
                                optCtrl = list(maxfun = 2e5)))

# If the maximal model is singular, simplify by dropping the random
# correlations, then the item slope, as needed.
if (isSingular(m)) {
  cat("Maximal model singular; dropping random correlations.\n")
  m <- update(m, . ~ prime_c + freq_c +
                (1 + prime_c || participant) + (1 + prime_c || item))
}
if (isSingular(m)) {
  cat("Still singular; dropping the by-item prime slope.\n")
  m <- update(m, . ~ prime_c + freq_c +
                (1 + prime_c || participant) + (1 | item))
}

if (isSingular(m)) {
  cat("Still singular; dropping the by-participant prime slope.\n")
  m <- update(m, . ~ prime_c + freq_c + (1 | participant) + (1 | item))
}

print(summary(m))

# Estimate and 95% CI for the priming effect, Satterthwaite degrees of freedom.
co <- summary(m, ddf = "Satterthwaite")$coefficients["prime_c", ]
est <- unname(co["Estimate"])
se <- unname(co["Std. Error"])
df <- unname(co["df"])
crit <- qt(0.975, df)
lower <- est - crit * se
upper <- est + crit * se

cat(sprintf("Priming effect (unrelated - related): %.1f ms, SE = %.1f, df = %.1f, 95%% CI [%.1f, %.1f], p = %.3g\n",
            est, se, df, lower, upper, co["Pr(>|t|)"]))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, lower, upper))
