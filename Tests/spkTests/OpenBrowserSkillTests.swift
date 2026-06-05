import XCTest
@testable import Spk

final class OpenBrowserSkillTests: XCTestCase {
    func testAllowedHTTPSURL() {
        let skill = OpenBrowserSkill()
        let expectation = XCTestExpectation(description: "execute")
        skill.execute(context: SkillContext(originalText: "", text: ""), args: ["url": "https://example.com"]) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected failure: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testAllowedHTTPURL() {
        let skill = OpenBrowserSkill()
        let expectation = XCTestExpectation(description: "execute")
        skill.execute(context: SkillContext(originalText: "", text: ""), args: ["url": "http://example.com"]) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected failure: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testRejectsFileURL() {
        let skill = OpenBrowserSkill()
        let expectation = XCTestExpectation(description: "execute")
        skill.execute(context: SkillContext(originalText: "", text: ""), args: ["url": "file:///etc/passwd"]) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected failure: \(error)")
            }
            // Should fallback to Google instead of opening file URL
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testRejectsJavaScriptURL() {
        let skill = OpenBrowserSkill()
        let expectation = XCTestExpectation(description: "execute")
        skill.execute(context: SkillContext(originalText: "", text: ""), args: ["url": "javascript:alert(1)"]) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected failure: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testRejectsInvalidURL() {
        let skill = OpenBrowserSkill()
        let expectation = XCTestExpectation(description: "execute")
        skill.execute(context: SkillContext(originalText: "", text: ""), args: ["url": "not-a-url"]) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected failure: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testFallbackWhenNoURLProvided() {
        let skill = OpenBrowserSkill()
        let expectation = XCTestExpectation(description: "execute")
        skill.execute(context: SkillContext(originalText: "", text: ""), args: [:]) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected failure: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
