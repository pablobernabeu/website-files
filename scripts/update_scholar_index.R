# Fetch publication titles from a Google Scholar profile and write
# data/scholar_index.json for use by the Hugo template.
#
# Usage (from repo root):
#   Rscript scripts/update_scholar_index.R
#
# If fetching fails the existing data/scholar_index.json is left unchanged.

library(httr)
library(rvest)
library(jsonlite)

SCHOLAR_URL <- "https://scholar.google.com/citations?user=DxD0QDoAAAAJ&pagesize=100&sortby=pubdate"
OUT_FILE    <- "data/scholar_index.json"

# Fetch with a browser-like User-Agent to avoid bot detection
resp <- tryCatch(
  GET(
    SCHOLAR_URL,
    add_headers(
      `User-Agent` = paste0(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ",
        "AppleWebKit/537.36 (KHTML, like Gecko) ",
        "Chrome/124.0.0.0 Safari/537.36"
      ),
      `Accept-Language` = "en-US,en;q=0.9"
    ),
    timeout(20)
  ),
  error = function(e) { message("Network error: ", e$message); NULL }
)

if (is.null(resp) || http_error(resp)) {
  message("Could not fetch Scholar profile. Leaving ", OUT_FILE, " unchanged.")
  quit(save = "no", status = 0)
}

page   <- read_html(content(resp, "text", encoding = "UTF-8"))
titles <- page |>
  html_elements(".gsc_a_at") |>
  html_text(trim = TRUE)

if (length(titles) == 0) {
  message("No titles found in Scholar profile (page structure may have changed).")
  message("Leaving ", OUT_FILE, " unchanged.")
  quit(save = "no", status = 0)
}

# Normalise: lowercase, collapse internal whitespace
normalise <- function(x) tolower(trimws(gsub("\\s+", " ", x)))

result <- list(
  updated   = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  titles    = titles,
  titles_lc = normalise(titles)
)

dir.create("data", showWarnings = FALSE)
write_json(result, OUT_FILE, auto_unbox = TRUE, pretty = TRUE)
cat("Wrote", length(titles), "titles to", OUT_FILE, "\n")
