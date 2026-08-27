# collect_related_references.R
#
# Fully automated weekly collection of related references for publications.
# - Auto-discovers every publication under content/publication/
# - For publications with an existing related references R script, extracts
#   the query from that script
# - For publications without one, auto-generates a Scopus query from the
#   publication title and DOI
# - Searches Scopus via a commit-pinned scopus_search_plus helper
# - Retrieves APA 7 formatted citations via CrossRef content negotiation
# - Inserts new citations into each publication's index file, sorted
#   alphabetically and deduplicated
# - Persists unfetched DOI candidates so time-limited runs resume collection
#   before moving on to newly discovered results
#
# Usage:
#   Rscript scripts/collect_related_references.R              # all publications
#   Rscript scripts/collect_related_references.R --pub NAME   # single publication
#   Rscript scripts/collect_related_references.R --lint-only  # repair files only
#
# Environment variables:
#   SCOPUS_API_KEY  — Elsevier Scopus API key (required)

library(rscopus)
library(dplyr)
library(jsonlite)

# Null-coalescing operator
`%||%` <- function(a, b) if (!is.null(a)) a else b

# Re-run the lint rules over the existing files without contacting Scopus or
# CrossRef, so a repair can be reproduced offline and after a rebase.
lint_only <- "--lint-only" %in% commandArgs(trailingOnly = TRUE)

# ---- Scopus API key ----

if (!lint_only) {
  api_key <- Sys.getenv("SCOPUS_API_KEY", unset = "")
  if (nchar(api_key) == 0) {
    api_key <- Sys.getenv("RSCOPUS_KEY", unset = "")
  }
  if (nchar(api_key) == 0) {
    stop("No Scopus API key found. Set the SCOPUS_API_KEY environment variable.")
  }
  rscopus::set_api_key(api_key)
}

# ---- Source the custom Scopus search helper ----

rscopus_plus_commit <- "b81c4b576dfba942c820766ea30229f8db2b77e5"
rscopus_plus_base <- paste0(
  "https://raw.githubusercontent.com/pablobernabeu/rscopus_plus/",
  rscopus_plus_commit,
  "/"
)
if (!lint_only) source(paste0(rscopus_plus_base, "scopus_search_plus.R"))

#' Query Scopus and return the unique, non-missing DOI values in memory.
#' Keeping this adapter free of file I/O prevents timestamped search snapshots
#' from accumulating in publication bundles.
search_scopus_dois <- function(query, run_period,
                               search = scopus_search_plus) {
  results <- search(
    query,
    paste0(min(run_period), "-", max(run_period)),
    quota = 20,
    verbose = TRUE
  )
  if (!is.data.frame(results) || !"doi" %in% names(results)) {
    stop("Scopus search returned no DOI column")
  }
  dois <- results$doi
  unique(dois[!is.na(dois) & nzchar(trimws(dois))])
}

# ===========================================================================
#  DISCOVERY
# ===========================================================================

#' Find the index file for a publication folder.
#' Returns the path to the first existing file among index.md, index.en.Rmd.
find_index_file <- function(pub_dir) {
  candidates <- c(
    file.path(pub_dir, "index.md"),
    file.path(pub_dir, "index.en.Rmd")
  )
  found <- candidates[file.exists(candidates)]
  if (length(found) == 0) return(NULL)
  found[1]
}

#' Find the pre-rendered HTML counterpart for an Rmd index file.
#' Returns NULL for non-Rmd files or if no HTML exists.
find_html_counterpart <- function(index_path) {
  if (!grepl("\\.Rmd$", index_path, ignore.case = TRUE)) return(NULL)
  html_path <- sub("\\.Rmd$", ".html", index_path, ignore.case = TRUE)
  if (file.exists(html_path)) html_path else NULL
}

#' Return the path to the standalone related-references.html for a publication.
#' This file is the single source of truth for all reference content and is
#' injected into the page by the Hugo layout via .Resources.GetMatch.
find_refs_html_file <- function(pub_dir) {
  file.path(pub_dir, "related-references.html")
}

#' Read YAML frontmatter from a markdown / Rmd file.
#' Returns a named list.
read_frontmatter <- function(path) {
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  delims <- which(trimws(lines) == "---")
  if (length(delims) < 2) return(list())
  yaml_text <- lines[(delims[1] + 1):(delims[2] - 1)]
  tryCatch(yaml::yaml.load(paste(yaml_text, collapse = "\n")),
           error = function(e) list())
}

#' Find the related-references directory for a publication.
#' Checks both "related references" (space) and "related-references" (hyphen).
find_refs_dir <- function(pub_dir) {
  candidates <- c(
    file.path(pub_dir, "related references"),
    file.path(pub_dir, "related-references")
  )
  found <- candidates[dir.exists(candidates)]
  if (length(found) > 0) return(found[1])
  # Default: create with space (consistent with majority)
  file.path(pub_dir, "related references")
}

#' Try to extract the Scopus query string from an existing related references
#' R script.  Returns NULL if no script or no query found.
extract_query_from_script <- function(refs_dir) {
  script <- file.path(refs_dir, "related references.R")
  if (!file.exists(script)) return(NULL)

  code <- paste(readLines(script, encoding = "UTF-8", warn = FALSE), collapse = "\n")

  # The query is always assigned as  query = paste( ... )
  # We evaluate the paste() call in a sandboxed environment.
  env <- new.env(parent = baseenv())
  tryCatch({
    m <- regmatches(code, regexpr("query\\s*=\\s*paste\\((.|\n)*?\\)\n", code, perl = TRUE))
    if (length(m) == 0) return(NULL)
    eval(parse(text = m), envir = env)
    return(env$query)
  }, error = function(e) NULL)
}

#' Extract the search_period value from an existing related references R script.
extract_period_from_script <- function(refs_dir) {
  script <- file.path(refs_dir, "related references.R")
  if (!file.exists(script)) return(NULL)
  lines <- readLines(script, encoding = "UTF-8", warn = FALSE)
  m <- grep("^\\s*search_period\\s*=", lines, value = TRUE)
  if (length(m) == 0) return(NULL)
  env <- new.env(parent = baseenv())
  tryCatch({
    eval(parse(text = m[1]), envir = env)
    return(env$search_period)
  }, error = function(e) NULL)
}

# ===========================================================================
#  AUTO-QUERY GENERATION
# ===========================================================================

#' Build an automatic Scopus query from publication metadata.
#' Uses the REF() field operator to find papers that cite this publication
#' by its title or DOI.
build_auto_query <- function(fm) {
  parts <- character(0)

  # 1. Search for papers that reference this publication by title
  title <- fm$title
  if (!is.null(title) && nchar(title) > 0) {
    title <- gsub("[*_`]", "", title)
    if (nchar(title) > 300) title <- substr(title, 1, 300)
    parts <- c(parts, paste0('REF("', title, '")'))
  }

  # 2. Search for papers that reference this publication by DOI
  doi <- fm$doi
  if (!is.null(doi) && nchar(doi) > 0) {
    parts <- c(parts, paste0('REF("', doi, '")'))
  }

  if (length(parts) == 0) return(NULL)
  paste(parts, collapse = " OR ")
}

# ===========================================================================
#  CROSSREF / APA 7
# ===========================================================================

#' Fetch an APA 7 citation string from CrossRef via DOI content negotiation.
get_apa7_citation <- function(doi, max_retries = 3) {
  for (attempt in seq_len(max_retries)) {
    citation <- tryCatch({
      url <- paste0("https://doi.org/", doi)
      response <- httr::GET(
        url,
        httr::add_headers(Accept = "text/x-bibliography; style=apa"),
        httr::timeout(30)
      )
      if (httr::status_code(response) == 200) {
        trimws(httr::content(response, as = "text", encoding = "UTF-8"))
      } else {
        NULL
      }
    }, error = function(e) NULL)

    if (!is.null(citation) && nchar(citation) > 0) {
      # Reject HTML responses (e.g. Chinese journals returning a full page instead of a citation)
      if (grepl('<[!?]|<html|<head|<meta|<body|<script', citation, perl = TRUE, ignore.case = TRUE)) {
        cat("    Warning: DOI server returned HTML instead of a citation for", doi, "\n")
        return(NULL)
      }
      # Reject raw JSON responses (API returning metadata instead of formatted citation)
      if (grepl('^\\s*\\{\\s*"', citation, perl = TRUE)) {
        cat("    Warning: DOI server returned JSON instead of a citation for", doi, "\n")
        return(NULL)
      }
      # Reject suspiciously long responses (a valid APA citation is rarely > 2000 chars)
      if (nchar(citation) > 2000) {
        cat("    Warning: citation too long (", nchar(citation), "chars) for", doi, "- likely malformed\n")
        return(NULL)
      }
      return(citation)
    }
    if (attempt < max_retries) Sys.sleep(2)
  }
  NULL
}

#' Fetch an abstract from Scopus via the Abstract Retrieval API.
#' Returns NULL if no abstract is available.
get_scopus_abstract <- function(doi, max_retries = 2) {
  for (attempt in seq_len(max_retries)) {
    abstract <- tryCatch({
      res <- rscopus::abstract_retrieval(doi, identifier = "doi", verbose = FALSE)
      abs_text <- res$content$`coredata`$`dc:description` %||% ""
      abs_text <- trimws(abs_text)
      if (nchar(abs_text) > 0) abs_text else NULL
    }, error = function(e) NULL)

    if (!is.null(abstract)) return(abstract)
    if (attempt < max_retries) Sys.sleep(1)
  }
  NULL
}

