---
title: "lexsync: Lexical optimisation and hardware-timed experiment generation"
type: software
software_kind:
  - package
  - web-application
aliases:
  - '/publication/lexsync/'
authors:
  - 'Bernabeu, P.'
date: '2026-06-07'
apa_captions: true
slug: lexsync
publication: 'Version 0.1.0 [Computer software]. CRAN'
doi: 10.32614/CRAN.package.lexsync
categories:
  - software
tags:
  - software
  - R
  - Python
  - psycholinguistics
  - experimental stimuli
  - EEG
abstract: 'Twin R and Python packages for selecting and matching lexical stimuli, counterbalancing lists, generating pseudowords, and writing PsychoPy, OpenSesame and jsPsych experiments with hardware-timed EEG triggers.'
summary: 'Lexical stimulus matching and experiment generation in R and Python.'
featured: no
open_materials: true
url_code: https://github.com/pablobernabeu/lexsync
links:
  - name: R documentation
    url: https://pablobernabeu.github.io/lexsync/r/
  - name: Python documentation
    url: https://pablobernabeu.github.io/lexsync/python/
  - name: R app guide
    url: https://pablobernabeu.github.io/lexsync/r/articles/the-app.html
  - name: Python app guide
    url: https://pablobernabeu.github.io/lexsync/python/the-app/
  - name: CRAN
    url: https://CRAN.R-project.org/package=lexsync
  - name: Blog post
    url: /2026/lexsync-from-corpus-to-eeg-ready-experiment/
package_docs:
  - name: R documentation
    url: https://pablobernabeu.github.io/lexsync/r/
  - name: Python documentation
    url: https://pablobernabeu.github.io/lexsync/python/
image:
  caption: ''
  focal_point: 'Center'
  preview_only: true
projects: []
---

## Overview

lexsync (Bernabeu, 2026) turns a lexical design into a checked set of stimuli and experiment files. It separates the candidate corpus from the design specification, reports whether matching and counterbalancing succeeded, and carries the resulting item table into PsychoPy, OpenSesame or jsPsych. The shared R/Python format makes the design inspectable before any presentation software is involved.

The repository also carries two browser front-ends over the same engines, a Shiny app for R and a Streamlit app for Python. Each assembles a design through the interface, runs the same pipeline as the packages and exports the code that reproduces it. Launch either one from the repository root, so that it finds the bundled corpora and the example item tables.

The main quality-control question for a set of lexical materials is whether the conditions remain comparable on the control variables chosen by the researcher. lexsync answers it as a claim of equivalence, testing each control against a bound fixed before selection, so a control passes only when its interval stays inside that bound. Figure 1 reports that test for the example design.

<figure>
<img src="images/balance-plot-1.png" alt="Standardised differences between low- and high-frequency conditions on word length, neighbourhood density and OLD20, with 90 per cent confidence intervals inside a shaded equivalence region from minus to plus 0.5" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>Each Control Tested Against the Schema's Default Equivalence Bound of Half a Standard Deviation, Chosen Before Selection Begins.</figcaption>
</figure>

## Reproducible hand-off

Save the design, the source lexicon, the matching report and the generated experiment together. Before recording EEG, verify the exported timing, trigger codes, trial order and counterbalancing in the target presentation framework. The [R documentation](https://pablobernabeu.github.io/lexsync/r/), [Python documentation](https://pablobernabeu.github.io/lexsync/python/) and [companion blog post](/2026/lexsync-from-corpus-to-eeg-ready-experiment/) provide the complete workflow.

## Reference

Bernabeu, P. (2026). *lexsync: Lexical optimisation and hardware-timed experiment generation* (Version 0.1.0) [Computer software]. CRAN. https://doi.org/10.32614/CRAN.package.lexsync
