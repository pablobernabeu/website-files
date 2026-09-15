---
title: "depictr: A unified toolkit for visualising statistical models and data"
type: software
aliases:
  - '/publication/depictr/'
authors:
  - 'Bernabeu, P.'
date: '2026-09-01'
slug: depictr
publication_types:
  - '9'
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
abstract: 'Twin R and Python packages for producing consistent, publication-ready statistical graphics from exploratory analysis through model estimates, diagnostics, uncertainty and power. The toolkit includes colourblind-aware palettes and measurable accessibility checks.'
summary: 'A consistent, accessible visual language for statistical analysis in R and Python.'
featured: no
url_code: https://github.com/pablobernabeu/depictr
links:
  - name: R documentation
    url: https://pablobernabeu.github.io/depictr/
  - name: Python documentation
    url: https://pablobernabeu.github.io/depictr-py/
  - name: CRAN
    url: https://CRAN.R-project.org/package=depictr
  - name: PyPI
    url: https://pypi.org/project/depictr/
  - name: Blog post
    url: /2026/depictr-one-visual-language-from-first-look-to-final-figure/
image:
  caption: ''
  focal_point: 'Center'
  preview_only: true
projects: []
---

## Overview

depictr provides a shared visual language for exploratory graphics, model estimates, diagnostics, uncertainty and power analyses. Its R and Python implementations use the same naming and colour conventions, while returning ordinary plot objects that can still be adapted to a study's needs. The accessibility audit checks the rendered figure rather than assuming that a palette is sufficient.

## Illustrative outputs

The figures below are larger examples from the companion article. They show how a single analysis can move from an observed distribution to model estimates and then to an audited, publication-ready display.

<figure>
<img src="images/distribution-1.png" alt="Empirical cumulative distributions of lexical-decision reaction times for related and unrelated primes, with quartile guides" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>Observed reaction-time distributions with directly readable quartiles.</figcaption>
</figure>

<figure>
<img src="images/model-estimates-1.png" alt="Forest plot of standardised fixed effects for priming condition, presentation modality and word frequency with 95 percent confidence intervals" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>Model estimates presented with a consistent interval convention.</figcaption>
</figure>

<figure>
<img src="images/audited-figure-1.png" alt="Corrected density curves of lexical-decision reaction times, distinguished by colour and line type" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>An audited figure that uses both colour and line type to separate conditions.</figcaption>
</figure>

## Reproducibility and accessibility

The recommended workflow is to keep the plotting code with the analysis, record the package version and run the audit on the exact figure that will be submitted or presented. Alt text and a meaningful caption remain part of the author's editorial responsibility. See the [R documentation](https://pablobernabeu.github.io/depictr/), [Python documentation](https://pablobernabeu.github.io/depictr-py/) and [companion blog post](/2026/depictr-one-visual-language-from-first-look-to-final-figure/) for runnable examples.

## Reference

Bernabeu, P. (2026). *depictr: A unified toolkit for visualising statistical models and data* (Version 0.3.0) [Computer software]. CRAN. https://doi.org/10.32614/CRAN.package.depictr
