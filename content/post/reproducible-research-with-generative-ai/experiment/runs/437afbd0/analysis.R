# Semantic priming in lexical decision: size of the priming effect
#
# Priming effect = RT after unrelated primes minus RT after related primes (ms),
# estimated as the fixed effect of a centred prime contrast in a linear
# mixed-effects model with by-participant and by-item random intercepts and
# random prime slopes. All rows are used; rt is left untransformed.

suppressPackageStartupMessages(library(lme4))

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# Sanity checks on the design
stopifnot(
  all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)),
  !anyNA(d$rt),
  setequal(unique(d$prime), c("related", "unrelated"))
)

# Centred contrast: related = -0.5, unrelated = +0.5
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

cat("Rows:", nrow(d),
    "| participants:", length(unique(d$participant)),
    "| items:", length(unique(d$item)), "\n")
cat("Cell means (ms):\n")
print(round(tapply(d$rt, d$prime, mean), 2))

# Linear mixed-effects model (REML, default optimiser)
fit <- lmer(
  rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
  data = d,
  REML = TRUE
)

print(summary(fit))

# Report any convergence or singular-fit messages
conv_msgs <- fit@optinfo$conv$lme4$messages
if (length(conv_msgs) > 0) {
  cat("Convergence messages:\n")
  cat(paste0("  ", conv_msgs, collapse = "\n"), "\n")
}
cat("Singular fit:", isSingular(fit), "\n")

# Priming effect and its 95% Wald confidence interval
estimate <- unname(fixef(fit)["prime_c"])
ci <- confint(fit, parm = "prime_c", method = "Wald", level = 0.95)
lower <- unname(ci["prime_c", 1])
upper <- unname(ci["prime_c", 2])

cat(sprintf("\nPriming effect (unrelated - related): %.2f ms, 95%% Wald CI [%.2f, %.2f]\n",
            estimate, lower, upper))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", estimate, lower, upper))
