# Priming effect in a lexical decision task: linear mixed-effects model.
suppressPackageStartupMessages(library(lme4))

d <- read.csv("data.csv", stringsAsFactors = FALSE)
stopifnot(all(d$prime %in% c("related", "unrelated")))

d$participant <- factor(d$participant)
d$item <- factor(d$item)
# Deviation coding: the fixed effect is unrelated minus related, in ms.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

cat("Rows:", nrow(d), " participants:", nlevels(d$participant),
    " items:", nlevels(d$item), "\n")
print(table(d$prime))

fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)
print(summary(fit))

msgs <- fit@optinfo$conv$lme4$messages
if (length(msgs)) cat("Convergence messages:", msgs, sep = "\n  ")
cat("Singular fit:", isSingular(fit), "\n")

est <- unname(fixef(fit)["prime_c"])
ci <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci["prime_c", 1], ci["prime_c", 2]))
