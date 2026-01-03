/**
 * Add ancillary/related tags to article pages based on tag connections
 * Uses same logic as tag-cloud-network.js without rebuilding pages
 */

(function() {
  'use strict';
  
  // Only run on article pages, not home page
  if (document.querySelector('#tags.home-section') || !document.querySelector('.article-tags')) {
    return;
  }
  
  // Add CSS to override existing article-tags styling - ALWAYS run this
  if (!document.getElementById('article-tags-custom-css')) {
    const style = document.createElement('style');
    style.id = 'article-tags-custom-css';
    style.textContent = `
      .article-tags,
      #top > article > div > div.article-tags,
      #top > div.pub > div > div.article-tags {
        text-align: center !important;
        line-height: 1.8 !important;
      }
      
      .article-tags a,
      .article-tags a:link,
      .article-tags a:visited,
      .article-tags a:hover,
      .article-tags .badge,
      #top > article > div > div.article-tags > a,
      #top > article > div > div.article-tags > a:link,
      #top > article > div > div.article-tags > a:visited,
      #top > article > div > div.article-tags > a:hover,
      #top > div.pub > div > div.article-tags > a,
      #top > div.pub > div > div.article-tags > a:link,
      #top > div.pub > div > div.article-tags > a:visited,
      #top > div.pub > div > div.article-tags > a:hover {
        display: inline !important;
        padding: 0 !important;
        margin: 0 0.3rem !important;
        margin-bottom: 0.3rem !important;
        background: transparent !important;
        background-color: transparent !important;
        border: none !important;
        border-radius: 0 !important;
        color: inherit !important;
        font-weight: 600 !important;
        font-size: 1rem !important;
        white-space: nowrap !important;
        position: relative !important;
        text-decoration: none !important;
        transition: none !important;
        transform: none !important;
        outline: none !important;
        box-shadow: none !important;
      }
      
      .article-tags-ancillary,
      #top > article > div > div.article-tags-ancillary,
      #top > div.pub > div > div.article-tags-ancillary {
        text-align: center !important;
        line-height: 1.8 !important;
      }
      
      .article-tags-ancillary a,
      .article-tags-ancillary a:link,
      .article-tags-ancillary a:visited,
      .article-tags-ancillary a:hover,
      #top > article > div > div.article-tags-ancillary > a,
      #top > article > div > div.article-tags-ancillary > a:link,
      #top > article > div > div.article-tags-ancillary > a:visited,
      #top > article > div > div.article-tags-ancillary > a:hover,
      #top > div.pub > div > div.article-tags-ancillary > a,
      #top > div.pub > div > div.article-tags-ancillary > a:link,
      #top > div.pub > div > div.article-tags-ancillary > a:visited,
      #top > div.pub > div > div.article-tags-ancillary > a:hover {
        display: inline !important;
        padding: 0 !important;
        margin: 0 0.25rem !important;
        margin-bottom: 0.25rem !important;
        background: transparent !important;
        background-color: transparent !important;
        border: none !important;
        border-radius: 0 !important;
        color: inherit !important;
        font-weight: 400 !important;
        font-size: 0.85rem !important;
        opacity: 0.6 !important;
        white-space: nowrap !important;
        position: relative !important;
        text-decoration: none !important;
        transition: none !important;
        transform: none !important;
        outline: none !important;
        box-shadow: none !important;
      }
    `;
    document.head.appendChild(style);
  }
  
  // Don't run if already processed
  if (document.querySelector('.article-tags-ancillary')) {
    console.log('Article ancillary tags: Already loaded, skipping');
    return;
  }
  
  // Get existing tags from current article
  const articleTagsContainer = document.querySelector('.article-tags');
  const existingTags = Array.from(articleTagsContainer.querySelectorAll('.badge')).map(badge => badge.textContent.trim());
  
  if (existingTags.length === 0) {
    return;
  }
  
  console.log('Article ancillary tags: Found existing tags:', existingTags);
  
  // Reuse categorization and similarity functions from tag-cloud-network.js
  function categorizeTag(tag) {
    const tagLower = tag.toLowerCase();
    
    const categoryPatterns = {
      syntax: /\b(syntax|grammar|morpholog|word order|sentence|clause|phrase)\b/i,
      semantics: /\b(semantic|meaning|conceptual|word recognition|lexic)\b/i,
      methods: /\b(statistics|statistical|regression|mixed|linear model|data|method|experiment|electroencephalography|erp|eeg|electrode|brain|neuroimaging)\b/i,
      cognition: /\b(cognit|attention|processing|memory|perception)\b/i,
      programming: /\b(r |r-stats|reproducib|code|dashboard|data vis|javascript|html|css|shiny|plotly|ggplot)\b/i,
      language: /\b(language|linguistic|bilingual|dutch|norwegian|spanish|english|psycholing)\b/i
    };
    
    for (const [category, pattern] of Object.entries(categoryPatterns)) {
      if (pattern.test(tagLower)) {
        return category;
      }
    }
    return 'other';
  }
  
  function getCategoryColor(category) {
    const colors = {
      syntax: '#3B82F6',      // Blue
      semantics: '#A855F7',   // Purple
      methods: '#10B981',     // Green
      cognition: '#F97316',   // Orange
      programming: '#EF4444', // Red
      language: '#06B6D4',    // Cyan
      other: '#6B7280'        // Gray
    };
    return colors[category] || colors.other;
  }
  
  function getSemanticSimilarity(tag1, tag2) {
    const t1 = tag1.toLowerCase();
    const t2 = tag2.toLowerCase();
    
    // Exact match
    if (t1 === t2) return 1.0;
    
    // Domain-specific co-occurrence patterns
    const domainPairs = {
      'word recognition': ['cognition', 'cognitive', 'experiment', 'processing', 'semantics', 'word'],
      'syntax': ['language', 'linguistic', 'psycholinguistics', 'processing', 'sentence', 'grammar'],
      'eeg': ['cognition', 'cognitive', 'experiment', 'methods', 'language', 'electroencephalography', 'erp'],
      'dutch': ['bilingual', 'psycholinguistics', 'word', 'reading', 'language', 'linguistic'],
      'english': ['linguistic', 'bilingual', 'psycholinguistics', 'language'],
      'spanish': ['linguistic', 'bilingual', 'psycholinguistics', 'language']
    };
    
    for (const [key, relatedTerms] of Object.entries(domainPairs)) {
      if (t1.includes(key) && relatedTerms.some(term => t2.includes(term))) return 0.8;
      if (t2.includes(key) && relatedTerms.some(term => t1.includes(term))) return 0.8;
    }
    
    // General semantic similarity
    const semanticPairs = [
      ['language', 'linguistic'],
      ['semantic', 'meaning'],
      ['cognition', 'cognitive'],
      ['statistics', 'statistical'],
      ['data', 'analysis'],
      ['experiment', 'experimental'],
      ['brain', 'neural'],
      ['reading', 'comprehension']
    ];
    
    for (const [term1, term2] of semanticPairs) {
      if ((t1.includes(term1) && t2.includes(term2)) || (t1.includes(term2) && t2.includes(term1))) {
        return 0.7;
      }
    }
    
    return 0;
  }
  
  // Calculate connection strength between two tags
  function getConnectionStrength(tag1, tag2) {
    const category1 = categorizeTag(tag1);
    const category2 = categorizeTag(tag2);
    const semantic = getSemanticSimilarity(tag1, tag2);
    
    let strength = 0;
    
    // Semantic similarity
    strength += semantic * 0.85;
    
    // Same category
    if (category1 === category2 && category1 !== 'other') {
      strength += 0.3;
    }
    
    // Related categories
    const relatedCategories = {
      syntax: ['semantics', 'language'],
      semantics: ['syntax', 'cognition', 'language'],
      methods: ['cognition'],
      cognition: ['semantics', 'methods'],
      programming: ['methods'],
      language: ['syntax', 'semantics']
    };
    
    if (relatedCategories[category1]?.includes(category2)) {
      strength += 0.15;
    }
    
    return Math.min(strength, 1);
  }
  
  // Find all related tags for existing article tags
  const relatedTagsMap = new Map();
  
  // Fetch tag co-occurrence data
  fetch('/index.json')
    .then(response => response.json())
    .then(data => {
      console.log('Article ancillary tags: Loaded index.json with', data.length, 'pages');
      
      // Build list of all available tags
      const allTagsSet = new Set();
      data.forEach(page => {
        (page.tags || []).forEach(tag => allTagsSet.add(tag));
      });
      const allTags = Array.from(allTagsSet);
      console.log('Article ancillary tags: Found', allTags.length, 'unique tags');
      
      // Build co-occurrence map
      const tagCooccurrence = new Map();
      
      data.forEach(page => {
        const pageTags = page.tags || [];
        for (let i = 0; i < pageTags.length; i++) {
          for (let j = i + 1; j < pageTags.length; j++) {
            const pair = [pageTags[i], pageTags[j]].sort().join('|||');
            tagCooccurrence.set(pair, (tagCooccurrence.get(pair) || 0) + 1);
          }
        }
      });
      
      // Find related tags for each existing tag
      existingTags.forEach(existingTag => {
        const related = [];
        
        allTags.forEach(candidateTag => {
          // Skip if it's already an existing tag
          if (existingTags.includes(candidateTag)) {
            return;
          }
          
          // Check co-occurrence
          const pair = [existingTag, candidateTag].sort().join('|||');
          const cooccurrenceCount = tagCooccurrence.get(pair) || 0;
          
          // Calculate strength
          let strength = 0;
          
          if (cooccurrenceCount > 0) {
            // Prioritize real co-occurrence data
            strength = cooccurrenceCount * 0.9;
          }
          
          // Add semantic/heuristic similarity
          strength += getConnectionStrength(existingTag, candidateTag) * 0.1;
          
          if (strength > 0.3) {
            related.push({ tag: candidateTag, strength });
          }
        });
        
        // Sort by strength
        related.sort((a, b) => b.strength - a.strength);
        relatedTagsMap.set(existingTag, related);
      });
      
      // Combine and deduplicate all related tags
      const allRelatedTags = new Set();
      relatedTagsMap.forEach(related => {
        related.forEach(r => allRelatedTags.add(r.tag));
      });
      
      // Style the container to match home page cloud
      articleTagsContainer.style.textAlign = 'center';
      articleTagsContainer.style.lineHeight = '1.8';
      articleTagsContainer.style.padding = '0.5rem';
      articleTagsContainer.style.margin = '0';
      
      // Enhance existing tags styling FIRST
      const existingBadges = articleTagsContainer.querySelectorAll('.badge');
      existingBadges.forEach(badge => {
        const tag = badge.textContent.trim();
        const category = categorizeTag(tag);
        const color = getCategoryColor(category);
        
        badge.setAttribute('data-tag-type', 'primary');
        badge.setAttribute('data-tag-name', tag);
        badge.setAttribute('data-category-color', color);
        
        // Add hover handlers for colored outline
        badge.addEventListener('mouseenter', function() {
          const tagColor = this.getAttribute('data-category-color');
          this.style.outline = `2px solid ${tagColor}`;
          this.style.outlineOffset = '2px';
          this.style.borderRadius = '0.3em';
        });
        
        badge.addEventListener('mouseleave', function() {
          this.style.outline = 'none';
          this.style.outlineOffset = '0';
          this.style.borderRadius = '0';
        });
      });
      
      // Sort primary tags alphabetically
      const primaryBadges = Array.from(articleTagsContainer.querySelectorAll('.badge'));
      primaryBadges.sort((a, b) => {
        const nameA = a.getAttribute('data-tag-name').toLowerCase();
        const nameB = b.getAttribute('data-tag-name').toLowerCase();
        return nameA.localeCompare(nameB);
      });
      articleTagsContainer.innerHTML = '';
      primaryBadges.forEach(badge => articleTagsContainer.appendChild(badge));
      
      // Add ancillary tags in separate container below
      if (allRelatedTags.size > 0) {
        console.log('Article ancillary tags: Adding', allRelatedTags.size, 'ancillary tags');
        
        // Create ancillary container
        const ancillaryContainer = document.createElement('div');
        ancillaryContainer.className = 'article-tags-ancillary';
        ancillaryContainer.style.textAlign = 'center';
        ancillaryContainer.style.lineHeight = '1.8';
        ancillaryContainer.style.padding = '0.5rem';
        ancillaryContainer.style.paddingTop = '0.75rem';
        ancillaryContainer.style.marginTop = '0.5rem';
        ancillaryContainer.style.borderTop = '1px solid rgba(0,0,0,0.15)';
        
        const ancillaryTags = [];
        
        Array.from(allRelatedTags).forEach(tag => {
          const category = categorizeTag(tag);
          const color = getCategoryColor(category);
          
          const badge = document.createElement('a');
          badge.className = 'badge badge-light ancillary-tag';
          badge.href = `/tags/${tag.toLowerCase().replace(/\s+/g, '-')}/`;
          badge.textContent = tag;
          badge.setAttribute('data-tag-type', 'ancillary');
          badge.setAttribute('data-tag-name', tag);
          badge.setAttribute('data-category-color', color);
          
          // Add hover handlers for colored outline
          badge.addEventListener('mouseenter', function() {
            const tagColor = this.getAttribute('data-category-color');
            this.style.opacity = '0.85';
            this.style.outline = `1px dashed ${tagColor}`;
            this.style.outlineOffset = '2px';
            this.style.borderRadius = '0.3em';
          });
          
          badge.addEventListener('mouseleave', function() {
            this.style.opacity = '0.6';
            this.style.outline = 'none';
            this.style.outlineOffset = '0';
            this.style.borderRadius = '0';
          });
          
          ancillaryTags.push(badge);
        });
        
        // Sort ancillary tags alphabetically
        ancillaryTags.sort((a, b) => {
          const nameA = a.getAttribute('data-tag-name').toLowerCase();
          const nameB = b.getAttribute('data-tag-name').toLowerCase();
          return nameA.localeCompare(nameB);
        });
        
        // Append sorted ancillary tags to their container
        ancillaryTags.forEach(badge => ancillaryContainer.appendChild(badge));
        
        // Insert ancillary container after primary tags
        articleTagsContainer.parentNode.insertBefore(ancillaryContainer, articleTagsContainer.nextSibling);
      }
    })
    .catch(error => {
      console.error('Error loading tag co-occurrence data:', error);
    });
})();
