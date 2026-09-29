# Semantic priming in lexical decision: size of the priming effect
# (RT after unrelated prime minus RT after related prime), in ms, with 95% CI.
#
# Design: 30 participants x 24 target words x 2 prime conditions, fully crossed.
# Prime is manipulated within participants AND within items, so both are
# modelled as crossed random factors, with by-participant and by-item random
# slopes for prime where the data support them.

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
  library(emmeans)
  library(dplyr)
})

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# ---- Checks ---------------------------------------------------------------
stopifnot(!anyNA(d),
          all(d$prime %in% c("related", "unrelated")),
          !any(duplicated(d[, c("participant", "item", "prime")])))

d <- d %>%
  mutate(participant = factor(participant),
         item        = factor(item),
         prime       = factor(prime, levels = c("related", "unrelated")),
         # deviation coding: coefficient = unrelated - related,
         # intercept = grand mean
         primeC      = ifelse(prime == "unrelated", 0.5, -0.5))

cat("Observations:", nrow(d),
    "| participants:", nlevels(d$participant),
    "| items:", nlevels(d$item), "\n")
cat("Cells per participant x item x prime:",
    paste(unique(table(d$participant, d$item, d$prime)), collapse = ","), "\n")
cat("RT range:", paste(range(d$rt), collapse = " - "), "ms\n")
# No RTs are implausibly fast/slow (< 200 or > 2500 ms), so no trimming is done.
cat("RTs < 200 ms or > 2500 ms:", sum(d$rt < 200 | d$rt > 2500), "\n\n")

cat("Condition means (ms):\n")
print(as.data.frame(d %>% group_by(prime) %>%
                      summarise(mean_rt = mean(rt), median_rt = median(rt),
                                n = n())))
cat("\n")

# ---- Random-effects structure ---------------------------------------------
# Start from the maximal model justified by the design.
m_max <- lmer(rt ~ primeC + (1 + primeC | participant) + (1 + primeC | item),
              data = d, REML = TRUE)
cat("Maximal model singular:", isSingular(m_max), "\n")
print(VarCorr(m_max))
cat("\n")

# In this data set the by-participant slope variance is estimated at ~0
# (correlation +1, singular fit), so that term is removed. The by-item slope
# variance is kept if it is not negligible (LRT at alpha = .20; Matuschek et
# al., 2017) -- it is substantial here (SD ~ 30 ms).
m_red <- lmer(rt ~ primeC + (1 | participant) + (1 + primeC | item),
              data = d, REML = TRUE)
m_noslope <- lmer(rt ~ primeC + (1 | participant) + (1 | item),
                  data = d, REML = TRUE)
lrt_pslope <- anova(m_red, m_max, refit = FALSE)
lrt_islope <- anova(m_noslope, m_red, refit = FALSE)
cat("LRT, by-participant slope (+ correlation):",
    sprintf("chisq = %.3f, p = %.3f", lrt_pslope$Chisq[2],
            lrt_pslope$`Pr(>Chisq)`[2]), "\n")
cat("LRT, by-item slope (+ correlation):",
    sprintf("chisq = %.3f, p = %.3f", lrt_islope$Chisq[2],
            lrt_islope$`Pr(>Chisq)`[2]), "\n\n")

if (isSingular(m_max)) {
  final <- m_red
  final_label <- "rt ~ prime + (1 | participant) + (1 + prime | item)"
} else {
  final <- m_max
  final_label <- "rt ~ prime + (1 + prime | participant) + (1 + prime | item)"
}
stopifnot(!isSingular(final))

cat("Final model:", final_label, "\n")
print(summary(final))
cat("\n")

# ---- Priming effect: unrelated - related, Satterthwaite df ----------------
fe  <- coef(summary(final, ddf = "Satterthwaite"))["primeC", ]
est <- unname(fe["Estimate"])
se  <- unname(fe["Std. Error"])
df_ <- unname(fe["df"])
ci  <- est + c(-1, 1) * qt(0.975, df_) * se

cat(sprintf("Priming effect (unrelated - related): %.2f ms, SE = %.2f, df = %.1f, t = %.2f, p = %.4f\n",
            est, se, df_, fe["t value"], fe["Pr(>|t|)"]))
cat(sprintf("95%% CI (Satterthwaite): [%.2f, %.2f] ms\n\n", ci[1], ci[2]))

# ---- Sensitivity checks (not used for the RESULT line) --------------------
cat("Sensitivity checks:\n")
prof <- suppressMessages(confint(final, parm = "primeC", method = "profile"))
cat(sprintf("  Profile-likelihood 95%% CI, final model:       [%.2f, %.2f]\n",
            prof[1], prof[2]))

fe_max <- coef(summary(m_max))["primeC", ]
ci_max <- fe_max["Estimate"] + c(-1, 1) * qt(0.975, fe_max["df"]) * fe_max["Std. Error"]
cat(sprintf("  Maximal (singular) model:                     %.2f [%.2f, %.2f]\n",
            fe_max["Estimate"], ci_max[1], ci_max[2]))

d$freqC <- d$frequency - mean(tapply(d$frequency, d$item, mean))
m_freq <- lmer(rt ~ primeC * freqC + (1 | participant) + (1 + primeC | item),
               data = d)
fe_f <- coef(summary(m_freq))
ci_f <- fe_f["primeC", "Estimate"] + c(-1, 1) * qt(0.975, fe_f["primeC", "df"]) *
  fe_f["primeC", "Std. Error"]
cat(sprintf("  + word frequency (centred) and interaction:   %.2f [%.2f, %.2f]; prime x freq = %.2f (p = %.2f)\n",
            fe_f["primeC", "Estimate"], ci_f[1], ci_f[2],
            fe_f["primeC:freqC", "Estimate"], fe_f["primeC:freqC", "Pr(>|t|)"]))

m_log <- lmer(log(rt) ~ primeC + (1 | participant) + (1 + primeC | item), data = d)
fe_l <- coef(summary(m_log))["primeC", ]
b0 <- fixef(m_log)[1]
cat(sprintf("  log-RT model: ratio = %.3f (p = %.3f), ~%.1f ms at the geometric mean RT\n",
            exp(fe_l["Estimate"]), fe_l["Pr(>|t|)"],
            exp(b0 + fe_l["Estimate"] / 2) - exp(b0 - fe_l["Estimate"] / 2)))

by_subj <- d %>% group_by(participant) %>%
  summarise(eff = mean(rt[prime == "unrelated"]) - mean(rt[prime == "related"]))
tt <- t.test(by_subj$eff)
cat(sprintf("  By-participant paired t-test (ignores item variability): %.2f [%.2f, %.2f]\n\n",
            tt$estimate, tt$conf.int[1], tt$conf.int[2]))

# ---- Final result ---------------------------------------------------------
cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, ci[1], ci[2]))
