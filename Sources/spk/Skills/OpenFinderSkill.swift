import Foundation
import Cocoa

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
