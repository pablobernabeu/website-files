# Semantic priming in lexical decision: size of the priming effect
# (RT after unrelated prime minus RT after related prime), in milliseconds,
# with a 95% confidence interval.
#
# Design: 30 participants x 24 target words; every participant saw every
# target once after a related and once after an unrelated prime (correct
# trials only). Prime is therefore within participants AND within items, so
# the estimate must generalise over both random samples. We fit a linear
# mixed-effects model on raw RT (so the effect is directly in ms) with crossed
# random effects for participants and items, including by-item and
# by-participant random slopes for prime (Barr et al., 2013). If the maximal
# model is singular, random-effect terms are simplified step by step
# (Matuschek et al., 2017), always keeping the by-item random slope, which
# carries the between-item variability in priming.

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
  library(dplyr)
})

# ---------------------------------------------------------------- data ----
d <- read.csv("data.csv", stringsAsFactors = FALSE)

stopifnot(all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)))
d <- d[complete.cases(d[, c("participant", "item", "prime", "frequency", "rt")]), ]
d$participant <- factor(d$participant)
d$item        <- factor(d$item)
d$prime       <- factor(d$prime, levels = c("related", "unrelated"))
stopifnot(!any(is.na(d$prime)))

cat("Observations:", nrow(d),
    "| participants:", nlevels(d$participant),
    "| items:", nlevels(d$item), "\n")
cat("Trials per participant x item cell:\n")
print(table(table(d$participant, d$item)))

# Deviation coding: coefficient of prime_c = unrelated - related (in ms)
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)
# Item-level covariate, centred on the mean across items
item_freq <- d %>% distinct(item, frequency)
stopifnot(nrow(item_freq) == nlevels(d$item))  # one frequency per item
d$freq_c <- d$frequency - mean(item_freq$frequency)

# --------------------------------------------------------- descriptives ----
cat("\nCondition means (ms):\n")
print(d %>% group_by(prime) %>%
        summarise(n = n(), mean_rt = mean(rt), median_rt = median(rt), sd_rt = sd(rt),
                  .groups = "drop") %>% as.data.frame())

cell_diff <- d %>%
  group_by(participant, item) %>%
  summarise(diff = rt[prime == "unrelated"] - rt[prime == "related"], .groups = "drop")
cat("\nRaw mean priming effect (unrelated - related):",
    round(mean(cell_diff$diff), 2), "ms\n")

by_item <- cell_diff %>% group_by(item) %>% summarise(diff = mean(diff), .groups = "drop")
by_subj <- cell_diff %>% group_by(participant) %>% summarise(diff = mean(diff), .groups = "drop")
cat("SD of by-item priming effects:", round(sd(by_item$diff), 1),
    "ms | SD of by-participant priming effects:", round(sd(by_subj$diff), 1), "ms\n")

# ------------------------------------------------------------ modelling ----
# Candidate random-effect structures, from maximal to simpler. The first one
# that converges without a singular fit is used.
candidates <- list(
  maximal =
    rt ~ prime_c + freq_c + (1 + prime_c | participant) + (1 + prime_c | item),
  no_subj_corr =
    rt ~ prime_c + freq_c + (1 + prime_c || participant) + (1 + prime_c | item),
  no_subj_slope =
    rt ~ prime_c + freq_c + (1 | participant) + (1 + prime_c | item),
  no_subj_slope_no_item_corr =
    rt ~ prime_c + freq_c + (1 | participant) + (1 + prime_c || item)
)

fit_ok <- function(m) {
  conv_msgs <- m@optinfo$conv$lme4$messages
  !isSingular(m, tol = 1e-4) && is.null(conv_msgs)
}

chosen <- NULL
for (nm in names(candidates)) {
  m <- suppressMessages(suppressWarnings(
    lmer(candidates[[nm]], data = d, REML = TRUE,
         control = lmerControl(optimizer = "bobyqa"))
  ))
  ok <- fit_ok(m)
  cat(sprintf("\nModel '%s': %s\n", nm,
              if (ok) "converged, non-singular -> selected"
              else "singular or not converged -> simplify"))
  if (!ok) print(VarCorr(m), comp = "Std.Dev.")
  if (ok) { chosen <- m; chosen_name <- nm; break }
}
if (is.null(chosen)) stop("No candidate random-effects structure gave a non-singular fit.")

cat("\nSelected model:", chosen_name, "\n")
print(formula(chosen))
print(VarCorr(chosen), comp = c("Variance", "Std.Dev."))

# Fixed effects with Satterthwaite small-sample degrees of freedom (in this
# balanced design Kenward-Roger gives the same SE and df, but is much slower)
coefs <- summary(chosen, ddf = "Satterthwaite")$coefficients
cat("\nFixed effects (Satterthwaite df):\n")
print(round(coefs, 4))

est <- unname(coefs["prime_c", "Estimate"])
se  <- unname(coefs["prime_c", "Std. Error"])
df  <- unname(coefs["prime_c", "df"])
lower <- est - qt(0.975, df) * se
upper <- est + qt(0.975, df) * se

cat(sprintf("\nPriming effect (unrelated - related): %.2f ms, SE = %.2f, df = %.1f, 95%% CI [%.2f, %.2f], p = %.4f\n",
            est, se, df, lower, upper, coefs["prime_c", "Pr(>|t|)"]))

# ----------------------------------------------------- sensitivity checks ----
cat("\n--- Sensitivity checks (not the reported result) ---\n")

prof <- suppressMessages(confint(chosen, parm = "prime_c", method = "profile"))
cat(sprintf("Profile-likelihood 95%% CI: [%.2f, %.2f]\n", prof[1, 1], prof[1, 2]))

m_log <- suppressMessages(suppressWarnings(
  lmer(update(formula(chosen), log(rt) ~ .), data = d, REML = TRUE,
       control = lmerControl(optimizer = "bobyqa"))
))
b_log <- fixef(m_log)
p_log <- summary(m_log)$coefficients["prime_c", "Pr(>|t|)"]
ms_log <- exp(b_log[["(Intercept)"]] + 0.5 * b_log[["prime_c"]]) -
          exp(b_log[["(Intercept)"]] - 0.5 * b_log[["prime_c"]])
cat(sprintf("Log-RT model: ratio = %.4f (%.1f%% slower), approx. %.1f ms at the typical RT, p = %.4f\n",
            exp(b_log[["prime_c"]]), 100 * (exp(b_log[["prime_c"]]) - 1), ms_log, p_log))

m_noslope <- suppressMessages(
  lmer(rt ~ prime_c + freq_c + (1 | participant) + (1 | item), data = d, REML = TRUE)
)
cs <- summary(m_noslope, ddf = "Satterthwaite")$coefficients["prime_c", ]
cat(sprintf(paste0("Intercepts-only model (ignores item variability in priming; anti-conservative): ",
                   "%.2f ms, 95%% CI [%.2f, %.2f]\n"),
            cs["Estimate"],
            cs["Estimate"] - qt(0.975, cs["df"]) * cs["Std. Error"],
            cs["Estimate"] + qt(0.975, cs["df"]) * cs["Std. Error"]))

# ------------------------------------------------------------- result ----
cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, lower, upper))
