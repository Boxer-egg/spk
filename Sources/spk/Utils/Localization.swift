import Foundation

func localized(_ key: String) -> String {
    let bundle = Bundle.module
    let preferred = Locale.preferredLanguages
    let available = bundle.localizations
    let matched = Bundle.preferredLocalizations(from: available, forPreferences: preferred)
    let lang = matched.first ?? "en"

    if let path = bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: "\(lang).lproj"),
       let dict = NSDictionary(contentsOfFile: path) as? [String: String],
       let value = dict[key] {
        return value
    }

    return key
}
