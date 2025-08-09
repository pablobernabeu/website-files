# IndexNow Setup for Hugo Academic Website

This implementation provides automatic URL submission to search engines using Bing's IndexNow protocol.

## 🚀 Features

1. **Initial Bulk Submission** - Submit all existing pages once
2. **Automatic Ongoing Submission** - New pages submitted via JavaScript
3. **Build-time Submission** - Submit changed pages on deployment

## 📁 Files Added

```
├── config.toml                                    # IndexNow configuration
├── static/
│   ├── ba7d2697a8f44966bd90543d188a8aac.txt       # API key verification file
│   └── js/indexnow.js                             # Automatic submission script
├── themes/hugo-academic/layouts/partials/
│   ├── site_head.html                             # Meta tags for IndexNow
│   └── site_js.html                               # JavaScript inclusion
├── scripts/
│   └── indexnow-bulk-submit.js                    # Bulk submission script
├── .github/workflows/
│   └── indexnow.yml                               # GitHub Actions workflow
└── package.json                                   # Node.js dependencies
```

## 🔧 Configuration

The following configuration has been added to `config.toml`:

```toml
[params.indexnow]
  enabled = true
  api_key = "ba7d2697a8f44966bd90543d188a8aac"
  host = "pablobernabeu.github.io"
  key_location = "https://pablobernabeu.github.io/ba7d2697a8f44966bd90543d188a8aac.txt"
```

## 📋 Usage

### 1. Initial Bulk Submission

Submit all existing pages to search engines:

```bash
# Install dependencies
npm install

# Build your Hugo site
hugo

# Submit all URLs from sitemap
npm run submit-urls
```

### 2. Automatic Submission

- **Enabled automatically** on all pages when `indexnow.enabled = true`
- **Submits current page** 2 seconds after page load
- **Works for visitors** browsing your site

### 3. GitHub Actions (Build-time)

- **Triggers automatically** on push to master/main branch
- **Builds Hugo site** and submits changed URLs
- **No manual intervention** required

## 🔍 Monitoring

### Check Submission Status

1. **Browser Console**: Look for IndexNow log messages
2. **Search Console**: Monitor indexing status in Bing/Google
3. **GitHub Actions**: Check workflow logs for bulk submissions

### Manual Testing

```javascript
// Test manual submission in browser console
IndexNow.submitUrl("https://pablobernabeu.github.io/some-page/");
```

## 🛠 Troubleshooting

### Common Issues

1. **Key file not accessible**

   - Ensure `ba7d2697a8f44966bd90543d188a8aac.txt` is in `/static/` directory
   - Check file is deployed to your website root

2. **CORS errors in browser**

   - Expected behavior for IndexNow API calls
   - Check browser console for success messages

3. **GitHub Actions failing**
   - Check workflow logs in GitHub Actions tab
   - Ensure dependencies are installed correctly

### Response Codes

- **200/202**: Success - URLs submitted and accepted
- **400**: Bad request - Check API key and URL format
- **422**: Invalid URLs - Some URLs may not be accepted
- **429**: Rate limited - Too many requests

## 🔒 Security Notes

- **API key** is public (required by IndexNow specification)
- **No sensitive data** exposed in submissions
- **GitHub Actions** uses repository secrets safely

## 📚 References

- [IndexNow Official Documentation](https://www.indexnow.org/)
- [Bing IndexNow Implementation Guide](https://www.bing.com/indexnow/getstarted)
- [Hugo Academic Theme](https://github.com/wowchemy/starter-hugo-academic)

---

✅ **Setup Complete** - Your website now automatically submits URLs to search engines!
