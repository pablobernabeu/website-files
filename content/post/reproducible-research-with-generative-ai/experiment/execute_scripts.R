# Collects the agents' scripts and executes each one several times with
# run_script(), every time in a fresh R process and a fresh copy of its
# directory. Identical output hashes across executions show that a script
# printed byte-identical output every time.
#
# Usage, from this directory:  Rscript execute_scripts.R [executions]

source('run_script.R')

executions <- as.integer(commandArgs(trailingOnly = TRUE)[1])
if (is.na(executions)) executions <- 3L

design <- read.csv('design.csv')
scripts <- design[design$route == 'script', ]

# Copy each finished script from the agents' directories into the post bundle,
# where it is kept. Where those directories no longer exist, the stored copies
# are executed as they are.
agent_dirs <- file.path('/home/user/agent_runs', scripts$run_id)
if (all(dir.exists(agent_dirs))) {
  stopifnot(file.copy(file.path(agent_dirs, 'analysis.R'), file.path('runs', scripts$run_id, 'analysis.R'),
                      overwrite = TRUE))
}

results <- do.call(rbind, lapply(seq_len(nrow(scripts)), function(i) {
  do.call(rbind, lapply(seq_len(executions), function(k) {
    cbind(run_script(scripts$run_id[i], data_file_for(scripts$data[i]), label = k),
          execution = k)
  }))
}))
results$environment <- child_environment()
write.csv(results, 'executions.csv', row.names = FALSE)
writeLines(capture.output(sessionInfo()), 'executions_session_info.txt')
print(results[, c('run_id', 'execution', 'status', 'result')])
