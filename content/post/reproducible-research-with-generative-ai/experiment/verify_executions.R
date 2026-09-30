# Executes every agent script once with run_script() and compares its output
# with the first of the stored executions in executions.csv. It is meant for the
# environment of those executions, which the Dockerfile in this folder rebuilds,
# and it stops with an error if any output differs, so that the check can run
# unattended. Unlike execute_scripts.R, it writes nothing.
#
# Usage, from this directory:  Rscript verify_executions.R

source('run_script.R')

design <- read.csv('design.csv')
scripts <- design[design$route == 'script', ]
stored <- read.csv('executions.csv')
stored <- stored[stored$execution == 1, ]

results <- do.call(rbind, lapply(seq_len(nrow(scripts)), function(i)
  run_script(scripts$run_id[i], data_file_for(scripts$data[i]), label = 'verify')))
results$identical <- results$status == 0 &
  results$stdout_sha256 == stored$stdout_sha256[match(results$run_id, stored$run_id)]

cat('Environment:', child_environment(), '\n')
cat('Stored executions:', unique(stored$environment), '\n\n')
print(results[, c('run_id', 'status', 'result', 'identical')], row.names = FALSE)
cat(sprintf('\n%d of %d scripts printed output byte-identical to the stored executions.\n',
            sum(results$identical), nrow(results)))
if (!all(results$identical)) quit(status = 1)
