---
title: "pilotr: Simulate experimental and behavioural data from a portable design specification"
type: software
aliases:
  - '/publication/pilotr/'
authors:
  - 'Bernabeu, P.'
date: '2026-08-21'
slug: pilotr
publication_types:
  - '9'
publication: 'Version 0.3.0 [Computer software]. Zenodo'
doi: 10.5281/zenodo.21266313
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
url_code: https://github.com/pablobernabeu/pilotr
links:
  - name: R documentation
    url: https://pablobernabeu.github.io/pilotr/r/
  - name: Python documentation
    url: https://pablobernabeu.github.io/pilotr/python/
  - name: Browser app
    url: https://pablobernabeu.github.io/pilotr/app/
  - name: PyPI
    url: https://pypi.org/project/pilotr/
  - name: Blog post
    url: /2026/pilotr-pilot-the-study-before-running-it/
image:
  caption: ''
  focal_point: 'Center'
  preview_only: true
projects: []
---

## Overview

pilotr makes a planned study executable before data collection. A portable specification describes the units, predictors, response family, fixed effects and random-effects structure; the same specification can then be simulated and analysed from R or Python. The important output is not a single power percentage, but a design diagnosis that includes detection, precision, Type S and Type M errors, and model warnings.

## Illustrative outputs

These plots show the complementary questions that a simulation-based design analysis should answer: how often the target effect is detected, how precisely it is estimated and how much significant estimates are exaggerated.

<figure>
<img src="images/power-curve-1.png" alt="Illustrative power curve for a priming effect across sample sizes, with an 80 percent reference line" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>Detection probability across participant counts.</figcaption>
</figure>

<figure>
<img src="images/precision-curve-1.png" alt="Two-panel precision plot showing the probability of excluding a negligible effect and mean confidence-interval width as sample size increases" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>Precision and the probability that an interval excludes a pre-specified negligible-effect region.</figcaption>
</figure>

<figure>
<img src="images/type-m-plot-1.png" alt="Type M error declining towards one as power increases across effect-size and sample-size simulations" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>Magnitude exaggeration among statistically significant estimates.</figcaption>
</figure>

## Reproducible planning

Treat the specification, simulation seed, package version, number of replicates and fitted model as part of the planning record. The smoke-test settings in the [companion blog post](/2026/pilotr-pilot-the-study-before-running-it/) demonstrate the pipeline; a real design decision requires many more replicates and a sensitivity analysis over plausible assumptions. Explore the full [R documentation](https://pablobernabeu.github.io/pilotr/r/), [Python documentation](https://pablobernabeu.github.io/pilotr/python/) or [browser app](https://pablobernabeu.github.io/pilotr/app/).

## Reference

Bernabeu, P. (2026). *pilotr: Simulate experimental and behavioural data from a portable design specification* (Version 0.3.0) [Computer software]. Zenodo. https://doi.org/10.5281/zenodo.21266313
