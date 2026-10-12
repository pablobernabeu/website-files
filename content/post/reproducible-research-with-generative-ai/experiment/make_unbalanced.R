# The follow-up data set: data.csv with 6% of its rows removed, as if those
# trials had been errors and excluded before analysis. Without them the design
# is no longer balanced, so the mixed model's estimate no longer equals the
# difference between the condition means and its REML fit has no closed form.
# Any proportion of removed trials unbalances the design; 6% removes 86 of the
# 1,440 trials and leaves every participant and word in the data.
#
# Usage, from this directory:  Rscript make_unbalanced.R [output folder]

# The folder to write into: the first argument, or this folder, whose stored
# file the script replaces
output_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(output_dir)) output_dir <- '.'

data <- read.csv('data.csv')
# The RNG kind of R 3.6.0 onwards, fixed so that sample() draws the same rows
# in every version from R 3.6.0. Earlier versions, whose RNGkind() lacks the
# third argument, stop here. The seed is that of spec.json, which pilotr's own
# generator used, so the two draws do not share a random-number stream.
RNGkind('Mersenne-Twister', 'Inversion', 'Rejection')
set.seed(2026)
errors <- sort(sample(nrow(data), round(0.06 * nrow(data))))
unbalanced <- data[-errors, ]
# A binary connection keeps the line endings '\n' on every operating system,
# so that the checksum does not depend on where the file is written.
connection <- file(file.path(output_dir, 'data_unbalanced.csv'), 'wb')
write.csv(unbalanced, connection, row.names = FALSE, quote = FALSE)
close(connection)
writeLines(digest::digest(file = file.path(output_dir, 'data_unbalanced.csv'), algo = 'sha256'))
