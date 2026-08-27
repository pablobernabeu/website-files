#!/usr/bin/env python3
"""Drop stored abstracts from the related references least likely to be read.

Abstracts are roughly four fifths of the weight of a Related References page.
Everything below the top of the ranking still ships its abstract to every
visitor, and on the largest pages that is several megabytes nobody reads.

Pruning is only safe against the ranking the reader itself computes. Cheaper
proxies were measured and rejected: keeping the top 2,000 by title similarity
alone displaces 84 of the reader's true top 1,000, and truncating every
abstract to 300 characters displaces 206. So this script reproduces the
reader's scoring from static/js/related-references.js, ranks by it, and keeps
the abstracts of the top KEEP references.

KEEP used to be justified as 2.5x a hard display cap of 1,000 references. That
cap is gone: the reader now renders RELATED_REFERENCES_PAGE_SIZE (100) at a
time behind a "show more", so every reference is reachable and no rank is
beyond the reader by construction. What replaces the cap as a justification is
how far anyone actually pages. KEEP = 2,500 is twenty-five pages deep, well
past any plausible session, and it keeps the margin the original figure was
chosen for: removing an abstract shrinks the corpus vocabulary, which moves the
rare-word threshold for every reference, so a pruned page re-scores slightly
differently in the reader.

Two consequences worth stating plainly rather than burying:

- A pruned reference is re-scored title-only by the reader, because
  computeRelevance weights an abstract when it has one. That is 60% of the
  thesis page and 53% of man-as-default. Pruning therefore changes the ranking
  it is derived from.
- Because prune_publication() scores from the current, already-pruned
  metadata, a pruned reference cannot climb back into the keep set, and a
  second pass over an unchanged page still finds more to prune. Ranking against
  "has an abstract or once had one" would make this idempotent; it does not do
  that yet.

Pruned entries keep their type and are marked "abstractPruned": true. The
reader treats that as "an abstract exists upstream, do not bulk-fetch it, but
do offer it on demand", and the collector treats it as "do not store this
abstract again".

Usage:
    python scripts/prune_reference_abstracts.py            # report only
    python scripts/prune_reference_abstracts.py --apply    # rewrite the files
"""

import argparse
import glob
import html as html_module
import io
import json
import os
import re
import sys

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("PyYAML is required: pip install pyyaml")

KEEP = 2500

# --------------------------------------------------------------------------
# Mirrors of the reader's text handling. Any divergence here shifts scores, so
# each function below tracks a named counterpart in related-references.js.
# --------------------------------------------------------------------------

# STOPWORDS in related-references.js
_STOPWORDS = set((
    'a an the and or but in on of to for with from by at is are was were be been being '
    'have has had do does did will would shall should may might can could not no nor '
    'this that these those it its he she they them their his her we our you your i me my '
    'if then than so as also very much more most all each any some such into about between '
    'through during before after above below up down out off over under again further too '
    'how what which who whom where when why there here just only both few many several '
    'other another new case study using used based evidence effects effect role'
).split(' '))

_NON_WORD = re.compile(r'[^a-z0-9À-ſ]+')


def tokenize(text):
    """tokenize() in related-references.js."""
    return [w for w in _NON_WORD.sub(' ', text.lower()).split()
            if len(w) > 2 and w not in _STOPWORDS]


def bigrams(tokens):
    """bigrams() in related-references.js."""
    return [tokens[i] + ' ' + tokens[i + 1] for i in range(len(tokens) - 1)]


def jaccard(a, b):
    """jaccard() in related-references.js, over Python sets."""
    union = len(a | b)
    return (len(a & b) / union) if union else 0.0


# decodeEntities() in related-references.js decodes only this table plus
# numeric references. Using Python's full entity table here would decode more
# than the reader does and drift the scores apart.
_NAMED_ENTITIES = {
    'amp': '&', 'apos': "'", 'quot': '"', 'nbsp': ' ', 'lt': '<', 'gt': '>',
    'ndash': '–', 'mdash': '—', 'lsquo': '‘', 'rsquo': '’',
    'ldquo': '“', 'rdquo': '”', 'hellip': '…',
}
_NUMERIC_ENTITY = re.compile(r'&#(x?)([0-9A-Fa-f]+);', re.I)
_NAMED_ENTITY = re.compile(r'&([A-Za-z]+);')


