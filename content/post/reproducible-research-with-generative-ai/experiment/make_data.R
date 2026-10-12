# Simulates the data set that every agent received, from the pilotr
# specification in spec.json, and writes it as data.csv with neutral labels.
# pilotr's own random-number generator makes the result identical on any
# machine and in its Python implementation, so the checksum printed at the end
# identifies the file the agents analysed.
#
# Usage, from this directory:  Rscript make_data.R [output folder]

library(pilotr)

# The folder to write into: the first argument, or this folder, whose stored
# file the script replaces
output_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(output_dir)) output_dir <- '.'

spec <- load_spec('spec.json')
simulated <- simulate_design(spec)

agent_data <- data.frame(
  participant = sprintf('P%02d', simulated$subject),
  item = sprintf('W%02d', simulated$item),
  prime = simulated$prime,
  frequency = round(simulated$frequency, 2),
  rt = simulated$rt
)
# A binary connection keeps the line endings '\n' on every operating system,
# so that the checksum does not depend on where the file is written.
connection <- file(file.path(output_dir, 'data.csv'), 'wb')
write.csv(agent_data, connection, row.names = FALSE, quote = FALSE)
close(connection)
writeLines(digest::digest(file = file.path(output_dir, 'data.csv'), algo = 'sha256'))
