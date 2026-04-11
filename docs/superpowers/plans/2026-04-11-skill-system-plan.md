# Spk Skill System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single LLM refinement prompt with a Skill Library + Planner + Executor architecture.

**Architecture:** Add a `Skill` protocol, a `SkillRegistry`, a `SkillPlanner` (LLM-based dispatcher), and a `SkillExecutor` (sequential runner). Prompts live in `~/.config/spk/prompts/` (with bundled fallbacks). `AppDelegate` hands transcripts to the Planner instead of directly to `LLMManager`.

**Tech Stack:** Swift 5.9, Cocoa/SwiftUI, XCTest, Yams (already imported).

---

## File Map

| File | Responsibility |
|------|----------------|
| `Sources/spk/Managers/PromptManager.swift` | Load prompts from user config dir, fallback to bundled Resources |
| `Sources/spk/Skills/Skill.swift` | `Skill` protocol, `SkillMetadata`, `SkillContext`, `SkillParameter` |
| `Sources/spk/Skills/SkillRegistry.swift` | Singleton registry of all Skills |
| `Sources/spk/Skills/SkillPlanner.swift` | Call LLM with assembled planner prompt, parse JSON plan |
| `Sources/spk/Skills/SkillExecutor.swift` | Run a JSON plan step-by-step through the registry |
| `Sources/spk/Skills/DefaultPasteSkill.swift` | LLM Skill: fallback refinement |
| `Sources/spk/Skills/FormatListSkill.swift` | LLM Skill: format text into a list |
| `Sources/spk/Skills/TranslateSkill.swift` | LLM Skill: translate text |
| `Sources/spk/Skills/LocalSkills.swift` | Local Skills: open_browser, open_finder, type_text, press_key |
| `Sources/spk/Managers/LLMManager.swift` | Modify `refineText` to accept `systemPrompt` parameter |
| `Sources/spk/Managers/SettingsManager.swift` | Remove monolithic `systemPrompt` property, keep config YAML |
| `Sources/spk/UI/PromptSettingsView.swift` | Edit `default_paste.prompt` instead of `systemPrompt` |
| `Sources/spk/App/AppDelegate.swift` | Wire `didFinishWithText` to `SkillPlanner` -> `SkillExecutor` |
| `Sources/spk/Resources/Prompts/planner.prompt` | Bundled planner system prompt template |
| `Sources/spk/Resources/Prompts/skills/*.prompt` | Bundled skill prompts |
| `Tests/spkTests/PromptManagerTests.swift` | Unit tests for prompt loading/fallback |
| `Tests/spkTests/SkillRegistryTests.swift` | Unit tests for skill lookup |
| `Tests/spkTests/SkillPlannerTests.swift` | Unit tests for prompt assembly and JSON parsing |
| `Tests/spkTests/SkillExecutorTests.swift` | Unit tests for sequential execution and context mutations |

---

### Task 1: Add test target to Package.swift

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Add testTarget to Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Spk",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Spk", targets: ["Spk"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Spk",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/spk",
            exclude: ["Resources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "spkTests",
            dependencies: ["Spk"],
            path: "Tests/spkTests",
            resources: [
                .copy("TestResources")
            ]
        )
    ]
)
```

- [ ] **Step 2: Create test directories**

Run:
```bash
mkdir -p Tests/spkTests/TestResources/Prompts/skills
mkdir -p Sources/spk/Skills
```

- [ ] **Step 3: Create bundled prompt files (initial content)**

`Sources/spk/Resources/Prompts/planner.prompt`:
```
You are an intent classifier for a voice assistant.
Available skills:
{{SKILLS}}

Instructions:
- Analyze the user's voice transcript.
- Return ONLY a JSON array of skill calls.
- If no specific skill matches, return [{"skill": "default_paste", "args": {}}].
- Each element must have "skill" (string) and "args" (object).
- Do not add explanations or markdown formatting.

Examples:
User: "打开浏览器搜索 YouTube"
Output: [{"skill":"open_browser","args":{}},{"skill":"type_text","args":{"text":"https://www.youtube.com"}},{"skill":"press_key","args":{"key":"return"}}]

User: "帮我整理成列表"
Output: [{"skill":"format_list","args":{}}]

