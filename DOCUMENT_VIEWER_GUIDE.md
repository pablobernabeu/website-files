# Document Viewer Usage Guide

## Overview

A document viewer shortcode has been added to your Hugo Academic website that allows you to embed and view PDF and Word documents directly on your pages.

## Supported File Types

- **PDF**: `.pdf`
- **Word Documents**: `.doc`, `.docx`

## Usage

### Basic Usage

To embed a document viewer in any Markdown file (blog posts, publications, pages, etc.), use the shortcode:

```markdown
{{< document-viewer url="/path/to/your/document.pdf" >}}
```

### With Custom Height

You can specify a custom height for the viewer:

```markdown
{{< document-viewer url="/path/to/document.pdf" height="800px" >}}
```

### With Custom Title

Add a custom title for accessibility:

```markdown
{{< document-viewer url="/path/to/document.docx" height="600px" title="Research Paper" >}}
```

## Examples

### Embedding a PDF from your static folder:

```markdown
{{< document-viewer url="/pdf/my-research-paper.pdf" height="700px" >}}
```

### Embedding a Word document:

```markdown
{{< document-viewer url="/documents/report.docx" height="600px" >}}
```

### Embedding an external PDF:

```markdown
{{< document-viewer url="https://example.com/path/to/document.pdf" >}}
```

## Features

1. **Native PDF Viewing**: PDFs are displayed using the browser's built-in PDF viewer
2. **Word Document Support**: Word documents are rendered using Microsoft Office Online Viewer
3. **Download Button**: A floating download button appears in the top-right corner
4. **Responsive**: The viewer adapts to different screen sizes
5. **Dark Theme Support**: Styling adjusts automatically for dark mode
6. **Lazy Loading**: Documents only load when needed to improve page performance
7. **Fallback Options**: If a browser doesn't support embedded viewing, a download link is provided

## File Location

Place your documents in:
- `static/pdf/` for PDFs
- `static/documents/` for Word documents
- Or any other folder under `static/`

Then reference them with `/folder-name/filename.ext`

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `url` | Yes | - | Path or URL to the document |
| `height` | No | `600px` | Height of the viewer container |
| `title` | No | `"Document Viewer"` | Title for accessibility |

## Styling

The document viewer includes:
- Rounded borders with shadow effects
- Hover effects for better interactivity
- A circular download button that scales on hover
- Full dark theme compatibility

## Troubleshooting

### Word Documents Not Loading

Word documents require:
1. The document must be publicly accessible (hosted on your site or external URL)
2. Microsoft Office Online Viewer needs to be able to access it
3. For local development, Word documents may not work - they need to be on a public URL

### PDF Not Displaying

- Check that the file path is correct
- Ensure the PDF exists in your `static/` folder
- Try opening the PDF URL directly in your browser

## Technical Details

- **PDF Viewer**: Uses browser's native `<iframe>` PDF rendering
- **Word Viewer**: Uses Microsoft's Office Online Viewer API
- **Shortcode Location**: `layouts/shortcodes/document-viewer.html`
- **CSS Styles**: Located in `themes/hugo-academic/assets/scss/custom.scss`
