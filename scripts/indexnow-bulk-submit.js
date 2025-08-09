#!/usr/bin/env node

/**
 * IndexNow Bulk Submission Script
 * Submits all URLs from Hugo sitemap to IndexNow API
 */

const fs = require("fs");
const path = require("path");
const fetch = require("node-fetch");
const xml2js = require("xml2js");

// Configuration
const CONFIG = {
  host: "pablobernabeu.github.io",
  apiKey: "ba7d2697a8f44966bd90543d188a8aac",
  keyLocation:
    "https://pablobernabeu.github.io/ba7d2697a8f44966bd90543d188a8aac.txt",
  sitemapPath: path.join(__dirname, "..", "public", "sitemap.xml"),
  apiEndpoint: "https://api.indexnow.org/indexnow",
  batchSize: 1000, // Maximum URLs per submission (Bing recommends ≤10,000)
  delayBetweenBatches: 2000, // 2 seconds between batches
};

/**
 * Extract URLs from Hugo sitemap.xml
 */
async function extractUrlsFromSitemap(sitemapPath) {
  try {
    const sitemapContent = fs.readFileSync(sitemapPath, "utf8");
    const parser = new xml2js.Parser();
    const result = await parser.parseStringPromise(sitemapContent);

    const urls = [];
    if (result.urlset && result.urlset.url) {
      for (const url of result.urlset.url) {
        if (url.loc && url.loc[0]) {
          urls.push(url.loc[0]);
        }
      }
    }

    return urls;
  } catch (error) {
    console.error("Error reading sitemap:", error.message);
    return [];
  }
}

/**
 * Submit URLs to IndexNow API
 */
async function submitToIndexNow(urls) {
  const payload = {
    host: CONFIG.host,
    key: CONFIG.apiKey,
    keyLocation: CONFIG.keyLocation,
    urlList: urls,
  };

  try {
    const response = await fetch(CONFIG.apiEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify(payload),
    });

    return {
      success: response.ok || response.status === 202,
      status: response.status,
      statusText: response.statusText,
    };
  } catch (error) {
    return {
      success: false,
      error: error.message,
    };
  }
}

/**
 * Split URLs into batches and submit
 */
async function submitInBatches(urls) {
  const batches = [];
  for (let i = 0; i < urls.length; i += CONFIG.batchSize) {
    batches.push(urls.slice(i, i + CONFIG.batchSize));
  }

  console.log(
    `📊 Submitting ${urls.length} URLs in ${batches.length} batch(es)`
  );

  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];
    console.log(
      `\n🚀 Submitting batch ${i + 1}/${batches.length} (${
        batch.length
      } URLs)...`
    );

    const result = await submitToIndexNow(batch);

    if (result.success) {
      console.log(
        `✅ Batch ${i + 1} submitted successfully (Status: ${result.status})`
      );
    } else {
      console.log(
        `❌ Batch ${i + 1} failed (Status: ${result.status || "Error"}): ${
          result.statusText || result.error
        }`
      );
    }

    // Rate limiting delay between batches
    if (i < batches.length - 1) {
      console.log(
        `⏳ Waiting ${CONFIG.delayBetweenBatches}ms before next batch...`
      );
      await new Promise((resolve) =>
        setTimeout(resolve, CONFIG.delayBetweenBatches)
      );
    }
  }
}

/**
 * Main execution
 */
async function main() {
  console.log("🔍 IndexNow Bulk Submission Script");
  console.log("=====================================");

  // Check if sitemap exists
  if (!fs.existsSync(CONFIG.sitemapPath)) {
    console.error(`❌ Sitemap not found at: ${CONFIG.sitemapPath}`);
    console.log("💡 Make sure to build your Hugo site first with: hugo");
    process.exit(1);
  }

  // Extract URLs from sitemap
  console.log(`📄 Reading sitemap from: ${CONFIG.sitemapPath}`);
  const urls = await extractUrlsFromSitemap(CONFIG.sitemapPath);

  if (urls.length === 0) {
    console.log("⚠️  No URLs found in sitemap");
    process.exit(0);
  }

  console.log(`📊 Found ${urls.length} URLs in sitemap`);

  // Filter to only include your domain
  const filteredUrls = urls.filter((url) => url.includes(CONFIG.host));
  console.log(`🎯 Filtered to ${filteredUrls.length} URLs from your domain`);

  if (filteredUrls.length === 0) {
    console.log("⚠️  No URLs found for your domain");
    process.exit(0);
  }

  // Submit URLs
  await submitInBatches(filteredUrls);

  console.log("\n🎉 Bulk submission completed!");
  console.log("\n📝 Next steps:");
  console.log("1. Check search console for indexing status");
  console.log("2. New pages will be automatically submitted via JavaScript");
  console.log("3. Use GitHub Actions for automatic submission on deployment");
}

// Run the script
main().catch((error) => {
  console.error("💥 Script failed:", error.message);
  process.exit(1);
});
