/*************************************************
 *  Navbar Dropdown Menus
 *  Shared functionality for navbar dropdown menus
 *  (font-size toggle and theme switcher)
 **************************************************/

(function() {
  'use strict';

  // Adjust dropdown position to prevent viewport overflow
  function adjustDropdownPosition(menu) {
    if (!menu) return;
    
    // In mobile view, just ensure transform is set for centering, then exit
    if (window.innerWidth <= 991) {
      menu.style.transform = 'translateX(-50%)';
      return;
    }
    
    // Use requestAnimationFrame for accurate measurements
    requestAnimationFrame(() => {
      // Reset to default position (centered for desktop)
      menu.style.transform = 'translateX(-50%)';
      
      // Get measurements after reset
      requestAnimationFrame(() => {
        const rect = menu.getBoundingClientRect();
        const viewportWidth = window.innerWidth;
        const padding = 30; // Increased padding for safety
        
        let translateX = -50;
        
        // Calculate overflow on right side
        const rightEdge = rect.right;
        const maxRight = viewportWidth - padding;
        
        if (rightEdge > maxRight) {
          // Shift left to fit
          const pixelsOver = rightEdge - maxRight;
          const percentShift = (pixelsOver / menu.offsetWidth) * 100;
          translateX = -50 - percentShift;
        }
        
        menu.style.transform = `translateX(${translateX}%)`;
      });
    });
  }

  // Initialize dropdown hover behavior
  function initDropdownHover() {
    const fontSizeDropdown = document.querySelector('.nav-item.dropdown:has(.font-size-menu)');
    const themeDropdown = document.querySelector('.nav-item.dropdown:has(.theme-menu)');
    
    // Prevent default behavior on navbar icon clicks
    document.querySelectorAll('.js-font-size-toggle, .js-theme-toggle').forEach(icon => {
      icon.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        return false;
      });
    });
    
    function closeAllDropdowns() {
      document.querySelectorAll('.font-size-menu, .theme-menu').forEach(menu => {
        menu.classList.remove('show');
      });
    }
    
    function setupDropdownHover(dropdown, menuClass) {
      if (!dropdown) return;
      
      const menu = dropdown.querySelector(menuClass);
      if (!menu) return;
      
      let hoverTimer;
      
      // Mouse enter on dropdown item
      dropdown.addEventListener('mouseenter', function() {
        clearTimeout(hoverTimer);
        
        // Close other dropdown immediately
        const otherMenu = menuClass === '.font-size-menu' 
          ? document.querySelector('.theme-menu')
          : document.querySelector('.font-size-menu');
        
        if (otherMenu && otherMenu.classList.contains('show')) {
          otherMenu.classList.remove('show');
        }
        
        // Show this dropdown immediately to allow hover to work
        menu.classList.add('show');
        adjustDropdownPosition(menu);
      });
      
      // Mouse leave from dropdown
      dropdown.addEventListener('mouseleave', function(e) {
        // Check if mouse is moving to the menu
        const relatedTarget = e.relatedTarget;
        if (relatedTarget && menu.contains(relatedTarget)) {
          return; // Don't close if moving into menu
        }
        hoverTimer = setTimeout(() => {
          menu.classList.remove('show');
        }, 500);
      });
      
      // Mouse enter menu - keep it open
      menu.addEventListener('mouseenter', function() {
        clearTimeout(hoverTimer);
        menu.classList.add('show');
      });
      
      // Mouse leave menu - close it
      menu.addEventListener('mouseleave', function() {
        hoverTimer = setTimeout(() => {
          menu.classList.remove('show');
        }, 300);
      });
    }
    
    setupDropdownHover(fontSizeDropdown, '.font-size-menu');
    setupDropdownHover(themeDropdown, '.theme-menu');
    
    // Close dropdowns on scroll in mobile view (check width on each scroll)
    window.addEventListener('scroll', function() {
      if (window.innerWidth <= 991) {
        closeAllDropdowns();
      }
    }, { passive: true });
    
    // Close dropdowns when clicking outside
    document.addEventListener('click', function(e) {
      if (!e.target.closest('.nav-item.dropdown')) {
        closeAllDropdowns();
      }
    });
  }

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initDropdownHover);
  } else {
    initDropdownHover();
  }
})();
