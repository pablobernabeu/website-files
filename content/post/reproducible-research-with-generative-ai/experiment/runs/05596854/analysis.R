# Semantic priming in lexical decision: size of the priming effect
#
# Data: data.csv (correct responses only), columns
#   participant, item, prime (related/unrelated), frequency (Zipf), rt (ms)
#
# Analysis (as specified):
#   - all rows, no exclusions, rt untransformed (ms)
#   - prime_c = -0.5 (related), +0.5 (unrelated)
#   - lme4::lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item)),
#     REML, default optimiser
#   - estimate = fixed effect of prime_c (unrelated minus related, in ms)
#   - 95% Wald CI from confint(fit, parm = "prime_c", method = "Wald")

suppressPackageStartupMessages(library(lme4))

# Resolve the script's own directory so data.csv is found regardless of cwd
script_dir <- tryCatch({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(file_arg) == 1) dirname(normalizePath(file_arg)) else getwd()
}, error = function(e) getwd())

d <- read.csv(file.path(script_dir, "data.csv"), stringsAsFactors = FALSE)

# Basic checks on the input
stopifnot(all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)))
stopifnot(all(d$prime %in% c("related", "unrelated")))
stopifnot(!anyNA(d$rt))

d$participant <- factor(d$participant)
d$item        <- factor(d$item)

# Contrast coding: related = -0.5, unrelated = +0.5
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

cat("Rows used:", nrow(d),
    "| participants:", nlevels(d$participant),
    "| items:", nlevels(d$item), "\n")
cat("Observed cell means (ms):\n")
print(round(tapply(d$rt, d$prime, mean), 2))
cat("\n")

# Linear mixed-effects model: REML (default) and default optimiser
fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)

print(summary(fit))

# Report any convergence / singularity messages
msgs <- fit@optinfo$conv$lme4$messages
if (!is.null(msgs)) {
  cat("\nConvergence messages:\n")
  print(msgs)
}
cat("Singular fit:", isSingular(fit), "\n\n")

# Fixed effect of prime_c and its 95% Wald CI
est <- unname(fixef(fit)["prime_c"])
ci  <- confint(fit, parm = "prime_c", method = "Wald", level = 0.95)
lower <- unname(ci["prime_c", 1])
upper <- unname(ci["prime_c", 2])

cat(sprintf("Priming effect (unrelated - related): %.2f ms, 95%% Wald CI [%.2f, %.2f]\n\n",
            est, lower, upper))

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n", est, lower, upper))
