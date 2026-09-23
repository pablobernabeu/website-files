---
title: "depictr: A unified toolkit for visualising statistical models and data"
type: software
software_kind:
  - package
  - web-application
aliases:
  - '/publication/depictr/'
authors:
  - 'Bernabeu, P.'
date: '2026-09-01'
apa_captions: true
slug: depictr
publication: 'Version 0.3.0 [Computer software]. CRAN'
doi: 10.32614/CRAN.package.depictr
categories:
  - software
tags:
  - software
  - R
  - Python
  - data visualisation
  - statistics
  - accessibility
abstract: 'Twin R and Python packages for producing consistent, publication-ready statistical graphics from exploratory analysis to model estimates, diagnostics, uncertainty and power. The toolkit includes colourblind-aware palettes and measurable accessibility checks.'
summary: 'A consistent, accessible visual language for statistical analysis in R and Python.'
featured: no
open_materials: true
url_code: https://github.com/pablobernabeu/depictr
links:
  - name: R documentation
    url: https://pablobernabeu.github.io/depictr/
  - name: Python documentation
    url: https://pablobernabeu.github.io/depictr-py/
  - name: Python app guide
    url: https://pablobernabeu.github.io/depictr-py/app/
  - name: CRAN
    url: https://CRAN.R-project.org/package=depictr
  - name: PyPI
    url: https://pypi.org/project/depictr/
  - name: Blog post
    url: /2026/depictr-one-visual-language-from-first-look-to-final-figure/
package_docs:
  - name: R documentation
    url: https://pablobernabeu.github.io/depictr/
  - name: Python documentation
    url: https://pablobernabeu.github.io/depictr-py/
image:
  caption: ''
  focal_point: 'Center'
  preview_only: true
projects: []
---

## Overview

depictr (Bernabeu, 2026) provides a shared visual language for exploratory graphics, model estimates, diagnostics, uncertainty and power analyses. Its R and Python implementations use the same naming and colour conventions, and both return ordinary plot objects that can still be adapted to the needs of a study. The accessibility audit examines the rendered figure itself, since a colourblind-aware palette alone cannot guarantee an accessible figure.

The Python implementation also has a Streamlit app, which offers a gallery of the plots and a way to try the package without writing any code. It runs locally from a clone of the [Python repository](https://github.com/pablobernabeu/depictr-py), as the [app guide](https://pablobernabeu.github.io/depictr-py/app/) explains.

## One Set of Conventions, Audited at the End

Colour, interval and labelling conventions carry from the observed distribution of a simulated lexical-decision experiment, through the model estimates, to the figure that will leave the project. Figure 1 shows the observed distributions, Figure 2 the model estimates drawn from the same data, and Figure 3 the version that the accessibility audit asked for.

<figure>
<img src="images/distribution-1.png" alt="Empirical cumulative distributions of lexical-decision reaction times for related and unrelated primes, with quartile guides" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>Observed Reaction-Time Distributions With Directly Readable Quartiles.</figcaption>
</figure>

<figure>
<img src="images/model-estimates-1.png" alt="Forest plot of the fixed effects, each per standard deviation of its predictor, for priming condition, presentation modality and word frequency, with 95 per cent confidence intervals" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>Fixed Effects in Milliseconds per Standard Deviation of the Predictor, With 95% Confidence Intervals.</figcaption>
</figure>

<figure>
<img src="images/audited-figure-1.png" alt="Corrected density curves of lexical-decision reaction times, distinguished by colour and line type" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>The Corrected Figure, in Which Colour and Line Type Both Separate the Priming Conditions.</figcaption>
</figure>

## Reproducibility and Accessibility

The recommended workflow is to keep the plotting code with the analysis, record the package version and run the audit on the exact figure that will be submitted or presented. Alt text and a meaningful caption remain part of the author's editorial responsibility. See the [R documentation](https://pablobernabeu.github.io/depictr/), [Python documentation](https://pablobernabeu.github.io/depictr-py/) and [companion blog post](/2026/depictr-one-visual-language-from-first-look-to-final-figure/) for runnable examples.

## Reference

Bernabeu, P. (2026). *depictr: A unified toolkit for visualising statistical models and data* (Version 0.3.0) [Computer software]. CRAN. https://doi.org/10.32614/CRAN.package.depictr
