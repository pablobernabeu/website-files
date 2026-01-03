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
  
  // Don't run if already processed
  if (document.querySelector('.article-tags-ancillary')) {
    console.log('Article ancillary tags: Already loaded, skipping');
    return;
  }
  
  // Get existing tags from current article
  const articleTagsContainer = document.querySelector('.article-tags');
  const existingTags = Array.from(articleTagsContainer.querySelectorAll('.badge'))
    .map(badge => badge.textContent.trim())
    .filter(tag => tag !== 's'); // Hide 's' tag
  
  // Hide 's' tag badges from display
  articleTagsContainer.querySelectorAll('.badge').forEach(badge => {
    if (badge.textContent.trim() === 's') {
      badge.style.display = 'none';
    }
  });
  
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
          // Skip if it's already an existing tag or is 's'
          if (existingTags.includes(candidateTag) || candidateTag === 's') {
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
      
      // Combine and deduplicate all related tags, keeping track of max strength
      const allRelatedTagsWithStrength = new Map();
      relatedTagsMap.forEach(related => {
        related.forEach(r => {
          const currentStrength = allRelatedTagsWithStrength.get(r.tag) || 0;
          if (r.strength > currentStrength) {
            allRelatedTagsWithStrength.set(r.tag, r.strength);
          }
        });
      });
      
      // Convert to array and sort by strength, then limit to ~15 tags (approx 3 lines)
      const sortedRelatedTags = Array.from(allRelatedTagsWithStrength.entries())
        .sort((a, b) => b[1] - a[1])
        .slice(0, 15)
        .map(entry => entry[0]);
      
      const allRelatedTags = new Set(sortedRelatedTags);
      
      // Enhance existing tags with data attributes and colored hover
      const existingBadges = articleTagsContainer.querySelectorAll('.badge');
      existingBadges.forEach(badge => {
        const tag = badge.textContent.trim();
        const category = categorizeTag(tag);
        const color = getCategoryColor(category);
        
        badge.setAttribute('data-tag-type', 'primary');
        badge.setAttribute('data-tag-name', tag);
        badge.setAttribute('data-category-color', color);
        
        // Add hover handlers for colored outline (overrides SCSS default)
        badge.addEventListener('mouseenter', function() {
          const tagColor = this.getAttribute('data-category-color');
          this.style.outline = `2px solid ${tagColor}`;
          this.style.outlineOffset = '2px';
          this.style.borderRadius = '0.3em';
        });
        
        badge.addEventListener('mouseleave', function() {
          this.style.outline = '';
          this.style.outlineOffset = '';
          this.style.borderRadius = '';
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
      
      // Add separator bar above heading
      const separator = document.createElement('div');
      separator.style.borderTop = '1px solid rgba(0,0,0,0.12)';
      separator.style.marginBottom = '0.75rem';
      separator.style.paddingTop = '0';
      articleTagsContainer.appendChild(separator);
      
      // Add heading for main tags
      const mainHeading = document.createElement('h4');
      mainHeading.textContent = 'Topics';
      mainHeading.style.textAlign = 'center';
      mainHeading.style.marginBottom = '0.5rem';
      mainHeading.style.opacity = '0.5';
      mainHeading.style.fontSize = '0.85rem';
      mainHeading.style.fontWeight = '400';
      mainHeading.style.textTransform = 'uppercase';
      mainHeading.style.letterSpacing = '0.05em';
      articleTagsContainer.appendChild(mainHeading);
      
      primaryBadges.forEach(badge => articleTagsContainer.appendChild(badge));
      
      // Add ancillary tags in separate container below
      if (allRelatedTags.size > 0) {
        console.log('Article ancillary tags: Adding', allRelatedTags.size, 'ancillary tags');
        
        // Create ancillary container
        const ancillaryContainer = document.createElement('div');
        ancillaryContainer.className = 'article-tags-ancillary';
        
        // Add heading for ancillary tags
        const ancillaryHeading = document.createElement('h4');
        ancillaryHeading.textContent = 'Related Topics';
        ancillaryHeading.style.textAlign = 'center';
        ancillaryHeading.style.marginBottom = '0.5rem';
        ancillaryHeading.style.opacity = '0.4';
        ancillaryHeading.style.fontSize = '0.8rem';
        ancillaryHeading.style.fontWeight = '400';
        ancillaryHeading.style.textTransform = 'uppercase';
        ancillaryHeading.style.letterSpacing = '0.05em';
        ancillaryContainer.appendChild(ancillaryHeading);
        
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
          
          // Add hover handlers for colored outline (overrides SCSS default)
          badge.addEventListener('mouseenter', function() {
            const tagColor = this.getAttribute('data-category-color');
            this.style.opacity = '0.85';
            this.style.outline = `1px dashed ${tagColor}`;
            this.style.outlineOffset = '2px';
            this.style.borderRadius = '0.3em';
          });
          
          badge.addEventListener('mouseleave', function() {
            this.style.opacity = '';
            this.style.outline = '';
            this.style.outlineOffset = '';
            this.style.borderRadius = '';
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
