# Semantic priming in lexical decision: size of the priming effect
# (unrelated minus related RT, in ms) from a linear mixed-effects model.

suppressPackageStartupMessages(library(lme4))

dat <- read.csv("data.csv", stringsAsFactors = FALSE)

# Sanity checks: every row is used, with no exclusions or transformation of rt
stopifnot(
  all(dat$prime %in% c("related", "unrelated")),
  !anyNA(dat$rt)
)

# Deviation coding: related = -0.5, unrelated = +0.5, so the prime_c
# coefficient is the unrelated - related difference (the priming effect)
dat$prime_c <- ifelse(dat$prime == "unrelated", 0.5, -0.5)

cat("Rows analysed:", nrow(dat), "\n")
cat("Participants:", length(unique(dat$participant)),
    " Items:", length(unique(dat$item)), "\n")
cat("Cell means (ms):\n")
print(tapply(dat$rt, dat$prime, mean))

# Maximal model for this design, fitted with REML and the default optimiser
fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = dat, REML = TRUE)

print(summary(fit))

conv_msgs <- fit@optinfo$conv$lme4$messages
if (length(conv_msgs) > 0) {
  cat("Convergence messages:\n")
  print(conv_msgs)
}
cat("Singular fit:", isSingular(fit), "\n")

estimate <- unname(fixef(fit)["prime_c"])
ci <- confint(fit, parm = "prime_c", method = "Wald")
lower <- ci["prime_c", 1]
upper <- ci["prime_c", 2]

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            estimate, lower, upper))
