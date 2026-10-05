import Foundation
import CoreFoundation

final class Preferences {
    static let domain = "com.granteagon.ClipBar"
    static let defaults: [String: Any] = ["PasteAutomatically": true, "ShowMenuBarIcon": true, "HistoryLimit": 50, "RetentionHours": 24, "PersistHistory": false, "ClearOnLock": true, "CaptureEnabled": true, "ExcludedBundleIDs": ["com.agilebits.onepassword7", "com.1password.1password", "com.bitwarden.desktop", "com.apple.Passwords"], "Shortcut": "command-backslash"]
    private let readValue: (String) -> Any?
    private let writeValue: (String, Any) -> Void
    private let isForced: (String) -> Bool
    private let synchronize: () -> Void
    init(read: @escaping (String) -> Any? = { CFPreferencesCopyAppValue($0 as CFString, Preferences.domain as CFString) },
         write: @escaping (String, Any) -> Void = {
             CFPreferencesSetAppValue($0 as CFString, $1 as CFPropertyList, Preferences.domain as CFString)
             CFPreferencesAppSynchronize(Preferences.domain as CFString)
         },
         forced: @escaping (String) -> Bool = { CFPreferencesAppValueIsForced($0 as CFString, Preferences.domain as CFString) },
         sync: @escaping () -> Void = { CFPreferencesAppSynchronize(Preferences.domain as CFString) }) {
        readValue = read; writeValue = write; isForced = forced; synchronize = sync
    }
    func value(_ key: String) -> Any { readValue(key) ?? Self.defaults[key]! }
    func forced(_ key: String) -> Bool { isForced(key) }
    func set(_ key: String, _ value: Any) {
        guard !forced(key) else { return }
        writeValue(key, value)
    }
    func refresh() { synchronize() }
    func bool(_ key: String) -> Bool { (value(key) as? NSNumber)?.boolValue ?? (Self.defaults[key] as? Bool ?? false) }
    var limit: Int { max(1, min(500, (value("HistoryLimit") as? NSNumber)?.intValue ?? 50)) }
    var hours: Double { max(0, min(8760, (value("RetentionHours") as? NSNumber)?.doubleValue ?? 24)) }
    var excluded: [String] { value("ExcludedBundleIDs") as? [String] ?? Self.defaults["ExcludedBundleIDs"] as! [String] }
}
