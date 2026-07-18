import Foundation

public enum SSHProxyL10n {
    public static func string(_ key: String, default defaultValue: String) -> String {
        Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
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
}
