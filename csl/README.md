# Citation styles

`apa.csl` is the APA 7th edition style of the Citation Style Language project,
copied unchanged from
[citation-style-language/styles](https://github.com/citation-style-language/styles/blob/3c6698d791a83016d699f50cbbea857f6ee3d2f8/apa.csl)
at commit 3c6698d791a83016d699f50cbbea857f6ee3d2f8, and licensed, as its
`<rights>` element states, under CC BY-SA 3.0.

A post that renders its citations with pandoc's citeproc names it in its front
matter, by a path relative to the post's folder, together with its bibliography
and `link-citations: true`, which links each citation to its entry:

```yaml
bibliography: references.yaml
csl: ../../../csl/apa.csl
link-citations: true
```

`static/js/citation-backlinks.js` then adds back-links from each entry to the
places that cite it. Hugo does not read this folder, so the style is not
published.

Two limits of the style, both met in
`content/post/reproducible-research-with-generative-ai`:

- It is CSL 1.0, which cannot tell a narrative citation from a parenthetical
  one, so a narrative citation of two authors would read "Messeri & Crockett
  (2024)" where APA writes "and". Such a citation keeps the names in the text
  and cites the year alone: `Messeri and Crockett [-@messeri2024]`.
- It treats a `paper-conference` without editors as a periodical and so omits
  the "In" before the proceedings. Proceedings without listed editors are
  entered as `chapter`, with an article number as text (`number: Article 1121`)
  so that it is not labelled "No.".
