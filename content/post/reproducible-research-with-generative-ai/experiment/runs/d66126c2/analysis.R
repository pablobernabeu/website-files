# Semantic priming effect in lexical decision (correct responses only).
# Priming effect = RT after unrelated prime minus RT after related prime,
# estimated as the fixed effect of prime_c in a linear mixed-effects model.

suppressPackageStartupMessages(library(lme4))

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# Sanity checks on the input (no rows are excluded or transformed).
stopifnot(
  all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)),
  all(d$prime %in% c("related", "unrelated")),
  !anyNA(d$rt)
)

d$participant <- factor(d$participant)
d$item        <- factor(d$item)

# Deviation coding: related = -0.5, unrelated = +0.5, so the prime_c
# coefficient is the unrelated - related difference in ms.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

cat("Rows:", nrow(d),
    "| participants:", nlevels(d$participant),
    "| items:", nlevels(d$item), "\n")
cat("Rows per condition:\n")
print(table(d$prime))

fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)

print(summary(fit))

conv_msgs <- fit@optinfo$conv$lme4$messages
if (length(conv_msgs) > 0) {
  cat("Convergence messages:\n")
  cat(paste0("  ", conv_msgs, collapse = "\n"), "\n")
}
cat("Singular fit:", isSingular(fit), "\n")

estimate <- unname(fixef(fit)["prime_c"])
ci <- confint(fit, parm = "prime_c", method = "Wald")
lower <- unname(ci["prime_c", 1])
upper <- unname(ci["prime_c", 2])

cat(sprintf("Priming effect (unrelated - related): %.2f ms, 95%% Wald CI [%.2f, %.2f]\n",
            estimate, lower, upper))
cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", estimate, lower, upper))
