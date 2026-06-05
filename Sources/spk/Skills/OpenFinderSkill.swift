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
        if let path = args["path"], Self.isAllowedPath(path) {
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))
        }
        completion(.success(()))
    }

    private static func isAllowedPath(_ path: String) -> Bool {
        // Reject paths containing directory traversal
        let normalized = (path as NSString).standardizingPath
        guard !normalized.contains("..") else { return false }

        // Allow paths within the user's home directory, /Applications, or standard system locations
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let allowedPrefixes = [
            home,
            "/Applications",
            "/System/Library/CoreServices",
            "/Users"
        ]
        return allowedPrefixes.contains { normalized.hasPrefix($0) || normalized == $0 }
    }
}
