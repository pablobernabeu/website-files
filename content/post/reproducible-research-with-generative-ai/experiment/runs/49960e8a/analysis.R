# Semantic priming in lexical decision: size of the priming effect (ms)
#
# Model: rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item)
# fitted with lme4::lmer() (REML, default optimiser), all rows, raw rt.
# prime_c = -0.5 (related), +0.5 (unrelated), so the prime_c fixed effect is
# the unrelated - related difference in ms (positive = priming facilitation).

library(lme4)

d <- read.csv("data.csv", stringsAsFactors = FALSE)

# Sanity checks: no exclusions are made, so fail loudly on unexpected input
stopifnot(all(c("participant", "item", "prime", "frequency", "rt") %in% names(d)))
stopifnot(all(d$prime %in% c("related", "unrelated")))
stopifnot(!anyNA(d$rt))

d$participant <- factor(d$participant)
d$item <- factor(d$item)
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

cat(sprintf("Rows: %d, participants: %d, items: %d\n",
            nrow(d), nlevels(d$participant), nlevels(d$item)))
print(aggregate(rt ~ prime, data = d, FUN = mean))

fit <- lme4::lmer(rt ~ prime_c + (1 + prime_c | participant) + (1 + prime_c | item),
                  data = d, REML = TRUE)

print(summary(fit))
cat("Singular fit:", isSingular(fit), "\n")
conv_msgs <- fit@optinfo$conv$lme4$messages
if (length(conv_msgs)) cat("Convergence messages:", conv_msgs, sep = "\n  ")

est <- unname(fixef(fit)["prime_c"])
ci <- confint(fit, parm = "prime_c", method = "Wald")
print(ci)

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            est, ci["prime_c", 1], ci["prime_c", 2]))