User: "翻译成西班牙文"
Output: [{"skill":"translate","args":{"targetLang":"es"}}]

User: "今天天气不错"
Output: [{"skill":"default_paste","args":{}}]
```

`Sources/spk/Resources/Prompts/skills/default_paste.prompt`:
```
You are a speech recognition correction assistant. Your task is to correct obvious speech recognition errors in the input text. Do not rewrite or polish the content if it is already correct. Return ONLY the corrected text without any explanation or preamble.
```

`Sources/spk/Resources/Prompts/skills/format_list.prompt`:
```
Reformat the user's text into a clear structured list. Use numbered lists (1., 2., 3.) if the items imply an order, otherwise use bullet points (-). Return ONLY the formatted list without additional commentary.
```

`Sources/spk/Resources/Prompts/skills/translate.prompt`:
```
Translate the user's text into the target language specified by the user. Return ONLY the translated text without explanations.
Target language: {{TARGET_LANG}}
```

`Tests/spkTests/TestResources/Prompts/planner.prompt`:
```
Planner test prompt
```

- [ ] **Step 4: Verify swift package still resolves**

Run: `swift package resolve`
Expected: completes without errors.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Tests/ Sources/spk/Resources/Prompts/
git commit -m "chore: add test target and bundled prompt resources"
```

---

### Task 2: Create PromptManager

**Files:**
- Create: `Sources/spk/Managers/PromptManager.swift`
- Create: `Tests/spkTests/PromptManagerTests.swift`

- [ ] **Step 1: Write PromptManager.swift**

```swift
import Foundation

class PromptManager {
    static let shared = PromptManager()

    private let userPromptsDir: URL
    private let bundle: Bundle

    init(userPromptsDir: URL? = nil, bundle: Bundle = .main) {
        self.userPromptsDir = userPromptsDir ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/spk/prompts", isDirectory: true)
        self.bundle = bundle
    }

    func promptURL(for path: String) -> URL? {
        let userURL = userPromptsDir.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: userURL.path) {
            return userURL
        }
        return bundle.url(forResource: path, withExtension: nil, subdirectory: "Prompts")
    }

    func loadPrompt(for path: String) -> String? {
        guard let url = promptURL(for: path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func ensureUserPromptsDirectory() {
        try? FileManager.default.createDirectory(at: userPromptsDir, withIntermediateDirectories: true)
    }

    func copyBundledPromptToUserDirectory(path: String) {
        guard let bundledURL = bundle.url(forResource: path, withExtension: nil, subdirectory: "Prompts") else { return }
        let userURL = userPromptsDir.appendingPathComponent(path)
        let dir = userURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: userURL.path) {
            try? FileManager.default.copyItem(at: bundledURL, to: userURL)
        }
    }
}
```

- [ ] **Step 2: Write PromptManagerTests.swift**

```swift
import XCTest
@testable import Spk

final class PromptManagerTests: XCTestCase {
    var tempDir: URL!
    var bundle: Bundle!
    var manager: PromptManager!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        bundle = Bundle(for: type(of: self))
        manager = PromptManager(userPromptsDir: tempDir, bundle: bundle)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testFallsBackToBundle() {
        let url = manager.promptURL(for: "planner.prompt")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("TestResources"))
    }

    func testPrefersUserDirectory() throws {
        let userPath = tempDir.appendingPathComponent("planner.prompt")
        try "user_override".write(to: userPath, atomically: true, encoding: .utf8)
        let url = manager.promptURL(for: "planner.prompt")
        XCTAssertNotNil(url)
        let content = try String(contentsOf: url!, encoding: .utf8)
        XCTAssertEqual(content, "user_override")
    }

    func testCopyBundledPrompt() {
        manager.copyBundledPromptToUserDirectory(path: "planner.prompt")
        let userPath = tempDir.appendingPathComponent("planner.prompt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: userPath.path))
    }
}
```

- [ ] **Step 3: Run tests**

