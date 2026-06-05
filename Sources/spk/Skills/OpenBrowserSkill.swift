import Foundation
import Cocoa

final class OpenBrowserSkill: Skill {
    var metadata: SkillMetadata {
        SkillMetadata(
            identifier: "open_browser",
            name: "Open Browser",
            description: "Open the default web browser. If the user wants to search, construct a search URL for the appropriate site and pass it as 'url'.",
            parameters: [
                SkillParameter(name: "url", type: "string", description: "Optional URL to open.", required: false)
            ]
        )
    }

    func execute(context: SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        let targetURL: URL
        if let urlString = args["url"], let url = URL(string: urlString), Self.isAllowedURL(url) {
            targetURL = url
        } else {
            targetURL = URL(string: "https://www.google.com")!
        }
        NSWorkspace.shared.open(targetURL)
        completion(.success(()))
    }

    private static func isAllowedURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
