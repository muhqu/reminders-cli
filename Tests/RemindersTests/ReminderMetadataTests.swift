@testable import RemindersLibrary
import XCTest

final class ReminderMetadataTests: XCTestCase {
    func testParsesAgentMetadata() {
        let metadata = ReminderMetadata(notes: """
        Re-run the deployment.

        [agent-meta]
        workspace=/tmp/project
        repo=git@github.com:example/project.git
        """)

        XCTAssertEqual(metadata.values["workspace"], "/tmp/project")
        XCTAssertEqual(metadata.values["repo"], "git@github.com:example/project.git")
    }

    func testParsesLegacyClaudeMetadata() {
        let metadata = ReminderMetadata(notes: """
        Follow up.

        [claude-meta]
        workspace=/tmp/legacy
        """)

        XCTAssertEqual(metadata.values["workspace"], "/tmp/legacy")
    }

    func testUsesLastMetadataBlock() {
        let metadata = ReminderMetadata(notes: """
        [claude-meta]
        workspace=/tmp/legacy

        [agent-meta]
        workspace=/tmp/current
        """)

        XCTAssertEqual(metadata.values, ["workspace": "/tmp/current"])
    }

    func testIgnoresMalformedLinesAndNormalizesKeys() {
        let metadata = ReminderMetadata(notes: """
        [agent-meta]
        WORKSPACE=/tmp/project
        malformed
        =missing-key
        """)

        XCTAssertEqual(metadata.values, ["workspace": "/tmp/project"])
    }

    func testPreservesEqualsSignsInValues() {
        let metadata = ReminderMetadata(notes: """
        [agent-meta]
        command=env MODE=test ./run.sh
        """)

        XCTAssertEqual(metadata.values["command"], "env MODE=test ./run.sh")
    }

    func testNoMetadataProducesEmptyValues() {
        XCTAssertEqual(ReminderMetadata(notes: "A regular reminder note.").values, [:])
        XCTAssertEqual(ReminderMetadata(notes: nil).values, [:])
    }

    func testCriterionParsing() {
        XCTAssertEqual(
            MetadataCriterion(argument: "WORKSPACE=/tmp/project"),
            MetadataCriterion(argument: "workspace=/tmp/project"))
        XCTAssertEqual(
            MetadataCriterion(argument: "command=env MODE=test")?.value,
            "env MODE=test")
        XCTAssertNil(MetadataCriterion(argument: "missing-separator"))
        XCTAssertNil(MetadataCriterion(argument: "=missing-key"))
    }

    func testCriteriaUseExactOrMatching() {
        let metadata = ReminderMetadata(notes: """
        [agent-meta]
        workspace=/tmp/project
        repo=git@github.com:example/project.git
        """)
        let matchingRepo = MetadataCriterion(argument: "repo=git@github.com:example/project.git")!
        let otherWorkspace = MetadataCriterion(argument: "workspace=/tmp/other")!
        let differentCase = MetadataCriterion(argument: "workspace=/TMP/PROJECT")!

        XCTAssertTrue(metadata.matches(any: []))
        XCTAssertTrue(metadata.matches(any: [otherWorkspace, matchingRepo]))
        XCTAssertFalse(metadata.matches(any: [otherWorkspace]))
        XCTAssertFalse(metadata.matches(any: [differentCase]))
    }

    func testShowCommandsAcceptRepeatableMetadataOptions() {
        XCTAssertNoThrow(try CLI.parseAsRoot([
            "show", "Claude",
            "--metadata", "workspace=/tmp/project",
            "--metadata", "repo-id=github.com/example/project",
            "--hide-notes",
        ]))
        XCTAssertNoThrow(try CLI.parseAsRoot([
            "show-all",
            "--metadata", "workspace=/tmp/project",
            "--hide-notes",
        ]))
    }

    func testShowRejectsMalformedMetadataOption() {
        XCTAssertThrowsError(try CLI.parseAsRoot([
            "show", "Claude",
            "--metadata", "missing-separator",
        ]))
    }
}
