import XCTest
@testable import Spk

final class PromptManagerTests: XCTestCase {
    var tempDir: URL!
    var bundle: Bundle!
    var manager: PromptManager!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        bundle = Bundle.module
        manager = PromptManager(userPromptsDir: tempDir, bundle: bundle)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testFallsBackToBundle() {
        let url = manager.promptURL(for: "planner.prompt")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("Prompts"))
    }

    func testPrefersUserDirectory() throws {
        let userPath = tempDir.appendingPathComponent("planner.prompt")
        try "user_override".write(to: userPath, atomically: true, encoding: .utf8)
        let url = manager.promptURL(for: "planner.prompt")
        XCTAssertNotNil(url)
        let content = try String(contentsOf: url!, encoding: .utf8)
        XCTAssertEqual(content, "user_override")
    }

    func testCopyBundledPrompt() {
        manager.copyBundledPromptToUserDirectory(path: "planner.prompt")
        let userPath = tempDir.appendingPathComponent("planner.prompt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: userPath.path))
    }
}
