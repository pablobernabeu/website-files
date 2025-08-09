#!/bin/bash

# IndexNow Bulk Submission Script (Bash + curl)
# Submits all URLs from Hugo sitemap to IndexNow API

# Configuration
HOST="pablobernabeu.github.io"
API_KEY="ba7d2697a8f44966bd90543d188a8aac"
KEY_LOCATION="https://pablobernabeu.github.io/ba7d2697a8f44966bd90543d188a8aac.txt"
SITEMAP_PATH="public/sitemap.xml"
API_ENDPOINT="https://api.indexnow.org/indexnow"

echo "🔍 IndexNow Bulk Submission Script (Bash)"
echo "=========================================="

# Check if sitemap exists
if [ ! -f "$SITEMAP_PATH" ]; then
    echo "❌ Sitemap not found at: $SITEMAP_PATH"
    echo "💡 Make sure to build your Hugo site first with: hugo"
    exit 1
fi

# Extract URLs from sitemap using grep and sed
echo "📄 Reading sitemap from: $SITEMAP_PATH"

# Extract URLs from sitemap.xml
URLS=$(grep -oP '(?<=<loc>)[^<]+' "$SITEMAP_PATH" | grep "$HOST" || true)

if [ -z "$URLS" ]; then
    echo "⚠️  No URLs found in sitemap"
    exit 0
fi

# Count URLs
URL_COUNT=$(echo "$URLS" | wc -l)
echo "📊 Found $URL_COUNT URLs from your domain"

# Create JSON payload
echo "🚀 Creating JSON payload..."

# Convert URLs to JSON array format
URL_ARRAY=""
while IFS= read -r url; do
    if [ -n "$url" ]; then
        if [ -n "$URL_ARRAY" ]; then
            URL_ARRAY="$URL_ARRAY,"
        fi
        URL_ARRAY="$URL_ARRAY\"$url\""
    fi
done <<< "$URLS"

# Create complete JSON payload
JSON_PAYLOAD="{
  \"host\": \"$HOST\",
  \"key\": \"$API_KEY\",
  \"keyLocation\": \"$KEY_LOCATION\",
  \"urlList\": [$URL_ARRAY]
}"

echo "📝 Submitting to IndexNow API..."

# Submit to IndexNow
RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
    -X POST \
    -H "Content-Type: application/json; charset=utf-8" \
    -H "User-Agent: Hugo-IndexNow-Submitter/1.0" \
    -d "$JSON_PAYLOAD" \
    "$API_ENDPOINT")

# Extract HTTP status code
HTTP_STATUS=$(echo "$RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
RESPONSE_BODY=$(echo "$RESPONSE" | sed -e 's/HTTPSTATUS:.*//g')

# Check response
if [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 202 ]; then
    echo "✅ URLs submitted successfully (Status: $HTTP_STATUS)"
    echo "📊 Submitted $URL_COUNT URLs to search engines"
else
    echo "❌ Submission failed (Status: $HTTP_STATUS)"
    echo "Response: $RESPONSE_BODY"
fi

echo ""
echo "🎉 Bulk submission completed!"
echo ""
echo "📝 Next steps:"
echo "1. Check search console for indexing status"
echo "2. New pages will be automatically submitted via JavaScript"
echo "3. Use GitHub Actions for automatic submission on deployment"
