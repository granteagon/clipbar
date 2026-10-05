import XCTest
import AppKit
import ClipBarCore
@testable import ClipBar

final class PrivacyTests: XCTestCase {
    func testEverySecretMarkerBlocksCaptureIncludingMixedRepresentations() {
        for marker in CapturePolicy.concealedTypes {
            XCTAssertFalse(CapturePolicy.allows(types: ["public.utf8-plain-text", marker], sourceBundleID: nil,
                                               excluded: [], enabled: true, paused: false, locked: false))
        }
    }
    func testPrivacyControlsAndExcludedSources() {
        for (enabled, paused, locked) in [(false, false, false), (true, true, false), (true, false, true)] {
            XCTAssertFalse(CapturePolicy.allows(types: [], sourceBundleID: nil, excluded: [], enabled: enabled, paused: paused, locked: locked))
        }
        XCTAssertFalse(CapturePolicy.allows(types: [], sourceBundleID: "password.app", excluded: ["password.app"], enabled: true, paused: false, locked: false))
        XCTAssertTrue(CapturePolicy.allows(types: ["public.png"], sourceBundleID: "editor.app", excluded: ["password.app"], enabled: true, paused: false, locked: false))
    }
    func testDefaultsAndMalformedManagedValues() {
        let defaults = Preferences(read: { _ in nil }, write: { _, _ in }, forced: { _ in false }, sync: {})
        XCTAssertEqual(defaults.limit, 50); XCTAssertEqual(defaults.hours, 24)
        XCTAssertFalse(defaults.bool("PersistHistory")); XCTAssertTrue(defaults.bool("ClearOnLock"))
        let malformed = Preferences(read: { _ in "invalid" }, write: { _, _ in }, forced: { _ in false }, sync: {})
        XCTAssertEqual(malformed.limit, 50); XCTAssertEqual(malformed.hours, 24)
        XCTAssertFalse(malformed.bool("PersistHistory"))
    }
    func testManagedWriteProtectionAndBounds() {
        var values: [String: Any] = ["HistoryLimit": 9999, "RetentionHours": -10]
        let prefs = Preferences(read: { values[$0] }, write: { values[$0] = $1 }, forced: { $0 == "PersistHistory" }, sync: {})
        prefs.set("PersistHistory", true)
        XCTAssertNil(values["PersistHistory"])
        XCTAssertEqual(prefs.limit, 500); XCTAssertEqual(prefs.hours, 0)
        prefs.set("HistoryLimit", -1); XCTAssertEqual(prefs.limit, 1)
        prefs.set("RetentionHours", 99999); XCTAssertEqual(prefs.hours, 8760)
    }
    func testCopyWritesOnlyToInjectedPasteboard() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let prefs = Preferences(read: { _ in nil }, write: { _, _ in }, forced: { _ in false }, sync: {})
        let store = Store(prefs: prefs, pasteboard: board, monitor: false)
        store.copy(Clip(text: "test text"))
        XCTAssertEqual(board.string(forType: .string), "test text")
        let png = Data([137, 80, 78, 71, 13, 10, 26, 10])
        store.copy(Clip(image: png))
        XCTAssertEqual(board.data(forType: .png), png)
        XCTAssertNil(board.string(forType: .string))
        store.clearClipboard(); XCTAssertTrue(board.pasteboardItems?.isEmpty ?? true)
    }
}
