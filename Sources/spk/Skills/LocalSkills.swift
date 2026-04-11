import Foundation
import Cocoa

final class OpenBrowserSkill: Skill {
    var metadata: SkillMetadata {
        SkillMetadata(
            identifier: "open_browser",
            name: "Open Browser",
            description: "Open the default web browser, optionally to a specific URL.",
            parameters: [
                SkillParameter(name: "url", type: "string", description: "Optional URL to open.", required: false)
            ]
        )
    }

    func execute(context: SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        if let urlString = args["url"], let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(string: "about:blank")!)
        }
        completion(.success(()))
    }
}

final class OpenFinderSkill: Skill {
    var metadata: SkillMetadata {
        SkillMetadata(
            identifier: "open_finder",
            name: "Open Finder",
            description: "Open Finder, optionally to a specific path.",
            parameters: [
                SkillParameter(name: "path", type: "string", description: "Optional file path to open in Finder.", required: false)
            ]
        )
    }

    func execute(context: SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        if let path = args["path"] {
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))
        }
        completion(.success(()))
    }
}

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
