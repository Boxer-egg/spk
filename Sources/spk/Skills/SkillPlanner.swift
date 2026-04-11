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
            case .success(let rawOutput):
                print(
                    "[Planner] Raw Output: \"\(rawOutput.replacingOccurrences(of: "\n", with: " "))\""
                )
                let calls = Self.parseCalls(from: rawOutput)
                print(
                    "[Planner] Parsed Calls: \(calls.map { "\($0.skill)(\($0.args))" }.joined(separator: ", "))"
                )
                if calls.isEmpty {
                    completion(.success([SkillCall(skill: "default_paste", args: [:])]))
                } else {
                    completion(.success(calls))
                }
            case .failure(let error):
                print("[Planner] Error: \(error)")
                completion(.failure(error))
            }
        }
    }

    static func parseCalls(from rawOutput: String) -> [SkillCall] {
        var cleaned = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Remove Markdown code fences
        if cleaned.hasPrefix("```") {
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[firstNewline...].dropFirst())
            }
        }
        if let fenceRange = cleaned.range(of: "```") {
            cleaned = String(cleaned[..<fenceRange.lowerBound])
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. Try JSON Decoding (Primary/Compatible way)
        if (cleaned.hasPrefix("[") && cleaned.hasSuffix("]"))
            || (cleaned.hasPrefix("{") && cleaned.hasSuffix("}"))
        {
            if let data = cleaned.data(using: .utf8),
                let calls = try? JSONDecoder().decode([SkillCall].self, from: data)
            {
                return calls
            }
        }

        // 3. Simple line-based format parsing: "CALL: skill_name | key=val"
        var calls: [SkillCall] = []
        let lines = cleaned.components(separatedBy: .newlines)
        for line in lines where line.starts(with: "CALL:") {
            let content = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            let parts = content.components(separatedBy: "|")
            let skillName = parts[0].trimmingCharacters(in: .whitespaces)
            var args: [String: String] = [:]

            if parts.count > 1 {
                for argPart in parts[1...].joined(separator: "|").components(separatedBy: ",") {
                    let kv = argPart.components(separatedBy: "=")
                    if kv.count == 2 {
                        args[kv[0].trimmingCharacters(in: .whitespaces)] = kv[1].trimmingCharacters(
                            in: .whitespaces)
                    }
                }
            }
            calls.append(SkillCall(skill: skillName, args: args))
        }

        if !calls.isEmpty {
            return calls
        }

        // 4. Ultimate Fallback: Treat as default_paste with the output as corrected text
        // We pass the refined text in arguments so the skill can skip calling LLM again if it wants.
        return [SkillCall(skill: "default_paste", args: ["refined_text": cleaned])]
    }
}
