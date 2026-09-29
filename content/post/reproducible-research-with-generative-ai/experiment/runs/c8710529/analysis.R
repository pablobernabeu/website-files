# Semantic priming in lexical decision: size of the priming effect
# (RT after unrelated prime minus RT after related prime), in milliseconds.
#
# Design: 30 participants x 24 target words, each target seen once after a
# related and once after an unrelated prime (prime is within-participant and
# within-item). Only correct responses are in the file.
#
# Analysis: linear mixed-effects model on raw RT (so the fixed effect is in
# ms) with crossed random effects for participants and items. Prime is coded
# -0.5 (related) / +0.5 (unrelated), so its coefficient is the priming effect.
# We start from the maximal random-effects structure (Barr et al., 2013) and
# simplify it if the fit is singular (Bates et al., 2015; Matuschek et al., 2017).
# The 95% CI uses Satterthwaite degrees of freedom (lmerTest).

suppressPackageStartupMessages({
  library(dplyr)
  library(lme4)
  library(lmerTest)
})

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# ---- Data checks -----------------------------------------------------------
stopifnot(all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)))
d <- d %>%
  mutate(
    participant = factor(participant),
    item        = factor(item),
    prime       = factor(prime, levels = c("related", "unrelated")),
    prime_c     = ifelse(prime == "unrelated", 0.5, -0.5),
    freq_c      = frequency - mean(tapply(frequency, item, mean))
  )
stopifnot(!anyNA(d$prime), !anyNA(d$rt))

cat("Observations:", nrow(d),
    "| participants:", nlevels(d$participant),
    "| items:", nlevels(d$item), "\n")
cat("RT range:", paste(range(d$rt), collapse = " - "), "ms\n\n")

cat("Condition means (ms):\n")
print(as.data.frame(d %>% group_by(prime) %>%
  summarise(n = n(), mean_rt = mean(rt), sd_rt = sd(rt), .groups = "drop")))
cat("\n")

ctrl <- lmerControl(optimizer = "bobyqa")

# ---- Maximal model ---------------------------------------------------------
m_max <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
              data = d, control = ctrl)
cat("Maximal model: singular fit =", isSingular(m_max), "\n")
print(VarCorr(m_max))
cat("\n")

# The maximal model is singular: the by-participant intercept/slope
# correlation goes to +1. Remove that correlation. The by-participant
# priming-slope variance then goes to zero, so drop the slope and check
# with a likelihood-ratio test that doing so costs nothing.
m_zcp <- lmer(rt ~ prime_c + (1 + prime_c || participant) + (1 + prime_c | item),
              data = d, control = ctrl)
m_fin <- lmer(rt ~ prime_c + (1 | participant) + (1 + prime_c | item),
              data = d, control = ctrl)
cat("By-participant slope SD without correlation:",
    signif(attr(VarCorr(m_zcp)$participant.1, "stddev"), 3), "\n")
cat("LRT, by-participant priming slope:\n")
print(anova(m_fin, m_zcp, refit = FALSE))
cat("\nFinal model: singular fit =", isSingular(m_fin), "\n")
print(summary(m_fin))

# ---- Priming effect with 95% CI (Satterthwaite) ----------------------------
ci_from <- function(m) {
  cf <- summary(m)$coefficients["prime_c", ]
  est <- unname(cf["Estimate"]); se <- unname(cf["Std. Error"]); df <- unname(cf["df"])
  c(estimate = est, se = se, df = df,
    lower = est - qt(0.975, df) * se, upper = est + qt(0.975, df) * se)
}
res <- ci_from(m_fin)

# ---- Sensitivity checks (printed for information only) ---------------------
cat("\nSensitivity checks for the priming effect (ms):\n")
sens <- rbind(
  "final: (1|subj) + (1+prime|item)" = res,
  "maximal (singular)"                = ci_from(m_max),
  "final + word frequency covariate"  = ci_from(update(m_fin, . ~ . + freq_c))
)
print(round(sens, 2))
prof <- confint(m_fin, parm = "prime_c", method = "profile", quiet = TRUE)
cat("Profile-likelihood 95% CI, final model:",
    paste(round(prof, 2), collapse = " to "), "\n")
m_log <- lmer(log(rt) ~ prime_c + (1 | participant) + (1 + prime_c | item),
              data = d, control = ctrl)
b_log <- fixef(m_log)["prime_c"]
cat(sprintf("Log-RT model: unrelated/related RT ratio = %.3f (about %.1f ms at the median RT)\n\n",
            exp(b_log), (exp(b_log) - 1) * median(d$rt[d$prime == "related"])))

cat(sprintf("Priming effect (unrelated - related): %.2f ms, 95%% CI [%.2f, %.2f], SE = %.2f, t(%.1f) = %.2f, p = %.4f\n",
            res["estimate"], res["lower"], res["upper"], res["se"], res["df"],
            res["estimate"] / res["se"],
            2 * pt(-abs(res["estimate"] / res["se"]), res["df"])))
cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            res["estimate"], res["lower"], res["upper"]))
