import Foundation

public enum SSHProxyL10n {
    public static let languageDefaultsKey = "SSHProxyTray.language"

    public static func string(_ key: String, default defaultValue: String) -> String {
        localizedBundle.localizedString(forKey: key, value: defaultValue, table: nil)
    }

    public static func format(
        _ key: String,
        default defaultValue: String,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: string(key, default: defaultValue),
            locale: Locale.current,
            arguments: arguments
        )
    }

    private static var localizedBundle: Bundle {
        guard let language = UserDefaults.standard.string(forKey: languageDefaultsKey),
              language != "system",
              let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
