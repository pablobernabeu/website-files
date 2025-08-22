+++
# A Demo section created with the Blank widget.
# Any elements can be added in the body: https://sourcethemes.com/academic/docs/writing-markdown-latex/
# Add more sections by duplicating this file and customizing to your requirements.

widget = "blank"  # See https://sourcethemes.com/academic/docs/page-builder/
headless = true  # This file represents a page section.
active = true  # Activate this widget? true/false
weight = 150  # Order that this section will appear.

title = "Videos and Podcasts"
subtitle = "Not the most riveting channel on [YouTube](https://www.youtube.com/channel/UCm3CfloakLprTWQuwjyjI2Q)—much less aurally exciting on [Spotify](https://open.spotify.com/show/4QXENVjprdaGkTvOexGvD3). <br> <div style = 'position: relative; margin-top: 20px; padding-top: 56.25%;'><iframe src='https://www.youtube-nocookie.com/embed/nh7E1L8Evc8' frameborder='0' allowfullscreen style = 'position:absolute; top:0; left:0; width:70%; height:100%;'></iframe></div>"

[design]
# Choose how many columns the section has. Valid values: 1 or 2.
columns = "2"

[design.background]
# Apply a background color, gradient, or image.
#   Uncomment (by removing `#`) an option to apply it.
#   Choose a light or dark text color by setting `text_color_light`.
#   Any HTML color name or Hex value is valid.

# Background color.
# color = "navy"

# Background gradient.
# gradient_start = "DeepSkyBlue"
# gradient_end = "SkyBlue"

# Background image.
# image = "headers/bubbles-wide.jpg"  # Name of image in `static/img/`.
# image_darken = 0.6  # Darken the image? Range 0-1 where 0 is transparent and 1 is opaque.
# image_size = "cover"  #  Options are `cover` (default), `contain`, or `actual` size.
# image_position = "center"  # Options include `left`, `center` (default), or `right`.
# image_parallax = true  # Use a fun parallax-like fixed background effect? true/false

# Text color (true=light or false=dark).
text_color_light = false

[design.spacing]
# Customize the section spacing. Order is top, right, bottom, left.
padding = ["100px", "0", "100px", "0"]

[advanced]
# Custom CSS. 
css_style = ""

# CSS class.
css_class = ""
+++


<div style = "margin-bottom: -2.5%;"></div>


### <span style='color:grey; font-size:70%;'>2025 ·</span>&nbsp; The architecture of meaning: Inside the words we use

<div class="max-w-2xl w-full p-6">

<!-- This wrapper controls the state of the component -->
<div id="collapsible-wrapper" class="collapsible-text-wrapper">

<!-- This div contains the text that will be collapsed -->
<div id="collapsible-content" class="collapsible-text-content">
<p id="main-text" class="text-base leading-relaxed mb-0">

What happens in your brain when you understand a simple word? It seems instantaneous, but this seemingly simple act is at the heart of one of the deepest mysteries of the human mind and has sparked one of the longest-running debates in cognitive science.

In this episode of Codex Mentis, we journey deep into the architecture of meaning to explore the battle between two powerful ideas. For decades, scientists were divided. Is your brain a vast, abstract dictionary, processing words like 'kick' by looking up amodal symbols and their connections to other symbols? Or is it a sophisticated simulator, where understanding 'kick' involves partially re-enacting the physical experience in your motor cortex?

We begin with a landmark finding—the 'object orientation effect'—that seemed to provide a knockout punch for the simulation theory, only to see this cornerstone of embodied cognition crumble under the immense rigor of a massive, multi-lab replication study involving thousands of participants across 18 languages. This 'failed' replication didn't end the debate; it forced the entire field to evolve, moving beyond simple dichotomies and toward a more nuanced and profound understanding of the mind.

This episode unpacks the state-of-the-art 'hybrid' model of conceptual processing, which is at the forefront of modern cognitive science. Discover how your brain pragmatically and flexibly uses two complementary systems in a dynamic partnership. The first is a fast, efficient language system that operates on statistical patterns, much like a modern AI, providing a 'shallow' but rapid understanding of a word's context. The second is a slower, more resource-intensive sensorimotor system that provides 'deep' grounding by simulating a word's connection to our lived, bodily experience.

The episode delves into the groundbreaking research from Pablo Bernabeu's 2022 thesis, which reveals that the interplay between these two systems is not fixed but constantly adapts based on three critical levels:

1. The task: The brain strategically deploys simulation only when a task demands deep semantic processing, conserving cognitive energy for shallower tasks.

2. The word: Concrete concepts like 'hammer' rely more heavily on sensorimotor simulation than abstract concepts like 'justice'.

3. The individual: We explore the fascinating 'task-relevance advantage,' a consistent finding that a larger vocabulary isn't just about knowing more words, but about possessing the cognitive finesse to flexibly and efficiently deploy the right mental system for the job at hand.

We also pull back the curtain on the science itself, discussing the 'replication crisis' and the immense statistical power needed to reliably detect these subtle cognitive effects—often requiring over 1,000 participants for a single experiment. This methodological deep dive reveals why the science of the mind requires massive, collaborative efforts to move forward.

