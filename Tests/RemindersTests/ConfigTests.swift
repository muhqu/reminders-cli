@testable import RemindersLibrary
import XCTest

final class ConfigTests: XCTestCase {
    func testValidConfig() throws {
        let yaml = """
        full_access: false
        allowed_lists:
          - "Work"
          - "Personal*"
        """
        let config = try Config.parse(yaml)
        XCTAssertFalse(config.fullAccess)
        XCTAssertEqual(config.allowedLists, ["Work", "Personal*"])
    }

    func testFullAccess() throws {
        let config = try Config.parse("full_access: true")
        XCTAssertTrue(config.fullAccess)
        XCTAssertEqual(config.allowedLists, [])
    }

    func testCommentOnlyYieldsDefaults() throws {
        let config = try Config.parse("# just a comment\n")
        XCTAssertFalse(config.fullAccess)
        XCTAssertEqual(config.allowedLists, [])
    }

    func testMissingKeysUseDefaults() throws {
        let config = try Config.parse("allowed_lists: [\"A\", \"B\"]")
        XCTAssertFalse(config.fullAccess)
        XCTAssertEqual(config.allowedLists, ["A", "B"])
    }

    func testWrongTypeThrows() {
        // allowed_lists must be a sequence of strings, not a scalar.
        XCTAssertThrowsError(try Config.parse("allowed_lists: 12345"))
    }

    func testMalformedYamlThrows() {
        XCTAssertThrowsError(try Config.parse("allowed_lists: [unterminated"))
    }
}
