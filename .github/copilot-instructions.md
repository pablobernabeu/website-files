# Copilot Instructions for this Repository

## File Editing Rules

- **Never edit files in the `public/` folder directly** unless explicitly told to do so. The `public/` folder contains generated output from Hugo and should be rebuilt using `blogdown::build_site()` or `blogdown::serve_site()`.

- Source files are located in:
  - `content/` - Markdown and R Markdown content
  - `static/` - Static assets (JS, CSS, images)
  - `themes/hugo-academic/` - Theme files (layouts, partials, SCSS, JS)
  - `layouts/` - Custom layout overrides
  - `config/` - Configuration files

## Build Process

After editing source files, the site should be rebuilt using R:
```r
blogdown::build_site()
```

Or for live preview:
```r
blogdown::serve_site()
```
