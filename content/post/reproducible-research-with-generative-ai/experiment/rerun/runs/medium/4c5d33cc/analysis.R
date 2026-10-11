# Priming effect in a lexical decision task, estimated with a linear
# mixed-effects model (REML, default optimiser), using every row of data.csv.
library(lme4)

dat <- read.csv("data.csv", stringsAsFactors = FALSE)

# Check the prime levels before coding, so an unexpected label cannot become NA.
stopifnot(all(dat$prime %in% c("related", "unrelated")))
dat$prime_c <- ifelse(dat$prime == "unrelated", 0.5, -0.5)

cat("Rows:", nrow(dat), " Participants:", length(unique(dat$participant)),
    " Items:", length(unique(dat$item)), "\n")
print(aggregate(rt ~ prime, data = dat, FUN = mean))

fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = dat, REML = TRUE)
print(summary(fit))

msgs <- fit@optinfo$conv$lme4$messages
if (length(msgs)) cat("Convergence messages:", msgs, sep = "\n")
cat("Singular fit:", isSingular(fit), "\n")

est <- unname(fixef(fit)["prime_c"])
ci  <- confint(fit, parm = "prime_c", method = "Wald")

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci["prime_c", 1], ci["prime_c", 2]))