#' Fetch metadata (abstract, type, language) from CrossRef API for a single DOI.
#' Falls back to the Scopus Abstract Retrieval API when CrossRef lacks an
#' abstract (many publishers deposit abstracts only in Scopus).
get_crossref_metadata <- function(doi, max_retries = 2) {
  result <- list(abstract = NULL, type = NULL, language = NULL,
                 retracted = FALSE, pub_year = NA_integer_)

  # --- Try CrossRef first ---
  for (attempt in seq_len(max_retries)) {
    result <- tryCatch({
      url <- paste0("https://api.crossref.org/works/", URLencode(doi, reserved = TRUE))
      response <- httr::GET(
        url,
        httr::add_headers(Accept = "application/json"),
        httr::timeout(15)
      )
      if (httr::status_code(response) == 200) {
        data <- jsonlite::fromJSON(httr::content(response, as = "text", encoding = "UTF-8"),
                                   simplifyVector = FALSE)
        msg <- data$message
        abstract_raw <- msg$`abstract` %||% ""
        # Strip JATS/HTML tags from abstract
        abstract_clean <- gsub("<[^>]+>", "", abstract_raw)
        abstract_clean <- trimws(abstract_clean)
        # Check for retraction: CrossRef marks retractions via update-to relation
        updates <- msg$`update-to` %||% list()
        is_retracted <- any(sapply(updates, function(u) {
          identical(tolower(u$type %||% ""), "retraction")
        }))
        # Extract earliest publication year for future-year detection
        pub_year <- tryCatch({
          dates <- msg$`published`$`date-parts`[[1]] %||%
                   msg$`published-print`$`date-parts`[[1]] %||%
                   msg$`published-online`$`date-parts`[[1]]
          as.integer(dates[[1]])
        }, error = function(e) NA_integer_)
        list(
          abstract    = if (nchar(abstract_clean) > 0) abstract_clean else NULL,
          type        = msg$type,
          language    = msg$language,
          retracted   = is_retracted,
          pub_year    = pub_year
        )
      } else {
        list(abstract = NULL, type = NULL, language = NULL)
      }
    }, error = function(e) list(abstract = NULL, type = NULL, language = NULL,
                                retracted = FALSE, pub_year = NA_integer_))

    if (!is.null(result$abstract) || !is.null(result$type)) break
    if (attempt < max_retries) Sys.sleep(1)
  }

  # --- Scopus fallback when CrossRef has no abstract ---
  if (is.null(result$abstract)) {
    scopus_abs <- get_scopus_abstract(doi)
    if (!is.null(scopus_abs)) {
      result$abstract <- scopus_abs
    }
  }

  # --- OpenAlex fallback when CrossRef + Scopus have no abstract ---
  if (is.null(result$abstract)) {
    oa_abs <- tryCatch({
      url <- paste0("https://api.openalex.org/works/doi:", URLencode(doi, reserved = TRUE),
                    "?select=abstract_inverted_index")
      res <- httr::GET(url, httr::add_headers(Accept = "application/json"), httr::timeout(15))
      if (httr::status_code(res) == 200) {
        data <- jsonlite::fromJSON(httr::content(res, as = "text", encoding = "UTF-8"),
                                   simplifyVector = FALSE)
        aii <- data$abstract_inverted_index
        if (!is.null(aii) && length(aii) > 0) {
          # Reconstruct plain text from inverted index (word -> positions)
          positions <- unlist(lapply(names(aii), function(w) {
            setNames(rep(w, length(aii[[w]])), as.character(unlist(aii[[w]])))
          }))
          idx <- as.integer(names(positions))
          paste(positions[order(idx)], collapse = " ")
        } else NULL
      } else NULL
    }, error = function(e) NULL)
    if (!is.null(oa_abs) && nchar(trimws(oa_abs)) > 0) result$abstract <- trimws(oa_abs)
  }

  result
}

#' Return TRUE if the string contains CJK, Arabic, or other non-Latin scripts.
#' Used to detect non-English papers when no language tag is available.
contains_non_latin_script <- function(text) {
  if (is.null(text) || nchar(text) == 0) return(FALSE)
  # CJK Unified Ideographs, Hiragana, Katakana, Arabic, Cyrillic, Korean Hangul
  grepl("[\u3000-\u9FFF\uAC00-\uD7AF\u0600-\u06FF\u0400-\u04FF]",
        text, perl = TRUE)
}

#' Decode the HTML entities that CrossRef leaves in citation text.
#' Container titles are deposited pre-escaped ("Neuroscience &amp; Biobehavioral
#' Reviews") and the APA formatter title-cases the entity name, so the citation
#' arrives holding "&Amp;". Decoding here lets citation_md_to_html() escape the
#' text exactly once, which is what makes the browser show a plain "&".
#' Escaping is occasionally layered more than once ("&amp;amp;"), hence the
#' repeated passes. "&lt;" and "&gt;" are deliberately left encoded: the HTML
#' writer does not escape angle brackets, so decoding them would inject markup.
decode_html_entities <- function(text, max_passes = 5L) {
  if (is.null(text) || length(text) == 0) return(text)

  named <- c(apos = "'", quot = "\"", nbsp = "\u00A0", ndash = "\u2013",
             mdash = "\u2014", lsquo = "\u2018", rsquo = "\u2019",
             ldquo = "\u201C", rdquo = "\u201D", hellip = "\u2026", amp = "&")

  decode_once <- function(x) {
    # Numeric character references, decimal (&#8217;) and hexadecimal (&#x2019;)
    refs <- gregexpr("&#[xX]?[0-9A-Fa-f]+;", x, perl = TRUE)
    regmatches(x, refs) <- lapply(regmatches(x, refs), function(hits) {
      vapply(hits, function(hit) {
        digits <- gsub("^&#|;$", "", hit)
        code <- if (grepl("^[xX]", digits)) {
          strtoi(sub("^[xX]", "", digits), base = 16L)
        } else {
          suppressWarnings(as.integer(digits))
        }
        if (is.na(code) || code <= 0) hit else intToUtf8(code)
      }, character(1), USE.NAMES = FALSE)
    })
    # "&amp;" is decoded last so that "&amp;lt;" yields the literal text "&lt;"
    # rather than "<".
    for (nm in names(named)) {
      x <- gsub(paste0("&", nm, ";"), named[[nm]], x, ignore.case = TRUE)
    }
    x
  }

  for (pass in seq_len(max_passes)) {
    decoded <- decode_once(text)
    if (identical(decoded, text)) break
    text <- decoded
  }
  text
}

#' Format a citation for embedding in Hugo markdown with DOI angle-bracket link.
format_citation_for_hugo <- function(citation, doi) {
  if (is.null(citation)) return(NULL)

  citation <- decode_html_entities(citation)

  doi_url <- paste0("https://doi.org/", doi)

  # Remove trailing DOI URL already appended by CrossRef (various formats, case-insensitive)
  doi_pattern <- paste0("\\s*https?://doi\\.org/", doi, "\\s*$")
  citation <- gsub(doi_pattern, "", citation, ignore.case = TRUE)

  citation <- trimws(citation)

  # Remove Portico preservation-service label inserted by CrossRef's APA formatter
  citation <- gsub("\\.?\\s*Portico\\.?", "", citation, ignore.case = FALSE, perl = FALSE)
  citation <- trimws(citation)

  # Strip <scp>...</scp> small-caps tags inserted by CrossRef (keep inner text)
  citation <- gsub("</?scp>", "", citation, ignore.case = TRUE)

  # Strip month/day from parenthetical dates, keeping year only: (2023, March 15) -> (2023)
  citation <- gsub("\\((\\d{4})[a-z]?),\\s*[A-Za-z]+\\.?\\s*\\d{0,2}\\)", "(\\1)", citation)

  citation <- sub("\\.$", "", citation)

  # Add APA 7 italics: wrap journal name and volume in *...* so that
  # citation_md_to_html() converts them to <em> tags.
  # Pattern: ". Journal Name, Volume[(Issue)][, Pages]" at the end of the body.
  # Volume must NOT be immediately followed by an en/em-dash, which would
  # indicate a page range (e.g. "89\u201390") rather than a volume number.
  citation <- sub(
    "(\\.\\s+)([^.]+?),\\s*(\\d{1,4})(?![\u2013\u2014-])(\\([^)]+\\))?((?:,\\s*[\\w\\d\u2013-]+(?:[\u2013-]\\d+)?)*)$",
    "\\1*\\2*, *\\3*\\4\\5",
    citation,
    perl = TRUE
  )
  # Fallback for conference proceedings and book chapters:
  # ". Container Title, N\u2013M" -- no separate volume/issue number.
  # Only apply when the journal pattern above left no italics (no "*" added).
  if (!grepl("\\*", citation, perl = TRUE)) {
    citation <- sub(
      "(\\.\\s+)([^.]+?),\\s*(\\d+[\u2013\u2014-]\\d+)\\s*$",
      "\\1*\\2*, \\3",
      citation,
      perl = TRUE
    )
  }
  # Fallback for ahead-of-print / online-first:
  # ". Journal Name" at end of body, no comma/volume/pages.
  # Only apply when neither previous pattern added italics.
  if (!grepl("\\*", citation, perl = TRUE)) {
    citation <- sub(
      "(\\.\\s+)([^.]+?)$",
      "\\1*\\2*",
      citation,
      perl = TRUE
    )
  }
  # Reject ahead-of-print placeholders: volume 0 or page 0 signals no real metadata yet
  if (grepl(",\\s*0\\s*(\\(|,|\\.|$)", citation, perl = TRUE)) {
    return(NULL)
  }
  # Reject citations with no author: APA starts with "(" when author is missing
  if (grepl("^\\s*\\(", citation, perl = TRUE)) {
    return(NULL)
  }
  # Reject citations where the title occupies the author field.
  # Valid APA author fields are either:
  #   - personal:      contain a comma-initial like ", J."
  #   - institutional: end with "." and contain no "?" (e.g. "World Health Organization.")
  # Titles masquerading as authors (CrossRef artefact) typically contain "?" and
  # lack any comma-initial, so they fail both conditions.
  pre_year <- sub("\\(\\d{4}.*", "", citation, perl = TRUE)
  has_personal_author      <- grepl(",\\s*[A-Z]\\.", pre_year, perl = TRUE)
  has_institutional_author <- grepl("\\.\\s*$", pre_year) && !grepl("[?:]", pre_year)
  if (!has_personal_author && !has_institutional_author) {
    return(NULL)
  }
  # Reject suspiciously short citations (valid APA journal articles are rarely < 60 chars)
  if (nchar(citation) < 60) {
    return(NULL)
  }
  paste0(citation, ". <", doi_url, ">")
}

