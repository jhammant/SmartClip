import XCTest
@testable import SmartClipCore

final class HistoryStoreTests: XCTestCase {
    private var dir: URL!
    private var store: HistoryStore!

    override func setUpWithError() throws {
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("smartclip-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = HistoryStore(dir: dir, maxEntries: 5)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testAppendStoresContentAndReadsItBack() throws {
        let record = try store.append(content: "hello world", app: "Ghostty")
        XCTAssertEqual(record.app, "Ghostty")
        XCTAssertEqual(record.type, "text")
        XCTAssertEqual(record.bytes, 11)
        XCTAssertEqual(store.content(of: record), "hello world")
        XCTAssertEqual(store.recent().count, 1)
    }

    func testHistoryLineIsValidJSONWithPreviewLast() throws {
        let record = try store.append(content: "line one\nline two", app: "Mail")
        let line = try XCTUnwrap(try String(contentsOf: dir.appendingPathComponent("history.jsonl"),
                                            encoding: .utf8).split(separator: "\n").first.map(String.init))
        XCTAssertTrue(line.hasSuffix("\"preview\":\"line one line two\"}"), line)
        let parsed = try XCTUnwrap(ClipRecord.parse(line))
        XCTAssertEqual(parsed, record)
    }

    func testQuotesAndControlCharactersStayParseable() throws {
        let record = try store.append(content: "say \"hi\"\u{7} \\ done", app: "Slack")
        let parsed = try XCTUnwrap(ClipRecord.parse(record.jsonLine))
        XCTAssertEqual(parsed.preview, "say \"hi\" \\ done")
        XCTAssertEqual(store.content(of: record), "say \"hi\"\u{7} \\ done")
    }

    func testSecretsAreLoggedButNeverStored() throws {
        let record = try store.append(content: "ghp_abcdefghijklmnopqrstuvwxyz0123456789", app: "Chrome")
        XCTAssertEqual(record.type, "redacted")
        XCTAssertEqual(record.file, "")
        XCTAssertEqual(record.preview, "(redacted)")
        XCTAssertNil(store.content(of: record))
        XCTAssertFalse(record.jsonLine.contains("ghp_"))
    }

    func testOversizedClipsAreNotStored() throws {
        store = HistoryStore(dir: dir, maxEntries: 5, maxClipBytes: 16)
        let record = try store.append(content: String(repeating: "x", count: 64))
        XCTAssertEqual(record.type, "large")
        XCTAssertEqual(record.file, "")
    }

    func testPruningDropsOldestEntriesAndTheirClipFiles() throws {
        for i in 1...8 { try store.append(content: "clip \(i)") }
        let remaining = store.recent()
        XCTAssertEqual(remaining.count, 5)
        XCTAssertEqual(remaining.first?.preview, "clip 8")
        XCTAssertEqual(remaining.last?.preview, "clip 4")
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("clips").path)
        XCTAssertEqual(files.count, 5)
    }

    func testImagesAreStoredAsFilesAlongsideTheTextIndex() throws {
        let png = Data("not really a png, but bytes are bytes".utf8)
        let record = try store.append(data: png, fileExtension: "png", type: "image",
                                      preview: "image 120×80 · 36 bytes", app: "Screenshot")
        XCTAssertTrue(record.isImage)
        XCTAssertEqual(record.file, "clips/1.png")
        XCTAssertEqual(store.data(of: record), png)
        XCTAssertNil(store.content(of: record), "an image must not be read back as text")
        XCTAssertEqual(store.recent().first?.preview, "image 120×80 · 36 bytes")
    }

    func testOversizedImagesAreNotStored() throws {
        store = HistoryStore(dir: dir, maxBinaryBytes: 8)
        let record = try store.append(data: Data(repeating: 0, count: 64), fileExtension: "png",
                                      type: "image", preview: "image")
        XCTAssertEqual(record.type, "large")
        XCTAssertEqual(record.file, "")
        XCTAssertNil(store.fileURL(of: record))
    }

