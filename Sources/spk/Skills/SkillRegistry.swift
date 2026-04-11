import Foundation

final class SkillRegistry {
    static let shared = SkillRegistry()
    private var skills: [String: Skill] = [:]
    private let lock = NSLock()

    func register(_ skill: Skill) {
        lock.lock()
        defer { lock.unlock() }
        skills[skill.metadata.identifier] = skill
    }

    func skill(for identifier: String) -> Skill? {
        lock.lock()
        defer { lock.unlock() }
        return skills[identifier]
    }

    func allSkills() -> [Skill] {
        lock.lock()
        defer { lock.unlock() }
        return Array(skills.values)
    }

    func allMetadataDescriptions() -> String {
        return allSkills().map { meta in
            let params = meta.metadata.parameters.map { p in
                "- \(p.name) (\(p.type)\(p.required ? ", required" : ", optional")): \(p.description)"
            }.joined(separator: "\n")
            return "\(meta.metadata.identifier): \(meta.metadata.description)\nParameters:\n\(params.isEmpty ? "(none)" : params)"
        }.joined(separator: "\n\n")
    }
}