# ===========================================================================
#  INDEX FILE READ / WRITE
# ===========================================================================

#' Convert a markdown-formatted citation to HTML for insertion into .html files.
#' Handles *italic* -> <em>, <URL> -> <a>, and & -> &amp;.
citation_md_to_html <- function(citation) {
  # Escape ampersands. The citation has already been through
  # decode_html_entities(), so every "&" here is a literal ampersand.
  html <- gsub("&", "&amp;", citation, fixed = TRUE)
  # Convert *text* to <em>text</em>
  html <- gsub("\\*([^*]+)\\*", "<em>\\1</em>", html)
  # Convert <URL> to <a href="URL" class="uri">URL</a>
  html <- gsub("<(https?://[^>]+)>", '<a href="\\1" class="uri">\\1</a>', html)
  html
}

#' Extract DOIs already present in a publication's index file.
#' Handles both markdown angle-bracket format and HTML <a> tag format.
extract_existing_dois <- function(index_path) {
  if (!file.exists(index_path)) return(character(0))
  content <- readLines(index_path, encoding = "UTF-8", warn = FALSE)
  # Match markdown: <https://doi.org/...>
  matches1 <- regmatches(content, gregexpr("<https://doi\\.org/([^>]+)>", content))
  # Match HTML: href="https://doi.org/..."
  matches2 <- regmatches(content, gregexpr('href="https?://doi\\.org/([^"]+)"', content))
  dois <- c(unlist(matches1), unlist(matches2))
  dois <- gsub("^<https://doi\\.org/", "", dois)
  dois <- gsub(">$", "", dois)
  dois <- gsub('^href="https?://doi\\.org/', "", dois)
  dois <- gsub('"$', "", dois)

  # Also load any manually skipped DOIs from skip.csv in the same refs dir
  refs_dir <- dirname(index_path)
  refs_dirs <- c(
    file.path(refs_dir, "related references"),
    file.path(refs_dir, "related-references")
  )
  for (rd in refs_dirs) {
    skip_file <- file.path(rd, "skip.csv")
    if (file.exists(skip_file)) {
      skip_dois <- tryCatch({
        d <- read.csv(skip_file, stringsAsFactors = FALSE)
        if ("doi" %in% names(d)) d$doi else d[[1]]
      }, error = function(e) character(0))
      dois <- c(dois, skip_dois)
    }
  }

  unique(tolower(trimws(dois)))
}

#' Normalise a DOI vector while preserving its first-seen order.
normalise_doi_vector <- function(dois) {
  dois <- tolower(trimws(as.character(unlist(dois, use.names = FALSE))))
  unique(dois[!is.na(dois) & nzchar(dois)])
}

#' Read DOI candidates that a previous collection run did not finish fetching.
#' The queue sits next to the per-publication query assets so it is committed
#' with the publication and survives the next scheduled GitHub Actions run.
#' Excluded DOI values are terminal policy rejections and must not be queued or
#' re-fetched when a later Scopus search returns them again.
read_ref_collection_backlog <- function(refs_dir) {
  empty <- list(
    pending = character(0),
    excluded = character(0),
    initial_search_complete = FALSE,
    valid = TRUE
  )
  backlog_path <- file.path(refs_dir, "pending-dois.json")
  if (!file.exists(backlog_path)) return(empty)
  backlog <- tryCatch(
    jsonlite::fromJSON(backlog_path),
    error = function(e) {
      message("  Warning: could not read pending DOI backlog: ", e$message)
      list(valid = FALSE)
    }
  )
  if (is.list(backlog) && isFALSE(backlog$valid)) {
    empty$valid <- FALSE
    return(empty)
  }
  # Accept a legacy top-level DOI array if a manually created file exists.
  if (!is.list(backlog) || is.null(names(backlog))) {
    return(list(
      pending = normalise_doi_vector(backlog),
      excluded = character(0),
      initial_search_complete = length(backlog) > 0,
      valid = TRUE
    ))
  }
  list(
    pending = normalise_doi_vector(backlog$pending),
    excluded = normalise_doi_vector(backlog$excluded),
    initial_search_complete = isTRUE(backlog$initial_search_complete),
    valid = TRUE
  )
}

#' Persist DOI candidates still awaiting a citation fetch.
#' The JSON is deliberately stable (no timestamp), so an
#' unchanged backlog does not create a needless workflow commit.
write_ref_collection_backlog <- function(refs_dir, pending,
                                          excluded = character(0),
                                          initial_search_complete = FALSE) {
  desired <- list(
    pending = normalise_doi_vector(pending),
    excluded = normalise_doi_vector(excluded),
    initial_search_complete = isTRUE(initial_search_complete)
  )
  current <- read_ref_collection_backlog(refs_dir)
  if (!current$valid) {
    stop("Refusing to overwrite unreadable pending DOI backlog")
  }
  current$valid <- NULL
  if (identical(current, desired)) return(FALSE)

  backlog_path <- file.path(refs_dir, "pending-dois.json")
  json_text <- jsonlite::toJSON(desired, auto_unbox = TRUE, pretty = FALSE)
  temp_path <- tempfile(pattern = "pending-dois-", tmpdir = refs_dir,
                        fileext = ".tmp")
  writeLines(as.character(json_text), temp_path, useBytes = TRUE)
  if (!file.rename(temp_path, backlog_path)) {
    # GitHub Actions runs on Linux, where rename replaces atomically. This
    # fallback keeps local Windows runs usable when the destination is open.
    copied <- file.copy(temp_path, backlog_path, overwrite = TRUE)
    unlink(temp_path)
    if (!copied) stop("Could not write pending DOI backlog")
  }
  TRUE
}

#' Insert new citations into the standalone related-references.html file.
#' Creates the file with the full skeleton if it does not yet exist.
#' New citations are converted from markdown to HTML <p> tags.
insert_references_into_refs_html <- function(refs_html_path, new_citations) {
  if (length(new_citations) == 0) return(FALSE)

  if (!file.exists(refs_html_path)) {
    # Create the file from scratch with the standard skeleton
    new_section <- c(
      "<h2 style=\"margin-top:2rem !important;font-size:1.5rem;\">Related references</h2>",
      "",
      "<div class = 'related-references'>",
      "",
      "<div class = 'hanging-indent'>",
      ""
    )
    for (cit in new_citations) {
      new_section <- c(new_section, paste0("<p>", citation_md_to_html(cit), "</p>"), "")
    }
    new_section <- c(new_section, "</div>", "", "</div>")
    writeLines(new_section, refs_html_path, useBytes = TRUE)
    return(TRUE)
  }

  content <- readLines(refs_html_path, encoding = "UTF-8", warn = FALSE)

  # Find the hanging-indent div (handles both quote styles and attribute order)
  hanging_line <- grep("hanging-indent", content)
  hanging_line <- hanging_line[grepl("<div", content[hanging_line])]
  if (length(hanging_line) == 0) {
    message("  Warning: no hanging-indent div found in ", refs_html_path)
    return(FALSE)
  }

  # First </div> after the hanging-indent opening is where new refs go
  closing_divs <- grep("^</div>", content)
  closing_divs_after <- closing_divs[closing_divs > hanging_line[1]]
  if (length(closing_divs_after) == 0) return(FALSE)

  insert_before <- closing_divs_after[1]

  insert_lines <- character(0)
  for (cit in new_citations) {
    insert_lines <- c(insert_lines, paste0("<p>", citation_md_to_html(cit), "</p>"), "")
  }

  content <- c(
    content[1:(insert_before - 1)],
    insert_lines,
    content[insert_before:length(content)]
  )

  writeLines(content, refs_html_path, useBytes = TRUE)
  TRUE
}

# ===========================================================================
#  METADATA JSON BLOCK (embedded in index file for JS to read)
# ===========================================================================

