import Foundation
import Combine
import Yams

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let configURL: URL
    private let systemPromptURL: URL
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

    @Published var systemPrompt: String {
        didSet {
            saveSystemPrompt()
        }
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
        self.systemPromptURL = configDir.appendingPathComponent("system_prompt.txt")

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
            "systemPrompt",
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
        self.systemPrompt = Self.loadSystemPrompt(config: config, systemPromptURL: systemPromptURL)
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

        // 如果主配置中还有旧的 systemPrompt，将其移除并迁移到单独文件
        if config["systemPrompt"] != nil {
            config.removeValue(forKey: "systemPrompt")
        }

        // 保存初始配置
        saveConfig()
        saveSystemPrompt()
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

    private static func loadSystemPrompt(config: [String: Any], systemPromptURL: URL) -> String {
        let fileManager = FileManager.default
        let txtURL = systemPromptURL
        let yamlURL = systemPromptURL.deletingPathExtension().appendingPathExtension("yaml")

        // 首先尝试从 txt 文件加载
        if fileManager.fileExists(atPath: txtURL.path) {
            do {
                return try String(contentsOf: txtURL, encoding: .utf8)
            } catch {
                print("Failed to load system prompt from \(txtURL.path): \(error)")
            }
        }

        // 如果 txt 不存在，尝试从旧的 yaml 文件加载并迁移
        if fileManager.fileExists(atPath: yamlURL.path) {
            do {
                let yamlString = try String(contentsOf: yamlURL, encoding: .utf8)
                var prompt: String?

                // 尝试解析 YAML 格式
                if let loaded = try Yams.load(yaml: yamlString) as? [String: Any],
                   let yamlPrompt = loaded["prompt"] as? String {
                    prompt = yamlPrompt
                } else if let yamlPrompt = try Yams.load(yaml: yamlString) as? String {
                    // 如果文件直接包含字符串
                    prompt = yamlPrompt
                }

                if let prompt = prompt {
                    // 迁移到 txt 文件
                    try prompt.write(to: txtURL, atomically: true, encoding: .utf8)
                    // 删除旧的 yaml 文件
                    try fileManager.removeItem(at: yamlURL)
                    print("Migrated system prompt from YAML to TXT format")
                    return prompt
                }
            } catch {
                print("Failed to load or migrate system prompt from \(yamlURL.path): \(error)")
            }
        }

        // 如果单独文件不存在，检查主配置中是否有旧值（迁移）
        if let oldPrompt = config["systemPrompt"] as? String {
            // 迁移到单独文件（稍后在初始化完成后保存）
            // 注意：此时不能修改 config 字典，因为它是传入的副本
            // 我们将在初始化后处理迁移
            return oldPrompt
        }

        // 返回默认值
        return "You are a speech recognition correction assistant. Your task is to correct obvious speech recognition errors in the input text. Do not rewrite or polish the content if it is already correct. Return ONLY the corrected text without any explanation or preamble."
    }

    private func saveSystemPrompt() {
        do {
            try systemPrompt.write(to: systemPromptURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save system prompt to \(systemPromptURL.path): \(error)")
        }
    }
}