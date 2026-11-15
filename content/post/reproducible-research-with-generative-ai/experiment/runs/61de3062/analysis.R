# Semantic priming in lexical decision: size of the priming effect
# (RT after unrelated prime minus RT after related prime), in ms, with 95% CI.
#
# Design: 30 participants x 24 target words x 2 prime conditions (related /
# unrelated), fully crossed; prime varies within participants and within items.
# Frequency (Zipf) is an item-level covariate.
#
# Model: linear mixed model on raw RT (so the effect is directly in ms) with
# crossed random effects for participants and items. The maximal model
# (by-participant and by-item random slopes for prime) is singular: the
# by-participant slope variance is estimated at ~0 (with or without the
# intercept-slope correlation), so that term is dropped. The by-item slope
# is retained because priming varies substantially across items; ignoring it
# would make the CI too narrow. The CI uses Satterthwaite degrees of freedom.

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
  library(dplyr)
})

d <- read.csv("data.csv", stringsAsFactors = FALSE)

stopifnot(!anyNA(d), all(d$prime %in% c("related", "unrelated")))

# prime coded -0.5 (related) / +0.5 (unrelated): its coefficient is the
# unrelated - related difference in ms, evaluated at mean frequency.
d <- d %>%
  mutate(
    participant = factor(participant),
    item        = factor(item),
    prime_c     = ifelse(prime == "unrelated", 0.5, -0.5),
    freq_c      = frequency - mean(frequency)
  )

cat("Observations:", nrow(d),
    "| participants:", nlevels(d$participant),
    "| items:", nlevels(d$item), "\n\n")

cat("Cell means (ms):\n")
print(as.data.frame(d %>% group_by(prime) %>%
  summarise(n = n(), mean_rt = mean(rt), sd_rt = sd(rt), .groups = "drop")))
cat("\n")

# ---- Maximal model (check of the random-effects structure) -----------------
m_max <- suppressMessages(
  lmer(rt ~ prime_c + freq_c + (1 + prime_c | participant) + (1 + prime_c | item),
       data = d, REML = TRUE)
)
m_zcp <- suppressMessages(
  lmer(rt ~ prime_c + freq_c + (1 + prime_c || participant) + (1 + prime_c || item),
       data = d, REML = TRUE)
)
cat("Maximal model singular:", isSingular(m_max), "\n")
print(VarCorr(m_max))
cat("\nZero-correlation model singular:", isSingular(m_zcp), "\n")
print(VarCorr(m_zcp))
cat("-> by-participant prime slope variance is ~0; dropped from final model.\n\n")

# ---- Final model ------------------------------------------------------------
m <- lmer(rt ~ prime_c + freq_c + (1 | participant) + (1 + prime_c | item),
          data = d, REML = TRUE)
cat("Final model singular:", isSingular(m), "\n")
print(summary(m))

est <- contest(m, L = c(0, 1, 0), confint = TRUE, joint = FALSE,
               ddf = "Satterthwaite", level = 0.95)
cat("\nPriming effect (unrelated - related), Satterthwaite 95% CI:\n")
print(est)

# ---- Sensitivity checks (not used for the result) --------------------------
# (a) log RT, back-transformed to ms at the grand-mean RT scale
m_log <- lmer(log(rt) ~ prime_c + freq_c + (1 | participant) + (1 + prime_c | item),
              data = d, REML = TRUE)
e_log <- contest(m_log, L = c(0, 1, 0), confint = TRUE, joint = FALSE)
to_ms <- function(b) unname(exp(fixef(m_log)[1]) * (exp(b / 2) - exp(-b / 2)))
cat(sprintf("\nSensitivity, log-RT model (ms): %.2f [%.2f, %.2f]\n",
            to_ms(e_log$Estimate), to_ms(e_log$lower), to_ms(e_log$upper)))

# (b) excluding observations with |standardised residual| > 3
keep <- abs(resid(m) / sigma(m)) <= 3
m_trim <- update(m, data = d[keep, ])
e_trim <- contest(m_trim, L = c(0, 1, 0), confint = TRUE, joint = FALSE)
cat(sprintf("Sensitivity, %d residual outliers removed (ms): %.2f [%.2f, %.2f]\n\n",
            sum(!keep), e_trim$Estimate, e_trim$lower, e_trim$upper))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est$Estimate, est$lower, est$upper))