#' Read existing ref-metadata JSON from the index file's <script> block.
#' Returns a named list (DOI -> list(abstract, type)).
read_ref_metadata <- function(index_path) {
  content <- readLines(index_path, encoding = "UTF-8", warn = FALSE)
  start <- grep('<script[^>]*class="ref-metadata"', content)
  if (length(start) == 0) return(list())

  end <- grep("</script>", content)
  end <- end[end > start[1]]
  if (length(end) == 0) return(list())

  json_lines <- content[(start[1] + 1):(end[1] - 1)]
  json_text <- paste(json_lines, collapse = "\n")
  tryCatch(
    jsonlite::fromJSON(json_text, simplifyVector = FALSE),
    error = function(e) list()
  )
}

#' Insert or update the <script class="ref-metadata"> JSON block in the index
#' file. The block goes inside the <div class="related-references"> div but
#' *after* the citations, immediately before the section's closing tag.
#'
#' Position matters for how the page loads. The block reaches 7.9 MB on the
#' largest publication, some 78% of that page, and while it sat at the top of
#' the section a reader's browser had to tokenise every byte of it before it
#' reached the first citation. Measured on the thesis page, the citations
#' finished parsing at 249 ms with the block first and at 102 ms with it last,
#' and over a real connection the gap is however long it takes to fetch 2.6 MB
#' of gzipped JSON rather than milliseconds. The reader's JavaScript finds the
#' block by class, so moving it costs nothing.
write_ref_metadata <- function(index_path, metadata) {
  if (length(metadata) == 0) return(FALSE)

  content <- readLines(index_path, encoding = "UTF-8", warn = FALSE)

  # Remove existing metadata block if present, along with any blank lines that
  # immediately surrounded it. Without this the padding below accumulated a
  # fresh pair of blank lines on every run.
  start <- grep('<script[^>]*class="ref-metadata"', content)
  if (length(start) > 0) {
    end <- grep("</script>", content)
    end <- end[end > start[1]]
    if (length(end) > 0) {
      first <- start[1]
      last <- end[1]
      while (first > 1 && !nzchar(trimws(content[first - 1]))) first <- first - 1
      while (last < length(content) && !nzchar(trimws(content[last + 1]))) last <- last + 1
      content <- content[-(first:last)]
    }
  }

  # The section must exist before anything is written into it.
  if (length(grep("related-references", content)) == 0) return(FALSE)

  # Convert metadata to compact JSON
  json_text <- jsonlite::toJSON(metadata, auto_unbox = TRUE, pretty = FALSE)

  insert_lines <- c(
    "",
    '<script type="application/json" class="ref-metadata">',
    as.character(json_text),
    "</script>",
    ""
  )

  # Insert before the last closing tag, which ends the related-references div;
  # the one before it ends the hanging-indent div holding the citations.
  close_divs <- grep("^\\s*</div>\\s*$", content)
  insert_at <- if (length(close_divs) > 0) close_divs[length(close_divs)] - 1 else length(content)
  if (insert_at < 0) insert_at <- 0

  head_lines <- if (insert_at > 0) content[1:insert_at] else character(0)
  tail_lines <- if (insert_at < length(content)) content[(insert_at + 1):length(content)] else character(0)
  content <- c(head_lines, insert_lines, tail_lines)

  writeLines(content, index_path, useBytes = TRUE)
  TRUE
}

# ===========================================================================
#  SCOPUS QUERY JSON BLOCK (embedded for JS viewer)
# ===========================================================================

#' Insert or update the <script class="scopus-queries"> JSON block in the
#' index file, inside the <div class="related-references"> section.
write_scopus_queries <- function(index_path, query, query_source,
                                 search_period, script_path = NULL,
                                 date_collected = Sys.Date()) {
  content <- readLines(index_path, encoding = "UTF-8", warn = FALSE)

  # Remove existing block if present, along with the blank lines that surrounded
  # it. The padding added below was never removed, so each run left two more
  # blank lines behind; one file had reached a run of 393.
  start <- grep('<script[^>]*class="scopus-queries"', content)
  if (length(start) > 0) {
    end <- grep("</script>", content)
    end <- end[end > start[1]]
    if (length(end) > 0) {
      first <- start[1]
      last <- end[1]
      while (first > 1 && !nzchar(trimws(content[first - 1]))) first <- first - 1
      while (last < length(content) && !nzchar(trimws(content[last + 1]))) last <- last + 1
      content <- content[-(first:last)]
    }
  }

  # Find insertion point: right after <div class = 'related-references'>
  related_div <- grep("related-references", content)
  if (length(related_div) == 0) return(FALSE)

  period_str <- if (is.character(search_period) && grepl("-", search_period)) {
    search_period
  } else {
    sp <- as.integer(search_period)
    paste0(min(sp), "-", max(sp))
  }
  info <- list(
    source  = query_source,
    query   = query,
    period  = period_str,
    collected = as.character(date_collected)
  )
  if (!is.null(script_path)) info$scriptPath <- script_path
  json_text <- jsonlite::toJSON(info, auto_unbox = TRUE, pretty = FALSE)

  insert_lines <- c(
    "",
    '<script type="application/json" class="scopus-queries">',
    as.character(json_text),
    "</script>",
    ""
  )

  insert_at <- related_div[1]
  tail_lines <- if (insert_at < length(content)) content[(insert_at + 1):length(content)] else character(0)
  content <- c(
    content[1:insert_at],
    insert_lines,
    tail_lines
  )

  writeLines(content, index_path, useBytes = TRUE)
  TRUE
}

# ===========================================================================
#  MAIN
# ===========================================================================

current_year <- as.integer(format(Sys.Date(), "%Y"))
any_changes <- FALSE

# Global time budget: stop adding new work after 30 minutes
# so the remaining time is available for git operations.
run_start_time <- proc.time()[["elapsed"]]
TIME_BUDGET_SECS <- 345 * 60  # 345 minutes (job timeout is 355 min)

time_remaining <- function() {
  TIME_BUDGET_SECS - (proc.time()[["elapsed"]] - run_start_time)
}

# Maximum number of DOIs to backfill metadata for in a single run.  Broad-topic
# publications can accumulate thousands of related references; backfilling them
# all in one job risks exceeding the time budget, and a job that is cancelled
# part-way persists nothing (its file changes are never uploaded).  Capping the
# work per run spreads the one-time catch-up over successive scheduled runs
# while keeping each run comfortably inside its budget.  Once the backlog is
# cleared, steady-state runs only backfill the handful of newly added DOIs, so
# the cap rarely binds again.
BACKFILL_CAP <- 400L

# ---- CLI argument: optional --pub NAME to process a single publication ----
args <- commandArgs(trailingOnly = TRUE)
single_pub <- NULL
if ("--pub" %in% args) {
  idx <- which(args == "--pub")
  if (idx < length(args)) {
    single_pub <- args[idx + 1]
    cat("Single-publication mode:", single_pub, "\n")
  }
}

pub_root <- "content/publication"
pub_dirs <- list.dirs(pub_root, recursive = FALSE, full.names = TRUE)
# Exclude hidden or underscore-prefixed entries
pub_dirs <- pub_dirs[!grepl("^[_.]", basename(pub_dirs))]

# Filter to a single publication if requested
if (!is.null(single_pub)) {
  pub_dirs <- pub_dirs[basename(pub_dirs) == single_pub]
  if (length(pub_dirs) == 0) {
    stop("Publication not found: ", single_pub)
  }
}

if (lint_only) pub_dirs <- character(0)

cat("Processing", length(pub_dirs), "publication folder(s)\n")

