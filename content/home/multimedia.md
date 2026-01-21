+++
# A Demo section created with the Blank widget.
# Any elements can be added in the body: https://sourcethemes.com/academic/docs/writing-markdown-latex/
# Add more sections by duplicating this file and customizing to your requirements.

widget = "blank"  # See https://sourcethemes.com/academic/docs/page-builder/
headless = true  # This file represents a page section.
active = true  # Activate this widget? true/false
weight = 150  # Order that this section will appear.

title = "Videos and Podcasts"
subtitle = "<div style='display: flex; align-items: center; gap: 30px;'><div style='flex: 0 0 20%; margin-left: 15px;'><div style='position: relative; width: 100%; padding-top: 56.25%;'><iframe src='https://www.youtube-nocookie.com/embed/nh7E1L8Evc8' frameborder='0' allowfullscreen style='position: absolute; top: 0; left: 0; width: 100%; height: 100%;'></iframe></div></div><div style='flex: 1; max-width: 400px;'>Not the most riveting channel on <a href='https://www.youtube.com/@pablo-bernabeu/videos'>YouTube</a>—much less on <a href='https://open.spotify.com/show/4QXENVjprdaGkTvOexGvD3'>Spotify</a>, <a href='https://podcasts.apple.com/us/podcast/codex-mentis-science-and-technology-to-study-cognition/id1837010092'>Apple Podcasts</a> or <a href='https://www.ivoox.com/en/podcast-codex-mentis-science-and-tech-to-study-cognition_sq_f12741704_1.html'>iVoox</a>.</div></div>"

[design]
# Choose how many columns the section has. Valid values: 1 or 2.
columns = "1"

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


<div style = "margin-bottom: 4%;"></div>

<button id="toggle-all-summaries" style="padding: 8px 16px; margin-bottom: 1rem; background-color: #059669; color: #ffffff; border: 1px solid #047857; border-radius: 4px; cursor: pointer; font-size: 0.9em; transition: all 0.2s ease;">
  <i class="fas fa-chevron-down"></i> Expand all video descriptions
</button>

<script>
document.addEventListener('DOMContentLoaded', function() {
  const toggleButton = document.getElementById('toggle-all-summaries');
  const summaries = document.querySelectorAll('#multimedia .multimedia-summary');
  
  // Add theme-aware hover effect
  toggleButton.addEventListener('mouseenter', function() {
    const isDark = document.body.classList.contains('dark');
    this.style.backgroundColor = isDark ? '#047857' : '#d1fae5';
    this.style.color = isDark ? '#ffffff' : '#000000';
  });
  
  toggleButton.addEventListener('mouseleave', function() {
    this.style.backgroundColor = '#059669';
    this.style.color = '#ffffff';
  });
  
  toggleButton.addEventListener('click', function() {
    const isExpanding = this.innerHTML.includes('Expand');
    
    summaries.forEach(summary => {
      if (isExpanding) {
        summary.classList.add('is-expanded');
      } else {
        summary.classList.remove('is-expanded');
      }
    });
    
    this.innerHTML = isExpanding ? '<i class="fas fa-chevron-up"></i> Collapse all video descriptions' : '<i class="fas fa-chevron-down"></i> Expand all video descriptions';
  });
});
</script>


### <span style='color:grey; font-size:70%;'>2025 ·</span>&nbsp; The digital parrot or the universal machine? Debating the mind in the model

<div class="multimedia-summary">

<div style='margin: -5px 0 2px 0;'><i class="fa-solid fa-wand-magic-sparkles" style='color:darkgrey; font-size:75%;'></i> <span style='color:darkgrey; font-style:italic; font-size:85%;'>Created using Google Gemini and NotebookLM.</span></div>

Can a machine that writes Shakespearean sonnets about traffic jams actually help us understand the human soul? In this episode of Codex Mentis, we dive into a 'potential bomb' thrown into the heart of cognitive science: the rise of Large Language Models (LLMs) and their challenge to how we think humans learn to speak.

