# Executes one agent's analysis.R in a fresh R process started by the running
# R installation, inside a fresh copy of its directory that holds only the
# script and the data file the agent saw. It returns the printed RESULT line,
# the exit status and a SHA-256 hash of the full output. The child runs in the
# C locale, because the locale changes some printed characters (the quotation
# marks in lmerTest's significance codes, for one) and so the bytes of the
# output. It loads no R profile either, since a project profile can reset the
# locale (renv's does, on Windows) and the library paths. execute_scripts.R,
# check_versions.R and the post all use it.

child_env <- c(callr::rcmd_safe_env(), LC_ALL = 'C', LANG = 'C', LANGUAGE = 'en')

# libpath chooses the package library of the child process, and output_copy,
# if given, is where to keep the full output.
run_script <- function(run_id, data_file, experiment_dir = '.', label = 1L,
                       libpath = .libPaths(), output_copy = NULL) {
  work <- file.path(tempdir(), sprintf('%s_%s', run_id, label))
  unlink(work, recursive = TRUE)
  dir.create(work)
  stopifnot(file.copy(file.path(experiment_dir, data_file), file.path(work, 'data.csv')),
            file.copy(file.path(experiment_dir, 'runs', run_id, 'analysis.R'), work))
  output_file <- file.path(work, 'output.txt')
  started <- Sys.time()
  status <- callr::rscript('analysis.R', wd = work, stdout = output_file, stderr = '2>&1',
                           libpath = libpath, env = child_env, user_profile = FALSE,
                           fail_on_status = FALSE, show = FALSE, timeout = 600)$status
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

# The environment the child processes run in, as they report it themselves
child_environment <- function(libpath = .libPaths()) {
  callr::r(function() {
    versions <- vapply(c('lme4', 'lmerTest', 'Matrix'), function(p)
      as.character(utils::packageVersion(p)), character(1))
    sprintf('R %s (%s, %s locale) with %s', getRversion(), R.version$platform,
            Sys.getlocale('LC_CTYPE'),
            sub(', ([^,]*)$', ' and \\1', paste(names(versions), versions, collapse = ', ')))
  }, libpath = libpath, env = child_env, user_profile = FALSE)
}

data_file_for <- function(data) ifelse(data == 'unbalanced', 'data_unbalanced.csv', 'data.csv')
