/*************************************************
 *  Academic
 *  https://github.com/gcushen/hugo-academic
 *
 *  Core JS functions and initialization.
 **************************************************/

(function ($) {

  /* ---------------------------------------------------------------------------
   * Responsive scrolling for URL hashes.
   * --------------------------------------------------------------------------- */

  // Dynamically get responsive navigation bar height for offsetting Scrollspy.
  function getNavBarHeight() {
    let $navbar = $('#navbar-main');
    let navbar_offset = $navbar.outerHeight();
    console.debug('Navbar height: ' + navbar_offset);
    return navbar_offset;
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
    target = (typeof target === 'undefined' || typeof target === 'object') ? decodeURIComponent(window.location.hash) : target;

    // If target element exists, scroll to it taking into account fixed navigation bar offset.
    if ($(target).length) {
      // Escape special chars from IDs, such as colons found in Markdown footnote links.
      target = '#' + $.escapeSelector(target.substring(1));  // Previously, `target = target.replace(/:/g, '\\:');`

      let elementOffset = Math.ceil($(target).offset().top - getNavBarHeight());  // Round up to highlight right ID!
      $('body').addClass('scrolling');
      $('html, body').animate({
        scrollTop: elementOffset
      }, 600, function () {
        $('body').removeClass('scrolling');
      });
    } else {
      console.debug('Cannot scroll to target `#' + target + '`. ID not found!');
    }
  }

  // Make Scrollspy responsive.
  function fixScrollspy() {
    let $body = $('body');
    let data = $body.data('bs.scrollspy');
    if (data) {
      data._config.offset = getNavBarHeight();
      $body.data('bs.scrollspy', data);
      $body.scrollspy('refresh');
    }
  }

  function removeQueryParamsFromUrl() {
    if (window.history.replaceState) {
      let urlWithoutSearchParams = window.location.protocol + "//" + window.location.host + window.location.pathname + window.location.hash;
      window.history.replaceState({path: urlWithoutSearchParams}, '', urlWithoutSearchParams);
    }
  }

  // Check for hash change event and fix responsive offset for hash links (e.g. Markdown footnotes).
  window.addEventListener("hashchange", scrollToAnchor);

  /* ---------------------------------------------------------------------------
   * Add smooth scrolling to all links inside the main navbar.
   * --------------------------------------------------------------------------- */

  $('#navbar-main li.nav-item a.nav-link').on('click', function (event) {
    // Store requested URL hash.
    let hash = this.hash;

    // If we are on a widget page and the navbar link is to a section on the same page.
    if (this.pathname === window.location.pathname && hash && $(hash).length && ($(".js-widget-page").length > 0)) {
      // Prevent default click behavior.
      event.preventDefault();

      // Use jQuery's animate() method for smooth page scrolling.
      // The numerical parameter specifies the time (ms) taken to scroll to the specified hash.
      let elementOffset = Math.ceil($(hash).offset().top - getNavBarHeight());  // Round up to highlight right ID!

      // Uncomment to debug.
      // let scrollTop = $(window).scrollTop();
      // let scrollDelta = (elementOffset - scrollTop);
      // console.debug('Scroll Delta: ' + scrollDelta);

      $('html, body').animate({
        scrollTop: elementOffset
      }, 800);
    }
  });

  /* ---------------------------------------------------------------------------
   * Hide mobile collapsable menu on clicking a link.
   * --------------------------------------------------------------------------- */

  $(document).on('click', '.navbar-collapse.show', function (e) {
    //get the <a> element that was clicked, even if the <span> element that is inside the <a> element is e.target
    let targetElement = $(e.target).is('a') ? $(e.target) : $(e.target).parent();

    if (targetElement.is('a') && targetElement.attr('class') != 'dropdown-toggle') {
      $(this).collapse('hide');
    }
  });

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
  let $grid_pubs = $('#container-publications');

  // Initialise Isotope.
  $grid_pubs.isotope({
    itemSelector: '.isotope-item',
    percentPosition: true,
    masonry: {
      // Use Bootstrap compatible grid layout.
      columnWidth: '.grid-sizer'
    },
    filter: function () {
      let $this = $(this);
      let searchResults = searchRegex ? $this.text().match(searchRegex) : true;
      let filterResults = filterValues ? $this.is(filterValues) : true;
      return searchResults && filterResults;
    }
  });

  // Filter by search term.
  let $quickSearch = $('.filter-search').keyup(debounce(function () {
    searchRegex = new RegExp($quickSearch.val(), 'gi');
    $grid_pubs.isotope();
  }));

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
    let value = '';
    for (let prop in obj) {
      value += obj[prop];
    }
    return value;
  }

  $('.pub-filters').on('change', function () {
    let $this = $(this);

    // Get group key.
    let filterGroup = $this[0].getAttribute('data-filter-group');

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
      if (url.substr(0, 9) == '.pubtype-') {
        window.location.hash = url.substr(9);
      } else {
        window.location.hash = '';
      }
    }
  });

  // Filter publications according to hash in URL.
  function filter_publications() {
    let urlHash = window.location.hash.replace('#', '');
    let filterValue = '*';

    // Check if hash is numeric.
    if (urlHash != '' && !isNaN(urlHash)) {
      filterValue = '.pubtype-' + urlHash;
    }

    // Set filter.
    let filterGroup = 'pubtype';
    pubFilters[filterGroup] = filterValue;
    filterValues = concatValues(pubFilters);

    // Activate filters.
    $grid_pubs.isotope();

    // Set selected option.
    $('.pubtype-select').val(filterValue);
  }

  /* ---------------------------------------------------------------------------
  * Google Maps or OpenStreetMap via Leaflet.
  * --------------------------------------------------------------------------- */

  function initMap() {
    if ($('#map').length) {
      let map_provider = $('#map-provider').val();
      let lat = $('#map-lat').val();
      let lng = $('#map-lng').val();
      let zoom = parseInt($('#map-zoom').val());
      let address = $('#map-dir').val();
      let api_key = $('#map-api-key').val();

      if (map_provider == 1) {
        let map = new GMaps({
          div: '#map',
          lat: lat,
          lng: lng,
          zoom: zoom,
          zoomControl: true,
          zoomControlOpt: {
            style: 'SMALL',
            position: 'TOP_LEFT'
          },
          panControl: false,
          streetViewControl: false,
          mapTypeControl: false,
          overviewMapControl: false,
          scrollwheel: true,
          draggable: true
        });

        map.addMarker({
          lat: lat,
          lng: lng,
          click: function (e) {
            let url = 'https://www.google.com/maps/place/' + encodeURIComponent(address) + '/@' + lat + ',' + lng + '/';
            window.open(url, '_blank')
          },
          title: address
        })
      } else {
        let map = new L.map('map').setView([lat, lng], zoom);
        if (map_provider == 3 && api_key.length) {
          L.tileLayer('https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token={accessToken}', {
            attribution: 'Map data &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="http://mapbox.com">Mapbox</a>',
            maxZoom: 18,
            id: 'mapbox.streets',
            accessToken: api_key
          }).addTo(map);
        } else {
          L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          }).addTo(map);
        }
        let marker = L.marker([lat, lng]).addTo(map);
        let url = lat + ',' + lng + '#map=' + zoom + '/' + lat + '/' + lng + '&layers=N';
        marker.bindPopup(address + '<p><a href="https://www.openstreetmap.org/directions?engine=osrm_car&route=' + url + '">Routing via OpenStreetMap</a></p>');
      }
    }
  }

  /* ---------------------------------------------------------------------------
   * GitHub API.
   * --------------------------------------------------------------------------- */

  function printLatestRelease(selector, repo) {
    $.getJSON('https://api.github.com/repos/' + repo + '/tags').done(function (json) {
      let release = json[0];
      $(selector).append(' ' + release.name);
    }).fail(function (jqxhr, textStatus, error) {
      let err = textStatus + ", " + error;
      console.log("Request Failed: " + err);
    });
  }

  /* ---------------------------------------------------------------------------
  * Toggle search dialog.
  * --------------------------------------------------------------------------- */

  function toggleSearchDialog() {
    if ($('body').hasClass('searching')) {
      // Clear search query and hide search modal.
      $('[id=search-query]').blur();
      $('body').removeClass('searching compensate-for-scrollbar');

      // Remove search query params from URL as user has finished searching.
      removeQueryParamsFromUrl();

      // Prevent fixed positioned elements (e.g. navbar) moving due to scrollbars.
      $('#fancybox-style-noscroll').remove();
    } else {
      // Prevent fixed positioned elements (e.g. navbar) moving due to scrollbars.
      if (!$('#fancybox-style-noscroll').length && document.body.scrollHeight > window.innerHeight) {
        $('head').append(
          '<style id="fancybox-style-noscroll">.compensate-for-scrollbar{margin-right:' +
          (window.innerWidth - document.documentElement.clientWidth) +
          'px;}</style>'
        );
        $('body').addClass('compensate-for-scrollbar');
      }

      // Show search modal.
      $('body').addClass('searching');
      $('.search-results').css({opacity: 0, visibility: 'visible'}).animate({opacity: 1}, 200);
      $('#search-query').focus();
    }
  }

  /* ---------------------------------------------------------------------------
  * Change Theme Mode (0: Day, 1: Night, 2: Auto).
  * --------------------------------------------------------------------------- */

  function canChangeTheme() {
    // If the theme changer component is present, then user is allowed to change the theme variation.
    return $('.js-dark-toggle').length;
  }

  function getThemeMode() {
    return parseInt(localStorage.getItem('dark_mode') || 2);
  }

  function changeThemeModeClick() {
    if (!canChangeTheme()) {
      return;
    }
    let $themeChanger = $('.js-dark-toggle i');
    let currentThemeMode = getThemeMode();
    let isDarkTheme;
    switch (currentThemeMode) {
      case 0:
        localStorage.setItem('dark_mode', '1');
        isDarkTheme = 1;
        console.info('User changed theme variation to Dark.');
        $themeChanger.removeClass('fa-moon fa-sun').addClass('fa-palette');
        break;
      case 1:
        localStorage.setItem('dark_mode', '2');
        if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
          // The visitor prefers dark themes and switching to the dark variation is allowed by admin.
          isDarkTheme = 1;
        } else if (window.matchMedia('(prefers-color-scheme: light)').matches) {
          // The visitor prefers light themes and switching to the dark variation is allowed by admin.
          isDarkTheme = 0;
        } else {
          isDarkTheme = isSiteThemeDark;  // Use the site's default theme variation based on `light` in the theme file.
        }
        console.info('User changed theme variation to Auto.');
        $themeChanger.removeClass('fa-moon fa-palette').addClass('fa-sun');
        break;
      default:
        localStorage.setItem('dark_mode', '0');
        isDarkTheme = 0;
        console.info('User changed theme variation to Light.');
        $themeChanger.removeClass('fa-sun fa-palette').addClass('fa-moon');
        break;
    }
    renderThemeVariation(isDarkTheme);
  }

  function getThemeVariation() {
    if (!canChangeTheme()) {
      return isSiteThemeDark;  // Use the site's default theme variation based on `light` in the theme file.
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
        if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
          // The visitor prefers dark themes and switching to the dark variation is allowed by admin.
          isDarkTheme = 1;
        } else if (window.matchMedia('(prefers-color-scheme: light)').matches) {
          // The visitor prefers light themes and switching to the dark variation is allowed by admin.
          isDarkTheme = 0;
        } else {
          isDarkTheme = isSiteThemeDark;  // Use the site's default theme variation based on `light` in the theme file.
        }
        break;
    }
    return isDarkTheme;
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
    const codeHlEnabled = $('link[title=hl-light]').length > 0;
    const codeHlLight = $('link[title=hl-light]')[0];
    const codeHlDark = $('link[title=hl-dark]')[0];
    const diagramEnabled = $('script[title=mermaid]').length > 0;

    // Check if re-render required.
    if (!init) {
      // If request to render light when light variation already rendered, return.
      // If request to render dark when dark variation already rendered, return.
      if ((isDarkTheme === 0 && !$('body').hasClass('dark')) || (isDarkTheme === 1 && $('body').hasClass('dark'))) {
        return;
      }
    }

    if (isDarkTheme === 0) {
      if (!init) {
        // Only fade in the page when changing the theme variation.
        $('body').css({opacity: 0, visibility: 'visible'}).animate({opacity: 1}, 500);
      }
      $('body').removeClass('dark');
      if (codeHlEnabled) {
        codeHlLight.disabled = false;
        codeHlDark.disabled = true;
      }
      if (diagramEnabled) {
        if (init) {
          mermaid.initialize({theme: 'default', securityLevel: 'loose'});
        } else {
          // Have to reload to re-initialise Mermaid with the new theme and re-parse the Mermaid code blocks.
          location.reload();
        }
      }
    } else if (isDarkTheme === 1) {
      if (!init) {
        // Only fade in the page when changing the theme variation.
        $('body').css({opacity: 0, visibility: 'visible'}).animate({opacity: 1}, 500);
      }
      $('body').addClass('dark');
      if (codeHlEnabled) {
        codeHlLight.disabled = true;
        codeHlDark.disabled = false;
      }
      if (diagramEnabled) {
        if (init) {
          mermaid.initialize({theme: 'dark', securityLevel: 'loose'});
        } else {
          // Have to reload to re-initialise Mermaid with the new theme and re-parse the Mermaid code blocks.
          location.reload();
        }
      }
    }
  }

  function initThemeVariation() {
    // If theme changer component present, set its icon according to the theme mode (day, night, or auto).
    if (canChangeTheme) {
      let themeMode = getThemeMode();
      let $themeChanger = $('.js-dark-toggle i');
      switch (themeMode) {
        case 0:
          $themeChanger.removeClass('fa-sun fa-palette').addClass('fa-moon');
          console.info('Initialize theme variation to Light.');
          break;
        case 1:
          $themeChanger.removeClass('fa-moon fa-sun').addClass('fa-palette');
          console.info('Initialize theme variation to Dark.');
          break;
        default:
          $themeChanger.removeClass('fa-moon fa-palette').addClass('fa-sun');
          console.info('Initialize theme variation to Auto.');
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
    $('.carousel').each(function () {
      // Get carousel slides.
      let items = $('.carousel-item', this);
      // Reset all slide heights.
      items.css('min-height', 0);
      // Normalize all slide heights.
      let maxHeight = Math.max.apply(null, items.map(function () {
        return $(this).outerHeight()
      }).get());
      items.css('min-height', maxHeight + 'px');
    })
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
    $('#TableOfContents').addClass('nav flex-column');
    $('#TableOfContents li').addClass('nav-item');
    $('#TableOfContents li a').addClass('nav-link');

    // Fix Goldmark task lists (remove bullet points).
    $("input[type='checkbox'][disabled]").parents('ul').addClass('task-list');
  }

  /**
   * Fix Mermaid.js clash with Highlight.js.
   * Refactor Mermaid code blocks as divs to prevent Highlight parsing them and enable Mermaid to parse them.
   */
  function fixMermaid() {
    let mermaids = [];
    [].push.apply(mermaids, document.getElementsByClassName('language-mermaid'));
    for (let i = 0; i < mermaids.length; i++) {
      $(mermaids[i]).unwrap('pre');  // Remove <pre> wrapper.
      $(mermaids[i]).replaceWith(function () {
        // Convert <code> block to <div> and add `mermaid` class so that Mermaid will parse it.
        return $("<div />").append($(this).contents()).addClass('mermaid');
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
    $('.js-dark-toggle').click(function (e) {
      e.preventDefault();
      changeThemeModeClick();
    });

    // Live update of day/night mode on system preferences update (no refresh required).
    // Note: since we listen only for *dark* events, we won't detect other scheme changes such as light to no-preference.
    const darkModeMediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    darkModeMediaQuery.addListener((e) => {
      if (!canChangeTheme()) {
        // Changing theme variation is not allowed by admin.
        return;
      }
      const darkModeOn = e.matches;
      console.log(`OS dark mode preference changed to ${darkModeOn ? '🌒 on' : '☀️ off'}.`);
      let currentThemeVariation = parseInt(localStorage.getItem('dark_mode') || 2);
      let isDarkTheme;
      if (currentThemeVariation === 2) {
        if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
          // The visitor prefers dark themes.
          isDarkTheme = 1;
        } else if (window.matchMedia('(prefers-color-scheme: light)').matches) {
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

  $(window).on('load', function () {
    // Filter projects.
    $('.projects-container').each(function (index, container) {
      let $container = $(container);
      let $section = $container.closest('section');
      let layout;
      if ($section.find('.isotope').hasClass('js-layout-row')) {
        layout = 'fitRows';
      } else {
        layout = 'masonry';
      }

      $container.imagesLoaded(function () {
        // Initialize Isotope after all images have loaded.
        $container.isotope({
          itemSelector: '.isotope-item',
          layoutMode: layout,
          masonry: {
            gutter: 20
          },
          filter: $section.find('.default-project-filter').text()
        });

        // Filter items when filter link is clicked.
        $section.find('.project-filters a').click(function () {
          let selector = $(this).attr('data-filter');
          $container.isotope({filter: selector});
          $(this).removeClass('active').addClass('active').siblings().removeClass('active all');
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
    if ($('.pub-filters-select')) {
      filter_publications();
      // Useful for changing hash manually (e.g. in development):
      // window.addEventListener('hashchange', filter_publications, false);
    }

    // Scroll to top of page.
    $('.back-to-top').click(function (event) {
      event.preventDefault();
      $('html, body').animate({
        'scrollTop': 0
      }, 800, function () {
        window.location.hash = "";
      });
    });

    // Load citation modal on 'Cite' click.
    $('.js-cite-modal').click(function (e) {
      e.preventDefault();
      let filename = $(this).attr('data-filename');
      let modal = $('#modal');
      modal.find('.modal-body code').load(filename, function (response, status, xhr) {
        if (status == 'error') {
          let msg = "Error: ";
          $('#modal-error').html(msg + xhr.status + " " + xhr.statusText);
        } else {
          $('.js-download-cite').attr('href', filename);
        }
      });
      modal.modal('show');
    });
    
    // Close modal on ESC key press
    $(document).keydown(function (e) {
      if (e.key === "Escape") { // Check if the ESC key is pressed
        $('#modal').modal('hide');
      }
    });

    // Copy citation text on 'Copy' click.
    $('.js-copy-cite').click(function (e) {
      e.preventDefault();
      // Get selection.
      let range = document.createRange();
      let code_node = document.querySelector('#modal .modal-body');
      range.selectNode(code_node);
      window.getSelection().addRange(range);
      try {
        // Execute the copy command.
        document.execCommand('copy');
      } catch (e) {
        console.log('Error: citation copy failed.');
      }
      // Remove selection.
      window.getSelection().removeRange(range);
    });

    // Initialise Google Maps if necessary.
    initMap();

    // Print latest version of GitHub projects.
    let githubReleaseSelector = '.js-github-release';
    if ($(githubReleaseSelector).length > 0)
      printLatestRelease(githubReleaseSelector, $(githubReleaseSelector).data('repo'));

    // On search icon click toggle search dialog.
    $('.js-search').click(function (e) {
      e.preventDefault();
      toggleSearchDialog();
    });
    $(document).on('keydown', function (e) {
      if (e.which == 27) {
        // `Esc` key pressed.
        if ($('body').hasClass('searching')) {
          toggleSearchDialog();
        }
      } else if (e.which == 191 && e.shiftKey == false && !$('input,textarea').is(':focus')) {
        // `/` key pressed outside of text input.
        e.preventDefault();
        toggleSearchDialog();
      }
    });

  });

  // Normalize Bootstrap carousel slide heights.
  $(window).on('load resize orientationchange', normalizeCarouselSlideHeights);

  // Automatic main menu dropdowns on mouse over.
  $('body').on('mouseenter mouseleave', '.dropdown', function (e) {
    var dropdown = $(e.target).closest('.dropdown');
    var menu = $('.dropdown-menu', dropdown);
    dropdown.addClass('show');
    menu.addClass('show');
    setTimeout(function () {
      dropdown[dropdown.is(':hover') ? 'addClass' : 'removeClass']('show');
      menu[dropdown.is(':hover') ? 'addClass' : 'removeClass']('show');
    }, 300);

    // Re-initialize Scrollspy with dynamic navbar height offset.
    fixScrollspy();

    if (window.location.hash) {
      // When accessing homepage from another page and `#top` hash is set, show top of page (no hash).
      if (window.location.hash == "#top") {
        window.location.hash = ""
      } else if (!$('.projects-container').length) {
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
  
  $(document).ready(function(){
    $('[data-toggle="tooltip1"]').tooltip();
  });
  
  
  // On scroll and only in desktop view, highlight section headings, tags in articles, bio info (name, title, email, socials), and the tag cloud at the bottom of the site. This work depends on CSS code in custom.scss, and JS code in academic.js.

  if (window.innerWidth > 1000) {
    document.addEventListener('DOMContentLoaded', function () {
      const sectionHeading = document.querySelectorAll('div.col-12.col-lg-4.section-heading');
      const sectionHeadingH1 = document.querySelectorAll('div.col-12.col-lg-4.section-heading > h1');
      const articleTags = document.querySelectorAll('div.article-container.pt-3 > div.btn-links.mb-3 > a:link');
      const citationButton = document.querySelectorAll('div.btn-links.mb-3 > button');
      const buttonH3 = document.querySelectorAll('button > h3');
      const portraitInfo = document.querySelectorAll('.portrait-title > h3');
      const icons = document.querySelectorAll('.social-icon');
      const cloudTags = document.querySelectorAll('.tag-cloud > a:link');
  
      function revealOnScroll(elements, delayFactor = 0) {
        const triggerBottom = window.innerHeight / 1.05;
        elements.forEach((el, index) => {
          const elTop = el.getBoundingClientRect().top;
          if (elTop < triggerBottom) {
            setTimeout(() => {
              el.classList.add('visible');
            }, index * delayFactor);
          }
        });
      }
  
      function checkElements() {
        revealOnScroll(sectionHeading);
        revealOnScroll(sectionHeadingH1);
        revealOnScroll(articleTags, 5);
        revealOnScroll(citationButton);
        revealOnScroll(buttonH3);
        revealOnScroll(portraitInfo, 30);
        revealOnScroll(icons, 90);
        revealOnScroll(cloudTags);
      }
  
      // Bind to scroll
      window.addEventListener('scroll', checkElements);
  
      // Also trigger on resize and when fragment identifiers change (e.g., #section)
      window.addEventListener('resize', checkElements);
      window.addEventListener('hashchange', () => {
        setTimeout(checkElements, 100);
      });
  
      // Ensure check runs after all content (e.g., images) is fully loaded
      window.addEventListener('load', () => {
        setTimeout(checkElements, 100);
      });
  
      // Initial check on DOM ready
      checkElements();
    });
  }
  
  
  // CARDS FOR IMAGES

  document.addEventListener("DOMContentLoaded", function () {
    const imageModal = document.getElementById('myModal');
    const images = document.querySelectorAll('.imageContainer img'); // Main article images
    const modalImageWrapper = document.querySelector('.imageModal-content-wrapper'); // Wrapper for modal images
    const prev = document.querySelector('.prev'); // Previous arrow
    const next = document.querySelector('.next'); // Next arrow
    const imageClose = document.querySelector('.imageClose'); // Close button
    let currentIndex = 0;
    let modalImages = [];

    // Function to create modal images only once
    function initializeModalImages() {
        if (modalImages.length === 0) { // Check if modal images are already initialized
            images.forEach((img, index) => {
                const modalImg = document.createElement('img');
                modalImg.src = img.src;
                modalImg.classList.add('imageModal-content');
                modalImg.style.display = 'none'; // Hide all modal images initially
                modalImageWrapper.appendChild(modalImg);
                modalImages.push(modalImg); // Push to modalImages array
            });
        }
    }

    // Function to display the clicked image in the modal
    function showImage(index) {
        currentIndex = index;
        modalImages.forEach((img) => {
            img.style.display = 'none'; // Hide all images
        });
        modalImages[currentIndex].style.display = 'block'; // Show the current image
    }

    // Open modal and display clicked image
    images.forEach((img, index) => {
        img.addEventListener('click', () => {
            initializeModalImages(); // Initialize the modal images only once
            imageModal.style.display = 'block'; // Show modal
            showImage(index); // Display the clicked image
        });
    });

    // Close modal
    imageClose.onclick = function () {
        imageModal.style.display = 'none';
    };

    // Close modal on ESC key
    window.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            imageModal.style.display = 'none';
        }
    });

    // Navigation for next and previous images
    next.onclick = function () {
        currentIndex = (currentIndex + 1) % modalImages.length; // Wrap around to first image
        showImage(currentIndex);
    };

    prev.onclick = function () {
        currentIndex = (currentIndex - 1 + modalImages.length) % modalImages.length; // Wrap around to last image
        showImage(currentIndex);
    };

    // Arrow key navigation
    window.addEventListener('keydown', (e) => {
        if (e.key === 'ArrowRight') {
            next.click();
        } else if (e.key === 'ArrowLeft') {
            prev.click();
        }
    });

    // Swipe gestures for mobile devices
    let startX = 0;
    let endX = 0;

    modalImageWrapper.addEventListener('touchstart', (e) => {
        startX = e.touches[0].clientX;
    });

    modalImageWrapper.addEventListener('touchend', (e) => {
        endX = e.changedTouches[0].clientX;

        if (startX > endX + 50) {
            next.click(); // Swipe left to move to next image
        } else if (startX < endX - 50) {
            prev.click(); // Swipe right to move to previous image
        }
    });
  });
  
  
  document.addEventListener('click', function (event) {
    let target = event.target.closest('#player-toolbar-left-actions > a');
    if (target) {
        event.preventDefault();
        let url = target.getAttribute('href') || target.dataset.href;
        if (url) window.open(url, '_blank', 'noopener,noreferrer');
    }
  });
  
  
  document.addEventListener('click', function (event) {
      if (event.target.classList.contains('toggle-script')) {
          let container = event.target.closest('.script-container');
          let scriptWrapper = container.querySelector('.script-wrapper');
          let existingEmbed = scriptWrapper.querySelector('.toggle-github-embed');
          let scriptSrc = container.dataset.src;

          if (existingEmbed) {
              // Remove existing embed
              existingEmbed.remove();
              event.target.textContent = "Show script";
              console.log("Script removed");
          } else {
              // Create and insert a new embed
              let embedContainer = document.createElement('div');
              embedContainer.className = "toggle-github-embed";

              let newScript = document.createElement('script');
              newScript.src = scriptSrc;

              embedContainer.appendChild(newScript);
              scriptWrapper.appendChild(embedContainer);

              event.target.textContent = "Hide script";
              console.log("Script added");
          }
      }
  });
  
  
  // Fold code chunks
  
  document.querySelectorAll(`
    pre[class]:not(.emgithub-container pre),
    pre > code[class]:not(.emgithub-container code)
  `).forEach(el => {
    const d = document.createElement('details');
    const summary = document.createElement('summary');
    
    // Style the summary text
    summary.style.color = 'darkgrey';
    summary.style.fontSize = '90%';
    summary.textContent = 'Hide';
    summary.style.fontWeight = 'normal';
    d.open = true;
  
    d.addEventListener('toggle', () => {
      if (d.open) {
        summary.textContent = 'Hide';
        summary.style.fontWeight = 'normal';
        summary.style.fontSize = '90%';
        summary.style.color = 'darkgrey';
      } else {
        summary.textContent = 'Show source code';
        summary.style.fontWeight = 'bold';
        summary.style.fontSize = '105%';
        summary.style.color = '#379E8A';
      }
    });
    
    const pre = el.tagName === 'CODE' ? el.parentNode : el;
    d.appendChild(summary);
    pre.before(d);
    d.append(pre);
  });


})(jQuery);

