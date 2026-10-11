# Priming effect in a lexical decision task: linear mixed-effects model.
suppressPackageStartupMessages(library(lme4))

d <- read.csv("data.csv", stringsAsFactors = FALSE)
stopifnot(all(d$prime %in% c("related", "unrelated")))

# Contrast code: related = -0.5, unrelated = +0.5, so the slope is the
# unrelated minus related difference in ms.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)
d$participant <- factor(d$participant)
d$item <- factor(d$item)

cat("Rows:", nrow(d), " Participants:", nlevels(d$participant),
    " Items:", nlevels(d$item), "\n")

fit <- lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
            data = d, REML = TRUE)
print(summary(fit))
if (length(fit@optinfo$conv$lme4$messages))
  cat("Convergence messages:", fit@optinfo$conv$lme4$messages, sep = "\n")
cat("Singular fit:", isSingular(fit), "\n")

est <- fixef(fit)[["prime_c"]]
ci <- confint(fit, parm = "prime_c", method = "Wald")
cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci[1, 1], ci[1, 2]))
