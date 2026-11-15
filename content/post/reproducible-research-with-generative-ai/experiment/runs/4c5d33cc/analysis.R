# Semantic priming in lexical decision: linear mixed-effects analysis
# Estimates the priming effect (unrelated - related RT, in ms) with a 95% Wald CI.

suppressPackageStartupMessages(library(lme4))

# Read data (correct responses only; incorrect trials already removed)
d <- read.csv("data.csv", stringsAsFactors = FALSE)

# Basic checks on the data
stopifnot(all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)))
stopifnot(all(d$prime %in% c("related", "unrelated")))
stopifnot(!anyNA(d$rt))

cat("Rows:", nrow(d),
    "| Participants:", length(unique(d$participant)),
    "| Items:", length(unique(d$item)), "\n")
print(table(d$prime))

# Grouping factors
d$participant <- factor(d$participant)
d$item <- factor(d$item)

# Deviation-code prime: related = -0.5, unrelated = +0.5
d$prime_c <- ifelse(d$prime == "related", -0.5, 0.5)

# Linear mixed-effects model, REML, default optimiser; rt untransformed, no exclusions
fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)

print(summary(fit))

# Convergence / singularity diagnostics
if (isSingular(fit)) cat("Note: fit is singular.\n")
conv_msgs <- fit@optinfo$conv$lme4$messages
if (length(conv_msgs) > 0) cat("Convergence messages:", conv_msgs, sep = "\n  ")

# Priming effect: fixed effect of prime_c (unrelated minus related, ms)
estimate <- unname(fixef(fit)["prime_c"])
ci <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("\nPriming effect: %.2f ms, 95%% Wald CI [%.2f, %.2f]\n",
            estimate, ci["prime_c", 1], ci["prime_c", 2]))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            estimate, ci["prime_c", 1], ci["prime_c", 2]))
