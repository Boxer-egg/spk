import Foundation
import CoreGraphics

final class PressKeySkill: Skill {
    var metadata: SkillMetadata {
        SkillMetadata(
            identifier: "press_key",
            name: "Press Key",
            description: "Simulate pressing a single key (e.g., return, escape).",
            parameters: [
                SkillParameter(name: "key", type: "string", description: "Key name to press. Supported: return.", required: true)
            ]
        )
    }

    func execute(context: SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let key = args["key"] else {
            completion(.success(()))
            return
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        switch key.lowercased() {
        case "return":
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        default:
            break
        }
        completion(.success(()))
    }
}
