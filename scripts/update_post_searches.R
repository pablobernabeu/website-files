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
#     Publications that mention lme4::allFit(), from three sources: Scopus (the
#     function name in any indexed field, and a proxy query on titles, abstracts
#     and keywords), Europe PMC (full text, mostly of open-access articles) and
#     OpenAlex (full text).
#
# Results are written under a `searches/` directory in each post bundle. The
# workflow .github/workflows/update-post-searches.yml runs this script, commits
# those directories to the branch it was dispatched from and uploads them as an
# artifact.
#
# Usage:
#   Rscript scripts/update_post_searches.R [all|speculation|allfit]
#
# Environment variables:
#   SCOPUS_API_KEY  Elsevier Scopus API key, read by scopusflow and never
#                   printed. Without it, a `speculation` run stops with an
#                   error. An `all` run warns and skips the speculation
#                   searches. Both `all` and `allfit` runs also skip the two
#                   Scopus searches for allFit but still run those of Europe
#                   PMC and OpenAlex.
#
# A table is written only when its search has finished. The committed file is
# left as it is if the search fails, even part-way through its pages, if a
# Scopus search returns fewer records than Scopus reported for it, if a
# speculation count is missing or if the search returns no rows where the
# committed table has some. The speculation RDS is saved only together with its
# CSV, so that the two always come from the same run.
#
# Each table has a stamp beside it, named after it with _retrieved.txt in place
# of .csv (such as searches/scopus_allfit_any_field_retrieved.txt), which holds
# the time (UTC) at which that table was written. A kept table keeps its old
# stamp, so no stamp dates a table that a run did not refresh. A bundle's
# searches/retrieved.txt holds the stamp of the latest table written to it, and
# its searches/session_info.txt the R session of the latest run that wrote one.
#
# A failed search does not stop the others. The script finishes the rest and
# then exits with an error that names the failed searches, so that the run is
# marked as failed while the tables that were written are still committed.

suppressPackageStartupMessages({
  library(scopusflow)
  library(httr2)
  library(jsonlite)
})

target <- commandArgs(trailingOnly = TRUE)
target <- if (length(target) == 0 || !nzchar(target[1])) "all" else target[1]
stopifnot(target %in% c("all", "speculation", "allfit"))

speculation_dir <- file.path(
  "content/post/speculation-across-various-scientific-topics", "searches"
)
allfit_dir <- file.path(
  "content/post",
  "2023-07-08-who-s-through-with-convergence-warnings-a-record-of-publications-using",
  "searches"
)

# The speculation searches alone make several hundred requests, so each stamp
# is taken when its table is written, not when the script starts.
utc_now <- function() format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC")

# Tracks which search directories received a table in this run, so that a
# bundle's session record is written only where one of its own searches wrote
# a table.
written_to <- character(0)

# Searches that failed or were rejected, reported together at the end.
failed <- character(0)

fail <- function(label, ...) {
  warning(..., call. = FALSE, immediate. = TRUE)
  failed <<- union(failed, label)
  invisible(FALSE)
}

# A failure in one search must not lose the others, so each search catches its
# own error, reports it and returns NULL.
try_search <- function(label, expr) {
  tryCatch(expr, error = function(e) {
    message("Search failed (", label, "): ", conditionMessage(e))
    failed <<- union(failed, label)
    NULL
  })
}

