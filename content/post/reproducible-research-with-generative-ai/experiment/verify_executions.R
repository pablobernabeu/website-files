# Executes every agent script once with run_script() and compares its output
# with the first of the stored executions in executions.csv. It is meant for the
# environment of those executions, which the Dockerfile in this folder rebuilds,
# and it stops with an error if any output differs, so that the check can run
# unattended. Given a file name, it also writes the comparison there, with the
# environment and, when it runs on GitHub Actions, the address of the run.
# Unlike execute_scripts.R, it never changes the stored executions.
#
# Usage, from this directory:  Rscript verify_executions.R [verification.csv]

source('run_script.R')

design <- read.csv('design.csv')
scripts <- design[design$route == 'script', ]
stored <- read.csv('executions.csv')
stored <- stored[stored$execution == 1, ]

results <- do.call(rbind, lapply(seq_len(nrow(scripts)), function(i)
  run_script(scripts$run_id[i], data_file_for(scripts$data[i]), label = 'verify')))
results$identical <- results$status == 0 &
  results$stdout_sha256 == stored$stdout_sha256[match(results$run_id, stored$run_id)]
results$environment <- child_environment()
results$run_url <- if (nzchar(Sys.getenv('GITHUB_RUN_ID'))) {
  with(as.list(Sys.getenv(c('GITHUB_SERVER_URL', 'GITHUB_REPOSITORY', 'GITHUB_RUN_ID'))),
       sprintf('%s/%s/actions/runs/%s', GITHUB_SERVER_URL, GITHUB_REPOSITORY, GITHUB_RUN_ID))
} else NA

cat('Environment:', unique(results$environment), '\n')
cat('Stored executions:', unique(stored$environment), '\n\n')
print(results[, c('run_id', 'status', 'result', 'identical')], row.names = FALSE)
cat(sprintf('\n%d of %d scripts printed output byte-identical to the stored executions.\n',
            sum(results$identical), nrow(results)))

output_file <- commandArgs(trailingOnly = TRUE)[1]
if (!is.na(output_file)) {
  write.csv(results[, c('run_id', 'status', 'result', 'stdout_sha256', 'identical',
                        'environment', 'run_url')], output_file, row.names = FALSE)
  # The session of a child process, where the scripts ran, and the versions of
  # the system packages that provide R, its packages and the BLAS
  # The installed ones only ('ii'), since the pattern also matches packages
  # that dpkg knows of but that are not installed
  packages <- tryCatch({
    listed <- system2('dpkg-query', c('-W', "-f='${db:Status-Abbrev}${Package} ${Version}\\n'",
                                      "'r-base-core'", "'r-cran-*'", 'libblas3', 'liblapack3'),
                      stdout = TRUE)
    sub('^ii +', '', grep('^ii', listed, value = TRUE))
  }, error = function(e) 'dpkg-query is not available')
  writeLines(c(callr::r(function() capture.output(sessionInfo()), env = child_env, user_profile = FALSE),
               '', 'System packages (dpkg-query -W):', packages),
             sub('\\.csv$', '_session_info.txt', output_file))
}
if (!all(results$identical)) quit(status = 1)
