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

        if cleaned.hasPrefix("```") {
            // Remove the opening fence line (e.g., ```json or ```)
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[firstNewline...].dropFirst())
            } else {
                cleaned = ""
            }
        }

        // Find the first closing fence and truncate from there
        if let fenceRange = cleaned.range(of: "```") {
            cleaned = String(cleaned[..<fenceRange.lowerBound])
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([SkillCall].self, from: data)
        } catch {
            print("SkillPlanner JSON decode error: \(error). Cleaned input: \(cleaned.prefix(200))")
            return []
        }
    }
}
