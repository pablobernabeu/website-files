# Gathers the 48 runs into results.csv: the condition, the numbers each run
# reported, how long it took and which tools it called. Prose runs report
# their numbers in the reply. Script runs are credited with the line their
# script prints when executed (executions.csv), which is also checked against
# the line quoted in the agent's reply. Tool calls are checked for compliance:
# a prose run may only read its data file, and a script run may only touch its
# own directory. The paths outside it are listed in outside_paths.

library(jsonlite)

design <- read.csv('design.csv')

# The last line of a reply or output that has the RESULT form, after removing
# Markdown emphasis and code marks and reading a true minus sign as a hyphen.
# A line that does not match the form exactly counts as missing.
result_pattern <- '^RESULT estimate=(-?[0-9]+(?:\\.[0-9]+)?) lower=(-?[0-9]+(?:\\.[0-9]+)?) upper=(-?[0-9]+(?:\\.[0-9]+)?)$'
parse_result <- function(text) {
  lines <- trimws(gsub('[`*]', '', gsub('\u2212', '-', strsplit(text, '\n')[[1]], fixed = TRUE)))
  line <- tail(c(NA, grep(result_pattern, lines, perl = TRUE, value = TRUE)), 1)
  number <- function(k) as.numeric(sub(result_pattern, sprintf('\\%d', k), line, perl = TRUE))
  data.frame(result_line = line, estimate = number(1), lower = number(2), upper = number(3))
}

executions <- read.csv('executions.csv')

rows <- lapply(seq_len(nrow(design)), function(i) {
  run <- design[i, ]
  folder <- file.path('runs', run$run_id)
  response <- paste(readLines(file.path(folder, 'response.txt'), warn = FALSE, encoding = 'UTF-8'), collapse = '\n')
  log <- fromJSON(file.path(folder, 'tool_calls.json'), simplifyVector = FALSE)
  tools <- vapply(log$calls, `[[`, character(1), 'tool')
  inputs <- vapply(log$calls, function(call) toJSON(call$input, auto_unbox = TRUE), character(1))
  # Every absolute path into the file system in a tool call's input, other
  # than the run's own directory, its contents and /dev/null, counts as
  # outside the run. Paths are recognised by their root directory, so that
  # a division in R code such as sum(x)/720 is not mistaken for one.
  own_dir <- file.path('/home/user/agent_runs', run$run_id)
  roots <- 'home|tmp|root|etc|usr|opt|var|mnt|srv|proc|dev|run|media|bin|lib|sbin|sys'
  paths <- unlist(regmatches(inputs, gregexpr(sprintf('(?<![\\w.-])/(?:%s)(?:/[\\w.-]+)*', roots),
                                              inputs, perl = TRUE)))
  outside <- paths[!(paths == own_dir | startsWith(paths, paste0(own_dir, '/')) | paths == '/dev/null')]
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
if (anyNA(results$result_line)) stop('No valid RESULT line for: ',
  paste(results$run_id[is.na(results$result_line)], collapse = ', '))
write.csv(results, 'results.csv', row.names = FALSE)
print(results[order(results$data, results$request, results$route),
              c('run_id', 'data', 'request', 'route', 'result_line', 'minutes', 'tool_calls',
                'compliant', 'matches_reply')])
