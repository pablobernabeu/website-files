# Priming effect in a lexical decision task: linear mixed-effects model.
# Uses every row of data.csv, untransformed rt, and the pre-specified model.

suppressPackageStartupMessages(library(lme4))

dat <- read.csv("data.csv", stringsAsFactors = FALSE)

stopifnot(all(dat$prime %in% c("related", "unrelated")))
dat$participant <- factor(dat$participant)
dat$item <- factor(dat$item)
# Deviation coding: the fixed effect equals unrelated minus related.
dat$prime_c <- ifelse(dat$prime == "related", -0.5, 0.5)

cat("Rows:", nrow(dat), " Participants:", nlevels(dat$participant),
    " Items:", nlevels(dat$item), "\n")
print(aggregate(rt ~ prime, data = dat, FUN = mean))

fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = dat, REML = TRUE)
print(summary(fit))

msgs <- fit@optinfo$conv$lme4$messages
if (!is.null(msgs)) cat("Convergence messages:", msgs, sep = "\n")
cat("Singular fit:", isSingular(fit), "\n")

est <- unname(fixef(fit)["prime_c"])
ci <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci[1, 1], ci[1, 2]))