for (pub_dir in pub_dirs) {

  pub_name <- basename(pub_dir)
  cat("\n=== Processing:", pub_name, "===\n")

  # Check global time budget before starting a new publication
  if (time_remaining() < 120) {
    cat("  Time budget nearly exhausted (",
        round(time_remaining()), "s left). Stopping.\n")
    break
  }

  # ---- Find index file ----
  index_path <- find_index_file(pub_dir)
  if (is.null(index_path)) {
    cat("  Skipping: no index file found\n")
    next
  }

  fm <- read_frontmatter(index_path)
  if (length(fm) == 0) {
    cat("  Skipping: could not parse frontmatter\n")
    next
  }

  # ---- Standalone related-references.html (single source of truth for refs) ----
  refs_html_path <- find_refs_html_file(pub_dir)

  # ---- Determine related-references directory ----
  refs_dir <- find_refs_dir(pub_dir)

  # ---- Determine query ----
  query <- extract_query_from_script(refs_dir)
  query_source <- "script"

  if (is.null(query)) {
    query <- build_auto_query(fm)
    query_source <- "auto"
  }

  if (is.null(query)) {
    cat("  Skipping: no DOI or title available to build a query\n")
    next
  }

  cat("  Query source:", query_source, "\n")

  # ---- Determine search period ----
  search_period <- NULL
  if (query_source == "script") {
    search_period <- extract_period_from_script(refs_dir)
  }
  if (is.null(search_period)) {
    pub_year <- tryCatch(
      as.integer(substr(as.character(fm$date), 1, 4)),
      error = function(e) NULL
    )
    if (is.null(pub_year) || is.na(pub_year)) pub_year <- current_year - 1
    # Ensure at least a 7-year search window
    search_start <- min(pub_year, current_year - 6L)
    search_period <- search_start:current_year
  }

  cat("  Search period:", min(search_period), "-", max(search_period), "\n")

  # ---- Create refs dir if needed ----
  if (!dir.exists(refs_dir)) dir.create(refs_dir, recursive = TRUE)

  # ---- Existing DOIs (dedup) ----
  existing_dois <- extract_existing_dois(refs_html_path)
  cat("  Existing DOIs in related-references.html:", length(existing_dois), "\n")

  # ---- Pending DOI backlog ----
  # A long first collection can find far more candidates than the job has time
  # to fetch. Keep those DOI values durably so the next scheduled run resumes
  # them instead of narrowing its search window and losing the older tail.
  backlog_path <- file.path(refs_dir, "pending-dois.json")
  backlog_exists <- file.exists(backlog_path)
  backlog <- read_ref_collection_backlog(refs_dir)
  if (!backlog$valid) {
    cat("  Skipping: pending DOI backlog is unreadable and was left untouched\n")
    next
  }
  excluded_dois <- backlog$excluded
  excluded_dois <- excluded_dois[!excluded_dois %in% existing_dois]
  pending_dois <- backlog$pending
  pending_dois <- pending_dois[!pending_dois %in%
    unique(c(existing_dois, excluded_dois))]
  if (length(pending_dois) > 0) {
    cat("  Pending DOI backlog:", length(pending_dois), "DOIs\n")
  }

  # ---- Run Scopus search ----
  # Citation HTML is the durable list state and pending-dois.json records an
  # unfinished fetch batch. This avoids timestamped Scopus snapshots while
  # still allowing a time-limited run to continue collecting later.
  initial_search_complete <- isTRUE(backlog$initial_search_complete) ||
    length(existing_dois) > 0L
  is_first_run <- !initial_search_complete

  # On subsequent runs, use a rolling 3-year lookback window so that
  # 2024/2025 papers not captured on the first run (due to Scopus relevance
  # sorting) are picked up in future runs, while still searching ahead to
  # catch newly published work.
  run_period <- search_period
  if (!is_first_run) {
    run_start <- current_year - 2L   # rolling 3-year lookback
    run_end   <- current_year + 1L
    # Never go before the original search start
    run_start <- max(run_start, min(search_period))
    if (run_start > run_end) run_start <- run_end
    run_period <- run_start:run_end
    cat("  Narrowed run period:", min(run_period), "-", max(run_period), "\n")
  }

  scopus_result <- tryCatch({
    cat(if (is_first_run) "  Initial Scopus search\n" else
      "  Rolling Scopus search\n")
    list(dois = search_scopus_dois(query, run_period), succeeded = TRUE)
  }, error = function(e) {
    cat("  Scopus search error:", e$message, "\n")
    list(dois = character(0), succeeded = FALSE)
  })
  scopus_dois <- scopus_result$dois

  if (length(scopus_dois) == 0) {
    cat("  No DOIs returned from Scopus\n")
    scopus_dois <- character(0)
  }

  # ---- Build the fetch queue ----
  # Existing backlog candidates stay first so the initial full-period search
  # is completely harvested across runs. Fresh rolling-search candidates are
  # then appended for newly published work. Stored citations and manual skips
  # and prior terminal exclusions are excluded before the queue is persisted.
  scopus_dois <- normalise_doi_vector(scopus_dois)
  known_dois <- unique(c(existing_dois, excluded_dois))
  scopus_dois <- scopus_dois[!scopus_dois %in% known_dois]
  new_dois <- unique(c(pending_dois, scopus_dois))
  initial_search_complete <- initial_search_complete ||
    (is_first_run && isTRUE(scopus_result$succeeded))
  persist_backlog <- backlog_exists || length(new_dois) > 0 ||
    length(excluded_dois) > 0 ||
    (initial_search_complete && length(existing_dois) == 0L)
  if (persist_backlog && write_ref_collection_backlog(
    refs_dir, new_dois, excluded_dois, initial_search_complete
  )) {
    any_changes <- TRUE
    cat("  Saved", length(new_dois), "DOIs for resumable collection\n")
  }
  cat("  DOIs awaiting citation fetch:", length(new_dois), "\n")

  # ---- Fetch APA 7 citations and CrossRef metadata for new DOIs ----
  new_citations <- character(0)
  new_metadata <- list()
  discarded_dois <- character(0)
  citation_dois <- character(0)
  inserted_dois <- character(0)
  for (doi in new_dois) {
    if (time_remaining() < 90) {
      cat("  Time budget low (", round(time_remaining()), "s). Stopping new-DOI fetches.\n")
      break
    }
    cat("  Fetching:", doi, "\n")
    # Fetch metadata first so we can check language before fetching the citation
    meta <- get_crossref_metadata(doi)
    # Skip non-English papers: check CrossRef language tag, then title characters
    cr_lang <- meta$language
    if (!is.null(cr_lang) && !grepl("^en", cr_lang, ignore.case = TRUE)) {
      cat("    Skipping: non-English language tag (", cr_lang, ")\n")
      discarded_dois <- c(discarded_dois, doi)
      next
    }
    # Skip non-paper CrossRef types that lack meaningful citation metadata
    non_paper_types <- c("component", "dataset", "peer-review", "grant",
                         "report-component", "other")
    if (!is.null(meta$type) && tolower(meta$type) %in% non_paper_types) {
      cat("    Skipping: CrossRef type '", meta$type, "' is not a citable paper\n", sep = "")
      discarded_dois <- c(discarded_dois, doi)
      next
    }
    # Skip retracted papers
    if (isTRUE(meta$retracted)) {
      cat("    Skipping: paper has been retracted\n")
      discarded_dois <- c(discarded_dois, doi)
      next
    }
    # Skip self-citation (DOI matches this publication's own DOI)
    pub_doi <- tolower(trimws(fm$doi %||% ""))
    if (nchar(pub_doi) > 0 && tolower(trimws(doi)) == pub_doi) {
      cat("    Skipping: self-citation\n")
      discarded_dois <- c(discarded_dois, doi)
      next
    }
    # Skip future publication years (data entry errors in CrossRef)
    py <- meta$pub_year
    if (length(py) == 1L && !is.na(py) && py > current_year + 1L) {
      cat("    Skipping: publication year", meta$pub_year, "is implausibly far in the future\n")
      discarded_dois <- c(discarded_dois, doi)
      next
    }
    cit <- get_apa7_citation(doi)
    if (!is.null(cit) && contains_non_latin_script(cit)) {
      cat("    Skipping: non-Latin script detected in citation\n")
      discarded_dois <- c(discarded_dois, doi)
      next
    }
    fmt <- format_citation_for_hugo(cit, doi)
    if (!is.null(fmt)) {
      new_citations <- c(new_citations, fmt)
      citation_dois <- c(citation_dois, doi)
    } else {
      cat("    Warning: citation unavailable\n")
    }
    # Store metadata (abstract + type + dateAdded) for the JS UI
    entry <- list()
    if (!is.null(meta$abstract)) entry$abstract <- meta$abstract
    if (!is.null(meta$type)) entry$type <- meta$type
    entry$dateAdded <- format(Sys.Date(), "%Y-%m-%d")
    new_metadata[[doi]] <- entry
    Sys.sleep(0.5)
  }

  # ---- Sort & insert new citations ----
  if (length(new_citations) > 0) {
    new_citations <- sort(new_citations)
    cat("  Inserting", length(new_citations), "citations into related-references.html\n")
    if (insert_references_into_refs_html(refs_html_path, new_citations)) {
      any_changes <- TRUE
      inserted_dois <- citation_dois
      cat("  Done\n")
    } else {
      cat("  Failed to update related-references.html\n")
    }
  }

  # Keep candidates until their citation was durably inserted. Deliberately
  # rejected items are removed too; transient citation failures remain queued
  # for a later retry instead of being silently lost.
  resolved_dois <- unique(c(discarded_dois, inserted_dois))
  remaining_dois <- new_dois[!new_dois %in% resolved_dois]
  excluded_dois <- unique(c(excluded_dois, discarded_dois))
  # Only write a final state when this publication already has, or this run
  # created, resumable state. Established lists with no candidates should not
  # acquire an empty sidecar merely because the scheduled action ran.
  if (persist_backlog && write_ref_collection_backlog(
    refs_dir, remaining_dois, excluded_dois, initial_search_complete
  )) {
    any_changes <- TRUE
    cat("  Pending DOI backlog now:", length(remaining_dois), "DOIs\n")
  }

  # ---- Backfill metadata for existing DOIs without metadata ----
  # Bounded, resumable backfill. Broad-topic publications can have thousands of
  # related references — far more than can be processed in one job — so each run
  # backfills at most BACKFILL_CAP DOIs and records an entry for every DOI it
  # touches. The "missing metadata" backlog therefore shrinks monotonically
  # across successive scheduled runs until it is exhausted. (A cancelled step
  # uploads nothing, so the only durable progress is a run that finishes and
  # commits; the cap keeps every run inside its time budget.) The JS UI still
  # fetches abstracts on demand for any DOI not yet backfilled.
  existing_metadata <- read_ref_metadata(refs_html_path)
  all_dois <- extract_existing_dois(refs_html_path)

  # DOIs completely missing from the metadata block. Highest priority: writing
  # any entry here is what lets a DOI leave the backlog permanently.
  dois_missing_meta <- setdiff(all_dois, tolower(names(existing_metadata)))
  # DOIs present in metadata but still lacking an abstract. Retried only a
  # bounded number of times so that papers with no abstract available anywhere
  # stop being re-queried on every run (which would otherwise keep the backlog
  # permanently non-empty and starve the DOIs further down the list).
  MAX_ABSTRACT_ATTEMPTS <- 3L
  # An entry marked abstractPruned had its abstract deliberately dropped by
  # scripts/prune_reference_abstracts.py because the reference ranks too low to
  # be worth shipping; the reader fetches it on demand instead. Without this
  # guard the backfill would read the missing abstract as a gap, fetch it from
  # CrossRef again and undo the pruning on the next scheduled run.
  #
  # Index with [["..."]] rather than $. R's $ partial-matches, so on an entry
  # that carries abstractAttempts but no abstract, e$abstract returned the
  # attempt count instead of NULL. That read as "already has an abstract", so a
  # DOI was retried once and then dropped out of this set for good, and
  # MAX_ABSTRACT_ATTEMPTS never came into play.
  dois_missing_abstract <- Filter(
    function(d) {
      e <- existing_metadata[[d]]
      is.null(e[["abstract"]]) &&
        !isTRUE(e[["abstractPruned"]]) &&
        (as.integer(e[["abstractAttempts"]] %||% 0L) < MAX_ABSTRACT_ATTEMPTS)
    },
    tolower(names(existing_metadata))
  )
  # New-entry DOIs first, then abstract retries.
  dois_to_backfill <- unique(c(dois_missing_meta, dois_missing_abstract))

  if (length(dois_to_backfill) > 0 && time_remaining() > 60) {
    # Two independent caps: a hard per-run count (BACKFILL_CAP) that bounds the
    # work regardless of nominal time left, and a time-based cap as a secondary
    # guard (~3s per DOI, leaving 60s for file writes).
    time_cap <- max(1L, as.integer((time_remaining() - 60) / 3))
    n_to_fill <- min(length(dois_to_backfill), time_cap, BACKFILL_CAP)
    n_deferred <- length(dois_to_backfill) - n_to_fill
    cat("  Backfilling metadata for", n_to_fill, "of",
        length(dois_to_backfill), "DOIs (",
        length(dois_missing_meta), "new,",
        length(dois_missing_abstract), "missing abstract);",
        n_deferred, "deferred to later runs\n")
    n_done <- 0L
    for (doi in dois_to_backfill[seq_len(n_to_fill)]) {
      if (time_remaining() < 60) {
        cat("  Time budget low (", round(time_remaining()), "s). Stopping backfill.\n")
        break
      }
      meta <- get_crossref_metadata(doi)
      entry <- existing_metadata[[doi]] %||% list()
      if (!is.null(meta$abstract)) entry$abstract <- meta$abstract
      if (!is.null(meta$type)) entry$type <- meta$type
      # Count an abstract-retry attempt when none could be obtained, so that
      # genuinely abstract-less papers eventually drop out of the retry set.
      # Exact indexing again: entry$abstract would partial-match the counter
      # this branch maintains, so it never incremented past one.
      if (is.null(entry[["abstract"]])) {
        entry$abstractAttempts <- as.integer(entry[["abstractAttempts"]] %||% 0L) + 1L
      }
      # Stamp every touched DOI so it leaves the "missing metadata" backlog even
      # when neither an abstract nor a type could be retrieved. This guarantees
      # forward progress: without it, a DOI that CrossRef cannot resolve would be
      # retried on every future run and block the rest of the backlog.
      entry$backfilled <- format(Sys.Date(), "%Y-%m-%d")
      new_metadata[[doi]] <- entry
      n_done <- n_done + 1L
      if (n_done %% 50L == 0L) {
        cat("    ...", n_done, "of", n_to_fill, "backfilled (",
            round(time_remaining()), "s left)\n")
      }
      Sys.sleep(0.5)
    }
  } else if (length(dois_to_backfill) > 0) {
    cat("  Skipping backfill (time budget low:", round(time_remaining()), "s left)\n")
  }

  # ---- Write metadata JSON block (new + backfilled) ----
  if (length(new_metadata) > 0) {
    merged_metadata <- modifyList(existing_metadata, new_metadata)
    write_ref_metadata(refs_html_path, merged_metadata)
    any_changes <- TRUE
    cat("  Updated metadata for", length(new_metadata), "DOIs\n")
  }

  # Embed Scopus query info for the JS viewer.
  sp <- "scripts/collect_related_references.R"
  # Only write if not already present
  refs_html_content <- readLines(refs_html_path, encoding = "UTF-8", warn = FALSE)
  if (!any(grepl('class="scopus-queries"', refs_html_content))) {
    write_scopus_queries(refs_html_path, query, query_source, search_period,
                         script_path = sp)
    any_changes <- TRUE
    cat("  Embedded Scopus query info\n")
  }
}

