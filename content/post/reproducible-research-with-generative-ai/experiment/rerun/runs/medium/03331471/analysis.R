# Semantic priming effect in lexical decision (correct responses only).
# Priming effect = mean RT after unrelated primes minus mean RT after related
# primes, estimated with a linear mixed-effects model on raw RTs (so the
# estimate is in milliseconds) with crossed random effects for participants
# and items (Baayen, Davidson & Bates, 2008), using the maximal random-effects
# structure justified by the design (Barr et al., 2013): prime varies within
# both participants and items, so it gets by-participant and by-item slopes.

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
})

d <- read.csv("data.csv", stringsAsFactors = FALSE)

stopifnot(all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)),
          !anyNA(d[c("participant", "item", "prime", "rt")]),
          setequal(unique(d$prime), c("related", "unrelated")))

cat("Observations:", nrow(d), " participants:", length(unique(d$participant)),
    " items:", length(unique(d$item)), "\n")
print(aggregate(rt ~ prime, d, function(x) c(mean = mean(x), sd = sd(x))))

d$participant <- factor(d$participant)
d$item <- factor(d$item)
# Contrast coded +/-0.5, so the coefficient is the unrelated - related
# difference and the intercept is the grand mean.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)
# Word frequency is an item-level covariate; centring keeps the intercept
# interpretable. Frequency is constant within item and balanced across prime
# conditions, so it can only sharpen, not bias, the priming estimate.
d$freq_c <- d$frequency - mean(d$frequency)

ctrl <- lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
m <- lmer(rt ~ prime_c + freq_c +
            (1 + prime_c | participant) + (1 + prime_c | item),
          data = d, REML = TRUE, control = ctrl)

# Fall back to uncorrelated random effects if the maximal model is singular.
if (isSingular(m)) {
  cat("Maximal model singular; dropping random-effect correlations.\n")
  m <- lmer(rt ~ prime_c + freq_c +
              (1 + prime_c || participant) + (1 + prime_c || item),
            data = d, REML = TRUE, control = ctrl)
}

print(summary(m))

# Satterthwaite degrees of freedom for the t-based 95% CI.
co <- coef(summary(m, ddf = "Satterthwaite"))["prime_c", ]
est <- unname(co["Estimate"])
se  <- unname(co["Std. Error"])
df  <- unname(co["df"])
tcrit <- qt(0.975, df)
lower <- est - tcrit * se
upper <- est + tcrit * se

cat(sprintf("Priming effect (unrelated - related): %.1f ms, SE = %.1f, df = %.1f, p = %.3g\n",
            est, se, df, co["Pr(>|t|)"]))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, lower, upper))
