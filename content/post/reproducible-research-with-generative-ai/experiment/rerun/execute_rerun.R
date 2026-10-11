# Executes every script of the second round twice, each time in a fresh R
# process in the C locale and a fresh copy of its folder, with run_script.R,
# and writes executions.csv and executions_session_info.txt next to this file.
#
# The scripts were executed in the R library the agents themselves used, that
# of R 4.6.1 started without a project profile, whose versions library.lock
# records. They were executed from this folder with
#   Rscript --no-init-file execute_rerun.R
# which replaces executions.csv and executions_session_info.txt, so a check
# runs in a copy of the whole experiment folder. A script whose R process
# crashes is executed again, and only its last attempt is kept.

source('../run_script.R')

# run_script() expects the data files at the top of a folder and each script in
# runs/<run_id>/, so the two rounds are laid out that way in a temporary folder
results <- read.csv('results.csv')
scripts <- results[results$route == 'script', ]
exec_dir <- file.path(tempdir(), 'rerun_exec')
for (round_name in unique(scripts$round)) {
  dir.create(file.path(exec_dir, round_name, 'runs'), recursive = TRUE, showWarnings = FALSE)
  stopifnot(file.copy(file.path('..', c('data.csv', 'data_unbalanced.csv')),
                      file.path(exec_dir, round_name), overwrite = TRUE))
}
for (i in seq_len(nrow(scripts))) {
  dir.create(file.path(exec_dir, scripts$round[i], 'runs', scripts$run_id[i]), showWarnings = FALSE)
  stopifnot(file.copy(file.path('runs', scripts$round[i], scripts$run_id[i], 'analysis.R'),
                      file.path(exec_dir, scripts$round[i], 'runs', scripts$run_id[i]), overwrite = TRUE))
}

rows <- list()
for (execution in 1:2) for (i in seq_len(nrow(scripts))) {
  attempts <- run_script_with_retries(scripts$run_id[i], data_file_for(scripts$data[i]),
                                      experiment_dir = file.path(exec_dir, scripts$round[i]),
                                      label = paste0(scripts$round[i], execution))
  row <- attempts[nrow(attempts), ]
  rows[[length(rows) + 1]] <- cbind(round = scripts$round[i], execution = execution, row)
}
executions <- do.call(rbind, rows)
executions$environment <- child_environment()
write.csv(executions, 'executions.csv', row.names = FALSE)
writeLines(capture.output(sessionInfo()), 'executions_session_info.txt')
