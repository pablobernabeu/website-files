---
title: 'Read My Mind: Can a model of decision-making predict your next answers?'
type: software
software_kind: web-application
abstract: 'Read My Mind is an educational web application in which students make a few dozen quick decisions about clouds of dots, watch a drift-diffusion model of decision-making being fitted to their own decisions on their device and then see whether the predictions the model locks in about their next answers hold up. It is designed for students aged 11 to 18. It keeps nothing on the device beyond a copy of its own files, which lets it work offline once it has been opened, and nothing the student does is sent anywhere.'
authors:
date: "2026-11-19"
draft: true
featured: false
image:
  caption: ''
  focal_point: ""
  preview_only: true
summary: 'Educational web application in which a drift-diffusion model is fitted to a student''s own decisions on the device and then tested, in front of the student, against their next answers.'
categories:
- research and teaching applications
- web application
tags:
- web application
- cognitive science
- decision-making
- drift-diffusion model
- computational modelling
- science outreach
- education
- uncertainty
- accessibility
- JavaScript
- D3.js
- open science
open_materials: true
url_code: 'https://github.com/pablobernabeu/read-my-mind'
links:
- name: Web application
  url: 'https://pablobernabeu.github.io/read-my-mind/'
diagram: true
apa_captions: true
---


[Read My Mind](https://pablobernabeu.github.io/read-my-mind/) is an educational web application that lets students test a scientific model of decision-making on their own choices. Students decide which of two clouds of flickering dots has more dots, under one scoring rule in which points drain away with time and another in which time is free but a mistake costs points. From those decisions, the application fits a drift-diffusion model on the student's own device, explains what the fitted model says about how they decided and then commits to predictions about the timing of their next answers before they give them. The model can lose, and the application says so when it does.

The application is designed for students aged 11 to 18 and for phones, tablets and laptops. A rough estimate from simulated sittings puts a sitting at 7 to 11 minutes, depending on how fast the student reads and whether they read the closing card about the science, but no sitting has yet been timed. The application needs no login.

<div style="width: 100%; height: 800px; margin: 2em 0; border-radius: 8px; overflow: hidden; border: 1px solid #ddd;">
  <iframe src="https://pablobernabeu.github.io/read-my-mind/"
      style="width: 100%; height: 100%; border: none;"
      title="Read My Mind web application">
  </iframe>
</div>

## How It Works

The diagram below traces a student's path through a sitting.

{{< diagram >}}
graph TD
  A["Practice: 12 turns that find<br/>the difficulty at which the<br/>student is about 80% correct"] --> B["Buzzer round: 16 turns<br/>in which points drain<br/>away with time"]
  B --> C["Checking round: 16 turns<br/>with no clock, in which<br/>a mistake costs points"]
  C --> D["How might a brain decide?<br/>A ball pushed by noisy<br/>evidence between two lines"]
  D --> E["The model is fitted to the<br/>student's own answers"]
  E --> F["Predictions are locked in:<br/>a time band for each of<br/>the next 12 turns"]
  F --> G["12 more buzzer turns, each<br/>revealed against the model<br/>and a simple guess"]
  G --> H["Results, the trade-off<br/>between speed and accuracy<br/>(only if the fit finds<br/>that the buzzer narrowed<br/>the gap between the lines)<br/>and the real science"]
{{< /diagram >}}

Each dot appears at a random moment, lives for half a second and then disappears, so the number on screen fluctuates around each cloud's average. Counting is therefore impossible, and the evidence a student sees arrives bit by bit, which is the situation the model describes. At each difficulty in the buzzer and checking rounds and in the 12 prediction turns, the cloud with more dots is on the left in half the turns and on the right in the other half. Likewise, it has the larger total area and the larger dots in half the turns and the smaller in the other half, so that neither its side, its total area nor the size of its dots points to the answer. In the practice turns, the side and these cues are drawn at random for each turn.

## Educational Objectives

Students can learn that a scientific model makes predictions that can be tested and that a fair test is one the model can fail. They can learn that predictions about people are ranges rather than single values, which links to medians, quartiles and the shape of a distribution in school statistics. They also experience the trade-off between speed and accuracy under two scoring rules. When the fit finds that a student waited for less evidence in the buzzer round than in the checking round, the application then estimates how waiting for each of these two amounts of evidence would have scored under each rule, which in most cases shows that the best balance depends on what a mistake costs. The application never ranks or scores students against one another, and it reminds them that the numbers it finds describe one sitting on one device rather than the student.

## The Model Behind It

The drift-diffusion model treats a quick two-choice decision as evidence that accumulates over time until it reaches one of two thresholds ([Ratcliff et al., 2016](https://doi.org/10.1016/j.tics.2016.01.007)). Three kinds of number describe it, which the application introduces in plain words: clue strength (the drift rate), the gap between the two thresholds (the boundary separation) and eyes-and-thumb time (the non-decision time). Clue strength is assumed to be proportional to the log of the ratio of the two dot counts, in line with research on comparing clouds of dots ([Ratcliff & McKoon, 2018](https://doi.org/10.1037/rev0000085)).

The application uses a simplified version of the model, without the variability between trials that researchers usually include, and it says what this leaves out: the simplified model predicts that correct and wrong answers take the same time, whereas real mistakes are often slower and can be faster when people rush ([Ratcliff & Rouder, 1998](https://doi.org/10.1111/1467-9280.00067)). It also tells students that it assumes the buzzer changes only how much evidence they wait for, although hurrying often changes other parts of the decision too ([Lerche & Voss, 2018](https://doi.org/10.3758/s13428-018-1034-7)). The model is fitted by maximum likelihood in a background thread of the browser while the student reads the explanation. The likelihood is computed from a series for the first-passage-time density rather than by simulation, and it allows for 5% of answers being random guesses.

## An Honest Test

After the fit, the application tells students whether the buzzer made them wait for less evidence, or that the turns are too few to tell, which is the honest answer for many students. Less often, it says that they seemed to wait for more evidence, which can happen by chance or if they got quicker as they played. Rarely, its numbers end at the edge of the range it allows, and it reports that it cannot say much about the student's gap. Next, the application draws, for each of the next 12 turns, a band of times where it expects about half of the student's answers to land, and locks these bands in before the student plays on (Figure 1). The model competes against a simple guess: a band of the same width, placed where it would have caught the most of the student's own buzzer answers. Both bands are built in the same way, so neither gains from the skew of response times alone.

<figure>
<img loading="lazy" decoding="async" src="img/screens.png" alt="Four phone screens from Read My Mind. The first shows a practice turn with two clouds of dots. The second shows the explanation, in which the same noisy evidence reaches the bottom line with a narrow gap and the top line with a wide gap. The third shows the fit, with the pretend player's answers under the curves the model predicts for each round. The fourth shows the locked prediction card, with the model's band and the simple guess above the pretend player's buzzer answers for easier and harder turns." style="max-width:100%; border-radius:6px; margin: 1em 0;">
<figcaption>A Practice Turn, the Explanation, the Fit and the Locked Prediction Card. All but the first are shown in Watch mode, so the marks on the fit and on the prediction card are the answers of Sam, a pretend player.</figcaption>
</figure>

With only 12 turns, a single game is a small test, and the application says so. Before release, its design was tested on thousands of simulated players. In 1,500 simulated sittings by players who follow the model apart from 5% of answers that are guesses, the model won 40.1% of games against the simple guess, tied 40.1% and lost 19.7%, and its bands caught 49.7% of the answers. When simulated players departed from the model, it never did better in the contest by more than simulation error, and it did worse by more than that with more guesses (10% of answers), very quick guesses or variability from turn to turn. The contest figures therefore probably overstate how the model will fare with real students, as the application tells them.

## Accessibility and Privacy

The application aims to meet the Web Content Accessibility Guidelines 2.2 at level AA. It works by touch, mouse or keyboard, supports reduced motion and light or dark colours, and never uses colour alone to carry meaning. Because the dot task is visual, students who cannot use it can choose Watch mode, which follows a pretend player through every step without timing, with each turn also given in a table. A page of notes for teachers suggests a 15 to 20 minute lesson, discussion prompts and a class tally of the model's wins, ties and losses that collects nothing about students.

Nothing a student does leaves the device, and the application keeps nothing on it beyond a copy of its own files, which lets it open offline after a first visit. A content security policy stops the page's scripts from opening network connections and lets the page load only its own files from its own site. There are no accounts, cookies or analytics, and closing the page removes the sitting.

## How It Was Built and Tested

The order of the rounds and the scoring of the buzzer round follow a design review in October 2026 that included two independent simulation studies of the proposed design. The application's own simulation studies then tested these choices and compared 10 with 16 turns per rule and 6, 10 and 12 prediction turns. They ran its code on four ordinary processor cores, so no high-performance computing was needed, and in most of them simulated players answered through the same state machine, planning, scoring and fitting that a student meets. The share of predicted answers that each band holds (52%) and the range of times the fit allows for guesses (up to 8 seconds) were chosen by simulation.

The simulations also checked the verdict on a separate set of 1,500 simulated players of the same kind whose gap did not change. It wrongly said that the gap got narrower for 3.1% of them and that it got wider for another 3.1%. When simulated players departed from the model in several ways, false 'narrower' verdicts stayed between 1.4% and 3.7% with the rounds in the application's order. With practice effects and the checking round first, they rose to 6.5%. With the buzzer round first, as the application plays it, practice effects gave the lowest rate of false 'narrower' verdicts (1.4%), the verdict that leads to the comparison of the two amounts of evidence, but raised false 'wider' verdicts to 8.1%, so that false verdicts in either direction were more common in this order (9.5% against 7.5%).

The model's first-passage-time code agrees with a 50-digit evaluation of the series to machine precision and with PyDDM to within PyDDM's own numerical error. Automated browser tests in Chromium, on an emulated phone and an emulated laptop, play whole sittings by touch and by keyboard. They check that nothing is stored beyond the service worker's copy of the application's own files, that the page requests nothing but those files and that the application opens offline after one visit, and they run axe-core accessibility checks on each kind of screen. The application has not yet been tested in other browsers, on a tablet, on real devices or with a screen reader.

## Source Code and Contributions

The application is written in HTML, CSS and JavaScript, with charts drawn in [D3.js](https://d3js.org/). It needs no build step, and any static web server can host it. The [source code is available on GitHub](https://github.com/pablobernabeu/read-my-mind) under the MIT licence for code and the [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/) licence for content. The repository documents the design decisions, the simulation studies and their results. Feature requests, bug reports and other suggestions can be submitted as [issues](https://github.com/pablobernabeu/read-my-mind/issues).

## References

Lerche, V., & Voss, A. (2018). Speed–accuracy manipulations and diffusion modeling: Lack of discriminant validity of the manipulation or of the parameter estimates? *Behavior Research Methods, 50*(6), 2568–2585. https://doi.org/10.3758/s13428-018-1034-7

Ratcliff, R., & McKoon, G. (2018). Modeling numerosity representation with an integrated diffusion model. *Psychological Review, 125*(2), 183–217. https://doi.org/10.1037/rev0000085

Ratcliff, R., & Rouder, J. N. (1998). Modeling response times for two-choice decisions. *Psychological Science, 9*(5), 347–356. https://doi.org/10.1111/1467-9280.00067

Ratcliff, R., Smith, P. L., Brown, S. D., & McKoon, G. (2016). Diffusion decision model: Current issues and history. *Trends in Cognitive Sciences, 20*(4), 260–281. https://doi.org/10.1016/j.tics.2016.01.007


<div class="btn-links mt-3"><a class="btn btn-outline-primary" href="https://pablobernabeu.github.io/read-my-mind/" target="_blank" rel="noopener">Access web application</a></div>
