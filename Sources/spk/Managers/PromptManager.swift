import Foundation

class PromptManager {
    static let shared = PromptManager()

    private let userPromptsDir: URL
    private let bundle: Bundle

    init(userPromptsDir: URL? = nil, bundle: Bundle = .main) {
        self.userPromptsDir = userPromptsDir ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/spk/prompts", isDirectory: true)
        self.bundle = bundle
    }

    func promptURL(for path: String) -> URL? {
        let userURL = userPromptsDir.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: userURL.path) {
            return userURL
        }
        if let url = bundle.url(forResource: path, withExtension: nil, subdirectory: "Prompts") {
            return url
        }
        if let url = bundle.url(forResource: path, withExtension: nil) {
            return url
        }
        return bundle.url(forResource: path, withExtension: nil, subdirectory: "TestResources/Prompts")
    }

    func loadPrompt(for path: String) -> String? {
        guard let url = promptURL(for: path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func ensureUserPromptsDirectory() {
        try? FileManager.default.createDirectory(at: userPromptsDir, withIntermediateDirectories: true)
    }

    func copyBundledPromptToUserDirectory(path: String) {
        let bundledURL: URL? = bundle.url(forResource: path, withExtension: nil, subdirectory: "Prompts")
            ?? bundle.url(forResource: path, withExtension: nil)
            ?? bundle.url(forResource: path, withExtension: nil, subdirectory: "TestResources/Prompts")
        guard let bundledURL = bundledURL else { return }
        let userURL = userPromptsDir.appendingPathComponent(path)
        let dir = userURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: userURL.path) {
            try? FileManager.default.copyItem(at: bundledURL, to: userURL)
        }
    }
}
