import Foundation

func localized(_ key: String) -> String {
    return Bundle.module.localizedString(forKey: key, value: key, table: nil)
}