def _numeric(match):
    try:
        code = int(match.group(2), 16 if match.group(1) else 10)
    except ValueError:
        return match.group(0)
    return chr(code) if 0 < code <= 0x10FFFF else match.group(0)


def decode_entities(text):
    """decodeEntities() in related-references.js."""
    if '&' not in text:
        return text
    out, passes = text, 0
    while passes < 5:
        previous = out
        out = _NAMED_ENTITY.sub(
            lambda m: _NAMED_ENTITIES.get(m.group(1).lower(), m.group(0)),
            _NUMERIC_ENTITY.sub(_numeric, out))
        passes += 1
        if out == previous:
            break
    return out


def clean_abstract(text):
    """cleanAbstract() in related-references.js."""
    clean = text if '<' not in text else re.sub(r'<[^>]+>', '', text)
    clean = decode_entities(clean)
    clean = re.sub(r'^\s*Abstract[:\.]?\s*', '', clean, flags=re.I)
    return clean.strip()


# applyApaItalics() in related-references.js. The reader rewrites citation
# markup before reading the text it scores, so skipping this step scores
# different text: parity against the browser drops from 98.75% to 87%.
_JOURNAL = re.compile(
    r'(\.\s+)([^.<>]+?),\s*(\d{1,4})(?![–—-])(\([^)]+\))?'
    r'((?:,\s*[\w\d–-]+(?:[–-]\d+)?)*)'
    r'(\.\s*(?:https?://\S+\s*)?\s*<a\s+href)', re.I)
_PROCEEDINGS = re.compile(
    r'(\.\s+)([^.<>]+?),\s*(\d+[–—-]\d+)'
    r'(\.\s*(?:https?://\S+\s*)?\s*<a\s+href)', re.I)
_AHEAD_OF_PRINT = re.compile(
    r'(\.\s+)([^.<>]+?)(\.\s*(?:https?://\S+\s*)?\s*<a\s+href)', re.I)


def apply_apa_italics(markup):
    """applyApaItalics() in related-references.js."""
    markup = re.sub(r'\.?\s*Portico\.?', '', markup)
    result = _JOURNAL.sub(
        lambda m: (m.group(1) + '<em>' + m.group(2) + '</em>, <em>' + m.group(3)
                   + '</em>' + (m.group(4) or '') + (m.group(5) or '') + m.group(6)),
        markup)
    if result == markup:
        result = _PROCEEDINGS.sub(
            lambda m: m.group(1) + '<em>' + m.group(2) + '</em>, ' + m.group(3) + m.group(4),
            result)
    if result == markup:
        result = _AHEAD_OF_PRINT.sub(
            lambda m: m.group(1) + '<em>' + m.group(2) + '</em>' + m.group(3),
            result)
    return result


def paragraph_text(paragraph_markup):
    """The citation text the reader scores, matching enhanceSection().

    The reader italicises a paragraph only when it carries no <em> or <i>, then
    reads textContent, which decodes every HTML entity.
    """
    inner = re.sub(r'^<p[^>]*>|</p>$', '', paragraph_markup.strip())
    if not re.search(r'<(em|i)[ >]', inner):
        inner = apply_apa_italics(inner)
    return html_module.unescape(re.sub(r'<[^>]+>', '', inner)).replace(' ', ' ')


def extract_ref_title(text):
    """extractRefTitle() in related-references.js."""
    match = re.search(r'\)\.\s+(.+?)(?:\.\s+(?:\*|In\s|http|<))', text, re.S)
    if match:
        return match.group(1)
    match = re.search(r'\)\.\s+(.+?)\.\s', text, re.S)
    return match.group(1) if match else text


