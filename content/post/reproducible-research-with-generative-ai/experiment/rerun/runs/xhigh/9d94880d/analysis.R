# Semantic priming in lexical decision: size of the priming effect
#
# Estimates how much slower correct responses are after unrelated primes
# than after related primes, in milliseconds, with a 95% confidence interval.
#
# Design: 30 participants x 24 target words, each target seen once after a
# related and once after an unrelated prime. Prime is therefore manipulated
# within participants and within items, so both participants and items are
# samples that the conclusion should generalise over (Clark, 1973). The
# analysis is a linear mixed-effects model with crossed random effects for
# participants and items. It starts from the maximal random-effects structure
# the design justifies, with by-participant and by-item random slopes for
# prime (Barr, Levy, Scheepers & Tily, 2013). If that fit is singular, the
# structure is simplified by a fixed rule (Bates, Kliegl, Vasishth & Baayen,
# 2015; Matuschek, Kliegl, Vasishth, Baayen & Bates, 2017): first the
# random-effect correlations are removed, then any variance component
# estimated at zero is dropped, until the fit is no longer singular.
#
# Response time is modelled on its raw millisecond scale so that the prime
# coefficient is directly the effect in milliseconds. The 95% confidence
# interval uses Satterthwaite degrees of freedom (Luke, 2017).
#
# Run from this directory with: Rscript analysis.R

suppressPackageStartupMessages({
  library(lme4)
  library(lmerTest)
})

# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

d <- read.csv("data.csv", stringsAsFactors = FALSE)

required <- c("participant", "item", "prime", "frequency", "rt")
stopifnot(all(required %in% names(d)))
stopifnot(!anyNA(d[required]))
stopifnot(setequal(unique(d$prime), c("related", "unrelated")))

d$participant <- factor(d$participant)
d$item        <- factor(d$item)
d$prime       <- factor(d$prime, levels = c("related", "unrelated"))

# The design should be fully crossed: every participant sees every item once
# per prime condition. Check this instead of assuming it.
cells <- table(d$participant, d$item, d$prime)
cat(sprintf("Participants: %d, items: %d, trials: %d\n",
            nlevels(d$participant), nlevels(d$item), nrow(d)))
cat(sprintf("Trials per participant x item x prime cell: min %d, max %d\n",
            min(cells), max(cells)))

# Frequency is a property of the target word, so it must be constant within
# each item.
stopifnot(all(tapply(d$frequency, d$item,
                     function(x) length(unique(x)) == 1)))

cat(sprintf("RT range: %d to %d ms (median %g)\n",
            min(d$rt), max(d$rt), median(d$rt)))
# No RT lies outside the bounds commonly used to remove anticipations and
# lapses in lexical decision (200 to 3000 ms), so no trials are excluded.
stopifnot(all(d$rt >= 200 & d$rt <= 3000))

# ---------------------------------------------------------------------------
# Descriptives
# ---------------------------------------------------------------------------

cond_means <- tapply(d$rt, d$prime, mean)
cat("\nMean RT by prime condition (ms):\n")
print(round(cond_means, 1))
cat(sprintf("Raw difference, unrelated - related: %.2f ms\n",
            cond_means[["unrelated"]] - cond_means[["related"]]))

# ---------------------------------------------------------------------------
# Model specification
# ---------------------------------------------------------------------------

# Deviation coding (related = -0.5, unrelated = +0.5): the prime coefficient
# is the unrelated minus related difference in ms, and the intercept is the
# grand mean.
d$prime_c <- ifelse(d$prime == "unrelated", 0.5, -0.5)

# Word frequency is a strong item-level predictor of lexical decision times,
# so it is entered (centred over items) to absorb item variance in overall
# speed. As it varies only between items and prime is balanced within every
# item, it does not change the priming estimate itself.
d$frequency_c <- d$frequency - mean(tapply(d$frequency, d$item, mean))

fixed_part <- "rt ~ prime_c + frequency_c"
ctrl <- lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))

fit <- function(random_part) {
  f <- as.formula(paste(fixed_part, "+", random_part))
  # Singularity is handled explicitly below, so lme4's message is muted.
  # bquote() embeds the formula in the stored call, so summaries print it
  # and update() can refit the model.
  suppressMessages(eval(bquote(
    lmer(.(f), data = d, REML = TRUE, control = ctrl))))
}

converged <- function(m) {
  msgs <- m@optinfo$conv$lme4$messages
  is.null(msgs) || all(grepl("singular", msgs))
}

# Build an uncorrelated random-effects part from a list giving, for each
# grouping factor, which of "(Intercept)" and "prime_c" to keep.
zero_corr_terms <- function(keep) {
  terms <- character(0)
  for (g in names(keep)) {
    k <- keep[[g]]
    if (length(k) == 0) next
    term <- if (identical(sort(k), c("(Intercept)", "prime_c"))) {
      sprintf("(1 + prime_c || %s)", g)
    } else if (identical(k, "(Intercept)")) {
      sprintf("(1 | %s)", g)
    } else {
      sprintf("(0 + prime_c | %s)", g)
    }
    terms <- c(terms, term)
  }
  paste(terms, collapse = " + ")
}

# ---------------------------------------------------------------------------
# Random-effects selection
# ---------------------------------------------------------------------------

maximal_re <- "(1 + prime_c | participant) + (1 + prime_c | item)"
m_max <- fit(maximal_re)
stopifnot(converged(m_max))

cat("\nMaximal model random effects:\n")
print(VarCorr(m_max))
cat("Singular:", isSingular(m_max), "\n")

