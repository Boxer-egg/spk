# Audio Recording History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional audio recording (m4a/AAC) synced with speech transcription, stored in `~/Library/Application Support/spk/tape/`, with UI controls in General settings and menu-bar history actions.

**Architecture:** A new `AudioRecorderManager` wraps `AVAudioRecorder` to produce m4a files during hotkey recording. `HistoryEntry` gains an `audioFilename` field to link transcripts to their audio. `HistoryManager` manages the tape directory lifecycle (create, cleanup with history rotation, deletion on clear). The settings UI presents history as a grouped card with "save text" (grayed-in, mandatory) and "save audio" (optional toggle). The menu-bar history submenu gains an "Open Original Audio" action.

**Tech Stack:** Swift, AVFoundation (`AVAudioRecorder`), AppKit (`NSMenu`, `NSWorkspace`), SwiftUI.

---

## File Map

- **Create:** `Sources/spk/Managers/AudioRecorderManager.swift` — starts/stops `AVAudioRecorder`, returns file URL.
- **Modify:** `Sources/spk/Managers/HistoryManager.swift` — add `audioFilename` support and tape directory cleanup.
- **Modify:** `Sources/spk/Managers/SettingsManager.swift` — add `isHistoryAudioEnabled`.
- **Modify:** `Sources/spk/App/AppDelegate.swift` — wire `AudioRecorderManager` into recording lifecycle and menu.
- **Modify:** `Sources/spk/UI/GeneralSettingsView.swift` — redesign history section into grouped toggles.
- **Modify:** `Sources/spk/Resources/*/Localizable.strings` (6 languages) — add new keys.

---

### Task 1: Extend `HistoryEntry` with `audioFilename`

**Files:**
- Modify: `Sources/spk/Managers/HistoryManager.swift:3-15`

- [ ] **Step 1: Add `audioFilename` to the struct**

Replace the `HistoryEntry` struct with:

```swift
struct HistoryEntry: Codable {
    let id: UUID
    let timestamp: Date
    let originalText: String
    let refinedText: String?
    let audioFilename: String?

    init(originalText: String, refinedText: String?, audioFilename: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.originalText = originalText
        self.refinedText = refinedText
        self.audioFilename = audioFilename
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/spk/Managers/HistoryManager.swift
git commit -m "feat: add audioFilename to HistoryEntry"
```

---

### Task 2: Update `HistoryManager` to manage tape directory

**Files:**
- Modify: `Sources/spk/Managers/HistoryManager.swift`

- [ ] **Step 1: Add tape directory property and initialization**

Inside `HistoryManager`, add:

```swift
    private let tapeDirectoryURL: URL
```

Update `private init()` to compute and create the tape directory:

```swift
    private init() {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let configDir = homeURL.appendingPathComponent(".config/spk", isDirectory: true)
        self.historyURL = configDir.appendingPathComponent("history.json")

        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spkSupportDir = appSupportDir.appendingPathComponent("spk", isDirectory: true)
        self.tapeDirectoryURL = spkSupportDir.appendingPathComponent("tape", isDirectory: true)

        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.createDirectory(at: tapeDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        loadHistory()
    }
```

- [ ] **Step 2: Update `addEntry` to accept `audioFilename`**

Replace the `addEntry` signature and body:

```swift
    func addEntry(originalText: String, refinedText: String?, audioFilename: String? = nil) {
        guard SettingsManager.shared.isHistoryEnabled else { return }

        let entry = HistoryEntry(originalText: originalText, refinedText: refinedText, audioFilename: audioFilename)
        entries.insert(entry, at: 0)

        if entries.count > maxEntries {
            let removed = entries.suffix(entries.count - maxEntries)
            for old in removed {
                if let filename = old.audioFilename {
                    let url = tapeDirectoryURL.appendingPathComponent(filename)
                    try? FileManager.default.removeItem(at: url)
                }
            }
            entries = Array(entries.prefix(maxEntries))
        }

        saveHistory()
    }
```

- [ ] **Step 3: Update `clearHistory` to also delete audio files**

Replace `clearHistory` with:

```swift
    func clearHistory() {
        for entry in entries {
            if let filename = entry.audioFilename {
                let url = tapeDirectoryURL.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: url)
            }
        }
        entries = []
        saveHistory()
    }
```

