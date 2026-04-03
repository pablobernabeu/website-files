"""
Auto-generate Scopus query scripts for publications that have a fulltext.pdf
but no hand-crafted 'related references.R' query script.

Discovers eligible publications, extracts reference titles from their PDFs,
selects up to 20 titles, and writes 'related references/related references.R'
scripts that the main R pipeline can use.
"""
import pdfplumber
import re
import os
import datetime

PUB_ROOT = os.path.join("content", "publication")
MAX_TITLES = 20


def extract_text(pdf_path):
    """Extract all text from a PDF."""
    text = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            t = page.extract_text()
            if t:
                text.append(t)
    return "\n".join(text)


def find_references_section(text):
    """Find the references/bibliography section of a paper."""
    # Common section headers (strict: on own line)
    strict_patterns = [
        r'\n\s*References?\s*\n',
        r'\n\s*REFERENCES?\s*\n',
        r'\n\s*Bibliography\s*\n',
        r'\n\s*BIBLIOGRAPHY\s*\n',
        r'\n\s*Works?\s+[Cc]ited\s*\n',
        r'\n\s*Literature\s+[Cc]ited\s*\n',
    ]
    # Flexible patterns for two-column PDFs where header merges with adjacent text
    flex_patterns = [
        r'\nReferences\s',
        r'\nREFERENCES\s',
        r'\nBibliography\s',
    ]
    best_pos = -1
    for pat in strict_patterns:
        m = re.search(pat, text)
        if m and m.start() > best_pos:
            best_pos = m.end()
    
    if best_pos < 0:
        # Fallback: look in last third with strict patterns
        last_third = text[len(text) * 2 // 3:]
        for pat in strict_patterns:
            m = re.search(pat, last_third)
            if m:
                best_pos = len(text) * 2 // 3 + m.end()
                break
    
    if best_pos < 0:
        # Fallback: flexible patterns in last 40% of text
        last_part = text[len(text) * 3 // 5:]
        for pat in flex_patterns:
            m = re.search(pat, last_part)
            if m:
                best_pos = len(text) * 3 // 5 + m.start()
                # Skip to next newline after the header word
                nl = text.find('\n', best_pos + 1)
                if nl > 0:
                    best_pos = nl + 1
                break
    
    if best_pos < 0:
        return None
    
    # Get everything after the References header
    # Stop at known post-reference sections or end
    ref_text = text[best_pos:]
    end_patterns = [
        r'\n\s*Appendi(?:x|ces)',
        r'\n\s*APPENDI(?:X|CES)',
        r'\n\s*Supplementary\s',
        r'\n\s*SUPPLEMENTARY\s',
        r'\n\s*Supporting\s+[Ii]nformation',
        r'\n\s*Author\s+[Cc]ontributions?',
        r'\n\s*Acknowledgment',
        r'\n\s*Authors?\s+and\s+Affiliations?',
        r"\n\s*Publisher.s\s+Note",
    ]
    for pat in end_patterns:
        m = re.search(pat, ref_text)
        if m:
            ref_text = ref_text[:m.start()]
            break
    
    return ref_text


def extract_titles_from_refs(ref_text):
    """
    Extract article/book titles from APA-style reference entries.
    
    APA pattern: Author(s) (Year). Title. Journal/Publisher...
    The title follows the year parenthetical and ends with a period
    before the journal name (usually in italics, but we can't see that in plain text).
    """
    titles = []
    
    # Split into individual references - each starts with a capital letter or author name
    # after a blank line or at the start
    lines = ref_text.strip().split('\n')
    
    # Rejoin into reference entries
    entries = []
    current = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            if current:
                entries.append(' '.join(current))
                current = []
            continue
        # Check if this line starts a new reference (starts with author pattern)
        # Author patterns: "Lastname, F." or "Lastname, First" or numbered "[1]"
        if (re.match(r'^[A-Z][a-zA-ZÀ-ÿ\'\-]+,\s', stripped) or
            re.match(r'^\[\d+\]', stripped) or
            re.match(r'^\d+\.\s', stripped)) and current:
            entries.append(' '.join(current))
            current = [stripped]
        else:
            current.append(stripped)
    if current:
        entries.append(' '.join(current))
    
    for entry in entries:
        # Try to extract title: text between "(YEAR)." or "(YEAR)," and the next period
        # that precedes a journal-like pattern
        m = re.search(r'\(\d{4}[a-z]?\)\.\s*(.+?)(?:\.\s*[A-Z]|\.\s*In\s|\.\s*\(|\.\s*http|\.\s*doi|\.\s*Retrieved|\.\s*$)', entry)
        if m:
            title = m.group(1).strip()
            # Clean up
            title = re.sub(r'\s+', ' ', title)
            title = title.rstrip('.')
            if len(title) > 10 and len(title) < 500:
                titles.append(title)
                continue
        
        # Fallback: try numbered reference style  [1] Author... Title. Journal
        m = re.search(r'(?:\[\d+\]|\d+\.)\s*[A-Z].*?\.\s*(.+?)(?:\.\s*[A-Z]|\.\s*In\s|\.\s*http|\.\s*doi|\.\s*$)', entry)
        if m:
            title = m.group(1).strip().rstrip('.')
            if len(title) > 10 and len(title) < 500:
                titles.append(title)
    
    return titles


def discover_pubs_needing_queries():
    """Find publications with fulltext.pdf but no related references R script."""
    pubs = []
    for entry in sorted(os.listdir(PUB_ROOT)):
        pub_dir = os.path.join(PUB_ROOT, entry)
        if not os.path.isdir(pub_dir) or entry.startswith(("_", ".")):
            continue
        pdf_path = os.path.join(pub_dir, "fulltext.pdf")
        if not os.path.exists(pdf_path):
            continue
        # Check for existing script in any common directory name variant
        has_script = False
        for dname in ["related references", "related-references"]:
            script = os.path.join(pub_dir, dname, "related references.R")
            if os.path.exists(script):
                has_script = True
                break
        if not has_script:
            pubs.append(entry)
    return pubs


def extract_pub_year(pub_dir):
    """Extract the publication year from the index.md frontmatter."""
    for fname in ["index.md", "_index.md"]:
        index_path = os.path.join(pub_dir, fname)
        if os.path.exists(index_path):
            with open(index_path, encoding="utf-8") as f:
                content = f.read()
            m = re.search(r'^date:\s*["\']?(\d{4})', content, re.MULTILINE)
            if m:
                return int(m.group(1))
    return None


def generate_r_script(pub_name, titles, pub_year):
    """Generate a related references R script with the given titles."""
    current_year = datetime.date.today().year
    if pub_year is None:
        pub_year = current_year - 1
    # Ensure at least a 7-year search window
    search_start = min(pub_year, current_year - 6)
    search_end = current_year

    # Build query lines using R's double-quoted strings.
    # Titles are wrapped in Scopus literal quotes inside the R string,
    # e.g.  "\"Some title\" OR ",
    # Single quotes in titles are safe; double quotes are escaped.
    lines = []
    for i, t in enumerate(titles):
        # Escape backslashes first, then double quotes for R string literals
        escaped = t.replace("\\", "\\\\").replace('"', '\\"')
        if i < len(titles) - 1:
            lines.append(f'    "\\"{escaped}\\" OR ",')
        else:
            lines.append(f'    "\\"{escaped}\\""')
    query_block = "\n".join(lines)

    refs_dir = f"content/publication/{pub_name}/related references"

    return f'''
# Run `scopus_search` as many times as necessary based on the number of results, 
# limited to limit of results per search allowed by my API quota (normally, 20).

library(dplyr)
library(rscopus)

# Note. Before running the current function, the user must read in their Scopus API key 
# confidentially (see https://cran.r-project.org/web/packages/rscopus/vignettes/api_key.html).
# An error will be thrown if there's no Scopus API key registered.

query = 
  paste(
{query_block}
  )

search_period = '{search_start}-{search_end}'

# Read in 'scopus_search_plus' function
source('https://raw.githubusercontent.com/pablobernabeu/rscopus_plus/main/scopus_search_plus.R')

results = scopus_search_plus(query, search_period, 20)

# List and save DOIs, which can then be copied and pasted into a reference manager, 
# such as Zotero, to create the list of references.

DOIs = results[complete.cases(results$doi), 'doi']

cat(DOIs, sep = '\\n')

write.csv(DOIs, '{refs_dir}/related references.csv', row.names = FALSE)
'''


def main():
    pubs = discover_pubs_needing_queries()

    if not pubs:
        print("All publications with fulltext.pdf already have query scripts.")
        return

    print(f"Found {len(pubs)} publication(s) needing auto-generated queries:")
    for p in pubs:
        print(f"  - {p}")

    generated = 0

    for pub in pubs:
        pub_dir = os.path.join(PUB_ROOT, pub)
        pdf_path = os.path.join(pub_dir, "fulltext.pdf")

        print(f"\n{'='*60}")
        print(f"Processing: {pub}")
        print(f"{'='*60}")

        text = extract_text(pdf_path)
        print(f"  Total text length: {len(text)} chars")

        ref_section = find_references_section(text)
        if ref_section is None:
            print(f"  WARNING: Could not find references section, skipping")
            continue

        print(f"  References section: {len(ref_section)} chars")

        titles = extract_titles_from_refs(ref_section)
        print(f"  Extracted {len(titles)} raw titles")

        if not titles:
            print(f"  WARNING: No titles extracted, skipping")
            continue

        # Select up to MAX_TITLES titles
        selected = titles[:MAX_TITLES]
        print(f"  Selected {len(selected)} titles for query")

        pub_year = extract_pub_year(pub_dir)

        # Generate and write the R script
        refs_dir = os.path.join(pub_dir, "related references")
        os.makedirs(refs_dir, exist_ok=True)
        script_path = os.path.join(refs_dir, "related references.R")

        script_content = generate_r_script(pub, selected, pub_year)
        with open(script_path, "w", encoding="utf-8") as f:
            f.write(script_content)

        print(f"  Generated: {script_path}")
        generated += 1

    print(f"\nDone. Generated {generated} query script(s).")


if __name__ == "__main__":
    main()
