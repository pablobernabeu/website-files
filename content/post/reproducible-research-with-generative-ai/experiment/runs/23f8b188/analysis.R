# Semantic priming in lexical decision: size of the priming effect
# (unrelated minus related RT), estimated with a linear mixed-effects model.

suppressPackageStartupMessages(library(lme4))

# Read the data (correct responses only; no exclusions, rt untransformed)
d <- read.csv("data.csv", stringsAsFactors = FALSE)

stopifnot(all(d$prime %in% c("related", "unrelated")), !anyNA(d$rt))

# Sum-coded prime: related = -0.5, unrelated = +0.5, so the prime_c
# coefficient is the unrelated - related difference in ms
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

cat("Rows:", nrow(d),
    " Participants:", length(unique(d$participant)),
    " Items:", length(unique(d$item)), "\n")
print(aggregate(rt ~ prime, data = d, FUN = mean))

# Maximal model with by-participant and by-item random intercepts and slopes;
# REML and the default optimiser
fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)
print(summary(fit))

est <- unname(fixef(fit)["prime_c"])
ci  <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci["prime_c", 1], ci["prime_c", 2]))
