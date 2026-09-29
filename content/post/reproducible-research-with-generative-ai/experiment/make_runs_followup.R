# Lays out the follow-up: eight prose and eight script runs of the specified
# request on the unbalanced data set, in a random launch order. Each run's
# directory holds that data set under the name data.csv.

set.seed(20260930)
design <- read.csv('design.csv')
if (!'data' %in% names(design)) design$data <- 'balanced'
followup <- data.frame(replicate = rep(1:8, 2), request = 'specified',
                       route = rep(c('prose', 'script'), each = 8), data = 'unbalanced')
followup <- followup[sample(nrow(followup)), ]
followup$order <- nrow(design) + seq_len(nrow(followup))
followup$run_id <- replicate(nrow(followup), paste(sample(c(0:9, letters[1:6]), 8, TRUE), collapse = ''))
stopifnot(!any(followup$run_id %in% design$run_id))

base <- '/home/user/agent_runs'
read_text <- function(path) paste(readLines(path), collapse = '\n')
for (i in seq_len(nrow(followup))) {
  run <- followup[i, ]
  run_dir <- file.path(base, run$run_id)
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
  file.copy('data_unbalanced.csv', file.path(run_dir, 'data.csv'), overwrite = TRUE)
  route <- gsub('{DIR}', run_dir, read_text(sprintf('prompts/route_%s.txt', run$route)), fixed = TRUE)
  prompt <- paste0(read_text('prompts/request_specified_unbalanced.txt'), '\n\n', route, '\n')
  dir.create(file.path('runs', run$run_id), recursive = TRUE, showWarnings = FALSE)
  writeLines(prompt, file.path('runs', run$run_id, 'prompt.txt'), sep = '')
}
design <- rbind(design[, c('order', 'run_id', 'route', 'request', 'data')],
                followup[, c('order', 'run_id', 'route', 'request', 'data')])
write.csv(design, 'design.csv', row.names = FALSE)
print(followup[, c('order', 'run_id', 'route')])
