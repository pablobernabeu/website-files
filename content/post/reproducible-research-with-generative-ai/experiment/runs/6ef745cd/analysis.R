# Semantic priming in lexical decision: size of the priming effect.
# Priming effect = RT after unrelated prime minus RT after related prime (ms).
# Every row is used, with no exclusions and no transformation of rt.

suppressPackageStartupMessages(library(lme4))

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# Sum-coded prime: related = -0.5, unrelated = +0.5.
# The prime_c coefficient is then the unrelated - related difference.
prime_codes <- c(related = -0.5, unrelated = 0.5)
d$prime_c <- unname(prime_codes[d$prime])
if (anyNA(d$prime_c)) {
  stop("Unexpected values in 'prime': ",
       paste(unique(d$prime[is.na(d$prime_c)]), collapse = ", "))
}

d$participant <- factor(d$participant)
d$item <- factor(d$item)

cat("Rows:", nrow(d),
    "| participants:", nlevels(d$participant),
    "| items:", nlevels(d$item), "\n")
cat("Condition means (ms):\n")
print(round(tapply(d$rt, d$prime, mean), 2))

# Linear mixed-effects model: REML, default optimiser.
fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)

print(summary(fit))

# Report fit diagnostics so a problem is visible rather than silent.
conv_msgs <- fit@optinfo$conv$lme4$messages
if (length(conv_msgs) > 0) {
  cat("Convergence messages:\n", paste(conv_msgs, collapse = "\n"), "\n")
}
cat("Singular fit:", isSingular(fit), "\n")

estimate <- unname(fixef(fit)["prime_c"])
ci <- confint(fit, parm = "prime_c", method = "Wald")
lower <- unname(ci["prime_c", 1])
upper <- unname(ci["prime_c", 2])

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            estimate, lower, upper))
