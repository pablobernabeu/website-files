# Semantic priming in lexical decision: size of the priming effect
#
# Priming effect = mean RT after unrelated primes - mean RT after related primes (ms).
# Design: 30 participants x 24 targets, each target seen once per prime condition,
# so prime varies within participants AND within items (fully crossed). The effect
# is estimated with a linear mixed-effects model on raw RT (ms) with crossed random
# effects for participants and items, so that the confidence interval generalises
# over both samples. Random slopes for prime are kept wherever the data support them.

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
  library(dplyr)
})

# ---- Read and check the data --------------------------------------------------
d <- read.csv("data.csv", stringsAsFactors = FALSE)

stopifnot(all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)))
stopifnot(!anyNA(d$rt), all(d$prime %in% c("related", "unrelated")))

d <- d %>%
  mutate(
    participant = factor(participant),
    item        = factor(item),
    prime       = factor(prime, levels = c("related", "unrelated")),
    # Centred +/-0.5 coding: the slope is the unrelated - related difference,
    # and the intercept is the grand mean.
    prime_c     = ifelse(prime == "unrelated", 0.5, -0.5),
    freq_c      = frequency - mean(frequency)
  )

cells <- table(d$participant, d$item, d$prime)
cat(sprintf("Observations: %d | participants: %d | items: %d\n",
            nrow(d), nlevels(d$participant), nlevels(d$item)))
cat(sprintf("Every participant x item x prime cell has exactly one trial: %s\n",
            all(cells == 1)))
cat(sprintf("RT range: %d-%d ms (data are correct responses; no further trimming)\n\n",
            min(d$rt), max(d$rt)))

# ---- Descriptives -------------------------------------------------------------
cat("Condition means (ms):\n")
print(as.data.frame(d %>% group_by(prime) %>%
  summarise(n = n(), mean_rt = mean(rt), sd_rt = sd(rt), median_rt = median(rt),
            .groups = "drop")))
cat("\n")

# ---- Mixed model: choose the random-effects structure ------------------------
# Start from the maximal structure justified by the design and simplify only if
# the fit is singular (a variance estimated at zero or a correlation at +/-1).
candidates <- list(
  "maximal"                          = rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
  "no participant slope-intercept r" = rt ~ prime_c + (1 + prime_c || participant) + (1 + prime_c | item),
  "no participant slope"             = rt ~ prime_c + (1 | participant) + (1 + prime_c | item),
  "no item slope-intercept r"        = rt ~ prime_c + (1 | participant) + (1 + prime_c || item),
  "intercepts only"                  = rt ~ prime_c + (1 | participant) + (1 | item)
)

ctrl <- lmerControl(optimizer = "bobyqa", calc.derivs = TRUE)
fit_quiet <- function(f, REML = TRUE) {
  suppressMessages(suppressWarnings(lmer(f, data = d, REML = REML, control = ctrl)))
}
# Convergence warnings other than the singular-fit notice (reported separately).
converged <- function(m) {
  msgs <- m@optinfo$conv$lme4$messages
  !any(!grepl("singular", msgs))
}

final <- NULL
for (nm in names(candidates)) {
  m <- fit_quiet(candidates[[nm]])
  sing <- isSingular(m)
  conv <- converged(m)
  cat(sprintf("Random effects '%s': singular = %s, converged = %s\n", nm, sing, conv))
  if (!sing && conv) {
    final <- m
    final_name <- nm
    break
  }
}
if (is.null(final)) stop("No candidate random-effects structure gave a regular fit.")

cat(sprintf("\nSelected model (%s):\n", final_name))
print(formula(final))
print(VarCorr(final), comp = "Std.Dev.")
cat("\n")

# ---- Priming effect and 95% CI -------------------------------------------------
# t-based Wald interval with Satterthwaite degrees of freedom (lmerTest).
cf    <- summary(final, ddf = "Satterthwaite")$coefficients["prime_c", ]
est   <- unname(cf["Estimate"])
se    <- unname(cf["Std. Error"])
df_s  <- unname(cf["df"])
ci    <- est + c(-1, 1) * qt(0.975, df_s) * se
cat(sprintf("Priming effect (unrelated - related): %.2f ms, SE = %.2f, df = %.1f, p = %.4f\n",
            est, se, df_s, unname(cf["Pr(>|t|)"])))
cat(sprintf("95%% CI (Satterthwaite): [%.2f, %.2f] ms\n\n", ci[1], ci[2]))

# ---- Sensitivity checks (reported, not used for the result) -------------------
cat("Sensitivity checks:\n")

# (a) Kenward-Roger degrees of freedom
kr <- summary(final, ddf = "Kenward-Roger")$coefficients["prime_c", ]
ci_kr <- kr["Estimate"] + c(-1, 1) * qt(0.975, kr["df"]) * kr["Std. Error"]
cat(sprintf("  Kenward-Roger 95%% CI:             [%.2f, %.2f] ms\n", ci_kr[1], ci_kr[2]))

# (b) Profile-likelihood interval (ML fit)
m_ml <- fit_quiet(formula(final), REML = FALSE)
ci_prof <- suppressMessages(confint(m_ml, parm = "prime_c", method = "profile", quiet = TRUE))
cat(sprintf("  Profile-likelihood 95%% CI:        [%.2f, %.2f] ms\n", ci_prof[1], ci_prof[2]))

# (c) Adjusting for target-word frequency (items are balanced across prime,
#     so this should not move the estimate)
m_freq <- fit_quiet(update(formula(final), . ~ . + freq_c))
cf_f <- summary(m_freq)$coefficients["prime_c", ]
cat(sprintf("  With frequency covariate:         %.2f ms, SE = %.2f\n",
            cf_f["Estimate"], cf_f["Std. Error"]))

# (d) By-participant and by-item paired analyses (F1 / F2)
by_subj <- d %>% group_by(participant, prime) %>% summarise(rt = mean(rt), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = prime, values_from = rt)
by_item <- d %>% group_by(item, prime) %>% summarise(rt = mean(rt), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = prime, values_from = rt)
t1 <- t.test(by_subj$unrelated, by_subj$related, paired = TRUE)
t2 <- t.test(by_item$unrelated, by_item$related, paired = TRUE)
cat(sprintf("  By-participant paired t (F1):     %.2f ms [%.2f, %.2f]  (ignores item variability)\n",
            t1$estimate, t1$conf.int[1], t1$conf.int[2]))
cat(sprintf("  By-item paired t (F2):            %.2f ms [%.2f, %.2f]\n",
            t2$estimate, t2$conf.int[1], t2$conf.int[2]))

# (e) Log-RT model (RTs are right-skewed): effect as a ratio
m_log <- fit_quiet(update(formula(final), log(.) ~ .))
cf_l <- summary(m_log)$coefficients["prime_c", ]
ci_l <- cf_l["Estimate"] + c(-1, 1) * qt(0.975, cf_l["df"]) * cf_l["Std. Error"]
cat(sprintf("  Log-RT model: unrelated/related = %.3f [%.3f, %.3f], p = %.4f\n\n",
            exp(cf_l["Estimate"]), exp(ci_l[1]), exp(ci_l[2]), cf_l["Pr(>|t|)"]))

# ---- Final result ------------------------------------------------------------
cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, ci[1], ci[2]))
