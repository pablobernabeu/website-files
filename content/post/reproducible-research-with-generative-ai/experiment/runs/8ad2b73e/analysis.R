# Semantic priming effect in lexical decision: linear mixed-effects model
#
# Estimates how much slower correct responses are after unrelated primes than
# after related primes, with a 95% Wald confidence interval.

suppressPackageStartupMessages(library(lme4))

# Read the data (all rows, no exclusions, rt left untransformed)
d <- read.csv("data.csv", stringsAsFactors = FALSE)

stopifnot(all(d$prime %in% c("related", "unrelated")))

# Sum-to-zero coding of prime: related = -0.5, unrelated = +0.5.
# With this coding the fixed effect of prime_c is the unrelated - related
# difference in ms, i.e. the priming effect.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)
d$participant <- factor(d$participant)
d$item <- factor(d$item)

cat("Rows:", nrow(d),
    "| participants:", nlevels(d$participant),
    "| items:", nlevels(d$item), "\n")
print(table(d$prime, d$prime_c))

# Maximal model for this design: by-participant and by-item random intercepts
# and random slopes for prime. REML, default optimiser.
fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)

print(summary(fit))

# Report any convergence or singular-fit messages
msgs <- fit@optinfo$conv$lme4$messages
if (!is.null(msgs)) cat("Convergence messages:", msgs, sep = "\n  ")
cat("Singular fit:", isSingular(fit), "\n")

# Priming effect and 95% Wald CI
est <- unname(fixef(fit)["prime_c"])
ci  <- confint(fit, parm = "prime_c", method = "Wald")
lower <- ci["prime_c", 1]
upper <- ci["prime_c", 2]

cat(sprintf("\nPriming effect (unrelated - related): %.2f ms, 95%% Wald CI [%.2f, %.2f]\n",
            est, lower, upper))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, lower, upper))
