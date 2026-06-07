#!/usr/bin/env python3
"""
Alt-text detector for the site's content.

Flags images that lack alt text so they can be given meaningful descriptions:
  * raw <img ...> tags with NO alt= attribute      -> "missing alt"   (warning)
  * markdown ![](...) images with empty alt         -> "empty alt"     (notice/review)

Intentional decorative images written as <img alt=""> are NOT flagged
(empty alt is the correct marker for decorative images). Generated knitr
figures (in *_files/figure-html/...) are reported separately, because fixing
those needs an .Rmd chunk `fig.alt` + a re-render rather than a content edit.

Scans content/ for .md/.Rmd/.markdown/.html, skipping generated asset dirs.

Exit code: 0 (advisory) by default. Set ALT_CHECK_STRICT=1 to exit 1 when any
content images (excluding generated figures) are missing alt -- i.e. to turn
this into a hard CI gate once the backlog is cleared.
"""
import os
import re
import sys

ROOT = os.environ.get("ALT_CHECK_DIR", "content")
EXTS = (".md", ".rmd", ".markdown", ".html")
SKIP_SUBSTR = ("/rmarkdown-libs/",)  # vendored JS/CSS libs only
IN_CI = os.environ.get("GITHUB_ACTIONS") == "true"

# Quote-aware: a `>` may appear inside a quoted attribute value (e.g. a Hugo
# shortcode like src="{{< blogdown/postref >}}..."), so don't end the tag on it.
img_re = re.compile(r'''<img\b(?:"[^"]*"|'[^']*'|[^>"'])*>''', re.IGNORECASE)
alt_re = re.compile(r"\balt\s*=", re.IGNORECASE)
md_empty_re = re.compile(r"!\[\s*\]\([^)]+\)")


def lineno(text, pos):
    return text.count("\n", 0, pos) + 1


def is_generated_figure(tag):
    return ("figure-html" in tag) or ("_files/" in tag)


missing_content = []   # raw <img> no alt, hand-authored content image
missing_figure = []    # raw <img> no alt, generated knitr figure
empty_md = []          # markdown ![](...) empty alt

for dirpath, _dirs, filenames in os.walk(ROOT):
    for fn in filenames:
        if not fn.lower().endswith(EXTS):
            continue
        path = os.path.join(dirpath, fn).replace("\\", "/")
        if any(s in path for s in SKIP_SUBSTR):
            continue
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            continue
        for m in img_re.finditer(text):
            tag = m.group(0)
            if alt_re.search(tag):
                continue
            entry = (path, lineno(text, m.start()), " ".join(tag.split())[:110])
            (missing_figure if is_generated_figure(tag) else missing_content).append(entry)
        for m in md_empty_re.finditer(text):
            empty_md.append((path, lineno(text, m.start()), m.group(0)[:110]))


def group(items):
    out = {}
    for f, ln, snip in items:
        out.setdefault(f, []).append((ln, snip))
    return out


def show(title, items, level):
    print(f"\n=== {title}: {len(items)} ===")
    for f, hits in sorted(group(items).items()):
        print(f"  {f}")
        for ln, snip in hits:
            print(f"    L{ln}: {snip}")
            if IN_CI:
                print(f"::{level} file={f},line={ln}::Image lacks alt text")


show('Content <img> with NO alt attribute  (add alt="..." or alt="")', missing_content, "warning")
show('Markdown ![](...) with empty alt  (confirm decorative or add alt)', empty_md, "notice")
show('Generated knitr figures with no alt  (needs .Rmd fig.alt + re-render)', missing_figure, "notice")

print(
    f"\nSUMMARY: {len(missing_content)} content image(s) missing alt, "
    f"{len(empty_md)} empty-alt markdown image(s), "
    f"{len(missing_figure)} generated figure(s) missing alt."
)

if os.environ.get("ALT_CHECK_STRICT") == "1" and missing_content:
    print("\nALT_CHECK_STRICT=1 and content images are missing alt -> failing.")
    sys.exit(1)
