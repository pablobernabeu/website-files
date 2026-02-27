pkgs <- c("corpus","sentimentr","sotu","text2vec","janeaustenr","quanteda")
for (p in pkgs) {
  avail <- requireNamespace(p, quietly = TRUE)
  if (avail) {
    ds <- data(package = p)
    cat(p, ":", paste(ds[["results"]][, "Item"], collapse = ", "), "\n")
  } else {
    cat(p, ": NOT INSTALLED\n")
  }
}
