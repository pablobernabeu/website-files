#!/usr/bin/env python3

"""
IndexNow Bulk Submission Script (Python)
Submits all URLs from Hugo sitemap to IndexNow API
"""

import json
import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET
import time
import os
import sys

# Configuration
CONFIG = {
    'host': 'pablobernabeu.github.io',
    'api_key': 'ba7d2697a8f44966bd90543d188a8aac',
    'key_location': 'https://pablobernabeu.github.io/ba7d2697a8f44966bd90543d188a8aac.txt',
    'sitemap_path': 'public/sitemap.xml',
    'api_endpoint': 'https://api.indexnow.org/indexnow',
    'batch_size': 50,  # Smaller batches to avoid 403 errors
    'delay_between_batches': 3  # Longer delay between batches
}

def extract_urls_from_sitemap(sitemap_path):
    """Extract URLs from Hugo sitemap.xml"""
    try:
        tree = ET.parse(sitemap_path)
        root = tree.getroot()
        
        urls = []
        # Handle namespace
        namespace = {'ns': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
        
        for url in root.findall('ns:url', namespace):
            loc = url.find('ns:loc', namespace)
            if loc is not None:
                urls.append(loc.text)
        
        # If no namespace, try without
        if not urls:
            for url in root.findall('url'):
                loc = url.find('loc')
                if loc is not None:
                    urls.append(loc.text)
        
        return urls
    except Exception as e:
        print(f"Error reading sitemap: {e}")
        return []

def submit_to_indexnow(urls):
    """Submit URLs to IndexNow API"""
    payload = {
        'host': CONFIG['host'],
        'key': CONFIG['api_key'],
        'keyLocation': CONFIG['key_location'],
        'urlList': urls
    }
    
    try:
        data = json.dumps(payload).encode('utf-8')
        
        req = urllib.request.Request(
            CONFIG['api_endpoint'],
            data=data,
            headers={
                'Content-Type': 'application/json; charset=utf-8',
                'User-Agent': 'Hugo-IndexNow-Submitter/1.0'
            },
            method='POST'
        )
        
        with urllib.request.urlopen(req) as response:
            return {
                'success': True,
                'status': response.getcode(),
                'response': response.read().decode('utf-8')
            }
    except urllib.error.HTTPError as e:
        return {
            'success': e.code in [200, 202],
            'status': e.code,
            'error': str(e)
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

def submit_in_batches(urls):
    """Split URLs into batches and submit"""
    batches = [urls[i:i + CONFIG['batch_size']] for i in range(0, len(urls), CONFIG['batch_size'])]
    
    print(f"📊 Submitting {len(urls)} URLs in {len(batches)} batch(es)")
    
    for i, batch in enumerate(batches, 1):
        print(f"\n🚀 Submitting batch {i}/{len(batches)} ({len(batch)} URLs)...")
        
        result = submit_to_indexnow(batch)
        
        if result['success']:
            print(f"✅ Batch {i} submitted successfully (Status: {result['status']})")
        else:
            print(f"❌ Batch {i} failed (Status: {result.get('status', 'Error')}): {result.get('error', 'Unknown error')}")
        
        # Rate limiting delay
        if i < len(batches):
            print(f"⏳ Waiting {CONFIG['delay_between_batches']}s before next batch...")
            time.sleep(CONFIG['delay_between_batches'])

def main():
    print('🔍 IndexNow Bulk Submission Script (Python)')
    print('==========================================')
    
    # Check if sitemap exists
    if not os.path.exists(CONFIG['sitemap_path']):
        print(f"❌ Sitemap not found at: {CONFIG['sitemap_path']}")
        print('💡 Make sure to build your Hugo site first with: hugo')
        sys.exit(1)
    
    # Extract URLs from sitemap
    print(f"📄 Reading sitemap from: {CONFIG['sitemap_path']}")
    urls = extract_urls_from_sitemap(CONFIG['sitemap_path'])
    
    if not urls:
        print('⚠️  No URLs found in sitemap')
        sys.exit(0)
    
    print(f"📊 Found {len(urls)} URLs in sitemap")
    
    # Filter to only include your domain
    filtered_urls = [url for url in urls if CONFIG['host'] in url]
    print(f"🎯 Filtered to {len(filtered_urls)} URLs from your domain")
    
    if not filtered_urls:
        print('⚠️  No URLs found for your domain')
        sys.exit(0)
    
    # Submit URLs
    submit_in_batches(filtered_urls)
    
    print('\n🎉 Bulk submission completed!')
    print('\n📝 Next steps:')
    print('1. Check search console for indexing status')
    print('2. New pages will be automatically submitted via JavaScript')
    print('3. Use GitHub Actions for automatic submission on deployment')

if __name__ == '__main__':
    main()
