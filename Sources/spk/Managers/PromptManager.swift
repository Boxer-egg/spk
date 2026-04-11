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
        return bundle.url(forResource: path, withExtension: nil, subdirectory: "Prompts")
    }

    func loadPrompt(for path: String) -> String? {
        guard let url = promptURL(for: path) else { return nil }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            print("Error: failed to load prompt at \(url.path): \(error)")
            return nil
        }
    }

    func ensureUserPromptsDirectory() {
        do {
            try FileManager.default.createDirectory(at: userPromptsDir, withIntermediateDirectories: true)
        } catch {
            print("Error: failed to create prompts directory at \(userPromptsDir.path): \(error)")
        }
    }

    func copyBundledPromptToUserDirectory(path: String) {
        guard let bundledURL = bundle.url(forResource: path, withExtension: nil, subdirectory: "Prompts") else { return }
        let userURL = userPromptsDir.appendingPathComponent(path)
        let dir = userURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: userURL.path) {
            do {
                try FileManager.default.copyItem(at: bundledURL, to: userURL)
            } catch {
                print("Error: failed to copy bundled prompt to \(userURL.path): \(error)")
            }
        }
    }
}
