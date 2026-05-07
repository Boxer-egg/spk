import XCTest

final class AudioTapOwnershipTests: XCTestCase {
    func testOnlySpeechManagerInstallsAudioInputTap() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let managersDirectory = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/spk/Managers", isDirectory: true)

        let managerFiles = try FileManager.default.contentsOfDirectory(
            at: managersDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "swift" && $0.lastPathComponent != "SpeechManager.swift" }

        for file in managerFiles {
            let source = try String(contentsOf: file)
            XCTAssertFalse(
                source.contains(".installTap(") || source.contains(" installTap("),
                "\(file.lastPathComponent) must consume audio buffers from SpeechManager instead of installing its own input tap."
            )
        }
    }
}
