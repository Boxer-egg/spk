import Foundation
import Combine
import Yams

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let configURL: URL
    private var config: [String: Any] = [:]

    @Published var isLLMEnabled: Bool {
        didSet {
            config["isLLMEnabled"] = isLLMEnabled
            saveConfig()
        }
    }

    @Published var selectedLanguage: Language {
        didSet {
            config["selectedLanguage"] = selectedLanguage.rawValue
            saveConfig()
        }
    }

    @Published var apiBaseURL: String {
        didSet {
            config["apiBaseURL"] = apiBaseURL
            saveConfig()
        }
    }

    @Published var apiKey: String {
        didSet {
            config["apiKey"] = apiKey
            saveConfig()
        }
    }

    @Published var model: String {
        didSet {
            config["model"] = model
            saveConfig()
        }
    }

    var defaultPastePromptPath: String {
        return "~/.config/spk/prompts/skills/default_paste.prompt"
    }

    @Published var isHoldToSpeak: Bool {
        didSet {
            config["isHoldToSpeak"] = isHoldToSpeak
            saveConfig()
        }
    }

    @Published var triggerKey: String {
        didSet {
            config["triggerKey"] = triggerKey
            saveConfig()
        }
    }

    @Published var isCopyToClipboardEnabled: Bool {
        didSet {
            config["isCopyToClipboardEnabled"] = isCopyToClipboardEnabled
            saveConfig()
        }
    }

    @Published var isHistoryEnabled: Bool {
        didSet {
            config["isHistoryEnabled"] = isHistoryEnabled
            saveConfig()
        }
    }

    @Published var isHistoryAudioEnabled: Bool {
        didSet {
            config["isHistoryAudioEnabled"] = isHistoryAudioEnabled
            saveConfig()
        }
    }

    @Published var selectedInputDeviceUID: String {
        didSet {
            config["selectedInputDeviceUID"] = selectedInputDeviceUID.isEmpty ? nil : selectedInputDeviceUID
            saveConfig()
        }
    }

    @Published var isAntiMisclickEnabled: Bool {
        didSet {
            config["isAntiMisclickEnabled"] = isAntiMisclickEnabled
            saveConfig()
        }
    }

    @Published var antiMisclickDelay: Double {
        didSet {
            config["antiMisclickDelay"] = antiMisclickDelay
            saveConfig()
        }
    }

    private init() {
        // 配置文件路径：~/.config/spk/
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let configDir = homeURL.appendingPathComponent(".config/spk", isDirectory: true)
        self.configURL = configDir.appendingPathComponent("config.yaml")

        // 确保目录存在
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true, attributes: nil)

        // 加载配置
        self.config = Self.loadConfig(from: configURL)

        // 迁移旧的 UserDefaults 配置（如果存在且 YAML 配置为空）
        let defaults = UserDefaults.standard
        let keysToMigrate = [
            "isLLMEnabled",
            "selectedLanguage",
            "apiBaseURL",
            "apiKey",
            "model",
            "isHoldToSpeak",
            "triggerKey",
            "isCopyToClipboardEnabled",
            "isHistoryEnabled",
            "isHistoryAudioEnabled",
            "selectedInputDeviceUID",
            "isAntiMisclickEnabled",
            "antiMisclickDelay"
        ]
        var migrated = false
        for key in keysToMigrate {
            if defaults.object(forKey: key) != nil && config[key] == nil {
                config[key] = defaults.object(forKey: key)
                migrated = true
            }
        }
        if migrated {
            // 注意：此时不能调用 saveConfig()，因为属性尚未初始化
            // 将在属性初始化后保存
        }

        // 设置默认值（如果配置中不存在）
        self.isLLMEnabled = (config["isLLMEnabled"] as? Bool) ?? false
        self.isCopyToClipboardEnabled = (config["isCopyToClipboardEnabled"] as? Bool) ?? false
        self.isHistoryEnabled = (config["isHistoryEnabled"] as? Bool) ?? true
        self.isHistoryAudioEnabled = (config["isHistoryAudioEnabled"] as? Bool) ?? false
        self.selectedLanguage = Language(rawValue: config["selectedLanguage"] as? String ?? "zh-CN") ?? .zhCN
        self.apiBaseURL = config["apiBaseURL"] as? String ?? "https://api.openai.com/v1"
        self.apiKey = config["apiKey"] as? String ?? ""
        self.model = config["model"] as? String ?? "gpt-3.5-turbo"
        self.isHoldToSpeak = config["isHoldToSpeak"] as? Bool ?? false
        self.triggerKey = config["triggerKey"] as? String ?? "Fn"
        self.selectedInputDeviceUID = config["selectedInputDeviceUID"] as? String ?? ""
        self.isAntiMisclickEnabled = (config["isAntiMisclickEnabled"] as? Bool) ?? true
        self.antiMisclickDelay = (config["antiMisclickDelay"] as? Double) ?? 0.25

        // 确保配置字典包含当前值（用于首次运行）
        config["isLLMEnabled"] = isLLMEnabled
        config["isCopyToClipboardEnabled"] = isCopyToClipboardEnabled
        config["isHistoryEnabled"] = isHistoryEnabled
        config["isHistoryAudioEnabled"] = isHistoryAudioEnabled
        config["selectedLanguage"] = selectedLanguage.rawValue
        config["apiBaseURL"] = apiBaseURL
        config["apiKey"] = apiKey
        config["model"] = model
        // systemPrompt 不再存储在主配置中
        config["isHoldToSpeak"] = isHoldToSpeak
        config["triggerKey"] = triggerKey
        config["selectedInputDeviceUID"] = selectedInputDeviceUID
        config["isAntiMisclickEnabled"] = isAntiMisclickEnabled
        config["antiMisclickDelay"] = antiMisclickDelay

        // 保存初始配置
        saveConfig()
    }

    private static func loadConfig(from url: URL) -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }

        do {
            let yamlString = try String(contentsOf: url, encoding: .utf8)
            if let loaded = try Yams.load(yaml: yamlString) as? [String: Any] {
                return loaded
            }
        } catch {
            print("Failed to load config from \(url.path): \(error)")
        }
        return [:]
    }

    private func saveConfig() {
        do {
            let yamlString = try Yams.dump(object: config)
            try yamlString.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save config to \(configURL.path): \(error)")
        }
    }
}