For fifty years, the 'nativist' view, championed by Noam Chomsky, argued that children are born with a 'built-in grammar' because the speech they hear is too messy and 'impoverished' to learn from scratch—a concept known as the Poverty of Stimulus. However, new research suggests LLMs provide an 'existence proof' that complex grammar can indeed be mastered through pure statistical patterns alone, potentially refuting half a century of linguistic theory.

But are these models truly 'brain-like,' or are we looking at a 'Cessna vs. Bird' problem? While both an aircraft and a bird achieve flight, their internal mechanisms are worlds apart. We explore the rigorous 'Four Questions' framework from ethologist Niklas Tinbergen to see where the comparison between silicon and synapse breaks down—from the lack of biological evolution to the 'unimodal' nature of text-only training.

We also tackle the 'Grounding Problem' and the 'Spanish Dictionary' thought experiment: can a model truly 'understand' a sunset if it has only ever read descriptions of one? We discuss the fascinating dissociation between formal linguistic competence (grammar) and functional competence (thought), and why the model's greatest failures—like its inability to handle unwritten sign languages or pass the BabyLM Challenge—might be its most important scientific gifts.

Join us as we determine if LLMs are a new theory of the mind or simply the sharpest tool cognitive science has ever been handed.

**References (in order of mention in the audio):**

<div style="padding-left: 2em; text-indent: -2em;">

Chomsky, N. (1980). *Rules and representations*. MIT Press. https://doi.org/10.1017/S0140525X0000...

Contreras Kallens, P., Kristensen-McLachlan, R. D., & Christiansen, M. H. (2023). Large language models demonstrate the potential of statistical learning in language. *Cognitive Science*, *47*(3), e13256. https://doi.org/10.1111/cogs.13256

Piantadosi, S. T. (2024). Modern language models refute Chomsky's approach to language. In E. Gibson & M. Poliak (Eds.), *From fieldwork to linguistic theory: A tribute to Dan Everett* (pp. 353–414). Language Science Press. https://doi.org/10.5281/zenodo.12665933

Cuskley, C., Woods, R., & Flaherty, M. (2024). The limitations of large language models for understanding human language and cognition. *Open Mind: Discoveries in Cognitive Science*, *8*, 1058–1083. https://doi.org/10.1162/opmi_a_00160

Tinbergen, N. (1963). On aims and methods of ethology. *Zeitschrift für Tierpsychologie*, *20*(4), 410–433. https://doi.org/10.1111/j.1439-0310.1...

Schrimpf, M., Blank, I. A., Tuckute, G., Kauf, C., Hosseini, E. A., Kanwisher, N., Tenenbaum, J. B., & Fedorenko, E. (2021). The neural architecture of language: Integrative modeling converges on predictive processing. *Proceedings of the National Academy of Sciences*, *118*(45), e2105646118. https://doi.org/10.1073/pnas.2105646118

Goldstein, A., Zada, Z., Buchnik, E., Schain, M., Price, A., Aubrey, B., Nastase, S. A., Feder, A., Emanuel, D., Cohen, A., Jansen, A., Gazula, H., Choe, G., Rao, A., Kim, C., Casto, C., Fanda, L., Doyle, W., Friedman, D. … Hasson, U. (2022). Shared computational principles for language processing in humans and deep language models. *Nature Neuroscience*, *25*, 369–380. https://psycnet.apa.org/doi/10.1038/s...

Bender, E. M., & Koller, A. (2020). Climbing towards NLU: On meaning, form, and understanding in the age of data. In *Proceedings of the 58th Annual Meeting of the Association for Computational Linguistics* (pp. 5185–5198). https://doi.org/10.18653/v1/2020.acl-...

Mahowald, K., Ivanova, A. A., Blank, I. A., Kanwisher, N., Tenenbaum, J. B., & Fedorenko, E. (2024). Dissociating language and thought in large language models. *Trends in Cognitive Sciences*, *28*(6), 517–540. https://doi.org/10.1016/j.tics.2024.0...

