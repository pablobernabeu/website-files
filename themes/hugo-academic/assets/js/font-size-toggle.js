/*************************************************
 *  Font Size Toggle
 *  Allows users to adjust base font size
 **************************************************/

(function() {
  'use strict';

  // Font size levels (in pixels for the base html font-size)
  const FONT_SIZES = [12, 13, 14, 15, 16, 17, 18, 19, 20];
  const DEFAULT_INDEX = 4; // 16px
  const STORAGE_KEY = 'fontSizeIndex';

  // Get current font size index from localStorage or use default
  function getCurrentIndex() {
    const stored = localStorage.getItem(STORAGE_KEY);
    return stored !== null ? parseInt(stored, 10) : DEFAULT_INDEX;
  }

  // Save font size index to localStorage
  function saveIndex(index) {
    localStorage.setItem(STORAGE_KEY, index);
  }

  // Apply font size to html element using data attribute
  function applyFontSize(index) {
    document.documentElement.setAttribute('data-font-size', index);
    console.log('Font size set to:', FONT_SIZES[index] + 'px');
  }

  // Increase font size
  function increaseFontSize() {
    let currentIndex = getCurrentIndex();
    if (currentIndex < FONT_SIZES.length - 1) {
      currentIndex++;
      saveIndex(currentIndex);
      applyFontSize(currentIndex);
    }
  }

  // Decrease font size
  function decreaseFontSize() {
    let currentIndex = getCurrentIndex();
    if (currentIndex > 0) {
      currentIndex--;
      saveIndex(currentIndex);
      applyFontSize(currentIndex);
    }
  }

  // Reset to default font size
  function resetFontSize() {
    saveIndex(DEFAULT_INDEX);
    applyFontSize(DEFAULT_INDEX);
  }

  // Initialize on page load
  function initFontSize() {
    const currentIndex = getCurrentIndex();
    applyFontSize(currentIndex);

    // Add event listeners for font size controls
    document.addEventListener('click', function(e) {
      // Prevent default for all font size controls
      if (e.target.closest('.js-font-increase, .js-font-decrease, .js-font-reset')) {
        e.preventDefault();
        e.stopPropagation();
      }

      // Increase font size
      if (e.target.closest('.js-font-increase')) {
        increaseFontSize();
      }

      // Decrease font size
      if (e.target.closest('.js-font-decrease')) {
        decreaseFontSize();
      }

      // Reset font size
      if (e.target.closest('.js-font-reset')) {
        resetFontSize();
      }
    });
  }

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initFontSize);
  } else {
    initFontSize();
  }
})();