m <- m_max
chosen_re <- maximal_re
if (isSingular(m)) {
  # Step 1: remove the random-effect correlations.
  keep <- list(participant = c("(Intercept)", "prime_c"),
               item        = c("(Intercept)", "prime_c"))
  chosen_re <- zero_corr_terms(keep)
  m <- fit(chosen_re)

  # Step 2: drop variance components estimated at zero (relative standard
  # deviation below lme4's default singularity tolerance), refitting until
  # the fit is no longer singular.
  while (isSingular(m)) {
    vc <- as.data.frame(VarCorr(m))
    vc <- vc[vc$grp != "Residual", ]
    vc$grp <- sub("\\.[0-9]+$", "", vc$grp)
    zero <- vc$sdcor / sigma(m) < 1e-4
    if (!any(zero)) {
      # Singular for another reason: drop the smallest component.
      zero <- vc$sdcor == min(vc$sdcor)
    }
    for (i in which(zero)) {
      keep[[vc$grp[i]]] <- setdiff(keep[[vc$grp[i]]], vc$var1[i])
    }
    cat(sprintf("Dropping zero-variance component(s): %s\n",
                paste(vc$grp[zero], vc$var1[zero], sep = ":",
                      collapse = ", ")))
    chosen_re <- zero_corr_terms(keep)
    m <- fit(chosen_re)
  }
}
stopifnot(converged(m), !isSingular(m))

# ---------------------------------------------------------------------------
# Confirmatory model
# ---------------------------------------------------------------------------

cat("\nSelected random-effects structure:", chosen_re, "\n")
cat("\nConfirmatory mixed-effects model:\n")
print(summary(m, ddf = "Satterthwaite"))

prime_ci <- function(model, ddf = "Satterthwaite") {
  cf <- summary(model, ddf = ddf)$coefficients["prime_c", ]
  crit <- qt(0.975, cf[["df"]])
  c(estimate = cf[["Estimate"]],
    lower    = cf[["Estimate"]] - crit * cf[["Std. Error"]],
    upper    = cf[["Estimate"]] + crit * cf[["Std. Error"]],
    se       = cf[["Std. Error"]],
    df       = cf[["df"]])
}

res <- prime_ci(m)
cat(sprintf(paste0("\nPriming effect (unrelated - related): %.2f ms, ",
                   "95%% CI [%.2f, %.2f], SE = %.2f, ",
                   "Satterthwaite df = %.1f\n"),
            res[["estimate"]], res[["lower"]], res[["upper"]],
            res[["se"]], res[["df"]]))

# ---------------------------------------------------------------------------
# Sensitivity checks (reported, not used for the result)
# ---------------------------------------------------------------------------

cat("\nSensitivity checks:\n")

# 1. The maximal model, despite its singular fit.
mx <- prime_ci(m_max)
cat(sprintf("  Maximal (singular) model:      %.2f ms [%.2f, %.2f]\n",
            mx[["estimate"]], mx[["lower"]], mx[["upper"]]))

# 2. Kenward-Roger degrees of freedom instead of Satterthwaite, if available.
if (requireNamespace("pbkrtest", quietly = TRUE)) {
  kr <- prime_ci(m, ddf = "Kenward-Roger")
  cat(sprintf("  Kenward-Roger df (%.1f):       %.2f ms [%.2f, %.2f]\n",
              kr[["df"]], kr[["estimate"]], kr[["lower"]], kr[["upper"]]))
}

# 3. Does word frequency moderate priming? If it did, the average effect
#    would depend on the frequency mix of the items.
m_int <- update(m, . ~ . + prime_c:frequency_c)
ci_int <- summary(m_int, ddf = "Satterthwaite")$coefficients
cat(sprintf("  Prime x frequency interaction: %.2f ms per Zipf unit, p = %.3f\n",
            ci_int["prime_c:frequency_c", "Estimate"],
            ci_int["prime_c:frequency_c", "Pr(>|t|)"]))

# 4. Log RT, to check that skew in raw RTs is not driving the conclusion.
#    The log-scale effect is expressed in ms at the geometric mean RT.
m_log <- suppressMessages(update(m, log(rt) ~ .))
lg <- prime_ci(m_log)
gm <- exp(fixef(m_log)[["(Intercept)"]])
to_ms <- function(b) gm * (exp(b / 2) - exp(-b / 2))
cat(sprintf("  Log-RT model, in ms at %.0f ms: %.2f ms [%.2f, %.2f]\n",
            gm, to_ms(lg[["estimate"]]), to_ms(lg[["lower"]]),
            to_ms(lg[["upper"]])))

# 5. Separate by-participant (F1) and by-item (F2) paired analyses. Each
#    treats only one random factor as random, so neither alone carries the
#    full uncertainty that the crossed model accounts for.
paired <- function(unit) {
  a <- aggregate(as.formula(paste("rt ~", unit, "+ prime")), d, mean)
  a <- a[order(a[[unit]]), ]
  t.test(a$rt[a$prime == "unrelated"], a$rt[a$prime == "related"],
         paired = TRUE)
}
by_subj <- paired("participant")
by_item <- paired("item")
cat(sprintf("  By-participant paired t-test:  %.2f ms [%.2f, %.2f]\n",
            by_subj$estimate, by_subj$conf.int[1], by_subj$conf.int[2]))
cat(sprintf("  By-item paired t-test:         %.2f ms [%.2f, %.2f]\n",
            by_item$estimate, by_item$conf.int[1], by_item$conf.int[2]))

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

cat(sprintf("RESULT estimate=%.2f lower=%.2f upper=%.2f\n",
            res[["estimate"]], res[["lower"]], res[["upper"]]))
