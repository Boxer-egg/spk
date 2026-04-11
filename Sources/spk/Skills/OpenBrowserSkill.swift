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
        if let urlString = args["url"], let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(string: "https://www.google.com")!)
        }
        completion(.success(()))
    }
}