Warstadt, A., Mueller, A., Choshen, L., Wilcox, E., Zhuang, C., Ciro, J., Mosquera, R., Paranjabe, B., Williams, A., Linzen, T., & Cotterell, R. (2023). Findings of the BabyLM Challenge: Sample-efficient pretraining on developmentally plausible corpora. In *Proceedings of the BabyLM Challenge at the 27th Conference on Computational Natural Language Learning* (pp. 1–34). https://doi.org/10.18653/v1/2023.conl...

</div>

</div>

<div style = "position: relative; margin-top: 1.4rem; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/7lOVAkCk-sc" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>


### <span style='color:grey; font-size:70%;'>2025 ·</span>&nbsp; Beyond the cloud: Reclaiming data sovereignty in speech transcription

<div class="multimedia-summary">

<div style='margin: -5px 0 2px 0;'><i class="fa-solid fa-wand-magic-sparkles" style='color:darkgrey; font-size:75%;'></i> <span style='color:darkgrey; font-style:italic; font-size:85%;'>Created using Google Gemini and NotebookLM.</span></div>

In this episode of Codex Mentis, we explore the critical intersection of generative AI and research methodology, focusing on a production-ready, open-source workflow for secure speech transcription developed by Dr Pablo Bernabeu. While OpenAI’s Whisper models have set a new gold standard for speech-to-text accuracy, relying on consumer-grade cloud interfaces like ChatGPT or Google Gemini often proves incompatible with the rigorous demands of academic and clinical research. We dissect the three primary limitations of these cloud-based tools—restrictive file size caps, a lack of methodological reproducibility, and the significant privacy and GDPR risks inherent in transmitting sensitive human data to third-party servers. The discussion highlights a sophisticated alternative that leverages high-performance computing environments to achieve complete data sovereignty by running transcription entirely offline within a secure institutional perimeter. We break down the engineering behind this transition, including the use of SLURM job scheduling for unlimited scalability across GPU nodes and the implementation of advanced quality controls to fix common AI hallucinations such as spurious repetitions and accidental language switching. Furthermore, we examine the system's intelligent, multi-tiered approach to personal name masking and speaker diarisation, which ensures participant anonymity and structured dialogue without compromising the semantic integrity of the research data. This episode provides a comprehensive look at how researchers can balance the power of modern AI with the non-negotiable requirements of ethical compliance and long-term scientific sustainability.

View [sources and related content](/2025/speech-transcription-python).

</div>

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/pPBhUgQBlBU" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>


### <span style='color:grey; font-size:70%;'>2025 ·</span>&nbsp; The modular mini-grammar: Building testable and reproducible artificial languages using FAIR principles

<div class="multimedia-summary">

<div style='margin: -5px 0 2px 0;'><i class="fa-solid fa-wand-magic-sparkles" style='color:darkgrey; font-size:75%;'></i> <span style='color:darkgrey; font-style:italic; font-size:85%;'>Created using Google Gemini and NotebookLM.</span></div>

In the high-stakes world of scientific inquiry, methods and findings are inextricable. Yet, issues of reproducibility remain a challenge, especially in experimental linguistics and cognitive science. As the old adage goes, "To err is human", but when creating research materials, adhering to best practices can significantly reduce mistakes and enhance long-term efficiency.

In this episode of Codex Mentis, we explore the crucial application of the FAIR Guiding Principles—making materials Findable, Accessible, Interoperable, and Reusable—to the creation of stimuli and experimental workflows.

Drawing on research presented by Bernabeu and colleagues, we delve into a complex study on multilingualism using artificial languages, designed specifically to ensure the materials are reproducible, testable, modifiable, and expandable. Unlike many previous artificial language studies that showed low to medium accessibility, this methodology emphasizes high standards for scientific data management.

