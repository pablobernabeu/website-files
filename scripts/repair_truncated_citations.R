#!/usr/bin/env Rscript
#
# repair_truncated_citations.R
#
# Restore references whose citation was cut off before it was written.
#
# CrossRef's APA formatter returns multi-line output whenever a title carries
# inline markup, putting the tag on a line of its own:
#
#   Chen, Y. (2025). The Effects of Gloss Language on
#                       <scp>L2</scp>
#                       Vocabulary Learning from Reading. TESOL Quarterly, ...
#
# writeLines() then wrote that as three lines, so the file held a <p> with no
# </p> followed by two unattached fragments, and lint rule 7 deleted the
# fragments. What remained was the first line alone: an authors-and-part-title
# stub with no journal and, because the DOI link sits at the end, no DOI.
#
# Losing the DOI is what made this compound. extract_existing_dois() reads DOIs
# to decide what the collector already has, so a truncated reference was
# invisible to it and got re-added on every run, truncated again each time. One
# reference had accumulated 88 copies. Lint rule 5 now falls back to the
# citation text, which removes the copies, and fold_citation_lines() in the
# collector stops new citations arriving split. This script repairs what those
# two fixes cannot: the text already destroyed.
#
# A truncated citation has no DOI, so it is matched back to its source through
# CrossRef's bibliographic search on the authors, year and surviving title
# prefix. The accept test is deliberately strict, because a wrong match would
# publish a fabricated citation, which is worse than leaving a stub in place:
#
#   - the surviving title prefix must be a prefix of the candidate's title
#   - the year must agree within one (online-first and issue years differ)
#   - the candidate's FIRST author must be the stub's first author
#
# The author test compares whole names, not substrings: "Ma, D. S. (2025).
# Introduction to" otherwise matched a paper by "Xu, H., Ma, J., &
# Mangelsdorf, K.", because "ma" occurs inside the joined author list.
#
# Anything that fails is reported, not guessed at. Whatever is accepted is run
# back through the collector's own format_citation_for_hugo() and
# citation_md_to_html(), so a repaired reference is indistinguishable from a
# freshly collected one.
#
# Usage:
#   Rscript scripts/repair_truncated_citations.R           # report only
#   Rscript scripts/repair_truncated_citations.R --apply   # rewrite the files
#
#   --drop-unrepairable  also delete the stubs that could not be matched. A
#                        stub carries no DOI, no journal and half a title, so
#                        the reader can do nothing with it; dropping it lets
#                        the collector re-add the reference in full if it
#                        still appears in a search.

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
})

args <- commandArgs(trailingOnly = TRUE)
apply_changes <- "--apply" %in% args
drop_unrepairable <- "--drop-unrepairable" %in% args

# Reuse the collector's formatting rather than restating it here, so a repaired
# citation goes through the same pipeline as a freshly collected one. Only
# top-level function definitions are evaluated; the collector's body would
# otherwise run a full collection.
collector <- "scripts/collect_related_references.R"
if (!file.exists(collector)) {
  stop("Run this from the repository root: ", collector, " not found")
}
for (expr in parse(text = paste(
  readLines(collector, encoding = "UTF-8", warn = FALSE), collapse = "\n"))) {
  if (is.call(expr) && as.character(expr[[1]])[1] %in% c("<-", "=") &&
      length(expr) == 3L && is.call(expr[[3]]) &&
      as.character(expr[[3]][[1]])[1] == "function") {
    eval(expr, envir = globalenv())
  }
}

UA <- "RelatedRefs/1.0 (+https://pablobernabeu.github.io)"

#' Lowercase, drop markup and punctuation. For comparison only.
norm_txt <- function(x) {
  x <- gsub("<[^>]*>", " ", x)
  x <- gsub("&[A-Za-z]+;|&#[0-9]+;", " ", x)
  x <- tolower(x)
  x <- gsub("[^[:alnum:]]+", " ", x, perl = TRUE)
  trimws(gsub("[[:space:]]+", " ", x))
}

#' Plain text of a citation paragraph, entities resolved.
para_text <- function(p) {
  t <- sub("^\\s*<p[^>]*>", "", p)
  t <- sub("</p>\\s*$", "", t)
  t <- gsub("<[^>]*>", " ", t)
  t <- decode_html_entities(t)
  trimws(gsub("[[:space:]]+", " ", t))
}

#' Split a stub into first-author surname, year and the surviving title prefix.
split_stub <- function(p) {
  txt <- para_text(p)
  m <- regexpr("\\((\\d{4})[a-z]?\\)\\.?\\s*", txt, perl = TRUE)
  if (m < 0) return(NULL)
  year_txt <- regmatches(txt, m)
  authors <- trimws(substr(txt, 1L, m - 1L))
  title <- trimws(substr(txt, m + attr(m, "match.length"), nchar(txt)))
  list(
    authors = authors,
    surname = trimws(strsplit(authors, ",")[[1]][1]),
    year = as.integer(gsub("\\D", "", year_txt)),
    title = title,
    query = txt
  )
}

