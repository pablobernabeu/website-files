# Semantic priming effect in lexical decision (correct responses only).
# Priming effect = mean RT(unrelated) - mean RT(related), in ms.
# Estimated with a linear mixed model with crossed random effects for
# participants and items, including by-participant and by-item random
# slopes for prime (the maximal structure justified by the design, Barr
# et al., 2013). RT is modelled on the raw ms scale so the estimate is
# directly in milliseconds. 95% CI uses Satterthwaite degrees of freedom.

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
})

d <- read.csv("data.csv", stringsAsFactors = FALSE)
stopifnot(all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)))
d <- d[!is.na(d$rt), ]
d$participant <- factor(d$participant)
d$item <- factor(d$item)
d$prime <- factor(d$prime, levels = c("related", "unrelated"))

cat("Observations:", nrow(d), " Participants:", nlevels(d$participant),
    " Items:", nlevels(d$item), "\n")
print(aggregate(rt ~ prime, d, function(x) c(mean = mean(x), sd = sd(x))))

# Sum-coded prime: +0.5 unrelated, -0.5 related, so the coefficient is the
# unrelated - related difference and the intercept is the grand mean.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)
# Centred target frequency as a covariate (item-level; absorbs item variance).
d$freq_c <- d$frequency - mean(d$frequency)

fit <- lmer(rt ~ prime_c + freq_c +
              (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE,
            control = lmerControl(optimizer = "bobyqa"))

if (isSingular(fit) || length(fit@optinfo$conv$lme4$messages) > 0) {
  message("Maximal model singular or non-convergent; dropping random-slope correlations.")
  fit <- lmer(rt ~ prime_c + freq_c +
                (1 + prime_c || participant) + (1 + prime_c || item),
              data = d, REML = TRUE,
              control = lmerControl(optimizer = "bobyqa"))
}
# If still singular, drop any random slope whose variance is estimated at
# (numerically) zero, following Matuschek et al. (2017); this leaves the
# fixed-effect estimate essentially unchanged but removes the degenerate term.
if (isSingular(fit)) {
  vc <- as.data.frame(VarCorr(fit))
  slope_var <- setNames(vc$vcov[vc$var1 == "prime_c" & !is.na(vc$var1)],
                        sub("[.]1$", "", vc$grp[vc$var1 == "prime_c" & !is.na(vc$var1)]))
  keep <- names(slope_var)[slope_var > 1e-6]
  re <- c(
    if ("participant" %in% keep) "(1 + prime_c || participant)" else "(1 | participant)",
    if ("item" %in% keep) "(1 + prime_c || item)" else "(1 | item)"
  )
  message("Dropping zero-variance random slopes; random effects: ", paste(re, collapse = " + "))
  fit <- lmer(as.formula(paste("rt ~ prime_c + freq_c +", paste(re, collapse = " + "))),
              data = d, REML = TRUE,
              control = lmerControl(optimizer = "bobyqa"))
}
print(summary(fit))

co <- summary(fit)$coefficients["prime_c", ]
est <- unname(co["Estimate"])
se <- unname(co["Std. Error"])
df <- unname(co["df"])
tcrit <- qt(0.975, df)
lower <- est - tcrit * se
upper <- est + tcrit * se

# Sanity check: paired participant-level difference
pm <- with(d, tapply(rt, list(participant, prime), mean))
cat(sprintf("By-participant mean difference: %.1f ms\n",
            mean(pm[, "unrelated"] - pm[, "related"])))

cat(sprintf("Priming effect: %.1f ms, 95%% CI [%.1f, %.1f] (Satterthwaite df = %.1f)\n",
            est, lower, upper, df))
cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, lower, upper))
