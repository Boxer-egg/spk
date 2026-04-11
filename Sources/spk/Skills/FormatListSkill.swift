import Foundation

final class FormatListSkill: Skill {
    var metadata: SkillMetadata {
        SkillMetadata(
            identifier: "format_list",
            name: "Format List",
            description:
                "Format free-form text into a structured numbered or bulleted list. Use this when the user's text contains multiple items, a sequence of steps, or when they explicitly ask for a list.",
            parameters: []
        )
    }

    func execute(
        context: SkillContext, args: [String: String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let prompt = PromptManager.shared.loadPrompt(for: "skills/format_list.prompt") else {
            print("[Executor] ERROR: Failed to load skills/format_list.prompt")
            completion(.success(()))
            return
        }
        print("[Executor] Calling LLM for format_list with prompt length: \(prompt.count)")

        LLMManager.shared.refineText(systemPrompt: prompt, userText: context.text) { result in
            switch result {
            case .success(let refined):
                context.text = refined
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
