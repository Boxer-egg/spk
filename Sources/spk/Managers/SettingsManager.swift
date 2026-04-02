import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    @Published var isLLMEnabled: Bool {
        didSet { defaults.set(isLLMEnabled, forKey: "isLLMEnabled") }
    }
    
    @Published var selectedLanguage: Language {
        didSet { defaults.set(selectedLanguage.rawValue, forKey: "selectedLanguage") }
    }
    
    @Published var apiBaseURL: String {
        didSet { defaults.set(apiBaseURL, forKey: "apiBaseURL") }
    }
    
    @Published var apiKey: String {
        didSet { defaults.set(apiKey, forKey: "apiKey") }
    }
    
    @Published var model: String {
        didSet { defaults.set(model, forKey: "model") }
    }
    
    @Published var systemPrompt: String {
        didSet { defaults.set(systemPrompt, forKey: "systemPrompt") }
    }
    
    @Published var isHoldToSpeak: Bool {
        didSet { defaults.set(isHoldToSpeak, forKey: "isHoldToSpeak") }
    }
    
    @Published var triggerKey: String {
        didSet { defaults.set(triggerKey, forKey: "triggerKey") }
    }

    @Published var isCopyToClipboardEnabled: Bool {
        didSet { defaults.set(isCopyToClipboardEnabled, forKey: "isCopyToClipboardEnabled") }
    }

    private init() {
        self.isLLMEnabled = defaults.bool(forKey: "isLLMEnabled")
        self.isCopyToClipboardEnabled = defaults.bool(forKey: "isCopyToClipboardEnabled")
        self.selectedLanguage = Language(rawValue: defaults.string(forKey: "selectedLanguage") ?? "zh-CN") ?? .zhCN
        self.apiBaseURL = defaults.string(forKey: "apiBaseURL") ?? "https://api.openai.com/v1"
        self.apiKey = defaults.string(forKey: "apiKey") ?? ""
        self.model = defaults.string(forKey: "model") ?? "gpt-3.5-turbo"
        self.systemPrompt = defaults.string(forKey: "systemPrompt") ?? "You are a speech recognition correction assistant. Your task is to correct obvious speech recognition errors in the input text. Do not rewrite or polish the content if it is already correct. Return ONLY the corrected text without any explanation or preamble."
        self.isHoldToSpeak = defaults.object(forKey: "isHoldToSpeak") as? Bool ?? true
        self.triggerKey = defaults.string(forKey: "triggerKey") ?? "Fn"
    }
}