Run: `swift test --filter PromptManagerTests`
Expected: 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/spk/Managers/PromptManager.swift Tests/spkTests/PromptManagerTests.swift
git commit -m "feat: add PromptManager with user/bundle fallback and tests"
```

---

### Task 3: Define Skill protocol and SkillRegistry

**Files:**
- Create: `Sources/spk/Skills/Skill.swift`
- Create: `Sources/spk/Skills/SkillRegistry.swift`
- Create: `Tests/spkTests/SkillRegistryTests.swift`

- [ ] **Step 1: Write Skill.swift**

```swift
import Foundation

protocol Skill {
    var metadata: SkillMetadata { get }
    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void)
}

struct SkillMetadata {
    let identifier: String
    let name: String
    let description: String
    let parameters: [SkillParameter]
}

struct SkillParameter {
    let name: String
    let type: String
    let description: String
    let required: Bool
}

struct SkillContext {
    var originalText: String
    var text: String
}

struct SkillCall: Decodable {
    let skill: String
    let args: [String: String]
}
```

- [ ] **Step 2: Write SkillRegistry.swift**

```swift
import Foundation

class SkillRegistry {
    static let shared = SkillRegistry()
    private var skills: [String: Skill] = [:]

    func register(_ skill: Skill) {
        skills[skill.metadata.identifier] = skill
    }

    func skill(for identifier: String) -> Skill? {
        return skills[identifier]
    }

    func allSkills() -> [Skill] {
        return Array(skills.values)
    }

    func allMetadataDescriptions() -> String {
        return allSkills().map { meta in
            let params = meta.metadata.parameters.map { p in
                "- \($0.name) (\($0.type)\(p.required ? ", required" : ", optional")): \($0.description)"
            }.joined(separator: "\n")
            return "\(meta.metadata.identifier): \(meta.metadata.description)\nParameters:\n\(params.isEmpty ? "(none)" : params)"
        }.joined(separator: "\n\n")
    }
}
```

- [ ] **Step 3: Write SkillRegistryTests.swift**

```swift
import XCTest
@testable import Spk

private struct MockSkill: Skill {
    let metadata: SkillMetadata
    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}

final class SkillRegistryTests: XCTestCase {
    func testRegisterAndLookup() {
        let registry = SkillRegistry()
        let skill = MockSkill(metadata: SkillMetadata(
            identifier: "mock",
            name: "Mock",
            description: "A mock skill",
            parameters: []
        ))
        registry.register(skill)
        XCTAssertNotNil(registry.skill(for: "mock"))
        XCTAssertNil(registry.skill(for: "unknown"))
    }

