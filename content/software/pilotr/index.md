---
title: "pilotr: Simulate experimental and behavioural data from a portable design specification"
type: software
software_kind:
  - package
  - web-application
aliases:
  - '/publication/pilotr/'
authors:
  - 'Bernabeu, P.'
date: '2026-08-21'
apa_captions: true
slug: pilotr
publication: 'Version 0.3.1 on CRAN and Version 0.3.0 on PyPI [Computer software]'
doi: 10.32614/CRAN.package.pilotr
citations:
  - label: 'Citation (CRAN)'
    file: cite-cran.bib
  - label: 'Citation (PyPI)'
    file: cite-pypi.bib
categories:
  - software
tags:
  - software
  - R
  - Python
  - simulation
  - power analysis
  - linear mixed-effects models
abstract: 'Twin R and Python packages for simulating experimental and behavioural data from a portable design specification. pilotr supports crossed mixed-effects designs, power and precision analyses, and reproducible generation from the same specification in either language.'
summary: 'Simulation-based design analysis from a portable R and Python specification.'
featured: no
open_materials: true
url_code: https://github.com/pablobernabeu/pilotr
links:
  - name: R documentation
    url: https://pablobernabeu.github.io/pilotr/r/
  - name: Python documentation
    url: https://pablobernabeu.github.io/pilotr/python/
  - name: Browser app
    url: https://pablobernabeu.github.io/pilotr/app/
  - name: CRAN
    url: https://CRAN.R-project.org/package=pilotr
  - name: PyPI
    url: https://pypi.org/project/pilotr/
  - name: Blog post
    url: /2026/pilotr-pilot-the-study-before-running-it/
package_docs:
  - name: R documentation
    url: https://pablobernabeu.github.io/pilotr/r/
  - name: Python documentation
    url: https://pablobernabeu.github.io/pilotr/python/
  - name: Browser app
    url: https://pablobernabeu.github.io/pilotr/app/
image:
  caption: ''
  focal_point: 'Center'
  preview_only: true
projects: []
---

## Overview

pilotr (Bernabeu, 2026a, 2026b) makes a planned study executable before any data are collected. A portable specification describes the units, predictors, response family, fixed effects and random-effects structure, and the same specification can then be simulated and analysed in R or Python. The main output is a design diagnosis that goes beyond a single power percentage to cover detection, precision, Type S (sign) and Type M (magnitude) errors, and model warnings.

## Detection, Precision and Exaggeration

A simulation-based design analysis should establish how often the target effect is detected, how precisely it is estimated and how much the statistically significant estimates exaggerate it. Figure 1 reports detection across participant counts, Figure 2 precision over a wider range of counts, and Figure 3 the exaggeration that survives a significance filter.

<figure>
<img src="images/power-curve-1.png" alt="Illustrative power curve for a priming effect across sample sizes, with an 80% reference line" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>Detection Probability Across Participant Counts. Each design uses 12 replicates. All simulated designs contain 24 items.</figcaption>
</figure>

<figure>
<img src="images/precision-curve-1.png" alt="Two-panel precision plot showing the probability of excluding a negligible effect and mean confidence-interval width as sample size increases" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>Precision and the Probability That an Interval Excludes a Prespecified Negligible-Effect Region. Each design uses 12 replicates. All simulated designs contain 24 items.</figcaption>
</figure>

<figure>
<img src="images/type-m-plot-1.png" alt="Type M error declining towards 1 as power increases across effect-size and sample-size simulations" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>Magnitude Exaggeration Among Statistically Significant Estimates. Each design uses 12 replicates.</figcaption>
</figure>

## Reproducible Planning

Treat the specification, simulation seed, package version, number of replicates and fitted model as part of the planning record. The [companion blog post](/2026/pilotr-pilot-the-study-before-running-it/) keeps its examples quick by running each analysis with a small number of replicates. A real design decision requires many more replicates and a sensitivity analysis over plausible assumptions. The [R documentation](https://pablobernabeu.github.io/pilotr/r/) and [Python documentation](https://pablobernabeu.github.io/pilotr/python/) cover the full workflow, and the [browser app](https://pablobernabeu.github.io/pilotr/app/), which needs no installation, builds and simulates a design and estimates power for a simple two-group comparison.

## References

Bernabeu, P. (2026a). *pilotr: Simulate experimental and behavioural data from a portable design specification* (Version 0.3.1) [Computer software]. CRAN. https://doi.org/10.32614/CRAN.package.pilotr

Bernabeu, P. (2026b). *pilotr: Simulate experimental and behavioural data from a portable design specification* (Version 0.3.0) [Computer software]. PyPI. https://pypi.org/project/pilotr/0.3.0/
