# collect_related_references.R
#
# Fully automated daily collection of related references for ALL publications.
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
# Usage: Rscript scripts/collect_related_references.R
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

#' Read YAML frontmatter from a markdown / Rmd file.
#' Returns a named list.
read_frontmatter <- function(path) {
  lines <- readLines(path, warn = FALSE)
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

  code <- paste(readLines(script, warn = FALSE), collapse = "\n")

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
  lines <- readLines(script, warn = FALSE)
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

    if (!is.null(citation) && nchar(citation) > 0) return(citation)
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

#' Fetch metadata (abstract, type) from CrossRef API for a single DOI.
#' Falls back to the Scopus Abstract Retrieval API when CrossRef lacks an
#' abstract (many publishers deposit abstracts only in Scopus).
get_crossref_metadata <- function(doi, max_retries = 2) {
  result <- list(abstract = NULL, type = NULL)

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
        list(
          abstract = if (nchar(abstract_clean) > 0) abstract_clean else NULL,
          type = msg$type
        )
      } else {
        list(abstract = NULL, type = NULL)
      }
    }, error = function(e) list(abstract = NULL, type = NULL))

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

  result
}

#' Format a citation for embedding in Hugo markdown with DOI angle-bracket link.
format_citation_for_hugo <- function(citation, doi) {
  if (is.null(citation)) return(NULL)

  doi_url <- paste0("https://doi.org/", doi)

  # Remove trailing DOI URL already appended by CrossRef (various formats)
  esc <- function(x) gsub("([.|()\\^{}+*?\\[\\]\\\\])", "\\\\\\1", x)
  citation <- gsub(paste0("\\s*", esc(doi_url), "\\s*$"), "", citation)
  citation <- gsub(paste0("\\s*", esc(gsub("https://", "http://", doi_url)), "\\s*$"), "", citation)

  citation <- trimws(citation)

  # Strip month/day from parenthetical dates, keeping year only: (2023, March 15) -> (2023)
  citation <- gsub("\\((\\d{4})[a-z]?),\\s*[A-Za-z]+\\.?\\s*\\d{0,2}\\)", "(\\1)", citation)

  citation <- sub("\\.$", "", citation)

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
  content <- readLines(index_path, warn = FALSE)
  # Match markdown: <https://doi.org/...>
  matches1 <- regmatches(content, gregexpr("<https://doi\\.org/([^>]+)>", content))
  # Match HTML: href="https://doi.org/..."
  matches2 <- regmatches(content, gregexpr('href="https?://doi\\.org/([^"]+)"', content))
  dois <- c(unlist(matches1), unlist(matches2))
  dois <- gsub("^<https://doi\\.org/", "", dois)
  dois <- gsub(">$", "", dois)
  dois <- gsub('^href="https?://doi\\.org/', "", dois)
  dois <- gsub('"$', "", dois)
  unique(tolower(trimws(dois)))
}

#' Insert new APA 7 citations into the related-references section of an
#' index file.  Creates the section if it does not exist.
insert_references_into_index <- function(index_path, new_citations) {
  if (length(new_citations) == 0) return(FALSE)

  content <- readLines(index_path, warn = FALSE)
  related_line <- grep("^### Related references", content)

  if (length(related_line) == 0) {
    # No section yet — append one at the end
    new_section <- c(
      "",
      "### Related references",
      "",
      "<div class = 'related-references'>",
      "",
      "<div class = 'hanging-indent'>",
      "",
      paste(new_citations, collapse = "\n\n"),
      "",
      "</div>",
      "",
      "</div>"
    )
    content <- c(content, new_section)
    writeLines(content, index_path)
    return(TRUE)
  }

  # Section exists — insert before the first </div> after the header
  closing_divs <- grep("^</div>", content)
  closing_divs_after <- closing_divs[closing_divs > related_line[1]]

  if (length(closing_divs_after) < 2) {
    message("  Warning: malformed related-references section in ", index_path)
    return(FALSE)
  }

  insert_before <- closing_divs_after[1]

  insert_lines <- character(0)
  for (cit in new_citations) insert_lines <- c(insert_lines, cit, "")

  content <- c(
    content[1:(insert_before - 1)],
    insert_lines,
    content[insert_before:length(content)]
  )

  writeLines(content, index_path)
  TRUE
}

