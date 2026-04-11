import Foundation

protocol Skill: AnyObject {
    var metadata: SkillMetadata { get }
    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void)
}

struct SkillMetadata {
    let identifier: String
    let name: String
    let description: String
    let parameters: [SkillParameter]
}

struct SkillParameter {
    let name: String
    let type: String
    let description: String
    let required: Bool
}

struct SkillContext {
    var originalText: String
    var text: String
}

struct SkillCall: Decodable {
    let skill: String
    let args: [String: String]
}
