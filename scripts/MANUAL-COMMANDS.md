# IndexNow Manual Submission Commands

## Single URL Submission

```bash
curl -X POST "https://api.indexnow.org/indexnow" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{
    "host": "pablobernabeu.github.io",
    "key": "ba7d2697a8f44966bd90543d188a8aac",
    "keyLocation": "https://pablobernabeu.github.io/ba7d2697a8f44966bd90543d188a8aac.txt",
    "urlList": ["https://pablobernabeu.github.io/"]
  }'
```

## Multiple URL Submission Example

```bash
curl -X POST "https://api.indexnow.org/indexnow" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{
    "host": "pablobernabeu.github.io",
    "key": "ba7d2697a8f44966bd90543d188a8aac",
    "keyLocation": "https://pablobernabeu.github.io/ba7d2697a8f44966bd90543d188a8aac.txt",
    "urlList": [
      "https://pablobernabeu.github.io/",
      "https://pablobernabeu.github.io/post/",
      "https://pablobernabeu.github.io/publication/"
    ]
  }'
```

## Response Codes

- 200/202: Success
- 400: Bad request (check format)
- 422: Invalid URLs
- 429: Rate limited

## Usage Instructions

1. Build your Hugo site: `hugo`
2. Run one of the scripts above
3. Check response for success/errors
