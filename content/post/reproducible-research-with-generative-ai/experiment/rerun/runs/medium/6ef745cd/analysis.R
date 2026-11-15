# Priming effect in lexical decision: linear mixed-effects model on raw RTs.
suppressPackageStartupMessages(library(lme4))

dat <- read.csv("data.csv", stringsAsFactors = FALSE)

# Basic checks: every row is kept, no exclusions or transformations.
stopifnot(all(dat$prime %in% c("related", "unrelated")), !anyNA(dat$rt))
cat("Rows:", nrow(dat), " Participants:", length(unique(dat$participant)),
    " Items:", length(unique(dat$item)), "\n")
print(aggregate(rt ~ prime, data = dat, FUN = mean))

# Deviation coding: related = -0.5, unrelated = +0.5, so the slope is the
# unrelated-minus-related difference in ms.
dat$prime_c <- ifelse(dat$prime == "related", -0.5, 0.5)

fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = dat, REML = TRUE)
print(summary(fit))

est <- unname(fixef(fit)["prime_c"])
ci  <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci["prime_c", 1], ci["prime_c", 2]))
