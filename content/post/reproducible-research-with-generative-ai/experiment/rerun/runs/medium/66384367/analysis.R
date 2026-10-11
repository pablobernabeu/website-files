# Priming effect in a lexical decision task, estimated with a linear
# mixed-effects model (all rows, untransformed RT).
suppressPackageStartupMessages(library(lme4))

d <- read.csv("data.csv", stringsAsFactors = FALSE)
stopifnot(all(d$prime %in% c("related", "unrelated")), !anyNA(d$rt))
d$participant <- factor(d$participant)
d$item <- factor(d$item)

# Effect coding: the prime_c coefficient is unrelated minus related.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

cat("Rows:", nrow(d), " Participants:", nlevels(d$participant),
    " Items:", nlevels(d$item), "\n")
print(aggregate(rt ~ prime, data = d, FUN = mean))

fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)
print(summary(fit))
if (isSingular(fit)) cat("Note: the fit is singular.\n")
msgs <- fit@optinfo$conv$lme4$messages
if (length(msgs)) cat("Convergence messages:", msgs, sep = "\n  ")

est <- unname(fixef(fit)["prime_c"])
ci <- confint(fit, parm = "prime_c", method = "Wald")
cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci[1, 1], ci[1, 2]))
