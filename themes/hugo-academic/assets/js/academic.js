/*************************************************
 *  Academic
 *  https://github.com/gcushen/hugo-academic
 *
 *  Core JS functions and initialization.
 **************************************************/

(function ($) {
  // GLOBAL RELOAD PREVENTION SYSTEM
  let themeChangeInProgress = false;

  // Override page reload globally when theme change is in progress
  const originalReload = window.location.reload;
  window.location.reload = function () {
    if (themeChangeInProgress) {
      console.warn("🚫 GLOBAL RELOAD BLOCKED - Theme change in progress");
      return false;
    }
    return originalReload.apply(this, arguments);
  };

  // Monitor for theme-related storage changes that might trigger reloads
  window.addEventListener("storage", function (e) {
    if (e.key === "dark_mode") {
      console.log(
        "🎨 Theme storage change detected:",
        e.oldValue,
        "→",
        e.newValue
      );
    }
  });

  /* ---------------------------------------------------------------------------
   * Responsive scrolling for URL hashes.
   * --------------------------------------------------------------------------- */

  // Dynamically get responsive navigation bar height for offsetting Scrollspy.
  function getNavBarHeight() {
    // Return fixed offset to match CSS scroll-margin-top
    return 60;
  }

  /**
   * Responsive hash scrolling.
   * Check for a URL hash as an anchor.
   * If it exists on current page, scroll to it responsively.
   * If `target` argument omitted (e.g. after event), assume it's the window's hash.
   */
  function scrollToAnchor(target) {
    // If `target` is undefined or HashChangeEvent object, set it to window's hash.
    // Decode the hash as browsers can encode non-ASCII characters (e.g. Chinese symbols).
    target =
      typeof target === "undefined" || typeof target === "object"
        ? decodeURIComponent(window.location.hash)
        : target;

    // If target element exists, scroll to it taking into account fixed navigation bar offset.
    if ($(target).length) {
      // Escape special chars from IDs, such as colons found in Markdown footnote links.
      target = "#" + $.escapeSelector(target.substring(1)); // Previously, `target = target.replace(/:/g, '\\:');`

      let elementOffset = Math.ceil($(target).offset().top - getNavBarHeight()); // Round up to highlight right ID!
      $("body").addClass("scrolling");
      $("html, body").animate(
        {
          scrollTop: elementOffset,
        },
        600,
        function () {
          $("body").removeClass("scrolling");
        }
      );
    } else {
      console.debug("Cannot scroll to target `#" + target + "`. ID not found!");
    }
  }

  // Make Scrollspy responsive.
  function fixScrollspy() {
    let $body = $("body");
    let data = $body.data("bs.scrollspy");
    if (data) {
      data._config.offset = getNavBarHeight();
      $body.data("bs.scrollspy", data);
      $body.scrollspy("refresh");
    }
  }

  // Enhanced navigation highlighting system
  function enhancedNavigationHighlighting() {
    const navLinks = document.querySelectorAll(
      '.navbar-nav .nav-link[href^="#"]'
    );

    if (navLinks.length === 0) {
      console.warn("No navigation links found");
      return;
    }

    // Dynamically extract section IDs from navigation links
    const sectionIds = [];
    navLinks.forEach((link) => {
      const href = link.getAttribute("href");
      if (href && href.startsWith("#") && href.length > 1) {
        const sectionId = href.substring(1);
        if (!sectionIds.includes(sectionId)) {
          sectionIds.push(sectionId);
        }
      }
    });

    const sections = [];

    // Find sections using multiple selectors for each discovered section ID
    sectionIds.forEach((id) => {
      let element =
        document.getElementById(id) ||
        document.querySelector(`section[id="${id}"]`) ||
        document.querySelector(`div[id="${id}"]`) ||
        document.querySelector(`[data-anchor="${id}"]`) ||
        document.querySelector(`.wg-${id}`) ||
        document.querySelector(`[class*="${id}"]`) ||
        document.querySelector(`*[data-section="${id}"]`) ||
        document.querySelector(`.section-${id}`);

      if (element) {
        sections.push(element);
        console.log(`Found section element for: ${id}`, element);
      } else {
        console.warn(`Could not find section element for: ${id}`);
      }
    });

    if (sections.length === 0) {
      console.warn("No sections found for any navigation links");
      return;
    }

    console.log(
      `Navigation highlighting initialized with ${navLinks.length} links and ${sections.length} sections`
    );
    console.log("Discovered section IDs:", sectionIds);

    // Cache section positions for better performance
    let sectionPositions = [];
    function cacheSectionPositions() {
      sectionPositions = sections.map((section) => ({
        element: section,
        top: section.offsetTop,
        bottom: section.offsetTop + section.offsetHeight,
      }));
    }
    cacheSectionPositions();

    function updateActiveNavigation() {
      const scrollPosition = window.scrollY + getNavBarHeight() + 10; // Reduced buffer for more accurate detection
      let activeSection = null;

      // Find the current section with more precise detection using cached positions
      sectionPositions.forEach(({ element, top, bottom }) => {
        // More precise section detection - account for section padding
        if (scrollPosition >= top - 20 && scrollPosition < bottom - 20) {
          activeSection = element;
        }
      });

      // If near the top of the page, highlight the first section
      if (window.scrollY < 100 && sections.length > 0) {
        activeSection = sections[0];
      }

      // Update navigation highlighting
      navLinks.forEach((link) => {
        link.classList.remove("active");

        if (activeSection) {
          const linkHref = link.getAttribute("href");
          const sectionId = "#" + activeSection.id;

          if (linkHref === sectionId) {
            link.classList.add("active");
            console.log(`Activated nav link for section: ${activeSection.id}`);
          }
        }
      });
    }

    // Optimized scroll handler for better performance
    let scrollTimeout;
    function handleScroll() {
      if (scrollTimeout) clearTimeout(scrollTimeout);
      scrollTimeout = setTimeout(updateActiveNavigation, 50); // Slightly longer timeout to reduce lag
    }

    // Initial update
    updateActiveNavigation();

    // Add scroll listener
    window.addEventListener("scroll", handleScroll, { passive: true });

    // Update on resize (navbar height might change and section positions need recalculation)
    let resizeTimeout;
    window.addEventListener(
      "resize",
      () => {
        if (resizeTimeout) clearTimeout(resizeTimeout);
        resizeTimeout = setTimeout(() => {
          cacheSectionPositions(); // Recalculate positions after layout changes
          updateActiveNavigation();
        }, 100);
      },
      { passive: true }
    );

    // Update when hash changes
    window.addEventListener("hashchange", updateActiveNavigation);

    return { updateActiveNavigation, handleScroll };
  }

  // Initialize enhanced navigation highlighting
  let navigationHighlighting = null;

  function initializeEnhancedNavigation() {
    // Clean up existing listeners if any
    if (navigationHighlighting && navigationHighlighting.handleScroll) {
      window.removeEventListener("scroll", navigationHighlighting.handleScroll);
    }

    // Initialize new navigation highlighting
    navigationHighlighting = enhancedNavigationHighlighting();
  }

  function removeQueryParamsFromUrl() {
    if (window.history.replaceState) {
      let urlWithoutSearchParams =
        window.location.protocol +
        "//" +
        window.location.host +
        window.location.pathname +
        window.location.hash;
      window.history.replaceState(
        { path: urlWithoutSearchParams },
        "",
        urlWithoutSearchParams
      );
    }
  }

  // Check for hash change event and fix responsive offset for hash links (e.g. Markdown footnotes).
  window.addEventListener("hashchange", scrollToAnchor);

  /* ---------------------------------------------------------------------------
   * Add smooth scrolling to all links inside the main navbar.
   * --------------------------------------------------------------------------- */

  $("#navbar-main li.nav-item a.nav-link").on("click", function (event) {
    // Store requested URL hash.
    let hash = this.hash;

    // If we are on a widget page and the navbar link is to a section on the same page.
    if (
      this.pathname === window.location.pathname &&
      hash &&
      $(hash).length &&
      $(".js-widget-page").length > 0
    ) {
      // Prevent default click behavior.
      event.preventDefault();

      // Use jQuery's animate() method for smooth page scrolling.
      // The numerical parameter specifies the time (ms) taken to scroll to the specified hash.
      let elementOffset = Math.ceil($(hash).offset().top - getNavBarHeight()); // Round up to highlight right ID!

      // Uncomment to debug.
      // let scrollTop = $(window).scrollTop();
      // let scrollDelta = (elementOffset - scrollTop);
      // console.debug('Scroll Delta: ' + scrollDelta);

      $("html, body").animate(
        {
          scrollTop: elementOffset,
        },
        800
      );
    }
  });

  /* ---------------------------------------------------------------------------
   * Hide mobile collapsable menu on clicking a link.
   * --------------------------------------------------------------------------- */

  $(document).on("click", ".navbar-collapse.show", function (e) {
    //get the <a> element that was clicked, even if the <span> element that is inside the <a> element is e.target
    let targetElement = $(e.target).is("a")
      ? $(e.target)
      : $(e.target).parent();

    if (
      targetElement.is("a") &&
      targetElement.attr("class") != "dropdown-toggle"
    ) {
      $(this).collapse("hide");
    }
  });

  // Enhanced mobile menu auto-close for navigation links
  $(document).on("click", ".navbar-nav .nav-link", function (e) {
    // Close mobile menu when any nav link is clicked (on mobile)
    if (window.innerWidth <= 768) {
      $(".navbar-collapse").collapse("hide");
    }
  });

  /* ---------------------------------------------------------------------------
   * Close mobile menu when scrolling.
   * --------------------------------------------------------------------------- */

  $(window).on("scroll", function () {
    // Close mobile menu when scrolling on mobile/tablet
    if (window.innerWidth <= 991) {
      let $navbarCollapse = $(".navbar-collapse");
      if ($navbarCollapse.hasClass("show")) {
        $navbarCollapse.collapse("hide");
      }
    }
  });

  /* ---------------------------------------------------------------------------
   * Close mobile/tablet toggle menu when tapping outside its area.
   * --------------------------------------------------------------------------- */

  $(document).on("click touchstart", function (e) {
    // Only apply on mobile and tablet devices (when toggle menu is used)
    if (window.innerWidth <= 991) {
      let $navbar = $("#navbar-main");
      let $navbarCollapse = $(".navbar-collapse");
      let $navbarToggler = $(".navbar-toggler");

      // Check if navbar is currently open
      if ($navbarCollapse.hasClass("show")) {
        // Check if click/tap was outside navbar area
        // Explicitly exclude the toggler button - it handles its own toggle behavior
        if (
          !$navbar.is(e.target) &&
          !$navbar.has(e.target).length &&
          !$navbarToggler.is(e.target) &&
          !$navbarToggler.has(e.target).length
        ) {
          $navbarCollapse.collapse("hide");
        }
      }
    }
  });

  /* ---------------------------------------------------------------------------
   * Mobile navbar toggle button handler.
   * --------------------------------------------------------------------------- */

  $(document).ready(function() {
    // Ensure Bootstrap collapse is initialized for mobile menu
    $('.navbar-toggler').on('click', function(e) {
      e.stopPropagation();
      const target = $(this).data('target');
      if (target) {
        const $target = $(target);
        // Only open the menu if it's closed, don't close it
        if (!$target.hasClass('show')) {
          $target.collapse('show');
        }
      }
    });
    
    // Close mobile menu when mouse leaves navbar area
    $('.navbar').on('mouseleave', function() {
      const $navbarCollapse = $('.navbar-collapse');
      if ($navbarCollapse.hasClass('show')) {
        $navbarCollapse.collapse('hide');
      }
    });
  });

  /* ---------------------------------------------------------------------------
   * Time-based navbar hide/show: Hide after 5s when not at top, show after 2s upscroll or at top.
   * --------------------------------------------------------------------------- */

  (function() {
    const $navbar = $('.navbar');
    let lastScrollTop = 0;
    let scrollDirection = null;
    let upScrollStartTime = 0;
    let timeAtCurrentPosition = 0;
    let lastPositionChangeTime = Date.now();
    
    const UPSCROLL_DURATION_TO_SHOW = 50; // 0.05 seconds of upscroll to show navbar
    const TIME_AT_POSITION_TO_HIDE = 11000; // 11 seconds at position (not scrolling) to hide
    const TOP_THRESHOLD = 50; // Consider "at top" if within 50px
    const MOUSE_TOP_THRESHOLD = 80; // Show navbar when mouse is within 80px of top
    
    function handleNavbarVisibility() {
      const currentScrollTop = window.pageYOffset || document.documentElement.scrollTop;
      const currentTime = Date.now();
      
      // Always show navbar when at top of page
      if (currentScrollTop <= TOP_THRESHOLD) {
        if ($navbar.hasClass('hide-navbar')) {
          $navbar.removeClass('hide-navbar');
        }
        scrollDirection = null;
        upScrollStartTime = 0;
        lastPositionChangeTime = currentTime;
        return;
      }
      
      // Determine scroll direction (no threshold - immediate response)
      let currentDirection = null;
      if (currentScrollTop < lastScrollTop) {
        currentDirection = 'up';
      } else if (currentScrollTop > lastScrollTop) {
        currentDirection = 'down';
        // Reset upscroll timer when scrolling down
        upScrollStartTime = 0;
      }
      
      // If direction changed to up, start timing
      if (currentDirection === 'up' && scrollDirection !== 'up') {
        upScrollStartTime = currentTime;
        scrollDirection = 'up';
      } else if (currentDirection === 'down') {
        scrollDirection = 'down';
      }
      
      // Check if user has been scrolling up for threshold time
      if (scrollDirection === 'up' && upScrollStartTime > 0) {
        const upScrollDuration = currentTime - upScrollStartTime;
        if (upScrollDuration >= UPSCROLL_DURATION_TO_SHOW) {
          // Show navbar after 2 seconds of upward scrolling
          if ($navbar.hasClass('hide-navbar')) {
            $navbar.removeClass('hide-navbar');
          }
        }
      }
      
      // Check if position hasn't changed (not scrolling)
      if (Math.abs(currentScrollTop - lastScrollTop) < 1) {
        timeAtCurrentPosition = currentTime - lastPositionChangeTime;
      } else {
        lastPositionChangeTime = currentTime;
        timeAtCurrentPosition = 0;
      }
      
      // Hide navbar after 5 seconds of no scrolling (when not at top)
      if (timeAtCurrentPosition >= TIME_AT_POSITION_TO_HIDE && currentScrollTop > TOP_THRESHOLD) {
        if (!$navbar.hasClass('hide-navbar')) {
          $navbar.addClass('hide-navbar');
        }
      }
      
      lastScrollTop = currentScrollTop;
    }
    
    // Use passive scroll listener for better performance
    let scrollTimeout;
    window.addEventListener('scroll', function() {
      if (scrollTimeout) {
        clearTimeout(scrollTimeout);
      }
      scrollTimeout = setTimeout(handleNavbarVisibility, 50);
    }, { passive: true });
    
    // Show navbar when mouse is near the top of the screen
    window.addEventListener('mousemove', function(e) {
      if (e.clientY <= MOUSE_TOP_THRESHOLD) {
        if ($navbar.hasClass('hide-navbar')) {
          $navbar.removeClass('hide-navbar');
          // Reset the timer so navbar stays visible for at least 11 seconds
          lastPositionChangeTime = Date.now();
          timeAtCurrentPosition = 0;
        }
      }
    }, { passive: true });
    
    // Also check periodically for the 5-second hide timer
    setInterval(handleNavbarVisibility, 1000);
  })();

  /* ---------------------------------------------------------------------------
   * Filter publications.
   * --------------------------------------------------------------------------- */

  // Active publication filters.
  let pubFilters = {};

  // Search term.
  let searchRegex;

  // Filter values (concatenated).
  let filterValues;

  // Publication container.
  let $grid_pubs = $("#container-publications");

  // Initialise Isotope.
  $grid_pubs.isotope({
    itemSelector: ".isotope-item",
    percentPosition: true,
    masonry: {
      // Use Bootstrap compatible grid layout.
      columnWidth: ".grid-sizer",
    },
    filter: function () {
      let $this = $(this);
      let searchResults = searchRegex ? $this.text().match(searchRegex) : true;
      let filterResults = filterValues ? $this.is(filterValues) : true;
      return searchResults && filterResults;
    },
  });

  // Filter by search term.
  let $quickSearch = $(".filter-search").keyup(
    debounce(function () {
      let searchTerms = $quickSearch.val().trim().split(/\s+/).filter(term => term.length > 0);
      if (searchTerms.length > 0) {
        // Create regex that matches all terms in any order
        let regexPattern = searchTerms.map(term => `(?=.*${term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`).join('') + '.*';
        searchRegex = new RegExp(regexPattern, "gis");
      } else {
        searchRegex = null;
      }
      $grid_pubs.isotope();
    })
  );

  // Debounce input to prevent spamming filter requests.
  function debounce(fn, threshold) {
    let timeout;
    threshold = threshold || 100;
    return function debounced() {
      clearTimeout(timeout);
      let args = arguments;
      let _this = this;

      function delayed() {
        fn.apply(_this, args);
      }

      timeout = setTimeout(delayed, threshold);
    };
  }

  // Flatten object by concatenating values.
  function concatValues(obj) {
    let value = "";
    for (let prop in obj) {
      value += obj[prop];
    }
    return value;
  }

  $(".pub-filters").on("change", function () {
    let $this = $(this);

    // Get group key.
    let filterGroup = $this[0].getAttribute("data-filter-group");

    // Set filter for group.
    pubFilters[filterGroup] = this.value;

    // Combine filters.
    filterValues = concatValues(pubFilters);

    // Activate filters.
    $grid_pubs.isotope();

    // If filtering by publication type, update the URL hash to enable direct linking to results.
    if (filterGroup == "pubtype") {
      // Set hash URL to current filter.
      let url = $(this).val();
      if (url.substr(0, 9) == ".pubtype-") {
        window.location.hash = url.substr(9);
      } else {
        window.location.hash = "";
      }
    }
  });

  // Filter publications according to hash in URL.
  function filter_publications() {
    let urlHash = window.location.hash.replace("#", "");
    let filterValue = "*";

    // Check if hash is numeric.
    if (urlHash != "" && !isNaN(urlHash)) {
      filterValue = ".pubtype-" + urlHash;
    }

    // Set filter.
    let filterGroup = "pubtype";
    pubFilters[filterGroup] = filterValue;
    filterValues = concatValues(pubFilters);

    // Activate filters.
    $grid_pubs.isotope();

    // Set selected option.
    $(".pubtype-select").val(filterValue);
  }

  /* ---------------------------------------------------------------------------
   * Google Maps or OpenStreetMap via Leaflet.
   * --------------------------------------------------------------------------- */

  function initMap() {
    if ($("#map").length) {
      let map_provider = $("#map-provider").val();
      let lat = $("#map-lat").val();
      let lng = $("#map-lng").val();
      let zoom = parseInt($("#map-zoom").val());
      let address = $("#map-dir").val();
      let api_key = $("#map-api-key").val();

      if (map_provider == 1) {
        let map = new GMaps({
          div: "#map",
          lat: lat,
          lng: lng,
          zoom: zoom,
          zoomControl: true,
          zoomControlOpt: {
            style: "SMALL",
            position: "TOP_LEFT",
          },
          panControl: false,
          streetViewControl: false,
          mapTypeControl: false,
          overviewMapControl: false,
          scrollwheel: true,
          draggable: true,
        });

        map.addMarker({
          lat: lat,
          lng: lng,
          click: function (e) {
            let url =
              "https://www.google.com/maps/place/" +
              encodeURIComponent(address) +
              "/@" +
              lat +
              "," +
              lng +
              "/";
            window.open(url, "_blank");
          },
          title: address,
        });
      } else {
        let map = new L.map("map").setView([lat, lng], zoom);
        if (map_provider == 3 && api_key.length) {
          L.tileLayer(
            "https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token={accessToken}",
            {
              attribution:
                'Map data &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="http://mapbox.com">Mapbox</a>',
              maxZoom: 18,
              id: "mapbox.streets",
              accessToken: api_key,
            }
          ).addTo(map);
        } else {
          L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
            maxZoom: 19,
            attribution:
              '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>',
          }).addTo(map);
        }
        let marker = L.marker([lat, lng]).addTo(map);
        let url =
          lat +
          "," +
          lng +
          "#map=" +
          zoom +
          "/" +
          lat +
          "/" +
          lng +
          "&layers=N";
        marker.bindPopup(
          address +
            '<p><a href="https://www.openstreetmap.org/directions?engine=osrm_car&route=' +
            url +
            '">Routing via OpenStreetMap</a></p>'
        );
      }
    }
  }

  /* ---------------------------------------------------------------------------
   * GitHub API.
   * --------------------------------------------------------------------------- */

  function printLatestRelease(selector, repo) {
    $.getJSON("https://api.github.com/repos/" + repo + "/tags")
      .done(function (json) {
        let release = json[0];
        $(selector).append(" " + release.name);
      })
      .fail(function (jqxhr, textStatus, error) {
        let err = textStatus + ", " + error;
        console.log("Request Failed: " + err);
      });
  }

  /* ---------------------------------------------------------------------------
   * Toggle search dialog.
   * --------------------------------------------------------------------------- */

  function toggleSearchDialog() {
    if ($("body").hasClass("searching")) {
      // Clear search query and hide search modal.
      $("[id=search-query]").blur();
      $("body").removeClass("searching compensate-for-scrollbar");

      // Remove search query params from URL as user has finished searching.
      removeQueryParamsFromUrl();

      // Prevent fixed positioned elements (e.g. navbar) moving due to scrollbars.
      $("#fancybox-style-noscroll").remove();
    } else {
      // Prevent fixed positioned elements (e.g. navbar) moving due to scrollbars.
      if (
        !$("#fancybox-style-noscroll").length &&
        document.body.scrollHeight > window.innerHeight
      ) {
        $("head").append(
          '<style id="fancybox-style-noscroll">.compensate-for-scrollbar{margin-right:' +
            (window.innerWidth - document.documentElement.clientWidth) +
            "px;}</style>"
        );
        $("body").addClass("compensate-for-scrollbar");
      }

      // Show search modal.
      $("body").addClass("searching");
      $(".search-results")
        .css({ opacity: 0, visibility: "visible" })
        .animate({ opacity: 1 }, 200);
      $("#search-query").focus();
    }
  }

  /* ---------------------------------------------------------------------------
   * Change Theme Mode (0: Day, 1: Night, 2: Auto).
   * --------------------------------------------------------------------------- */

  function canChangeTheme() {
    // If the theme changer component is present, then user is allowed to change the theme variation.
    return $(".js-dark-toggle").length;
  }

  function getThemeMode() {
    return parseInt(localStorage.getItem("dark_mode") || 2);
  }

  function changeThemeModeClick() {
    if (!canChangeTheme()) {
      return;
    }

    // GLOBAL ANTI-RELOAD PROTECTION
    themeChangeInProgress = true;
    console.log("🔄 Theme switch initiated - GLOBAL RELOAD PROTECTION ACTIVE");

    // Save current scroll position before theme change
    const savedScrollY = window.pageYOffset || document.documentElement.scrollTop;

    let $themeChanger = $(".js-dark-toggle i");
    let $themeToggle = $(".js-dark-toggle");
    let currentThemeMode = getThemeMode();
    let isDarkTheme;
    switch (currentThemeMode) {
      case 0:
        localStorage.setItem("dark_mode", "1");
        isDarkTheme = 1;
        console.info("User changed theme variation to Dark.");
        $themeChanger.removeClass("fa-moon fa-sun").addClass("fa-palette");
        $themeToggle.attr("title", "Toggle auto mode");
        break;
      case 1:
        localStorage.setItem("dark_mode", "2");
        if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
          // The visitor prefers dark themes and switching to the dark variation is allowed by admin.
          isDarkTheme = 1;
        } else if (window.matchMedia("(prefers-color-scheme: light)").matches) {
          // The visitor prefers light themes and switching to the dark variation is allowed by admin.
          isDarkTheme = 0;
        } else {
          isDarkTheme = isSiteThemeDark; // Use the site's default theme variation based on `light` in the theme file.
        }
        console.info("User changed theme variation to Auto.");
        $themeChanger.removeClass("fa-moon fa-palette").addClass("fa-sun");
        $themeToggle.attr("title", "Toggle light mode");
        break;
      default:
        localStorage.setItem("dark_mode", "0");
        isDarkTheme = 0;
        console.info("User changed theme variation to Light.");
        $themeChanger.removeClass("fa-sun fa-palette").addClass("fa-moon");
        $themeToggle.attr("title", "Toggle dark mode");
        break;
    }

    renderThemeVariation(isDarkTheme);

    // Restore scroll position after theme rendering and animation
    setTimeout(() => {
      window.scrollTo(0, savedScrollY);
    }, 550);

    // Reset global flag after theme switch is complete
    setTimeout(() => {
      themeChangeInProgress = false;
      console.log(
        "✅ Theme switch complete - GLOBAL RELOAD PROTECTION DISABLED"
      );
    }, 1500);
  }

  function getThemeVariation() {
    if (!canChangeTheme()) {
      return isSiteThemeDark; // Use the site's default theme variation based on `light` in the theme file.
    }
    let currentThemeMode = getThemeMode();
    let isDarkTheme;
    switch (currentThemeMode) {
      case 0:
        isDarkTheme = 0;
        break;
      case 1:
        isDarkTheme = 1;
        break;
      default:
        if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
          // The visitor prefers dark themes and switching to the dark variation is allowed by admin.
          isDarkTheme = 1;
        } else if (window.matchMedia("(prefers-color-scheme: light)").matches) {
          // The visitor prefers light themes and switching to the dark variation is allowed by admin.
          isDarkTheme = 0;
        } else {
          isDarkTheme = isSiteThemeDark; // Use the site's default theme variation based on `light` in the theme file.
        }
        break;
    }
    return isDarkTheme;
  }

  /**
   * Force reset animation colors after theme switch to prevent color persistence
   */
  function resetAnimationColors() {
    // Remove and re-add animation classes to force color recalculation
    const animatedElements = document.querySelectorAll(".visible");
    animatedElements.forEach((element) => {
      // Temporarily remove the class
      element.classList.remove("visible");
      // Force a reflow to ensure the removal takes effect
      element.offsetHeight;
      // Re-add the class to trigger fresh color calculation
      element.classList.add("visible");
    });

    // Also reset any elements that might have inline styles from animations
    const elementsWithInlineStyles =
      document.querySelectorAll("[style*='color']");
    elementsWithInlineStyles.forEach((element) => {
      // Check if this element has animation-related classes
      if (
        element.classList.contains("visible") ||
        element.closest(".article-style") ||
        element.closest(".tag-cloud") ||
        element.closest(".biography-container")
      ) {
        // Remove inline color styles to let CSS take over
        element.style.removeProperty("color");
        // Force reflow
        element.offsetHeight;
      }
    });

    // Force recalculation of CSS custom properties
    const root = document.documentElement;
    const computedStyle = getComputedStyle(root);

    // Trigger a style recalculation by temporarily modifying and restoring a property
    const currentDisplay = root.style.display;
    root.style.display = "none";
    root.offsetHeight; // Trigger reflow
    root.style.display = currentDisplay;
  }

  /**
   * Render theme variation (day or night).
   *
   * @param {int} isDarkTheme - TODO: convert to boolean.
   * @param {boolean} init
   * @returns {undefined}
   */
  function renderThemeVariation(isDarkTheme, init = false) {
    // Is code highlighting enabled in site config?
    const codeHlEnabled = $("link[title=hl-light]").length > 0;
    const codeHlLight = $("link[title=hl-light]")[0];
    const codeHlDark = $("link[title=hl-dark]")[0];
    const diagramEnabled = $("script[title=mermaid]").length > 0;

    // Debug logging for Mermaid detection
    console.log("Theme switch debug:", {
      isDarkTheme,
      init,
      diagramEnabled,
      mermaidElementsCount: document.querySelectorAll(".mermaid").length,
    });

    // Check if re-render required.
    if (!init) {
      // If request to render light when light variation already rendered, return.
      // If request to render dark when dark variation already rendered, return.
      if (
        (isDarkTheme === 0 && !$("body").hasClass("dark")) ||
        (isDarkTheme === 1 && $("body").hasClass("dark"))
      ) {
        return;
      }
    }

    if (isDarkTheme === 0) {
      if (!init) {
        // Only fade in the page when changing the theme variation.
        $("body")
          .css({ opacity: 0, visibility: "visible" })
          .animate({ opacity: 1 }, 500);
      }
      $("body").removeClass("dark");
      if (codeHlEnabled) {
        codeHlLight.disabled = false;
        codeHlDark.disabled = true;
      }
      // Check for Mermaid diagrams - only process if they actually exist
      const mermaidElements = document.querySelectorAll(".mermaid");
      const hasActualMermaidContent = mermaidElements.length > 0;

      // COMPLETELY DISABLE MERMAID RELOAD FOR THEME SWITCHING
      // Only allow Mermaid initialization on page load, never on theme switch
      if (diagramEnabled && hasActualMermaidContent && init) {
        console.log("Initializing Mermaid with default theme on page load");
        mermaid.initialize({ theme: "default", securityLevel: "loose" });
      } else if (!init && hasActualMermaidContent) {
        console.log(
          "MERMAID RELOAD PREVENTED - Theme switching without reload"
        );
        // For theme switching, we just log that we're skipping reload
        // Mermaid diagrams will keep their current theme until page reload
      }
      // NO RELOAD EVER during theme switching

      // Reset animation colors after theme switch (with delay to ensure DOM is updated)
      if (!init) {
        setTimeout(() => resetAnimationColors(), 200);
      }
    } else if (isDarkTheme === 1) {
      if (!init) {
        // Only fade in the page when changing the theme variation.
        $("body")
          .css({ opacity: 0, visibility: "visible" })
          .animate({ opacity: 1 }, 500);
      }
      $("body").addClass("dark");
      if (codeHlEnabled) {
        codeHlLight.disabled = true;
        codeHlDark.disabled = false;
      }
      // Check for Mermaid diagrams - only process if they actually exist
      const mermaidElements = document.querySelectorAll(".mermaid");
      const hasActualMermaidContent = mermaidElements.length > 0;

      // COMPLETELY DISABLE MERMAID RELOAD FOR THEME SWITCHING
      // Only allow Mermaid initialization on page load, never on theme switch
      if (diagramEnabled && hasActualMermaidContent && init) {
        console.log("Initializing Mermaid with dark theme on page load");
        mermaid.initialize({ theme: "dark", securityLevel: "loose" });
      } else if (!init && hasActualMermaidContent) {
        console.log(
          "MERMAID RELOAD PREVENTED - Theme switching without reload"
        );
        // For theme switching, we just log that we're skipping reload
        // Mermaid diagrams will keep their current theme until page reload
      }
      // NO RELOAD EVER during theme switching

      // Reset animation colors after theme switch (with delay to ensure DOM is updated)
      if (!init) {
        setTimeout(() => resetAnimationColors(), 200);
      }
    }
  }

  function initThemeVariation() {
    // If theme changer component present, set its icon according to the theme mode (day, night, or auto).
    if (canChangeTheme) {
      let themeMode = getThemeMode();
      let $themeChanger = $(".js-dark-toggle i");
      let $themeToggle = $(".js-dark-toggle");
      switch (themeMode) {
        case 0:
          $themeChanger.removeClass("fa-sun fa-palette").addClass("fa-moon");
          $themeToggle.attr("title", "Toggle dark mode");
          console.info("Initialize theme variation to Light.");
          break;
        case 1:
          $themeChanger.removeClass("fa-moon fa-sun").addClass("fa-palette");
          $themeToggle.attr("title", "Toggle auto mode");
          console.info("Initialize theme variation to Dark.");
          break;
        default:
          $themeChanger.removeClass("fa-moon fa-palette").addClass("fa-sun");
          $themeToggle.attr("title", "Toggle light mode");
          console.info("Initialize theme variation to Auto.");
          break;
      }
    }
    // Render the day or night theme.
    let isDarkTheme = getThemeVariation();
    renderThemeVariation(isDarkTheme, true);
  }

  /* ---------------------------------------------------------------------------
   * Normalize Bootstrap Carousel Slide Heights.
   * --------------------------------------------------------------------------- */

  function normalizeCarouselSlideHeights() {
    $(".carousel").each(function () {
      // Get carousel slides.
      let items = $(".carousel-item", this);
      // Reset all slide heights.
      items.css("min-height", 0);
      // Normalize all slide heights.
      let maxHeight = Math.max.apply(
        null,
        items
          .map(function () {
            return $(this).outerHeight();
          })
          .get()
      );
      items.css("min-height", maxHeight + "px");
    });
  }

  /* ---------------------------------------------------------------------------
   * Fix Hugo's Goldmark output and Mermaid code blocks.
   * --------------------------------------------------------------------------- */

  /**
   * Fix Hugo's Goldmark output.
   */
  function fixHugoOutput() {
    // Fix Goldmark table of contents.
    // - Must be performed prior to initializing ScrollSpy.
    $("#TableOfContents").addClass("nav flex-column");
    $("#TableOfContents li").addClass("nav-item");
    $("#TableOfContents li a").addClass("nav-link");

    // Fix Goldmark task lists (remove bullet points).
    $("input[type='checkbox'][disabled]").parents("ul").addClass("task-list");
  }

  /**
   * Fix Mermaid.js clash with Highlight.js.
   * Refactor Mermaid code blocks as divs to prevent Highlight parsing them and enable Mermaid to parse them.
   */
  function fixMermaid() {
    let mermaids = [];
    [].push.apply(
      mermaids,
      document.getElementsByClassName("language-mermaid")
    );
    for (let i = 0; i < mermaids.length; i++) {
      $(mermaids[i]).unwrap("pre"); // Remove <pre> wrapper.
      $(mermaids[i]).replaceWith(function () {
        // Convert <code> block to <div> and add `mermaid` class so that Mermaid will parse it.
        return $("<div />").append($(this).contents()).addClass("mermaid");
      });
    }
  }

  /* ---------------------------------------------------------------------------
   * On document ready.
   * --------------------------------------------------------------------------- */

  $(document).ready(function () {
    fixHugoOutput();
    fixMermaid();

    // Initialise code highlighting if enabled for this page.
    // Note: this block should be processed after the Mermaid code-->div conversion.
    if (code_highlighting) {
      hljs.initHighlighting();
    }

    // Initialize theme variation.
    initThemeVariation();

    // Change theme mode.
    $(".js-dark-toggle").click(function (e) {
      e.preventDefault();
      changeThemeModeClick();
    });

    // Light theme button - set to light mode specifically
    $(".js-set-theme-light").click(function (e) {
      e.preventDefault();
      localStorage.setItem("dark_mode", "0");
      renderThemeVariation(0);
    });

    // Dark theme button - set to dark mode specifically
    $(".js-set-theme-dark").click(function (e) {
      e.preventDefault();
      localStorage.setItem("dark_mode", "1");
      renderThemeVariation(1);
    });

    // Search trigger from menu
    $(document).on("click", ".js-search-trigger", function (e) {
      e.preventDefault();
      e.stopPropagation();
      $(".js-search").click();
    });
    
    // Font size toggle - ensure theme menu is completely hidden first
    $(document).on("click", ".js-font-size-toggle", function (e) {
      e.preventDefault();
      e.stopPropagation();
      let fontMenu = $(".font-size-menu");
      let themeMenu = $(".theme-menu");
      
      // Force immediate hide - check both visibility states
      if (themeMenu.is(":visible")) {
        themeMenu.hide();
        // Wait for DOM update before showing
        setTimeout(function() {
          fontMenu.toggle();
        }, 50);
      } else {
        fontMenu.toggle();
      }
    });
    
    // Theme toggle - ensure font size menu is completely hidden first
    $(document).on("click", ".js-theme-toggle", function (e) {
      e.preventDefault();
      e.stopPropagation();
      let fontMenu = $(".font-size-menu");
      let themeMenu = $(".theme-menu");
      
      // Force immediate hide - check both visibility states
      if (fontMenu.is(":visible")) {
        fontMenu.hide();
        // Wait for DOM update before showing
        setTimeout(function() {
          themeMenu.toggle();
        }, 50);
      } else {
        themeMenu.toggle();
      }
    });
    
    // Hide dropdowns when clicking outside
    $(document).on("click", function (e) {
      if (!$(e.target).closest(".nav-item.dropdown").length) {
        $(".font-size-menu, .theme-menu").stop(true, true).css("display", "none");
      }
    });

    // Live update of day/night mode on system preferences update (no refresh required).
    // Note: since we listen only for *dark* events, we won't detect other scheme changes such as light to no-preference.
    const darkModeMediaQuery = window.matchMedia(
      "(prefers-color-scheme: dark)"
    );
    darkModeMediaQuery.addListener((e) => {
      if (!canChangeTheme()) {
        // Changing theme variation is not allowed by admin.
        return;
      }
      const darkModeOn = e.matches;
      console.log(
        `OS dark mode preference changed to ${darkModeOn ? "🌒 on" : "☀️ off"}.`
      );
      let currentThemeVariation = parseInt(
        localStorage.getItem("dark_mode") || 2
      );
      let isDarkTheme;
      if (currentThemeVariation === 2) {
        if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
          // The visitor prefers dark themes.
          isDarkTheme = 1;
        } else if (window.matchMedia("(prefers-color-scheme: light)").matches) {
          // The visitor prefers light themes.
          isDarkTheme = 0;
        } else {
          // The visitor does not have a day or night preference, so use the theme's default setting.
          isDarkTheme = isSiteThemeDark;
        }
        renderThemeVariation(isDarkTheme);
      }
    });
  });

  /* ---------------------------------------------------------------------------
   * On window loaded.
   * --------------------------------------------------------------------------- */

  $(window).on("load", function () {
    // Filter projects.
    $(".projects-container").each(function (index, container) {
      let $container = $(container);
      let $section = $container.closest("section");
      let layout;
      if ($section.find(".isotope").hasClass("js-layout-row")) {
        layout = "fitRows";
      } else {
        layout = "masonry";
      }

      $container.imagesLoaded(function () {
        // Initialize Isotope after all images have loaded.
        $container.isotope({
          itemSelector: ".isotope-item",
          layoutMode: layout,
          masonry: {
            gutter: 20,
          },
          filter: $section.find(".default-project-filter").text(),
        });

        // Filter items when filter link is clicked.
        $section.find(".project-filters a").click(function () {
          let selector = $(this).attr("data-filter");
          $container.isotope({ filter: selector });
          $(this)
            .removeClass("active")
            .addClass("active")
            .siblings()
            .removeClass("active all");
          return false;
        });

        // If window hash is set, scroll to hash.
        // Placing this within `imagesLoaded` prevents scrolling to the wrong location due to dynamic image loading
        // affecting page layout and position of the target anchor ID.
        // Note: If there are multiple project widgets on a page, ideally only perform this once after images
        // from *all* project widgets have finished loading.
        if (window.location.hash) {
          scrollToAnchor();
        }
      });
    });

    // Enable publication filter for publication index page.
    if ($(".pub-filters-select")) {
      filter_publications();
      // Useful for changing hash manually (e.g. in development):
      // window.addEventListener('hashchange', filter_publications, false);
    }

    // Scroll to top of page.
    $(".back-to-top").click(function (event) {
      event.preventDefault();
      $("html, body").animate(
        {
          scrollTop: 0,
        },
        800,
        function () {
          window.location.hash = "";
        }
      );
    });

    // Load citation modal on 'Cite' click.
    $(".js-cite-modal").click(function (e) {
      e.preventDefault();
      let filename = $(this).attr("data-filename");
      let modal = $("#modal");
      modal
        .find(".modal-body code")
        .load(filename, function (response, status, xhr) {
          if (status == "error") {
            let msg = "Error: ";
            $("#modal-error").html(msg + xhr.status + " " + xhr.statusText);
          } else {
            $(".js-download-cite").attr("href", filename);
          }
        });
      modal.modal("show");
    });

    // Close modal on ESC key press
    $(document).keydown(function (e) {
      if (e.key === "Escape") {
        // Check if the ESC key is pressed
        $("#modal").modal("hide");
      }
    });

    // Copy citation text on 'Copy' click.
    $(".js-copy-cite").click(function (e) {
      e.preventDefault();
      // Get selection.
      let range = document.createRange();
      let code_node = document.querySelector("#modal .modal-body");
      range.selectNode(code_node);
      window.getSelection().addRange(range);
      try {
        // Execute the copy command.
        document.execCommand("copy");
      } catch (e) {
        console.log("Error: citation copy failed.");
      }
      // Remove selection.
      window.getSelection().removeRange(range);
    });

    // Initialise Google Maps if necessary.
    initMap();

    // Print latest version of GitHub projects.
    let githubReleaseSelector = ".js-github-release";
    if ($(githubReleaseSelector).length > 0)
      printLatestRelease(
        githubReleaseSelector,
        $(githubReleaseSelector).data("repo")
      );

    // On search icon click toggle search dialog.
    $(".js-search").click(function (e) {
      e.preventDefault();
      toggleSearchDialog();
    });

    // Close search modal when clicking outside the content area (on margins)
    $(".search-results").click(function (e) {
      // Only close if clicking directly on the search-results background (not on child elements)
      if (e.target === this && $("body").hasClass("searching")) {
        toggleSearchDialog();
      }
    });

    $(document).on("keydown", function (e) {
      if (e.which == 27) {
        // `Esc` key pressed.
        if ($("body").hasClass("searching")) {
          toggleSearchDialog();
        }
      } else if (
        e.which == 191 &&
        e.shiftKey == false &&
        !$("input,textarea").is(":focus")
      ) {
        // `/` key pressed outside of text input.
        e.preventDefault();
        toggleSearchDialog();
      }
    });
  });

  // Normalize Bootstrap carousel slide heights.
  $(window).on("load resize orientationchange", normalizeCarouselSlideHeights);

  // Automatic main menu dropdowns on mouse over.
  $("body").on("mouseenter mouseleave", ".dropdown", function (e) {
    var dropdown = $(e.target).closest(".dropdown");
    var menu = $(".dropdown-menu", dropdown);
    dropdown.addClass("show");
    menu.addClass("show");
    setTimeout(function () {
      dropdown[dropdown.is(":hover") ? "addClass" : "removeClass"]("show");
      menu[dropdown.is(":hover") ? "addClass" : "removeClass"]("show");
    }, 300);

    // Re-initialize Scrollspy with dynamic navbar height offset.
    fixScrollspy();

    if (window.location.hash) {
      // When accessing homepage from another page and `#top` hash is set, show top of page (no hash).
      if (window.location.hash == "#top") {
        window.location.hash = "";
      } else if (!$(".projects-container").length) {
        // If URL contains a hash and there are no dynamically loaded images on the page,
        // immediately scroll to target ID taking into account responsive offset.
        // Otherwise, wait for `imagesLoaded()` to complete before scrolling to hash to prevent scrolling to wrong
        // location.
        scrollToAnchor();
      }
    }

    // Call `fixScrollspy` when window is resized.
    let resizeTimer;
    $(window).resize(function () {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(fixScrollspy, 200);
    });
  });

  /* ---------------------------------------------------------------------------
   * Enable a hovering tooltip
   * --------------------------------------------------------------------------- */

  $(document).ready(function () {
    $('[data-toggle="tooltip1"]').tooltip();
  });

  // On scroll and only in desktop view, highlight section headings, tags in articles, bio info (name, title, email, socials), and the tag cloud at the bottom of the site. This work depends on CSS code in custom.scss, and JS code in academic.js.

  // Make scroll animations responsive to viewport changes
  let scrollAnimationsInitialized = false;
  let scrollEventListeners = [];

  function initializeScrollAnimations() {
    // Clean up existing event listeners
    scrollEventListeners.forEach((listener) => {
      window.removeEventListener(listener.type, listener.handler);
    });
    scrollEventListeners = [];

    // Initialize scroll animations for desktop view
    if (window.innerWidth > 999) {
      function setupScrollAnimations() {
        const sectionHeading = document.querySelectorAll(
          "div.col-12.col-lg-4.section-heading"
        );
        const sectionHeadingH1 = document.querySelectorAll(
          "div.col-12.col-lg-4.section-heading > h1"
        );
        const articleTags = document.querySelectorAll(
          "div.article-container.pt-3 > div.btn-links.mb-3 > a:link"
        );
        const fullText = document.querySelectorAll(
          "#top > div.pub > div > a > button"
        );
        const citationButton = document.querySelectorAll(
          "div.btn-links.mb-3 > button"
        );
        const buttonH3 = document.querySelectorAll("button > h3");
        const portraitInfo = document.querySelectorAll(".portrait-title > h3");
        const icons = document.querySelectorAll(".social-icon");
        const cloudTags = document.querySelectorAll(".tag-cloud > a:link");

        function revealOnScroll(elements, delayFactor = 0) {
          const triggerBottom = window.innerHeight / 1.05;
          elements.forEach((el, index) => {
            // Skip already visible elements to avoid unnecessary getBoundingClientRect() calls
            if (el.classList.contains("visible")) return;

            const elTop = el.getBoundingClientRect().top;
            // Show elements that are in view or have already passed the trigger point
            if (elTop < triggerBottom) {
              // Use requestAnimationFrame for smoother, immediate updates instead of setTimeout
              if (delayFactor === 0) {
                el.classList.add("visible");
              } else {
                // Only use minimal delays for specific elements
                setTimeout(() => {
                  el.classList.add("visible");
                }, Math.min(index * delayFactor, 50)); // Cap max delay at 50ms
              }
            }
          });
        }

        function checkAllElementsOnLoad(elements, delayFactor = 0) {
          const triggerBottom = window.innerHeight / 1.05;
          elements.forEach((el, index) => {
            // Skip already visible elements to avoid unnecessary getBoundingClientRect() calls
            if (el.classList.contains("visible")) return;

            const rect = el.getBoundingClientRect();
            // Show elements that are currently visible or above the viewport
            if (rect.top < triggerBottom || rect.bottom < 0) {
              // Use requestAnimationFrame for smoother, immediate updates instead of setTimeout
              if (delayFactor === 0) {
                el.classList.add("visible");
              } else {
                // Only use minimal delays for specific elements
                setTimeout(() => {
                  el.classList.add("visible");
                }, Math.min(index * delayFactor, 50)); // Cap max delay at 50ms
              }
            }
          });
        }

        function checkElements(isInitialLoad = false) {
          if (isInitialLoad) {
            // On initial load or hash change, check all elements including those already above viewport
            // Reduced delays for faster page responsiveness
            checkAllElementsOnLoad(sectionHeading);
            checkAllElementsOnLoad(sectionHeadingH1);
            checkAllElementsOnLoad(articleTags, 1); // Reduced from 5
            checkAllElementsOnLoad(fullText);
            checkAllElementsOnLoad(citationButton);
            checkAllElementsOnLoad(buttonH3);
            checkAllElementsOnLoad(portraitInfo, 2); // Reduced from 30
            checkAllElementsOnLoad(icons, 3); // Reduced from 90
            checkAllElementsOnLoad(cloudTags);
          } else {
            // Regular scroll behavior - minimal delays for instant feedback
            revealOnScroll(sectionHeading);
            revealOnScroll(sectionHeadingH1);
            revealOnScroll(articleTags, 1); // Reduced from 5
            revealOnScroll(fullText);
            revealOnScroll(citationButton);
            revealOnScroll(buttonH3);
            revealOnScroll(portraitInfo, 2); // Reduced from 30
            revealOnScroll(icons, 3); // Reduced from 90
            revealOnScroll(cloudTags);
          }
        }

        // Create event handlers with throttling for better performance
        let scrollTimeout;
        const scrollHandler = () => {
          // Throttle scroll events to run at most every 50ms for faster responsiveness
          if (scrollTimeout) return;
          scrollTimeout = setTimeout(() => {
            checkElements(false);
            scrollTimeout = null;
          }, 50); // Reduced from 100ms for faster response
        };

        const resizeHandler = () => {
          // When resizing, reinitialize animations
          setTimeout(() => {
            initializeScrollAnimations();
          }, 100);
        };
        const hashChangeHandler = () => {
          // Immediate response to hash changes for faster navigation
          setTimeout(() => checkElements(true), 0);
        };
        const loadHandler = () => {
          // Quick initial load
          setTimeout(() => checkElements(true), 50);
        };

        // Bind to scroll with passive listener for better performance
        window.addEventListener("scroll", scrollHandler, { passive: true });
        scrollEventListeners.push({ type: "scroll", handler: scrollHandler });

        // Also trigger on resize and when fragment identifiers change (e.g., #section)
        window.addEventListener("resize", resizeHandler);
        scrollEventListeners.push({ type: "resize", handler: resizeHandler });

        window.addEventListener("hashchange", hashChangeHandler);
        scrollEventListeners.push({
          type: "hashchange",
          handler: hashChangeHandler,
        });

        // Ensure check runs after all content (e.g., images) is fully loaded
        window.addEventListener("load", loadHandler);
        scrollEventListeners.push({ type: "load", handler: loadHandler });

        // Initial check - this handles both initial load and resize from mobile to desktop
        checkElements(true);
      }

      // Check if DOM is already loaded
      if (document.readyState === "loading") {
        // DOM is still loading, wait for it
        document.addEventListener("DOMContentLoaded", setupScrollAnimations);
      } else {
        // DOM is already loaded, run immediately
        setupScrollAnimations();
      }

      scrollAnimationsInitialized = true;
    } else {
      // For mobile/tablet screens, enable scroll animations with optimized performance
      function setupMobileScrollAnimations() {
        const sectionHeading = document.querySelectorAll(
          "div.col-12.col-lg-4.section-heading"
        );
        const sectionHeadingH1 = document.querySelectorAll(
          "div.col-12.col-lg-4.section-heading > h1"
        );
        const articleTags = document.querySelectorAll(
          "div.article-container.pt-3 > div.btn-links.mb-3 > a:link"
        );
        const fullText = document.querySelectorAll(
          "#top > div.pub > div > a > button"
        );
        const citationButton = document.querySelectorAll(
          "div.btn-links.mb-3 > button"
        );
        const buttonH3 = document.querySelectorAll("button > h3");
        const portraitInfo = document.querySelectorAll(".portrait-title > h3");
        const icons = document.querySelectorAll(".social-icon");
        const cloudTags = document.querySelectorAll(".tag-cloud > a:link");

        // Mobile-optimized reveal function with throttling
        let ticking = false;
        function revealOnScrollMobile() {
          if (!ticking) {
            requestAnimationFrame(() => {
              const triggerBottom = window.innerHeight / 1.15; // More generous trigger for earlier animation
              const triggerTop = -50; // Allow elements to animate when scrolling up

              // Function to check and animate elements
              function animateVisible(elements, delayFactor = 0) {
                elements.forEach((el, index) => {
                  if (!el.classList.contains("visible")) {
                    const rect = el.getBoundingClientRect();

                    // Trigger if element is coming into view from below OR from above
                    if (
                      (rect.top < triggerBottom && rect.top > triggerTop) ||
                      (rect.bottom > triggerTop &&
                        rect.bottom < window.innerHeight)
                    ) {
                      // Immediate visibility for elements with no delay, minimal delays otherwise
                      if (delayFactor === 0) {
                        el.classList.add("visible");
                      } else {
                        setTimeout(() => {
                          el.classList.add("visible");
                        }, Math.min(index * delayFactor, 30)); // Cap at 30ms for mobile
                      }
                    }
                  }
                });
              }

              // Animate different element groups with minimal delays for instant feel
              animateVisible(sectionHeading);
              animateVisible(sectionHeadingH1);
              animateVisible(articleTags, 1);
              animateVisible(fullText);
              animateVisible(citationButton);
              animateVisible(buttonH3);
              animateVisible(portraitInfo, 1); // Reduced from 5
              animateVisible(icons, 2); // Reduced from 10
              animateVisible(cloudTags, 1); // Reduced from 3

              ticking = false;
            });
          }
          ticking = true;
        }

        // Throttled scroll event handler
        const mobileScrollHandler = () => revealOnScrollMobile();

        // Initial check for elements already in view - faster for instant feedback
        setTimeout(() => revealOnScrollMobile(), 10);

        // Add scroll listener
        window.addEventListener("scroll", mobileScrollHandler, {
          passive: true,
        });
        scrollEventListeners.push({
          type: "scroll",
          handler: mobileScrollHandler,
        });
      }

      // Setup mobile animations
      if (document.readyState === "loading") {
        document.addEventListener(
          "DOMContentLoaded",
          setupMobileScrollAnimations
        );
      } else {
        setupMobileScrollAnimations();
      }

      scrollAnimationsInitialized = true;
    }
  }

  // Initialize scroll animations on DOM ready
  document.addEventListener("DOMContentLoaded", initializeScrollAnimations);

  // Re-initialize on window resize to handle mobile/desktop transitions
  window.addEventListener("resize", () => {
    setTimeout(initializeScrollAnimations, 100);
  });

  // CARDS FOR IMAGES

  document.addEventListener("DOMContentLoaded", function () {
    const imageModal = document.getElementById("myModal");
    const images = document.querySelectorAll(".imageContainer img"); // Main article images
    const modalImageWrapper = document.querySelector(
      ".imageModal-content-wrapper"
    ); // Wrapper for modal images
    const prev = document.querySelector(".prev"); // Previous arrow
    const next = document.querySelector(".next"); // Next arrow
    const imageClose = document.querySelector(".imageClose"); // Close button
    let currentIndex = 0;
    let modalImages = [];

    // Function to create modal images only once
    function initializeModalImages() {
      if (modalImages.length === 0) {
        // Check if modal images are already initialized
        images.forEach((img, index) => {
          const modalImg = document.createElement("img");
          modalImg.src = img.src;
          modalImg.classList.add("imageModal-content");
          modalImg.style.display = "none"; // Hide all modal images initially
          modalImageWrapper.appendChild(modalImg);
          modalImages.push(modalImg); // Push to modalImages array
        });
      }
    }

    // Function to display the clicked image in the modal
    function showImage(index) {
      currentIndex = index;
      modalImages.forEach((img) => {
        img.style.display = "none"; // Hide all images
      });
      modalImages[currentIndex].style.display = "block"; // Show the current image
    }

    // Open modal and display clicked image
    images.forEach((img, index) => {
      img.addEventListener("click", () => {
        initializeModalImages(); // Initialize the modal images only once
        imageModal.style.display = "block"; // Show modal
        showImage(index); // Display the clicked image
      });
    });

    // Close modal
    imageClose.onclick = function () {
      imageModal.style.display = "none";
    };

    // Close modal on ESC key
    window.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        imageModal.style.display = "none";
      }
    });

    // Navigation for next and previous images
    next.onclick = function () {
      currentIndex = (currentIndex + 1) % modalImages.length; // Wrap around to first image
      showImage(currentIndex);
    };

    prev.onclick = function () {
      currentIndex =
        (currentIndex - 1 + modalImages.length) % modalImages.length; // Wrap around to last image
      showImage(currentIndex);
    };

    // Arrow key navigation
    window.addEventListener("keydown", (e) => {
      if (e.key === "ArrowRight") {
        next.click();
      } else if (e.key === "ArrowLeft") {
        prev.click();
      }
    });

    // Swipe gestures for mobile devices
    let startX = 0;
    let endX = 0;

    modalImageWrapper.addEventListener("touchstart", (e) => {
      startX = e.touches[0].clientX;
    });

    modalImageWrapper.addEventListener("touchend", (e) => {
      endX = e.changedTouches[0].clientX;

      if (startX > endX + 50) {
        next.click(); // Swipe left to move to next image
      } else if (startX < endX - 50) {
        prev.click(); // Swipe right to move to previous image
      }
    });
  });

  document.addEventListener("click", function (event) {
    let target = event.target.closest("#player-toolbar-left-actions > a");
    if (target) {
      event.preventDefault();
      let url = target.getAttribute("href") || target.dataset.href;
      if (url) window.open(url, "_blank", "noopener,noreferrer");
    }
  });

  document.addEventListener("click", function (event) {
    if (event.target.classList.contains("toggle-script")) {
      let container = event.target.closest(".script-container");
      let scriptWrapper = container.querySelector(".script-wrapper");
      let existingEmbed = scriptWrapper.querySelector(".toggle-github-embed");
      let scriptSrc = container.dataset.src;

      if (existingEmbed) {
        // Remove existing embed
        existingEmbed.remove();
        event.target.textContent = "Show script";
        console.log("Script removed");
      } else {
        // Create and insert a new embed
        let embedContainer = document.createElement("div");
        embedContainer.className = "toggle-github-embed";

        let newScript = document.createElement("script");
        newScript.src = scriptSrc;

        embedContainer.appendChild(newScript);
        scriptWrapper.appendChild(embedContainer);

        event.target.textContent = "Hide script";
        console.log("Script added");
      }
    }
  });

  // Fold code chunks

  document
    .querySelectorAll(
      `
    pre[class]:not(.emgithub-container pre),
    pre > code[class]:not(.emgithub-container code)
  `
    )
    .forEach((el) => {
      const d = document.createElement("details");
      const summary = document.createElement("summary");

      // Style the summary text
      summary.style.color = "darkgrey";
      summary.style.fontSize = "90%";
      summary.textContent = "Collapse";
      summary.style.fontWeight = "normal";
      d.open = true;

      d.addEventListener("toggle", () => {
        if (d.open) {
          summary.textContent = "Collapse";
          summary.style.fontWeight = "normal";
          summary.style.fontSize = "90%";
          summary.style.color = "darkgrey";
        } else {
          summary.textContent = "Expand";
          summary.style.fontWeight = "bold";
          summary.style.fontSize = "103%";
          summary.style.color = "#379E8A";
        }
      });

      const pre = el.tagName === "CODE" ? el.parentNode : el;
      d.appendChild(summary);
      pre.before(d);
      d.append(pre);
    });

  // Collapsible abstracts on home page - click to expand
  $(document).on(
    "click",
    "#publication .media-body .article-style, #applications-and-dashboards .media-body .article-style, #blog .media-body .article-style",
    function (e) {
      const $abstract = $(this);
      const $mediaBody = $abstract.closest(".media-body");

      // Check if already expanded
      if ($mediaBody.hasClass("is-expanded")) {
        return;
      }

      // Get the full height and expand
      const fullHeight = this.scrollHeight;
      $abstract.css({
        "max-height": fullHeight + "px",
        cursor: "default",
      });

      // Mark as expanded
      $mediaBody.addClass("is-expanded");

      // Add "View complete content" button after expansion
      const $title = $mediaBody.find(".article-title a");
      const pageUrl = $title.attr("href");

      if (pageUrl && !$abstract.next(".view-complete-content-btn").length) {
        const $viewCompleteContentBtn = $("<a>", {
          href: pageUrl,
          class: "view-complete-content-btn",
          html: '<i class="fas fa-plus"></i> View complete content',
        });

        $abstract.after($viewCompleteContentBtn);
      }
    }
  );

  // Document Viewer Controls
  $(document).ready(function () {
    // Zoom functionality for PDFs
    $(".doc-zoom-in, .doc-zoom-out").on("click", function (e) {
      e.preventDefault();
      const $toolbar = $(this).closest(".document-viewer-toolbar");
      const $iframe = $toolbar.siblings("iframe");
      const isPDF = $toolbar.data("is-pdf");

      if (isPDF && $iframe.length) {
        // For PDFs, try to manipulate the iframe content
        try {
          const iframeDoc =
            $iframe[0].contentDocument || $iframe[0].contentWindow.document;
          const currentZoom = parseFloat(iframeDoc.body.style.zoom || 1);
          const zoomDelta = $(this).hasClass("doc-zoom-in") ? 0.1 : -0.1;
          const newZoom = Math.max(0.5, Math.min(3, currentZoom + zoomDelta));
          iframeDoc.body.style.zoom = newZoom;
          console.log("Zoom level:", newZoom);
        } catch (err) {
          // Cross-origin restriction - open in new tab instead
          console.log("Cannot zoom embedded PDF, opening in new tab");
          const url = $toolbar.data("doc-url");
          window.open(url, "_blank");
        }
      }
    });

    // Print functionality
    $(".doc-print").on("click", function (e) {
      e.preventDefault();
      const $toolbar = $(this).closest(".document-viewer-toolbar");
      const $iframe = $toolbar.siblings("iframe");
      const docUrl = $toolbar.data("doc-url");

      // Try to print the iframe content
      try {
        if ($iframe.length && $iframe[0].contentWindow) {
          $iframe[0].contentWindow.print();
          console.log("Printing document");
        } else {
          throw new Error("Cannot access iframe");
        }
      } catch (err) {
        // If iframe print fails, open in new window for printing
        console.log("Cannot print embedded document, opening in new window");
        const printWindow = window.open(docUrl, "_blank");
        if (printWindow) {
          printWindow.onload = function () {
            printWindow.print();
          };
        }
      }
    });

    console.log("Document viewer controls initialized");
  });

  // Robust collapsible functionality - works with unlimited sections
  $(document).ready(function () {
    console.log("Setting up collapsible sections...");

    // Handle multimedia-summary click to expand (matches pub-abstract style)
    $(document).on("click", ".multimedia-summary", function (e) {
      const $summary = $(this);
      
      // Check if already expanded
      if ($summary.hasClass("is-expanded")) {
        return;
      }

      // Get the full height and expand
      const fullHeight = this.scrollHeight;
      $summary.css({
        "max-height": fullHeight + "px",
      });

      // Mark as expanded
      $summary.addClass("is-expanded");

      console.log("Multimedia summary expanded! Height:", fullHeight + "px");
    });

    console.log("Collapsible functionality ready");
  });

  // Initialize enhanced navigation highlighting
  document.addEventListener("DOMContentLoaded", function () {
    console.log("Initializing enhanced navigation highlighting...");
    if (typeof enhancedNavigationHighlighting === "function") {
      enhancedNavigationHighlighting();
    } else {
      console.warn("enhancedNavigationHighlighting function not found");
    }
  });
})(jQuery);
