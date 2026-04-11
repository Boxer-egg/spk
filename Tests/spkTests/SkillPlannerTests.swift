import XCTest
@testable import Spk

final class SkillPlannerTests: XCTestCase {
    func testParseCallsPlainJSON() {
        let json = "[{\"skill\":\"format_list\",\"args\":{}},{\"skill\":\"translate\",\"args\":{\"targetLang\":\"es\"}}]"
        let calls = SkillPlanner.parseCalls(from: json)
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].skill, "format_list")
        XCTAssertEqual(calls[1].skill, "translate")
        XCTAssertEqual(calls[1].args["targetLang"], "es")
    }

    func testParseCallsWithMarkdownFences() {
        let json = "```json\n[{\"skill\":\"default_paste\",\"args\":{}}]\n```"
        let calls = SkillPlanner.parseCalls(from: json)
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].skill, "default_paste")
    }

    func testParseCallsInvalidJSONReturnsEmpty() {
        let calls = SkillPlanner.parseCalls(from: "not json")
        XCTAssertTrue(calls.isEmpty)
    }

    func testParseCallsWithPlainFences() {
        let json = "```\n[{\"skill\":\"default_paste\",\"args\":{}}]\n```"
        let calls = SkillPlanner.parseCalls(from: json)
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].skill, "default_paste")
    }

    func testParseCallsWithTrailingText() {
        let json = "```json\n[{\"skill\":\"format_list\",\"args\":{}}]\n```\nHere is the plan."
        let calls = SkillPlanner.parseCalls(from: json)
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].skill, "format_list")
    }
}