Finally, we look to the future, exploring how the recent explosion of Large Language Models (LLMs) provides a fascinating test case for these theories, and how new frontiers like interoception—our sense of our body's internal state—are expanding the very definition of embodiment to help explain our grasp of abstract concepts like 'anxiety' or 'hope'.

This is a comprehensive exploration of the intricate, context-dependent dance between language and body that creates meaning in every moment. It will fundamentally change the way you think about the words you use every day.

</p>
</div>

<!-- The "Continue reading button. It is a block-level element that sits after the text container. -->

<button id="read-more-btn" class="read-more-btn link-style-button mt-2" onclick="
  console.log('Inline onclick fired!');
  event.preventDefault();
  event.stopPropagation();
  var wrapper = document.getElementById('collapsible-wrapper');
  var content = document.getElementById('collapsible-content');
  if (wrapper && content) {
    content.style.maxHeight = content.scrollHeight + 'px';
    wrapper.classList.add('is-expanded');
    console.log('Expansion successful via inline onclick!');
  } else {
    console.log('Elements not found in inline onclick');
  }
">
Continue reading...
</button>

</div>
</div>

<div style = "position: relative; margin-top: 20px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/1lulQ8vyEN4" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2025 ·</span>&nbsp; Segmentation of ERPs involving several markers and time adjustments in BrainVision Analyzer

This live demonstration guides you through the process of segmenting event-related potentials (ERPs) in BrainVision Analyzer. The events of interest are represented by several markers, requiring some thought to time-lock each segmentation to the event onset.

<div style = "position: relative; margin-top: 20px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/QXOpa-uOBVc" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2025 ·</span>&nbsp; Visualising EEG effects with topographic mapping in BrainVision Analyzer

This tutorial walks through the key steps: creating grand averages across participants, computing difference waves between experimental conditions, selecting appropriate map types, and defining time windows for visualisation.

<div style = "position: relative; margin-top: 20px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/FI9FO7oJj_o" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2025 ·</span>&nbsp; Naming results files exported from Gorilla Experiment Builder

<div style = "position: relative; margin-top: 20px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/nVidNO8xcxE" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2024 ·</span>&nbsp; [Reducing the impedance in electroencephalography using a blunt needle, electrolyte gel and wiggling](/2024/lowering-impedance-in-electroencephalography-using-a-blunt-needle-electrolyte-gel-and-wiggling)

<div style = "position: relative; margin-top: 20px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/4KLtp-WnOOo" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2024 ·</span>&nbsp; [Briefing participants to prevent muscle artifacts in electroencephalography sessions](/2024/preventing-muscle-artifacts-in-electroencephalography-sessions)

<div style = "position: relative; margin-top: 20px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/9Mbv6bUZlqY" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2021 ·</span>&nbsp; [Linguistic and embodied systems in conceptual processing: Variation across individuals and items](/presentation/linguistic-and-embodied-systems-in-conceptual-processing-variation-across-individuals-and-items)

<div style = "position: relative; margin-top: 20px;">
<a href = 'https://www.youtube.com/watch?v=y2bopgYWYvE&ab_channel=LancasterPsychology'>
<img src = '/presentation/linguistic-and-embodied-systems-in-conceptual-processing-variation-across-individuals-and-items/img/thumbnail.png'></a>
</div>

<div style = 'padding-bottom: 3.5%;'></div>

### <span style='color:grey; font-size:70%;'>2020 ·</span>&nbsp; [Reproducibilidad en torno a una aplicación web](/presentation/2020-10-08-reproducibilidad-en-torno-a-una-aplicacion-web)

<div style = "position: relative; margin-top: 20px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/1njLOAWqLPM" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2020 ·</span>&nbsp; Workshop on <i class="fa-brands fa-r-project" aria-label="R"></i> Markdown, dashboards and Binder (see [programme and materials](https://github.com/pablobernabeu/CarpentryCon-2020-workshop-Open-Data-Reproducibility))

<div style = "position: relative; margin-top: 20px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/wZsPD7CgJC0" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2020 ·</span>&nbsp; Personal profile and experience at Lancaster University Department of Psychology

<div style = "position: relative; margin-top: 20px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/ZEoan5tWqFg" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2020 ·</span>&nbsp; Embedding open research and reproducibility in the UG and PGT curricula

<div style = "position: relative; margin-top: 20px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/vzkDBZ1qWfY" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2019 ·</span>&nbsp; Part of application for [Gorilla Grant](#funding-awards)

<div style = "position: relative; margin-top: 20px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/DTHFuC0Lw0Y" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2019 ·</span>&nbsp; Part of application for [Software Sustainability Institute Fellowship](#funding-awards)

<div style = "position: relative; margin-top: 20px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/F-MQ8BYwLn4" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2019 ·</span>&nbsp; Demonstration of procedure for bundled PSA Studies [002](/publication/chen-etal-inprep) and [003](/publication/multi-region-investigation-of-man-as-default-in-attitudes)

<iframe src="https://mfr.de-1.osf.io/render?url=https://osf.io/download/h36wr/?direct%26mode=render"
    style="margin-top:10px"
    width="100%"
    scrolling="yes"
    height="394px"
    marginheight="0"
    frameborder="0"
    allowfullscreen
    webkitallowfullscreen>
</iframe>
