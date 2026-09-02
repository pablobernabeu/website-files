+++
# Twin R and Python packages, presented with the Blank widget in two columns so
# that the heading and the composite of the hex logos sit in the left-hand
# column and the package table in the right-hand one.

widget = "blank"  # See https://sourcethemes.com/academic/docs/page-builder/
headless = true  # This file represents a page section.
active = true  # Activate this widget? true/false
weight = 50  # Order that this section will appear.

title = "Twin R and Python Packages"
subtitle = "<img src='/img/twin-packages-hex.webp' alt='Hexagonal logos of the five packages: scopusflow, lexsync, depictr, pilotr and theoryforge' width='760' height='507' style='max-width: 100%; height: auto; margin: 0.6rem 0 1rem;' loading='lazy'><span style='font-size:80%;'>Five pairs of packages, one in R and one in Python, that produce the same results from the same specification. Each pair is cross-checked in continuous integration, so an analysis can be repeated in either language.</span>"

[design]
  # Choose how many columns the section has. Valid values: 1 or 2.
  columns = "2"

[design.background]
  # Text color (true=light or false=dark).
  text_color_light = false

[design.spacing]
  # Customize the section spacing. Order is top, right, bottom, left.
  padding = ["100px", "0", "100px", "0"]

[advanced]
 # Custom CSS.
 css_style = ""

 # CSS class.
 css_class = ""
+++

<div style="margin-bottom: 1.4rem; font-size: 0.95em;">
Each package ships with bundled data, so the examples in its documentation run without an account or a download. The articles linked below apply each package to a research problem.
</div>

<div class="twin-package" style="display: flex; gap: 1rem; align-items: flex-start; margin-bottom: 1.4rem;">
  <img src="/img/hex-scopusflow.png" alt="" width="60" height="69" style="flex: 0 0 60px; margin-top: 0.2rem;" loading="lazy">
  <div style="min-width: 0;">
    <div style="font-weight: 600; font-size: 1.05em;">scopusflow</div>
    <div style="font-size: 0.85em; line-height: 1.7;"><a href="https://pablobernabeu.github.io/scopusflow/">R docs</a> &middot; <a href="https://pablobernabeu.github.io/scopusflow-py/">Python docs</a> &middot; <a href="https://CRAN.R-project.org/package=scopusflow">CRAN</a> &middot; <a href="https://pypi.org/project/scopusflow">PyPI</a> &middot; <a href="https://github.com/pablobernabeu/scopusflow">GitHub</a></div>
    <div style="margin-top: 0.3rem;">Quota-aware searches of the Scopus database. A search is written as an inspectable plan, run with caching and resumption, and written up to the PRISMA-S standard from the records themselves.</div>
    <div style="margin-top: 0.3rem; font-size: 0.95em;">Article: <a href="/2026/scopusflow-a-literature-search-you-can-rerun/">Searching a literature you can rerun</a></div>
  </div>
</div>

<div class="twin-package" style="display: flex; gap: 1rem; align-items: flex-start; margin-bottom: 1.4rem;">
  <img src="/img/hex-lexsync.png" alt="" width="60" height="69" style="flex: 0 0 60px; margin-top: 0.2rem;" loading="lazy">
  <div style="min-width: 0;">
    <div style="font-weight: 600; font-size: 1.05em;">lexsync</div>
    <div style="font-size: 0.85em; line-height: 1.7;"><a href="https://pablobernabeu.github.io/lexsync/r/">R docs</a> &middot; <a href="https://pablobernabeu.github.io/lexsync/python/">Python docs</a> &middot; <a href="https://github.com/pablobernabeu/lexsync">GitHub</a></div>
    <div style="margin-top: 0.3rem;">Stimulus sets for word-recognition experiments, drawn from word-frequency corpora in dozens of languages and equated across conditions and lists, together with the PsychoPy, OpenSesame or jsPsych experiment that presents them.</div>
    <div style="margin-top: 0.3rem; font-size: 0.95em;">Article: <a href="/2026/lexsync-from-corpus-to-eeg-ready-experiment/">From corpus to EEG-ready experiment</a></div>
  </div>
