# Semantic priming in lexical decision: size of the priming effect
# (unrelated minus related prime RT, in ms) with a 95% confidence interval.
#
# Design: 30 participants x 24 target words x 2 prime conditions; every target
# is seen by every participant once after each prime type (fully crossed,
# within-participant and within-item). Participants AND items are random
# samples, so the effect is estimated with a linear mixed model with crossed
# random effects, including by-item and by-participant random slopes for prime
# (Clark, 1973; Barr et al., 2013). Analysing RT on the raw ms scale so the
# effect is directly in milliseconds.

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
  library(dplyr)
})

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# ---- Data checks ----------------------------------------------------------
stopifnot(!anyNA(d$rt),
          setequal(unique(d$prime), c("related", "unrelated")),
          !any(duplicated(d[, c("participant", "item", "prime")])))
cat(sprintf("Observations: %d | participants: %d | items: %d\n",
            nrow(d), n_distinct(d$participant), n_distinct(d$item)))
cat(sprintf("RT range: %d-%d ms (no trimming applied)\n", min(d$rt), max(d$rt)))

cell_means <- d %>% group_by(prime) %>%
  summarise(mean_rt = mean(rt), sd_rt = sd(rt), n = n(), .groups = "drop")
print(as.data.frame(cell_means))

# ---- Coding ---------------------------------------------------------------
# prime_c: -0.5 = related, +0.5 = unrelated, so its coefficient is the
# priming effect (unrelated - related) in ms.
# freq_c: item Zipf frequency centred on the item mean; an item-level
# covariate that absorbs baseline item differences (orthogonal to prime here).
d <- d %>%
  mutate(prime_c = ifelse(prime == "unrelated", 0.5, -0.5),
         freq_c  = frequency - mean(tapply(frequency, item, mean)))

prime_ci <- function(m, ddf = "Satterthwaite") {
  s <- coef(summary(m, ddf = ddf))["prime_c", ]
  q <- qt(0.975, s[["df"]])
  c(estimate = s[["Estimate"]], se = s[["Std. Error"]], df = s[["df"]],
    lower = s[["Estimate"]] - q * s[["Std. Error"]],
    upper = s[["Estimate"]] + q * s[["Std. Error"]])
}

# ---- Random-effects structure ---------------------------------------------
# 1. Maximal model.
m_max <- lmer(rt ~ prime_c + freq_c +
                (1 + prime_c | participant) + (1 + prime_c | item),
              data = d, REML = TRUE)
cat("\nMaximal model singular:", isSingular(m_max), "\n")
print(VarCorr(m_max))

# 2. Maximal model is singular (participant slope/intercept correlation at
#    the boundary); drop the correlation parameters.
m_zc <- lmer(rt ~ prime_c + freq_c +
               (1 + prime_c || participant) + (1 + prime_c || item),
             data = d, REML = TRUE)
cat("\nZero-correlation model singular:", isSingular(m_zc), "\n")
print(VarCorr(m_zc))

# 3. Still singular: the by-participant prime slope variance is estimated at
#    ~0, so remove it. The by-item slope (substantial) is kept, with its
#    correlation. This is the final, non-singular model.
m_final <- lmer(rt ~ prime_c + freq_c +
                  (1 | participant) + (1 + prime_c | item),
                data = d, REML = TRUE)
if (isSingular(m_final)) stop("Final model is singular")
cat("\nFinal model:\n")
print(summary(m_final))

# ---- Estimate and 95% CI (t-based, Satterthwaite df) -----------------------
res <- prime_ci(m_final, "Satterthwaite")
res_kr <- prime_ci(m_final, "Kenward-Roger")

# ---- Sensitivity checks ---------------------------------------------------
w <- d %>% select(participant, item, prime, rt) %>%
  tidyr::pivot_wider(names_from = prime, values_from = rt) %>%
  mutate(diff = unrelated - related)
by_subj <- t.test(tapply(w$diff, w$participant, mean))
by_item <- t.test(tapply(w$diff, w$item, mean))

sens <- rbind(
  "Final LMM, Satterthwaite"          = res,
  "Final LMM, Kenward-Roger"          = res_kr,
  "Maximal LMM (singular)"            = prime_ci(m_max),
  "By-participant paired t (F1 only)" = c(by_subj$estimate, by_subj$stderr,
                                          by_subj$parameter, by_subj$conf.int),
  "By-item paired t (F2 only)"        = c(by_item$estimate, by_item$stderr,
                                          by_item$parameter, by_item$conf.int)
)
cat("\nPriming effect (unrelated - related, ms) under alternative analyses:\n")
print(round(sens, 2))
cat("Note: the by-participant-only CI ignores item variability in priming",
    "and is too narrow.\n")

cat(sprintf(paste0("\nPriming effect: %.1f ms (SE %.1f, df %.1f), ",
                   "95%% CI [%.1f, %.1f]\n"),
            res["estimate"], res["se"], res["df"], res["lower"], res["upper"]))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            res["estimate"], res["lower"], res["upper"]))
