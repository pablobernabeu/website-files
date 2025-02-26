

function initPDFViewer(containerId, pdfPath) {
    const container = document.getElementById(containerId);
    if (!container) {
        console.error(`Container with ID "${containerId}" not found.`);
        return;
    }

    // Create viewer elements dynamically
    container.innerHTML = `
        <div class="viewer-container" id="${containerId}-viewer">
            <canvas id="${containerId}-canvas"></canvas>
            <button class="nav-btn prev-btn" id="${containerId}-prev">&#10094;</button>
            <button class="nav-btn next-btn" id="${containerId}-next">&#10095;</button>
        </div>
        <div class="progress-bar"><div class="progress" id="${containerId}-progress"></div></div>
        <button class="fullscreen-btn" id="${containerId}-fullscreen">Enter Full Screen</button>
    `;

    let pdfDoc = null;
    let currentPage = 1;
    let totalPages = 1;
    const canvas = document.getElementById(`${containerId}-canvas`);
    const ctx = canvas.getContext('2d');
    const progressBar = document.getElementById(`${containerId}-progress`);

    // Load PDF
    pdfjsLib.getDocument(pdfPath).promise.then(pdf => {
        pdfDoc = pdf;
        totalPages = pdfDoc.numPages;
        renderPage(currentPage);
    });

    function renderPage(pageNum) {
        pdfDoc.getPage(pageNum).then(page => {
            const viewport = page.getViewport({ scale: 1.5 });
            canvas.width = viewport.width;
            canvas.height = viewport.height;
            const renderContext = { canvasContext: ctx, viewport: viewport };
            page.render(renderContext);
            updateProgress();
        });
    }

    function updateProgress() {
        let progress = (currentPage / totalPages) * 100;
        progressBar.style.width = progress + '%';
    }

    function nextPage() {
        if (currentPage < totalPages) {
            currentPage++;
            renderPage(currentPage);
        }
    }

    function prevPage() {
        if (currentPage > 1) {
            currentPage--;
            renderPage(currentPage);
        }
    }

    document.getElementById(`${containerId}-next`).addEventListener('click', nextPage);
    document.getElementById(`${containerId}-prev`).addEventListener('click', prevPage);

    document.addEventListener('keydown', function(event) {
        if (event.key === 'ArrowRight') nextPage();
        if (event.key === 'ArrowLeft') prevPage();
    });

    document.addEventListener('wheel', function(event) {
        event.preventDefault(); // Block vertical scrolling
    }, { passive: false });

    // Full-Screen Mode
    document.getElementById(`${containerId}-fullscreen`).addEventListener('click', function() {
        if (!document.fullscreenElement) {
            container.requestFullscreen();
            this.textContent = 'Exit Full Screen';
        } else {
            document.exitFullscreen();
            this.textContent = 'Enter Full Screen';
        }
    });

    // Swipe Gesture Support
    let hammertime = new Hammer(document.getElementById(`${containerId}-viewer`));
    hammertime.on('swipeleft', nextPage);
    hammertime.on('swiperight', prevPage);
}

