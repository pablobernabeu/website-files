#!/usr/bin/env python3
"""
Hold every reference on the site to one name for CRAN: "Comprehensive R Archive Network (CRAN)".

The R packages' citations and pkgdown sites name CRAN that way (rule 6 of check_doi_display.py
in each package repository), and so has every reference here since 2026-10-16. This check keeps
a new post or page from bringing back "CRAN." or a bare full name. Over the hand-written content
(.md, .Rmd, the .html knitted from them, and .bib files) it reports:

  * "CRAN." as the source just before a reference's link, in Markdown or in rendered HTML;
  * a pandoc-rendered <span>CRAN</span>, which comes from a .bib field;
  * a BibTeX publisher, institution or organization field that names CRAN in other words;
  * the full name without "(CRAN)" after it (a link on the abbreviation is fine);
  * a page's `publication:` line that names CRAN without the full name, since the theme prints
    it as the source in the page's citation;
  * a reference line that links a CRAN DOI (10.32614/CRAN.package.<pkg>) without naming CRAN.

Labels such as the "Citation (CRAN)" buttons, and prose such as "install it from CRAN", are not
references and are left alone. The auto-collected related-references.html files hold third-party
metadata and are skipped, as are generated asset folders.

A post's .Rmd and the .html knitted from it should change together, in one commit, so that the
deploy finds no stale .Rmd and re-knits nothing; this check reads both.

Exit code 1 on any finding. In GitHub Actions each finding is also an error annotation.
"""
import os
import re
import sys

ROOT = os.environ.get("CRAN_CHECK_DIR", "content")
EXTS = (".md", ".rmd", ".html", ".bib")
SKIP_NAMES = ("related-references.html",)
SKIP_SUBSTR = ("/rmarkdown-libs/", "_files/")
IN_CI = os.environ.get("GITHUB_ACTIONS") == "true"

NAME = "Comprehensive R Archive Network (CRAN)"
SOURCE = re.compile(r"(?<![\w(>])CRAN\.(?=[ \t]+(?:\[|<a\s|<)?https?://|[ \t]+<a\s)")
RENDERED = re.compile(r"<span>CRAN</span>\.")
FIELD = re.compile(r"\b(publisher|institution|organization)\s*=\s*(\{+|\")(.*?)(\}+|\")", re.I)
FULL = re.compile(r"(?i)\bComprehensive\s+R\s+Archive\s+Network\b"
                  r"(?!\s+\((?:CRAN|\[CRAN\]\([^)]*\)|<a\s[^>]*>CRAN</a>)\))")
CRAN_DOI_LINK = re.compile(r"https?://doi\.org/10\.32614/CRAN\.package\.")
REFERENCE_MARK = re.compile(r"\[(?:Computer software|R package)\]|\(Version |R package version")


def findings(text, path):
    """(line number, message) for each place the file names CRAN in other words."""
    out = []

    def add(pos, msg):
        out.append((text.count("\n", 0, pos) + 1, msg))

    for m in SOURCE.finditer(text):
        add(m.start(), f"a reference names its source in full: write '{NAME}.'")
    for m in RENDERED.finditer(text):
        add(m.start(), f"rendered from a .bib field that says CRAN: write {NAME} in the .bib")
    for m in FIELD.finditer(text):
        value = m.group(3).strip()
        if re.search(r"\bCRAN\b|R Archive Network", value) and value != NAME:
            add(m.start(), f"{m.group(1)} '{value}': write {NAME}")
    for m in FULL.finditer(text):
        add(m.start(), f"give the abbreviation after the name: {NAME}")
    pos = 0
    for line in text.split("\n"):
        if path.lower().endswith((".md", ".rmd")) and line.startswith("publication:") \
                and re.search(r"\bCRAN\b", line) and NAME not in line:
            add(pos, f"the publication line names CRAN: write {NAME}")
        if CRAN_DOI_LINK.search(line) and REFERENCE_MARK.search(line) and NAME not in line:
            add(pos, f"a reference to a CRAN DOI names its source before the link: '{NAME}.'")
        pos += len(line) + 1
    return out


def main():
    problems = []
    scanned = 0
    for dirpath, _, files in os.walk(ROOT):
        for name in files:
            path = os.path.join(dirpath, name).replace(os.sep, "/")
            if not name.lower().endswith(EXTS) or name in SKIP_NAMES \
                    or any(s in path + "/" for s in SKIP_SUBSTR):
                continue
            with open(path, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
            scanned += 1
            problems += [(path, line, msg) for line, msg in findings(text, path)]
    for path, line, msg in problems:
        print(f"{path}:{line}: {msg}")
        if IN_CI:
            print(f"::error file={path},line={line}::{msg}")
    print(f"CRAN name: {scanned} files read, {len(problems)} finding(s).")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
