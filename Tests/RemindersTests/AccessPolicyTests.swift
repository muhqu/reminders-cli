@testable import RemindersLibrary
import XCTest

final class AccessPolicyTests: XCTestCase {
    private func policy(fullAccess: Bool = false, _ patterns: [String]) -> AccessPolicy {
        return AccessPolicy(Config(fullAccess: fullAccess, allowedLists: patterns))
    }

    func testExactMatch() {
        let p = policy(["Work"])
        XCTAssertTrue(p.allows("Work"))
        XCTAssertFalse(p.allows("Personal"))
    }

    func testCaseInsensitive() {
        XCTAssertTrue(policy(["work"]).allows("WORK"))
        XCTAssertTrue(policy(["WoRk"]).allows("work"))
    }

    func testGlobPrefix() {
        let p = policy(["Personal*"])
        XCTAssertTrue(p.allows("Personal"))
        XCTAssertTrue(p.allows("Personal Stuff"))
        XCTAssertFalse(p.allows("My Personal"))
    }

    func testGlobSuffix() {
        let p = policy(["*shared"])
        XCTAssertTrue(p.allows("Team shared"))
        XCTAssertFalse(p.allows("shared notes"))
    }

    func testGlobSingleChar() {
        let p = policy(["List?"])
        XCTAssertTrue(p.allows("ListA"))
        XCTAssertFalse(p.allows("ListAB"))
        XCTAssertFalse(p.allows("List"))
    }

    func testEmptyAllowlistDeniesAll() {
        let p = policy([])
        XCTAssertFalse(p.allows("Work"))
        XCTAssertFalse(p.allows(""))
    }

    func testFullAccessAllowsAll() {
        let p = policy(fullAccess: true, [])
        XCTAssertTrue(p.allows("Anything"))
        XCTAssertTrue(p.allows(""))
    }

    func testMultiplePatternsAnyMatch() {
        let p = policy(["Work", "Personal*"])
        XCTAssertTrue(p.allows("Work"))
        XCTAssertTrue(p.allows("Personal Errands"))
        XCTAssertFalse(p.allows("Groceries"))
    }
}
