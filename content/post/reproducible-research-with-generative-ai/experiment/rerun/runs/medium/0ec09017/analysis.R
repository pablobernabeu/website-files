# Priming effect in a lexical decision task, estimated with a linear
# mixed-effects model (lme4, REML, default optimiser).
suppressPackageStartupMessages(library(lme4))

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# Basic checks on the input: every row is used, with no exclusions.
stopifnot(all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)))
stopifnot(all(d$prime %in% c("related", "unrelated")), !anyNA(d$rt))
cat("Rows:", nrow(d), " Participants:", length(unique(d$participant)),
    " Items:", length(unique(d$item)), "\n")
print(aggregate(rt ~ prime, data = d, FUN = mean))

# Contrast coding: related = -0.5, unrelated = +0.5, so the fixed effect of
# prime_c is the unrelated-minus-related difference in ms.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)
d$participant <- factor(d$participant)
d$item <- factor(d$item)

fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)
print(summary(fit))
msgs <- fit@optinfo$conv$lme4$messages
if (!is.null(msgs)) cat("Convergence messages:", msgs, sep = "\n")
cat("Singular fit:", isSingular(fit), "\n")

est <- unname(fixef(fit)["prime_c"])
ci <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("RESULT estimate=%.4f lower=%.4f upper=%.4f\n",
            est, ci[1, 1], ci[1, 2]))