    func testBudgetEvictsOldestContentsButKeepsEveryHistoryLine() throws {
        store = HistoryStore(dir: dir, maxEntries: 0, budgetBytes: 100)
        var records: [ClipRecord] = []
        // Spaces matter: a 40-character run of unbroken alphanumerics would be
        // read as a credential and never stored, so nothing would be evicted.
        for i in 1...5 {
            records.append(try store.append(content: String(repeating: "clip \(i) ", count: 6)))
        }
        XCTAssertTrue(records.allSatisfy { !$0.file.isEmpty }, "all five must actually be stored")

        let lines = try String(contentsOf: dir.appendingPathComponent("history.jsonl"), encoding: .utf8)
            .split(separator: "\n")
        XCTAssertEqual(lines.count, 5, "the index is the archive — every copy stays listed")
        XCTAssertLessThanOrEqual(store.storedBytes(), 100)
        XCTAssertNil(store.fileURL(of: records[0]), "oldest contents evicted")
        XCTAssertNotNil(store.fileURL(of: records[4]), "newest contents kept")
    }

    func testNothingIsPrunedByDefault() throws {
        store = HistoryStore(dir: dir)
        for i in 1...50 { try store.append(content: "clip \(i)") }
        XCTAssertEqual(store.recent(1000).count, 50)
        XCTAssertNotNil(store.fileURL(of: store.recent(1000).last!))
    }

    func testRecentIsNewestFirst() throws {
        try store.append(content: "first")
        try store.append(content: "second")
        XCTAssertEqual(store.recent().map(\.preview), ["second", "first"])
        XCTAssertEqual(store.last()?.preview, "second")
    }
}

final class SecretFilterTests: XCTestCase {
    func testCredentialShapes() {
        XCTAssertTrue(SecretFilter.looksSecret("ghp_0123456789abcdefghij"))
        XCTAssertTrue(SecretFilter.looksSecret("export API_KEY=abc123"))
        XCTAssertTrue(SecretFilter.looksSecret("-----BEGIN RSA PRIVATE KEY-----"))
        XCTAssertTrue(SecretFilter.looksSecret("AKIAIOSFODNN7EXAMPLE"))
        XCTAssertTrue(SecretFilter.looksSecret(String(repeating: "a1B2", count: 12)))
    }

    func testLongFilePathsAreNotMistakenForTokens() {
        // 40+ characters of slashes, dots and letters — the same shape as an
        // opaque credential, but copying a path is completely ordinary.
        XCTAssertFalse(SecretFilter.looksSecret("/Users/jhammant/dev/utilities/SmartClip/README.md"))
        XCTAssertFalse(SecretFilter.looksSecret("~/Library/Application Support/SmartClip/clips/42.png"))
        XCTAssertTrue(SecretFilter.looksSecret("AKIAIOSFODNN7EXAMPLEAKIAIOSFODNN7EXAMPLE1234"))
    }

    func testLongSentencesWithoutPunctuationAreNotTokens() {
        // Regression: spaces used to be stripped before the "one opaque token"
        // check, so this ordinary sentence was redacted as a secret.
        XCTAssertFalse(SecretFilter.looksSecret("Thursday at ten works for me so see you then at the office Sam"))
    }

    func testOrdinaryTextIsKept() {
        XCTAssertFalse(SecretFilter.looksSecret("Hi Sam, that works for me — Thursday at 10?"))
        XCTAssertFalse(SecretFilter.looksSecret("https://github.com/jhammant/SmartClip/pull/12"))
        XCTAssertFalse(SecretFilter.looksSecret("func slugify(_ s: String) -> String { s.lowercased() }"))
    }

    func testTypeGuessing() {
        XCTAssertEqual(TypeGuess.of("https://example.com"), "url")
        XCTAssertEqual(TypeGuess.of("{\"a\":1}"), "json")
        XCTAssertEqual(TypeGuess.of("import Foundation\nlet x = 1"), "code")
        XCTAssertEqual(TypeGuess.of("just some prose"), "text")
    }
}
