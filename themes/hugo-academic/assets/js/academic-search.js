/*************************************************
 *  Academic
 *  https://github.com/gcushen/hugo-academic
 *
 *  In-built Fuse based search algorithm.
 **************************************************/

/* ---------------------------------------------------------------------------
 * Configuration.
 * --------------------------------------------------------------------------- */

// Configure Fuse.
let fuseOptions = {
  shouldSort: true,
  includeMatches: true,
  tokenize: true,
  threshold: 0.25, // Balanced matching
  location: 0,
  distance: 50, // Allow more distance flexibility
  maxPatternLength: 32,
  minMatchCharLength: search_config.minLength,
  findAllMatches: false, // Stop at first good match for better performance
  ignoreLocation: false, // Consider location in matching
  keys: [
    { name: "title", weight: 0.99 } /* 1.0 doesn't work o_O */,
    { name: "summary", weight: 0.6 },
    { name: "authors", weight: 0.5 },
    { name: "content", weight: 0.2 },
    { name: "tags", weight: 0.6 },
    { name: "categories", weight: 0.5 },
  ],
};

// Configure summary.
let summaryLength = 60;

/* ---------------------------------------------------------------------------
 * Functions.
 * --------------------------------------------------------------------------- */

// Get query from URI.
function getSearchQuery(name) {
  return decodeURIComponent(
    (location.search.split(name + "=")[1] || "").split("&")[0]
  ).replace(/\+/g, " ");
}

// Set query in URI without reloading the page.
function updateURL(url) {
  if (history.replaceState) {
    window.history.replaceState({ path: url }, "", url);
  }
}

// Pre-process new search query.
function initSearch(force, fuse) {
  let query = $("#search-query").val();

  // If query deleted or empty, clear results immediately and update URL.
  if (query.length < 1) {
    $("#search-hits").empty();
    // Remove query parameter from URL
    let cleanURL =
      window.location.protocol +
      "//" +
      window.location.host +
      window.location.pathname +
      window.location.hash;
    updateURL(cleanURL);
    return;
  }

  // Check for timer event (enter key not pressed) and query less than minimum length required.
  if (!force && query.length < fuseOptions.minMatchCharLength) {
    $("#search-hits").empty();
    return;
  }

  // Do search.
  $("#search-hits").empty();
  searchAcademic(query, fuse);

  // A query typed just before the overlay closed can still be searched
  // afterwards, when the index arrives, and by then toggleSearchDialog() has
  // taken the query out of the URL. Only an open overlay puts it back.
  if (!$("body").hasClass("searching")) {
    return;
  }
  let newURL =
    window.location.protocol +
    "//" +
    window.location.host +
    window.location.pathname +
    "?q=" +
    encodeURIComponent(query) +
    window.location.hash;
  updateURL(newURL);
}

// Perform search.
function searchAcademic(query, fuse) {
  let results = fuse.search(query);
  // console.log({"results": results});

  if (results.length > 0) {
    $("#search-hits").append(
      '<h3 class="mt-0">' + results.length + " " + i18n.results + "</h3>"
    );
    parseResults(query, results);
  } else {
    $("#search-hits").append(
      '<div class="search-no-results">' + i18n.no_results + "</div>"
    );
  }
}

