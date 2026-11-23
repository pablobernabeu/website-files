# Website enhancements: changes made and proposals

Internal reference, November 2026. The first part records what the branch `claude/website-content-format-enhance-356y72` changes. The second part sets out further enhancements to consider before any of them is implemented. Nothing here is deployed until the branch is merged into `master`.

## Changes on this branch

None of the changes touches an R Markdown source, so the deploy workflow rebuilds no post. Every built page was compared with a build of `master`: apart from the menu order and the Person structured data, which appear on every page, only the home page, the author page, the four section lists, their feeds, the search index and the sitemap differ, and the sitemap only in the order of its 462 entries.

The home page now places Software after Workshops and Presentations, and the menu follows the same order. Section backgrounds alternate by position, so Workshops now has the grey background and Presentations the white one.

The texts on the home page and the section pages were revised for concision and house style. The bio merges six short paragraphs into four and adds one sentence on current work (children's reading comprehension in digital formats), drawn from the John Fell grant and the recent talks listed on the site. The teaching section loses its generic phrasing ('cornerstone of scientific integrity', 'empowers students', 'cutting-edge', 'excel in their academic and professional endeavours') and a dangling modifier, while each course keeps its content. In the funding table, the Open Research Prize entry no longer says 'Awarded' for a shortlisting, and the John Fell entry no longer defines reading by what it is not. The section pages are now titled 'Publications', 'Presentations', 'Software' and 'Blog and Resources', each with a one-line subtitle, which also serves as the page's meta description in place of the site description prefixed by the title.

The largest gain in loading time came from the Videos section. A script wrapped each video entry in a `div` once the page had loaded, and moving an iframe in the document makes the browser load it at once, so all twenty YouTube players and the OSF viewer were requested on every visit to the home page, however far the visitor scrolled. The wrappers are now written in the Markdown, the rendered structure is identical, and the frames load only as the visitor approaches them. The tag network at the foot of the home page now reads the search index (220 KB) only when the visitor comes within about a screen of it, and it now ignores hidden tags, which it had excluded only by accident of scroll position. The 248 KB video thumbnail loads lazily. Measured locally, the uncompressed bytes requested from the site and its CDN on first view fell from 2.20 MB to 1.67 MB, before counting the third-party frames that are no longer requested.

One CSS rule changed. In the home Software section, a negative margin clipped the second line of each citation ('(CRAN) and PyPI'). The same defect had been fixed for the blog list, and the software rule now shares that fix. The /software/ list now uses the same order as the home widget, which differed for items released on the same day. The Person structured data gains the avatar, the universities attended and the research areas.

## Proposals

### A grounded assistant for reading the research

An assistant that explains a paper to a visitor is feasible on this site, but only with safeguards that an off-the-shelf chatbot lacks, and the first step need not involve a live model at all.

The safest first step is a set of plain-language summaries, generated offline from the full text of each open-access paper, then checked, edited and approved before publication as ordinary text on the publication page, with a note on how they were produced (as the podcast descriptions already carry). This carries no risk of a fabricated statement reaching a visitor unchecked, costs nothing to serve, raises no privacy question and helps search engines. A template field such as `lay_summary` in the publication front matter would be enough.

A live question-and-answer feature would add the ability to answer a visitor's own question, at the price of answers that no one has checked. GitHub Pages cannot hold an API key, so the requests would go through a small proxy, for which a Cloudflare Worker is sufficient: its free plan allows 100,000 requests a day, and the time spent waiting for the model does not count towards its CPU limit ([Cloudflare Workers limits](https://developers.cloudflare.com/workers/platform/limits)). The proxy would hold the key, limit the rate per visitor, cap the monthly spend and allow the feature to be switched off at once.

The model would receive the full text of the one paper in question, never the open web, under instructions to answer only from that text and to say when the paper does not address a question. Instructions alone do not prevent fabrication, so the proxy should check the answers mechanically before a visitor sees them. The model would return its answer together with the passages it relies on, through structured output. The proxy would then confirm that each quoted passage occurs verbatim in the paper and that any reference mentioned appears in the paper's own reference list, and it would withhold any answer that fails either check. This makes fabricated quotations and references detectable, though a misreading of a genuine passage, for instance of a statistical result, would still pass. For that reason, the interface would show the supporting passages under each answer, and it would offer a few bounded tasks (explain this term, summarise the method, state the limitations the authors acknowledge) rather than open conversation.

Three constraints apply. Licensing: the full texts used must be open access or author manuscripts that may be redistributed in this way. Terms of service: the Gemini API terms restrict apps offered to users in the UK, the EEA and Switzerland to the paid tier, and under the paid tier Google does not use prompts or responses to improve its products, although it logs them for a limited period ([Gemini API terms](https://ai.google.dev/gemini-api/terms); [forum discussion of the UK and EEA clause](https://discuss.ai.google.dev/t/clarification-on-only-paid-services-for-eea-ch-uk/107860)). These pages could not be opened from the environment in which this note was written, so the wording should be checked at the source. Privacy: visitors' questions are personal data once they reach Google, so the site's privacy page would need a section on the feature, and nothing should be sent until the visitor opens the assistant.

The cost depends on the price per token at the time, which Google has changed several times in 2026 ([pricing page](https://ai.google.dev/gemini-api/docs/pricing)). A paper of about 15,000 words is roughly 20,000 tokens, so each question costs about 20,000 times the input price, plus the answer. Context caching charges much less for a paper that is sent repeatedly. At an input price of $1.50 per million tokens, for instance, a thousand questions a month would cost about $30 without caching and a few dollars with it.

Chrome's built-in model (Gemini Nano, through the Prompt API) would avoid the key, the cost and the transfer of data, but it runs only in desktop Chrome on capable hardware and downloads a large model on first use ([Chrome built-in AI APIs](https://developer.chrome.com/docs/ai/built-in-apis)). Posts on Chrome's developer forum from late 2025 and early 2026 put its input quota at 9,216 tokens, under half of a typical paper, though the figure is undocumented and has changed before ([chrome-ai-dev-preview-discuss](https://groups.google.com/a/chromium.org/g/chrome-ai-dev-preview-discuss)). It does not suit this purpose.

The recommended path is the reviewed summaries first, then, if they prove useful, a pilot of the live feature on two or three open-access papers with the verbatim-quotation check in place.

### Loading time

Twenty YouTube frames still load as a visitor scrolls through the Videos section. A click-to-load placeholder (the video's thumbnail with a play button, which loads the player only when pressed) would remove that cost entirely and also keep YouTube from being contacted at all unless a video is played. This changes the section's markup and appearance, so it needs a decision on the design.

The site's main stylesheet (`academic.css`, compiled from the theme and `custom.scss`) is about 357 KB before compression and blocks rendering on every page. Much of it overrides earlier rules. Pruning it would help, but it needs page-by-page visual comparison, because the selectors depend closely on the structure of each page.

Font Awesome loads its full stylesheet and two font files (about 350 KB together before compression) for a few dozen icons. A subset served from the site, or inline SVG icons, would remove most of that. Serving Montserrat and Roboto from the site instead of Google Fonts would remove a third-party connection and the transfer of visitors' IP addresses to Google.

The 248 KB PNG video thumbnail would take 50 KB as a JPEG or 29 KB as WebP (both at quality 80). The featured images in the lists are produced at 150 pixels wide, so they look soft on high-density screens. Adding a 300-pixel version through `srcset` would sharpen them at a small cost.

### Robustness and accessibility

On desktop, the profile details beside the photo (role, emails and profile icons) and every link in the tag cloud start invisible and appear only when a script reveals them on scroll. If JavaScript is off, or if the jQuery file from cdnjs fails to load, they stay invisible, as a test with scripts disabled confirmed. The hidden starting state should apply only once the script is known to be running, for instance under a class that the script adds to the page. This touches a shared block of CSS, so it was left for a separate change with visual checks.

The grey of the section subtitles (`rgba(0,0,0,.54)` on white) gives a contrast of about 4.6:1, just above the WCAG AA threshold for normal text. A slightly darker grey would leave more margin.

### Content

The home page opens directly on the first publication, as the Publications heading is hidden on desktop, and the bio sits about 10,000 pixels down. A visitor arriving from a search engine sees no statement of who the site belongs to until they scroll a long way. One option is a single introductory line above the publications, linking to the bio.

The descriptions of the NotebookLM podcast episodes in the Videos section are labelled as generated, but phrases such as 'pervasive culture of silence' and 'structural paradox' read as generated text. Tightening them would bring them closer to the rest of the site. The abstract of the Gemini lightning talk ('democratises access', 'necessitates a shift in researcher responsibility') has the same quality, though it may need to remain as submitted.

The funding table names 'the readsync toolkit', which appears nowhere else on the site. If it is the package now called lexsync, the entry should use the current name.

The presentations and funding tables abbreviate September as 'Sept' and the other months to three letters. 'Sep' would be consistent, though 'Sept' is also common in British usage.
