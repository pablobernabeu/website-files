source("renv/activate.R")

options(blogdown.hugo.version = '0.61.0', 
        blogdown.server.timeout = 600,
        blogdown.knit.on_save = TRUE)

# Enable copy of code blocks to clipboard
library(xaringanExtra)
xaringanExtra::use_clipboard()

# Global Rmd chunk options
library(knitr)
knitr::opts_chunk$set(
  # Improve quality of figures
  fig.retina = 4 )

# DOWNLOAD CV FROM OSF
message('Downloading CV from OSF to /static...')
download.file(
  url = 'https://osf.io/download/84ktq',
  destfile = 'static/cv-pablo-bernabeu.pdf',
  mode = 'wb',
)
