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
  tryCatch(
    download.file(
      url = 'https://osf.io/download/84ktq',
      destfile = 'static/cv-pablo-bernabeu.pdf',
      mode = 'wb'
    ),
    # Offline or OSF unavailable: keep the copy already in /static rather than
    # aborting startup.
    error = function(e) message('Could not download CV: ', conditionMessage(e))
  )
  options(blogdown.fast_preview = FALSE)
}