What you will learn:

- The Power of Open Source: We discuss the importance of using free, script-based, open-source software, such as R and OpenSesame, to augment the credibility and reliability of research.

- Modular Frameworks: Discover how creating a modular workflow based on minimal components in R facilitates the expansion of materials to new languages or within the same language set.

- Rigour and Reproducibility: We examine crucial testing steps exerted throughout the preparation workflow—including checking if all experimental elements appear equally often—to prevent blatant disparities and spurious effects.

- Detailed Experimentation: Hear how custom Python code within OpenSesame was implemented to manage complex procedures across multiple sessions, including assigning participant-specific parameters (like mini-language or resting-state order).

- Measuring the Brain: We look at the technical challenge of accurately time-locking electroencephalographic (EEG) measurements. The episode details the custom Python script used in OpenSesame to send triggers to the serial port, enabling precise Event-Related Potential (ERP) recording.

- Generous Documentation: Why detailed documentation, using formats like README.txt that are universally accessible, is essential for allowing collaborators and future researchers (or even your future self) to understand, reproduce, and reuse the materials.

Adhering to FAIR standards ensures that the investment in research materials facilitates researchers' work beyond the shortest term, contributing to the best use of resources and increasing scientific reliability.

View [sources and related content](/presentation/making-research-materials-findable-accessible-interoperable-reusable-fair).

</div>

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/NG9G1gQdOEo" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>


### <span style='color:grey; font-size:70%;'>2025 ·</span>&nbsp; Third language learning and morphosyntactic transfer

<div class="multimedia-summary">

<div style='margin: -5px 0 2px 0;'><i class="fa-solid fa-wand-magic-sparkles" style='color:darkgrey; font-size:75%;'></i> <span style='color:darkgrey; font-style:italic; font-size:85%;'>Created using Google Gemini and NotebookLM.</span></div>

Many of us know how difficult it is to master a second language (L2). But what happens when you decide to go for a third? You might assume the process gets easier once your brain is "warmed up," but the reality is far more complex and far more fascinating.

In this insightful episode of Codex Mentis, we explore the burgeoning science of Third Language Acquisition, or L3 acquisition. We reveal why learning an L3 presents a fundamentally different cognitive puzzle than learning an L2.

The Two-Blueprint Problem: When an L3 learner approaches a new language, their brain has two prior linguistic blueprints—the native language (L1) and the second language (L2)—instead of just one. This means they already have experience managing two co-existing, often competing, language systems. This difference has profound, measurable consequences on the learning process, documented clearly in studies like the one involving L1 English/L2 Spanish speakers learning French, where they preferentially borrowed the complicating Spanish grammar instead of the helpful English one. This phenomenon, known as Cross-Linguistic Influence or 'transfer,' forces the L3 learner's brain to run a rapid, high-stakes cost-benefit analysis about which existing knowledge base to deploy. This effort reflects a fundamental principle of human cognition: cognitive economy, where the brain avoids redundancy by reusing existing knowledge.

The Great Debate: How Does the Brain Choose its Blueprint? The field is split over how transfer occurs:

1. Typological Primacy Model: Argues for a 'wholesale' transfer—the brain makes a quick-and-dirty assessment of the new language's overall structure (its typology) and copies the entire grammatical system of the most similar known language (L1 or L2). This is the 'big picture first' approach.

2. Linguistic Proximity Model and Scalpel Model: Suggest a continuous, granular, property-by-property negotiation. Influence is exerted by the language (L1 or L2) that has the most similar feature to the specific feature currently being processed in the L3.

Building Languages in the Lab: To test these competing theories and study the initial state of learning, scientists employ ingenious methodology: the artificial language paradigm. These miniature, custom-designed languages provide total control over input and allow researchers to create perfectly unambiguous contrasts between the learner's L1, L2, and the new L3. By using familiar words but new grammar (semi-artificial languages), researchers bypass the time-consuming process of memorizing vocabulary (the 'lexico-semantic bottleneck') and get straight to processing morphosyntax.

