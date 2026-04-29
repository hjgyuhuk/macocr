---
name: macocr
description: Extract text from images using macOS Vision Framework OCR. Use when user needs to read text from screenshots, photos, scanned documents, or any image containing text, or mentions OCR, text extraction from images.
---

# macocr — macOS OCR Tool

Extract text from images using Apple's Vision Framework. Supports single files, batch processing, stdin image streams, base64 text input, and structured JSON output with bounding boxes.

## Quick start

```bash
# Extract text to stdout
macocr screenshot.png

# JSON output with bounding boxes
macocr -j screenshot.png

# Save text to file (creates screenshot.txt beside the image)
macocr -o screenshot.png

# Read binary image data from stdin
cat screenshot.png | macocr -

# Read base64 image data from stdin
cat screenshot.b64 | macocr --base64 -
```

## Options

| Flag | Description |
|------|-------------|
| `-o, --ocr` | Export OCR text to `<filename>.txt` beside each source file |
| `-j, --json` | Output JSON with text and bounding boxes |
| `--base64` | Decode each input as base64 text before OCR |
| `-v, --version` | Print version |
| `-h, --help` | Show help |

## Workflows

### Extract text from a single image
```bash
macocr image.png
```

### Batch process multiple images
```bash
# Prints extracted text from each file
macocr a.png b.png c.jpg

# JSON array output for all files
macocr -j a.png b.png c.jpg
```

### Save results to files
```bash
# Creates image.txt, doc.txt next to source files
macocr -o image.png doc.png
```

### Use OCR results in pipelines
```bash
# Pipe to other tools
macocr screenshot.png | grep "error"

# Save JSON for programmatic processing
macocr -j screenshot.png > result.json

# OCR binary image data from stdin
cat screenshot.png | macocr -

# OCR base64 text from stdin
cat screenshot.b64 | macocr --base64 -

# OCR a base64 text file
macocr --base64 screenshot.b64
```

## JSON Output Format

With `-j`, output is a JSON object for a single input and a JSON array for multiple inputs:
```json
{
  "file": "screenshot.png",
  "imageWidth": 1920,
  "imageHeight": 1080,
  "text": "Extracted text content\n",
  "boxes": [
    {
      "text": "Extracted text content",
      "x": 100.0,
      "y": 50.0,
      "w": 200.0,
      "h": 30.0
    }
  ]
}
```

For stdin input, the JSON `file` value is `"-"`.

## Supported Formats

Any image format supported by macOS Vision Framework:
- PNG, JPEG, TIFF, BMP, GIF
- HEIC/HEIF
- PDF (first page)

## Common Use Cases

- **Screenshot text extraction**: Capture text from error messages, UI elements
- **Document digitization**: Extract text from scanned documents or photos
- **Data entry automation**: Read text from forms, receipts, invoices
- **Accessibility**: Convert image-based text to machine-readable format
