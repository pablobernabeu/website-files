# Semantic priming effect in lexical decision (correct responses only).
# Priming effect = RT(unrelated) - RT(related), in milliseconds.
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

cat("Observations:", nrow(d), " participants:", nlevels(d$participant),
    " items:", nlevels(d$item), "\n")
print(aggregate(rt ~ prime, d, function(x) c(mean = mean(x), sd = sd(x))))

# Sum-coded prime (+0.5 unrelated, -0.5 related), so the coefficient is the
# unrelated - related difference in ms; frequency is centred.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)
d$freq_c <- d$frequency - mean(d$frequency)

# Maximal random-effects structure justified by the design: prime varies
# within participants and within items. Fall back to simpler structures if
# the fit is singular or fails to converge.
forms <- list(
  rt ~ prime_c + freq_c + (1 + prime_c | participant) + (1 + prime_c | item),
  rt ~ prime_c + freq_c + (1 + prime_c || participant) + (1 + prime_c || item),
  rt ~ prime_c + freq_c + (1 + prime_c | participant) + (1 | item),
  rt ~ prime_c + freq_c + (1 | participant) + (1 | item)
)
ctrl <- lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
fit <- NULL
for (f in forms) {
  m <- tryCatch(lmer(f, data = d, REML = TRUE, control = ctrl),
                error = function(e) NULL)
  if (is.null(m)) next
  conv_ok <- length(m@optinfo$conv$lme4$messages) == 0
  if (!isSingular(m) && conv_ok) { fit <- m; break }
  if (is.null(fit)) fit <- m
}
cat("\nSelected model:\n"); print(formula(fit))
print(summary(fit))

# Satterthwaite-based 95% CI for the priming effect.
co <- summary(fit, ddf = "Satterthwaite")$coefficients["prime_c", ]
tcrit <- qt(0.975, co["df"])
est <- unname(co["Estimate"])
lower <- unname(est - tcrit * co["Std. Error"])
upper <- unname(est + tcrit * co["Std. Error"])

# Sanity check: by-participant paired difference.
pm <- with(d, tapply(rt, list(participant, prime), mean))
cat("\nBy-participant mean difference (paired t):\n")
print(t.test(pm[, "unrelated"], pm[, "related"], paired = TRUE)$conf.int)

cat(sprintf("\nPriming effect: %.1f ms, 95%% CI [%.1f, %.1f]\n", est, lower, upper))
cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, lower, upper))