- [ ] **Step 4: Commit**

```bash
git add Sources/spk/Managers/HistoryManager.swift
git commit -m "feat: HistoryManager manages tape directory and audioFilename"
```

---

### Task 3: Add `isHistoryAudioEnabled` to `SettingsManager`

**Files:**
- Modify: `Sources/spk/Managers/SettingsManager.swift`

- [ ] **Step 1: Add the published property**

After `isHistoryEnabled`, add:

```swift
    @Published var isHistoryAudioEnabled: Bool {
        didSet {
            config["isHistoryAudioEnabled"] = isHistoryAudioEnabled
            saveConfig()
        }
    }
```

- [ ] **Step 2: Update `keysToMigrate`**

Add `"isHistoryAudioEnabled"` to the `keysToMigrate` array.

- [ ] **Step 3: Initialize the property and seed config**

In `private init()`, after `isHistoryEnabled` initialization, add:

```swift
        self.isHistoryAudioEnabled = (config["isHistoryAudioEnabled"] as? Bool) ?? false
```

And after the existing config seed block, add:

```swift
        config["isHistoryAudioEnabled"] = isHistoryAudioEnabled
```

- [ ] **Step 4: Commit**

```bash
git add Sources/spk/Managers/SettingsManager.swift
git commit -m "feat: add isHistoryAudioEnabled setting"
```

---

### Task 4: Create `AudioRecorderManager`

**Files:**
- Create: `Sources/spk/Managers/AudioRecorderManager.swift`

- [ ] **Step 1: Write the manager**

```swift
import Foundation
import AVFoundation

class AudioRecorderManager {
    static let shared = AudioRecorderManager()

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

    private let tapeDirectoryURL: URL

    private init() {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spkSupportDir = appSupportDir.appendingPathComponent("spk", isDirectory: true)
        self.tapeDirectoryURL = spkSupportDir.appendingPathComponent("tape", isDirectory: true)
        try? FileManager.default.createDirectory(at: tapeDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }

    func startRecording() -> URL? {
        let filename = "\(UUID().uuidString).m4a"
        let url = tapeDirectoryURL.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            let success = recorder.record()
            guard success else { return nil }
            self.recorder = recorder
            self.currentURL = url
            return url
        } catch {
            print("Failed to start audio recording: \(error)")
            return nil
        }
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        let url = currentURL
        recorder = nil
        currentURL = nil
        return url
    }
}
```

- [ ] **Step 2: Add `NSMicrophoneUsageDescription` to Info.plist if missing**

Check `Sources/spk/Resources/Info.plist`. If there is no `NSMicrophoneUsageDescription` key, add it. The project likely already has microphone access (used by `SpeechManager`), but verify the key exists. If the file is an XML plist, add:

```xml
	<key>NSMicrophoneUsageDescription</key>
	<string>This app needs microphone access for speech recognition and optional audio recording.</string>
```

- [ ] **Step 3: Commit**

```bash
git add Sources/spk/Managers/AudioRecorderManager.swift Sources/spk/Resources/Info.plist
git commit -m "feat: add AudioRecorderManager for m4a history audio"
```

---

### Task 5: Update `GeneralSettingsView` history UI

**Files:**
- Modify: `Sources/spk/UI/GeneralSettingsView.swift`

- [ ] **Step 1: Replace the history toggleRow with a grouped card section**

Replace the `general.history.title` toggleRow block inside the first `card { VStack(spacing: 0) { ... } }` (around lines 30-35) with:

```swift
                        VStack(alignment: .leading, spacing: 0) {
                            Text(NSLocalizedString("general.history.title", comment: ""))
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.top, 10)
                            Text(NSLocalizedString("general.history.subtitle", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 6)

                            Divider().padding(.leading, 12)

                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(NSLocalizedString("general.history.text.title", comment: ""))
                                        .font(.system(size: 13, weight: .medium))
                                    Text(NSLocalizedString("general.history.text.subtitle", comment: ""))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: .constant(true))
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    .disabled(true)
                                    .opacity(0.6)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)

                            Divider().padding(.leading, 12)

                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(NSLocalizedString("general.history.audio.title", comment: ""))
                                        .font(.system(size: 13, weight: .medium))
                                    Text(NSLocalizedString("general.history.audio.subtitle", comment: ""))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $settings.isHistoryAudioEnabled)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
```

