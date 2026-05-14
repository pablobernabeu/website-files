# collect_related_references.R
#
# Fully automated weekly collection of related references for publications.
# - Auto-discovers every publication under content/publication/
# - For publications with an existing related references R script, extracts
#   the query from that script
# - For publications without one, auto-generates a Scopus query from the
#   publication title and DOI
# - Searches Scopus via scopus_search_DOIs / scopus_search_additional_DOIs
# - Retrieves APA 7 formatted citations via CrossRef content negotiation
# - Inserts new citations into each publication's index file, sorted
#   alphabetically and deduplicated
#
# Usage:
#   Rscript scripts/collect_related_references.R              # all publications
#   Rscript scripts/collect_related_references.R --pub NAME   # single publication
#
# Environment variables:
#   SCOPUS_API_KEY  — Elsevier Scopus API key (required)

library(rscopus)
library(dplyr)
library(jsonlite)

# Null-coalescing operator
`%||%` <- function(a, b) if (!is.null(a)) a else b

# ---- Scopus API key ----

api_key <- Sys.getenv("SCOPUS_API_KEY", unset = "")
if (nchar(api_key) == 0) {
  api_key <- Sys.getenv("RSCOPUS_KEY", unset = "")
}
if (nchar(api_key) == 0) {
  stop("No Scopus API key found. Set the SCOPUS_API_KEY environment variable.")
}
rscopus::set_api_key(api_key)

# ---- Source the custom Scopus helper functions ----

source("https://raw.githubusercontent.com/pablobernabeu/rscopus_plus/main/scopus_search_DOIs.R")
source("https://raw.githubusercontent.com/pablobernabeu/rscopus_plus/main/scopus_search_additional_DOIs.R")

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

