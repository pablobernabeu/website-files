# Lays out the 32 runs: eight for each combination of route (prose or script)
# and request (open or specified), in a random launch order so that time of day
# is not confounded with condition. Each run gets its own directory holding
# only data.csv, and its prompt is assembled here from the templates.
#
# Usage, from this directory:  Rscript make_runs.R [folder for the runs]
# It replaces design.csv and runs/<run_id>/prompt.txt, so a check runs in a copy.

# The folder that holds each run's directory, whose path the prompts give the
# agents: the first argument, or the folder the runs used
base <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(base)) base <- '/home/user/agent_runs'
# Binary connections keep the line endings '\n' on every operating system
write_text <- function(text, path) {
  connection <- file(path, 'wb')
  writeLines(text, connection, sep = '')
  close(connection)
}
write_design <- function(design) {
  connection <- file('design.csv', 'wb')
  write.csv(design, connection, row.names = FALSE)
  close(connection)
}

# The RNG kind of R 3.6.0 onwards, as in make_unbalanced.R
RNGkind('Mersenne-Twister', 'Inversion', 'Rejection')
set.seed(20260929)
design <- expand.grid(replicate = 1:8, request = c('open', 'specified'),
                      route = c('prose', 'script'), stringsAsFactors = FALSE)
design <- design[sample(nrow(design)), ]
design$order <- seq_len(nrow(design))
design$run_id <- replicate(nrow(design), paste(sample(c(0:9, letters[1:6]), 8, TRUE), collapse = ''))
design <- design[, c('order', 'run_id', 'route', 'request')]
stopifnot(!anyDuplicated(design$run_id))

read_text <- function(path) paste(readLines(path), collapse = '\n')
for (i in seq_len(nrow(design))) {
  run <- design[i, ]
  run_dir <- file.path(base, run$run_id)
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
  stopifnot(file.copy('data.csv', run_dir, overwrite = TRUE))
  route <- gsub('{DIR}', run_dir, read_text(sprintf('prompts/route_%s.txt', run$route)), fixed = TRUE)
  prompt <- paste0(read_text(sprintf('prompts/request_%s.txt', run$request)), '\n\n', route, '\n')
  dir.create(file.path('runs', run$run_id), recursive = TRUE, showWarnings = FALSE)
  write_text(prompt, file.path('runs', run$run_id, 'prompt.txt'))
}
write_design(design)
print(design)
