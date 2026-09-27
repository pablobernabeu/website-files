#!/usr/bin/env python3
"""
Subresource Integrity (SRI) check for the files the built site loads from cdnjs.

When a file's hash differs from the integrity attribute on its <script> or
<link>, the browser refuses the file and nothing on the page says so: with a
wrong hash for highlight.js's languages/r.min.js, the R code on every post
would simply lose its highlighting. The hashes are recorded by hand in
themes/hugo-academic/data/assets.toml, so this runs before each deploy.

Every <script src> and every <link rel="stylesheet|preload|modulepreload" href>
on cdnjs.cloudflare.com in the built pages is collected with its integrity
attribute. Each distinct file is downloaded once with curl (as in the recipe at
the top of assets.toml), hashed and compared with the attribute the way a
browser compares it (the strongest algorithm listed decides).

Exit status 1, which stops the deploy, when a file does not match its
integrity attribute or cdnjs has no such file (404 or 410). The same happens
when a tag has a hash in its integrity attribute but no crossorigin attribute:
a browser cannot check a cross-origin file fetched without CORS, so it refuses
the file.

A download that fails for any other reason after curl's retries is only a
warning, since a CDN outage says nothing about the hashes. So is a file left
unchecked once the downloads have taken TIME_BUDGET seconds in all, which
keeps a CDN that hangs, rather than refusing connections, from holding the
deploy past the step's timeout. A cdnjs file loaded with no integrity attribute
is a warning too, which gives the hash cdnjs serves today; check it against
https://cdnjs.com/ before recording it.

Usage: verify_cdn_sri.py [SITE_DIR]   (default: public)
"""
import base64
import hashlib
import os
import subprocess
import sys
import tempfile
import time
from html.parser import HTMLParser
from urllib.parse import urlsplit

CDN_HOST = "cdnjs.cloudflare.com"
# Link types that fetch a file the integrity attribute applies to. A preconnect
# or dns-prefetch link names only the host and is left out.
SRI_LINK_TYPES = {"stylesheet", "preload", "modulepreload"}
# Weakest first. A browser checks only the hashes of the strongest algorithm an
# integrity attribute lists, and ignores the rest.
ALGORITHMS = ("sha256", "sha384", "sha512")
# Seconds allowed for all the downloads together. The deploy step's
# timeout-minutes (5) must stay above this plus the time needed to read the
# built pages (a few seconds), or a hanging CDN fails the job after all.
TIME_BUDGET = 180
IN_CI = os.environ.get("GITHUB_ACTIONS") == "true"


