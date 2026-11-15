# Executes one agent's analysis.R in a fresh R process started by the running
# R installation, inside a fresh copy of its directory that holds only the
# script and the data file the agent saw. It returns the printed RESULT line,
# the exit status and a SHA-256 hash of the full output (stdout and stderr).
# The hash is taken over the lines as readLines() returns them, joined by '\n'
# with no final newline, so it does not depend on the line endings a platform
# writes, and it differs from a checksum of the output file. The child runs in the
# C locale, because the locale changes some printed characters (the quotation
# marks in lmerTest's significance codes, for one) and so the bytes of the
# output. It loads no R profile either, since a project profile can reset the
# locale (renv's does, on Windows) and the library paths. execute_scripts.R,
# verify_executions.R, check_versions.R, rerun/execute_rerun.R and the post all
# use it.

child_env <- c(callr::rcmd_safe_env(), LC_ALL = 'C', LANG = 'C', LANGUAGE = 'en')

# run_id names the script's folder under runs/, data_file the data set in
# experiment_dir that is copied in as data.csv, and label keeps apart the work
# folders of repeated executions. libpath chooses the package library of the
# child process, and output_copy, if given, is where to keep the full output.
# A script still running after timeout seconds stops the execution with an
# error. Ten minutes, about seven times the slowest recorded execution (86 s,
# in version_check.csv), is taken to mean that it hangs.
# Returns one row (run_id, seconds, status, result, stdout_sha256), and deletes
# and recreates the folder tempdir()/<run_id>_<label>.
run_script <- function(run_id, data_file, experiment_dir = '.', label = 1L,
                       libpath = .libPaths(), output_copy = NULL, timeout = 600) {
  work <- file.path(tempdir(), sprintf('%s_%s', run_id, label))
  unlink(work, recursive = TRUE)
  dir.create(work)
  stopifnot(file.copy(file.path(experiment_dir, data_file), file.path(work, 'data.csv')),
            file.copy(file.path(experiment_dir, 'runs', run_id, 'analysis.R'), work))
  output_file <- file.path(work, 'output.txt')
  started <- Sys.time()
  execution <- callr::rscript('analysis.R', wd = work, stdout = output_file, stderr = '2>&1',
                              libpath = libpath, env = child_env, user_profile = FALSE,
                              fail_on_status = FALSE, show = FALSE, timeout = timeout)
  if (isTRUE(execution$timeout)) stop(run_id, ' was still running after ', timeout, ' seconds')
  status <- execution$status
  output <- readLines(output_file, warn = FALSE)
  if (!is.null(output_copy)) stopifnot(file.copy(output_file, output_copy, overwrite = TRUE))
  data.frame(
    run_id,
    seconds = round(as.numeric(difftime(Sys.time(), started, units = 'secs')), 1),
    status,
    result = tail(c(NA, grep('^RESULT ', output, value = TRUE)), 1),
    stdout_sha256 = digest::digest(paste(output, collapse = '\n'), algo = 'sha256',
                                   serialize = FALSE)
  )
}

# Executes a script with run_script() and, if its R process crashes (any exit
# status other than 0, or 1 for an R error), executes it again, up to three
# times in all. On Windows the child process occasionally ends with an access
# violation that a second attempt does not repeat. One row per attempt.
run_script_with_retries <- function(..., label = 1L, attempts = 3L) {
  rows <- list()
  repeat {
    k <- length(rows) + 1
    row <- run_script(..., label = paste(label, k, sep = '_'))
    rows[[k]] <- cbind(row, attempt = k)
    if (row$status %in% c(0, 1) || k == attempts) break
  }
  do.call(rbind, rows)
}

# The environment the child processes run in, as they report it themselves
child_environment <- function(libpath = .libPaths()) {
  callr::r(function() {
    versions <- vapply(c('lme4', 'lmerTest', 'Matrix'), function(p) {
      as.character(utils::packageVersion(p))
    }, character(1))
    sprintf('R %s (%s, %s locale) with %s', getRversion(), R.version$platform,
            Sys.getlocale('LC_CTYPE'),
            sub(', ([^,]*)$', ' and \\1', paste(names(versions), versions, collapse = ', ')))
  }, libpath = libpath, env = child_env, user_profile = FALSE)
}

# The data file a run received, from the data column of design.csv
data_file_for <- function(data) {
  stopifnot(all(data %in% c('balanced', 'unbalanced')))
  ifelse(data == 'unbalanced', 'data_unbalanced.csv', 'data.csv')
}
