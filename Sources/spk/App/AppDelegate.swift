import Cocoa
import SwiftUI
import Speech
import AVFoundation

@main
class AppDelegate: NSObject, NSApplicationDelegate, KeyboardManagerDelegate, SpeechManagerDelegate, NSMenuDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    var statusItem: NSStatusItem?
    let keyboardManager = KeyboardManager()
    let speechManager = SpeechManager()
    let hudPanel = HUDPanel.shared
    
    var settingsWindow: NSWindow?
    var historyMenuItem: NSMenuItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Force LSUIElement behavior
        setupMenuBar()
        setupEditMenu() // Enable Copy/Paste
        keyboardManager.delegate = self
        speechManager.delegate = self
        
        checkPermissions()
        
        // Initial language
        speechManager.setLanguage(SettingsManager.shared.selectedLanguage)
    }
    
    private func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            print("Speech Recognition Status: \(status.rawValue)")
        }
        
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            print("Microphone Access Granted: \(granted)")
        }
    }
    
    private func setupEditMenu() {
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        editMenuItem.submenu = editMenu
        NSApp.mainMenu = mainMenu
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Spk")
        }
        
        let menu = NSMenu()
        
        // Languages
        let langMenu = NSMenu()
        for lang in Language.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            item.representedObject = lang
            item.state = (lang == SettingsManager.shared.selectedLanguage) ? .on : .off
            langMenu.addItem(item)
        }
        let langMenuItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        langMenuItem.submenu = langMenu
        menu.addItem(langMenuItem)

        // History
        let historyMenu = NSMenu()
        let historyMenuItem = NSMenuItem(title: "History", action: nil, keyEquivalent: "")
        historyMenuItem.submenu = historyMenu
        menu.addItem(historyMenuItem)
        self.historyMenuItem = historyMenuItem

        menu.addItem(NSMenuItem.separator())
        
        // LLM Toggle
        let llmToggle = NSMenuItem(title: "LLM Correction", action: #selector(toggleLLM), keyEquivalent: "l")
        llmToggle.state = SettingsManager.shared.isLLMEnabled ? .on : .off
        menu.addItem(llmToggle)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.delegate = self
        statusItem?.menu = menu
    }
    
    @objc func changeLanguage(_ sender: NSMenuItem) {
        if let lang = sender.representedObject as? Language {
            SettingsManager.shared.selectedLanguage = lang
            speechManager.setLanguage(lang)
            updateMenuStates()
        }
    }
    
    @objc func toggleLLM() {
        SettingsManager.shared.isLLMEnabled.toggle()
        updateMenuStates()
    }
    
    private func updateMenuStates() {
        if let menu = statusItem?.menu {
            // Update Language checkmarks
            if let langMenu = menu.item(withTitle: "Language")?.submenu {
                for item in langMenu.items {
                    item.state = (item.representedObject as? Language == SettingsManager.shared.selectedLanguage) ? .on : .off
                }
            }
            // Update LLM Toggle checkmark
            if let llmItem = menu.item(withTitle: "LLM Correction") {
                llmItem.state = SettingsManager.shared.isLLMEnabled ? .on : .off
            }
        }
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView()
            let controller = NSHostingController(rootView: view)
            settingsWindow = NSWindow(contentViewController: controller)
            settingsWindow?.title = "Spk Settings"
            settingsWindow?.styleMask = [.titled, .closable]
            settingsWindow?.level = .floating
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - KeyboardManagerDelegate
    private var isRecording = false

    func triggerPressed(down: Bool) {
        if down {
            startRecordingProcess()
        } else {
            stopRecordingProcess()
        }
    }
    
    func triggerToggled() {
        if isRecording {
            stopRecordingProcess()
        } else {
            startRecordingProcess()
        }
    }
    
    private func startRecordingProcess() {
        guard !isRecording else { return }
        isRecording = true
        HUDViewModel.shared.reset()
        HUDViewModel.shared.isVisible = true
        HUDPanel.shared.show()
        do {
            try speechManager.startRecording()
        } catch {
            print("Failed to start recording: \(error)")
            HUDViewModel.shared.state = .error
            isRecording = false
        }
    }
    
    private func stopRecordingProcess() {
        guard isRecording else { return }
        isRecording = false
        speechManager.stopRecording()
    }
    
    // MARK: - SpeechManagerDelegate
    func speechManager(_ manager: SpeechManager, didUpdateText text: String) {
        HUDViewModel.shared.text = text
    }
    
    func speechManager(_ manager: SpeechManager, didUpdateVolume volume: Float) {
        HUDViewModel.shared.volume = volume
    }
    
    func speechManager(_ manager: SpeechManager, didFinishWithText text: String) {
        if SettingsManager.shared.isLLMEnabled {
            HUDViewModel.shared.state = .refining
            HUDViewModel.shared.text = text // Show original text while refining
            
            LLMManager.shared.refineText(text) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let refined):
                        HUDViewModel.shared.text = refined
                        HUDViewModel.shared.state = .success
                        ClipboardManager.shared.pasteText(refined, keepInClipboard: SettingsManager.shared.isCopyToClipboardEnabled)
                        HistoryManager.shared.addEntry(originalText: text, refinedText: refined)
                    case .failure(let error):
                        print("LLM Error: \(error)")
                        HUDViewModel.shared.state = .error
                        ClipboardManager.shared.pasteText(text, keepInClipboard: SettingsManager.shared.isCopyToClipboardEnabled)
                        HistoryManager.shared.addEntry(originalText: text, refinedText: nil)
                    }
                    
                    // Delay hiding to let user see the final result
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        HUDViewModel.shared.isVisible = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            HUDPanel.shared.hide()
                        }
                    }
                }
            }
        } else {
            HUDViewModel.shared.state = .success
            ClipboardManager.shared.pasteText(text, keepInClipboard: SettingsManager.shared.isCopyToClipboardEnabled)
            HistoryManager.shared.addEntry(originalText: text, refinedText: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                HUDViewModel.shared.isVisible = false
                HUDPanel.shared.hide()
            }
        }
    }
    
    func speechManager(_ manager: SpeechManager, didFailWithError error: Error) {
        print("Speech Error: \(error)")
        HUDViewModel.shared.state = .error
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            HUDViewModel.shared.isVisible = false
            HUDPanel.shared.hide()
        }
    }

    // MARK: - NSMenuDelegate
    func menuWillOpen(_ menu: NSMenu) {
        updateHistoryMenu()
    }

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
                    if prefix.count >= maxChars - 3 {
                        title = String(prefix.prefix(maxChars - 3)) + "..."
                    } else {
                        let remain = maxChars - prefix.count - 3
                        title = prefix + String(text.prefix(remain)) + "..."
                    }
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

    @objc func selectHistoryItem(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? HistoryEntry else { return }
        // 将文本复制到剪贴板或粘贴？
        // 暂时仅复制到剪贴板
        let text = entry.refinedText ?? entry.originalText
        ClipboardManager.shared.pasteText(text, keepInClipboard: true)
    }

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
}
