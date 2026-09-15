---
title: "scopusflow: A reproducible workflow layer for Scopus bibliographic searches"
type: software
aliases:
  - '/publication/scopusflow/'
authors:
  - 'Bernabeu, P.'
date: '2026-08-21'
slug: scopusflow
publication_types:
  - '9'
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
abstract: 'Twin R and Python packages for planning, running and documenting reproducible Scopus searches. scopusflow handles quotas and retries, supports resumable retrieval, normalises records, tracks changes in DOI sets and produces PRISMA-S search records.'
summary: 'Reproducible, quota-aware Scopus searches in R and Python.'
featured: no
url_code: https://github.com/pablobernabeu/scopusflow
links:
  - name: R documentation
    url: https://pablobernabeu.github.io/scopusflow/
  - name: Python documentation
    url: https://pablobernabeu.github.io/scopusflow-py/
  - name: CRAN
    url: https://CRAN.R-project.org/package=scopusflow
  - name: PyPI
    url: https://pypi.org/project/scopusflow/
  - name: Blog post
    url: /2026/scopusflow-a-literature-search-you-can-rerun/
image:
  caption: ''
  focal_point: 'Center'
  preview_only: true
projects: []
---

## Overview

scopusflow treats a bibliographic search as a versioned workflow rather than a one-off export. A plan records the query and partitions, completed cells are cached for safe resumption, and the resulting object retains retrieval metadata, package version and DOI-level changes. The R and Python packages use the same workflow concepts while respecting the access and redistribution limits of the source database.

## Illustrative output

The example below uses the package's offline stand-in corpus, so the plot demonstrates the workflow rather than claiming to describe the live Scopus literature.

<figure>
<img src="images/records-per-year-1.png" alt="Line chart showing the number of graphene-supercapacitor records in an offline demonstration corpus from 2015 to 2024" loading="lazy" decoding="async" style="display:block;width:100%;height:auto;">
<figcaption>Records per year in the reproducible offline demonstration.</figcaption>
</figure>

## Reproducible reporting

Keep the plan, cache manifest, native result object, DOI comparison and generated PRISMA-S record under version control. A future update can then distinguish a change in the literature from a change in the query, database coverage or retrieval process. Read the [R documentation](https://pablobernabeu.github.io/scopusflow/), [Python documentation](https://pablobernabeu.github.io/scopusflow-py/) and [companion blog post](/2026/scopusflow-a-literature-search-you-can-rerun/) for the offline and authenticated workflows.

## Reference

Bernabeu, P. (2026). *scopusflow: A reproducible workflow layer for Scopus bibliographic searches* (Version 0.4.0) [Computer software]. CRAN. https://doi.org/10.32614/CRAN.package.scopusflow
