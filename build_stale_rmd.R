# Build any Rmd files whose source has changed since their HTML output was built.
# Mirrors the "Check for stale Rmd → HTML pages" step in .github/workflows/deploy.yml.
#
# Usage (from repo root):
#   Rscript build_stale_rmd.R               # one-shot
#   Rscript build_stale_rmd.R --dry-run     # just print what would be built
#   Rscript build_stale_rmd.R --watch       # poll every 15 s and rebuild on change
#   Rscript build_stale_rmd.R --watch --interval=30  # custom poll interval (seconds)

# Allow args to be injected before sourcing (e.g. from a job launcher)
if (!exists(".cli_args")) .cli_args <- commandArgs(trailingOnly = TRUE)
dry_run  <- "--dry-run" %in% .cli_args
watch    <- "--watch"   %in% .cli_args

interval <- 15L
interval_arg <- grep("^--interval=", .cli_args, value = TRUE)
if (length(interval_arg)) {
  interval <- as.integer(sub("^--interval=", "", interval_arg))
  if (is.na(interval) || interval < 1L) interval <- 15L
}

find_stale <- function() {
  rmds  <- list.files("content", pattern = "\\.Rmd$", recursive = TRUE, full.names = TRUE)
  stale <- character(0)
  for (rmd in rmds) {
    html <- sub("\\.Rmd$", ".html", rmd)
    if (!file.exists(html) || is_stale_in_git(rmd, html)) {
      stale <- c(stale, rmd)
    }
  }
  stale
}

# Modification times cannot answer this question: a fresh clone stamps every file
# with the checkout time, so an Rmd edited two years after its HTML looks current.
# Ask Git which commit last touched each file instead, and treat the Rmd as stale
# when its commit is not an ancestor of the HTML's. This mirrors the check in
# .github/workflows/deploy.yml.
last_commit <- function(path) {
  out <- suppressWarnings(
    system2("git", c("log", "-1", "--format=%H", "--", shQuote(path)),
            stdout = TRUE, stderr = FALSE)
  )
  if (length(out) == 0) "" else out[1]
}

is_stale_in_git <- function(rmd, html) {
  rmd_commit  <- last_commit(rmd)
  html_commit <- last_commit(html)
  # Uncommitted files have no history to compare, so fall back to modification
  # times, which are meaningful for a file the user has just edited.
  if (!nzchar(rmd_commit) || !nzchar(html_commit)) {
    return(file.mtime(rmd) > file.mtime(html))
  }
  status <- system2("git", c("merge-base", "--is-ancestor", rmd_commit, html_commit),
                    stdout = FALSE, stderr = FALSE)
  status != 0L
}

build_stale <- function(stale) {
  for (rmd in stale) {
    cat("\nRebuilding:", rmd, "\n")
    blogdown::build_site(build_rmd = rmd)
  }
}

if (!watch) {
  # ── One-shot mode ────────────────────────────────────────────────────────────
  stale <- find_stale()
  if (length(stale) == 0) {
    cat("All HTML pages are up to date.\n")
  } else {
    cat("Stale Rmd files found:\n")
    cat(paste0("  ", stale, "\n"), sep = "")
    if (!dry_run) build_stale(stale)
    else cat("Dry run — not building.\n")
  }
} else {
  # ── Watch mode ───────────────────────────────────────────────────────────────
  cat(sprintf("Watching for Rmd changes every %d s. Press Ctrl+C to stop.\n", interval))

  # Snapshot mtimes at startup — only rebuild files edited after this point
  all_rmds   <- list.files("content", pattern = "\\.Rmd$", recursive = TRUE, full.names = TRUE)
  last_mtime <- setNames(file.mtime(all_rmds), all_rmds)

  repeat {
    Sys.sleep(interval)

    all_rmds    <- list.files("content", pattern = "\\.Rmd$", recursive = TRUE, full.names = TRUE)
    cur_mtime   <- setNames(file.mtime(all_rmds), all_rmds)

    # Files that are new or whose mtime increased since last check
    changed <- all_rmds[vapply(all_rmds, function(f) {
      is.na(last_mtime[f]) || cur_mtime[f] > last_mtime[f]
    }, logical(1))]

    last_mtime <- cur_mtime

    if (length(changed)) {
      cat(format(Sys.time(), "[%H:%M:%S]"), "Changed:\n")
      cat(paste0("  ", changed, "\n"), sep = "")
      build_stale(changed)
    }
  }
}
