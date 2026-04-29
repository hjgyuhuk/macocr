import Foundation
import Vision
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Version

let version = "1.1.0"

// MARK: - Data Models

struct OCRBox: Codable {
    let text: String
    let x: Double
    let y: Double
    let w: Double
    let h: Double
}

struct OCRResult {
    let text: String
    let imageWidth: Int
    let imageHeight: Int
    let boxes: [OCRBox]
}

// JSON output shape — supports single file and batch (array) mode
struct JSONOutput: Codable {
    let file: String
    let imageWidth: Int
    let imageHeight: Int
    let text: String
    let boxes: [OCRBox]
}

// MARK: - Core OCR

/// Returns true if the file at `path` is a recognized image format.
func isImage(_ path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
    guard let cfUTI = CGImageSourceGetType(source) else { return false }
    guard let utType = UTType(cfUTI as String) else { return false }
    return utType.conforms(to: .image)
}

/// Runs Vision OCR on image data and returns a structured result.
/// Returns nil if the data cannot be decoded as an image.
func performOCR(data: Data, label: String) -> OCRResult? {
    guard
        let source = CGImageSourceCreateWithData(data as CFData, nil),
        let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        fputs("warning: cannot decode image '\(label)'\n", stderr)
        return nil
    }

    let imageWidth  = cgImage.width
    let imageHeight = cgImage.height

    var resultText = ""
    var boxes: [OCRBox] = []

    let request = VNRecognizeTextRequest { req, _ in
        guard let observations = req.results as? [VNRecognizedTextObservation] else { return }

        for obs in observations {
            guard let top = obs.topCandidates(1).first else { continue }
            let text = top.string
            resultText += text + "\n"

            // Vision uses bottom-left origin, normalized coords → convert to
            // top-left pixel coords that match what image editors expect.
            let bb = obs.boundingBox
            let x = bb.minX * Double(imageWidth)
            let y = (1.0 - bb.maxY) * Double(imageHeight)
            let w = bb.width  * Double(imageWidth)
            let h = bb.height * Double(imageHeight)

            boxes.append(OCRBox(text: text, x: x, y: y, w: w, h: h))
        }
    }

    request.revision            = VNRecognizeTextRequestRevision3
    request.recognitionLevel    = .accurate
    request.usesLanguageCorrection = true
    if #available(macOS 13.0, *) {
        request.automaticallyDetectsLanguage = true
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try? handler.perform([request])

    return OCRResult(text: resultText, imageWidth: imageWidth, imageHeight: imageHeight, boxes: boxes)
}

/// Runs Vision OCR on the image at `path` and returns a structured result.
/// Returns nil if the file cannot be read or decoded.
func performOCR(_ path: String) -> OCRResult? {
    guard let data = FileManager.default.contents(atPath: path) else {
        fputs("warning: cannot read file '\(path)'\n", stderr)
        return nil
    }
    return performOCR(data: data, label: path)
}

// MARK: - Helpers

func writeTextFile(_ text: String, to path: String) throws {
    try text.write(toFile: path, atomically: true, encoding: .utf8)
}

func fileStem(_ path: String) -> String {
    URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
}

func toJSONString<T: Encodable>(_ value: T, pretty: Bool = true) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = pretty ? [.prettyPrinted, .withoutEscapingSlashes] : [.withoutEscapingSlashes]
    guard let data = try? encoder.encode(value) else { return "{}" }
    return String(data: data, encoding: .utf8) ?? "{}"
}

func readStdin() -> Data {
    FileHandle.standardInput.readDataToEndOfFile()
}

func decodeBase64(_ data: Data, label: String) -> Data? {
    guard let decoded = Data(base64Encoded: data, options: [.ignoreUnknownCharacters]) else {
        fputs("warning: cannot decode base64 input '\(label)'\n", stderr)
        return nil
    }
    return decoded
}

func loadInputData(path: String, base64: Bool) -> Data? {
    let raw: Data
    if path == "-" {
        raw = readStdin()
    } else {
        guard let fileData = FileManager.default.contents(atPath: path) else {
            fputs("warning: cannot read file '\(path)'\n", stderr)
            return nil
        }
        raw = fileData
    }

    return base64 ? decodeBase64(raw, label: path) : raw
}