# ===========================================================================
#  APA 7 LETTER CASE
# ===========================================================================
#
# CrossRef returns whatever case the publisher deposited, so about a third of
# titles arrive in Title Case where APA 7 requires sentence case. Whether a
# capitalised word is a proper noun cannot be decided from the word alone, so
# each word's case is learned from the abstracts already stored in the
# ref-metadata blocks: running prose in which "English" and "Bayesian" are
# always capitalised while "memory" and "processing" almost never are. Titles
# are not used as evidence, since rewriting them would feed the next run's
# lexicon. A title is rewritten only when every capitalised word in it is
# confidently classified, so one unrecognised word leaves the title untouched.

CASE_MIN_COUNT    <- 5     # attestations required before a word is judged
CASE_LOWER_SHARE  <- 0.95  # lowercase share above which a word is a common word
CASE_PROPER_SHARE <- 0.25  # lowercase share below which a word is a proper noun
# Titles cluster at either end of this measure, with a sparse band between
# roughly 0.3 and 0.65, so the threshold sits in the valley.
CASE_TITLE_SHARE  <- 0.65

APA_HYPHENS  <- "[-\u2010\u2011\u2012\u2013\u2014]"
APA_SENT_END <- "[:?!.\u2014\u2013]['\"\u2019\u201d)]?$"
# A word whose case can be judged: one capital followed by lower case. Acronyms,
# camel case and anything carrying digits fall outside it and are left alone.
APA_PLAIN_WORD <- "^[[:upper:]][[:lower:]'\u2019]+$"

#' Tokenise running prose, dropping the positions where English capitalises
#' whatever the word is: sentence-initial, structured-abstract headings
#' ("Methods:"), and enumerated labels ("Study 1", "Experiment 2").
prose_tokens <- function(text) {
  parts <- strsplit(text, "\\s+")[[1]]
  n <- length(parts)
  if (n < 2) return(character(0))
  keep <- rep(TRUE, n)
  keep[1] <- FALSE
  after_stop <- which(grepl(APA_SENT_END, parts, perl = TRUE)) + 1
  keep[after_stop[after_stop <= n]] <- FALSE
  keep[grepl(":$", parts)] <- FALSE
  keep[grepl("^[(\\[]?[0-9]", c(parts[-1], ""), perl = TRUE)] <- FALSE
  words <- gsub("^[^[:alpha:]]+|[^[:alpha:]'\u2019-]+$", "", parts[keep], perl = TRUE)
  words[nchar(words) >= 3 & grepl("^[[:alpha:]]", words, perl = TRUE)]
}

#' Learn which words are ordinary common words and which are proper nouns.
#' Returns two environments used as sets, so that lookup stays O(1) across the
#' tens of thousands of words checked per run.
build_case_lexicon <- function(refs_files) {
  as_set <- function(x) {
    x <- x[nzchar(x)]
    e <- new.env(hash = TRUE, parent = emptyenv(), size = max(29L, length(x)))
    for (w in x) assign(w, TRUE, envir = e)
    e
  }
  empty <- list(safe = as_set(character(0)), proper = as_set(character(0)))

  abstracts <- unlist(lapply(refs_files, function(f) {
    unlist(lapply(read_ref_metadata(f), function(m) m$abstract %||% NULL))
  }))
  if (length(abstracts) == 0) return(empty)

  tokens <- unlist(lapply(abstracts, prose_tokens))
  if (length(tokens) == 0) return(empty)

  lower <- tolower(tokens)
  total <- table(lower)
  lc    <- table(lower[!grepl("^[[:upper:]]", tokens, perl = TRUE)])
  words <- names(total)
  n_total <- as.numeric(total[words])
  n_lower <- as.numeric(ifelse(words %in% names(lc), lc[words], 0))
  share <- n_lower / n_total

  list(
    safe   = as_set(words[n_lower >= CASE_MIN_COUNT & share >= CASE_LOWER_SHARE]),
    proper = as_set(words[n_total >= CASE_MIN_COUNT & share <= CASE_PROPER_SHARE])
  )
}

classify_word <- function(word, lex) {
  w <- tolower(word)
  if (exists(w, envir = lex$safe, inherits = FALSE)) {
    "safe"
  } else if (exists(w, envir = lex$proper, inherits = FALSE)) {
    "proper"
  } else {
    "unknown"
  }
}

#' Share of a title's content words that carry a capital, ignoring positions
#' where APA 7 requires one anyway. NA when the title is too short to judge.
title_case_share <- function(title) {
  parts <- strsplit(title, "\\s+")[[1]]
  if (length(parts) < 2) return(NA_real_)
  keep <- rep(TRUE, length(parts))
  keep[1] <- FALSE
  after_stop <- which(grepl(APA_SENT_END, parts, perl = TRUE)) + 1
  keep[after_stop[after_stop <= length(parts)]] <- FALSE
  words <- gsub("[^[:alpha:]'\u2019-]", "", parts[keep], perl = TRUE)
  words <- words[nchar(words) >= 3]
  if (length(words) < 4) return(NA_real_)
  mean(grepl("^[[:upper:]]", words, perl = TRUE))
}

