import Foundation

enum Language: String, CaseIterable, Identifiable {
    case zhCN = "zh-CN"
    case enUS = "en-US"
    case zhTW = "zh-TW"
    case jaJP = "ja-JP"
    case koKR = "ko-KR"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .zhCN: return "简体中文"
        case .enUS: return "English"
        case .zhTW: return "繁体中文"
        case .jaJP: return "日本語"
        case .koKR: return "한국어"
        }
    }

    /// ISO 639-1 language code for WhisperKit.
    var whisperLanguageCode: String? {
        switch self {
        case .zhCN, .zhTW: return "zh"
        case .enUS: return "en"
        case .jaJP: return "ja"
        case .koKR: return "ko"
        }
    }
}