# An empty result far more often means an outage, a revoked key or a changed API
# than a literature that has emptied, and the workflow commits whatever is on
# disk, so an empty table never replaces an existing file that holds rows.
write_table <- function(x, path, retrieved = utc_now()) {
  x <- as.data.frame(x)
  if (nrow(x) == 0 && file.exists(path) &&
      nrow(utils::read.csv(path, nrows = 1)) > 0) {
    warning("Search for ", basename(path), " returned no rows; ",
            "keeping the committed file.", call. = FALSE, immediate. = TRUE)
    return(invisible(FALSE))
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(x, path, row.names = FALSE, fileEncoding = "UTF-8")
  writeLines(retrieved, sub("\\.csv$", "_retrieved.txt", path))
  writeLines(retrieved, file.path(dirname(path), "retrieved.txt"))
  message("Wrote ", path, " (", nrow(x), " rows)")
  written_to <<- union(written_to, normalizePath(dirname(path)))
  invisible(TRUE)
}

# scopusflow's offset paging ends without an error when Scopus serves an empty
# or short page, so a search cut short can look finished. Its records are
# therefore compared with the total that Scopus reported for the query, up to
# the most that offset paging can return.
scopus_complete <- function(records, label) {
  total <- attr(records, "total_results")
  cap <- getOption("scopusflow.hard_cap", 5000L)
  if (length(total) != 1 || is.na(total) || nrow(records) >= min(total, cap))
    return(TRUE)
  fail(label, "The ", label, " search returned ", nrow(records), " of the ",
       total, " records Scopus reported for it; keeping the committed file.")
}

# ---- Speculation across topics ------------------------------------------------

# Only a `speculation` run stops without a key. An `all` run skips these
# searches with a warning, because stopping here would also prevent the
# keyless Europe PMC and OpenAlex searches further down.
run_speculation <- target %in% c("all", "speculation")
if (run_speculation && !scopus_has_key()) {
  if (target == "speculation") stop("No Scopus API key found in SCOPUS_API_KEY.")
  warning("No Scopus API key found in SCOPUS_API_KEY; ",
          "skipping the speculation searches.", call. = FALSE, immediate. = TRUE)
  run_speculation <- FALSE
}

if (run_speculation) {
  # The current year is included so that the plots reach the latest records,
  # and the post notes that this final year is incomplete.
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

  # The nine literatures make up one table and one figure, so a failure in any
  # of them keeps the committed files for all nine.
  comparisons <- try_search("speculation", {
    cmp_list <- lapply(names(topics), function(label) {
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
    names(cmp_list) <- names(topics)
    cmp_list
  })

  if (!is.null(comparisons)) {
    speculation_table <- do.call(rbind, lapply(comparisons, as.data.frame))
    speculation_csv <- file.path(speculation_dir, "speculation_comparisons.csv")
    # scopusflow returns NA for a year whose response lacked
    # opensearch:totalResults. Such a year would drop out of the plots without
    # notice, so the whole run is set aside instead.
    if (anyNA(speculation_table$n) || anyNA(speculation_table$reference_n)) {
      fail("speculation", "Some speculation counts are missing; keeping ",
           "speculation_comparisons.csv and .rds as they are.")
    } else {
      retrieved <- utc_now()
      attr(comparisons, "retrieved") <- retrieved
      # The post reads the RDS, and the CSV holds the same data. The RDS is
      # saved only if write_table() wrote the CSV, so that a kept CSV never
      # sits beside an RDS from a different run.
      if (write_table(speculation_table, speculation_csv, retrieved))
        saveRDS(comparisons, file.path(speculation_dir, "speculation_comparisons.rds"))
    }
  }
  if (!normalizePath(speculation_dir, mustWork = FALSE) %in% written_to)
    warning("No search wrote to ", speculation_dir, "; leaving its retrieved.txt as it is.",
            call. = FALSE, immediate. = TRUE)
}

# ---- Publications that used allFit ---------------------------------------------

if (target %in% c("all", "allfit")) {
  # Europe PMC and OpenAlex need no key, so a missing key skips only the two
  # Scopus searches and the rest of the bundle still runs.
  have_key <- scopus_has_key()
  if (!have_key)
    warning("No Scopus API key found in SCOPUS_API_KEY; ",
            "running the Europe PMC and OpenAlex searches only.",
            call. = FALSE, immediate. = TRUE)
  dir.create(allfit_dir, recursive = TRUE, showWarnings = FALSE)

  # A paging loop yields NULL whether it ends with `break` or try_search()
  # catches an error part-way, so this wrapper returns TRUE only if the loop
  # ran to its end. The pages gathered before a failure are then never
  # written over a complete committed table.
  paging_finished <- function(label, expr) {
    !is.null(try_search(label, {
      expr
      TRUE
    }))
  }

  # 1. Scopus: the function name in any indexed field (title, abstract,
  #    keywords, references and others, but not the body of the article). If
  #    Scopus rejects the quoted ALL() query as malformed (HTTP 400, which
  #    scopusflow signals as scopus_error_bad_request), the unquoted form is
  #    tried, and then a narrower search of titles, abstracts, keywords and
  #    references only. Any other error, such as a rate limit, a server error,
  #    a lost connection or a spent quota, says nothing about the query, and
  #    the narrower search would then replace the table the post describes as
  #    any indexed field, so the search stops there and the committed file is
  #    kept. Pages of 25 records are the most the API serves to a key used
  #    outside its institution's network, and larger pages are rejected as
  #    malformed.
  records_all <- NULL
  q_all <- NA_character_
  if (have_key) {
    for (q in c('ALL("allFit")', 'ALL(allFit)', 'TITLE-ABS-KEY(allFit) OR REF(allFit)')) {
      result <- try_search("Scopus any field", tryCatch(
        scopus_fetch(q, page_size = 25),
        scopus_error_bad_request = function(e) e
      ))
      if (inherits(result, "scopus_error_bad_request")) {
        message("Scopus rejected the query ", q, ": ", conditionMessage(result))
        next
      }
      records_all <- result
      q_all <- q
      break
    }
    if (is.na(q_all))
      fail("Scopus any field", "Scopus rejected every form of the any-field ",
           "query; keeping scopus_allfit_any_field.csv as it is.")
  }
  # Each query file describes the table saved beside it, so it is written only
  # when that table is. Otherwise a kept table could sit beside the query of a
  # search that returned nothing, such as a fallback form of this one.
  if (!is.null(records_all) &&
      scopus_complete(records_all, "Scopus any field") &&
      write_table(records_all, file.path(allfit_dir, "scopus_allfit_any_field.csv")))
    writeLines(q_all, file.path(allfit_dir, "scopus_allfit_any_field_query.txt"))

  # 2. Scopus: a proxy query for titles, abstracts and keywords that describe
  #    maximal random-effects structures and convergence, since studies that
  #    compared optimisers seldom name the function in a field Scopus indexes.
  q_proxy <- paste(
    '("lme4" OR "lmerTest" OR "brms") AND maximal AND "random slopes"',
    'AND (convergence OR converge OR converged OR converging)'
  )
  records_proxy <- if (!have_key) NULL else try_search("Scopus proxy",
                              scopus_fetch(q_proxy, field = "TITLE-ABS-KEY", page_size = 25))
  if (!is.null(records_proxy) &&
      scopus_complete(records_proxy, "Scopus proxy") &&
      write_table(records_proxy, file.path(allfit_dir, "scopus_convergence_proxy.csv")))
    writeLines(q_proxy, file.path(allfit_dir, "scopus_convergence_proxy_query.txt"))

  # 3. Europe PMC: full text, held mostly for open-access articles. The
  #    function name must occur in the article together with a mixed-model
  #    term, which excludes some unrelated uses of the string. A page size of
  #    1000 is the largest the API accepts.
  epmc_query <- paste(
    '"allFit" AND (lme4 OR "mixed-effects" OR "mixed effects" OR',
    '"mixed model" OR "mixed models" OR "multilevel")'
  )
  epmc <- list()
  cursor <- "*"
  epmc_finished <- paging_finished("Europe PMC", repeat {
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
  # Absent JSON fields arrive as NULL, which vapply() cannot hold, so they
  # become NA.
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
  if (!epmc_finished)
    warning("The Europe PMC search did not finish; leaving ",
            "europepmc_allfit_fulltext.csv as it is.", call. = FALSE, immediate. = TRUE)
  else if (write_table(epmc_table, file.path(allfit_dir, "europepmc_allfit_fulltext.csv")))
    writeLines(epmc_query, file.path(allfit_dir, "europepmc_query.txt"))

  # 4. OpenAlex: full-text search over the works whose text OpenAlex holds.
  #    On its own, the function name also matches unrelated text (the search
  #    ignores case and tolerates near matches), so a mixed-model term is
  #    required alongside it. Pages of 200 records are the largest it accepts.
  openalex_filter <- paste0('fulltext.search:allFit AND (lme4 OR lmer OR ',
                            '"mixed effects" OR "mixed-effects" OR "mixed model" OR ',
                            '"mixed models" OR multilevel)')
  oa <- list()
  cursor <- "*"
  oa_finished <- paging_finished("OpenAlex", repeat {
    resp <- request("https://api.openalex.org/works") |>
      req_url_query(
        filter = openalex_filter,
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
  if (!oa_finished)
    warning("The OpenAlex search did not finish; leaving ",
            "openalex_allfit_fulltext.csv as it is.", call. = FALSE, immediate. = TRUE)
  else if (write_table(oa_table, file.path(allfit_dir, "openalex_allfit_fulltext.csv")))
    writeLines(openalex_filter, file.path(allfit_dir, "openalex_filter.txt"))

  if (!normalizePath(allfit_dir, mustWork = FALSE) %in% written_to)
    warning("No search wrote to ", allfit_dir, "; leaving its retrieved.txt as it is.",
            call. = FALSE, immediate. = TRUE)
}

# The package versions behind a table can change between runs, so each bundle
# that received a table records the session that wrote it.
for (dir in written_to)
  writeLines(utils::capture.output(utils::sessionInfo()), file.path(dir, "session_info.txt"))

if (length(failed) > 0)
  stop("These searches did not finish, and their committed files were kept: ",
       paste(failed, collapse = ", "), ".", call. = FALSE)

message("Done.")