#' Rewrite a Title Cased title in APA 7 sentence case. Reports whether every
#' capitalised word could be classified; an incomplete result must be discarded
#' rather than used, since a half-converted title is worse than none.
apa_sentence_case <- function(title, lex) {
  words <- strsplit(title, " ", fixed = TRUE)[[1]]
  if (length(words) < 2) return(list(text = title, complete = FALSE))

  out <- words
  complete <- TRUE
  # CrossRef occasionally prefixes a title with a chapter number, which must not
  # be mistaken for the first word.
  first_word <- which(grepl("[[:alpha:]]", words, perl = TRUE))[1]
  if (is.na(first_word)) return(list(text = title, complete = FALSE))

  for (i in seq_along(words)) {
    word <- words[i]
    core <- gsub("^[^[:alpha:]]+|[^[:alpha:]'\u2019]+$", "", word, perl = TRUE)
    if (!nzchar(core)) next
    segments <- strsplit(core, APA_HYPHENS, perl = TRUE)[[1]]
    separators <- regmatches(core, gregexpr(APA_HYPHENS, core, perl = TRUE))[[1]]
    if (any(!nzchar(segments)) || length(separators) != length(segments) - 1L) next

    # The word opening the title or a new sentence keeps its capital, but the
    # rest of a hyphenated compound does not: "Self-report", not "Self-Report".
    at_start <- i <= first_word || grepl(APA_SENT_END, words[i - 1L], perl = TRUE)
    idx <- if (at_start) seq_along(segments)[-1] else seq_along(segments)
    if (!length(idx)) next

    judged <- grepl(APA_PLAIN_WORD, segments[idx], perl = TRUE)
    # Acronyms, camel case and anything carrying digits are left alone, and do
    # not count against the title: "fMRI" and "COVID-19" are already correct.
    if (!all(judged | grepl("^[[:lower:]]", segments[idx], perl = TRUE))) next

    classes <- vapply(segments[idx][judged], classify_word, character(1),
                      lex = lex, USE.NAMES = FALSE)
    if (any(classes == "unknown")) { complete <- FALSE; next }
    demote <- idx[judged][classes == "safe"]
    if (!length(demote)) next

    segments[demote] <- tolower(segments[demote])
    new_core <- paste0(segments, c(separators, ""), collapse = "")
    out[i] <- sub(core, new_core, word, fixed = TRUE)
  }
  list(text = paste(out, collapse = " "), complete = complete)
}

# The title is the span between the year and the italicised container, which is
# the only boundary that can be located reliably. Lines without it are skipped.
APA_TITLE_PATTERN <- "^(<p[^>]*>.*?\\(\\d{4}[a-z]?\\)\\.\\s+)(.*?)(<em>.*)$"

fix_title_case_in_line <- function(ln, lex) {
  if (!grepl(APA_TITLE_PATTERN, ln, perl = TRUE)) return(ln)
  prefix <- sub(APA_TITLE_PATTERN, "\\1", ln, perl = TRUE)
  span   <- sub(APA_TITLE_PATTERN, "\\2", ln, perl = TRUE)
  suffix <- sub(APA_TITLE_PATTERN, "\\3", ln, perl = TRUE)

  # In an edited-book reference the span runs past the title into the editor
  # field ("... . In B. Editor (Ed.), "), which is not sentence cased.
  editor_at <- regexpr("\\.\\s+In\\s+[A-Z]", span, perl = TRUE)
  editor_tail <- ""
  if (editor_at > 0) {
    editor_tail <- substring(span, editor_at)
    span <- substring(span, 1, editor_at - 1)
  }
  trail <- regmatches(span, regexpr("\\s*$", span))
  span <- substring(span, 1, nchar(span) - nchar(trail))

  # A title deposited wholly in capitals carries no case information to recover.
  if (!nzchar(span) || !grepl("[[:lower:]]", span, perl = TRUE)) return(ln)
  share <- title_case_share(span)
  if (is.na(share) || share < CASE_TITLE_SHARE) return(ln)

  result <- apa_sentence_case(span, lex)
  if (!result$complete || identical(result$text, span)) return(ln)
  paste0(prefix, result$text, trail, editor_tail, suffix)
}

# Work types whose italicised span is the work's own title rather than a
# periodical name. Proceedings are excluded: APA 7 sets them in sentence case
# only when published as a book, and the deposit does not say which.
APA_BOOK_TYPES <- c("book", "book-chapter", "edited-book", "monograph",
                    "reference-book", "dissertation", "report")

#' Apply sentence case to the italicised title of a book or chapter container.
#' A journal name stays in title case, so this runs only on the types above.
fix_container_case_in_line <- function(ln, lex, type) {
  if (!type %in% APA_BOOK_TYPES || !grepl("<em>", ln, fixed = TRUE)) return(ln)
  prefix <- sub("^(.*?<em>).*$", "\\1", ln, perl = TRUE)
  span   <- sub("^.*?<em>(.*?)</em>.*$", "\\1", ln, perl = TRUE)
  suffix <- sub("^.*?<em>.*?(</em>.*)$", "\\1", ln, perl = TRUE)

  # A second italic span straight after the first is the volume number of a
  # periodical, so the deposited type is wrong and the span is a journal name.
  if (grepl("^</em>,\\s*<em>", suffix, perl = TRUE)) return(ln)
  if (!nzchar(span) || !grepl("[[:lower:]]", span, perl = TRUE)) return(ln)

  share <- title_case_share(span)
  if (is.na(share) || share < CASE_TITLE_SHARE) return(ln)
  result <- apa_sentence_case(span, lex)
  if (!result$complete || identical(result$text, span)) return(ln)
  paste0(prefix, result$text, suffix)
}

# Author fields are occasionally deposited wholly in capitals.
APA_AUTHOR_PATTERN <- "^(<p[^>]*>)(.*?)(\\s*\\(\\d{4}[a-z]?\\).*)$"
APA_UPPER <- "A-Z\u00C0-\u00D6\u00D8-\u00DE"

fix_author_case_in_line <- function(ln) {
  if (!grepl(APA_AUTHOR_PATTERN, ln, perl = TRUE)) return(ln)
  prefix  <- sub(APA_AUTHOR_PATTERN, "\\1", ln, perl = TRUE)
  authors <- sub(APA_AUTHOR_PATTERN, "\\2", ln, perl = TRUE)
  suffix  <- sub(APA_AUTHOR_PATTERN, "\\3", ln, perl = TRUE)

  letters_only <- gsub("&amp;|[^A-Za-z]", "", authors)
  if (nchar(letters_only) < 2 || grepl("[a-z]", letters_only)) return(ln)

  # Only ASCII and Latin-1 names are recased; case mapping is locale dependent
  # for scripts such as Turkish, where lowercasing "I" is ambiguous.
  eligible <- paste0("^[", APA_UPPER, "'\u2019-]{2,}[,.]?$")
  recase <- function(w) {
    if (!grepl(eligible, w, perl = TRUE)) return(w)
    core <- sub("[,.]+$", "", w)
    punct <- substring(w, nchar(core) + 1)
    parts <- strsplit(core, "(?<=['\u2019-])", perl = TRUE)[[1]]
    parts <- vapply(parts, function(p) sub("^(.)(.*)$", "\\1\\L\\2", p, perl = TRUE),
                    character(1), USE.NAMES = FALSE)
    out <- paste0(parts, collapse = "")
    paste0(sub("^Mc([a-z])", "Mc\\U\\1", out, perl = TRUE), punct)
  }
  words <- strsplit(authors, " ", fixed = TRUE)[[1]]
  paste0(prefix, paste(vapply(words, recase, character(1), USE.NAMES = FALSE),
                       collapse = " "), suffix)
}

# ===========================================================================
#  LINT EXISTING REFERENCES
#  Re-scan all publication index files for known bad patterns and fix in place.
# ===========================================================================

cat("\n=== Linting existing references ===\n")

lint_files <- list.files("content/publication", pattern = "related-references\\.html$",
                         recursive = TRUE, full.names = TRUE)

# Built once from every publication's abstracts, so that a word's case is
# judged against the whole corpus rather than against one publication's topic.
case_lexicon <- build_case_lexicon(lint_files)
cat("Case lexicon:", length(ls(case_lexicon$safe)), "common words,",
    length(ls(case_lexicon$proper)), "proper nouns\n")