def compute_relevance(core, ref_text, ref_abstract, word_freqs, rare_threshold, query):
    """computeRelevance() in related-references.js, same weights."""
    ref_title = extract_ref_title(ref_text)
    title_tokens = tokenize(ref_title)
    if not title_tokens:
        return 0
    title_set = set(title_tokens)
    title_bigrams = set(bigrams(title_tokens))

    title_uni = jaccard(core['title_set'], title_set)
    title_bi = jaccard(core['title_bigrams'], title_bigrams)

    abs_uni = abs_bi = 0.0
    has_abstracts = bool(core['abstract_tokens']) and bool(ref_abstract)
    ref_abs_set = set()
    if has_abstracts:
        ref_abs_tokens = tokenize(ref_abstract)
        if ref_abs_tokens:
            ref_abs_set = set(ref_abs_tokens)
            abs_uni = jaccard(core['abstract_set'], ref_abs_set)
            abs_bi = jaccard(core['abstract_bigrams'], set(bigrams(ref_abs_tokens)))
        else:
            has_abstracts = False

    core_tokens = core['merged_set'] if has_abstracts else core['title_set']
    ref_tokens = (title_set | ref_abs_set) if has_abstracts else title_set
    shared = possible = 0
    for word in core_tokens:
        count = word_freqs.get(word)
        if count and count <= rare_threshold:
            possible += 1
            if word in ref_tokens:
                shared += 1
    rare = (shared / possible) if possible else 0.0

    query_bonus = 0.0
    if query:
        lowered = query.lower()
        if ref_title.lower() in lowered:
            query_bonus = 1.0
        else:
            hits = sum(1 for w in title_tokens if w in lowered)
            query_bonus = hits / len(title_tokens) if title_tokens else 0.0

    if has_abstracts:
        raw = (title_uni * 0.25 + title_bi * 0.15 + abs_uni * 0.20
               + abs_bi * 0.10 + rare * 0.20 + query_bonus * 0.10)
    else:
        raw = title_uni * 0.40 + title_bi * 0.30 + rare * 0.20 + query_bonus * 0.10
    return max(0, min(100, round(raw * 350)))


# --------------------------------------------------------------------------
# Page handling
# --------------------------------------------------------------------------

def read_front_matter(publication_dir):
    for candidate in ('index.md', 'index.en.Rmd', 'index.en.md'):
        path = os.path.join(publication_dir, candidate)
        if os.path.exists(path):
            text = io.open(path, encoding='utf-8').read()
            lines = text.split('\n')
            fences = [i for i, line in enumerate(lines) if line.strip() == '---']
            if len(fences) >= 2:
                return yaml.safe_load('\n'.join(lines[fences[0] + 1:fences[1]])) or {}
            return {}
    return {}


def core_context(front_matter):
    """What getCoreTitle() and getCoreAbstract() read from the built page.

    site_head.html sets og:title from the page title and the meta description
    from `summary`, falling back to `abstract`. Verified against the deployed
    thesis page: both reconstruct exactly.
    """
    title = str(front_matter.get('title', '') or '')
    description = str(front_matter.get('summary') or front_matter.get('abstract') or '')
    title_tokens = tokenize(title)
    abstract_tokens = tokenize(description)
    title_set = set(title_tokens)
    abstract_set = set(abstract_tokens)
    return {
        'title_set': title_set,
        'title_bigrams': set(bigrams(title_tokens)),
        'abstract_tokens': abstract_tokens,
        'abstract_set': abstract_set,
        'abstract_bigrams': set(bigrams(abstract_tokens)),
        'merged_set': title_set | abstract_set,
    }


def load_page(refs_path):
    source = io.open(refs_path, encoding='utf-8').read()
    meta_match = re.search(
        r'(<script[^>]*class="ref-metadata"[^>]*>)(.*?)(</script>)', source, re.S)
    if not meta_match:
        return None
    metadata = json.loads(meta_match.group(2).strip())
    query_match = re.search(
        r'<script[^>]*class="scopus-queries"[^>]*>(.*?)</script>', source, re.S)
    query = ''
    if query_match:
        parsed = json.loads(query_match.group(1).strip())
        query = (parsed[0].get('query', '') if isinstance(parsed, list)
                 else parsed.get('query', '')) or ''
    body = re.sub(r'<script.*?</script>', '', source, flags=re.S)
    references = []
    for paragraph in re.findall(r'<p[ >].*?</p>', body, re.S):
        text = paragraph_text(paragraph)
        if not text.strip():
            continue
        doi_match = re.search(r'doi\.org/([^"<\s]+)', paragraph)
        references.append({'doi': doi_match.group(1) if doi_match else None,
                           'text': text})
    return {'source': source, 'metadata': metadata, 'query': query,
            'references': references, 'meta_match': meta_match}


