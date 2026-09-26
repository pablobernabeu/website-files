// Links to the sections of an article.
//
// Every h2 and h3 in the body of a post, a software page or a publication page is
// given a link to itself, a "#" that custom.scss shows beside the heading on hover
// or keyboard focus, so that a reader can copy the address of one section.
//
// layouts/partials/custom_js.html loads this file on those three kinds of page when
// the body holds an h2 or h3.
(function () {
  "use strict";

  var body = document.querySelector(".article-container > .article-style");
  if (!body) return;

  // A heading takes part only where it is visible body text that can hold a link.
  // An .sr-only heading is never seen, and one inside a <details> may be folded
  // away. One inside a link or a button cannot contain another link, and the
  // related references block belongs to related-references.js, which rebuilds it.
  var EXCLUDED = "details, summary, a, button, label, .related-references";

  function eligible(heading) {
    if (heading.classList.contains("sr-only")) return false;
    if (!/\S/.test(heading.textContent)) return false;
    var outer = heading.parentElement.closest(EXCLUDED);
    return !(outer && body.contains(outer));
  }

  // The heading's text, without footnote markers, whose numbers would read as part
  // of the title.
  function label(heading) {
    var copy = heading.cloneNode(true);
    var notes = copy.querySelectorAll(".footnote-ref");
    for (var i = 0; i < notes.length; i++) notes[i].remove();
    return copy.textContent.replace(/\s+/g, " ").trim();
  }

  // Goldmark puts the id on the heading itself. Pandoc puts it on the
  // <div class="section"> (or, in HTML5 output, the <section>) that the heading
  // opens, and leaves the heading without one. Only the heading that opens the
  // section takes its id, since a later one would send the reader to the top of
  // the section instead of to itself.
  function existingId(heading) {
    if (heading.id) return heading.id;
    var parent = heading.parentElement;
    if (parent !== body && parent.id && parent.firstElementChild === heading &&
        (parent.tagName === "SECTION" || parent.classList.contains("section"))) {
      return parent.id;
    }
    return "";
  }

  // A heading written as raw HTML may have no id at all, so one is made from its
  // text in the form pandoc uses. It starts with a letter, which keeps it a valid
  // CSS identifier for the scripts that look targets up by selector, and it is
  // numbered if the page already holds the same id.
  function newId(heading, text) {
    var base = text.normalize("NFKD").replace(/[\u0300-\u036f]/g, "")
      .toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
    if (!/^[a-z]/.test(base)) base = "section" + (base ? "-" + base : "");
    var id = base;
    for (var n = 1; document.getElementById(id); n++) id = base + "-" + n;
    heading.id = id;
    return id;
  }

  function link(id, text) {
    var a = document.createElement("a");
    a.setAttribute("href", "#" + id);
    a.textContent = text;
    return a;
  }

  var made = [];
  var candidates = body.querySelectorAll("h2, h3");
  for (var i = 0; i < candidates.length; i++) {
    var heading = candidates[i];
    if (!eligible(heading)) continue;
    var id = existingId(heading);
    if (!id) {
      id = newId(heading, label(heading));
      made.push(id);
    }

    // The link is the heading's last child and is taken out of the flow in
    // custom.scss, so the heading wraps exactly as it did without it. Its visible
    // text is the "#"; screen readers hear the label instead.
    var anchor = link(id, "#");
    anchor.className = "heading-anchor";
    anchor.setAttribute("aria-label", "Link to this section");
    heading.appendChild(anchor);
  }

  // An address that points at an id made here arrives before the id exists. The
  // HTML standard has the browser look for its target only while the page is
  // being parsed, which is over before this runs, so the scroll is made here.
  // scroll-padding-top in custom.scss keeps the heading clear of the navbar.
  var hash = "";
  try {
    hash = decodeURIComponent(window.location.hash.slice(1));
  } catch (e) {}
  if (hash && made.indexOf(hash) !== -1) {
    document.getElementById(hash).scrollIntoView();
  }
})();