    func testMetadataDescriptions() {
        let registry = SkillRegistry()
        let skill = MockSkill(metadata: SkillMetadata(
            identifier: "mock",
            name: "Mock",
            description: "Does a thing",
            parameters: [SkillParameter(name: "foo", type: "string", description: "bar", required: true)]
        ))
        registry.register(skill)
        let desc = registry.allMetadataDescriptions()
        XCTAssertTrue(desc.contains("mock"))
        XCTAssertTrue(desc.contains("Does a thing"))
        XCTAssertTrue(desc.contains("foo"))
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter SkillRegistryTests`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/spk/Skills/Skill.swift Sources/spk/Skills/SkillRegistry.swift Tests/spkTests/SkillRegistryTests.swift
git commit -m "feat: add Skill protocol and SkillRegistry with tests"
```

---

### Task 4: Refactor LLMManager to accept parameterized prompts

**Files:**
- Modify: `Sources/spk/Managers/LLMManager.swift`

- [ ] **Step 1: Change refineText signature**

Replace the existing `refineText(_ text: String, completion: ...)` method with:

```swift
    func refineText(systemPrompt: String, userText: String, completion: @escaping (Result<String, Error>) -> Void) {
        let settings = SettingsManager.shared
        guard settings.isLLMEnabled, !settings.apiKey.isEmpty else {
            completion(.success(userText))
            return
        }

        let urlString = settings.apiBaseURL + "/chat/completions"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "LLMManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid API Base URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": settings.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userText]
            ],
            "temperature": 0.3
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                completion(.failure(NSError(domain: "LLMManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from LLM API"])))
                return
            }

            completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        task.resume()
    }
```

- [ ] **Step 2: Update testConnection**

Replace the existing `testConnection` with:

```swift
    func testConnection(completion: @escaping (Result<String, Error>) -> Void) {
        refineText(systemPrompt: "You are a helpful assistant.", userText: "Hello, this is a test connection.") { result in
            switch result {
            case .success:
                completion(.success("Connection Successful!"))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
```

- [ ] **Step 3: Build to verify compilation**

Run: `swift build`
Expected: build succeeds (AppDelegate references still broken, which is expected until Task 7).

- [ ] **Step 4: Commit**

```bash
git add Sources/spk/Managers/LLMManager.swift
git commit -m "refactor: make LLMManager.refineText accept explicit systemPrompt and userText"
```

---

### Task 5: Create SkillPlanner

**Files:**
- Create: `Sources/spk/Skills/SkillPlanner.swift`
- Create: `Tests/spkTests/SkillPlannerTests.swift`

- [ ] **Step 1: Write SkillPlanner.swift**

```swift
import Foundation

class SkillPlanner {
    static let shared = SkillPlanner()

    func plan(for text: String, completion: @escaping (Result<[SkillCall], Error>) -> Void) {
        guard let rawPrompt = PromptManager.shared.loadPrompt(for: "planner.prompt") else {
            completion(.success([SkillCall(skill: "default_paste", args: [:])]))
            return
        }

        let skillsDescription = SkillRegistry.shared.allMetadataDescriptions()
        let systemPrompt = rawPrompt.replacingOccurrences(of: "{{SKILLS}}", with: skillsDescription)

        LLMManager.shared.refineText(systemPrompt: systemPrompt, userText: text) { result in
            switch result {
            case .success(let jsonString):
                let calls = Self.parseCalls(from: jsonString)
                if calls.isEmpty {
                    completion(.success([SkillCall(skill: "default_paste", args: [:])]))
                } else {
                    completion(.success(calls))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    static func parseCalls(from jsonString: String) -> [SkillCall] {
        // Strip markdown code fences if present
        var cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json"), let end = cleaned.range(of: "```", range: cleaned.index(cleaned.startIndex, offsetBy: 7)..<cleaned.endIndex) {
            cleaned = String(cleaned[cleaned.index(cleaned.startIndex, offsetBy: 7)..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if cleaned.hasPrefix("```"), let end = cleaned.range(of: "```", range: cleaned.index(cleaned.startIndex, offsetBy: 3)..<cleaned.endIndex) {
            cleaned = String(cleaned[cleaned.index(cleaned.startIndex, offsetBy: 3)..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let data = cleaned.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([SkillCall].self, from: data)) ?? []
    }
}
```

- [ ] **Step 2: Write SkillPlannerTests.swift**

```swift
import XCTest
@testable import Spk

final class SkillPlannerTests: XCTestCase {
    func testParseCallsPlainJSON() {
        let json = "[{\"skill\":\"format_list\",\"args\":{}},{\"skill\":\"translate\",\"args\":{\"targetLang\":\"es\"}}]"
        let calls = SkillPlanner.parseCalls(from: json)
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].skill, "format_list")
        XCTAssertEqual(calls[1].skill, "translate")
        XCTAssertEqual(calls[1].args["targetLang"], "es")
    }

    func testParseCallsWithMarkdownFences() {
        let json = "```json\n[{\"skill\":\"default_paste\",\"args\":{}}]\n```"
        let calls = SkillPlanner.parseCalls(from: json)
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].skill, "default_paste")
    }

    func testParseCallsInvalidJSONReturnsEmpty() {
        let calls = SkillPlanner.parseCalls(from: "not json")
        XCTAssertTrue(calls.isEmpty)
    }
}
```

- [ ] **Step 3: Run tests**

Run: `swift test --filter SkillPlannerTests`
Expected: 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/spk/Skills/SkillPlanner.swift Tests/spkTests/SkillPlannerTests.swift
git commit -m "feat: add SkillPlanner with JSON parsing and tests"
```

---

### Task 6: Create SkillExecutor

**Files:**
- Create: `Sources/spk/Skills/SkillExecutor.swift`
- Create: `Tests/spkTests/SkillExecutorTests.swift`

- [ ] **Step 1: Write SkillExecutor.swift**

