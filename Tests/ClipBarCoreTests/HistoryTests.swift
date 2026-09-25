import XCTest
@testable import ClipBarCore
final class HistoryTests: XCTestCase {
    func testDeduplicateAndCap() {
        var h = History()
        for text in ["a", "b", "a", "c"] { h.add(Clip(text: text), limit: 2, hours: 0) }
        XCTAssertEqual(h.items.compactMap(\.text), ["c", "a"])
    }
    func testExpiryBoundaryAndNoExpiry() {
        var h = History(); let now = Date()
        h.add(Clip(text: "old", date: now.addingTimeInterval(-3600)), limit: 50, hours: 0, now: now)
        XCTAssertEqual(h.items.count, 1)
        h.prune(limit: 50, hours: 1, now: now)
        XCTAssertTrue(h.items.isEmpty)
    }
    func testOversizeAndTotalMemoryBound() {
        var h = History()
        h.add(Clip(image: Data(repeating: 0, count: History.itemLimit + 1)), limit: 50, hours: 0)
        XCTAssertTrue(h.items.isEmpty)
        for byte in UInt8(0)..<10 { h.add(Clip(image: Data(repeating: byte, count: History.itemLimit)), limit: 50, hours: 0) }
        XCTAssertEqual(h.items.count, 8)
    }
    func testPolicyReductionAndClear() {
        var h = History()
        for text in ["a", "b", "c"] { h.add(Clip(text: text), limit: 50, hours: 0) }
        h.prune(limit: 1, hours: 0)
        XCTAssertEqual(h.items.first?.text, "c")
        h.clear(); XCTAssertTrue(h.items.isEmpty)
    }
}
