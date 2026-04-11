import Foundation

final class DefaultPasteSkill: Skill {
    var metadata: SkillMetadata {
        SkillMetadata(
            identifier: "default_paste",
            name: "Default Paste",
            description:
                "Correct speech recognition errors and refine the text. Use this when no other specific skill matches the user's intent.",
            parameters: []
        )
    }

    func execute(
        context: SkillContext, args: [String: String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // If the planner already provided a refined text (robust fallback), use it immediately
        if let refined = args["refined_text"] {
            context.text = refined
            completion(.success(()))
            return
        }

        guard let prompt = PromptManager.shared.loadPrompt(for: "skills/default_paste.prompt")
        else {
            completion(.success(()))
            return
        }
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
