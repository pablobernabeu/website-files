---
title: "theoryforge: Systematic theory development"
type: software
software_kind:
  - package
  - web-application
aliases:
  - '/publication/theoryforge/'
authors:
  - 'Bernabeu, P.'
date: '2026-09-01'
apa_captions: true
slug: theoryforge
publication: 'Version 0.6.0 [Computer software]. CRAN'
doi: 10.32614/CRAN.package.theoryforge
categories:
  - software
tags:
  - software
  - R
  - Python
  - theory
  - metascience
  - preregistration
abstract: 'Twin R and Python packages for representing scientific theories as versioned, machine-checkable objects. theoryforge validates theory files, evaluates their specification, derives testable implications, compares amendments, and exports diagrams and preregistration materials.'
summary: 'Versioned, machine-checkable scientific theories in R and Python.'
featured: no
open_materials: true
url_code: https://github.com/pablobernabeu/theoryforge
links:
  - name: R documentation
    url: https://pablobernabeu.github.io/theoryforge/r/
  - name: Python documentation
    url: https://pablobernabeu.github.io/theoryforge/python/
  - name: Browser apps
    url: https://pablobernabeu.github.io/theoryforge/
  - name: CRAN
    url: https://CRAN.R-project.org/package=theoryforge
  - name: PyPI
    url: https://pypi.org/project/theoryforge/
  - name: Blog post
    url: /2026/theoryforge-a-theory-you-can-check/
package_docs:
  - name: R documentation
    url: https://pablobernabeu.github.io/theoryforge/r/
  - name: Python documentation
    url: https://pablobernabeu.github.io/theoryforge/python/
  - name: Browser apps
    url: https://pablobernabeu.github.io/theoryforge/
image:
  caption: ''
  focal_point: 'Center'
  preview_only: true
projects: []
---

## Overview

theoryforge (Bernabeu, 2026) represents a scientific theory as a versioned, machine-checkable document. Constructs, propositions, predictions, alternatives and provenance are linked by identifiers, so the package can validate the specification, derive implications, compare amendments and export a reviewable dossier. The checks assess the completeness and internal coherence of a specification, which is a separate matter from whether the theory is true. Figure 1 sets out that workflow, from the theory file to the dossier.

<figure>
<img src="images/theoryforge-workflow.svg" alt="Workflow diagram: a structured theory file is validated, used to derive testable implications, compared with a rival theory and preserved as a versioned dossier" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>The Dashed Return Path Carries an Amended Theory Back Through the Same Checks That the First Version Passed.</figcaption>
</figure>

## Reproducible theory development

Store the theory document, schema version, validation report, derived implications, data-generating assumptions and checksum together. The [R documentation](https://pablobernabeu.github.io/theoryforge/r/), [Python documentation](https://pablobernabeu.github.io/theoryforge/python/), [browser apps](https://pablobernabeu.github.io/theoryforge/) and [companion blog post](/2026/theoryforge-a-theory-you-can-check/) show how the same specification supports formalisation, testing and preregistration.

## Reference

Bernabeu, P. (2026). *theoryforge: Systematic theory development* (Version 0.6.0) [Computer software]. CRAN. https://doi.org/10.32614/CRAN.package.theoryforge
