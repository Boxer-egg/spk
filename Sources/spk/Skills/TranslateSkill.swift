import Foundation

final class TranslateSkill: Skill {
    var metadata: SkillMetadata {
        SkillMetadata(
            identifier: "translate",
            name: "Translate",
            description: "Translate the text into another language.",
            parameters: [
                SkillParameter(name: "targetLang", type: "string", description: "Target language code or name, e.g. 'es', 'English', 'French'.", required: true)
            ]
        )
    }

    func execute(context: SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let template = PromptManager.shared.loadPrompt(for: "skills/translate.prompt") else {
            completion(.success(()))
            return
        }
        let targetLang = args["targetLang"] ?? "English"
        let prompt = template.replacingOccurrences(of: "{{TARGET_LANG}}", with: targetLang)
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
