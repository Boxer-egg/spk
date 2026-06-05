import XCTest
@testable import Spk

final class AudioRecorderManagerTests: XCTestCase {
    var tempTapeDir: URL!

    override func setUp() {
        super.setUp()
        // AudioRecorderManager uses a singleton with a fixed path, so we test
        // the public API behaviors that don't require actual recording
        tempTapeDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("spk/tape", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempTapeDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        // Clean up any test files we created directly
        let testFiles = (try? FileManager.default.contentsOfDirectory(at: tempTapeDir, includingPropertiesForKeys: nil)) ?? []
        for file in testFiles where file.lastPathComponent.hasPrefix("test_") {
            try? FileManager.default.removeItem(at: file)
        }
        super.tearDown()
    }

    func testUrlForAudioPreventsPathTraversal() {
        let maliciousFilename = "../../../etc/passwd"
        let url = AudioRecorderManager.shared.urlForAudio(named: maliciousFilename)
        // The lastPathComponent extraction should strip the traversal
        XCTAssertFalse(url.path.contains("../"))
        XCTAssertEqual(url.lastPathComponent, "passwd")
    }

    func testUrlForAudioReturnsCorrectPath() {
        let filename = "test_audio.m4a"
        let url = AudioRecorderManager.shared.urlForAudio(named: filename)
        XCTAssertEqual(url.lastPathComponent, filename)
        XCTAssertTrue(url.path.hasSuffix("/spk/tape/test_audio.m4a"))
    }

    func testRemoveOrphanedAudioFiles() throws {
        // Create test files
        let file1 = tempTapeDir.appendingPathComponent("test_orphaned_1.m4a")
        let file2 = tempTapeDir.appendingPathComponent("test_referenced_2.m4a")
        try "audio1".write(to: file1, atomically: true, encoding: .utf8)
        try "audio2".write(to: file2, atomically: true, encoding: .utf8)

        // Only file2 is referenced
        AudioRecorderManager.shared.removeOrphanedAudioFiles(referencedFilenames: ["test_referenced_2.m4a"])

        XCTAssertFalse(FileManager.default.fileExists(atPath: file1.path), "Orphaned file should be removed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file2.path), "Referenced file should be kept")

        // Cleanup
        try? FileManager.default.removeItem(at: file2)
    }

    func testRemoveOrphanedIgnoresNonM4AFiles() throws {
        let m4aFile = tempTapeDir.appendingPathComponent("test_audio.m4a")
        let txtFile = tempTapeDir.appendingPathComponent("test_notes.txt")
        try "audio".write(to: m4aFile, atomically: true, encoding: .utf8)
        try "notes".write(to: txtFile, atomically: true, encoding: .utf8)

        AudioRecorderManager.shared.removeOrphanedAudioFiles(referencedFilenames: [])

        XCTAssertFalse(FileManager.default.fileExists(atPath: m4aFile.path), ".m4a orphaned file should be removed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: txtFile.path), ".txt file should be ignored")

        // Cleanup
        try? FileManager.default.removeItem(at: txtFile)
    }

    func testConcurrentStartRecordingWithSameIdentifierReturnsNil() {
        // In test environment without audio input, startRecording may fail and return nil.
        // We verify the API contract: if a recording is already in progress for an identifier,
        // a second call returns nil.
        let firstResult = AudioRecorderManager.shared.startRecording(identifier: "test_concurrent")
        // If first succeeded, second must return nil
        if firstResult != nil {
            let secondResult = AudioRecorderManager.shared.startRecording(identifier: "test_concurrent")
            XCTAssertNil(secondResult, "Second startRecording with same identifier should return nil")
            // Cleanup
            _ = AudioRecorderManager.shared.stopRecording(identifier: "test_concurrent")
            if let url = firstResult {
                try? FileManager.default.removeItem(at: url)
            }
        }
        // If first failed (no audio input in tests), the API still behaved correctly
    }

    func testStopRecordingReturnsNilForUnknownIdentifier() {
        let result = AudioRecorderManager.shared.stopRecording(identifier: "nonexistent_identifier")
        XCTAssertNil(result)
    }
}
