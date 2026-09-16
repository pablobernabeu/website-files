---
abstract: 'We tested whether conceptual processing is modality-specific by tracking the time course of the Conceptual Modality Switch effect. Forty-six participants verified the relation between property words and concept words. The conceptual modality of consecutive trials was manipulated in order to produce an Auditory-to-visual switch condition, a Haptic-to-visual switch condition, and a Visual-to-visual, no-switch condition. Event-Related Potentials (ERPs) were time-locked to the onset of the first word (property) in the target trials so as to measure the effect online and to avoid a within-trial confound. A switch effect was found, characterized by more negative ERP amplitudes for modality switches than no-switches. It proved significant in four typical time windows from 160 to 750 milliseconds post word onset, with greater strength in posterior brain regions, and after 350 milliseconds. These results suggest that conceptual processing may be modality-specific in certain tasks, but also that the early stage of processing is relatively amodal.'
type: software
software_kind: web-application
aliases:
  - '/applications-and-dashboards/bernabeu-etal-2017-modalityswitch/'
authors:
date: "2017-01-01"
diagram: true
# doi: "https://doi.org/10.31234/osf.io/a5pcz"
featured: false
image:
  caption: ''
  focal_point: ""
  preview_only: false
links:
- name: Web application
  url: 'https://pablobernabeu.shinyapps.io/ERP-waveform-visualization_CMS-experiment/'
- name: Research paper
  url: '/publication/bernabeu-etal-2017/'
- name: Master's thesis
  url: '/publication/bernabeu-2017-mphil-thesis/'
#  projects:
# - internal-project
publishDate: "2017-01-01"
publication:
publication_short:
# slides: example
summary: 'Shiny web application for exploring the event-related potentials (ERPs) from a conceptual modality switch experiment by group of participants, individual participant, brain area and electrode.'
categories:
- conceptual processing
- R
- web application
- research and teaching applications
tags:
- web application
- data dashboard
- R
- R Shiny
- conceptual modality switch
- conceptual processing
- reading
- event-related potentials
- cognition
- psycholinguistics
- HTML
- CSS
title: 'Modality switch effects emerge early and increase throughout conceptual processing'
url_code: 'https://github.com/pablobernabeu/Modality-switch-effects-emerge-early-and-increase-throughout-conceptual-processing/tree/master/Shiny-app'
url_data: 'https://github.com/pablobernabeu/Modality-switch-effects-emerge-early-and-increase-throughout-conceptual-processing/tree/master/Shiny-app'
url_fulltext: 'https://psyarxiv.com/a5pcz'
# url_poster: '#'
# url_project: ""
# url_slides: ""
# url_source: '#'
# url_video: '#'
---

<a href='https://pablobernabeu.shinyapps.io/ERP-waveform-visualization_CMS-experiment/'>
      <button style = "background-color: white; color: black; border: 2px solid #4CAF50; border-radius: 12px;">
      <h3 style = "margin-top: 7px !important; margin-left: 9px !important; margin-right: 9px !important;"> 
      <span style="color:#DBE6DA;"></span> Web application </h3></button></a> &nbsp;

<br>
<br>

### How it works
{{< diagram >}}
graph TD
  A["EEG-ERP data from word<br/>comprehension experiment"] --> B["ERP plots spanning 800 ms<br/>of word processing"]
  B --> C["Groups of participants"]
  C --> D["Individual participants"]
  D --> E["Brain areas"]
  E --> F["Electrodes"]
  B --> G["Download HD plots, view<br/>95% confidence intervals"]
{{< /diagram >}}

The data come from a psychology experiment on word comprehension in which electroencephalographic (EEG) responses were measured. The plots span the first 800 milliseconds of word processing. The app is intended to help researchers and the public explore the data at four levels, from the broadest to the most specific: groups of participants, individual participants, brain areas and electrodes.

