# update_post_searches.R
#
# Re-runs the bibliographic searches behind two posts, so that their figures and
# tables can be rebuilt from fresh counts:
#
#   content/post/speculation-across-various-scientific-topics
#     Yearly share of records mentioning speculation within nine reference
#     literatures (Scopus, through scopusflow::scopus_compare_topics()).
#
#   content/post/2023-07-08-who-s-through-with-convergence-warnings-a-record-of-publications-using
#     Publications that used lme4::allFit(), from three sources: Scopus (the
#     function name in any indexed field, and a proxy query on the abstract),
#     Europe PMC (full text of open-access articles) and OpenAlex (full text).
#
# Results are written under a `searches/` directory in each post bundle. The
# workflow .github/workflows/update-post-searches.yml runs this script and
# uploads those directories as an artifact.
#
# Usage:
#   Rscript scripts/update_post_searches.R [all|speculation|allfit]
#
# Environment variables:
#   SCOPUS_API_KEY  Elsevier Scopus API key (read by scopusflow; never printed)
#
# Each run writes the retrieval date to searches/retrieved.txt in both bundles.

suppressPackageStartupMessages({
  library(scopusflow)
  library(httr2)
  library(jsonlite)
})

target <- commandArgs(trailingOnly = TRUE)
target <- if (length(target) == 0 || !nzchar(target[1])) "all" else target[1]
stopifnot(target %in% c("all", "speculation", "allfit"))

retrieved <- format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC")

speculation_dir <- file.path(
  "content/post/speculation-across-various-scientific-topics", "searches"
)
allfit_dir <- file.path(
  "content/post",
  "2023-07-08-who-s-through-with-convergence-warnings-a-record-of-publications-using",
  "searches"
)

# Records whether anything was actually retrieved in this run, so that the
# retrieval timestamps are only refreshed when there is new data behind them.
wrote_anything <- FALSE