```swift
import Foundation

class SkillExecutor {
    static let shared = SkillExecutor()

    func execute(calls: [SkillCall], originalText: String, completion: @escaping (Result<String, Error>) -> Void) {
        var context = SkillContext(originalText: originalText, text: originalText)

        // If no calls, fallback to default_paste behavior
        let effectiveCalls = calls.isEmpty ? [SkillCall(skill: "default_paste", args: [:])] : calls

        runStep(index: 0, calls: effectiveCalls, context: &context) { result in
            switch result {
            case .success:
                completion(.success(context.text))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func runStep(index: Int, calls: [SkillCall], context: inout SkillContext, completion: @escaping (Result<Void, Error>) -> Void) {
        guard index < calls.count else {
            completion(.success(()))
            return
        }

        let call = calls[index]
        guard let skill = SkillRegistry.shared.skill(for: call.skill) else {
            print("Skill not found: \(call.skill)")
            runStep(index: index + 1, calls: calls, context: &context, completion: completion)
            return
        }

        skill.execute(context: &context, args: call.args) { result in
            switch result {
            case .success:
                self.runStep(index: index + 1, calls: calls, context: &context, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
```

- [ ] **Step 2: Write SkillExecutorTests.swift**

```swift
import XCTest
@testable import Spk

private struct AppendSkill: Skill {
    let metadata: SkillMetadata
    let suffix: String
    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        context.text += suffix
        completion(.success(()))
    }
}

private struct FailingSkill: Skill {
    let metadata: SkillMetadata
    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.failure(NSError(domain: "Test", code: 1)))
    }
}

final class SkillExecutorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SkillRegistry.shared.register(AppendSkill(
            metadata: SkillMetadata(identifier: "append_a", name: "A", description: "", parameters: []),
            suffix: "A"
        ))
        SkillRegistry.shared.register(AppendSkill(
            metadata: SkillMetadata(identifier: "append_b", name: "B", description: "", parameters: []),
            suffix: "B"
        ))
        SkillRegistry.shared.register(FailingSkill(
            metadata: SkillMetadata(identifier: "fail", name: "Fail", description: "", parameters: [])
        ))
    }

    func testSequentialExecution() {
        let expectation = XCTestExpectation(description: "execute")
        SkillExecutor.shared.execute(
            calls: [SkillCall(skill: "append_a", args: [:]), SkillCall(skill: "append_b", args: [:])],
            originalText: "X"
        ) { result in
            if case .success(let text) = result {
                XCTAssertEqual(text, "XAB")
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testMissingSkillSkipped() {
        let expectation = XCTestExpectation(description: "execute")
        SkillExecutor.shared.execute(
            calls: [SkillCall(skill: "append_a", args: [:]), SkillCall(skill: "missing", args: [:]), SkillCall(skill: "append_b", args: [:])],
            originalText: "X"
        ) { result in
            if case .success(let text) = result {
                XCTAssertEqual(text, "XAB")
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testFailureStopsExecution() {
        let expectation = XCTestExpectation(description: "execute")
        SkillExecutor.shared.execute(
            calls: [SkillCall(skill: "append_a", args: [:]), SkillCall(skill: "fail", args: [:]), SkillCall(skill: "append_b", args: [:])],
            originalText: "X"
        ) { result in
            if case .failure = result {
                // expected
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
```

- [ ] **Step 3: Run tests**

Run: `swift test --filter SkillExecutorTests`
Expected: 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/spk/Skills/SkillExecutor.swift Tests/spkTests/SkillExecutorTests.swift
git commit -m "feat: add SkillExecutor with sequential step runner and tests"
```

---

### Task 7: Create LLM-based Skills

**Files:**
- Create: `Sources/spk/Skills/DefaultPasteSkill.swift`
- Create: `Sources/spk/Skills/FormatListSkill.swift`
- Create: `Sources/spk/Skills/TranslateSkill.swift`

- [ ] **Step 1: Write DefaultPasteSkill.swift**

```swift
import Foundation

