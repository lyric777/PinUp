import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String {
        rawValue
    }

    var localizationCode: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }

    var displayName: String {
        switch self {
        case .system:
            return L10n.tr("language_system")
        case .english:
            return L10n.tr("language_english")
        case .simplifiedChinese:
            return L10n.tr("language_simplified_chinese")
        }
    }
}

enum L10n {
    private static let appLanguageKey = "PinUp.AppLanguage"

    static var appLanguage: AppLanguage {
        get {
            guard
                let rawValue = UserDefaults.standard.string(forKey: appLanguageKey),
                let language = AppLanguage(rawValue: rawValue)
            else {
                return .system
            }

            return language
        }

        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: appLanguageKey)
        }
    }

    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localizedString(forKey: key)
        guard !arguments.isEmpty else {
            return format
        }

        return String(format: format, locale: Locale.current, arguments: arguments)
    }

    private static func localizedString(forKey key: String) -> String {
        guard
            let code = appLanguage.localizationCode,
            let path = Bundle.main.path(forResource: code, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return NSLocalizedString(key, comment: "")
        }

        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
