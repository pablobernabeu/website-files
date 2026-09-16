---
abstract: 'Dashboard presenting open data from Prudic et al. (2018), who compared three ways of recording butterfly species richness in Los Angeles: Pollard walks by trained volunteers, Malaise traps with expert identification, and crowd-sourced iNaturalist observations. The coding involved reshaping the data to a long format, merging data sets and, as ever, wrangling with the layout of a table.'
type: software
software_kind: web-application
aliases:
  - '/applications-and-dashboards/butterfly-species-richness-in-la/'
authors:
date: "2020-01-01"
publishDate: "2020-01-01"
diagram: true
# doi:
featured: false
image:
  caption: ''
  focal_point: ""
  preview_only: false
links:
- name: Dashboard
  url: '/dashboards/Butterfly-species-richness-in-LA'
#  projects:
# - internal-project
publication:
publication_short:
# slides: example
summary: 
categories:
- web application
- research and teaching applications
- data visualisation
- R
tags:
- data dashboard
- R
- citizen science
- butterflies
- nature
- open data
- BioScan
- iNaturalist
- HTML
- CSS
- tidy
- merge
- Software Sustainability Institute Fellowship
title: 'Data dashboard: Butterfly species richness in Los Angeles'
url_code: 'https://github.com/pablobernabeu/Data-is-present/blob/master/examples-documents-dashboards/Dashboards/Flexdashboard/Butterfly-species-richness-in-LA.Rmd'
url_data: 'https://github.com/jcoliver/bioscan'
# url_fulltext: ''
# url_poster: '#'
# url_project: ""
# url_slides: ""
# url_source: '#'
# url_video: '#'
---


<a href='/dashboards/Butterfly-species-richness-in-LA'>
      <button style = "background-color: white; color: black; border: 2px solid #196F27; border-radius: 12px;">
      <h3 style = "margin-top: 7px !important; margin-left: 9px !important; margin-right: 9px !important;">
      <span style="color:#DBE6DA;"></span> Dashboard
      </h3></button>
      </a>

<br>
<br>

### How it works
{{< diagram >}}
graph TD
  A["Open data from<br/>Prudic et al. (2018)"] --> B["iNaturalist<br/>(crowd-sourced observations)"]
  A --> C["BioScan<br/>(Pollard walks and Malaise traps)"]
  B --> D["Reshape, merge<br/>and wrangle in R"]
  C --> D
  D --> E["Dashboard: butterfly species<br/>richness in Los Angeles"]
{{< /diagram >}}

This dashboard presents open data (<a href='https://github.com/jcoliver/bioscan/blob/master/data/iNaturalist-clean-reduced.csv'>iNaturalist</a> and <a href='https://github.com/jcoliver/bioscan/blob/master/data/BioScanDataComplete.csv'>BioScan</a>) from [Prudic et al. (2018)](https://doi.org/10.3390/insects9040186). The authors compared three ways of recording butterfly species richness in Los Angeles: Pollard walks by trained volunteers, Malaise traps with expert identification (both recorded in the BioScan data) and crowd-sourced iNaturalist observations.

I developed this dashboard after reproducing the [analyses of the original study](https://github.com/jcoliver/bioscan) in a [ReproHack session](https://github.com/reprohack/reprohack-hq/blob/master/README.md).

My coding tasks included transforming the data to a long format,

```
# There are pseudovariables, that is, observations entered as variables. 
# Since most R processes need the tidy format, convert below 
# (see https://r4ds.had.co.nz/tidy-data.html). The specific numbers 
# found through traps and crowdsourcing methods are preserved.

BioScan = BioScan %>% pivot_longer(
    cols = Anthocharis_sara:Vanessa_cardui, names_to = "Species",
    values_to = "Number", values_drop_na = TRUE
  )

# Compare
#str(BioScan)
#str(dat)
# 928 rows now; the result of 29 pseudo-variables being transposed 
# into rows, interacting with 32 previous rows, i.e., 29 * 32 = 928.
```


merging three data sets, 

```
# The iNaturalist data set presents a challenge that differs from the 
# pseudovariables found above. The number of animals of each species 
# must be computed from repeated entries, per site.

iNaturalist = merge(iNaturalist, 
                    iNaturalist %>% 
                      count(species, site, name = 'Number'))
```


and, as ever, wrangling with the layout of the dashboard pages to preserve the format of a table.

```
Species details {style="background-color: #FCFCFC;"}
=======================================================================

Column {style="data-width:100%; position:static; height:1000px;"}
-----------------------------------------------------------------------
```

### Reference

Prudic, K. L., Oliver, J. C., Brown, B. V., & Long, E. C. (2018). Comparisons of citizen science data-gathering approaches to evaluate urban butterfly diversity. *Insects, 9*(4), 186. https://doi.org/10.3390/insects9040186