By creating this app, I tried to reach beyond the scope of open science at the time, which was often confined to files shared on data repositories. I made the case for using Shiny apps in science in a [blog post](/2017/the-case-for-data-dashboards-first-steps-in-r-shiny/) and in [slides](https://www.slideshare.net/PabloBernabeu/presenting-data-interactively-online-using-r-shiny-126064157).

### Technical details

I placed tabs at the top of the page to avoid cramming the sidebar with widgets. I adjusted the appearance of these tabs and used reactive conditions to change the inputs in the sidebar depending on the active tab.

```
mainPanel(

	tags$style(HTML('
	    .tabbable > .nav > li > a                  		{background-color:white; color:#3E454E}
	    .tabbable > .nav > li > a:hover            		{background-color:#002555; color:white}
	    .tabbable > .nav > li[class=active] > a 		{background-color:#ECF4FF; color:black}
	    .tabbable > .nav > li[class=active] > a:hover	{background-color:#E7F1FF; color:black}
	')),

	tabsetPanel(id='tabvals',

            tabPanel(value=1, h4(strong('Group & Electrode')), br(), plotOutput('plot_GroupAndElectrode'),
			h5(a(strong('See plots with 95% Confidence Intervals'), href='https://osf.io/2tpxn/',
			target='_blank'), style='text-decoration: underline;'), 
			downloadButton('downloadPlot.1', 'Download HD plot'), br(), br(),
			# EEG montage
			img(src='https://preview.ibb.co/n7qiYR/EEG_montage.png', height=500, width=1000)),

            tabPanel(value=2, h4(strong('Participant & Area')), br(), plotOutput('plot_ParticipantAndLocation'),
			h5(a(strong('See plots with 95% Confidence Intervals'), href='https://osf.io/86ch9/',
			target='_blank'), style='text-decoration: underline;'), 
			downloadButton('downloadPlot.2', 'Download HD plot'), br(), br(),
			# EEG montage
			img(src='https://preview.ibb.co/n7qiYR/EEG_montage.png', height=500, width=1000)),

            tabPanel(value=3, h4(strong('Participant & Electrode')), br(), plotOutput('plot_ParticipantAndElectrode'),
			br(), downloadButton('downloadPlot.3', 'Download HD plot'), br(), br(),
			# EEG montage
			img(src='https://preview.ibb.co/n7qiYR/EEG_montage.png', height=500, width=1000)),

            tabPanel(value=4, h4(strong('OLD Group & Electrode')), br(), plotOutput('plot_OLDGroupAndElectrode'),
			h5(a(strong('See plots with 95% Confidence Intervals'), href='https://osf.io/dvs2z/',
			target='_blank'), style='text-decoration: underline;'), 
			downloadButton('downloadPlot.4', 'Download HD plot'), br(), br(),
			# EEG montage
			img(src='https://preview.ibb.co/n7qiYR/EEG_montage.png', height=500, width=1000))
	),
```

The data set was fairly large for an app hosted on a free plan. To lighten the processing, I split the data into several files and reduced their total size. I also moved a particularly heavy set of plots, those with confidence intervals, to PDF files linked from the app.

```
h5(a(strong('See plots with 95% Confidence Intervals'), href='https://osf.io/dvs2z/',
			target='_blank'), style='text-decoration: underline;'),
```

The app links to the published paper, the raw data and its own _server_ and _ui_ scripts. The scripts and the data used by the app are available [on GitHub](https://github.com/pablobernabeu/Modality-switch-effects-emerge-early-and-increase-throughout-conceptual-processing/tree/master/Shiny-app) and archived on Zenodo (Bernabeu, 2024).

Each tab has a button to download the plot in high resolution, as shown below for the first tab.


```
# From server.R script

spec_title = paste0('ERP waveforms for ', input$var.Group, ' Group, Electrode ', input$var.Electrodes.1, ' (negative values upward; time windows displayed)')

plot_GroupAndElectrode = ggplot(df2, aes(x=time, y=-microvolts, color=condition)) +
  geom_rect(xmin=160, xmax=216, ymin=7.5, ymax=-8, color = 'grey75', fill='black', alpha=0, linetype='longdash') +
  geom_rect(xmin=270, xmax=370, ymin=7.5, ymax=-8, color = 'grey75', fill='black', alpha=0, linetype='longdash') +
  geom_rect(xmin=350, xmax=550, ymin=8, ymax=-7.5, color = 'grey75', fill='black', alpha=0, linetype='longdash') +
  geom_rect(xmin=500, xmax=750, ymin=7.5, ymax=-8, color = 'grey75', fill='black', alpha=0, linetype='longdash') +
  geom_line(size=1, alpha = 1) + scale_linetype_manual(values=colours) +
  scale_y_continuous(limits=c(-8.38, 8.3), breaks=seq(-8,8,by=1), expand = c(0,0.1)) +
  scale_x_continuous(limits=c(-208,808),breaks=seq(-200,800,by=100), expand = c(0.005,0), labels= c('-200','-100 ms','0','100 ms','200','300 ms','400','500 ms','600','700 ms','800')) +
  ggtitle(spec_title) + theme_bw() + geom_vline(xintercept=0) +
  annotate(geom='segment', y=seq(-8,8,1), yend=seq(-8,8,1), x=-4, xend=8, color='black') +
  annotate(geom='segment', y=-8.2, yend=-8.38, x=seq(-200,800,100), xend=seq(-200,800,100), color='black') +
  geom_segment(x = -200, y = 0, xend = 800, yend = 0, size=0.5, color='black') +
  theme(legend.position = c(0.100, 0.150), legend.background = element_rect(fill='#EEEEEE', size=0),
	axis.title=element_blank(), legend.key.width = unit(1.2,'cm'), legend.text=element_text(size=17),
	legend.title = element_text(size=17, face='bold'), plot.title= element_text(size=20, hjust = 0.5, vjust=2),
	axis.text.y = element_blank(), axis.text.x = element_text(size = 14, vjust= 2.12, face='bold', color = 'grey32', family='sans'),
	axis.ticks=element_blank(), panel.border = element_blank(), panel.grid.major = element_blank(), 
	panel.grid.minor = element_blank(), plot.margin = unit(c(0.1,0.1,0,0), 'cm')) +
  annotate('segment', x=160, xend=216, y=-8, yend=-8, colour = 'grey75', size = 1.5) +
  annotate('segment', x=270, xend=370, y=-8, yend=-8, colour = 'grey75', size = 1.5) +
  annotate('segment', x=350, xend=550, y=-7.5, yend=-7.5, colour = 'grey75', size = 1.5) +
  annotate('segment', x=500, xend=750, y=-8, yend=-8, colour = 'grey75', size = 1.5) +
  scale_fill_manual(name = 'Context / Target trial', values=colours) +
  scale_color_manual(name = 'Context / Target trial', values=colours) +
  guides(linetype=guide_legend(override.aes = list(size=1.2))) +
   guides(color=guide_legend(override.aes = list(size=2.5))) +
# Print y axis labels within plot area:
  annotate('text', label = expression(bold('\u2013' * '3 ' * '\u03bc' * 'V')), x = -29, y = 3, size = 4.5, color = 'grey32', family='sans') +
  annotate('text', label = expression(bold('+3 ' * '\u03bc' * 'V')), x = -29, y = -3, size = 4.5, color = 'grey32', family='sans') +
  annotate('text', label = expression(bold('\u2013' * '6 ' * '\u03bc' * 'V')), x = -29, y = 6, size = 4.5, color = 'grey32', family='sans')

print(plot_GroupAndElectrode)

output$downloadPlot.1 <- downloadHandler(
	filename <- function(file){
	paste0(input$var.Group, ' group, electrode ', input$var.Electrodes.1, ', ', Sys.Date(), '.png')},
   	content <- function(file){
      		png(file, units='in', width=13, height=5, res=900)
      		print(plot_GroupAndElectrode)
      		dev.off()},
	contentType = 'image/png')
  } )
```

```
# From ui.R script

downloadButton('downloadPlot.1', 'Download HD plot')
```

### Rising to the challenge

In my first days with Shiny, I spent an eternity stuck on a single letter, "μ", which appeared in the labels of my plots (a micro-souvenir from hell, as I came to know it). The app ran perfectly on my laptop but could not be deployed online. Eventually, I read about UTF-8 encoding in a forum, and all I had to do was write "Âμ" instead of "μ". A better option I found later was `expression("\u03bc")`.

Embedding images was also tricky, as I could not get the usual `www` folder to work. Instead, I uploaded the images to a website and entered their URLs in `img(src)`, which avoided folder paths altogether.

```
img(src="https://preview.ibb.co/n7qiYR/EEG_montage.png 1", height=500, width=1000)
```

Later, I added one more image in the same way: the _favicon_, the small icon shown on the browser tab.

```
tags$head(tags$link(rel="shortcut icon", href="https://image.ibb.co/fXUwzb/favic.png")),  # web favicon
```

### References

Bernabeu, P. (2024). *Modality-switch-effects-emerge-early-and-increase-throughout-conceptual-processing* (Version 1.0.0) [Computer software]. Zenodo. https://doi.org/10.5281/zenodo.10616354

Bernabeu, P., Willems, R. M., & Louwerse, M. M. (2017). *Modality switch effects emerge early and increase throughout conceptual processing: Evidence from ERPs* [Web application]. https://pablobernabeu.shinyapps.io/ERP-waveform-visualization_CMS-experiment/