struct DefaultPasteSkill: Skill {
    var metadata: SkillMetadata {
        SkillMetadata(
            identifier: "default_paste",
            name: "Default Paste",
            description: "Correct speech recognition errors and refine the text. Use this when no other specific skill matches the user's intent.",
            parameters: []
        )
    }

    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let prompt = PromptManager.shared.loadPrompt(for: "skills/default_paste.prompt") else {
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
```

- [ ] **Step 2: Write FormatListSkill.swift**

```swift
import Foundation

struct FormatListSkill: Skill {
    var metadata: SkillMetadata {
        SkillMetadata(
            identifier: "format_list",
            name: "Format List",
            description: "Reformat free-form text into a structured numbered or bulleted list.",
            parameters: []
        )
    }

    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
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
```

- [ ] **Step 3: Write TranslateSkill.swift**

```swift
import Foundation

struct TranslateSkill: Skill {
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

    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
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
```

- [ ] **Step 4: Build to verify compilation**

Run: `swift build`
Expected: succeeds (some AppDelegate references missing until Task 9).

- [ ] **Step 5: Commit**

```bash
git add Sources/spk/Skills/DefaultPasteSkill.swift Sources/spk/Skills/FormatListSkill.swift Sources/spk/Skills/TranslateSkill.swift
git commit -m "feat: add LLM-based Skills: default_paste, format_list, translate"
```

---

### Task 8: Create Local Skills

**Files:**
- Create: `Sources/spk/Skills/LocalSkills.swift`

- [ ] **Step 1: Write LocalSkills.swift**

```swift
import Foundation
import Cocoa

struct OpenBrowserSkill: Skill {
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

    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        if let urlString = args["url"], let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(string: "about:blank")!)
        }
        completion(.success(()))
    }
}

struct OpenFinderSkill: Skill {
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

    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        if let path = args["path"] {
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))
        }
        completion(.success(()))
    }
}

struct TypeTextSkill: Skill {
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

    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
        let text = args["text"] ?? context.text
        ClipboardManager.shared.pasteText(text, keepInClipboard: SettingsManager.shared.isCopyToClipboardEnabled)
        completion(.success(()))
    }
}

struct PressKeySkill: Skill {
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

    func execute(context: inout SkillContext, args: [String: String], completion: @escaping (Result<Void, Error>) -> Void) {
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
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/spk/Skills/LocalSkills.swift
git commit -m "feat: add local Skills: open_browser, open_finder, type_text, press_key"
```

---

### Task 9: Wire up AppDelegate and initialize Registry

**Files:**
- Modify: `Sources/spk/App/AppDelegate.swift`

- [ ] **Step 1: Add Skill registration to applicationDidFinishLaunching**

In `AppDelegate.swift`, inside `applicationDidFinishLaunching`, after `speechManager.delegate = self`, add:

```swift
        // Register skills
        SkillRegistry.shared.register(DefaultPasteSkill())
        SkillRegistry.shared.register(FormatListSkill())
        SkillRegistry.shared.register(TranslateSkill())
        SkillRegistry.shared.register(OpenBrowserSkill())
        SkillRegistry.shared.register(OpenFinderSkill())
        SkillRegistry.shared.register(TypeTextSkill())
        SkillRegistry.shared.register(PressKeySkill())
```

- [ ] **Step 2: Add prompt migration/initialization**

In `applicationDidFinishLaunching`, after skill registration, add:

```swift
        // Ensure user prompts directory exists and copy defaults if needed
        PromptManager.shared.ensureUserPromptsDirectory()
        PromptManager.shared.copyBundledPromptToUserDirectory(path: "planner.prompt")
        PromptManager.shared.copyBundledPromptToUserDirectory(path: "skills/default_paste.prompt")
        PromptManager.shared.copyBundledPromptToUserDirectory(path: "skills/format_list.prompt")
        PromptManager.shared.copyBundledPromptToUserDirectory(path: "skills/translate.prompt")
```

(Note: migration of `system_prompt.txt` to `default_paste.prompt` will be handled in Task 10.)

- [ ] **Step 3: Rewrite didFinishWithText**

Replace the entire `func speechManager(_ manager: SpeechManager, didFinishWithText text: String)` method with:

```swift
    func speechManager(_ manager: SpeechManager, didFinishWithText text: String) {
        hudShowWorkItem = nil

        // If HUD was never visible (anti-misclick), don't process results
        guard isHudVisible else {
            isHudVisible = false
            return
        }

        let wordCount = text.count
        statisticsTodayCount += 1
        statisticsTotalWords += wordCount

        HUDViewModel.shared.state = .refining
        HUDViewModel.shared.text = text
        updateMenuBarIcon(badgeColor: .systemBlue)

        SkillPlanner.shared.plan(for: text) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let calls):
                    SkillExecutor.shared.execute(calls: calls, originalText: text) { execResult in
                        DispatchQueue.main.async {
                            switch execResult {
                            case .success(let finalText):
                                HUDViewModel.shared.text = finalText
                                HUDViewModel.shared.state = .success
                                if finalText != text {
                                    ClipboardManager.shared.pasteText(finalText, keepInClipboard: SettingsManager.shared.isCopyToClipboardEnabled)
                                }
                                HistoryManager.shared.addEntry(originalText: text, refinedText: finalText != text ? finalText : nil, audioFilename: self.currentAudioFilename)
                            case .failure(let error):
                                print("Skill execution error: \(error)")
                                HUDViewModel.shared.state = .error
                                ClipboardManager.shared.pasteText(text, keepInClipboard: SettingsManager.shared.isCopyToClipboardEnabled)
                                HistoryManager.shared.addEntry(originalText: text, refinedText: nil, audioFilename: self.currentAudioFilename)
                            }
                            self.currentAudioFilename = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                HUDViewModel.shared.isVisible = false
                                self.updateMenuBarIcon(badgeColor: nil)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    HUDPanel.shared.hide()
                                }
                            }
                        }
                    }
                case .failure(let error):
                    print("Planner error: \(error)")
                    HUDViewModel.shared.state = .error
                    ClipboardManager.shared.pasteText(text, keepInClipboard: SettingsManager.shared.isCopyToClipboardEnabled)
                    HistoryManager.shared.addEntry(originalText: text, refinedText: nil, audioFilename: self.currentAudioFilename)
                    self.currentAudioFilename = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        HUDViewModel.shared.isVisible = false
                        self.updateMenuBarIcon(badgeColor: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            HUDPanel.shared.hide()
                        }
                    }
                }
            }
        }
    }
