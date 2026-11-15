# Priming effect in a lexical decision task: unrelated minus related RT (ms).
suppressPackageStartupMessages(library(lme4))

dat <- read.csv("data.csv", stringsAsFactors = FALSE)
stopifnot(all(dat$prime %in% c("related", "unrelated")))

# Deviation coding: the prime_c coefficient is the unrelated - related difference.
dat$prime_c <- ifelse(dat$prime == "related", -0.5, 0.5)

fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = dat, REML = TRUE)
print(summary(fit))

est <- unname(fixef(fit)["prime_c"])
ci  <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci["prime_c", 1], ci["prime_c", 2]))
