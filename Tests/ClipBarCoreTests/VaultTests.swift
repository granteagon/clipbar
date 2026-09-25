import XCTest
import CryptoKit
import ClipBarCore
@testable import ClipBar

final class VaultTests: XCTestCase {
    func testEncryptedRoundTripAndDeletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.enc")
        let key = SymmetricKey(size: .bits256)
        let vault = Vault(url: url, keyProvider: { key })
        let clips = [Clip(text: "Private test phrase"), Clip(image: Data([1, 2, 3]))]
        try vault.save(clips)
        XCTAssertEqual(try vault.load(), clips)
        XCTAssertNil(try Data(contentsOf: url).range(of: Data("Private test phrase".utf8)))
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
        try vault.save([])
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try vault.load(), [])
    }
    func testTamperingIsRejected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.enc")
        let key = SymmetricKey(size: .bits256)
        let vault = Vault(url: url, keyProvider: { key })
        try vault.save([Clip(text: "test")])
        var bytes = try Data(contentsOf: url); bytes[bytes.count - 1] ^= 1
        try bytes.write(to: url)
        XCTAssertThrowsError(try vault.load())
    }
}
