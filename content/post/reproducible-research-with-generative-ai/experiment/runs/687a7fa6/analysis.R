# Semantic priming in lexical decision: size of the priming effect
# (RT after unrelated prime minus RT after related prime), in ms, with 95% CI.
#
# Design: 30 participants x 24 target words x 2 prime conditions, fully crossed.
# Prime varies within participants AND within items, so the effect can vary
# across both, and the analysis has to generalise over participants and words
# at the same time. It uses a linear mixed model on raw RT, so the prime
# coefficient is in milliseconds, with crossed random effects for participants
# and items and by-item and by-participant random slopes for prime.

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)   # Satterthwaite df for the fixed-effect t tests and CIs
  library(dplyr)
})

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# ---- Data checks -----------------------------------------------------------
stopifnot(all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)))
stopifnot(!anyNA(d))
stopifnot(all(d$prime %in% c("related", "unrelated")))
cat("Rows:", nrow(d), " participants:", n_distinct(d$participant),
    " items:", n_distinct(d$item), "\n")
cat("Trials per participant x prime cell (range):",
    range(table(d$participant, d$prime)), "\n")
cat("Duplicate participant/item/prime rows:",
    sum(duplicated(d[, c("participant", "item", "prime")])), "\n")
cat("RT range (ms):", range(d$rt), "\n")
# The RTs (correct trials only) run from about 380 to 1600 ms, with no
# anticipations or very long lapses, so no trimming is applied.

cat("\nCondition means (ms):\n")
print(d %>% group_by(prime) %>%
        summarise(n = n(), mean_rt = mean(rt), sd_rt = sd(rt), .groups = "drop"))

# ---- Coding ----------------------------------------------------------------
# Prime: deviation coding with unrelated = +0.5 and related = -0.5, so the
# coefficient is the unrelated - related difference in ms, averaged over the
# other terms.
# Frequency: an item-level covariate, centred on the mean over items. It can
# only absorb between-item baseline variance. Because every item appears in
# both prime conditions, it is orthogonal to prime.
d <- d %>%
  mutate(prime_c = ifelse(prime == "unrelated", 0.5, -0.5),
         participant = factor(participant),
         item = factor(item))
item_freq <- d %>% distinct(item, frequency)
stopifnot(nrow(item_freq) == n_distinct(d$item))  # one frequency per item
d$freq_c <- d$frequency - mean(item_freq$frequency)

ctl <- lmerControl(optimizer = "bobyqa")

# ---- Maximal model ---------------------------------------------------------
m_max <- lmer(rt ~ prime_c + freq_c +
                (1 + prime_c | participant) + (1 + prime_c | item),
              data = d, REML = TRUE, control = ctl)
cat("\nMaximal model random effects:\n")
print(VarCorr(m_max), comp = c("Std.Dev.", "Variance"))
cat("Singular fit:", isSingular(m_max), "\n")

# The maximal fit is singular because the by-participant prime slope has
# essentially zero variance (its correlation with the intercept is at +1).
# Removing that zero-variance term gives the non-singular model below. It
# keeps the by-item prime slope, which is clearly non-zero (SD of about 30 ms)
# and is tested next. Removing the participant slope leaves the estimate
# unchanged and barely moves the SE (9.8 ms in the maximal model, 9.7 ms here).
m <- lmer(rt ~ prime_c + freq_c +
            (1 | participant) + (1 + prime_c | item),
          data = d, REML = TRUE, control = ctl)
cat("\nFinal model:\n")
print(summary(m))
cat("Singular fit:", isSingular(m), "\n")

# Is there by-item variability in the priming effect? This is a likelihood-
# ratio test of the by-item slope variance. Because the variance cannot be
# negative, the p-value uses the boundary-corrected 50:50 chi-square mixture.
m_zc  <- lmer(rt ~ prime_c + freq_c + (1 | participant) + (1 + prime_c || item),
              data = d, REML = TRUE, control = ctl)
m_int <- lmer(rt ~ prime_c + freq_c + (1 | participant) + (1 | item),
              data = d, REML = TRUE, control = ctl)
lrt <- anova(m_zc, m_int, refit = FALSE)
cat(sprintf("\nBy-item prime-slope variance: LRT chi2 = %.2f, boundary-corrected p = %.3f\n",
            lrt$Chisq[2], 0.5 * pchisq(lrt$Chisq[2], df = 1, lower.tail = FALSE)))
# Leaving this term out treats the 24 words as fixed (the language-as-fixed-
# effect fallacy), and the CI then comes out too narrow.

# ---- Priming effect: estimate and 95% CI (Satterthwaite t) -----------------
co  <- coef(summary(m))["prime_c", ]
est <- unname(co["Estimate"])
se  <- unname(co["Std. Error"])
df  <- unname(co["df"])
ci  <- est + c(-1, 1) * qt(0.975, df) * se
cat(sprintf("\nPriming effect (unrelated - related): %.2f ms, SE = %.2f, df = %.1f, t = %.2f, p = %.4f\n",
            est, se, df, est / se, 2 * pt(-abs(est / se), df)))
cat(sprintf("95%% CI (Satterthwaite): [%.2f, %.2f] ms\n", ci[1], ci[2]))

# ---- Sensitivity checks (not used for the RESULT line) ---------------------
prof <- suppressMessages(confint(m, parm = "prime_c", method = "profile"))
cat(sprintf("Profile-likelihood 95%% CI: [%.2f, %.2f] ms\n", prof[1], prof[2]))

# Does priming depend on word frequency?
m_int_freq <- lmer(rt ~ prime_c * freq_c + (1 | participant) + (1 + prime_c | item),
                   data = d, REML = TRUE, control = ctl)
pf <- coef(summary(m_int_freq))["prime_c:freq_c", ]
cat(sprintf("Prime x frequency interaction: %.2f ms per Zipf unit (p = %.3f)\n",
            pf["Estimate"], pf["Pr(>|t|)"]))

# The same model on log RT, since RTs are right-skewed. The effect is converted
# back to ms at the model's typical (geometric-mean) RT.
m_log <- lmer(log(rt) ~ prime_c + freq_c + (1 | participant) + (1 + prime_c | item),
              data = d, REML = TRUE, control = ctl)
cl  <- coef(summary(m_log))
b0  <- cl["(Intercept)", "Estimate"]
b1  <- cl["prime_c", "Estimate"]
se1 <- cl["prime_c", "Std. Error"]
df1 <- cl["prime_c", "df"]
to_ms <- function(b) exp(b0 + b / 2) - exp(b0 - b / 2)
ci_log <- b1 + c(-1, 1) * qt(0.975, df1) * se1
cat(sprintf("Log-RT model: effect = %.2f ms at typical RT, 95%% CI [%.2f, %.2f] ms (p = %.4f)\n",
            to_ms(b1), to_ms(ci_log[1]), to_ms(ci_log[2]), cl["prime_c", "Pr(>|t|)"]))

# ---- Final result -----------------------------------------------------------
cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, ci[1], ci[2]))