def metadata_entry(metadata, doi):
    if not doi:
        return None
    return metadata.get(doi) or metadata.get(doi.lower())


def prune_publication(publication_dir, apply_changes):
    refs_path = os.path.join(publication_dir, 'related-references.html')
    if not os.path.exists(refs_path):
        return None
    page = load_page(refs_path)
    if page is None:
        return None

    core = core_context(read_front_matter(publication_dir))
    metadata, references, query = page['metadata'], page['references'], page['query']

    for ref in references:
        entry = metadata_entry(metadata, ref['doi']) or {}
        raw = entry.get('abstract')
        ref['abstract'] = clean_abstract(raw) if raw else ''

    word_freqs = {}
    for ref in references:
        words = set(tokenize(extract_ref_title(ref['text']) + ' ' + ref['abstract']))
        for word in words:
            word_freqs[word] = word_freqs.get(word, 0) + 1
    rare_threshold = max(3, len(word_freqs) // 10)

    for index, ref in enumerate(references):
        ref['index'] = index
        ref['score'] = compute_relevance(core, ref['text'], ref['abstract'],
                                         word_freqs, rare_threshold, query)

    with_abstract = [r for r in references if r['abstract'] and r['doi']]
    ranked = sorted(references, key=lambda r: (-r['score'], r['index']))
    keep_dois = {r['doi'] for r in ranked[:KEEP] if r['doi']}

    pruned, freed = 0, 0
    if apply_changes:
        for key, entry in metadata.items():
            if not isinstance(entry, dict) or not entry.get('abstract'):
                continue
            if key in keep_dois or key.lower() in {d.lower() for d in keep_dois}:
                continue
            freed += len(entry['abstract'])
            del entry['abstract']
            entry['abstractPruned'] = True
            pruned += 1
        # Keep the block on three lines: opening tag, JSON, closing tag. The
        # collector removes an existing block by finding "</script>" on a line
        # *after* the opening tag, so collapsing them onto one line would stop
        # it matching and it would append a second block on the next run.
        rewritten = json.dumps(metadata, separators=(',', ':'), ensure_ascii=False)
        source = page['source']
        start, end = page['meta_match'].span(2)
        updated = source[:start] + '\n' + rewritten + '\n' + source[end:]
        io.open(refs_path, 'wb').write(updated.encode('utf-8'))
    else:
        keep_lower = {d.lower() for d in keep_dois}
        for key, entry in metadata.items():
            if isinstance(entry, dict) and entry.get('abstract') \
                    and key not in keep_dois and key.lower() not in keep_lower:
                pruned += 1
                freed += len(entry['abstract'])

    return {
        'name': os.path.basename(publication_dir.rstrip('/\\')),
        'references': len(references),
        'with_abstract': len(with_abstract),
        'kept': len(with_abstract) - pruned,
        'pruned': pruned,
        'freed': freed,
    }


def main():
    global KEEP
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true',
                        help='rewrite the files (default is a dry run)')
    parser.add_argument('--keep', type=int, default=KEEP,
                        help='abstracts to retain per publication (default %d)' % KEEP)
    args = parser.parse_args()
    KEEP = args.keep

    rows = []
    for publication_dir in sorted(glob.glob('content/publication/*/')):
        result = prune_publication(publication_dir, args.apply)
        if result:
            rows.append(result)

    print('%-46s %8s %8s %8s %8s %10s'
          % ('publication', 'refs', 'abstr', 'kept', 'pruned', 'freed'))
    total_pruned = total_freed = 0
    for row in rows:
        total_pruned += row['pruned']
        total_freed += row['freed']
        print('%-46s %8d %8d %8d %8d %9.1fK'
              % (row['name'][:46], row['references'], row['with_abstract'],
                 row['kept'], row['pruned'], row['freed'] / 1024))
    print()
    print('%s abstracts pruned, %.1f MB freed%s'
          % (f'{total_pruned:,}', total_freed / 1048576,
             '' if args.apply else '  (dry run: nothing written)'))


if __name__ == '__main__':
    main()
