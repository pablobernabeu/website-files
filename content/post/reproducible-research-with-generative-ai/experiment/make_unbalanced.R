# The follow-up data set: data.csv with 6% of its rows removed, as if those
# trials had been errors and excluded before analysis. Without them the design
# is no longer balanced, so the mixed model's estimate no longer equals the
# difference between the condition means and its REML fit has no closed form.

data <- read.csv('data.csv')
set.seed(2026)
errors <- sort(sample(nrow(data), round(0.06 * nrow(data))))
unbalanced <- data[-errors, ]
# A binary connection keeps the line endings '\n' on every operating system,
# so that the checksum does not depend on where the file is written.
connection <- file('data_unbalanced.csv', 'wb')
write.csv(unbalanced, connection, row.names = FALSE, quote = FALSE)
close(connection)
writeLines(digest::digest(file = 'data_unbalanced.csv', algo = 'sha256'))
