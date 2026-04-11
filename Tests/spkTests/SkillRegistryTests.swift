import XCTest
@testable import Spk

private struct MockSkill: Skill {
    let metadata: SkillMetadata
    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
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
}
