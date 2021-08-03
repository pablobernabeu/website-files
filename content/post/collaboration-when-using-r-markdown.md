---
title: Collaboration while using R Markdown
author: Pablo
date: '2020-10-03'
slug: collaboration-while-using-R-markdown
categories:
  - research methods
  - R
tags:
  - R
  - R Markdown
subtitle: 'Advice based on a presentation by Michael Frank'
summary: ''
authors: []
lastmod: ''
featured: no
image:
  caption: ''
  focal_point: ''
  preview_only: no
projects: []
---


In a highly recommendable [presentation available on Youtube](https://www.youtube.com/watch?v=Nj9J5iCSMB0), **Michael Frank** walks us through R Markdown. Below, I loosely summarise and partly elaborate on Frank's advice regarding collaboration among colleagues, some of whom may not be used to R Markdown ([see relevant time point in Frank's presentation](https://www.youtube.com/watch?v=Nj9J5iCSMB0&feature=youtu.be&t=2900&ab_channel=MichaelFrank)).

1. The first way is to use GitHub, which has a great version control system, and even allows the rendering of Markdown text, if the file is given the extension '.md' on GitHub. Furthermore, GitHub has made private repositories with any number of collaborators free.

2. The second way is to copy the text part of the unrendered R Markdown doc (i.e., excluding any long code chunks) to Word or Google Docs, or any other trackable editor. The collaborators would then edit the text, and refrain from editing any of the R or Markdown code (i.e., any inline code, hashes, etc.). Changes would be tracked and accepted (any unwanted edits of the code may be undone), and transferred to the original document. 

3. The third way is to knit the document to Word, which allows tracking changes, or otherwise to knit to PDF.