for (lf in lint_files) {
  lines <- readLines(lf, encoding = "UTF-8", warn = FALSE)
  changed_lint <- FALSE

  # Strip leading <p> tags to expose raw citation text for author-field checks.
  # All citation lines in related-references.html are wrapped in <p>...</p>.
  inner <- sub("^<p[^>]*>\\s*", "", lines)

  # The removal rules below (2-5) only ever apply to actual citation paragraphs
  # (lines beginning with <p>). The file also holds <script> blocks — the
  # ref-metadata and scopus-queries JSON — whose single content line can
  # coincidentally match a citation pattern (e.g. an embedded abstract that
  # contains a "https://doi.org/..." URL). Guarding every removal with
  # is_citation_line() prevents the lint pass from silently deleting the
  # metadata JSON, which would otherwise wipe every backfilled abstract on each
  # run — the reason metadata never persisted for broad-topic publications.
  is_citation_line <- function(x) grepl("^\\s*<p[^>]*>", x, perl = TRUE)

  # 1. Remove duplicate plain DOI URL when a hyperlinked DOI already exists.
  #    Handles both orderings:
  #    a) bare DOI preceding the <a href> link
  #    b) bare DOI following a </a> close-tag (already linked)
  new_lines <- gsub(
    "\\s+https?://doi\\.org/[^\"<>\\s]+\\.?\\s+(<a\\s)",
    " \\1",
    lines,
    ignore.case = TRUE,
    perl = TRUE
  )
  new_lines <- gsub(
    "(</a>)(\\.?\\s+)https?://doi\\.org/[^\"<>\\s]+\\.?",
    "\\1\\2",
    new_lines,
    ignore.case = TRUE,
    perl = TRUE
  )
  if (any(new_lines != lines)) { changed_lint <- TRUE }
  lines <- new_lines

  # 2. Remove ahead-of-print placeholders: lines where volume/issue is "0(0)".
  keep <- !(is_citation_line(lines) & grepl(",\\s*0\\s*\\(0\\)", lines, perl = TRUE))
  if (any(!keep)) { changed_lint <- TRUE }
  lines  <- lines[keep]
  inner  <- inner[keep]

  # 3. Remove citations with no author: citation text (after <p>) starts with
  #    "(" followed by a year or "N.d." and the line contains a DOI link.
  keep <- !(is_citation_line(lines) &
              grepl("^\\s*\\(([0-9]|N\\.d\\.)", inner, perl = TRUE) &
              grepl("https://doi.org/", lines, fixed = TRUE))
  if (any(!keep)) { changed_lint <- TRUE }
  lines  <- lines[keep]
  inner  <- inner[keep]

  # 4. Remove citations where the title occupies the author field (CrossRef artefact).
  #    Valid APA author fields have either personal initials (", J.") or are
  #    institutional names that end with "." and contain no "?" or ":".
  pre_year_lint <- sub("\\(\\d{4}.*", "", inner, perl = TRUE)
  has_personal_lint      <- grepl(",\\s*[A-Z]\\.", pre_year_lint, perl = TRUE)
  has_institutional_lint <- grepl("\\.\\s*$", pre_year_lint) & !grepl("[?:]", pre_year_lint)
  keep <- !(is_citation_line(lines) &
              grepl("https://doi.org/", lines, fixed = TRUE) &
              !has_personal_lint & !has_institutional_lint)
  if (any(!keep)) { changed_lint <- TRUE }
  lines  <- lines[keep]
  inner  <- inner[keep]

  # 5. Remove duplicate DOI links within the same file (keep first occurrence).
  #    DOI URLs in HTML appear as href="https://doi.org/..." — exclude quote/angle chars.
  #    Use substr + attr to keep the result aligned with `lines` (regmatches drops
  #    non-matching elements, which would misalign the index). Only citation
  #    paragraphs participate; <script>/JSON lines are ignored so an abstract's
  #    embedded DOI can neither be removed nor evict a real citation's DOI.
  m_doi <- regexpr("https://doi\\.org/[^\"<>\\s]+", lines, perl = TRUE)
  doi_hits <- tolower(ifelse(
    is_citation_line(lines) & m_doi > 0L,
    substr(lines, m_doi, m_doi + attr(m_doi, "match.length") - 1L),
    NA_character_
  ))
  seen_dois <- character(0)
  keep <- vapply(seq_along(lines), function(i) {
    d <- doi_hits[i]
    if (is.na(d) || nchar(d) == 0L) return(TRUE)
    if (d %in% seen_dois) return(FALSE)
    seen_dois <<- c(seen_dois, d)
    TRUE
  }, logical(1))
  if (any(!keep)) { changed_lint <- TRUE }
  lines <- lines[keep]

  # 6. Close unclosed <em> tags within <p> reference lines.
  #    CrossRef sometimes returns titles with an <em> that is never closed (e.g.
  #    when the title is truncated mid-word, or when <scp> tags are mixed in).
  #    For every line starting with <p>, count open vs close <em> tags; if there
  #    is a deficit, insert the missing </em> closers just before </p>.
  fix_em_line <- function(ln) {
    if (!grepl("^\\s*<p[^>]*>", ln, perl = TRUE)) return(ln)
    n_open  <- lengths(regmatches(ln, gregexpr("<em>",  ln, fixed = TRUE)))
    n_close <- lengths(regmatches(ln, gregexpr("</em>", ln, fixed = TRUE)))
    deficit <- n_open - n_close
    if (deficit <= 0L) return(ln)
    closers <- strrep("</em>", deficit)
    if (grepl("</p>\\s*$", ln, perl = TRUE)) {
      # Insert before the closing </p>
      gsub("</p>\\s*$", paste0(closers, "</p>"), ln, perl = TRUE)
    } else {
      # No </p> — append closers and add </p>
      paste0(trimws(ln, which = "right"), closers, "</p>")
    }
  }
  new_lines <- vapply(lines, fix_em_line, character(1L), USE.NAMES = FALSE)
  if (any(new_lines != lines)) { changed_lint <- TRUE }
  lines <- new_lines

  # 7. Remove orphan inline-tag lines (e.g. "<scp>CEOs</scp>") that appear
  #    between <p> reference lines.  These arise when CrossRef returns a title
  #    split across lines with a <scp> small-caps tag for an acronym; the R
  #    pandoc pipeline writes the continuation on a bare line without a <p>
  #    wrapper, leaving an unattached fragment.  We keep only lines that are
  #    either (a) empty/whitespace, (b) start with a recognised block tag
  #    (<p>, <h2>, <div>, </div>, <script>, </script>, <!), or (c) are the
  #    JSON / JS content that sits inside a <script> block.
  in_script <- FALSE
  keep_orphan <- vapply(lines, function(ln) {
    stripped <- trimws(ln)
    if (grepl("^<script", stripped)) { in_script <<- TRUE;  return(TRUE) }
    if (grepl("^</script", stripped)) { in_script <<- FALSE; return(TRUE) }
    if (in_script) return(TRUE)
    if (nchar(stripped) == 0L) return(TRUE)
    grepl("^<(?:p[^>]*>|h[1-6]|div|/div|/p>|!)", stripped, perl = TRUE)
  }, logical(1L), USE.NAMES = FALSE)
  if (any(!keep_orphan)) { changed_lint <- TRUE }
  lines <- lines[keep_orphan]

  # 8. Repair double-escaped HTML entities in reference lines. CrossRef deposits
  #    container titles pre-escaped and its APA formatter title-cases the entity
  #    name, so "&" arrived as "&Amp;" and was escaped again on insertion,
  #    leaving the page showing "&Amp;" instead of "&".
  fix_entities_line <- function(ln) {
    if (!is_citation_line(ln)) return(ln)
    out <- ln
    # Escaping is occasionally layered more than once, and gsub does not rescan
    # its own output, so collapse repeatedly until the line settles.
    for (pass in seq_len(5L)) {
      collapsed <- gsub("&amp;amp;", "&amp;", out, perl = TRUE, ignore.case = TRUE)
      if (identical(collapsed, out)) break
      out <- collapsed
    }
    refs <- gregexpr("&amp;#[xX]?[0-9A-Fa-f]+;", out, perl = TRUE)
    regmatches(out, refs) <- lapply(regmatches(out, refs), function(hits) {
      decode_html_entities(sub("^&amp;", "&", hits))
    })
    out
  }
  new_lines <- vapply(lines, fix_entities_line, character(1L), USE.NAMES = FALSE)
  if (any(new_lines != lines)) { changed_lint <- TRUE }
  lines <- new_lines

  # 9. Convert Title Cased titles to APA 7 sentence case, leaving any title
  #    containing a word the corpus cannot classify exactly as deposited.
  ref_types <- vapply(read_ref_metadata(lf),
                      function(m) as.character(m$type %||% "")[1], character(1L))
  names(ref_types) <- tolower(names(ref_types))
  new_lines <- vapply(lines, function(ln) {
    if (!is_citation_line(ln)) return(ln)
    doi <- if (grepl('href="https?://doi\\.org/', ln, perl = TRUE)) {
      tolower(sub('^.*href="https?://doi\\.org/([^"]+)".*$', "\\1", ln, perl = TRUE))
    } else ""
    hit <- match(doi, names(ref_types))
    ln <- fix_title_case_in_line(ln, case_lexicon)
    fix_container_case_in_line(ln, case_lexicon,
                               if (is.na(hit)) "" else ref_types[[hit]])
  }, character(1L), USE.NAMES = FALSE)
  if (any(new_lines != lines)) { changed_lint <- TRUE }
  lines <- new_lines

  # 10. Recase author fields deposited wholly in capitals ("BYBEE, J.").
  new_lines <- vapply(lines, function(ln) {
    if (!is_citation_line(ln)) return(ln)
    fix_author_case_in_line(ln)
  }, character(1L), USE.NAMES = FALSE)
  if (any(new_lines != lines)) { changed_lint <- TRUE }
  lines <- new_lines

  if (changed_lint) {
    writeLines(lines, lf, useBytes = TRUE)
    any_changes <- TRUE
    cat("  Linted:", basename(dirname(lf)), "\n")
  }
}

cat("\n=== Finished ===\n")
if (any_changes) {
  cat("Changes were made — ready to commit.\n")
} else {
  cat("No changes to commit.\n")
}