```

- [ ] **Step 4: Build to verify compilation**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/spk/App/AppDelegate.swift
git commit -m "feat: wire SkillPlanner and SkillExecutor into AppDelegate"
```

---

### Task 10: Update Settings UI and migrate old system prompt

**Files:**
- Modify: `Sources/spk/Managers/SettingsManager.swift`
- Modify: `Sources/spk/UI/PromptSettingsView.swift`
- Modify: `Sources/spk/App/AppDelegate.swift`

- [ ] **Step 1: Update SettingsManager to remove monolithic systemPrompt**

Replace the `systemPrompt` property and its persistence with a read-only convenience that points to the file.

In `SettingsManager.swift`:
1. Remove `@Published var systemPrompt: String` and `private let systemPromptURL`.
2. Remove `saveSystemPrompt()` method.
3. Remove `Self.loadSystemPrompt(config: systemPromptURL:)` method.
4. In `private init()`, remove `self.systemPrompt = ...`, `config.removeValue(forKey: "systemPrompt")`, and `saveSystemPrompt()`.
5. Add a convenience computed property:

```swift
    var defaultPastePromptPath: String {
        return "~/.config/spk/prompts/skills/default_paste.prompt"
    }
```

(Actual content editing is done by `PromptSettingsView` reading/writing the file directly.)

Also update `keysToMigrate` to remove `"systemPrompt"`.

- [ ] **Step 2: Rewrite PromptSettingsView to edit default_paste.prompt**

Replace `PromptSettingsView.swift` entirely:

