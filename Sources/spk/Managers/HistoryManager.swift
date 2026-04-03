import Foundation

struct HistoryEntry: Codable {
    let id: UUID
    let timestamp: Date
    let originalText: String
    let refinedText: String?
    let audioFilename: String?

    init(originalText: String, refinedText: String?, audioFilename: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.originalText = originalText
        self.refinedText = refinedText
        self.audioFilename = audioFilename
    }
}

class HistoryManager {
    static let shared = HistoryManager()

    private let historyURL: URL
    private var entries: [HistoryEntry] = []
    private let maxEntries = 20

    private init() {
        // 配置文件路径：~/.config/spk/
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let configDir = homeURL.appendingPathComponent(".config/spk", isDirectory: true)
        self.historyURL = configDir.appendingPathComponent("history.json")

        // 确保目录存在
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true, attributes: nil)

        loadHistory()
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyURL.path) else {
            entries = []
            return
        }

        do {
            let data = try Data(contentsOf: historyURL)
            let decoded = try JSONDecoder().decode([HistoryEntry].self, from: data)
            entries = decoded.sorted { $0.timestamp > $1.timestamp } // 按时间倒序排列
        } catch {
            print("Failed to load history from \(historyURL.path): \(error)")
            entries = []
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: historyURL)
        } catch {
            print("Failed to save history to \(historyURL.path): \(error)")
        }
    }

    func addEntry(originalText: String, refinedText: String?, audioFilename: String? = nil) {
        guard SettingsManager.shared.isHistoryEnabled else { return }

        let entry = HistoryEntry(originalText: originalText, refinedText: refinedText, audioFilename: audioFilename)
        entries.insert(entry, at: 0) // 添加到开头（最新）

        // 限制条目数量
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveHistory()
    }

    func getEntries() -> [HistoryEntry] {
        return entries // 已经按时间倒序排列
    }

    func clearHistory() {
        entries = []
        saveHistory()
    }
}