The previous single `toggleRow` call for history is removed entirely.

- [ ] **Step 2: Commit**

```bash
git add Sources/spk/UI/GeneralSettingsView.swift
git commit -m "feat: update GeneralSettingsView with grouped history text/audio toggles"
```

---

### Task 6: Integrate audio recording into `AppDelegate`

**Files:**
- Modify: `Sources/spk/App/AppDelegate.swift`

- [ ] **Step 1: Track the current recording's audio filename**

Add a new property near `isRecording`:

```swift
    private var currentAudioFilename: String?
```

- [ ] **Step 2: Start audio recorder when recording begins**

In `startRecordingProcess()`, after `isRecording = true`, add:

```swift
        currentAudioFilename = nil
        if SettingsManager.shared.isHistoryAudioEnabled {
            if let url = AudioRecorderManager.shared.startRecording() {
                currentAudioFilename = url.lastPathComponent
            }
        }
```

- [ ] **Step 3: Stop audio recorder and pass filename to history**

In `stopRecordingProcess()`, add after `speechManager.stopRecording()`:

```swift
        if SettingsManager.shared.isHistoryAudioEnabled {
            AudioRecorderManager.shared.stopRecording()
        }
```

Then, in `speechManager(_:didFinishWithText:)`, replace all four calls to `HistoryManager.shared.addEntry(originalText:refinedText:)` with their `audioFilename:` counterparts:

For the LLM success branch:
```swift
HistoryManager.shared.addEntry(originalText: text, refinedText: refined, audioFilename: self.currentAudioFilename)
```

For the LLM failure branch:
```swift
HistoryManager.shared.addEntry(originalText: text, refinedText: nil, audioFilename: self.currentAudioFilename)
```

For the non-LLM branch:
```swift
HistoryManager.shared.addEntry(originalText: text, refinedText: nil, audioFilename: self.currentAudioFilename)
```

Also add `self.currentAudioFilename = nil` at the end of `didFinishWithText` after the history is added, to avoid accidental reuse.

- [ ] **Step 4: Add "Open Original Audio" to history submenu**

In `updateHistoryMenu()`, inside the `submenu` construction block (after `viewOriginalItem`), add:

```swift
                let openAudioItem = NSMenuItem(title: NSLocalizedString("menu.history.openAudio", comment: ""), action: #selector(openHistoryAudio(_:)), keyEquivalent: "")
                openAudioItem.representedObject = entry
                if entry.audioFilename == nil {
                    openAudioItem.isEnabled = false
                }
                submenu.addItem(openAudioItem)
```

- [ ] **Step 5: Implement `openHistoryAudio(_:)` action**

Add the action method:

```swift
    @objc func openHistoryAudio(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? HistoryEntry,
              let filename = entry.audioFilename else { return }
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let tapeDir = appSupportDir.appendingPathComponent("spk/tape", isDirectory: true)
        let url = tapeDir.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        }
    }
```

- [ ] **Step 6: Commit**

```bash
git add Sources/spk/App/AppDelegate.swift
git commit -m "feat: integrate audio recording into recording lifecycle and menu"
```

---

### Task 7: Add localization strings

**Files:**
- Modify: `Sources/spk/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Sources/spk/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/spk/Resources/ja.lproj/Localizable.strings`
- Modify: `Sources/spk/Resources/de.lproj/Localizable.strings`
- Modify: `Sources/spk/Resources/fr.lproj/Localizable.strings`
- Modify: `Sources/spk/Resources/es.lproj/Localizable.strings`

- [ ] **Step 1: Add keys to each language file**

Insert the following block into **all six** `Localizable.strings` files, adjusting translations per language (shown below are the correct translations for each):

**zh-Hans:**
```
"general.history.text.title" = "保存文字记录";
"general.history.text.subtitle" = "转录结果（始终保存）";
"general.history.audio.title" = "保存音频记录";
"general.history.audio.subtitle" = "同时录制原始音频（m4a）";
"menu.history.openAudio" = "打开原始音频";
```

