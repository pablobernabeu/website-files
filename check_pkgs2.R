pkgs <- c("topicmodels", "gutenbergr", "modeldata", "textdata", "stm")
for (p in pkgs) {
  avail <- requireNamespace(p, quietly = TRUE)
  if (avail) {
    ds <- data(package = p)
    cat(p, ":", paste(ds[["results"]][, "Item"], collapse = ", "), "\n")
  } else {
    cat(p, ": NOT INSTALLED\n")
  }
}
# Also check what quanteda has more precisely
cat("\nquanteda datasets:\n")
ds <- data(package = "quanteda")
for (i in seq_len(nrow(ds[["results"]]))) {
  cat("  ", ds[["results"]][i, "Item"], "-", ds[["results"]][i, "Title"], "\n")
}