</div>

<div class="twin-package" style="display: flex; gap: 1rem; align-items: flex-start; margin-bottom: 1.4rem;">
  <img src="/img/hex-depictr.png" alt="" width="60" height="69" style="flex: 0 0 60px; margin-top: 0.2rem;" loading="lazy">
  <div style="min-width: 0;">
    <div style="font-weight: 600; font-size: 1.05em;">depictr</div>
    <div style="font-size: 0.85em; line-height: 1.7;"><a href="https://pablobernabeu.github.io/depictr/">R docs</a> &middot; <a href="https://pablobernabeu.github.io/depictr-py/">Python docs</a> &middot; <a href="https://pypi.org/project/depictr">PyPI</a> &middot; <a href="https://github.com/pablobernabeu/depictr">GitHub</a></div>
    <div style="margin-top: 0.3rem;">Plots for each stage of an analysis, from a first look at the data through model estimates to diagnostics and uncertainty, in one theme and a colourblind-safe palette, with an accessibility check for each figure.</div>
    <div style="margin-top: 0.3rem; font-size: 0.95em;">Article: <a href="/2026/depictr-one-visual-language-from-first-look-to-final-figure/">One visual language from first look to final figure</a></div>
  </div>
</div>

<div class="twin-package" style="display: flex; gap: 1rem; align-items: flex-start; margin-bottom: 1.4rem;">
  <img src="/img/hex-pilotr.png" alt="" width="60" height="69" style="flex: 0 0 60px; margin-top: 0.2rem;" loading="lazy">
  <div style="min-width: 0;">
    <div style="font-weight: 600; font-size: 1.05em;">pilotr</div>
    <div style="font-size: 0.85em; line-height: 1.7;"><a href="https://pablobernabeu.github.io/pilotr/r/">R docs</a> &middot; <a href="https://pablobernabeu.github.io/pilotr/python/">Python docs</a> &middot; <a href="https://pypi.org/project/pilotr">PyPI</a> &middot; <a href="https://pablobernabeu.github.io/pilotr/app/">App</a> &middot; <a href="https://github.com/pablobernabeu/pilotr">GitHub</a></div>
    <div style="margin-top: 0.3rem;">Simulated experimental and behavioural data from a portable design specification, with crossed by-participant and by-item variation, and the power, error and precision analyses that a design needs before it is run.</div>
    <div style="margin-top: 0.3rem; font-size: 0.95em;">Article: <a href="/2026/pilotr-pilot-the-study-before-running-it/">Pilot the study before running it</a></div>
  </div>
</div>

<div class="twin-package" style="display: flex; gap: 1rem; align-items: flex-start; margin-bottom: 1.4rem;">
  <img src="/img/hex-theoryforge.png" alt="" width="60" height="69" style="flex: 0 0 60px; margin-top: 0.2rem;" loading="lazy">
  <div style="min-width: 0;">
    <div style="font-weight: 600; font-size: 1.05em;">theoryforge</div>
    <div style="font-size: 0.85em; line-height: 1.7;"><a href="https://pablobernabeu.github.io/theoryforge/r/">R docs</a> &middot; <a href="https://pablobernabeu.github.io/theoryforge/python/">Python docs</a> &middot; <a href="https://pypi.org/project/theoryforge">PyPI</a> &middot; <a href="https://pablobernabeu.github.io/theoryforge/">Apps</a> &middot; <a href="https://github.com/pablobernabeu/theoryforge">GitHub</a></div>
    <div style="margin-top: 0.3rem;">A scientific theory is stored as a versioned, machine-checkable document. The package scores it against a rigour checklist, derives what it forbids in data, compiles it to lavaan syntax and appraises its amendments.</div>
    <div style="margin-top: 0.3rem; font-size: 0.95em;">Article: <a href="/2026/theoryforge-a-theory-you-can-check/">A theory you can check</a></div>
  </div>
</div>
