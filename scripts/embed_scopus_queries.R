# One-time script: embed Scopus query info from existing R scripts into
# the index files so the JS "View Scopus searches" button works immediately.
#
# This reads query + search_period from each publication's
# `related references/related references.R` file and writes a
# <script class="scopus-queries"> JSON block into the index file.

library(jsonlite)

# --- Helper functions (same as in collect_related_references.R) ---

find_index_file <- function(pub_dir) {
  candidates <- c(
    file.path(pub_dir, "index.md"),
    file.path(pub_dir, "index.Rmd"),
    file.path(pub_dir, "index.en.md"),
    file.path(pub_dir, "index.en.Rmd")
  )
  found <- candidates[file.exists(candidates)]
  if (length(found) > 0) return(found[1])
  NULL
}

find_refs_dir <- function(pub_dir) {
  candidates <- c(
    file.path(pub_dir, "related references"),
    file.path(pub_dir, "related-references")
  )
  found <- candidates[dir.exists(candidates)]
  if (length(found) > 0) return(found[1])
  NULL
}

find_html_counterpart <- function(index_path) {
  if (!grepl("\\.(Rmd|rmd)$", index_path)) return(NULL)
  html_path <- sub("\\.(Rmd|rmd)$", ".html", index_path)
  if (file.exists(html_path)) return(html_path)
  NULL
}

extract_query_from_script <- function(refs_dir) {
  if (is.null(refs_dir)) return(NULL)
  script <- file.path(refs_dir, "related references.R")
  if (!file.exists(script)) return(NULL)
  code <- paste(readLines(script, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  env <- new.env(parent = baseenv())
  tryCatch({
    m <- regmatches(code, regexpr("query\\s*=\\s*paste\\((.|\n)*?\\)\n", code, perl = TRUE))
    if (length(m) == 0) return(NULL)
    eval(parse(text = m), envir = env)
    return(env$query)
  }, error = function(e) NULL)
}

extract_period_from_script <- function(refs_dir) {
  if (is.null(refs_dir)) return(NULL)
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

write_scopus_queries <- function(index_path, query, search_period, script_path) {
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

  # Find insertion point: right after <div class='related-references'>
  # (or class="related-references" for HTML files)
  related_div <- grep("related-references", content)
  if (length(related_div) == 0) return(FALSE)

  period_str <- if (!is.null(search_period)) {
    # search_period can be '2017-2023' (string) or 2022:2023 (integer vector)
    if (is.character(search_period) && grepl("-", search_period)) {
      # Already a formatted string like "2017-2023"
      search_period
    } else {
      sp <- as.integer(search_period)
      paste0(min(sp), "-", max(sp))
    }
  } else {
    "unknown"
  }

  info <- list(
    source  = "script",
    query   = query,
    period  = period_str,
    scriptPath = script_path
  )
  json_text <- toJSON(info, auto_unbox = TRUE, pretty = FALSE)

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

  writeLines(content, index_path, useBytes = TRUE)
  TRUE
}

# --- Main ---

pub_root <- "content/publication"
pub_dirs <- list.dirs(pub_root, recursive = FALSE, full.names = TRUE)
pub_dirs <- pub_dirs[!grepl("^[_.]", basename(pub_dirs))]

changes <- 0

for (pub_dir in pub_dirs) {
  pub_name <- basename(pub_dir)
  refs_dir <- find_refs_dir(pub_dir)
  if (is.null(refs_dir)) next

  query <- extract_query_from_script(refs_dir)
  if (is.null(query)) next

  search_period <- extract_period_from_script(refs_dir)

  index_path <- find_index_file(pub_dir)
  if (is.null(index_path)) next

  # Only embed if the file has a related-references section
  content <- readLines(index_path, encoding = "UTF-8", warn = FALSE)
  if (!any(grepl("related-references", content))) next

  # Path to the R script (relative to repo root, with forward slashes)
  script_file <- file.path(refs_dir, "related references.R")
  script_path <- gsub("\\\\", "/", script_file)

  cat("Embedding query for:", pub_name, "\n")
  if (write_scopus_queries(index_path, query, search_period, script_path)) {
    changes <- changes + 1
    cat("  -> Updated", basename(index_path), "\n")

    # Also update HTML counterpart for Rmd publications
    html_path <- find_html_counterpart(index_path)
    if (!is.null(html_path)) {
      html_content <- readLines(html_path, encoding = "UTF-8", warn = FALSE)
      if (any(grepl("related-references", html_content))) {
        if (write_scopus_queries(html_path, query, search_period, script_path)) {
          cat("  -> Updated", basename(html_path), "\n")
        }
      }
    }
  }
}

cat("\nDone. Updated", changes, "publication(s).\n")
