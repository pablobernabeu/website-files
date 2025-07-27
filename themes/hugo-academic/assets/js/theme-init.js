// Immediate theme application to prevent flash
(function () {
  "use strict";

  // Get saved theme preference or default to auto
  function getThemeMode() {
    return parseInt(localStorage.getItem("dark_mode") || 2);
  }

  function shouldUseDarkTheme() {
    let currentThemeMode = getThemeMode();
    switch (currentThemeMode) {
      case 0:
        return false; // Light mode
      case 1:
        return true; // Dark mode
      default:
        // Auto mode - only apply if user has explicitly interacted with theme before
        // Otherwise, let the site load with default light theme
        if (localStorage.getItem("dark_mode") === null) {
          return false; // No preference saved, use light theme by default
        }
        return window.matchMedia("(prefers-color-scheme: dark)").matches;
    }
  }

  // Apply theme immediately before page renders, but don't interfere with body class
  if (shouldUseDarkTheme()) {
    document.documentElement.classList.add("dark-theme-loading");

    // Set initial dark background to prevent flash, but don't add dark class to body yet
    // The main academic.js will handle the body dark class properly
    document.documentElement.style.backgroundColor = "#0f172a";
    document.documentElement.style.color = "#e2e8f0";
  }

  // Clean up loading class and let academic.js handle proper theme initialization
  document.addEventListener("DOMContentLoaded", function () {
    document.documentElement.classList.remove("dark-theme-loading");
    document.documentElement.style.backgroundColor = "";
    document.documentElement.style.color = "";
  });
})();
