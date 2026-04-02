import Foundation

class SettingsManager {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    var apiBaseURL: String {
        get { defaults.string(forKey: "apiBaseURL") ?? "https://api.openai.com/v1" }
        set { defaults.set(newValue, forKey: "apiBaseURL") }
    }
    
    var apiKey: String {
        get { defaults.string(forKey: "apiKey") ?? "" }
        set { defaults.set(newValue, forKey: "apiKey") }
    }
    
    var model: String {
        get { defaults.string(forKey: "model") ?? "gpt-3.5-turbo" }
        set { defaults.set(newValue, forKey: "model") }
    }
    
    var systemPrompt: String {
        get { defaults.string(forKey: "systemPrompt") ?? "You are a speech recognition correction assistant. Your task is to correct obvious speech recognition errors in the input text. Do not rewrite or polish the content if it is already correct. Return ONLY the corrected text without any explanation or preamble." }
        set { defaults.set(newValue, forKey: "systemPrompt") }
    }
    
    var isLLMEnabled: Bool {
        get { defaults.bool(forKey: "isLLMEnabled") }
        set { defaults.set(newValue, forKey: "isLLMEnabled") }
    }
    
    var selectedLanguage: Language {
        get { Language(rawValue: defaults.string(forKey: "selectedLanguage") ?? "zh-CN") ?? .zhCN }
        set { defaults.set(newValue.rawValue, forKey: "selectedLanguage") }
    }
}
