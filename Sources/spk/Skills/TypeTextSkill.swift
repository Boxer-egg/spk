import Foundation

final class TypeTextSkill: Skill {
    var metadata: SkillMetadata {
        SkillMetadata(
            identifier: "type_text",
            name: "Type Text",
            description: "Simulate keyboard input to type the given text at the current cursor location.",
            parameters: [
                SkillParameter(name: "text", type: "string", description: "The text to type.", required: true)
            ]
        )
    }

    func execute(context: SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        let text = args["text"] ?? context.text
        ClipboardManager.shared.pasteText(text, keepInClipboard: SettingsManager.shared.isCopyToClipboardEnabled)
        completion(.success(()))
    }
}
