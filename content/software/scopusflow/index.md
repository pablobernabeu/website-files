---
title: "scopusflow: A reproducible workflow layer for Scopus bibliographic searches"
type: software
software_kind:
  - package
  - web-application
aliases:
  - '/publication/scopusflow/'
authors:
  - 'Bernabeu, P.'
date: '2026-08-21'
apa_captions: true
slug: scopusflow
publication: 'Version 0.4.0 [Computer software]. CRAN'
doi: 10.32614/CRAN.package.scopusflow
categories:
  - software
tags:
  - software
  - R
  - Python
  - bibliometrics
  - literature review
  - reproducibility
abstract: 'Twin R and Python packages for planning, running and documenting reproducible Scopus searches. scopusflow handles quotas and retries, supports resumable retrieval, normalises records, tracks changes in DOI sets, and produces PRISMA-S search records.'
summary: 'Reproducible, quota-aware Scopus searches in R and Python.'
featured: no
open_materials: true
url_code: https://github.com/pablobernabeu/scopusflow
links:
  - name: Python code
    url: https://github.com/pablobernabeu/scopusflow-py
  - name: R documentation
    url: https://pablobernabeu.github.io/scopusflow/
  - name: Python documentation
    url: https://pablobernabeu.github.io/scopusflow-py/
  - name: R app guide
    url: https://pablobernabeu.github.io/scopusflow/articles/using-the-app.html
  - name: Python app guide
    url: https://pablobernabeu.github.io/scopusflow-py/guides/the-app/
  - name: CRAN
    url: https://CRAN.R-project.org/package=scopusflow
  - name: PyPI
    url: https://pypi.org/project/scopusflow/
  - name: Blog post
    url: /2026/scopusflow-a-literature-search-you-can-rerun/
package_docs:
  - name: R documentation
    url: https://pablobernabeu.github.io/scopusflow/
  - name: Python documentation
    url: https://pablobernabeu.github.io/scopusflow-py/
image:
  caption: ''
  focal_point: 'Center'
  preview_only: true
projects: []
---

## Overview

scopusflow (Bernabeu, 2026) turns a bibliographic search from a one-off export into a versioned workflow. A plan records the query and can divide it into yearly cells. Completed cells can be cached so that an interrupted retrieval resumes where it stopped, and the resulting object retains the retrieval metadata, package version and DOI-level changes. The R and Python packages use the same workflow concepts while respecting the access and redistribution limits of the source database.

Both packages also ship a code-free app that drives the same workflow through a browser tab. Each runs on the researcher's own machine and by default listens on 127.0.0.1 alone, so the Scopus key never leaves it. `run_app()` starts the R version and the `scopusflow-gui` command starts the Python one.

<figure>
<img src="images/records-per-year-1.png" alt="Line chart showing the number of graphene-supercapacitor records in an offline demonstration corpus from 2015 to 2024" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>Retrieved Without an API Key From the Corpus Bundled With the Package. The counts show the workflow and say nothing about the Scopus literature on graphene supercapacitors.</figcaption>
</figure>

## Reproducible reporting

Keep the plan, cache manifest, native result object, DOI comparison and generated PRISMA-S record under version control. A future update can then distinguish a change in the literature from a change in the query, database coverage or retrieval process. Read the [R documentation](https://pablobernabeu.github.io/scopusflow/), [Python documentation](https://pablobernabeu.github.io/scopusflow-py/) and [companion blog post](/2026/scopusflow-a-literature-search-you-can-rerun/) for the offline and authenticated workflows.

## Reference

Bernabeu, P. (2026). *scopusflow: A reproducible workflow layer for Scopus bibliographic searches* (Version 0.4.0) [Computer software]. CRAN. https://doi.org/10.32614/CRAN.package.scopusflow
