#!/usr/bin/env python3
"""
lychee preprocessor for the check of the built site: prints an HTML page with
the contents of its <script> elements blanked out.

The check passes --include-verbatim, under which lychee also extracts links
from the contents of <script> elements. What it finds there is code and data
rather than links of the page, and some of it cannot be resolved: the
{{relpermalink}} placeholder in the template for search results, which every
page that Hugo renders from the templates carries, and the URLs in the data of
the dashboards' htmlwidgets, which sit between escaped quotes in JSON strings.
lychee takes the escaped quotes for part of each URL and so reads it as a
local path. Each of these would be reported as a broken link.

Without --include-verbatim lychee extracts no links from script contents, but
it still reads them as markup. Ordinary JavaScript such as the `i<n` of a loop
condition then looks to it like the start of a tag, which runs on until the
next `>` and so swallows the closing </script>, and lychee extracts no further
links from the page. Once the scripts are blanked, the check no longer depends
on how lychee reads them.

The contents are replaced with spaces, keeping line breaks, so the line and
column numbers in lychee's report still point into the published file. The
tags themselves are kept, so the files that `<script src>` loads are still
checked. The URLs in JSON-LD metadata (<script type="application/ld+json">)
go unchecked with the rest; Hugo writes them from the site's base URL and the
permalinks of the page, its featured image and the site icon.

Usage, as lychee runs it: blank_inline_scripts.py PAGE.html
"""
import re
import sys

# As in the HTML parser, script data runs from the end of the start tag to the
# first `</script`, whatever the JavaScript between them looks like. A `>`
# inside a quoted attribute value does not end the start tag.
SCRIPT = re.compile(
    r"""(<script\b(?:[^>"']|"[^"]*"|'[^']*')*>)(.*?)(?=</script)""",
    re.IGNORECASE | re.DOTALL,
)


def blank(match):
    return match.group(1) + re.sub(r"[^\n]", " ", match.group(2))


def main():
    # surrogateescape round-trips any byte that is not valid UTF-8 unchanged.
    with open(sys.argv[1], encoding="utf-8", errors="surrogateescape") as f:
        html = f.read()
    sys.stdout.buffer.write(
        SCRIPT.sub(blank, html).encode("utf-8", errors="surrogateescape")
    )


if __name__ == "__main__":
    main()