# An empty result is far more often an outage, a revoked key or a changed API
# than a literature that has emptied, and the workflow commits whatever is on
# disk, so an empty table never replaces committed results.
write_table <- function(x, path) {
  x <- as.data.frame(x)
  if (nrow(x) == 0 && file.exists(path) &&
      nrow(utils::read.csv(path, nrows = 1)) > 0) {
    warning("Search for ", basename(path), " returned no rows; ",
            "keeping the committed file.", call. = FALSE, immediate. = TRUE)
    return(invisible(FALSE))
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(x, path, row.names = FALSE, fileEncoding = "UTF-8")
  message("Wrote ", path, " (", nrow(x), " rows)")
  wrote_anything <<- TRUE
  invisible(TRUE)
}

# ---- Speculation across topics ------------------------------------------------

if (target %in% c("all", "speculation")) {
  if (!scopus_has_key()) stop("No Scopus API key found in SCOPUS_API_KEY.")

  # The current year is included so that the plots run up to the latest
  # records; the post notes that the last year is incomplete.
  years <- 1980:as.integer(format(Sys.Date(), "%Y"))

  topics <- c(
    "language evolution"              = '"language evolution" OR "evolution of language"',
    "language comprehension"          = '"language comprehension"',
    "language disorders"              = '"language disorders" OR "language disorder"',
    "linguistic relativity"           = '"linguistic relativity"',
    "language teaching"               = '"language teaching"',
    "bilingual advantage"             = '"bilingual advantage" OR "bilingual advantages"',
    "sensorimotor simulation"         = '"sensorimotor simulation"',
    "artificial general intelligence" = '"artificial general intelligence"',
    "hadron collider"                 = '"hadron collider"'
  )

  comparisons <- lapply(names(topics), function(label) {
    message("Speculation within: ", label)
    cmp <- scopus_compare_topics(
      reference_query  = topics[[label]],
      comparison_terms = "speculat*",
      years            = years,
      field            = "TITLE-ABS-KEY"
    )
    cmp$topic <- label
    cmp
  })
  names(comparisons) <- names(topics)
  attr(comparisons, "retrieved") <- retrieved

  dir.create(speculation_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(comparisons, file.path(speculation_dir, "speculation_comparisons.rds"))
  write_table(do.call(rbind, lapply(comparisons, as.data.frame)),
              file.path(speculation_dir, "speculation_comparisons.csv"))
  if (wrote_anything) writeLines(retrieved, file.path(speculation_dir, "retrieved.txt")) else
    warning("No search produced rows; leaving retrieved.txt as it is.",
            call. = FALSE, immediate. = TRUE)
}

# ---- Publications that used allFit ---------------------------------------------

if (target %in% c("all", "allfit")) {
  if (!scopus_has_key()) stop("No Scopus API key found in SCOPUS_API_KEY.")
  dir.create(allfit_dir, recursive = TRUE, showWarnings = FALSE)

  # A failure in one source must not lose the others, so each search is
  # wrapped and reported. `try_search()` returns NULL on failure.
  try_search <- function(label, expr) {
    tryCatch(expr, error = function(e) {
      message("Search failed (", label, "): ", conditionMessage(e))
      NULL
    })
  }

  # 1. Scopus: the function name in any indexed field (title, abstract,
  #    keywords, references and so on; not the body of the article). The
  #    ALL() field tag is tried first, with two fallbacks. Pages of 25 records
  #    are the most the API serves to a key used outside its institution's
  #    network; larger pages are rejected as malformed.
  records_all <- NULL
  for (q_all in c('ALL("allFit")', 'ALL(allFit)',
                  'TITLE-ABS-KEY(allFit) OR REF(allFit)')) {
    records_all <- try_search(q_all, scopus_fetch(q_all, page_size = 25))
    if (!is.null(records_all)) {
      attr(records_all, "query_used") <- q_all
      break
    }
  }
  if (!is.null(records_all)) {
    write_table(records_all, file.path(allfit_dir, "scopus_allfit_any_field.csv"))
    writeLines(q_all, file.path(allfit_dir, "scopus_allfit_any_field_query.txt"))
  }

  # 2. Scopus: the proxy query drafted in 2023, which targets abstracts that
  #    describe maximal random-effects structures and convergence.
  q_proxy <- paste(
    '("lme4" OR "lmerTest" OR "brms") AND maximal AND "random slopes"',
    'AND (convergence OR converge OR converged OR converging)'
  )
  records_proxy <- try_search("proxy",
                              scopus_fetch(q_proxy, field = "TITLE-ABS-KEY", page_size = 25))
  if (!is.null(records_proxy)) {
    write_table(records_proxy, file.path(allfit_dir, "scopus_convergence_proxy.csv"))
  }

  # 3. Europe PMC: full text of open-access articles. The phrase must occur in
  #    the article together with a mixed-model term, which excludes unrelated
  #    uses of the string.
  epmc_query <- paste(
    '"allFit" AND (lme4 OR "mixed-effects" OR "mixed effects" OR',
    '"mixed model" OR "mixed models" OR "multilevel")'
  )
  epmc <- list()
  cursor <- "*"
  try_search("Europe PMC", repeat {
    resp <- request("https://www.ebi.ac.uk/europepmc/webservices/rest/search") |>
      req_url_query(query = epmc_query, format = "json", pageSize = 1000,
                    cursorMark = cursor, resultType = "lite") |>
      req_user_agent("pablobernabeu.github.io post searches") |>
      req_retry(max_tries = 4) |>
      req_perform() |>
      resp_body_json()
    hits <- resp$resultList$result
    if (length(hits) == 0) break
    epmc <- c(epmc, hits)
    nxt <- resp$nextCursorMark
    if (is.null(nxt) || identical(nxt, cursor)) break
    cursor <- nxt
  })
  pick <- function(x, field) {
    v <- x[[field]]
    if (is.null(v)) NA_character_ else as.character(v)
  }
  epmc_table <- data.frame(
    id            = vapply(epmc, pick, character(1), "id"),
    source        = vapply(epmc, pick, character(1), "source"),
    doi           = vapply(epmc, pick, character(1), "doi"),
    title         = vapply(epmc, pick, character(1), "title"),
    authors       = vapply(epmc, pick, character(1), "authorString"),
    year          = vapply(epmc, pick, character(1), "pubYear"),
    journal       = vapply(epmc, pick, character(1), "journalTitle"),
    is_open_access = vapply(epmc, pick, character(1), "isOpenAccess"),
    stringsAsFactors = FALSE
  )
  write_table(epmc_table, file.path(allfit_dir, "europepmc_allfit_fulltext.csv"))

  # 4. OpenAlex: full-text search, where the text is available to OpenAlex.
  #    On its own, the function name also matches unrelated text (the search
  #    is not case-sensitive and tolerates near matches), so a mixed-model
  #    term is required alongside it.
  oa <- list()
  cursor <- "*"
  try_search("OpenAlex", repeat {
    resp <- request("https://api.openalex.org/works") |>
      req_url_query(
        filter = paste0('fulltext.search:allFit AND (lme4 OR lmer OR ',
                        '"mixed effects" OR "mixed-effects" OR "mixed model" OR ',
                        '"mixed models" OR multilevel)'),
        `per-page` = 200, cursor = cursor,
        select = "id,doi,title,publication_year,authorships,primary_location",
        mailto = "pcbernabeu@gmail.com"
      ) |>
      req_user_agent("pablobernabeu.github.io post searches") |>
      req_retry(max_tries = 4) |>
      req_perform() |>
      resp_body_json()
    hits <- resp$results
    if (length(hits) == 0) break
    oa <- c(oa, hits)
    nxt <- resp$meta$next_cursor
    if (is.null(nxt)) break
    cursor <- nxt
  })
  oa_table <- data.frame(
    id      = vapply(oa, pick, character(1), "id"),
    doi     = vapply(oa, pick, character(1), "doi"),
    title   = vapply(oa, pick, character(1), "title"),
    year    = vapply(oa, pick, character(1), "publication_year"),
    authors = vapply(oa, function(x) {
      a <- x$authorships
      if (length(a) == 0) return(NA_character_)
      paste(vapply(a, function(z) pick(z$author, "display_name"), character(1)),
            collapse = "; ")
    }, character(1)),
    journal = vapply(oa, function(x) {
      s <- x$primary_location$source
      if (is.null(s)) NA_character_ else pick(s, "display_name")
    }, character(1)),
    stringsAsFactors = FALSE
  )
  write_table(oa_table, file.path(allfit_dir, "openalex_allfit_fulltext.csv"))

  if (wrote_anything) writeLines(retrieved, file.path(allfit_dir, "retrieved.txt")) else
    warning("No search produced rows; leaving retrieved.txt as it is.",
            call. = FALSE, immediate. = TRUE)
}

message("Done.")
