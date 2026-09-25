import Foundation
import CryptoKit
import Security
import ClipBarCore

/// Optional encrypted persistence. No clipboard contents or keys go into preferences or logs.
final class Vault {
    private let url: URL
    private let suppliedKey: (() throws -> SymmetricKey)?
    init(url: URL? = nil, keyProvider: (() throws -> SymmetricKey)? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ClipBar/history.enc")
        self.suppliedKey = keyProvider
    }
    private let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Preferences.domain, kSecAttrAccount as String: "history-key"]
    private func key() throws -> SymmetricKey {
        if let suppliedKey { return try suppliedKey() }
        var q = query; q[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data { return SymmetricKey(data: data) }
        guard status == errSecItemNotFound else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        let key = SymmetricKey(size: .bits256)
        var add = query
        add[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let added = SecItemAdd(add as CFDictionary, nil)
        guard added == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(added)) }
        return key
    }
    func load() throws -> [Clip] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 48 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        let box = try AES.GCM.SealedBox(combined: Data(contentsOf: url))
        return try JSONDecoder().decode([Clip].self, from: AES.GCM.open(box, using: key()))
    }
    func save(_ items: [Clip]) throws {
        if items.isEmpty { try delete(); return }
        let data = try AES.GCM.seal(JSONEncoder().encode(items), using: key()).combined!
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    func delete() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
