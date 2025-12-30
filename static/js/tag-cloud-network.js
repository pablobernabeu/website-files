// Tag cloud network visualization - shows co-occurrence relationships
(function() {
  'use strict';

  const THRESHOLD = 0.40; // Sensible default: shows meaningful connections without clutter
  let tags = [];
  let cooccurrences = [];
  let svg = null;

  function initTagNetwork() {
    const tagCloud = document.querySelector('#tags .tag-cloud');
    if (!tagCloud) return;

    // Parse tag data from links
    tags = Array.from(tagCloud.querySelectorAll('a')).map(link => ({
      element: link,
      name: link.getAttribute('data-tag'),
      count: parseInt(link.getAttribute('data-count')),
      url: link.href,
      category: categorizeTag(link.getAttribute('data-tag'))
    }));

    // Calculate centrality metrics
    calculateCentrality(tags);

    // Fetch co-occurrence data
    cooccurrences = calculateCooccurrences(tags);

    // Create SVG canvas for connection lines
    svg = createSVGCanvas(tagCloud);

    // Draw connections with temporal animation
    drawConnectionsAnimated(svg, cooccurrences, tags);

    // Redraw on window resize
    let resizeTimeout;
    window.addEventListener('resize', () => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(() => {
        svg.innerHTML = '';
        drawConnectionsAnimated(svg, cooccurrences, tags);
      }, 150);
    });
  }

  function categorizeTag(tagName) {
    const categories = {
      syntax: /syntax|grammar|morphology|parsing|tree|clause|sentence|word order/i,
      semantics: /semantic|meaning|pragmatic|lexicon|lexical|conceptual|metaphor/i,
      methods: /statistic|analysis|method|experiment|study|data|research|model|regression|mixed.effect/i,
      cognition: /cognit|perception|memory|brain|neuroscience|psychological|mental/i,
      programming: /\bR\b|python|programming|code|software|package|function|script|github/i,
      language: /language|linguistic|speech|text|corpus|translation/i
    };

    const lowerTag = tagName.toLowerCase();
    for (const [category, pattern] of Object.entries(categories)) {
      if (pattern.test(tagName)) {
        return category;
      }
    }
    return 'other';
  }

  function getCategoryColor(category) {
    const colors = {
      syntax: '#3b82f6',      // Blue
      semantics: '#8b5cf6',   // Purple
      methods: '#10b981',     // Green
      cognition: '#f59e0b',   // Orange
      programming: '#ef4444', // Red
      language: '#06b6d4',    // Cyan
      other: '#6b7280'        // Gray
    };
    return colors[category] || colors.other;
  }

  function calculateCentrality(tags) {
    // Calculate degree centrality (will be updated with actual connections)
    tags.forEach(tag => {
      tag.centrality = 0;
    });
  }

  function calculateCooccurrences(tags) {
    const cooccurrences = [];

    for (let i = 0; i < tags.length; i++) {
      for (let j = i + 1; j < tags.length; j++) {
        const tag1 = tags[i];
        const tag2 = tags[j];
        
        // Multiple factors contribute to relationship strength:
        
        // 1. Frequency similarity (tags with similar counts likely appear together)
        const maxCount = Math.max(tag1.count, tag2.count);
        const minCount = Math.min(tag1.count, tag2.count);
        const frequencyRatio = minCount / maxCount;
        
        // 2. Absolute frequency (popular tags are more likely to co-occur)
        const popularityFactor = Math.min((minCount / 10), 1); // Cap at 10 posts
        
        // 3. Category affinity (same category = likely related)
        const sameCategoryBonus = tag1.category === tag2.category ? 0.25 : 0;
        const relatedCategoryBonus = areRelatedCategories(tag1.category, tag2.category) ? 0.12 : 0;
        
        // 4. Semantic similarity based on tag names
        const semanticSimilarity = calculateSemanticSimilarity(tag1.name, tag2.name);
        
        // Combined strength with weighted factors
        const strength = (
          frequencyRatio * 0.35 +          // Frequency similarity
          popularityFactor * 0.20 +         // Absolute popularity
          sameCategoryBonus +               // Same category
          relatedCategoryBonus +            // Related category
          semanticSimilarity * 0.25         // Semantic similarity
        );

        // Only include if above threshold
        if (strength >= THRESHOLD) {
          cooccurrences.push({
            source: tag1,
            target: tag2,
            strength: Math.min(strength, 1.0), // Cap at 1.0
            factors: {
              frequency: frequencyRatio,
              popularity: popularityFactor,
              category: sameCategoryBonus + relatedCategoryBonus,
              semantic: semanticSimilarity
            }
          });
        }
      }
    }

    // Update centrality based on actual connections
    tags.forEach(tag => tag.centrality = 0);
    cooccurrences.forEach(conn => {
      conn.source.centrality++;
      conn.target.centrality++;
    });

    // Normalize centrality
    const maxCentrality = Math.max(...tags.map(t => t.centrality), 1);
    tags.forEach(tag => {
      tag.centralityNorm = tag.centrality / maxCentrality;
      // Highlight hub tags (top 20% by connections)
      if (tag.centrality > 0 && tag.centralityNorm > 0.6) {
        tag.element.style.textDecoration = 'underline';
        tag.element.style.textDecorationStyle = 'dotted';
        tag.element.setAttribute('title', `Hub tag: ${tag.centrality} connections`);
      } else {
        tag.element.style.textDecoration = '';
        tag.element.removeAttribute('title');
      }
    });

    // Sort by strength and limit to prevent clutter
    return cooccurrences
      .sort((a, b) => b.strength - a.strength)
      .slice(0, Math.min(25, tags.length * 2));
  }

  function areRelatedCategories(cat1, cat2) {
    const related = {
      'syntax': ['semantics', 'language'],
      'semantics': ['syntax', 'language', 'cognition'],
      'methods': ['programming'],
      'cognition': ['semantics', 'language'],
      'programming': ['methods'],
      'language': ['syntax', 'semantics', 'cognition']
    };
    return related[cat1]?.includes(cat2) || related[cat2]?.includes(cat1);
  }

  function calculateSemanticSimilarity(name1, name2) {
    const words1 = name1.toLowerCase().split(/[-\s]+/);
    const words2 = name2.toLowerCase().split(/[-\s]+/);
    
    // Check for shared words
    const sharedWords = words1.filter(w => words2.includes(w));
    if (sharedWords.length > 0) {
      return 0.3 + (sharedWords.length * 0.2);
    }
    
    // Check for substring matches (e.g., "language" and "linguistic")
    for (const w1 of words1) {
      for (const w2 of words2) {
        if (w1.length > 3 && w2.length > 3) {
          if (w1.includes(w2) || w2.includes(w1)) {
            return 0.25;
          }
          // Check if they share a significant prefix (at least 4 chars)
          const minLen = Math.min(w1.length, w2.length);
          if (minLen >= 4) {
            const prefix = Math.min(4, minLen);
            if (w1.substring(0, prefix) === w2.substring(0, prefix)) {
              return 0.15;
            }
          }
        }
      }
    }
    
    return 0;
  }



  function createSVGCanvas(container) {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.style.position = 'absolute';
    svg.style.top = '0';
    svg.style.left = '0';
    svg.style.width = '100%';
    svg.style.height = '100%';
    svg.style.pointerEvents = 'auto'; // Allow interaction with lines
    svg.style.zIndex = '0';
    
    // Insert SVG before tag links
    container.style.position = 'relative';
    container.insertBefore(svg, container.firstChild);
    
    return svg;
  }

  function drawConnectionsAnimated(svg, cooccurrences, tags) {
    const rect = svg.parentElement.getBoundingClientRect();
    svg.setAttribute('viewBox', `0 0 ${rect.width} ${rect.height}`);

    cooccurrences.forEach((conn, index) => {
      setTimeout(() => {
        drawConnection(svg, conn, rect.width, rect.height);
      }, index * 100); // Stagger animation
    });

    // Bring tag links to front
    tags.forEach(tag => {
      tag.element.style.position = 'relative';
      tag.element.style.zIndex = '1';
    });
  }

  function drawConnection(svg, conn, width, height) {
    const sourceRect = conn.source.element.getBoundingClientRect();
    const targetRect = conn.target.element.getBoundingClientRect();
    const containerRect = svg.parentElement.getBoundingClientRect();

    // Calculate center points
    const x1 = sourceRect.left + sourceRect.width / 2 - containerRect.left;
    const y1 = sourceRect.top + sourceRect.height / 2 - containerRect.top;
    const x2 = targetRect.left + targetRect.width / 2 - containerRect.left;
    const y2 = targetRect.top + targetRect.height / 2 - containerRect.top;

    // Calculate control point for curved line
    const dx = x2 - x1;
    const dy = y2 - y1;
    const distance = Math.sqrt(dx * dx + dy * dy);
    const curvature = Math.min(distance * 0.2, 50);
    const angle = Math.atan2(dy, dx);
    const controlX = (x1 + x2) / 2 + Math.cos(angle + Math.PI / 2) * curvature;
    const controlY = (y1 + y2) / 2 + Math.sin(angle + Math.PI / 2) * curvature;

    // Create curved path
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    const pathData = `M ${x1} ${y1} Q ${controlX} ${controlY} ${x2} ${y2}`;
    path.setAttribute('d', pathData);
    path.setAttribute('fill', 'none');
    
    const opacity = conn.strength * 0.2;
    const strokeWidth = conn.strength * 1.5;
    const color = getCategoryColor(conn.source.category);
    
    path.setAttribute('stroke', color);
    path.setAttribute('stroke-width', strokeWidth);
    path.setAttribute('stroke-opacity', 0);
    path.setAttribute('stroke-linecap', 'round');
    path.style.transition = 'all 0.3s ease';
    
    // Invisible wider path for hovering
    const hitPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    hitPath.setAttribute('d', pathData);
    hitPath.setAttribute('fill', 'none');
    hitPath.setAttribute('stroke', 'transparent');
    hitPath.setAttribute('stroke-width', Math.max(strokeWidth * 4, 12));
    hitPath.style.cursor = 'pointer';

    // Add to SVG
    const group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    group.appendChild(path);
    group.appendChild(hitPath);

    // Add edge label
    const label = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    label.setAttribute('x', controlX);
    label.setAttribute('y', controlY);
    label.setAttribute('text-anchor', 'middle');
    label.setAttribute('fill', color);
    label.setAttribute('font-size', '10');
    label.setAttribute('opacity', '0');
    label.textContent = conn.strength.toFixed(2);
    label.style.pointerEvents = 'none';
    group.appendChild(label);

    // Create particle for animation
    const particle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    particle.setAttribute('r', '2');
    particle.setAttribute('fill', color);
    particle.setAttribute('opacity', '0');
    group.appendChild(particle);

    svg.appendChild(group);

    // Fade in animation
    setTimeout(() => {
      path.setAttribute('stroke-opacity', opacity);
    }, 50);

    // Tooltip
    const tooltip = createTooltip(conn);

    // Interaction handlers - only on the line itself, not on tags
    const highlightConnection = (highlight) => {
      if (highlight) {
        path.setAttribute('stroke-opacity', Math.min(opacity * 2.5, 0.6));
        path.setAttribute('stroke-width', strokeWidth * 1.8);
        label.setAttribute('opacity', '0.8');
        conn.source.element.style.fontWeight = '700';
        conn.target.element.style.fontWeight = '700';
        tooltip.style.display = 'block';
        animateParticle(particle, pathData);
      } else {
        path.setAttribute('stroke-opacity', opacity);
        path.setAttribute('stroke-width', strokeWidth);
        label.setAttribute('opacity', '0');
        conn.source.element.style.fontWeight = '';
        conn.target.element.style.fontWeight = '';
        tooltip.style.display = 'none';
        particle.setAttribute('opacity', '0');
      }
    };

    // Only attach hover handlers to the connection line
    let isHovering = false;
    
    hitPath.addEventListener('mouseenter', (e) => {
      isHovering = true;
      highlightConnection(true);
      positionTooltip(tooltip, e);
    });
    
    hitPath.addEventListener('mouseleave', () => {
      isHovering = false;
      // Small delay to prevent flickering
      setTimeout(() => {
        if (!isHovering) {
          highlightConnection(false);
        }
      }, 50);
    });
    
    // Don't reposition tooltip during hover to prevent jittering
    
    // Click line to navigate between tags
    hitPath.addEventListener('click', (e) => {
      e.preventDefault();
      conn.source.element.scrollIntoView({ behavior: 'smooth', block: 'center' });
      setTimeout(() => {
        conn.target.element.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }, 800);
    });
  }

  function animateParticle(particle, pathData) {
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', pathData);
    
    let progress = 0;
    particle.setAttribute('opacity', '0.8');
    
    const animate = () => {
      if (progress > 1) return;
      
      const point = path.getPointAtLength(progress * path.getTotalLength());
      particle.setAttribute('cx', point.x);
      particle.setAttribute('cy', point.y);
      
      progress += 0.02;
      requestAnimationFrame(animate);
    };
    
    animate();
  }

  function createTooltip(conn) {
    const tooltip = document.createElement('div');
    tooltip.style.cssText = `
      position: fixed;
      background: rgba(0, 0, 0, 0.92);
      color: white;
      padding: 0.6rem 0.85rem;
      border-radius: 0.3rem;
      font-size: 0.75rem;
      pointer-events: none;
      z-index: 1000;
      display: none;
      max-width: 300px;
      line-height: 1.5;
      border: 1px solid rgba(255, 255, 255, 0.1);
    `;
    
    const factorDetails = `
      <div style="margin-top: 0.5rem; padding-top: 0.5rem; border-top: 1px solid rgba(255,255,255,0.2); font-size: 0.7rem; opacity: 0.85;">
        <div style="margin-bottom: 0.2rem;">Frequency similarity: ${(conn.factors.frequency * 100).toFixed(0)}%</div>
        <div style="margin-bottom: 0.2rem;">Absolute popularity: ${(conn.factors.popularity * 100).toFixed(0)}%</div>
        <div style="margin-bottom: 0.2rem;">Category affinity: ${(conn.factors.category * 100).toFixed(0)}%</div>
        <div>Semantic similarity: ${(conn.factors.semantic * 100).toFixed(0)}%</div>
      </div>
    `;
    
    tooltip.innerHTML = `
      <div style="margin-bottom: 0.4rem;">
        <strong>${conn.source.name}</strong> · <strong>${conn.target.name}</strong>
      </div>
      <div style="margin-bottom: 0.3rem; opacity: 0.9;">
        Connection strength: <strong>${(conn.strength * 100).toFixed(1)}%</strong>
      </div>
      <div style="font-size: 0.7rem; opacity: 0.75;">
        ${conn.source.count} posts · ${conn.target.count} posts
      </div>
      ${factorDetails}
    `;
    document.body.appendChild(tooltip);
    return tooltip;
  }

  function positionTooltip(tooltip, event) {
    const offset = 25; // Larger offset to prevent tooltip from blocking hover area
    const tooltipRect = tooltip.getBoundingClientRect();
    
    // Position to the right and below cursor by default
    let left = event.clientX + offset;
    let top = event.clientY + offset;
    
    // Adjust if tooltip would go off screen
    if (left + tooltipRect.width > window.innerWidth - 10) {
      left = event.clientX - tooltipRect.width - offset;
    }
    if (top + tooltipRect.height > window.innerHeight - 10) {
      top = event.clientY - tooltipRect.height - offset;
    }
    
    // Ensure tooltip doesn't go off left or top edge
    left = Math.max(10, left);
    top = Math.max(10, top);
    
    tooltip.style.left = left + 'px';
    tooltip.style.top = top + 'px';
  }

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initTagNetwork);
  } else {
    initTagNetwork();
  }
})();
