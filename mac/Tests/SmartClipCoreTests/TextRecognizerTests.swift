import AppKit
import XCTest
@testable import SmartClipCore

final class TextRecognizerTests: XCTestCase {
    /// Draws real text into a PNG, the way a screenshot of a document looks.
    private func renderPNG(_ text: String) throws -> Data {
        let size = NSSize(width: 900, height: 160)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        (text as NSString).draw(at: NSPoint(x: 30, y: 55), withAttributes: [
            .font: NSFont.systemFont(ofSize: 44, weight: .medium),
            .foregroundColor: NSColor.black,
        ])
        image.unlockFocus()
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        return try XCTUnwrap(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
    }

    func testReadsTextOutOfAnImage() throws {
        let png = try renderPNG("Invoice 48213 due Friday")
        let text = TextRecognizer.text(in: png)
        XCTAssertTrue(text.contains("48213"), "got: \(text)")
        XCTAssertTrue(text.lowercased().contains("invoice"), "got: \(text)")
    }

    func testAnImageWithNoTextGivesNothing() throws {
        let png = try renderPNG("")
        XCTAssertEqual(TextRecognizer.text(in: png), "")
    }

    func testGarbageDataDoesNotCrash() {
        XCTAssertEqual(TextRecognizer.text(in: Data("not an image".utf8)), "")
    }
}

final class ImageTextStoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("smartclip-ocr-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func testImageTextIsKeptInTheIndexAndStaysParseable() throws {
        let store = HistoryStore(dir: dir)
        let record = try store.append(data: Data("png".utf8), fileExtension: "png", type: "image",
                                      preview: "image 10×10 · 3 bytes", ocr: "Invoice \"48213\" due Friday")
        let line = record.jsonLine
        XCTAssertTrue(line.hasSuffix("\"preview\":\"image 10×10 · 3 bytes\"}"), "preview must stay last")
        XCTAssertEqual(ClipRecord.parse(line)?.ocr, "Invoice \"48213\" due Friday")
    }

    func testAScreenshotOfASecretIsNotKept() throws {
        let store = HistoryStore(dir: dir)
        let record = try store.append(data: Data("png".utf8), fileExtension: "png", type: "image",
                                      preview: "image", ocr: "Your token: ghp_0123456789abcdefghijklmnop")
        XCTAssertEqual(record.type, "redacted")
        XCTAssertEqual(record.file, "")
        XCTAssertEqual(record.ocr, "", "the secret text must not reach the index either")
        XCTAssertFalse(record.jsonLine.contains("ghp_"))
    }

    func testTextClipsDoNotCarryAnOcrField() throws {
        let record = try HistoryStore(dir: dir).append(content: "plain")
        XCTAssertFalse(record.jsonLine.contains("\"ocr\""))
    }
}