class CdnReferences(HTMLParser):
    """Collects (url, integrity, has_crossorigin) for each cdnjs script and stylesheet."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.found = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "script":
            url = attrs.get("src")
        elif tag == "link" and SRI_LINK_TYPES & set((attrs.get("rel") or "").lower().split()):
            url = attrs.get("href")
        else:
            return
        if url and url.startswith("//"):
            url = "https:" + url
        if url and urlsplit(url).hostname == CDN_HOST:
            # A bare `integrity` (as the minifier writes an empty one) parses as
            # None. A bare `crossorigin` means anonymous, so only its absence counts.
            self.found.append((url, (attrs.get("integrity") or "").strip(),
                               "crossorigin" in attrs))


def collect(site_dir):
    """Returns ({url: {integrity: [pages]}}, {url: [pages]}) over every HTML file under
    site_dir. The second dict lists the pages whose tag for url carries an integrity
    check but no crossorigin attribute."""
    refs = {}
    no_cors = {}
    for dirpath, _dirs, filenames in os.walk(site_dir):
        for fn in filenames:
            if not fn.endswith(".html"):
                continue
            path = os.path.join(dirpath, fn)
            parser = CdnReferences()
            with open(path, encoding="utf-8", errors="replace") as fh:
                parser.feed(fh.read())
            page = os.path.relpath(path, site_dir)
            for url, integrity, has_crossorigin in parser.found:
                refs.setdefault(url, {}).setdefault(integrity, []).append(page)
                if parse_integrity(integrity)[0] and not has_crossorigin:
                    no_cors.setdefault(url, []).append(page)
    return refs, no_cors


def parse_integrity(value):
    """Returns the hashes a browser would check against: those of the strongest algorithm listed."""
    hashes = {}
    for token in value.split():
        algorithm, _, digest = token.partition("-")
        algorithm = algorithm.lower()
        if algorithm in ALGORITHMS and digest:
            # Anything after "?" is an option, which does not form part of the hash.
            hashes.setdefault(algorithm, set()).add(digest.split("?", 1)[0])
    for algorithm in reversed(ALGORITHMS):
        if algorithm in hashes:
            return algorithm, hashes[algorithm]
    return None, set()


def download(url, dest, seconds):
    """Fetches url into dest with curl, stopping it after `seconds` at most.

    Returns the HTTP status, or None if no response came in time. Each attempt
    gives up after 10 s without a connection or 30 s in all, and curl starts no
    retry more than 60 s after the first attempt began, so one file takes about
    65 s at worst."""
    try:
        result = subprocess.run(
            ["curl", "--silent", "--show-error", "--location",
             "--connect-timeout", "10", "--max-time", "30",
             "--retry", "2", "--retry-delay", "3", "--retry-max-time", "60",
             "--output", dest, "--write-out", "%{http_code}", url],
            capture_output=True, text=True, timeout=seconds)
    except subprocess.TimeoutExpired:
        print(f"    curl stopped after {seconds:.0f} s, when the time budget ran out")
        return None
    if result.returncode != 0:
        print(f"    {result.stderr.strip()}")
        return None
    return int(result.stdout.strip() or 0)


def b64_digest(data, algorithm):
    return base64.b64encode(hashlib.new(algorithm, data).digest()).decode()


def annotate(level, message):
    print(f"::{level}::{message}" if IN_CI else f"{level.upper()}: {message}")


def where(pages):
    return f"{len(pages)} page(s), e.g. {sorted(pages)[0]}"


def main():
    site_dir = sys.argv[1] if len(sys.argv) > 1 else "public"
    if not os.path.isdir(site_dir):
        sys.exit(f"{site_dir} is not a directory; build the site first.")
    refs, no_cors = collect(site_dir)
    if not refs:
        print(f"No {CDN_HOST} files are referenced under {site_dir}.")
        return 0

    verified = failures = warnings = 0
    # Chromium, for one, blocks such a file outright ("the resource requires the
    # request to be CORS enabled to check the integrity"), whatever its hash.
    for url, pages in sorted(no_cors.items()):
        annotate("error", f"{url} has an integrity attribute but no crossorigin attribute on "
                          f"{where(pages)}. Browsers refuse a cross-origin file whose integrity "
                          f"they cannot check without CORS; add crossorigin=\"anonymous\".")
        failures += 1

    deadline = time.monotonic() + TIME_BUDGET
    with tempfile.TemporaryDirectory() as tmp:
        dest = os.path.join(tmp, "file")
        for url in sorted(refs):
            print(url)
            seconds_left = deadline - time.monotonic()
            if seconds_left <= 0:
                annotate("warning", f"Could not verify {url} (the {TIME_BUDGET} s time budget "
                                    f"for downloads is spent).")
                warnings += 1
                continue
            status = download(url, dest, seconds_left)
            if status in (404, 410):
                annotate("error", f"{url} does not exist on {CDN_HOST} (HTTP {status}); "
                                  f"referenced by {where(sum(refs[url].values(), []))}.")
                failures += 1
                continue
            if status != 200:
                reason = "no response" if status is None else f"HTTP {status}"
                annotate("warning", f"Could not verify {url} ({reason}).")
                warnings += 1
                continue
            with open(dest, "rb") as fh:
                data = fh.read()

            for integrity, pages in sorted(refs[url].items()):
                algorithm, expected = parse_integrity(integrity)
                if algorithm is None:
                    annotate("warning", f"{url} loads with no integrity check on {where(pages)}. "
                                        f"cdnjs serves sha512-{b64_digest(data, 'sha512')}")
                    warnings += 1
                    continue
                actual = b64_digest(data, algorithm)
                if actual in expected:
                    print(f"    ok  {algorithm}-{actual}")
                    verified += 1
                else:
                    annotate("error", f"SRI mismatch for {url} on {where(pages)}: the page expects "
                                      f"{integrity}, cdnjs serves {algorithm}-{actual}. Browsers will "
                                      f"refuse this file.")
                    failures += 1

    print(f"\n{verified} verified, {failures} failed, {warnings} warning(s), "
          f"across {len(refs)} {CDN_HOST} file(s).")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
