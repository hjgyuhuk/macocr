# macocr

**macocr** is a lightweight, high-performance command-line utility for macOS that performs Optical Character Recognition (OCR) using Apple's native **Vision Framework**. 

It provides fast text extraction and bounding box data without needing third-party dependencies or internet access.

## Features

* **Native Performance:** Built on top of Apple's Vision Framework (`VNRecognizeTextRequest`).
* **Accurate Extraction:** Uses `Revision 3` of the Vision OCR engine for maximum accuracy.
* **Bounding Box Data:** Provides pixel-accurate coordinates (top-left origin) for every recognized text block.
* **Flexible Output:**
    * **Plain Text:** Stream extracted text directly to `stdout`.
    * **JSON:** Structured data including image dimensions, file paths, and bounding boxes.
    * **Batch Export:** Automatically save results as `.txt` files alongside your images.
* **Language Support:** Includes automatic language detection (on macOS 13.0+).

## Installation

### Prerequisites
* macOS 11.0 or later (macOS 13.0+ recommended for auto-language detection).
* Swift 5.x.

### Building from Source
1. Copy the code into a file named `main.swift`.
2. Compile using `swiftc`:
   ```bash
   swiftc -O main.swift -o macocr
   ```
3. Move to your path:
   ```bash
   chmod +x macocr
   sudo mv macocr /usr/local/bin/
   ```

## Usage

```bash
macocr [OPTIONS] <file> [<file> ...]
```

### Options
* `-o, --ocr`: Export OCR text to `<filename>.txt` beside each source file.
* `-j, --json`: Output OCR results as JSON (includes text and bounding boxes).
* `-v, --version`: Print version and exit.
* `-h, --help`: Show help.

### Examples

**1. Basic extraction to terminal:**
```bash
macocr receipt.png
```

**2. Extract structured data for a batch of images:**
```bash
macocr -j page1.jpg page2.jpg > results.json
```

**3. Process images and save text files automatically:**
```bash
macocr -o screenshot.png
# Creates screenshot.txt
```

## JSON Output Schema
When using the `--json` flag, the tool returns an object (for single files) or an array (for multiple files) with the following structure:

```json
{
  "file": "path/to/image.png",
  "imageWidth": 1920,
  "imageHeight": 1080,
  "text": "Extracted Text\nLine 2",
  "boxes": [
    {
      "text": "Extracted Text",
      "x": 100.5,
      "y": 200.0,
      "w": 50.2,
      "h": 15.0
    }
  ]
}
```
