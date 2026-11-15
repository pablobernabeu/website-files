# Priming effect in lexical decision RTs: linear mixed-effects model.
suppressPackageStartupMessages(library(lme4))

d <- read.csv("data.csv", stringsAsFactors = FALSE)
stopifnot(all(d$prime %in% c("related", "unrelated")), !anyNA(d$rt))
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

cat("Rows:", nrow(d), " participants:", length(unique(d$participant)),
    " items:", length(unique(d$item)), "\n")
print(aggregate(rt ~ prime, data = d, FUN = mean))

fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)
print(summary(fit))
if (length(fit@optinfo$conv$lme4$messages))
  cat("Convergence messages:", fit@optinfo$conv$lme4$messages, sep = "\n")
cat("Singular fit:", isSingular(fit), "\n")

est <- unname(fixef(fit)["prime_c"])
ci  <- confint(fit, parm = "prime_c", method = "Wald")
cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci[1, 1], ci[1, 2]))