crossref_search <- function(query, rows = 20L) {
  url <- paste0(
    "https://api.crossref.org/works?rows=", rows,
    "&select=DOI,title,author,issued&query.bibliographic=",
    URLencode(substr(query, 1L, 400L), reserved = TRUE)
  )
  res <- tryCatch(
    httr::GET(url, httr::add_headers(`User-Agent` = UA), httr::timeout(45)),
    error = function(e) NULL
  )
  if (is.null(res) || httr::status_code(res) != 200) return(list())
  parsed <- tryCatch(
    jsonlite::fromJSON(httr::content(res, as = "text", encoding = "UTF-8"),
                       simplifyDataFrame = FALSE),
    error = function(e) NULL
  )
  if (is.null(parsed)) return(list())
  parsed$message$items %||% list()
}

#' The strict accept test described in the header.
pick_match <- function(stub, items) {
  want_title <- norm_txt(stub$title)
  want_surname <- norm_txt(stub$surname)
  for (it in items) {
    cand_title <- norm_txt(paste(unlist(it$title %||% ""), collapse = " "))
    if (nchar(cand_title) == 0L) next
    if (nchar(want_title) > 0L &&
        substr(cand_title, 1L, nchar(want_title)) != want_title) next
    parts <- it$issued$`date-parts`
    cand_year <- suppressWarnings(as.integer(parts[[1]][[1]]))
    if (is.na(cand_year) || abs(cand_year - stub$year) > 1L) next
    fams <- vapply(it$author %||% list(),
                   function(a) norm_txt(a$family %||% ""), character(1L))
    if (length(fams) == 0L) next
    # The stub is APA, so its leading name is the paper's first author. Compare
    # whole names: CrossRef and the APA formatter disagree about how much of a
    # compound surname belongs to the family field ("Pereira da Silva" against
    # "da Silva"), so accept either one containing the other as whole words.
    if (nchar(want_surname) > 0L) {
      whole <- function(needle, hay) {
        grepl(paste0("(^| )", needle, "( |$)"), hay, perl = TRUE)
      }
      if (!(identical(fams[1], want_surname) ||
            whole(want_surname, fams[1]) ||
            whole(fams[1], want_surname))) next
    }
    return(it$DOI)
  }
  NULL
}

repair_one <- function(p) {
  stub <- split_stub(p)
  if (is.null(stub)) return(list(status = "unparseable"))
  doi <- pick_match(stub, crossref_search(stub$query))
  Sys.sleep(0.4)
  if (is.null(doi)) return(list(status = "no-match", stub = stub))
  citation <- get_apa7_citation(doi)
  Sys.sleep(0.4)
  if (is.null(citation)) return(list(status = "no-citation", stub = stub, doi = doi))
  formatted <- format_citation_for_hugo(citation, doi)
  if (is.null(formatted)) return(list(status = "rejected", stub = stub, doi = doi))
  list(status = "repaired", stub = stub, doi = doi,
       line = paste0("<p>", citation_md_to_html(formatted), "</p>"))
}

# ---------------------------------------------------------------------------

files <- list.files("content/publication", pattern = "related-references\\.html$",
                    recursive = TRUE, full.names = TRUE)
cache <- new.env(parent = emptyenv())
n_repaired <- n_failed <- n_dropped <- 0L
failures <- character(0)

for (path in files) {
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  in_script <- FALSE
  out <- character(0)
  changed <- FALSE
  pub <- basename(dirname(path))

  for (ln in lines) {
    stripped <- trimws(ln)
    if (grepl("^<script", stripped)) in_script <- TRUE
    if (grepl("^</script", stripped)) in_script <- FALSE
    # A citation with no DOI link is the signature of truncation: the DOI sits
    # at the end of the line, so it is the first thing a cut removes.
    is_stub <- !in_script &&
      grepl("^\\s*<p[^>]*>", ln, perl = TRUE) &&
      !grepl("doi\\.org/", ln)
    if (!is_stub) {
      out <- c(out, ln)
      next
    }
    key <- paste0("k", trimws(ln))
    if (!exists(key, envir = cache)) {
      assign(key, repair_one(ln), envir = cache)
    }
    res <- get(key, envir = cache)
    if (identical(res$status, "repaired")) {
      out <- c(out, res$line)
      changed <- TRUE
      n_repaired <- n_repaired + 1L
    } else if (drop_unrepairable) {
      changed <- TRUE
      n_dropped <- n_dropped + 1L
    } else {
      out <- c(out, ln)
      n_failed <- n_failed + 1L
      failures <- c(failures, paste0("  [", res$status, "] ", pub, ": ",
                                     substr(trimws(ln), 1L, 100L)))
    }
  }

  if (changed) {
    if (apply_changes) {
      writeLines(out, path, useBytes = TRUE)
      cat("Repaired:", pub, "\n")
    } else {
      cat("Would repair:", pub, "\n")
    }
  }
}

cat("\n=== Summary ===\n")
cat("Citations repaired :", n_repaired, "\n")
if (drop_unrepairable) cat("Stubs dropped      :", n_dropped, "\n")
cat("Left in place      :", n_failed, "\n")
if (length(failures) > 0) {
  cat("\nCould not be matched:\n")
  cat(paste(unique(failures), collapse = "\n"), "\n")
}
if (!apply_changes) cat("\nReport only. Re-run with --apply to write.\n")
