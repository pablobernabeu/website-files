# Gathers the 48 runs into results.csv: the condition, the numbers each run
# reported, how long it took and which tools it called. Prose runs report
# their numbers in the reply. Script runs are credited with the line their
# script prints when executed (executions.csv), which is also checked against
# the line quoted in the agent's reply. Tool calls are checked for compliance:
# a prose run may only read its data file, and a script run may only touch its
# own directory.

library(jsonlite)

design <- read.csv('design.csv')

parse_result <- function(text) {
  line <- tail(c(NA, regmatches(text, gregexpr('RESULT estimate=[^\n`]*', text))[[1]]), 1)
  number <- function(key) as.numeric(sub(sprintf('.*%s=(-?[0-9.]+).*', key), '\\1', line))
  data.frame(result_line = trimws(line), estimate = number('estimate'),
             lower = number('lower'), upper = number('upper'))
}

executions <- read.csv('executions.csv')

rows <- lapply(seq_len(nrow(design)), function(i) {
  run <- design[i, ]
  folder <- file.path('runs', run$run_id)
  response <- paste(readLines(file.path(folder, 'response.txt'), warn = FALSE), collapse = '\n')
  log <- fromJSON(file.path(folder, 'tool_calls.json'), simplifyVector = FALSE)
  tools <- vapply(log$calls, `[[`, character(1), 'tool')
  inputs <- vapply(log$calls, function(call) toJSON(call$input, auto_unbox = TRUE), character(1))
  own_dir <- file.path('/home/user/agent_runs', run$run_id)
  paths <- unlist(regmatches(inputs, gregexpr('/home/user/[A-Za-z0-9_./-]*', inputs)))
  outside <- paths[!startsWith(paths, own_dir)]
  compliant <- if (run$route == 'prose') all(tools == 'Read') else length(outside) == 0

  reported <- parse_result(response)
  if (run$route == 'script') {
    executed <- executions[executions$run_id == run$run_id & executions$execution == 1, ]
    numbers <- parse_result(executed$result)
    numbers$matches_reply <- identical(numbers$result_line, reported$result_line)
  } else {
    numbers <- reported
    numbers$matches_reply <- NA
  }
  stamps <- as.POSIXct(c(log$started, log$finished), format = '%Y-%m-%dT%H:%M:%OS', tz = 'UTC')
  cbind(run, numbers,
        minutes = round(as.numeric(difftime(stamps[2], stamps[1], units = 'mins')), 2),
        tool_calls = length(tools), compliant, outside_paths = paste(unique(outside), collapse = ' '),
        reply_words = length(strsplit(response, '\\s+')[[1]]))
})
results <- do.call(rbind, rows)
write.csv(results, 'results.csv', row.names = FALSE)
print(results[order(results$data, results$request, results$route),
              c('run_id', 'data', 'request', 'route', 'result_line', 'minutes', 'tool_calls',
                'compliant', 'matches_reply')])