**en:**
```
"general.history.text.title" = "Save Text Record";
"general.history.text.subtitle" = "Transcription always saved";
"general.history.audio.title" = "Save Audio Record";
"general.history.audio.subtitle" = "Also record original audio (m4a)";
"menu.history.openAudio" = "Open Original Audio";
```

**ja:**
```
"general.history.text.title" = "文字記録を保存";
"general.history.text.subtitle" = "文字起こし結果は常に保存されます";
"general.history.audio.title" = "音声記録を保存";
"general.history.audio.subtitle" = "元の音声も同時に録音（m4a）";
"menu.history.openAudio" = "元の音声を開く";
```

**de:**
```
"general.history.text.title" = "Textaufzeichnung speichern";
"general.history.text.subtitle" = "Transkription wird immer gespeichert";
"general.history.audio.title" = "Audioaufzeichnung speichern";
"general.history.audio.subtitle" = "Originalaudio auch aufzeichnen (m4a)";
"menu.history.openAudio" = "Originalaudio öffnen";
```

**fr:**
```
"general.history.text.title" = "Enregistrer le texte";
"general.history.text.subtitle" = "La transcription est toujours sauvegardée";
"general.history.audio.title" = "Enregistrer l'audio";
"general.history.audio.subtitle" = "Enregistrer aussi l'audio original (m4a)";
"menu.history.openAudio" = "Ouvrir l'audio original";
```

**es:**
```
"general.history.text.title" = "Guardar registro de texto";
"general.history.text.subtitle" = "La transcripción siempre se guarda";
"general.history.audio.title" = "Guardar registro de audio";
"general.history.audio.subtitle" = "También grabar audio original (m4a)";
"menu.history.openAudio" = "Abrir audio original";
```

- [ ] **Step 2: Commit**

```bash
git add Sources/spk/Resources/*/Localizable.strings
git commit -m "feat: localize audio recording history strings"
```

---

### Task 8: Build and run verification

- [ ] **Step 1: Build the project**

Run the appropriate build command for the project (e.g., in Xcode: `Cmd+B`, or via `swift build` / `xcodebuild` if configured). Expected result: **Build Succeeded** with zero errors.

- [ ] **Step 2: Quick functional check**

1. Launch the app.
2. Open Settings > General.
3. Verify the History section shows two rows: "Save Text Record" (grayed-on) and "Save Audio Record" (toggleable, default off).
4. Turn on "Save Audio Record".
5. Trigger a recording via hotkey, speak a few words, release.
6. Check that `~/Library/Application Support/spk/tape/` contains a new `.m4a` file.
7. Open the menu bar > History > (latest entry) submenu.
8. Verify three items: "Paste this content", "View original content...", "Open Original Audio".
9. Click "Open Original Audio" and verify it plays in the default app (e.g., QuickTime).
10. Turn off "Save Audio Record", record again, and verify the new history entry has "Open Original Audio" grayed out.

- [ ] **Step 3: Commit any final tweaks**

If any fixes were needed, commit them.

---

## Self-Review

1. **Spec coverage:**
   - m4a (AAC) storage → Task 4 (`kAudioFormatMPEG4AAC`).
   - Store in `~/Library/Application Support/spk/tape/` → Tasks 2 and 4.
   - Named by history index (actually UUID mapped via `HistoryEntry.audioFilename`) → Task 1/2.
   - Keep max 20, same as history → Task 2 ( pruning in `addEntry` and `clearHistory`).
   - Settings: text grayed-in mandatory, audio optional → Task 3/5.
   - Menu history: submenu adds open audio → Task 6.

2. **Placeholder scan:** None found. All code blocks include exact file paths and Swift code.

3. **Type consistency:**
   - `HistoryEntry.init` gains `audioFilename: String? = nil` → used consistently.
   - `HistoryManager.addEntry` signature updated → matched in all 3 call sites in `AppDelegate`.
   - `SettingsManager.isHistoryAudioEnabled` is a `Bool` → bound to Toggle in SwiftUI.
   - `AudioRecorderManager.startRecording()` returns `URL?` → used in `AppDelegate`.

No gaps identified.
