# Spk UI Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement History menu truncation + clear action, and refactor Settings into a modern Sidebar-style layout with a timed API test status card.

**Architecture:** Replace the existing `TabView` in `SettingsView.swift` with a custom HStack Sidebar layout, splitting each tab into its own SwiftUI view. Update `AppDelegate.updateHistoryMenu()` to truncate long text to ~50 characters and add a "Clear History..." confirmation action.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit (NSAlert, NSMenu), macOS 14+

---

## File Structure

| File | Responsibility |
|------|----------------|
| `Sources/spk/App/AppDelegate.swift` | History menu title truncation, Clear History NSMenuItem + NSAlert |
| `Sources/spk/Managers/HistoryManager.swift` | Verify `clearHistory()` exists (no code changes expected) |
| `Sources/spk/UI/SettingsView.swift` | Root window layout: Sidebar (160px) + content area, 640×420 |
| `Sources/spk/UI/GeneralSettingsView.swift` | Toggles for LLM, Clipboard, History |
| `Sources/spk/UI/APISettingsView.swift` | Endpoint fields + timed Test Connection status card |
| `Sources/spk/UI/PromptSettingsView.swift` | System prompt TextEditor |
| `Sources/spk/UI/ShortcutSettingsView.swift` | Hold-to-speak toggle, trigger key picker, usage hints |

---

## Notes for implementer

- The project is a native macOS SwiftUI app. Because it is UI-heavy, we validate each step by building (`swift build`) and optionally running the app to inspect the UI.
- Use system colors (`Color.primary`, `Color.secondary`, `Color(nsColor: .controlBackgroundColor)`, `Color(nsColor: .selectedContentBackgroundColor)`) so light/dark mode works automatically.
- Keep exact SF Symbol names consistent with existing code.
- `HistoryManager.clearHistory()` already exists; confirm it before wiring the menu action.

---

### Task 1: Confirm HistoryManager.clearHistory() exists

**Files:**
- Read: `Sources/spk/Managers/HistoryManager.swift`

- [ ] **Step 1: Open and verify**

  Read `Sources/spk/Managers/HistoryManager.swift` and confirm there is a method `func clearHistory()` that sets `entries = []` and calls `saveHistory()`.

- [ ] **Step 2: Document result**

  If it exists, proceed to Task 2. If it does NOT exist, add the following method inside `HistoryManager` before proceeding:

  ```swift
  func clearHistory() {
      entries = []
      saveHistory()
  }
  ```

---

### Task 2: Truncate History menu titles and add Clear History action

**Files:**
- Modify: `Sources/spk/App/AppDelegate.swift`

- [ ] **Step 1: Replace updateHistoryMenu() body**

  Find the `updateHistoryMenu()` method (around line 249). Replace the entire method body so it truncates titles to 50 characters and adds a Clear History menu item when entries exist.

  ```swift
  private func updateHistoryMenu() {
      guard let historyMenu = historyMenuItem?.submenu else { return }
      historyMenu.removeAllItems()

      let entries = HistoryManager.shared.getEntries()
      if entries.isEmpty {
          let item = NSMenuItem(title: "No history", action: nil, keyEquivalent: "")
          item.isEnabled = false
          historyMenu.addItem(item)
      } else {
          let maxChars = 50
          for entry in entries.prefix(10) {
              let dateFormatter = DateFormatter()
              dateFormatter.dateStyle = .short
              dateFormatter.timeStyle = .short
              let dateStr = dateFormatter.string(from: entry.timestamp)
              let prefix = "\(dateStr): "
              let text = entry.refinedText ?? entry.originalText
              let title: String
              if prefix.count + text.count > maxChars {
                  let remain = maxChars - prefix.count - 3
                  title = prefix + String(text.prefix(max(0, remain))) + "..."
              } else {
                  title = prefix + text
              }
              let item = NSMenuItem(title: title, action: #selector(selectHistoryItem(_:)), keyEquivalent: "")
              item.representedObject = entry
              historyMenu.addItem(item)
          }
          if entries.count > 10 {
              historyMenu.addItem(NSMenuItem.separator())
              let moreItem = NSMenuItem(title: "\(entries.count - 10) more entries", action: nil, keyEquivalent: "")
              moreItem.isEnabled = false
              historyMenu.addItem(moreItem)
          }
          historyMenu.addItem(NSMenuItem.separator())
          let clearItem = NSMenuItem(title: "Clear History...", action: #selector(clearHistory(_:)), keyEquivalent: "")
          historyMenu.addItem(clearItem)
      }
  }
  ```

