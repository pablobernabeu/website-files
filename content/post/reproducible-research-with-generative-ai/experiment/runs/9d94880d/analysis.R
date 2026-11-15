# Semantic priming in lexical decision: size of the priming effect
# (RT after unrelated prime minus RT after related prime), in ms, with 95% CI.
#
# Design: 30 participants x 24 target words x 2 prime conditions, fully crossed
# (each participant saw each target once after each prime type). Both
# participants and items are random samples, so the estimate and its CI must
# account for variability across both, including item-to-item variability in
# the priming effect itself (by-item random slopes). A by-participant analysis
# alone would treat the 24 items as fixed and give a CI that is too narrow.

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
  library(emmeans)
})

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# ---- Checks on the data ---------------------------------------------------
stopifnot(!anyNA(d), all(d$prime %in% c("related", "unrelated")))
d$participant <- factor(d$participant)
d$item        <- factor(d$item)
d$prime       <- factor(d$prime, levels = c("related", "unrelated"))
contrasts(d$prime) <- matrix(c(-0.5, 0.5), dimnames = list(NULL, "unrel_vs_rel"))
# Numeric version of the same contrast, used for random slopes so that
# uncorrelated (||) structures behave as intended.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

cat("Observations:", nrow(d),
    "| participants:", nlevels(d$participant),
    "| items:", nlevels(d$item), "\n")
cat("Cells per participant x item x prime (should all be 1):\n")
print(table(table(d$participant, d$item, d$prime)))
cat("\nMean RT by prime condition (ms):\n")
print(round(tapply(d$rt, d$prime, mean), 1))

# ---- Random-effects structure ---------------------------------------------
# Start from the maximal structure justified by the design (Barr et al., 2013):
# random intercepts and prime slopes for both participants and items.
m_max <- lmer(rt ~ prime + (1 + prime_c | participant) + (1 + prime_c | item),
              data = d)
cat("\nMaximal model singular fit:", isSingular(m_max), "\n")
print(VarCorr(m_max))

# The maximal fit is singular: the by-participant slope variance is estimated
# at (essentially) zero, with a degenerate +1 correlation. Removing that
# unsupported component (Matuschek et al., 2017; Bates et al., 2015) gives a
# non-singular model with an identical fixed-effect estimate. The by-item slope
# is kept: it is supported by the data (LRT p < .20, the Matuschek criterion,
# with a sizeable SD of about 30 ms), and dropping it would ignore real
# item-to-item variability in priming and understate the uncertainty.
m <- lmer(rt ~ prime + (1 | participant) + (1 + prime_c | item), data = d)
cat("\nFinal model singular fit:", isSingular(m), "\n")

m_noslope <- lmer(rt ~ prime + (1 | participant) + (1 | item), data = d)
cat("\nLRT for the by-item prime slope:\n")
print(anova(m_noslope, m, refit = FALSE))

cat("\n==== Final model ====\n")
print(summary(m))

# ---- Priming effect: unrelated minus related, Satterthwaite df -------------
emm <- emmeans(m, ~ prime, lmer.df = "satterthwaite")
cat("\nEstimated marginal means (ms):\n")
print(emm)
pe <- summary(contrast(emm, list(priming = c(-1, 1))),
              infer = c(TRUE, TRUE), level = 0.95)
cat("\nPriming effect (unrelated - related), ms:\n")
print(pe)

# ---- Sensitivity checks (reported, not used for the RESULT line) -----------
cat("\n==== Sensitivity checks ====\n")
ci_row <- function(label, est, lo, hi) {
  cat(sprintf("%-55s %7.2f  [%7.2f, %7.2f]\n", label, est, lo, hi))
}
ci_row("Final model, Satterthwaite (primary)",
       pe$estimate, pe$lower.CL, pe$upper.CL)

L <- c(0, 1)
kr <- contest(m, L, joint = FALSE, confint = TRUE, ddf = "Kenward-Roger")
ci_row("Final model, Kenward-Roger", kr$Estimate, kr$lower, kr$upper)

pr <- confint(m, parm = "primeunrel_vs_rel", method = "profile", quiet = TRUE)
ci_row("Final model, profile likelihood", fixef(m)[2], pr[1], pr[2])

mx <- contest(m_max, L, joint = FALSE, confint = TRUE)
ci_row("Maximal (singular) model, Satterthwaite", mx$Estimate, mx$lower, mx$upper)

# Word frequency is an item property, balanced across prime conditions, so it
# cannot confound the priming contrast; adding it (centred) and its
# interaction with prime leaves the estimate unchanged.
d$freq_c <- d$frequency - mean(tapply(d$frequency, d$item, mean))
m_freq <- lmer(rt ~ prime * freq_c + (1 | participant) + (1 + prime_c | item),
               data = d)
fq <- contest(m_freq, c(0, 1, 0, 0), joint = FALSE, confint = TRUE)
ci_row("Adding frequency (centred) x prime", fq$Estimate, fq$lower, fq$upper)
cat(sprintf("  prime x frequency interaction: %.2f ms per Zipf unit, p = %.3f\n",
            fixef(m_freq)["primeunrel_vs_rel:freq_c"],
            summary(m_freq)$coefficients["primeunrel_vs_rel:freq_c", "Pr(>|t|)"]))

# Intercepts-only model ignores item variability in priming: CI too narrow.
io <- contest(m_noslope, L, joint = FALSE, confint = TRUE)
ci_row("Random intercepts only (anticonservative)", io$Estimate, io$lower, io$upper)

# Classic by-participant (F1) and by-item (F2) paired analyses.
agg <- function(g) {
  a <- aggregate(rt ~ g + prime, data = transform(d, g = d[[g]]), FUN = mean)
  w <- reshape(a, idvar = "g", timevar = "prime", direction = "wide")
  t.test(w$rt.unrelated, w$rt.related, paired = TRUE)
}
t1 <- agg("participant"); t2 <- agg("item")
ci_row("By-participant paired t-test (ignores items)",
       unname(t1$estimate), t1$conf.int[1], t1$conf.int[2])
ci_row("By-item paired t-test (ignores participants)",
       unname(t2$estimate), t2$conf.int[1], t2$conf.int[2])

# Log-RT model, effect expressed as ms at the geometric-mean RT.
m_log <- lmer(log(rt) ~ prime + (1 | participant) + (1 + prime_c | item), data = d)
bl <- fixef(m_log); lc <- contest(m_log, L, joint = FALSE, confint = TRUE)
to_ms <- function(b) exp(bl[1]) * (exp(b / 2) - exp(-b / 2))
ci_row("Log-RT model, back-transformed at geometric mean",
       to_ms(bl[2]), to_ms(lc$lower), to_ms(lc$upper))

# ---- Result ----------------------------------------------------------------
cat("\n")
cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            pe$estimate, pe$lower.CL, pe$upper.CL))
