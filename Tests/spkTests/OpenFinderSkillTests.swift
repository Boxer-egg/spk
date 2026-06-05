import XCTest
@testable import Spk

final class OpenFinderSkillTests: XCTestCase {
    func testAllowedPathInHomeDirectory() {
        let skill = OpenFinderSkill()
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path + "/Documents"
        let expectation = XCTestExpectation(description: "execute")
        skill.execute(context: SkillContext(originalText: "", text: ""), args: ["path": homePath]) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected failure: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testAllowedPathInApplications() {
        let skill = OpenFinderSkill()
        let expectation = XCTestExpectation(description: "execute")
        skill.execute(context: SkillContext(originalText: "", text: ""), args: ["path": "/Applications/Safari.app"]) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected failure: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testRejectsPathTraversal() {
        let skill = OpenFinderSkill()
        let expectation = XCTestExpectation(description: "execute")
        skill.execute(context: SkillContext(originalText: "", text: ""), args: ["path": "../../../etc/passwd"]) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected failure: \(error)")
            }
            // Should fallback to opening Finder instead of the malicious path
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testRejectsSystemPathOutsideAllowed() {
        let skill = OpenFinderSkill()
        let expectation = XCTestExpectation(description: "execute")
        skill.execute(context: SkillContext(originalText: "", text: ""), args: ["path": "/etc/passwd"]) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected failure: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testRejectsRelativePathOutsideHome() {
        let skill = OpenFinderSkill()
        let expectation = XCTestExpectation(description: "execute")
        skill.execute(context: SkillContext(originalText: "", text: ""), args: ["path": "/usr/bin/whoami"]) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected failure: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testFallbackWhenNoPathProvided() {
        let skill = OpenFinderSkill()
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