- [ ] **Step 2: Add clearHistory(_:) action**

  Add the following method inside `AppDelegate` (near `selectHistoryItem`):

  ```swift
  @objc func clearHistory(_ sender: NSMenuItem?) {
      let alert = NSAlert()
      alert.messageText = "Clear History?"
      alert.informativeText = "确定要清除所有历史记录吗？此操作无法撤销。"
      alert.alertStyle = .warning
      alert.addButton(withTitle: "Clear")
      alert.addButton(withTitle: "Cancel")
      let response = alert.runModal()
      if response == .alertFirstButtonReturn {
          HistoryManager.shared.clearHistory()
          updateHistoryMenu()
      }
  }
  ```

- [ ] **Step 3: Build**

  Run:
  ```bash
  swift build
  ```
  Expected: success, no errors.

- [ ] **Step 4: Commit**

  ```bash
  git add Sources/spk/App/AppDelegate.swift
  git commit -m "feat: truncate History menu titles and add Clear History action"
  ```

---

### Task 3: Create GeneralSettingsView

**Files:**
- Create: `Sources/spk/UI/GeneralSettingsView.swift`

- [ ] **Step 1: Write the file**

  ```swift
  import SwiftUI

  struct GeneralSettingsView: View {
      @ObservedObject var settings = SettingsManager.shared

      var body: some View {
          ScrollView {
              VStack(alignment: .leading, spacing: 16) {
                  Text("General")
                      .font(.title2)
                      .fontWeight(.semibold)

                  card {
                      VStack(spacing: 0) {
                          toggleRow(
                              title: "Enable LLM Correction",
                              subtitle: "Refine speech with AI before pasting",
                              isOn: $settings.isLLMEnabled
                          )

                          Divider().padding(.leading, 12)

                          toggleRow(
                              title: "Copy to Clipboard",
                              subtitle: "Save final output automatically",
                              isOn: $settings.isCopyToClipboardEnabled
                          )

                          Divider().padding(.leading, 12)

                          toggleRow(
                              title: "Record History",
                              subtitle: "Save transcriptions (max 20 entries)",
                              isOn: $settings.isHistoryEnabled
                          )
                      }
                  }

                  Spacer(minLength: 20)
              }
              .padding(20)
          }
      }

      @ViewBuilder
      private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
          content()
              .padding(.vertical, 8)
              .background(Color(nsColor: .controlBackgroundColor))
              .cornerRadius(12)
      }

      @ViewBuilder
      private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
          HStack(alignment: .center, spacing: 12) {
              VStack(alignment: .leading, spacing: 2) {
                  Text(title)
                      .font(.system(size: 13, weight: .medium))
                  Text(subtitle)
                      .font(.caption)
                      .foregroundColor(.secondary)
              }
              Spacer()
              Toggle("", isOn: isOn)
                  .toggleStyle(.switch)
                  .labelsHidden()
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
      }
  }
  ```

- [ ] **Step 2: Build**

  Run:
  ```bash
  swift build
  ```
  Expected: success.

- [ ] **Step 3: Commit**

  ```bash
  git add Sources/spk/UI/GeneralSettingsView.swift
  git commit -m "feat: add GeneralSettingsView for sidebar layout"
  ```

---

### Task 4: Create PromptSettingsView

**Files:**
- Create: `Sources/spk/UI/PromptSettingsView.swift`