// MARK: - Argument Parsing

struct Args {
    enum Mode { case print, export, json }
    var mode: Mode = .print
    var base64: Bool = false
    var files: [String] = []
}

func parseArgs() -> Args {
    var result = Args()
    var raw = CommandLine.arguments.dropFirst()

    while let arg = raw.first {
        raw = raw.dropFirst()
        switch arg {
        case "-o", "--ocr":
            result.mode = .export
        case "-j", "--json":
            result.mode = .json
        case "--base64":
            result.base64 = true
        case "-v", "--version":
            print("macocr v\(version)")
            exit(0)
        case "-h", "--help":
            printHelp()
            exit(0)
        default:
            if arg != "-" && arg.hasPrefix("-") {
                fputs("unknown option: \(arg)\n", stderr)
                exit(1)
            }
            result.files.append(arg)
        }
    }

    return result
}

func printHelp() {
    print("""
    macocr v\(version) — macOS OCR via Vision Framework

    USAGE
        macocr [OPTIONS] <file|-> [<file> ...]

    OPTIONS
        -o, --ocr       Export OCR text to <filename>.txt beside each source file
        -j, --json      Output OCR results as JSON (text + bounding boxes)
        --base64        Decode each input as base64 text before OCR
        -v, --version   Print version and exit
        -h, --help      Show this help

    EXAMPLES
        # Print extracted text to stdout
        macocr screenshot.png

        # Output JSON with bounding boxes
        macocr -j screenshot.png

        # Batch JSON (outputs a JSON array)
        macocr -j a.png b.png

        # Read binary image data from stdin
        cat screenshot.png | macocr -

        # Read base64 image data from stdin
        cat screenshot.b64 | macocr --base64 -

        # Write screenshot.txt next to the image
        macocr -o screenshot.png
    """)
}

// MARK: - Entry Point

let args = parseArgs()

guard !args.files.isEmpty else {
    fputs("error: no input files specified  (try --help)\n", stderr)
    exit(1)
}

if args.files.filter({ $0 == "-" }).count > 1 {
    fputs("error: stdin input '-' can only be used once\n", stderr)
    exit(1)
}

switch args.mode {

case .print:
    for path in args.files {
        guard path == "-" || args.base64 || isImage(path) else { continue }
        guard let data = loadInputData(path: path, base64: args.base64) else { continue }
        if let result = performOCR(data: data, label: path) {
            print(result.text, terminator: "")
        }
    }

case .json:
    var outputs: [JSONOutput] = []
    for path in args.files {
        guard path == "-" || args.base64 || isImage(path) else {
            fputs("skipping '\(path)': not a recognised image\n", stderr)
            continue
        }
        guard let data = loadInputData(path: path, base64: args.base64) else { continue }
        guard let result = performOCR(data: data, label: path) else { continue }
        outputs.append(JSONOutput(
            file: path,
            imageWidth: result.imageWidth,
            imageHeight: result.imageHeight,
            text: result.text,
            boxes: result.boxes
        ))
    }
    // Single file → plain object; multiple files → array
    if outputs.count == 1 {
        print(toJSONString(outputs[0]))
    } else {
        print(toJSONString(outputs))
    }

case .export:
    for path in args.files {
        guard path != "-" else {
            fputs("skipping '-': cannot export stdin input beside a source file\n", stderr)
            continue
        }
        guard args.base64 || isImage(path) else {
            fputs("skipping '\(path)': not a recognised image\n", stderr)
            continue
        }
        guard let data = loadInputData(path: path, base64: args.base64) else { continue }
        guard let result = performOCR(data: data, label: path) else { continue }

        let dir     = URL(fileURLWithPath: path).deletingLastPathComponent().path
        let outPath = (dir as NSString).appendingPathComponent(fileStem(path) + ".txt")

        do {
            try writeTextFile(result.text, to: outPath)
            print("\(path) --> \(outPath)")
        } catch {
            fputs("error writing '\(outPath)': \(error.localizedDescription)\n", stderr)
        }
    }
}