Learning vs. Acquisition: The Neural Evidence: This leads to a critical question rooted in Stephen Krashen’s work: are these lab studies capturing subconscious, intuitive acquisition (like a child absorbing their native tongue) or conscious, effortful learning (like cramming rules for an exam)?

Using EEG brain scans to measure neural activity, researchers look for the P600—the brain's automatic, implicit signature for grammatical errors in a native language. Surprisingly, early studies on artificial languages did not find the P600. Instead, they observed the P300. The P300 is a domain-general signal linked to attention, working memory, and processing unexpected patterns.

This means the brain’s initial response to a new grammar is not an automatic 'copy-and-paste' of a prior language; rather, L3 acquisition begins with the conscious recruitment of domain-general pattern-matching and attention.

The Next Frontier: We detail the sophisticated, large-scale, longitudinal study currently underway, designed to bridge the gap between conscious learning and subconscious acquisition. This research tracks participants over months to see if the P300 evolves into the automatic P600, while systematically measuring individual differences in working memory, inhibitory control, and implicit learning aptitude.

The study of the third tongue is evolving beyond linguistics; it has become a privileged window into one of the most fundamental questions about the human mind: how we manage, integrate, and reuse complex systems of knowledge.

Join us and delve into the science of the multilingual mind!

View [sources and related content](/publication/third-language-longitudinal-data-artificial-language-learning-eeg).

</div>

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/tcBCMajt16Y" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>


### <span style='color:grey; font-size:70%;'>2025 ·</span>&nbsp; Behind the curtains: Methods used to investigate conceptual processing

<div class="multimedia-summary">

<div style='margin: -5px 0 2px 0;'><i class="fa-solid fa-wand-magic-sparkles" style='color:darkgrey; font-size:75%;'></i> <span style='color:darkgrey; font-style:italic; font-size:85%;'>Created using Google Gemini and NotebookLM.</span></div>

How do scientists measure a thought? While the great philosophical questions about the nature of meaning have been debated for centuries, the last few decades have seen the development of a sophisticated scientific toolkit designed to turn these abstract queries into concrete, measurable data. In this episode of Codex Mentis, we go behind the curtains of cognitive science to explore the very methods used to investigate how the human brain processes language and constructs meaning.

Moving from the 'what' to the 'how', this programme offers a detailed review of the modern psycholinguist's toolkit. The journey begins with the foundational behavioural paradigms that capture cognition in milliseconds. Discover the logic behind the Lexical Decision Task, where a simple button press reveals the speed of word recognition, and the Semantic Priming paradigm, which uses subtle manipulations of time to dissociate the mind's automatic reflexes from its controlled, strategic operations.

From there, the discussion delves into the neuro-cognitive instruments that allow us to eavesdrop on the brain at work. Learn how Electroencephalography (EEG) and its famous N400 component provide a precise electrical timestamp for the brain's "sense-making" effort. Explore how Functional Magnetic Resonance Imaging (fMRI) creates detailed maps of the brain's "semantic system," showing us where meaning is processed. And see how Eye-Tracking in the Visual World Paradigm provides a direct, observable trace of the brain making predictions in real time.

Finally, the episode demystifies the complex statistical techniques required to analyse this intricate data. We delve into the shift from older statistical methods to modern Linear Mixed-Effects Models, which are designed to handle the inherent variability between people and words. The conversation concludes with a crucial look at the foundations of trustworthy research, examining how scientists determine the sensitivity of their experiments and calculate the required sample sizes to ensure their findings are robust and reproducible. This episode provides a comprehensive guide to the ingenious procedures scientists employ to understand one of the most fundamental aspects of human experience: how we make sense of the world, one word at a time.

View [sources and related content](/publication/pablo-bernabeu-2022-phd-thesis).

</div>

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/ftFoNsEbJcM" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>