#' Format a citation for embedding in Hugo markdown with DOI angle-bracket link.
format_citation_for_hugo <- function(citation, doi) {
  if (is.null(citation)) return(NULL)

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
  # Escape ampersands (but not inside HTML entities)
  html <- gsub("&(?!amp;|lt;|gt;|quot;)", "&amp;", citation, perl = TRUE)
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
#' file. The block is placed inside the <div class="related-references"> div,
#' before the <div class="hanging-indent">.
write_ref_metadata <- function(index_path, metadata) {
  if (length(metadata) == 0) return(FALSE)

  content <- readLines(index_path, encoding = "UTF-8", warn = FALSE)

  # Remove existing metadata block if present
  start <- grep('<script[^>]*class="ref-metadata"', content)
  if (length(start) > 0) {
    end <- grep("</script>", content)
    end <- end[end > start[1]]
    if (length(end) > 0) {
      content <- content[-(start[1]:end[1])]
    }
  }

  # Find insertion point: right after <div class = 'related-references'>
  related_div <- grep("related-references", content)
  if (length(related_div) == 0) return(FALSE)

  # Convert metadata to compact JSON
  json_text <- jsonlite::toJSON(metadata, auto_unbox = TRUE, pretty = FALSE)

  insert_lines <- c(
    "",
    '<script type="application/json" class="ref-metadata">',
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
#  SCOPUS QUERY JSON BLOCK (embedded for JS viewer)
# ===========================================================================

#' Insert or update the <script class="scopus-queries"> JSON block in the
#' index file, inside the <div class="related-references"> section.
write_scopus_queries <- function(index_path, query, query_source,
                                 search_period, script_path = NULL,
                                 date_collected = Sys.Date()) {
  content <- readLines(index_path, encoding = "UTF-8", warn = FALSE)

  # Remove existing block if present
  start <- grep('<script[^>]*class="scopus-queries"', content)
  if (length(start) > 0) {
    end <- grep("</script>", content)
    end <- end[end > start[1]]
    if (length(end) > 0) {
      content <- content[-(start[1]:end[1])]
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

  # ---- Run Scopus search ----
  timestamp_file <- file.path(refs_dir,
                              "date and time of previous retrieval of DOIs.txt")
  is_first_run <- !file.exists(timestamp_file)

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

  # Pre-write the timestamp and an empty DOI CSV before calling the Scopus API.
  # If the API call crashes (e.g.  rate-limit / transient error), these files
  # will already exist, so the NEXT scheduled run will see is_first_run = FALSE
  # and move on to scopus_search_additional_DOIs instead of retrying the same
  # failing first-run path indefinitely.
  if (is_first_run) {
    tryCatch({
      date_time_pre <- as.character(format(Sys.time(), "%Y-%m-%d %H%M"))
      fileConn <- file(timestamp_file)
      writeLines(date_time_pre, fileConn)
      close(fileConn)
      write.csv(data.frame(x = character(0)),
                file.path(refs_dir, paste0("DOIs, ", date_time_pre, ".csv")),
                row.names = FALSE)
    }, error = function(e) {
      cat("  Warning: could not pre-write timestamp:", e$message, "\n")
    })
  }

  new_dois <- tryCatch({
    refs_path <- paste0(refs_dir, "/")

    if (is_first_run) {
      cat("  First run -> scopus_search_DOIs\n")
      scopus_search_DOIs(
        query = query,
        search_period = paste0(min(search_period), "-", max(search_period)),
        quota = 20,
        path = refs_path, save_date_time_file = TRUE,
        console_print_DOIs = FALSE
      )
      csv_files <- list.files(refs_dir, pattern = "^DOIs,.*\\.csv$",
                              full.names = TRUE)
      if (length(csv_files) > 0) {
        latest <- csv_files[order(file.mtime(csv_files), decreasing = TRUE)[1]]
        d <- read.csv(latest, stringsAsFactors = FALSE)
        if ("x" %in% names(d)) d$x else d[[1]]
      } else character(0)

    } else {
      cat("  Subsequent run -> scopus_search_additional_DOIs\n")
      scopus_search_additional_DOIs(
        query = query,
        search_period = paste0(min(run_period), "-", max(run_period)),
        quota = 20,
        path = refs_path, save_date_time_file = TRUE,
        console_print_DOIs = FALSE
      )
      csv_files <- list.files(refs_dir,
                              pattern = "^additional DOIs,.*\\.csv$",
                              full.names = TRUE)
      if (length(csv_files) > 0) {
        latest <- csv_files[order(file.mtime(csv_files), decreasing = TRUE)[1]]
        d <- read.csv(latest, stringsAsFactors = FALSE)
        if ("x" %in% names(d)) d$x else d[[1]]
      } else character(0)
    }
  }, error = function(e) {
    cat("  Scopus search error:", e$message, "\n")
    character(0)
  })

  if (length(new_dois) == 0) {
    cat("  No DOIs returned from Scopus\n")
    new_dois <- character(0)
  }

  # ---- Deduplicate ----
  # Normalise and deduplicate within the fetched batch first (Scopus can
  # return the same DOI twice in one result set), then remove DOIs already
  # present in the HTML file.
  new_dois <- unique(tolower(trimws(new_dois)))
  new_dois <- new_dois[!new_dois %in% existing_dois]
  cat("  New DOIs to fetch:", length(new_dois), "\n")

  # ---- Fetch APA 7 citations and CrossRef metadata for new DOIs ----
  new_citations <- character(0)
  new_metadata <- list()
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
      next
    }
    # Skip non-paper CrossRef types that lack meaningful citation metadata
    non_paper_types <- c("component", "dataset", "peer-review", "grant",
                         "report-component", "other")
    if (!is.null(meta$type) && tolower(meta$type) %in% non_paper_types) {
      cat("    Skipping: CrossRef type '", meta$type, "' is not a citable paper\n", sep = "")
      next
    }
    # Skip retracted papers
    if (isTRUE(meta$retracted)) {
      cat("    Skipping: paper has been retracted\n")
      next
    }
    # Skip self-citation (DOI matches this publication's own DOI)
    pub_doi <- tolower(trimws(fm$doi %||% ""))
    if (nchar(pub_doi) > 0 && tolower(trimws(doi)) == pub_doi) {
      cat("    Skipping: self-citation\n")
      next
    }
    # Skip future publication years (data entry errors in CrossRef)
    py <- meta$pub_year
    if (length(py) == 1L && !is.na(py) && py > current_year + 1L) {
      cat("    Skipping: publication year", meta$pub_year, "is implausibly far in the future\n")
      next
    }
    cit <- get_apa7_citation(doi)
    if (!is.null(cit) && contains_non_latin_script(cit)) {
      cat("    Skipping: non-Latin script detected in citation\n")
      next
    }
    fmt <- format_citation_for_hugo(cit, doi)
    if (!is.null(fmt)) {
      new_citations <- c(new_citations, fmt)
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
      cat("  Done\n")
    } else {
      cat("  Failed to update related-references.html\n")
    }
  }

  # ---- Backfill metadata for existing DOIs without metadata ----
  # With per-publication parallelism, we can backfill generously —
  # just respect the time budget. The JS UI handles on-demand CrossRef
  # lookups for any DOIs not yet backfilled.
  existing_metadata <- read_ref_metadata(refs_html_path)
  all_dois <- extract_existing_dois(refs_html_path)

  # DOIs completely missing from the metadata block
  dois_missing_meta <- setdiff(all_dois, tolower(names(existing_metadata)))
  # DOIs present in metadata but still lacking an abstract (retry via Scopus)
  dois_missing_abstract <- Filter(
    function(d) is.null(existing_metadata[[d]]$abstract),
    tolower(names(existing_metadata))
  )
  dois_to_backfill <- unique(c(dois_missing_meta, dois_missing_abstract))

  if (length(dois_to_backfill) > 0 && time_remaining() > 60) {
    # Cap by remaining time: ~3s per DOI, leave 60s for file writes
    time_cap <- max(1L, as.integer((time_remaining() - 60) / 3))
    n_to_fill <- min(length(dois_to_backfill), time_cap)
    cat("  Backfilling metadata for", n_to_fill, "of",
        length(dois_to_backfill), "DOIs (",
        length(dois_missing_meta), "new,",
        length(dois_missing_abstract), "missing abstract)\n")
    for (doi in dois_to_backfill[seq_len(n_to_fill)]) {
      if (time_remaining() < 60) {
        cat("  Time budget low (", round(time_remaining()), "s). Stopping backfill.\n")
        break
      }
      meta <- get_crossref_metadata(doi)
      entry <- existing_metadata[[doi]] %||% list()
      if (!is.null(meta$abstract)) entry$abstract <- meta$abstract
      if (!is.null(meta$type)) entry$type <- meta$type
      if (length(entry) > 0) new_metadata[[doi]] <- entry
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
#  LINT EXISTING REFERENCES
#  Re-scan all publication index files for known bad patterns and fix in place.
# ===========================================================================

cat("\n=== Linting existing references ===\n")

lint_files <- list.files("content/publication", pattern = "related-references\\.html$",
                         recursive = TRUE, full.names = TRUE)

for (lf in lint_files) {
  lines <- readLines(lf, encoding = "UTF-8", warn = FALSE)
  changed_lint <- FALSE

  # Strip leading <p> tags to expose raw citation text for author-field checks.
  # All citation lines in related-references.html are wrapped in <p>...</p>.
  inner <- sub("^<p[^>]*>\\s*", "", lines)

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
  keep <- !grepl(",\\s*0\\s*\\(0\\)", lines, perl = TRUE)
  if (any(!keep)) { changed_lint <- TRUE }
  lines  <- lines[keep]
  inner  <- inner[keep]

  # 3. Remove citations with no author: citation text (after <p>) starts with
  #    "(" followed by a year or "N.d." and the line contains a DOI link.
  keep <- !(grepl("^\\s*\\(([0-9]|N\\.d\\.)", inner, perl = TRUE) &
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
  keep <- !(grepl("https://doi.org/", lines, fixed = TRUE) &
              !has_personal_lint & !has_institutional_lint)
  if (any(!keep)) { changed_lint <- TRUE }
  lines  <- lines[keep]
  inner  <- inner[keep]

  # 5. Remove duplicate DOI links within the same file (keep first occurrence).
  #    DOI URLs in HTML appear as href="https://doi.org/..." — exclude quote/angle chars.
  #    Use substr + attr to keep the result aligned with `lines` (regmatches drops
  #    non-matching elements, which would misalign the index).
  m_doi <- regexpr("https://doi\\.org/[^\"<>\\s]+", lines, perl = TRUE)
  doi_hits <- tolower(ifelse(
    m_doi > 0L,
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
