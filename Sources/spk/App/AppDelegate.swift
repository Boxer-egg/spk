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
    
    private var hudShowWorkItem: DispatchWorkItem?
    private var isHudVisible = false
    var settingsWindow: NSWindow?
    var historyMenuItem: NSMenuItem?
    var statsTodayItem: NSMenuItem?
    var statsWordsItem: NSMenuItem?
    var inputDeviceMenuItem: NSMenuItem?

    private var statisticsTodayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "statsCount_" + formatter.string(from: Date())
    }

    private var statisticsTotalWords: Int {
        get { UserDefaults.standard.integer(forKey: "statsTotalWords") }
        set { UserDefaults.standard.set(newValue, forKey: "statsTotalWords") }
    }

    private var statisticsTodayCount: Int {
        get { UserDefaults.standard.integer(forKey: statisticsTodayKey) }
        set { UserDefaults.standard.set(newValue, forKey: statisticsTodayKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Force LSUIElement behavior
        setupMenuBar()
        setupEditMenu() // Enable Copy/Paste
        keyboardManager.delegate = self
        speechManager.delegate = self
        
        checkPermissions()

        let referenced = HistoryManager.shared.getEntries().compactMap { $0.audioFilename }
        AudioRecorderManager.shared.removeOrphanedAudioFiles(referencedFilenames: referenced)

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
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        editMenuItem.submenu = editMenu

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu

        NSApp.mainMenu = mainMenu
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = composedMenuBarIcon(badgeColor: nil)
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
        let langMenuItem = NSMenuItem(title: NSLocalizedString("menu.language", comment: ""), action: nil, keyEquivalent: "")
        langMenuItem.submenu = langMenu
        menu.addItem(langMenuItem)

        // History
        let historyMenu = NSMenu()
        let historyMenuItem = NSMenuItem(title: NSLocalizedString("menu.history", comment: ""), action: nil, keyEquivalent: "")
        historyMenuItem.submenu = historyMenu
        menu.addItem(historyMenuItem)
        self.historyMenuItem = historyMenuItem

        menu.addItem(NSMenuItem.separator())

        // LLM Toggle
        let llmToggle = NSMenuItem(title: NSLocalizedString("menu.llm", comment: ""), action: #selector(toggleLLM), keyEquivalent: "l")
        llmToggle.state = SettingsManager.shared.isLLMEnabled ? .on : .off
        menu.addItem(llmToggle)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.settings", comment: ""), action: #selector(openSettings), keyEquivalent: ","))

        // Statistics Items
        let todayItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        todayItem.isEnabled = false
        menu.addItem(todayItem)
        self.statsTodayItem = todayItem

        let wordsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        wordsItem.isEnabled = false
        menu.addItem(wordsItem)
        self.statsWordsItem = wordsItem

        menu.addItem(NSMenuItem.separator())

        // Input Device
        let deviceMenu = NSMenu()
        let deviceMenuItem = NSMenuItem(title: NSLocalizedString("menu.inputDevice", comment: ""), action: nil, keyEquivalent: "")
        deviceMenuItem.submenu = deviceMenu
        menu.addItem(deviceMenuItem)
        self.inputDeviceMenuItem = deviceMenuItem

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu.quit", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
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
            if let langMenuItem = menu.items.first(where: { $0.title == NSLocalizedString("menu.language", comment: "") }),
               let langMenu = langMenuItem.submenu {
                for item in langMenu.items {
                    item.state = (item.representedObject as? Language == SettingsManager.shared.selectedLanguage) ? .on : .off
                }
            }
            // Update LLM Toggle checkmark
            if let llmItem = menu.items.first(where: { $0.title == NSLocalizedString("menu.llm", comment: "") }) {
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
            settingsWindow?.styleMask = [.titled, .closable, .miniaturizable]
            settingsWindow?.level = .floating
            settingsWindow?.minSize = NSSize(width: 640, height: 840)
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - KeyboardManagerDelegate
    private var isRecording = false
    private var currentAudioFilename: String?

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
        isHudVisible = false
        currentAudioFilename = nil
        
        // Start engine immediately to avoid missing audio
        if SettingsManager.shared.isHistoryAudioEnabled {
            if let url = AudioRecorderManager.shared.startRecording() {
                currentAudioFilename = url.lastPathComponent
            }
        }
        
        do {
            try speechManager.startRecording()
            updateMenuBarIcon(badgeColor: .systemRed)
            HUDViewModel.shared.reset()
            
            // HUD display logic
            hudShowWorkItem?.cancel()
            
            let showWorkItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.isRecording else { return }
                self.isHudVisible = true
                HUDViewModel.shared.isVisible = true
                HUDPanel.shared.show()
            }
            self.hudShowWorkItem = showWorkItem
            
            if SettingsManager.shared.isAntiMisclickEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + SettingsManager.shared.antiMisclickDelay, execute: showWorkItem)
            } else {
                showWorkItem.perform()
            }
            
        } catch {
            print("Failed to start recording: \(error)")
            if SettingsManager.shared.isHistoryAudioEnabled {
                _ = AudioRecorderManager.shared.stopRecording()
            }
            currentAudioFilename = nil
            isRecording = false
            updateMenuBarIcon(badgeColor: nil)
        }
    }
    
    private func stopRecordingProcess() {
        guard isRecording else { return }
        isRecording = false
        
        // Cancel pending HUD show
        hudShowWorkItem?.cancel()
        
        if !isHudVisible {
            // Anti-misclick triggered: short press, HUD was never shown
            speechManager.stopRecording() // This will trigger didFinishWithText, we need to ignore it there
            if SettingsManager.shared.isHistoryAudioEnabled {
                _ = AudioRecorderManager.shared.stopRecording()
                if let filename = currentAudioFilename {
                    let url = AudioRecorderManager.shared.urlForAudio(named: filename)
                    try? FileManager.default.removeItem(at: url)
                }
            }
            updateMenuBarIcon(badgeColor: nil)
            currentAudioFilename = nil
            return
        }
        
        // Normal flow
        speechManager.stopRecording()
        if SettingsManager.shared.isHistoryAudioEnabled {
            _ = AudioRecorderManager.shared.stopRecording()
        }
    }
    
    // MARK: - SpeechManagerDelegate
    func speechManager(_ manager: SpeechManager, didUpdateText text: String) {
        HUDViewModel.shared.text = text
    }
    
    func speechManager(_ manager: SpeechManager, didUpdateVolume volume: Float) {
        HUDViewModel.shared.volume = volume
    }
    
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

        if SettingsManager.shared.isLLMEnabled {
            HUDViewModel.shared.state = .refining
            HUDViewModel.shared.text = text // Show original text while refining
            updateMenuBarIcon(badgeColor: .systemBlue)

            LLMManager.shared.refineText(systemPrompt: "", userText: text) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let refined):
                        HUDViewModel.shared.text = refined
                        HUDViewModel.shared.state = .success
                        ClipboardManager.shared.pasteText(refined, keepInClipboard: SettingsManager.shared.isCopyToClipboardEnabled)
                        HistoryManager.shared.addEntry(originalText: text, refinedText: refined, audioFilename: self.currentAudioFilename)
                    case .failure(let error):
                        print("LLM Error: \(error)")
                        HUDViewModel.shared.state = .error
                        ClipboardManager.shared.pasteText(text, keepInClipboard: SettingsManager.shared.isCopyToClipboardEnabled)
                        HistoryManager.shared.addEntry(originalText: text, refinedText: nil, audioFilename: self.currentAudioFilename)
                    }

                    self.currentAudioFilename = nil

                    // Delay hiding to let user see the final result
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        HUDViewModel.shared.isVisible = false
                        self.updateMenuBarIcon(badgeColor: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            HUDPanel.shared.hide()
                        }
                    }
                }
            }
        } else {
            HUDViewModel.shared.state = .success
            updateMenuBarIcon(badgeColor: nil)
            ClipboardManager.shared.pasteText(text, keepInClipboard: SettingsManager.shared.isCopyToClipboardEnabled)
            HistoryManager.shared.addEntry(originalText: text, refinedText: nil, audioFilename: self.currentAudioFilename)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                HUDViewModel.shared.isVisible = false
                HUDPanel.shared.hide()
            }
            self.currentAudioFilename = nil
        }
    }
    
    func speechManager(_ manager: SpeechManager, didFailWithError error: Error) {
        hudShowWorkItem?.cancel()
        hudShowWorkItem = nil
        
        guard isHudVisible else {
            isHudVisible = false
            return
        }
        
        print("Speech Error: \(error)")
        HUDViewModel.shared.state = .error
        updateMenuBarIcon(badgeColor: nil)
        if SettingsManager.shared.isHistoryAudioEnabled {
            _ = AudioRecorderManager.shared.stopRecording()
        }
        currentAudioFilename = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            HUDViewModel.shared.isVisible = false
            HUDPanel.shared.hide()
        }
    }

    // MARK: - NSMenuDelegate
    func menuWillOpen(_ menu: NSMenu) {
        updateHistoryMenu()
        updateInputDeviceMenu()
        statsTodayItem?.title = String(format: NSLocalizedString("menu.statistics.today", comment: ""), statisticsTodayCount)
        statsWordsItem?.title = String(format: NSLocalizedString("menu.statistics.words", comment: ""), statisticsTotalWords)
    }

    private func updateInputDeviceMenu() {
        guard let deviceMenu = inputDeviceMenuItem?.submenu else { return }
        deviceMenu.removeAllItems()

        let devices = AudioDeviceManager.shared.enumerateInputDevices()
        let systemDefaultItem = NSMenuItem(title: NSLocalizedString("menu.inputDevice.systemDefault", comment: ""), action: #selector(changeInputDevice(_:)), keyEquivalent: "")
        systemDefaultItem.representedObject = nil
        systemDefaultItem.state = SettingsManager.shared.selectedInputDeviceUID.isEmpty ? .on : .off
        deviceMenu.addItem(systemDefaultItem)

        if !devices.isEmpty {
            deviceMenu.addItem(NSMenuItem.separator())
            for device in devices {
                let item = NSMenuItem(title: device.name, action: #selector(changeInputDevice(_:)), keyEquivalent: "")
                item.representedObject = device.uid
                item.state = (device.uid == SettingsManager.shared.selectedInputDeviceUID) ? .on : .off
                deviceMenu.addItem(item)
            }
        }
    }

    @objc func changeInputDevice(_ sender: NSMenuItem) {
        if let uid = sender.representedObject as? String {
            SettingsManager.shared.selectedInputDeviceUID = uid
        } else {
            SettingsManager.shared.selectedInputDeviceUID = ""
        }
        updateMenuStates()
    }

    private func updateHistoryMenu() {
        guard let historyMenu = historyMenuItem?.submenu else { return }
        historyMenu.removeAllItems()

        let entries = HistoryManager.shared.getEntries()
        if entries.isEmpty {
            let item = NSMenuItem(title: NSLocalizedString("menu.history.empty", comment: ""), action: nil, keyEquivalent: "")
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
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.representedObject = entry

                let submenu = NSMenu()
                let pasteItem = NSMenuItem(title: NSLocalizedString("menu.history.paste", comment: ""), action: #selector(pasteHistoryItem(_:)), keyEquivalent: "")
                pasteItem.representedObject = entry
                submenu.addItem(pasteItem)

                let viewOriginalItem = NSMenuItem(title: NSLocalizedString("menu.history.viewOriginal", comment: ""), action: #selector(viewOriginalHistoryItem(_:)), keyEquivalent: "")
                viewOriginalItem.representedObject = entry
                submenu.addItem(viewOriginalItem)

                let openAudioItem = NSMenuItem(title: NSLocalizedString("menu.history.openAudio", comment: ""), action: #selector(openHistoryAudio(_:)), keyEquivalent: "")
                openAudioItem.representedObject = entry
                if entry.audioFilename == nil {
                    openAudioItem.isEnabled = false
                }
                submenu.addItem(openAudioItem)

                item.submenu = submenu
                historyMenu.addItem(item)
            }
            if entries.count > 10 {
                historyMenu.addItem(NSMenuItem.separator())
                let moreItem = NSMenuItem(title: String(format: NSLocalizedString("menu.history.more", comment: ""), entries.count - 10), action: nil, keyEquivalent: "")
                moreItem.isEnabled = false
                historyMenu.addItem(moreItem)
            }
            historyMenu.addItem(NSMenuItem.separator())
            let clearItem = NSMenuItem(title: NSLocalizedString("menu.history.clear", comment: ""), action: #selector(clearHistory(_:)), keyEquivalent: "")
            historyMenu.addItem(clearItem)
        }
    }

    @objc func pasteHistoryItem(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? HistoryEntry else { return }
        let text = entry.refinedText ?? entry.originalText
        ClipboardManager.shared.pasteText(text, keepInClipboard: true)
    }

    @objc func openHistoryAudio(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? HistoryEntry,
              let filename = entry.audioFilename else { return }
        let url = AudioRecorderManager.shared.urlForAudio(named: filename)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func viewOriginalHistoryItem(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? HistoryEntry else { return }
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("menu.history.original.title", comment: "")
        alert.informativeText = entry.originalText
        alert.alertStyle = .informational
        // 复制按钮先添加，使其成为主按钮（蓝色）
        alert.addButton(withTitle: NSLocalizedString("menu.history.original.copy", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("menu.history.original.close", comment: ""))
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(entry.originalText, forType: .string)
        }
    }

    @objc func clearHistory(_ sender: NSMenuItem?) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("menu.history.clear.title", comment: "")
        alert.informativeText = NSLocalizedString("menu.history.clear.message", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("menu.history.clear.confirm", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("menu.history.clear.cancel", comment: ""))
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            HistoryManager.shared.clearHistory()
            updateHistoryMenu()
        }
    }

    private func updateMenuBarIcon(badgeColor: NSColor? = nil) {
        guard let button = statusItem?.button else { return }
        button.image = composedMenuBarIcon(badgeColor: badgeColor)
    }

    private func composedMenuBarIcon(badgeColor: NSColor?) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            if let base = NSImage(systemSymbolName: "waveform.and.mic", accessibilityDescription: "Spk") {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                    .applying(NSImage.SymbolConfiguration(paletteColors: [.labelColor]))
                let configured = base.withSymbolConfiguration(config) ?? base
                configured.draw(in: rect)
            }
            if let color = badgeColor {
                let badgeRadius: CGFloat = 3
                let badgeRect = NSRect(
                    x: rect.maxX - badgeRadius * 2.2,
                    y: rect.maxY - badgeRadius * 2.2,
                    width: badgeRadius * 2,
                    height: badgeRadius * 2
                )
                color.setFill()
                NSBezierPath(ovalIn: badgeRect).fill()
            }
            return true
        }
        return image
    }
}