#' Insert new references into a pre-rendered .html counterpart of an Rmd file.
#' Converts markdown citations to HTML <p> tags.
insert_references_into_html <- function(html_path, new_citations) {
  if (length(new_citations) == 0 || is.null(html_path)) return(FALSE)
  if (!file.exists(html_path)) return(FALSE)

  content <- readLines(html_path, warn = FALSE)

  # Find the hanging-indent div inside the related-references section
  hanging_line <- grep('class="hanging-indent"', content)
  if (length(hanging_line) == 0) {
    # No related references section in HTML — append one
    new_section <- c(
      '<div id="related-references" class="section level3">',
      '<h3>Related references</h3>',
      '<div class="related-references">',
      '<div class="hanging-indent">'
    )
    for (cit in new_citations) {
      new_section <- c(new_section, paste0("<p>", citation_md_to_html(cit), "</p>"))
    }
    new_section <- c(new_section, "</div>", "</div>", "</div>")
    content <- c(content, new_section)
    writeLines(content, html_path)
    return(TRUE)
  }

  # Find the closing </div> for hanging-indent (first </div> after hanging_line)
  closing_divs <- grep("^</div>", content)
  closing_divs_after <- closing_divs[closing_divs > hanging_line[1]]
  if (length(closing_divs_after) == 0) return(FALSE)

  insert_before <- closing_divs_after[1]

  insert_lines <- character(0)
  for (cit in new_citations) {
    insert_lines <- c(insert_lines, paste0("<p>", citation_md_to_html(cit), "</p>"))
  }

  content <- c(
    content[1:(insert_before - 1)],
    insert_lines,
    content[insert_before:length(content)]
  )

  writeLines(content, html_path)
  TRUE
}

# ===========================================================================
#  METADATA JSON BLOCK (embedded in index file for JS to read)
# ===========================================================================

#' Read existing ref-metadata JSON from the index file's <script> block.
#' Returns a named list (DOI -> list(abstract, type)).
read_ref_metadata <- function(index_path) {
  content <- readLines(index_path, warn = FALSE)
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

  content <- readLines(index_path, warn = FALSE)

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
  content <- c(
    content[1:insert_at],
    insert_lines,
    content[(insert_at + 1):length(content)]
  )

  writeLines(content, index_path)
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
  content <- readLines(index_path, warn = FALSE)

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
  content <- c(
    content[1:insert_at],
    insert_lines,
    content[(insert_at + 1):length(content)]
  )

  writeLines(content, index_path)
  TRUE
}

# ===========================================================================
#  MAIN
# ===========================================================================

current_year <- as.integer(format(Sys.Date(), "%Y"))
any_changes <- FALSE

# Global time budget: stop adding new work after 45 minutes
# so the remaining time is available for git operations.
run_start_time <- proc.time()[["elapsed"]]
TIME_BUDGET_SECS <- 45 * 60  # 45 minutes

time_remaining <- function() {
  TIME_BUDGET_SECS - (proc.time()[["elapsed"]] - run_start_time)
}

pub_root <- "content/publication"
pub_dirs <- list.dirs(pub_root, recursive = FALSE, full.names = TRUE)
# Exclude hidden or underscore-prefixed entries
pub_dirs <- pub_dirs[!grepl("^[_.]", basename(pub_dirs))]