// Parse search results.
function parseResults(query, results) {
  $.each(results, function (key, value) {
    let content_key = value.item.section;
    let content = "";
    let snippet = "";
    let snippetHighlights = [];

    // Show abstract in results for content types where the abstract is often the primary content.
    if (["publication", "presentation"].includes(content_key)) {
      content = value.item.summary;
    } else {
      content = value.item.content;
    }

    if (fuseOptions.tokenize) {
      snippetHighlights.push(query);
    } else {
      $.each(value.matches, function (matchKey, matchValue) {
        if (matchValue.key == "content") {
          let start =
            matchValue.indices[0][0] - summaryLength > 0
              ? matchValue.indices[0][0] - summaryLength
              : 0;
          let end =
            matchValue.indices[0][1] + summaryLength < content.length
              ? matchValue.indices[0][1] + summaryLength
              : content.length;
          snippet += content.substring(start, end);
          snippetHighlights.push(
            matchValue.value.substring(
              matchValue.indices[0][0],
              matchValue.indices[0][1] - matchValue.indices[0][0] + 1
            )
          );
        }
      });
    }

    if (snippet.length < 1) {
      snippet += value.item.summary; // Alternative fallback: `content.substring(0, summaryLength*2);`
    }

    // Load template.
    let template = $("#search-hit-fuse-template").html();

    // Localize content types.
    if (content_key in content_type) {
      content_key = content_type[content_key];
    }

    // Override type for home page sections.
    if (value.item.relpermalink && value.item.relpermalink.includes('/#')) {
      content_key = 'Section on home page';
    }

    // Replace hyphens with spaces in content type.
    content_key = content_key.replace(/-/g, ' ');

    // Parse template.
    let templateData = {
      key: key,
      title: value.item.title,
      type: content_key,
      relpermalink: value.item.relpermalink,
      snippet: snippet,
    };
    let output = render(template, templateData);
    $("#search-hits").append(output);

    // Highlight search terms in result.
    $.each(snippetHighlights, function (hlKey, hlValue) {
      $("#summary-" + key).mark(hlValue);
    });
  });
  
  // Add click handlers for search result links using event delegation
  $(document).off('click.searchresults').on('click.searchresults', '#search-hits a', function(e) {
    const href = $(this).attr('href');
    
    // Prevent default link behavior
    e.preventDefault();
    e.stopPropagation();
    
    // Extract hash from href
    let targetHash = null;
    let isTargetHomePage = false;
    
    try {
      const targetUrl = new URL(href, window.location.origin);
      if (targetUrl.hash) {
        targetHash = targetUrl.hash.substring(1);
      }
      isTargetHomePage = targetUrl.pathname === '/' || targetUrl.pathname === '/index.html' || targetUrl.pathname === '';
    } catch (err) {
      const hashMatch = href.match(/#(.+)$/);
      if (hashMatch) {
        targetHash = hashMatch[1];
      }
      isTargetHomePage = href.startsWith('/#') || href.startsWith('#');
    }
    
    const isCurrentlyHomePage = window.location.pathname === '/' || window.location.pathname === '/index.html';
    const isHomePageHashNav = targetHash && isTargetHomePage && isCurrentlyHomePage;
    
    // Close search by simulating Escape key press (this triggers toggleSearchDialog)
    $(document).trigger($.Event('keydown', { which: 27 }));
    
    // Navigate after search closes
    setTimeout(function() {
      if (isHomePageHashNav) {
        window.location.assign('/#' + targetHash);
      } else {
        window.location.href = href;
      }
    }, 150);
    
    return false;
  });
}

function render(template, data) {
  // Replace placeholders with their values.
  let key, find, re;
  for (key in data) {
    find = "\\{\\{\\s*" + key + "\\s*\\}\\}"; // Expect placeholder in the form `{{x}}`.
    re = new RegExp(find, "g");
    template = template.replace(re, data[key]);
  }
  return template;
}

/* ---------------------------------------------------------------------------
 * Initialize.
 * --------------------------------------------------------------------------- */

// If Academic's in-built search is enabled and Fuse loaded, then initialize it.
if (typeof Fuse === "function") {
  // The index is fetched when it is first needed rather than with every page:
  // when the overlay opens, when the page arrives with a query in its URL or
  // when a query is typed. getSearchIndex(), in layouts/partials/custom_head.html,
  // shares a single download with the other scripts that read the index.
  let fuse = null;
  let fuseRequest = null;

  const loadFuse = function () {
    if (!fuseRequest) {
      fuseRequest = getSearchIndex().then(function (search_index) {
        fuse = new Fuse(search_index, fuseOptions);
        return fuse;
      });
      // Forget a failed download, so that the next attempt makes a fresh one.
      fuseRequest.catch(function () {
        fuseRequest = null;
      });
    }
    return fuseRequest;
  };

  // A query typed while the index is still on its way is searched once it
  // arrives. Only the latest request is kept, since initSearch() reads the
  // query from the box at that point.
  let searchPending = false;
  let pendingForce = false;
  const search = function (force) {
    if (fuse) {
      initSearch(force, fuse);
      return;
    }
    pendingForce = force;
    if (searchPending) return;
    searchPending = true;
    loadFuse().then(
      function (fuse) {
        searchPending = false;
        initSearch(pendingForce, fuse);
      },
      function () {
        searchPending = false;
      }
    );
  };

  // Every control that opens the overlay adds the `searching` class to <body>
  // (see manageSearchOverlayFocus in academic.js), so watching for that class
  // starts the download whichever of them was used, before a key is typed.
  if (window.MutationObserver) {
    const overlayWatcher = new MutationObserver(function () {
      if (fuse) {
        overlayWatcher.disconnect();
      } else if (document.body.classList.contains("searching")) {
        loadFuse().catch(function () {});
      }
    });
    overlayWatcher.observe(document.body, { attributes: true, attributeFilter: ["class"] });
  }

  // On page load, check for search query in URL.
  const initialQuery = getSearchQuery("q");
  if (initialQuery) {
    loadFuse().then(function (fuse) {
      $("body").addClass("searching");
      $(".search-results")
        .css({ opacity: 0, visibility: "visible" })
        .animate({ opacity: 1 }, 200);
      $("#search-query").val(initialQuery);
      $("#search-query").focus();
      initSearch(true, fuse);
    }, function () {});
  }

  // On search box key up, process query.
  $("#search-query").keyup(function (e) {
    clearTimeout($.data(this, "searchTimer")); // Ensure only one timer runs!

    // Check if query is empty - clear immediately without timer
    let query = $(this).val();
    if (query.length < 1) {
      $("#search-hits").empty();
      return;
    }

    if (e.keyCode == 13) {
      search(true);
    } else {
      $(this).data(
        "searchTimer",
        setTimeout(function () {
          search(false);
        }, 250)
      );
    }
  });
}
