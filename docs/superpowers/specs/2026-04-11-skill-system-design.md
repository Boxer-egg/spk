# Spk Skill System Design

## 1. Goal

Replace the single LLM refinement prompt with a **Skill Library + Planner + Executor** architecture.

- **Planner (LLM-based)** receives voice transcript + available Skill metadata and returns a JSON execution plan.
- **Executor** runs each Skill locally in sequence.
- **Registry** holds all Skills.
- **Fallback**: if no specific Skill is matched, `default_paste` runs the original text-refinement flow.

## 2. High-Level Architecture

```
Voice → SpeechManager → Transcript
                              ↓
                        SkillPlanner
                              ↓
              LLM returns JSON execution plan
                              ↓
                        SkillExecutor
                              ↓
              Skill 1 → Skill 2 → Skill N
                              ↓
                 ClipboardManager.paste()
```

## 3. Core Components

### 3.1 Skill Protocol

```swift
protocol Skill {
    var metadata: SkillMetadata { get }
    func execute(context: inout SkillContext, completion: @escaping (Result<Void, Error>) -> Void)
}

struct SkillMetadata {
    let identifier: String
    let name: String
    let description: String
    let parameters: [SkillParameter]
}

struct SkillContext {
    var originalText: String
    var text: String
}

struct SkillParameter {
    let name: String
    let type: String
    let description: String
    let required: Bool
}
```

### 3.2 SkillPlanner

- Loads `planner.prompt` from disk.
- Injects the `metadata` of all registered Skills into the prompt dynamically.
- Sends the transcript to the configured LLM endpoint.
- Expects a JSON array response:

```json
[
  { "skill": "format_list", "args": {} },
  { "skill": "translate", "args": { "targetLang": "es" } }
]
```

- If the LLM returns an empty array or invalid JSON, falls back to `[{ "skill": "default_paste", "args": {} }]`.

### 3.3 SkillExecutor

- Receives the JSON plan.
- Looks up each Skill by `identifier` in `SkillRegistry`.
- Runs them sequentially in a `DispatchQueue`.
- Passes a mutable `SkillContext` so Skills can chain text transformations.
- After the final Skill, if `context.text` differs from `context.originalText`, calls `ClipboardManager.shared.pasteText(context.text, ...)`. If the text is unchanged (e.g., only local action Skills were executed), it performs no paste.

### 3.4 SkillRegistry

- Singleton that holds all Skill instances.
- Skills are **manually registered in Swift code** today (hard-coded list) to keep type safety.
- Each Skill is instantiated once at startup and reused.

## 4. Skill Types

### 4.1 LLM-based Skills

Internally call `LLMManager` with their own dedicated Prompt file.

Examples:
- `default_paste` — general refinement/formatting (replaces the old single-prompt flow).
- `format_list` — turns free-form dictation into numbered/bulleted lists.
- `translate` — translates `context.text` into the language specified by `targetLang`.

### 4.2 Local Skills

Execute natively without further LLM calls.

Examples:
- `open_browser` — `NSWorkspace.shared.open(URL)`.
- `open_finder` — opens Finder, optionally at a path.
- `type_text` — simulates keystrokes to type text.
- `press_key` — simulates a single keypress (e.g., Return).

## 5. Prompt File Organization

### 5.1 Built-in Prompts

Shipped inside `Spk.app/Contents/Resources/Prompts/`.

```
Resources/Prompts/
  planner.prompt
  skills/
    default_paste.prompt
    format_list.prompt
    translate.prompt
```

### 5.2 User Override Directory

At runtime, the app first checks the user config directory, falling back to the bundled version if not found.

```
~/.config/spk/prompts/
  planner.prompt
  skills/
    default_paste.prompt
    format_list.prompt
    translate.prompt
```

**This allows post-build tuning without recompiling.**

## 6. MVP Skill Set

| Identifier | Type | Description |
|------------|------|-------------|
| `default_paste` | LLM | Fallback: refine/format the text as before and paste it. |
| `format_list` | LLM | Reformat transcript into a structured list. |
| `translate` | LLM | Translate `context.text` to the language given in `targetLang`. |
| `open_browser` | Local | Open the default browser with an optional `url`. |
| `open_finder` | Local | Open Finder with an optional `path`. |
| `type_text` | Local | Simulate typing the provided `text`. |
| `press_key` | Local | Simulate pressing a key (e.g., `return`). |

## 7. Integration with Existing Code

- **Entry point change**: `AppDelegate.speechManager(_:didFinishWithText:)` hands the transcript to `SkillPlanner` instead of directly calling `LLMManager.shared.refineText`.
- **Settings UI**: `PromptSettingsView` edits the Prompt file for `default_paste` instead of the monolithic `systemPrompt` string in `SettingsManager`.
- **LLMManager**: `refineText(systemPrompt:userText:completion:)` is retained as a generic helper used by both `SkillPlanner` and LLM-based Skills.

## 8. Error Handling

- **Planner parse failure** → fallback to `default_paste`.
- **Skill not found in Registry** → log error, skip step, continue execution.
- **Single Skill failure** → Executor stops the chain, shows error state in HUD, and does **not** paste partial results.
- **LLM network failure** in a LLM-based Skill → same behavior as today (show error, paste original `context.text`).

## 9. Extensibility Path (Future Variant 2)

This design intentionally avoids fully hard-coding Prompts:

- Skill `description` lives in a Swift struct but is **decoupled** from execution logic.
- LLM-based Skill Prompts are **external text files**.
- `planner.prompt` is **external** and dynamically assembled.

If we later want user-defined Skills without compiling, the migration is limited to:

1. Replacing the hard-coded `SkillRegistry` registration with a YAML/JSON loader.
2. Adding a small runtime factory that creates generic `LLMSkill` and `LocalSkill` instances from configuration.

All existing Prompt files and Skill execution helpers remain reusable.

## 10. Example Execution Flow

**User says:** "打开浏览器搜索 YouTube 并查询游戏"

1. `SpeechManager` finishes → text: `打开浏览器搜索 YouTube 并查询游戏`
2. `SkillPlanner` sends it to LLM with injected Skill metadata.
3. LLM returns:
   ```json
   [
     { "skill": "open_browser", "args": {} },
     { "skill": "type_text", "args": { "text": "https://www.youtube.com/results?search_query=游戏" } },
     { "skill": "press_key", "args": { "key": "return" } }
   ]
   ```
4. `SkillExecutor` runs `open_browser`, `type_text`, `press_key` in order.
5. No further paste step is needed because the Local Skills already performed the action.

**User says:** "整理成列表并翻译成西班牙文"

1. LLM returns:
   ```json
   [
     { "skill": "format_list", "args": {} },
     { "skill": "translate", "args": { "targetLang": "es" } }
   ]
   ```
2. `format_list` processes `context.text`.
3. `translate` reads the updated `context.text` and produces Spanish output.
4. Executor finishes and pastes the final Spanish list.
