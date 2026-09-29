# Executes one agent's analysis.R in a fresh R process, inside a fresh copy of
# its directory that holds only the script and the data file the agent saw,
# and returns the printed RESULT line with a SHA-256 hash of the full output.
# execute_scripts.R and the post both use it.

run_script <- function(run_id, data_file, experiment_dir = '.', label = 1L) {
  work <- file.path(tempdir(), sprintf('%s_%s', run_id, label))
  dir.create(work, showWarnings = FALSE)
  file.copy(file.path(experiment_dir, data_file), file.path(work, 'data.csv'), overwrite = TRUE)
  file.copy(file.path(experiment_dir, 'runs', run_id, 'analysis.R'), work, overwrite = TRUE)
  owd <- setwd(work)
  on.exit(setwd(owd))
  started <- Sys.time()
  output <- suppressWarnings(system2('Rscript', c('--vanilla', 'analysis.R'),
                                     stdout = TRUE, stderr = TRUE, timeout = 600))
  data.frame(
    run_id,
    seconds = round(as.numeric(difftime(Sys.time(), started, units = 'secs')), 1),
    status = if (is.null(attr(output, 'status'))) 0L else attr(output, 'status'),
    result = tail(c(NA, grep('^RESULT ', output, value = TRUE)), 1),
    stdout_sha256 = digest::digest(paste(output, collapse = '\n'), algo = 'sha256',
                                   serialize = FALSE)
  )
}

data_file_for <- function(data) ifelse(data == 'unbalanced', 'data_unbalanced.csv', 'data.csv')
