# Finds which part of the environment changed the printed output of the
# agents' scripts between the stored executions and the environment in which
# the post is built. Every script is executed on one machine with three package
# libraries that differ only in the versions of lme4 and lmerTest:
#
#   renv.lock           the site's renv library (lme4 2.0-6, lmerTest 3.2-1)
#   lme4 1.1-35.1       the same, with lme4 returned to the version of the
#                       stored executions
#   lme4 1.1-35.1 and   the same, with lmerTest also returned (3.1-3)
#   lmerTest 3.1-3
#
# The older versions are built from the CRAN archive, each into its own
# library, which needs a compiler (Rtools on Windows). Matrix stays at the renv
# version throughout, because Matrix 1.6-5, the version of the stored
# executions, no longer compiles under R 4.6.
#
# A script whose R process crashes is executed again (run_script_with_retries),
# and every attempt is recorded. The output of each script's last attempt is
# kept in outputs/<library>/<run_id>.txt, and version_check.csv has one row per
# attempt, with the versions of the packages the scripts load.
#
# Usage, from the root of the repository so that renv is active:
#   Rscript content/post/reproducible-research-with-generative-ai/experiment/check_versions.R
# The environment variable STORED_LIBS may name a folder that already holds the
# libraries lme4-1.1-35.1 and lmerTest-3.1-3, which saves building them.

script_file <- sub('^--file=', '', grep('^--file=', commandArgs(), value = TRUE))
experiment_dir <- normalizePath(dirname(script_file))
source(file.path(experiment_dir, 'run_script.R'))

stored_versions <- c(lme4 = '1.1-35.1', lmerTest = '3.1-3')
stored_root <- Sys.getenv('STORED_LIBS', file.path(tools::R_user_dir('genai-post-check', 'cache'),
                                                    'stored-versions'))
stored_libs <- setNames(file.path(stored_root, paste(names(stored_versions), stored_versions, sep = '-')),
                        names(stored_versions))
for (package in names(stored_versions)) {
  lib <- stored_libs[[package]]
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  installed <- tryCatch(utils::packageDescription(package, lib.loc = lib)$Version,
                        error = function(e) NA, warning = function(w) NA)
  if (!identical(installed, stored_versions[[package]])) {
    tarball <- sprintf('%s_%s.tar.gz', package, stored_versions[[package]])
    local <- file.path(tempdir(), tarball)
    download.file(sprintf('https://cran.r-project.org/src/contrib/Archive/%s/%s', package, tarball),
                  local, mode = 'wb', quiet = TRUE)
    install.packages(local, lib = lib, repos = NULL, type = 'source')
  }
  stopifnot(identical(utils::packageDescription(package, lib.loc = lib)$Version,
                      stored_versions[[package]]))
}

libraries <- list(
  `renv.lock` = .libPaths(),
  `lme4 1.1-35.1` = c(stored_libs[['lme4']], .libPaths()),
  `lme4 1.1-35.1 and lmerTest 3.1-3` = c(stored_libs[['lme4']], stored_libs[['lmerTest']], .libPaths()))
folders <- setNames(c('renv-lock', 'stored-lme4', 'stored-lme4-lmertest'), names(libraries))
unlink(file.path(experiment_dir, 'outputs'), recursive = TRUE)
for (folder in folders) dir.create(file.path(experiment_dir, 'outputs', folder), recursive = TRUE)

design <- read.csv(file.path(experiment_dir, 'design.csv'))
scripts <- design[design$route == 'script', ]
tasks <- expand.grid(i = seq_len(nrow(scripts)), library = names(libraries),
                     stringsAsFactors = FALSE)

# The executions run four at a time, each in its own R process as before. The
# workers skip the R profile, which in a project with renv can take longer to
# run than the cluster waits for a worker, and receive the library paths below.
execute <- function(task) {
  run_id <- scripts$run_id[task$i]
  keep <- file.path(experiment_dir, 'outputs', folders[[task$library]], paste0(run_id, '.txt'))
  attempts <- run_script_with_retries(run_id, data_file_for(scripts$data[task$i]), experiment_dir,
                                      label = folders[[task$library]],
                                      libpath = libraries[[task$library]], output_copy = keep)
  output <- readLines(keep, warn = FALSE)
  attempts$trimmed_sha256 <- NA
  attempts$trimmed_sha256[nrow(attempts)] <- digest::digest(
    paste(sub('[ \t]+$', '', output), collapse = '\n'), algo = 'sha256', serialize = FALSE)
  cbind(library = task$library, attempts)
}
cluster <- parallel::makeCluster(4, rscript_args = '--no-init-file')
invisible(parallel::clusterCall(cluster, function(paths) .libPaths(paths), .libPaths()))
parallel::clusterExport(cluster, c('experiment_dir', 'scripts', 'libraries', 'folders', 'run_script',
                                   'run_script_with_retries', 'child_env', 'data_file_for'))
results <- do.call(rbind, parallel::parLapply(cluster, split(tasks, seq_len(nrow(tasks))), execute))
parallel::stopCluster(cluster)

# The environment as the stored executions recorded it, and the versions of
# every package the scripts load, as each library provides them
environments <- vapply(libraries, child_environment, character(1))
versions <- vapply(libraries, function(lib) callr::r(function() {
  packages <- c('lme4', 'lmerTest', 'Matrix', 'reformulas', 'emmeans', 'pbkrtest', 'dplyr', 'tidyr')
  found <- vapply(packages, function(p) tryCatch(utils::packageDescription(p)$Version,
                                                 warning = function(w) NA_character_), character(1))
  paste(names(found)[!is.na(found)], found[!is.na(found)], collapse = ', ')
}, libpath = lib, user_profile = FALSE), character(1))
results$environment <- environments[results$library]
results$packages <- versions[results$library]
results <- results[order(match(results$library, names(libraries)), match(results$run_id, scripts$run_id),
                         results$attempt), ]
write.csv(results, file.path(experiment_dir, 'version_check.csv'), row.names = FALSE)

# The kept outputs are rewritten with the line ending '\n', which Windows does
# not write, so that they are the same bytes on every system (the hashes, taken
# over lines, are unaffected)
for (file in list.files(file.path(experiment_dir, 'outputs'), recursive = TRUE, full.names = TRUE)) {
  lines <- readLines(file, warn = FALSE)
  connection <- file(file, 'wb')
  writeLines(lines, connection)
  close(connection)
}

# The session of a child process in each library, which is where the scripts ran
sessions <- unlist(lapply(names(libraries), function(name) c(
  sprintf('==== %s', name), '',
  callr::r(function() capture.output(sessionInfo()), libpath = libraries[[name]],
           env = child_env, user_profile = FALSE), '')))
writeLines(sessions, file.path(experiment_dir, 'version_check_session_info.txt'))
print(results[, c('library', 'run_id', 'attempt', 'status', 'result')], row.names = FALSE)
