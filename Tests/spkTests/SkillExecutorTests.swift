import XCTest
@testable import Spk

private final class AppendSkill: Skill {
    let metadata: SkillMetadata
    let suffix: String
    init(metadata: SkillMetadata, suffix: String) {
        self.metadata = metadata
        self.suffix = suffix
    }
    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        context.text += suffix
        completion(.success(()))
    }
}

private final class FailingSkill: Skill {
    let metadata: SkillMetadata
    init(metadata: SkillMetadata) {
        self.metadata = metadata
    }
    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.failure(NSError(domain: "Test", code: 1)))
    }
}

final class SkillExecutorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SkillRegistry.shared.register(AppendSkill(
            metadata: SkillMetadata(identifier: "append_a", name: "A", description: "", parameters: []),
            suffix: "A"
        ))
        SkillRegistry.shared.register(AppendSkill(
            metadata: SkillMetadata(identifier: "append_b", name: "B", description: "", parameters: []),
            suffix: "B"
        ))
        SkillRegistry.shared.register(FailingSkill(
            metadata: SkillMetadata(identifier: "fail", name: "Fail", description: "", parameters: [])
        ))
    }

    func testSequentialExecution() {
        let expectation = XCTestExpectation(description: "execute")
        SkillExecutor.shared.execute(
            calls: [SkillCall(skill: "append_a", args: [:]), SkillCall(skill: "append_b", args: [:])],
            originalText: "X"
        ) { result in
            if case .success(let text) = result {
                XCTAssertEqual(text, "XAB")
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testMissingSkillSkipped() {
        let expectation = XCTestExpectation(description: "execute")
        SkillExecutor.shared.execute(
            calls: [SkillCall(skill: "append_a", args: [:]), SkillCall(skill: "missing", args: [:]), SkillCall(skill: "append_b", args: [:])],
            originalText: "X"
        ) { result in
            if case .success(let text) = result {
                XCTAssertEqual(text, "XAB")
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testFailureStopsExecution() {
        let expectation = XCTestExpectation(description: "execute")
        SkillExecutor.shared.execute(
            calls: [SkillCall(skill: "append_a", args: [:]), SkillCall(skill: "fail", args: [:]), SkillCall(skill: "append_b", args: [:])],
            originalText: "X"
        ) { result in
            if case .failure = result {
                // expected
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
