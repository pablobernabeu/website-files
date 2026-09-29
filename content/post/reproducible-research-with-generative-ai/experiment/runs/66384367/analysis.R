# Semantic priming in lexical decision: size of the priming effect
# (unrelated minus related RT, in ms) from a linear mixed-effects model.

suppressPackageStartupMessages(library(lme4))

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# Guard against unexpected prime labels, which would silently become NA below
stopifnot(all(d$prime %in% c("related", "unrelated")))

# Contrast coding: related = -0.5, unrelated = +0.5, so the prime_c slope
# is the unrelated - related difference in ms
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

cat("Rows:", nrow(d),
    "| participants:", length(unique(d$participant)),
    "| items:", length(unique(d$item)), "\n")
cat("Cell means (ms):\n")
print(aggregate(rt ~ prime, data = d, FUN = mean))

# All rows, raw rt, REML, default optimiser
fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)

print(summary(fit))

# Surface any convergence or singular-fit messages
conv_msgs <- fit@optinfo$conv$lme4$messages
if (length(conv_msgs) > 0) {
  cat("Convergence messages:\n")
  print(conv_msgs)
}
cat("Singular fit:", isSingular(fit), "\n")

est <- unname(fixef(fit)["prime_c"])
ci  <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci["prime_c", 1], ci["prime_c", 2]))
