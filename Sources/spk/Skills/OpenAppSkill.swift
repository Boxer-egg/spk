import Foundation
import Cocoa

final class OpenAppSkill: Skill {
    private static let commonAppMap: [String: String] = [
        "微信": "WeChat",
        "wechat": "WeChat",
        "qq": "QQ",
        "qq浏览器": "QQ Browser",
        "火狐": "Firefox",
        "火狐浏览器": "Firefox",
        "firefox": "Firefox",
        "safari": "Safari",
        "chrome": "Google Chrome",
        "谷歌浏览器": "Google Chrome",
        "edge": "Microsoft Edge",
        "vscode": "Visual Studio Code",
        "code": "Visual Studio Code",
        "终端": "Terminal",
        "terminal": "Terminal",
        "iterm": "iTerm",
        "网易云音乐": "NeteaseMusic",
        "spotify": "Spotify",
        "飞书": "Lark",
        "钉钉": "DingTalk",
        "企业微信": "WeCom",
        "腾讯会议": "TencentMeeting",
        "zoom": "zoom.us",
        "备忘录": "Notes",
        "日历": "Calendar",
        "提醒事项": "Reminders",
        "设置": "System Settings",
        "系统设置": "System Settings",
        "appstore": "App Store",
        "邮件": "Mail",
        "照片": "Photos",
        "信息": "Messages",
        "facetime": "FaceTime",
        "地图": "Maps",
        "计算器": "Calculator",
        "预览": "Preview"
    ]

    var metadata: SkillMetadata {
        SkillMetadata(
            identifier: "open_app",
            name: "Open App",
            description: "Open a local macOS application by name. Use this when the user says '打开微信' or 'open Firefox'. Do not use this for web searches or generic URLs.",
            parameters: [
                SkillParameter(name: "name", type: "string", description: "The human-readable app name (e.g., 'WeChat', 'Firefox').", required: true)
            ]
        )
    }

    func execute(context: SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let name = args["name"] else {
            completion(.success(()))
            return
        }

        let appName: String
        let lowercased = name.lowercased()
        if let mapped = Self.commonAppMap[lowercased] {
            appName = mapped
        } else if let mapped = Self.commonAppMap[name] {
            appName = mapped
        } else {
            appName = name
        }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
            completion(.success(()))
            return
        }

        if let path = NSWorkspace.shared.fullPath(forApplication: appName) {
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
            completion(.success(()))
            return
        }

        // Fallback: use local Spotlight (mdfind) to resolve Chinese/display names like 滴答清单 -> TickTick
        Self.findAppViaSpotlight(named: appName) { url in
            if let url = url {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
            }
            completion(.success(()))
        }
    }

    private static func findAppViaSpotlight(named query: String, completion: @escaping (URL?) -> Void) {
        let directories = ["/Applications", FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path]

        // Try display name first, then filename. Avoid complex compound predicates which can match everything.
        let predicates = [
            "kMDItemDisplayName == '*\(query)*'cd",
            "kMDItemFSName == '*\(query)*'cd"
        ]

        func runQuery(index: Int) {
            guard index < predicates.count else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
            var args = [String]()
            for dir in directories { args.append(contentsOf: ["-onlyin", dir]) }
            args.append(predicates[index])
            task.arguments = args

            let pipe = Pipe()
            task.standardOutput = pipe
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                DispatchQueue.main.async {
                    if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       let firstPath = output.components(separatedBy: "\n").first,
                       !firstPath.isEmpty {
                        completion(URL(fileURLWithPath: firstPath))
                    } else {
                        runQuery(index: index + 1)
                    }
                }
            }

            do {
                try task.run()
            } catch {
                DispatchQueue.main.async {
                    runQuery(index: index + 1)
                }
            }
        }

        runQuery(index: 0)
    }
}
