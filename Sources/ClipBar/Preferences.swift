import Foundation
import CoreFoundation

final class Preferences {
    static let domain = "com.granteagon.ClipBar"
    static let defaults: [String: Any] = ["HistoryLimit": 50, "RetentionHours": 24, "PersistHistory": false, "ClearOnLock": true, "CaptureEnabled": true, "ExcludedBundleIDs": ["com.agilebits.onepassword7", "com.1password.1password", "com.bitwarden.desktop", "com.apple.Passwords"], "Shortcut": "command-backslash"]
    func value(_ key: String) -> Any { CFPreferencesCopyAppValue(key as CFString, Self.domain as CFString) ?? Self.defaults[key]! }
    func forced(_ key: String) -> Bool { CFPreferencesAppValueIsForced(key as CFString, Self.domain as CFString) }
    func set(_ key: String, _ value: Any) {
        guard !forced(key) else { return }
        CFPreferencesSetAppValue(key as CFString, value as CFPropertyList, Self.domain as CFString)
        CFPreferencesAppSynchronize(Self.domain as CFString)
    }
    func refresh() { CFPreferencesAppSynchronize(Self.domain as CFString) }
    func bool(_ key: String) -> Bool { (value(key) as? NSNumber)?.boolValue ?? (Self.defaults[key] as? Bool ?? false) }
    var limit: Int { max(1, min(500, (value("HistoryLimit") as? NSNumber)?.intValue ?? 50)) }
    var hours: Double { max(0, min(8760, (value("RetentionHours") as? NSNumber)?.doubleValue ?? 24)) }
    var excluded: [String] { value("ExcludedBundleIDs") as? [String] ?? Self.defaults["ExcludedBundleIDs"] as! [String] }
}
