# Semantic priming in lexical decision: size of the priming effect
# (unrelated minus related RT, in ms) estimated with a linear mixed-effects model.

suppressPackageStartupMessages(library(lme4))

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# Basic sanity checks (no rows are excluded)
stopifnot(all(d$prime %in% c("related", "unrelated")))
stopifnot(!anyNA(d[, c("participant", "item", "prime", "rt")]))

d$participant <- factor(d$participant)
d$item        <- factor(d$item)

# Deviation coding: related = -0.5, unrelated = +0.5, so the prime_c
# coefficient is the unrelated - related difference (the priming effect).
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

cat("Rows:", nrow(d),
    "| participants:", nlevels(d$participant),
    "| items:", nlevels(d$item), "\n")
cat("Rows per condition:\n")
print(table(d$prime))
cat("\nObserved mean RT by condition (ms):\n")
print(round(tapply(d$rt, d$prime, mean), 1))

# Linear mixed-effects model: REML, default optimiser
fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)

cat("\n")
print(summary(fit))

# Report any convergence / singular-fit messages
conv_msgs <- fit@optinfo$conv$lme4$messages
if (length(conv_msgs) > 0) {
  cat("\nConvergence messages:\n")
  cat(paste0("  ", conv_msgs, "\n"), sep = "")
}
cat("Singular fit:", isSingular(fit), "\n")

# Priming effect and its 95% Wald confidence interval
est <- unname(fixef(fit)["prime_c"])
ci  <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("\nPriming effect (unrelated - related): %.2f ms, 95%% Wald CI [%.2f, %.2f]\n",
            est, ci[1, 1], ci[1, 2]))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci[1, 1], ci[1, 2]))
