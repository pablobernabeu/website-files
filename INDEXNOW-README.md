# IndexNow Setup for the Hugo Academic Website

This site notifies IndexNow-participating search engines (Bing, Yandex, Seznam,
etc.) of its URLs whenever it is published, using the [IndexNow](https://www.indexnow.org/)
protocol. Submission is **server-side, at deploy time** — it does not run in
visitors' browsers.

## How it works

1. **Key verification file** — `static/ba7d2697a8f44966bd90543d188a8aac.txt`
   is deployed to the site root so search engines can verify ownership.
2. **Configuration** — `config.toml` holds the IndexNow parameters (below). The
   theme also emits `indexnow-*` `<meta>` tags from these values
   (`themes/hugo-academic/layouts/partials/site_head.html`).
3. **Submission** — `.github/workflows/indexnow-ping.yml` runs after every
   successful "Deploy to GitHub Pages" run (plus a weekly cron and a manual
   trigger). It fetches the live `sitemap.xml`, extracts every `<loc>`, and
   POSTs the list to `https://api.indexnow.org/indexnow`.

## Configuration

```toml
[params.indexnow]
  enabled = true
  api_key = "ba7d2697a8f44966bd90543d188a8aac"
  host = "pablobernabeu.github.io"
  key_location = "https://pablobernabeu.github.io/ba7d2697a8f44966bd90543d188a8aac.txt"
```

## Manual submission

Run the workflow on demand from the GitHub **Actions** tab → **IndexNow
submission** → **Run workflow**. No local Node.js setup or npm scripts are
required.

## Monitoring

- **GitHub Actions logs** — the `indexnow-ping` run prints the URL count and the
  IndexNow HTTP response (200 = accepted, 202 = received/validating).
- **Bing Webmaster Tools** — monitor indexing/IndexNow status there.

## Response codes

| Code | Meaning |
|------|---------|
| 200  | Success — URLs accepted |
| 202  | Received — URLs validating |
| 400  | Bad request — check key/URL format |
| 403  | Forbidden — key not valid / not found at key location |
| 422  | Unprocessable — URLs don't match the host or key location |
| 429  | Too many requests — rate limited |

## Security notes

- The IndexNow **API key is public by design** (it must be readable at the key
  location URL). No secrets are involved.
- Submissions contain only public URLs.

## References

- [IndexNow documentation](https://www.indexnow.org/)
- [Bing IndexNow getting started](https://www.bing.com/indexnow/getstarted)

## Notes

- `static/js/indexnow.js` is loaded by the theme (`site_js.html`, gated on
  `indexnow.enabled`) and exposes `window.IndexNow` for manual submission. Its
  per-visitor auto-submit has been **disabled** in favour of the deploy-time
  workflow above, so it no longer fires a request on every page view.
