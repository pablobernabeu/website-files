if (!nzchar(Sys.getenv("CI"))) {
  # Local-only: activate renv, load interactive helpers, download CV
  source("renv/activate.R")

  options(blogdown.hugo.version = '0.61.0', 
          blogdown.server.timeout = 600,
          blogdown.knit.on_save = TRUE,
          blogdown.server.args = c('--disableFastRender'))

  # Enable copy of code blocks to clipboard. Optional convenience, so a missing
  # package must not take down every R session in the project (including the
  # "Serve site" and "Rmd watcher" tasks).
  if (requireNamespace("xaringanExtra", quietly = TRUE)) {
    xaringanExtra::use_clipboard()
  } else {
    message("xaringanExtra not installed; code-block clipboard buttons disabled.")
  }

  # Global Rmd chunk options. Guarded for the same reason: knitr is only needed
  # once something is actually knitted, and the failure is clearer there.
  if (requireNamespace("knitr", quietly = TRUE)) {
    knitr::opts_chunk$set(
      # Improve quality of figures
      fig.retina = 4 )
  } else {
    message("knitr not installed; run renv::restore() before building.")
  }

  # DOWNLOAD CV FROM OSF
  message('Downloading CV from OSF to /static...')
  # Download to a temporary file and replace the tracked copy only once the
  # download is complete. Writing straight to static/ deleted the committed CV
  # whenever OSF answered with an error (a 404 in September 2026), so every R
  # session in the project left a deletion in the working tree. The checks
  # mirror .github/workflows/update-cv.yml: a PDF header and a %%EOF trailer,
  # which a truncated transfer lacks.
  cv_tmp <- tempfile(fileext = '.pdf')
  cv_ok <- tryCatch({
    download.file(url = 'https://osf.io/download/84ktq', destfile = cv_tmp,
                  mode = 'wb', quiet = TRUE)
    bytes <- readBin(cv_tmp, 'raw', file.size(cv_tmp))
    tail_text <- rawToChar(bytes[max(1, length(bytes) - 2047):length(bytes)][
      bytes[max(1, length(bytes) - 2047):length(bytes)] != as.raw(0)])
    length(bytes) > 1000 &&
      identical(rawToChar(bytes[1:4]), '%PDF') &&
      grepl('%%EOF', tail_text, fixed = TRUE)
  }, error = function(e) {
    message('Could not download CV: ', conditionMessage(e))
    FALSE
  }, warning = function(w) {
    message('Could not download CV: ', conditionMessage(w))
    FALSE
  })
  if (isTRUE(cv_ok)) {
    file.copy(cv_tmp, 'static/cv-pablo-bernabeu.pdf', overwrite = TRUE)
  } else {
    message('Keeping the CV already in /static.')
  }
  unlink(cv_tmp)
  options(blogdown.fast_preview = FALSE)
}
