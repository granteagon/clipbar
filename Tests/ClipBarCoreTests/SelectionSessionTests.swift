import XCTest
@testable import ClipBarCore
final class SelectionSessionTests: XCTestCase {
    func testQuickTapDoesNotCommit() {
        var session = SelectionSession(); session.begin()
        XCTAssertFalse(session.release())
    }
    func testHeldNavigationCommitsOnlyOnce() {
        var session = SelectionSession(); session.begin(); session.navigate(modifiersHeld: true)
        XCTAssertTrue(session.release()); XCTAssertFalse(session.release())
    }
    func testCancellationAndUnmodifiedNavigationDoNotCommit() {
        var session = SelectionSession(); session.navigate(modifiersHeld: true); session.cancel()
        XCTAssertFalse(session.release())
        session.navigate(modifiersHeld: false); XCTAssertFalse(session.release())
    }
}
