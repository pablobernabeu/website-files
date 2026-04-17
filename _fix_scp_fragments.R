#!/usr/bin/env Rscript
# _fix_scp_fragments.R
#
# Fix fragmented citations in related-references.html files where CrossRef
# returned citations with <scp> small-caps tags that ended up as bare elements
# between <p> tags (instead of inside them).
#
# The problem pattern (plain-MD source, each line wrapped independently):
#   <p>Author, A. (2021). Title comparing</p>
#               <scp>2D</scp>
#   <p>desktop to</p>
#               <scp>3D</scp>
#   <p>rest of citation. <em>Journal</em>. <a href="...doi.org..."></a></p>
#
# The fix merges those fragments into one <p>, stripping <scp> wrapper tags.

strip_scp_tags <- function(s) {
  gsub("</?scp>", "", s, ignore.case = TRUE)
}

is_scp_only_line <- function(s) {
  stripped <- trimws(s)
  grepl("^<scp>[^<]*</scp>$", stripped, ignore.case = TRUE)
}

is_single_line_p <- function(s) {
  stripped <- trimws(s)
  grepl("^<p[> ]", stripped) && grepl("</p>$", stripped)
}

fix_file <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")

  # Find start and end of hanging-indent section
  hi_start <- grep("class\\s*=\\s*['\"]?hanging-indent", lines)
  if (length(hi_start) == 0) {
    cat("  No hanging-indent found, skipping\n")
    return(invisible(NULL))
  }
  hi_start <- hi_start[1]

  # Find the closing </div> for the hanging-indent div
  # Count open/close divs starting from hi_start
  depth <- 0
  hi_end <- NA
  for (i in hi_start:length(lines)) {
    opens  <- nchar(gsub("[^<]", "", lines[i])) - nchar(gsub("<div", "", lines[i], fixed = TRUE))
    closes <- nchar(gsub("[^<]", "", lines[i])) - nchar(gsub("</div>", "", lines[i], fixed = TRUE))
    if (i == hi_start) {
      depth <- depth + opens - closes
    } else {
      depth <- depth + opens - closes
      if (depth <= 0) { hi_end <- i; break }
    }
  }
  if (is.na(hi_end)) hi_end <- length(lines)

  # Extract the content lines (inside the hanging-indent div)
  inner <- lines[(hi_start + 1):(hi_end - 1)]

  # Pass: collect citations, merging groups that have bare <scp> between <p> elements
  result <- character(0)
  pending <- character(0)   # collected lines for current fragment group
  in_group <- FALSE         # are we accumulating a fragment group?

  for (raw_line in inner) {
    stripped <- trimws(raw_line)

    # Blank line
    if (nchar(stripped) == 0) {
      if (!in_group) result <- c(result, raw_line)
      next
    }

    # Bare <scp> line (not inside a <p> — this is the trigger for fragment detection)
    if (is_scp_only_line(stripped) && !grepl("^<p[> ]", stripped)) {
      # Join its text content into the pending group
      text_only <- strip_scp_tags(stripped)
      text_only <- trimws(text_only)
      if (nchar(text_only) > 0) pending <- c(pending, text_only)
      in_group <- TRUE
      next
    }

    # Single-line <p>...</p>
    if (is_single_line_p(stripped)) {
      if (in_group) {
        # This <p> is a continuation of the fragment group — strip p tags and collect
        inner_text <- sub("^<p[^>]*>", "", stripped)
        inner_text <- sub("</p>$", "", inner_text)
        pending <- c(pending, inner_text)

        # Group ends when this <p> contained the doi.org link (= final fragment)
        if (grepl("doi\\.org", stripped, fixed = FALSE)) {
          # Merge group into a single <p>
          merged <- paste(pending, collapse = " ")
          merged <- gsub("\\s+", " ", merged, perl = TRUE)
          merged <- trimws(merged)
          result <- c(result, paste0("<p>", merged, "</p>"))
          pending <- character(0)
          in_group <- FALSE
        }
        # else keep accumulating
      } else {
        # Not in a group — this might start one (if it ends with </p> but has no doi.org)
        # We defer flushing until we know: peek at next non-blank line.
        # Strategy: always start a pending group; flush immediately if next line
        # is a new author-year <p> OR we've consumed everything.
        # Simple approach: push to pending and set in_group
        inner_text <- sub("^<p[^>]*>", "", stripped)
        inner_text <- sub("</p>$", "", inner_text)
        pending <- c(inner_text)

        if (grepl("doi\\.org", stripped, fixed = FALSE)) {
          # Complete citation — flush right away (single-line complete citation)
          result <- c(result, stripped)
          pending <- character(0)
        } else {
          in_group <- TRUE
        }
      }
      next
    }

    # Multi-line <p> start or continuation (from Rmd pandoc output)
    # Pass through these unchanged — they're already correct HTML
    if (in_group) {
      # Shouldn't happen in plain-MD files, but handle defensively
      # Flush current group first (it was a complete citation without doi.org — e.g. a book)
      if (length(pending) > 0) {
        merged <- paste(pending, collapse = " ")
        merged <- gsub("\\s+", " ", merged, perl = TRUE)
        merged <- trimws(merged)
        result <- c(result, paste0("<p>", merged, "</p>"))
        pending <- character(0)
      }
      in_group <- FALSE
    }
    result <- c(result, raw_line)
  }

  # Flush any remaining pending group (e.g. last citation without doi.org)
  if (length(pending) > 0) {
    merged <- paste(pending, collapse = " ")
    merged <- gsub("\\s+", " ", merged, perl = TRUE)
    merged <- trimws(merged)
    result <- c(result, paste0("<p>", merged, "</p>"))
  }

  # Reassemble the file
  fixed_lines <- c(
    lines[1:hi_start],
    result,
    lines[hi_end:length(lines)]
  )
  # Drop any R NA values that may have slipped in
  fixed_lines <- fixed_lines[!is.na(fixed_lines)]

  # Write back
  writeLines(fixed_lines, path, useBytes = FALSE)
  cat("  Fixed:", path, "\n")
  cat("  Lines before:", length(lines), "| after:", length(fixed_lines), "\n")
}

# Only process plain-MD source publications (Rmd ones use multi-line <p> blocks
# which are already correct HTML and must not be touched by this script).
# These are the ones whose related-references.html was migrated from index.md
# line-by-line (each line wrapped in its own <p>).
plain_md_pubs <- c(
  "Bernabeu_Vogt2015",
  "Bernabeu-2017-MPhil-thesis",
  "Bernabeu-2018",
  "Bernabeu-2022-PhD-thesis-Language-sensorimotor-simulation-conceptual-processing",
  "Bernabeu-etal-2017",
  "Bernabeu-Tillman-2019",
  "investigating-object-orientation-effects-across-18-languages"
)

base <- "content/publication"
for (pub in plain_md_pubs) {
  fp <- file.path(base, pub, "related-references.html")
  if (!file.exists(fp)) { cat("MISSING:", fp, "\n"); next }
  cat("\nProcessing:", pub, "\n")
  fix_file(fp)
}

cat("\nDone.\n")