### <span style='color:grey; font-size:70%;'>2025 ·</span>&nbsp; The architecture of meaning: Inside the words we use

<div class="multimedia-summary">

<div style='margin: -5px 0 2px 0;'><i class="fa-solid fa-wand-magic-sparkles" style='color:darkgrey; font-size:75%;'></i> <span style='color:darkgrey; font-style:italic; font-size:85%;'>Created using Google Gemini and NotebookLM.</span></div>

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

View [sources and related content](/publication/pablo-bernabeu-2022-phd-thesis).

</div>

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/Uii-4ybSmKM" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2025 ·</span>&nbsp; Segmentation of ERPs involving several markers and time adjustments in BrainVision Analyzer

This live demonstration guides you through the process of segmenting event-related potentials (ERPs) in BrainVision Analyzer. The events of interest are represented by several markers, requiring some thought to time-lock each segmentation to the event onset.

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/QXOpa-uOBVc" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2025 ·</span>&nbsp; Visualising EEG effects with topographic mapping in BrainVision Analyzer

This tutorial walks through the key steps: creating grand averages across participants, computing difference waves between experimental conditions, selecting appropriate map types, and defining time windows for visualisation.

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/FI9FO7oJj_o" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2025 ·</span>&nbsp; Naming results files exported from Gorilla Experiment Builder

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/nVidNO8xcxE" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2024 ·</span>&nbsp; [Reducing the impedance in electroencephalography using a blunt needle, electrolyte gel and wiggling](/2024/lowering-impedance-in-electroencephalography-using-a-blunt-needle-electrolyte-gel-and-wiggling)

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/4KLtp-WnOOo" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2024 ·</span>&nbsp; [Briefing participants to prevent muscle artifacts in electroencephalography sessions](/2024/preventing-muscle-artifacts-in-electroencephalography-sessions)

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/9Mbv6bUZlqY" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2021 ·</span>&nbsp; [Linguistic and embodied systems in conceptual processing: Variation across individuals and items](/presentation/linguistic-and-embodied-systems-in-conceptual-processing-variation-across-individuals-and-items)

<div class="multimedia-thumbnail" style="margin-top: 10px;">
<a href='https://www.youtube.com/watch?v=y2bopgYWYvE&ab_channel=LancasterPsychology'>
<img src='/presentation/linguistic-and-embodied-systems-in-conceptual-processing-variation-across-individuals-and-items/img/thumbnail.png'></a>
</div>

<div style = 'padding-bottom: 3.5%;'></div>

### <span style='color:grey; font-size:70%;'>2020 ·</span>&nbsp; [Reproducibilidad en torno a una aplicación web](/presentation/2020-10-08-reproducibilidad-en-torno-a-una-aplicacion-web)

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/1njLOAWqLPM" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2020 ·</span>&nbsp; Workshop on <i class="fa-brands fa-r-project" aria-label="R"></i> Markdown, dashboards and Binder (see [programme and materials](https://github.com/pablobernabeu/CarpentryCon-2020-workshop-Open-Data-Reproducibility))

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/wZsPD7CgJC0" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2020 ·</span>&nbsp; Personal profile and experience at Lancaster University Department of Psychology

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/ZEoan5tWqFg" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2020 ·</span>&nbsp; Embedding open research and reproducibility in the UG and PGT curricula

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/vzkDBZ1qWfY" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2019 ·</span>&nbsp; Part of application for [Gorilla Grant](#funding-awards)

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
<iframe src="https://www.youtube-nocookie.com/embed/DTHFuC0Lw0Y" frameborder="0" allowfullscreen
style = "position:absolute; top:0; left:0; width:95%; height:95%;"></iframe>
</div>

### <span style='color:grey; font-size:70%;'>2019 ·</span>&nbsp; Part of application for [Software Sustainability Institute Fellowship](#funding-awards)

<div style = "position: relative; margin-top: 10px; padding-top: 56.25%;">
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
