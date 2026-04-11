import XCTest
@testable import Spk

private final class MockSkill: Skill {
    let metadata: SkillMetadata
    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
    init(metadata: SkillMetadata) {
        self.metadata = metadata
    }
}

final class SkillRegistryTests: XCTestCase {
    func testRegisterAndLookup() {
        let registry = SkillRegistry()
        let skill = MockSkill(metadata: SkillMetadata(
            identifier: "mock",
            name: "Mock",
            description: "A mock skill",
            parameters: []
        ))
        registry.register(skill)
        XCTAssertNotNil(registry.skill(for: "mock"))
        XCTAssertNil(registry.skill(for: "unknown"))
    }

    func testMetadataDescriptions() {
        let registry = SkillRegistry()
        let skill = MockSkill(metadata: SkillMetadata(
            identifier: "mock",
            name: "Mock",
            description: "Does a thing",
            parameters: [SkillParameter(name: "foo", type: "string", description: "bar", required: true)]
        ))
        registry.register(skill)
        let desc = registry.allMetadataDescriptions()
        XCTAssertTrue(desc.contains("mock"))
        XCTAssertTrue(desc.contains("Does a thing"))
        XCTAssertTrue(desc.contains("foo"))
    }

    func testAllSkills() {
        let registry = SkillRegistry()
        let skillA = MockSkill(metadata: SkillMetadata(
            identifier: "skillA",
            name: "Skill A",
            description: "First skill",
            parameters: []
        ))
        let skillB = MockSkill(metadata: SkillMetadata(
            identifier: "skillB",
            name: "Skill B",
            description: "Second skill",
            parameters: []
        ))
        registry.register(skillA)
        registry.register(skillB)

        let all = registry.allSkills()
        XCTAssertEqual(all.count, 2)
        let identifiers = all.map { $0.metadata.identifier }.sorted()
        XCTAssertEqual(identifiers, ["skillA", "skillB"])
    }

    func testSkillCallDecoding() throws {
        let json = """
        [
            {"skill": "uppercase", "args": {"text": "hello"}},
            {"skill": "summarize", "args": {"ratio": "0.5"}}
        ]
        """
        let data = json.data(using: .utf8)!
        let calls = try JSONDecoder().decode([SkillCall].self, from: data)

        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].skill, "uppercase")
        XCTAssertEqual(calls[0].args["text"], "hello")
        XCTAssertEqual(calls[1].skill, "summarize")
        XCTAssertEqual(calls[1].args["ratio"], "0.5")
    }
}
