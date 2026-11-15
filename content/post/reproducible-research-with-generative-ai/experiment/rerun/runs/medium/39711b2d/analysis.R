# Priming effect in a lexical decision task: linear mixed-effects model
suppressPackageStartupMessages(library(lme4))

dat <- read.csv("data.csv", stringsAsFactors = FALSE)
stopifnot(all(dat$prime %in% c("related", "unrelated")))

dat$participant <- factor(dat$participant)
dat$item <- factor(dat$item)
dat$prime_c <- ifelse(dat$prime == "related", -0.5, 0.5)

cat("Rows:", nrow(dat), " Participants:", nlevels(dat$participant),
    " Items:", nlevels(dat$item), "\n")
print(aggregate(rt ~ prime, data = dat, FUN = mean))

fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = dat, REML = TRUE)
print(summary(fit))

est <- unname(fixef(fit)["prime_c"])
ci <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("RESULT estimate=%.4f lower=%.4f upper=%.4f\n",
            est, ci["prime_c", 1], ci["prime_c", 2]))
