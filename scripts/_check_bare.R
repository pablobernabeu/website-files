files <- list.files("content/publication", pattern = "related-references\\.html",
                    recursive = TRUE, full.names = TRUE)

for (f in files) {
  lines <- readLines(f, warn = FALSE, encoding = "UTF-8")

  hang_s <- grep("hanging-indent", lines)
  hang_s <- hang_s[grepl("<div", lines[hang_s])][1]
  close_d <- grep("^</div>", lines)
  hang_e <- close_d[close_d > hang_s][1]

  if (is.na(hang_s) || is.na(hang_e)) next

  inner <- lines[(hang_s + 1L):(hang_e - 1L)]
  stripped <- trimws(inner)
  bare <- inner[nchar(stripped) > 0 & !grepl("^<", stripped)]

  if (length(bare) > 0) {
    cat("BARE TEXT in", basename(dirname(f)), ":\n")
    cat(head(bare, 5), sep = "\n")
    cat("\n")
  }
}
cat("Check done.\n")
