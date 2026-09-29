# Semantic priming in lexical decision: size of the priming effect (ms)
# Model: rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item)
# fitted with lme4::lmer (REML, default optimiser); 95% Wald CI for prime_c.

suppressPackageStartupMessages(library(lme4))

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# Sanity checks (no rows are excluded; rt is used untransformed)
stopifnot(
  all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)),
  all(d$prime %in% c("related", "unrelated")),
  !anyNA(d$rt)
)

# Deviation coding: related = -0.5, unrelated = +0.5,
# so the prime_c coefficient is (unrelated - related), i.e. the priming effect.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)
d$participant <- factor(d$participant)
d$item <- factor(d$item)

cat("Rows:", nrow(d), " Participants:", nlevels(d$participant),
    " Items:", nlevels(d$item), "\n")
cat("Cell means (ms):\n")
print(aggregate(rt ~ prime, data = d, FUN = mean))

fit <- lme4::lmer(
  rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
  data = d,
  REML = TRUE
)

print(summary(fit))

# Report any convergence / singularity messages from the fit
msgs <- fit@optinfo$conv$lme4$messages
if (!is.null(msgs)) cat("Convergence messages:", msgs, sep = "\n  ")
cat("Singular fit:", isSingular(fit), "\n")

est <- unname(fixef(fit)["prime_c"])
ci <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci["prime_c", 1], ci["prime_c", 2]))
