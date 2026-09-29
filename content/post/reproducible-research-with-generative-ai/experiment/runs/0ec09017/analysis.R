# Semantic priming in lexical decision: size of the priming effect.
# Priming effect = RT after unrelated primes minus RT after related primes.

suppressPackageStartupMessages(library(lme4))

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# Basic checks: every row is used, with no exclusions and no transformation of rt.
stopifnot(all(d$prime %in% c("related", "unrelated")),
          !anyNA(d$rt))

# Contrast code: related = -0.5, unrelated = +0.5,
# so the prime_c coefficient is the unrelated - related difference in ms.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

cat("Rows:", nrow(d),
    "| participants:", length(unique(d$participant)),
    "| items:", length(unique(d$item)), "\n")
cat("Rows per condition:\n"); print(table(d$prime))
cat("Mean RT per condition (ms):\n"); print(round(tapply(d$rt, d$prime, mean), 1))

# Linear mixed-effects model, REML, default optimiser.
fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)
print(summary(fit))

# Report any convergence or singular-fit messages.
msgs <- fit@optinfo$conv$lme4$messages
if (length(msgs)) cat("Convergence messages:", msgs, sep = "\n  ")
cat("Singular fit:", isSingular(fit), "\n")

est <- unname(fixef(fit)["prime_c"])
ci  <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("Priming effect (unrelated - related): %.2f ms, 95%% Wald CI [%.2f, %.2f]\n",
            est, ci[1, 1], ci[1, 2]))
cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, ci[1, 1], ci[1, 2]))
