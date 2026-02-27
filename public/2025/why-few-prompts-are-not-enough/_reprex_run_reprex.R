#' ---
#' output:
#'   reprex::reprex_document:
#'     advertise: FALSE
#'     std_out_err: TRUE
#' ---

library(LSAfun)
library(ggplot2)
library(ggrepel)

# ---- 1. Toy corpus: two semantic domains, 'bank' deliberately spans both ----

docs <- c(
  "the river flows past the bank into the lake",
  "fish swim in the river near the reeds",
  "flooding raised the river level above the bank",
  "birds nest along the river and beside the lake",
  "water tumbles over rocks in the mountain stream",
  "the bank approved the mortgage and the loan",
  "interest rates affect every bank and every credit card",
  "the bank charges fees on overdraft and savings accounts",
  "investors deposit money at the bank to earn interest",
  "the loan from the bank helped finance the house"
)

# ---- 2. Term-document matrix (simple counts, stop-words removed) ------------

stop_words <- c(
  "the", "a", "an", "and", "in", "on", "at", "to", "of",
  "into", "over", "near", "past", "every", "from", "helped",
  "along", "above", "beside"
)

clean <- lapply(docs, function(d) {
  toks <- unlist(strsplit(tolower(d), "\\W+"))
  toks[nchar(toks) > 0 & !toks %in% stop_words]
})

vocab <- sort(unique(unlist(clean)))
tdm <- sapply(clean, function(toks) {
  tabulate(match(toks, vocab), nbins = length(vocab))
})
rownames(tdm) <- vocab

# ---- 3. LSA: log-entropy weighting then SVD, keeping 2 dimensions ----------

tf       <- tdm / (colSums(tdm) + 1e-9)[col(tdm)]
idf      <- log2((ncol(tdm) + 1) / (rowSums(tdm > 0) + 1))
weighted <- tf * idf

sv       <- svd(weighted, nu = 2, nv = 2)
words_2d <- sv$u %*% diag(sv$d[1:2])
rownames(words_2d) <- vocab

# ---- 4. Cosine similarity via LSAfun::Cos() ---------------------------------

pairs <- list(
  c("river",  "fish"),
  c("river",  "bank"),
  c("bank",   "loan"),
  c("bank",   "interest"),
  c("river",  "loan"),
  c("fish",   "mortgage")
)

sims <- sapply(pairs, function(p) round(Cos(p[1], p[2], tvectors = words_2d), 3))
names(sims) <- sapply(pairs, paste, collapse = " ~ ")
print(sims)
