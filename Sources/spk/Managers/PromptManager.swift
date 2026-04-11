import Foundation

class PromptManager {
    static let shared = PromptManager()

    private let userPromptsDir: URL
    private let bundle: Bundle

    init(userPromptsDir: URL? = nil, bundle: Bundle = .module) {
        self.userPromptsDir =
            userPromptsDir
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/spk/prompts", isDirectory: true)
        self.bundle = bundle
    }

    func promptURL(for path: String) -> URL? {
        let userURL = userPromptsDir.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: userURL.path) {
            return userURL
        }
        return bundledURL(for: path)
    }

    private func bundledURL(for path: String) -> URL? {
        print("[PromptManager] Searching for bundled resource: \(path)")

        // 1. Try standard bundle lookup (works for SPM and standard app bundles)
        if let url = bundle.url(forResource: path, withExtension: nil, subdirectory: "Prompts") {
            print("[PromptManager] Found in bundle (Prompts/): \(url.path)")
            return url
        }

        let components = path.components(separatedBy: "/")
        if components.count > 1 {
            let fileName = components.last!
            let subDir = "Prompts/" + components.dropLast().joined(separator: "/")
            if let url = bundle.url(forResource: fileName, withExtension: nil, subdirectory: subDir)
            {
                print("[PromptManager] Found in bundle (\(subDir)): \(url.path)")
                return url
            }
        }

        // 2. Direct filesystem fallback for manual .app bundles
        if let resourceURL = Bundle.main.resourceURL {
            let directURL = resourceURL.appendingPathComponent("Prompts").appendingPathComponent(
                path)
            if FileManager.default.fileExists(atPath: directURL.path) {
                print("[PromptManager] Found via direct resource path: \(directURL.path)")
                return directURL
            } else {
                print("[PromptManager] Not found at direct path: \(directURL.path)")
            }
        }

        print("[PromptManager] FAILED to find resource: \(path)")
        return nil
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
            try FileManager.default.createDirectory(
                at: userPromptsDir, withIntermediateDirectories: true)
        } catch {
            print("Error: failed to create prompts directory at \(userPromptsDir.path): \(error)")
        }
    }

    func copyBundledPromptToUserDirectory(path: String) {
        guard let bundledURL = bundledURL(for: path) else { return }
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
