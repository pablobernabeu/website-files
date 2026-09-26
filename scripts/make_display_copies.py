#!/usr/bin/env python3
"""Write display-size WebP copies of full-resolution photos in a page bundle.

A phone photo is several thousand pixels wide, and a page that shows photos at
their own size makes every reader download all of those pixels, however small
the photos appear. This script writes copies 800, 1200 and 1600 pixels wide
beside each photo. The page offers them through srcset and lets the browser
choose, and keeps the original for its lightbox, which loads the file named in
data-full only when the reader opens that photo:

    <img src='images/1-800w.webp'
         srcset='images/1-800w.webp 800w, images/1-1200w.webp 1200w, images/1-1600w.webp 1600w'
         sizes='(max-width: 700px) calc(100vw - 40px), 346px'
         width='800' height='1778' data-full='images/1.webp' alt='...'>

In the half-width gallery that these sizes describe, a desktop screen takes the
800-pixel copy even at twice the usual pixel density, and a phone at three
times takes the 1200. The 1600 serves the few screens that need more, such as
a small tablet at twice.

The width and height attributes give the browser the photo's shape before it
arrives, so the page does not move as the photos load. The script prints them
for each copy. Image budget (.github/workflows/image-budget.yml) counts a file
named in data-full as loaded on request, not with the page.

A copy is named after its original, with spaces turned into hyphens because
srcset separates its candidates with whitespace. Colours are converted to sRGB
and the copy is saved without a colour profile, which browsers read as sRGB; a
phone's embedded profile can otherwise be a sixth of an 800-pixel copy. Camera
metadata is left out too, after any EXIF rotation has been applied to the
pixels. A width at or above the original's is skipped.

Usage: python3 scripts/make_display_copies.py [--quality Q] IMAGE [IMAGE ...]
Requires Pillow.
"""
import argparse
import io
import os
import sys

from PIL import Image, ImageCms, ImageOps

WIDTHS = (800, 1200, 1600)
DEFAULT_QUALITY = 80


def to_srgb(im):
    """Return the image as RGB in sRGB, converting from its embedded profile."""
    icc = im.info.get("icc_profile")
    im = im.convert("RGB")
    if icc:
        source = ImageCms.ImageCmsProfile(io.BytesIO(icc))
        im = ImageCms.profileToProfile(im, source, ImageCms.createProfile("sRGB"), outputMode="RGB")
    return im


def copy_name(path, width):
    stem, _ = os.path.splitext(os.path.basename(path))
    return os.path.join(os.path.dirname(path), f"{stem.replace(' ', '-')}-{width}w.webp")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("images", nargs="+")
    parser.add_argument("--quality", type=int, default=DEFAULT_QUALITY)
    args = parser.parse_args()

    for path in args.images:
        with Image.open(path) as original:
            im = to_srgb(ImageOps.exif_transpose(original))
        for width in WIDTHS:
            if width >= im.width:
                print(f"{path}: {im.width} px wide, no {width}w copy needed")
                continue
            height = round(im.height * width / im.width)
            out = copy_name(path, width)
            im.resize((width, height), Image.LANCZOS).save(out, "WEBP", quality=args.quality, method=6)
            print(f"{out}: {width}x{height}, {os.path.getsize(out) // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
