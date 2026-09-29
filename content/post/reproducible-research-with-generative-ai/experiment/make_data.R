# Simulates the data set that every agent received, from the pilotr
# specification in spec.json, and writes it as data.csv with neutral labels.
# pilotr's own random-number generator makes the result identical on any
# machine and in its Python implementation, so the checksum printed at the end
# identifies the file the agents analysed.

library(pilotr)

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
connection <- file('data.csv', 'wb')
write.csv(agent_data, connection, row.names = FALSE, quote = FALSE)
close(connection)
digest::digest(file = 'data.csv', algo = 'sha256')