cat("Found", length(pub_dirs), "publication folders\n")

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
  existing_dois <- extract_existing_dois(index_path)
  cat("  Existing DOIs in index:", length(existing_dois), "\n")

  # ---- Run Scopus search ----
  timestamp_file <- file.path(refs_dir,
                              "date and time of previous retrieval of DOIs.txt")
  is_first_run <- !file.exists(timestamp_file)

  # On subsequent runs, narrow the search period to just the last year of the
  # original period through current_year + 1.  This avoids re-querying
  # historical years that have already been collected and keeps the Scopus
  # API usage efficient.
  run_period <- search_period
  if (!is_first_run) {
    run_start <- max(search_period)
    run_end   <- current_year + 1L
    if (run_start > run_end) run_start <- run_end
    run_period <- run_start:run_end
    cat("  Narrowed run period:", min(run_period), "-", max(run_period), "\n")
  }

  new_dois <- tryCatch({
    refs_path <- paste0(refs_dir, "/")

    if (is_first_run) {
      cat("  First run -> scopus_search_DOIs\n")
      scopus_search_DOIs(
        query = query, search_period = search_period, quota = 20,
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
        query = query, search_period = run_period, quota = 20,
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
  new_dois <- new_dois[!tolower(new_dois) %in% existing_dois]
  cat("  New DOIs to fetch:", length(new_dois), "\n")

  # ---- Fetch APA 7 citations and CrossRef metadata for new DOIs ----
  new_citations <- character(0)
  new_metadata <- list()
  for (doi in new_dois) {
    cat("  Fetching:", doi, "\n")
    cit <- get_apa7_citation(doi)
    fmt <- format_citation_for_hugo(cit, doi)
    if (!is.null(fmt)) {
      new_citations <- c(new_citations, fmt)
    } else {
      cat("    Warning: citation unavailable\n")
    }
    # Fetch metadata (abstract + type) for the JS UI
    meta <- get_crossref_metadata(doi)
    entry <- list()
    if (!is.null(meta$abstract)) entry$abstract <- meta$abstract
    if (!is.null(meta$type)) entry$type <- meta$type
    if (length(entry) > 0) new_metadata[[doi]] <- entry
    Sys.sleep(0.5)
  }

  # ---- Sort & insert new citations ----
  if (length(new_citations) > 0) {
    new_citations <- sort(new_citations)
    cat("  Inserting", length(new_citations), "citations into",
        basename(index_path), "\n")
    if (insert_references_into_index(index_path, new_citations)) {
      any_changes <- TRUE
      cat("  Done\n")

      # Also update the pre-rendered HTML counterpart for Rmd publications
      html_path <- find_html_counterpart(index_path)
      if (!is.null(html_path)) {
        if (insert_references_into_html(html_path, new_citations)) {
          cat("  Also updated", basename(html_path), "\n")
        } else {
          cat("  Warning: could not update HTML counterpart\n")
        }
      }
    } else {
      cat("  Failed to update index file\n")
    }
  }

  # ---- Backfill metadata for existing DOIs without metadata ----
  # Cap at 15 DOIs per publication per run to keep CI runtime under 1 hour.
  # The JS UI handles on-demand CrossRef lookups for any remaining DOIs.
  BACKFILL_CAP <- 15L
  existing_metadata <- read_ref_metadata(index_path)
  all_dois <- extract_existing_dois(index_path)

  # DOIs completely missing from the metadata block
  dois_missing_meta <- setdiff(all_dois, tolower(names(existing_metadata)))
  # DOIs present in metadata but still lacking an abstract (retry via Scopus)
  dois_missing_abstract <- Filter(
    function(d) is.null(existing_metadata[[d]]$abstract),
    tolower(names(existing_metadata))
  )
  dois_to_backfill <- unique(c(dois_missing_meta, dois_missing_abstract))

  if (length(dois_to_backfill) > 0 && time_remaining() > 60) {
    # Further cap by remaining time: ~3s per DOI
    time_cap <- max(1L, as.integer((time_remaining() - 60) / 3))
    n_to_fill <- min(length(dois_to_backfill), BACKFILL_CAP, time_cap)
    cat("  Backfilling metadata for", n_to_fill, "of",
        length(dois_to_backfill), "DOIs (",
        length(dois_missing_meta), "new,",
        length(dois_missing_abstract), "missing abstract)\n")
    for (doi in dois_to_backfill[seq_len(n_to_fill)]) {
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
  html_path <- find_html_counterpart(index_path)
  if (length(new_metadata) > 0) {
    merged_metadata <- modifyList(existing_metadata, new_metadata)
    write_ref_metadata(index_path, merged_metadata)
    any_changes <- TRUE
    cat("  Updated metadata for", length(new_metadata), "DOIs\n")
    if (!is.null(html_path)) {
      existing_html_meta <- read_ref_metadata(html_path)
      merged_html_meta <- modifyList(existing_html_meta, new_metadata)
      write_ref_metadata(html_path, merged_html_meta)
    }
  }

  # Embed Scopus query info for the JS viewer (in both source and HTML)
  # Always link to the general collection script (the per-publication scripts
  # are no longer reflective of the continuous workflow updates).
  sp <- "scripts/collect_related_references.R"
  # Only write if not already present
  existing_content <- readLines(index_path, warn = FALSE)
  if (!any(grepl('class="scopus-queries"', existing_content))) {
    write_scopus_queries(index_path, query, query_source, search_period,
                         script_path = sp)
    any_changes <- TRUE
    cat("  Embedded Scopus query info\n")
  }
  if (!is.null(html_path)) {
    html_content <- readLines(html_path, warn = FALSE)
    if (!any(grepl('class="scopus-queries"', html_content))) {
      write_scopus_queries(html_path, query, query_source, search_period,
                           script_path = sp)
    }
  }
}

cat("\n=== Finished ===\n")
if (any_changes) {
  cat("Changes were made — ready to commit.\n")
} else {
  cat("No changes to commit.\n")
}