```swift
import SwiftUI

struct PromptSettingsView: View {
    @State private var promptText: String = ""
    private let promptURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/spk/prompts/skills/default_paste.prompt")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("prompt.title", comment: ""))
                    .font(.title2)
                    .fontWeight(.semibold)

                card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Paste Prompt")
                            .font(.system(size: 13, weight: .medium))
                        Text("This prompt is used when no specific skill matches your voice input.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextEditor(text: $promptText)
                            .frame(minHeight: 200)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                            .background(Color(nsColor: .textBackgroundColor).cornerRadius(6))
                            .onChange(of: promptText) { _ in
                                savePrompt()
                            }
                    }
                    .padding(14)
                }

                HStack {
                    Spacer()
                    Text(NSLocalizedString("common.changesSaved", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 8)

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .onAppear {
            loadPrompt()
        }
    }

    private func loadPrompt() {
        if FileManager.default.fileExists(atPath: promptURL.path) {
            if let content = try? String(contentsOf: promptURL, encoding: .utf8) {
                promptText = content
                return
            }
        }
        // Fallback to bundled default
        if let bundledURL = Bundle.main.url(forResource: "skills/default_paste", withExtension: "prompt", subdirectory: "Prompts"),
           let content = try? String(contentsOf: bundledURL, encoding: .utf8) {
            promptText = content
        }
    }

    private func savePrompt() {
        try? promptText.write(to: promptURL, atomically: true, encoding: .utf8)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
    }
}
```

- [ ] **Step 3: Add system_prompt.txt migration in AppDelegate**

In `AppDelegate.applicationDidFinishLaunching`, right before the `PromptManager` initialization block, add:

```swift
        // Migrate old system_prompt.txt to default_paste.prompt if needed
        let oldPromptURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/spk/system_prompt.txt")
        let defaultPastePromptURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/spk/prompts/skills/default_paste.prompt")
        if FileManager.default.fileExists(atPath: oldPromptURL.path) && !FileManager.default.fileExists(atPath: defaultPastePromptURL.path) {
            PromptManager.shared.ensureUserPromptsDirectory()
            try? FileManager.default.createDirectory(at: defaultPastePromptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: oldPromptURL, to: defaultPastePromptURL)
        }
```

- [ ] **Step 4: Build and run tests**

Run: `swift build`
Expected: succeeds.

Run: `swift test`
Expected: all tests pass (PromptManagerTests, SkillRegistryTests, SkillPlannerTests, SkillExecutorTests).

- [ ] **Step 5: Commit**

```bash
git add Sources/spk/Managers/SettingsManager.swift Sources/spk/UI/PromptSettingsView.swift Sources/spk/App/AppDelegate.swift
git commit -m "feat: update settings UI for default_paste prompt and migrate old system_prompt.txt"
```

---

### Task 11: Final integration and manual verification

- [ ] **Step 1: Full build**

Run: `swift build`
Expected: clean build.

- [ ] **Step 2: Manual end-to-end test checklist**

Run the app (from Xcode or by launching the built executable).

1. Hold Speak key, say "今天天气不错", release.
   - Expected: `default_paste` runs. Refined text is pasted.
2. Open `~/.config/spk/prompts/skills/default_paste.prompt` in an editor, change a word, save.
   - Expected: next recording uses the new prompt without recompilation.
3. (If LLM is enabled) Say "整理成列表：买牛奶，买鸡蛋，买面包".
   - Expected: `format_list` skill is triggered. Result is a numbered/bulleted list.
4. (If LLM is enabled) Say "翻译成英文：你好世界".
   - Expected: `translate` skill is triggered with `targetLang: "英文"` (or similar). Result is English text.
5. Say "打开浏览器搜索 YouTube".
   - Expected: browser opens and types URL.

- [ ] **Step 3: Commit any missing changes**

If any file was modified during testing/fixes, commit them with a descriptive message.

---

## Self-Review Checklist

1. **Spec coverage:**
   - Skill protocol + Registry ✅ Task 3
   - SkillPlanner (LLM dispatcher) ✅ Task 5
   - SkillExecutor (sequential runner) ✅ Task 6
   - LLM-based Skills ✅ Task 7
   - Local Skills ✅ Task 8
   - Prompt loading with user override ✅ Task 2
   - AppDelegate integration ✅ Task 9
   - Settings UI migration ✅ Task 10
   - Fallback to `default_paste` ✅ Task 5 (Planner) + Task 9 (Executor)

2. **Placeholder scan:** No TBD, TODO, or vague steps remain.

3. **Type consistency:**
   - `Skill.execute` signature consistently uses `(context: inout SkillContext, args: [String: String], completion: ...)` across all tasks.
   - `SkillCall.args` is `[String: String]`.
   - `SkillPlanner.parseCalls` decodes to `[SkillCall]`.

Plan complete and saved to `docs/superpowers/plans/2026-04-11-skill-system-plan.md`.
