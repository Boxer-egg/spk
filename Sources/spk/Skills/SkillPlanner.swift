import Foundation

class SkillPlanner {
    static let shared = SkillPlanner()

    func plan(for text: String, completion: @escaping (Result<[SkillCall], Error>) -> Void) {
        guard let rawPrompt = PromptManager.shared.loadPrompt(for: "planner.prompt") else {
            completion(.success([SkillCall(skill: "default_paste", args: [:])]))
            return
        }

        let skillsDescription = SkillRegistry.shared.allMetadataDescriptions()
        let systemPrompt = rawPrompt.replacingOccurrences(of: "{{SKILLS}}", with: skillsDescription)

        LLMManager.shared.refineText(systemPrompt: systemPrompt, userText: text) { result in
            switch result {
            case .success(let jsonString):
                let calls = Self.parseCalls(from: jsonString)
                if calls.isEmpty {
                    completion(.success([SkillCall(skill: "default_paste", args: [:])]))
                } else {
                    completion(.success(calls))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    static func parseCalls(from jsonString: String) -> [SkillCall] {
        // Strip markdown code fences if present
        var cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json"), let end = cleaned.range(of: "```", range: cleaned.index(cleaned.startIndex, offsetBy: 7)..<cleaned.endIndex) {
            cleaned = String(cleaned[cleaned.index(cleaned.startIndex, offsetBy: 7)..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if cleaned.hasPrefix("```"), let end = cleaned.range(of: "```", range: cleaned.index(cleaned.startIndex, offsetBy: 3)..<cleaned.endIndex) {
            cleaned = String(cleaned[cleaned.index(cleaned.startIndex, offsetBy: 3)..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let data = cleaned.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([SkillCall].self, from: data)) ?? []
    }
}
