# Semantic priming effect in lexical decision (correct responses only).
# Estimates how much slower responses are after unrelated primes than after
# related primes, in milliseconds, with a 95% confidence interval.
#
# Design: 30 participants x 24 targets x 2 prime conditions, fully crossed,
# so prime varies within participants and within items. A linear mixed model
# with crossed random intercepts and by-participant and by-item random slopes
# for prime (Barr et al., 2013) gives an estimate in the original ms scale
# that generalises over both participants and items.

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
})

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# Basic checks on the design
stopifnot(!anyNA(d),
          setequal(unique(d$prime), c("related", "unrelated")))
cat("Rows:", nrow(d), " Participants:", length(unique(d$participant)),
    " Items:", length(unique(d$item)), "\n")
cells <- table(d$participant, d$item, d$prime)
cat("Observations per participant x item x prime cell:",
    paste(unique(as.vector(cells)), collapse = ", "), "\n")

# Descriptive condition means
cat("\nMean RT by prime (ms):\n")
print(round(tapply(d$rt, d$prime, mean), 1))

# Prime coded as a sum-to-zero contrast scaled so that its coefficient is
# the unrelated minus related difference: -0.5 related, +0.5 unrelated.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)
d$participant <- factor(d$participant)
d$item <- factor(d$item)

# Frequency is constant within item and balanced across prime conditions,
# so it cannot confound the within-item priming contrast; it is left out.
fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE,
            control = lmerControl(optimizer = "bobyqa"))

# Fall back to uncorrelated slopes if the maximal model is singular
if (isSingular(fit)) {
  cat("\nMaximal model singular; refitting with uncorrelated random effects.\n")
  fit <- lmer(rt ~ prime_c + (1 + prime_c || participant) +
                (1 + prime_c || item),
              data = d, REML = TRUE,
              control = lmerControl(optimizer = "bobyqa"))
}

cat("\nModel summary:\n")
print(summary(fit))

# Satterthwaite-based t interval for the priming coefficient
co <- summary(fit)$coefficients["prime_c", ]
est <- unname(co["Estimate"])
se  <- unname(co["Std. Error"])
df  <- unname(co["df"])
tcrit <- qt(0.975, df)
lower <- est - tcrit * se
upper <- est + tcrit * se

cat(sprintf("\nPriming effect (unrelated - related): %.1f ms, SE = %.1f, df = %.1f, p = %.3g\n",
            est, se, df, unname(co["Pr(>|t|)"])))
cat(sprintf("95%% CI (Satterthwaite): [%.1f, %.1f] ms\n", lower, upper))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, lower, upper))
