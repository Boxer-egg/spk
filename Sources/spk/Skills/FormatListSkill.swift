import Foundation

final class FormatListSkill: Skill {
    var metadata: SkillMetadata {
        SkillMetadata(
            identifier: "format_list",
            name: "Format List",
            description: "Reformat free-form text into a structured numbered or bulleted list.",
            parameters: []
        )
    }

    func execute(context: SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let prompt = PromptManager.shared.loadPrompt(for: "skills/format_list.prompt") else {
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