- [ ] **Step 1: Write the file**

  ```swift
  import SwiftUI

  struct PromptSettingsView: View {
      @ObservedObject var settings = SettingsManager.shared

      var body: some View {
          ScrollView {
              VStack(alignment: .leading, spacing: 16) {
                  Text("AI Prompt")
                      .font(.title2)
                      .fontWeight(.semibold)

                  card {
                      VStack(alignment: .leading, spacing: 8) {
                          Text("System Prompt")
                              .font(.system(size: 13, weight: .medium))
                          Text("This prompt guides how the AI refines your speech.")
                              .font(.caption)
                              .foregroundColor(.secondary)

                          TextEditor(text: $settings.systemPrompt)
                              .frame(minHeight: 200)
                              .font(.system(size: 12, design: .monospaced))
                              .padding(6)
                              .background(
                                  RoundedRectangle(cornerRadius: 6)
                                      .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                              )
                              .background(Color(nsColor: .textBackgroundColor).cornerRadius(6))
                      }
                      .padding(14)
                  }

                  Spacer(minLength: 20)
              }
              .padding(20)
          }
      }

      @ViewBuilder
      private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
          content()
              .background(Color(nsColor: .controlBackgroundColor))
              .cornerRadius(12)
      }
  }
  ```

- [ ] **Step 2: Build**

  Run:
  ```bash
  swift build
  ```
  Expected: success.

- [ ] **Step 3: Commit**

  ```bash
  git add Sources/spk/UI/PromptSettingsView.swift
  git commit -m "feat: add PromptSettingsView for sidebar layout"
  ```

---

### Task 5: Create ShortcutSettingsView

**Files:**
- Create: `Sources/spk/UI/ShortcutSettingsView.swift`

- [ ] **Step 1: Write the file**

  ```swift
  import SwiftUI

  struct ShortcutSettingsView: View {
      @ObservedObject var settings = SettingsManager.shared

      let triggerKeys = ["Fn", "Left Ctrl", "Left Option", "Right Option"]

      var body: some View {
          ScrollView {
              VStack(alignment: .leading, spacing: 16) {
                  Text("Shortcuts")
                      .font(.title2)
                      .fontWeight(.semibold)

                  card {
                      VStack(spacing: 0) {
                          HStack {
                              VStack(alignment: .leading, spacing: 2) {
                                  Text("Hold to Speak")
                                      .font(.system(size: 13, weight: .medium))
                                  Text(settings.isHoldToSpeak ? "Press and hold to record" : "Toggle mode: click to start/stop")
                                      .font(.caption)
                                      .foregroundColor(.secondary)
                              }
                              Spacer()
                              Toggle("", isOn: $settings.isHoldToSpeak)
                                  .toggleStyle(.switch)
                                  .labelsHidden()
                          }
                          .padding(.horizontal, 14)
                          .padding(.vertical, 10)

                          Divider().padding(.leading, 12)

                          HStack {
                              Text("Trigger Key")
                                  .font(.system(size: 13, weight: .medium))
                              Spacer()
                              Picker("", selection: $settings.triggerKey) {
                                  ForEach(triggerKeys, id: \.self) { key in
                                      Text(key).tag(key)
                                  }
                              }
                              .pickerStyle(.menu)
                              .frame(width: 140)
                              .labelsHidden()
                          }
                          .padding(.horizontal, 14)
                          .padding(.vertical, 10)
                      }
                  }

                  VStack(alignment: .leading, spacing: 8) {
                      Text("Usage Hints")
                          .font(.headline)
                      if settings.isHoldToSpeak {
                          Text("• Press and hold the selected key to record.\n• Release to finish.")
                      } else {
                          Text("• Click the key once to start.\n• Click it again to stop.")
                      }
                  }
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .padding(.horizontal, 4)

                  Spacer(minLength: 20)
              }
              .padding(20)
          }
      }

      @ViewBuilder
      private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
          content()
              .padding(.vertical, 8)
              .background(Color(nsColor: .controlBackgroundColor))
              .cornerRadius(12)
      }
  }
  ```

- [ ] **Step 2: Build**

  Run:
  ```bash
  swift build
  ```
  Expected: success.

