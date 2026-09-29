# Semantic priming in lexical decision: size of the priming effect
#
# Reads data.csv (correct responses only; columns participant, item, prime,
# frequency, rt), fits a linear mixed-effects model with maximal random
# effects for prime by participant and by item, and reports the fixed effect
# of prime (unrelated minus related) in milliseconds with a 95% Wald CI.

suppressPackageStartupMessages(library(lme4))

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# Use every row, no exclusions, rt untransformed.
stopifnot(all(d$prime %in% c("related", "unrelated")))
d$participant <- factor(d$participant)
d$item        <- factor(d$item)

# Sum-to-zero contrast: related = -0.5, unrelated = +0.5, so the prime_c
# coefficient is the unrelated - related difference (the priming effect).
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

cat("Rows:", nrow(d),
    "| participants:", nlevels(d$participant),
    "| items:", nlevels(d$item), "\n")
cat("Cell means (ms):\n")
print(tapply(d$rt, d$prime, mean))

# REML (lmer default) with the default optimiser.
fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)

print(summary(fit))

conv_msgs <- fit@optinfo$conv$lme4$messages
if (!is.null(conv_msgs)) {
  cat("Convergence messages:\n")
  print(conv_msgs)
}
cat("Singular fit:", isSingular(fit), "\n")

est <- unname(fixef(fit)["prime_c"])
ci  <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("Priming effect (unrelated - related): %.2f ms, 95%% Wald CI [%.2f, %.2f]\n",
            est, ci[1, 1], ci[1, 2]))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci[1, 1], ci[1, 2]))