- [ ] **Step 3: Commit**

  ```bash
  git add Sources/spk/UI/ShortcutSettingsView.swift
  git commit -m "feat: add ShortcutSettingsView for sidebar layout"
  ```

---

### Task 6: Create APISettingsView with timed status card

**Files:**
- Create: `Sources/spk/UI/APISettingsView.swift`

- [ ] **Step 1: Write the file**

  ```swift
  import SwiftUI

  struct APISettingsView: View {
      @ObservedObject var settings = SettingsManager.shared

      @State private var testStatus: String = ""
      @State private var isTesting: Bool = false
      @State private var testDuration: TimeInterval = 0

      var body: some View {
          ScrollView {
              VStack(alignment: .leading, spacing: 16) {
                  Text("API Settings")
                      .font(.title2)
                      .fontWeight(.semibold)

                  card {
                      VStack(spacing: 14) {
                          VStack(alignment: .leading, spacing: 4) {
                              Text("API Base URL")
                                  .font(.system(size: 13, weight: .medium))
                              TextField("", text: $settings.apiBaseURL)
                                  .textFieldStyle(.roundedBorder)
                          }

                          VStack(alignment: .leading, spacing: 4) {
                              Text("API Key")
                                  .font(.system(size: 13, weight: .medium))
                              SecureField("", text: $settings.apiKey)
                                  .textFieldStyle(.roundedBorder)
                          }

                          VStack(alignment: .leading, spacing: 4) {
                              Text("Model")
                                  .font(.system(size: 13, weight: .medium))
                              TextField("", text: $settings.model)
                                  .textFieldStyle(.roundedBorder)
                          }
                      }
                      .padding(14)
                  }

                  // Test Connection
                  HStack(spacing: 12) {
                      Button(action: testConnection) {
                          Label("Test Connection", systemImage: "bolt.horizontal.fill")
                      }
                      .disabled(isTesting || settings.apiKey.isEmpty)

                      if isTesting {
                          ProgressView()
                              .scaleEffect(0.7)
                              .frame(width: 20, height: 20)
                          Text("Testing...")
                              .font(.caption)
                              .foregroundColor(.secondary)
                      }
                  }

                  statusCard

                  Spacer(minLength: 20)
              }
              .padding(20)
          }
      }

      @ViewBuilder
      private var statusCard: some View {
          let borderColor: Color
          let icon: String
          let message: String

          if testStatus.isEmpty {
              borderColor = Color.secondary.opacity(0.3)
              icon = "info.circle"
              message = "点击上方按钮测试连接状态"
          } else if testStatus.contains("Successful") {
              borderColor = .green
              icon = "checkmark.circle.fill"
              message = "\(testStatus)（耗时 \(String(format: "%.2f", testDuration))s）"
          } else {
              borderColor = .red
              icon = "xmark.circle.fill"
              message = "\(testStatus)（耗时 \(String(format: "%.2f", testDuration))s）"
          }

          HStack(alignment: .top, spacing: 8) {
              Image(systemName: icon)
                  .foregroundColor(borderColor)
              Text(message)
                  .font(.system(size: 12))
                  .foregroundColor(.primary)
              Spacer()
          }
          .padding(12)
          .background(Color(nsColor: .controlBackgroundColor))
          .overlay(
              RoundedRectangle(cornerRadius: 10)
                  .stroke(borderColor, lineWidth: 1)
          )
          .cornerRadius(10)
      }

      @ViewBuilder
      private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
          content()
              .background(Color(nsColor: .controlBackgroundColor))
              .cornerRadius(12)
      }

      private func testConnection() {
          isTesting = true
          testStatus = ""
          let start = Date()
          LLMManager.shared.testConnection { result in
              DispatchQueue.main.async {
                  isTesting = false
                  testDuration = Date().timeIntervalSince(start)
                  switch result {
                  case .success(let msg):
                      testStatus = msg
                  case .failure(let error):
                      testStatus = "Error: \(error.localizedDescription)"
                  }
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build**

  Run:
  ```bash
  swift build
  ```
  Expected: success.

- [ ] **Step 3: Commit**

  ```bash
  git add Sources/spk/UI/APISettingsView.swift
  git commit -m "feat: add APISettingsView with timed connection test status card"
  ```

---

### Task 7: Refactor SettingsView as Sidebar container

**Files:**
- Modify: `Sources/spk/UI/SettingsView.swift` (full rewrite)

- [ ] **Step 1: Rewrite SettingsView.swift**

  Replace the entire file with:

  ```swift
  import SwiftUI

  enum SettingsTab: String, CaseIterable {
      case general, api, prompt, shortcuts

      var title: String {
          switch self {
          case .general: return "General"
          case .api: return "API"
          case .prompt: return "Prompt"
          case .shortcuts: return "Shortcuts"
          }
      }

      var icon: String {
          switch self {
          case .general: return "gearshape.fill"
          case .api: return "network"
          case .prompt: return "text.bubble.fill"
          case .shortcuts: return "keyboard.fill"
          }
      }
  }

  struct SettingsView: View {
      @State private var selectedTab: SettingsTab = .general

      var body: some View {
          HStack(spacing: 0) {
              // Sidebar
              VStack(alignment: .leading, spacing: 4) {
                  Text("SPK")
                      .font(.system(size: 13, weight: .bold))
                      .foregroundColor(.primary)
                  Text("Settings")
                      .font(.system(size: 11))
                      .foregroundColor(.secondary)
                      .padding(.bottom, 12)

                  ForEach(SettingsTab.allCases, id: \.self) { tab in
                      Button(action: { selectedTab = tab }) {
                          HStack(spacing: 8) {
                              Image(systemName: tab.icon)
                                  .frame(width: 18)
                              Text(tab.title)
                                  .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                              Spacer()
                          }
                          .padding(.vertical, 6)
                          .padding(.horizontal, 8)
                          .contentShape(Rectangle())
                      }
                      .buttonStyle(.plain)
                      .foregroundColor(selectedTab == tab ? .primary : .secondary)
                      .background(
                          selectedTab == tab
                              ? Color(nsColor: .selectedContentBackgroundColor)
                              : Color.clear
                      )
                      .cornerRadius(6)
                  }

                  Spacer()
              }
              .padding(12)
              .frame(width: 160)
              .background(Color(nsColor: .windowBackgroundColor))

              Divider()

              // Content
              Group {
                  switch selectedTab {
                  case .general:
                      GeneralSettingsView()
                  case .api:
                      APISettingsView()
                  case .prompt:
                      PromptSettingsView()
                  case .shortcuts:
                      ShortcutSettingsView()
                  }
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(Color(nsColor: .windowBackgroundColor))
          }
          .frame(width: 640, height: 420)
      }
  }
  ```

- [ ] **Step 2: Build**

  Run:
  ```bash
  swift build
  ```
  Expected: success.

- [ ] **Step 3: Commit**

  ```bash
  git add Sources/spk/UI/SettingsView.swift
  git commit -m "feat: refactor SettingsView into sidebar layout with 640x420 window"
  ```

---

### Task 8: Final build verification

- [ ] **Step 1: Build the full project**

  Run:
  ```bash
  swift build
  ```
  Expected: success, 0 errors, 0 warnings.

- [ ] **Step 2: Manual UI checklist**

  If you run the app locally (`swift run` or open in Xcode), verify:
  1. Settings window opens at ~640×420 and shows a left sidebar with 4 items.
  2. Clicking each sidebar item switches the right content.
  3. General tab shows 3 toggles inside a rounded card.
  4. API tab shows Base URL / API Key / Model inputs and a "Test Connection" button.
  5. Clicking "Test Connection" shows a loading spinner and then a colored status card with elapsed time.
  6. History menu items are truncated with `...` when text is long.
  7. History menu shows "Clear History..." at the bottom when entries exist.
  8. Clicking "Clear History..." shows an alert; confirming clears the menu.

- [ ] **Step 3: Final commit (if any changes)**

  If any fixes were necessary during verification, commit them. Otherwise just confirm the build is clean.
