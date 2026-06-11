import Cocoa
import Carbon

class ClipboardManager {
    static let shared = ClipboardManager()
    private let maxRestoreAttempts = 3

    func pasteText(_ text: String, keepInClipboard: Bool) {
        let pasteboard = NSPasteboard.general
        let originalItems = pasteboard.pasteboardItems?.map { item in
            let types = item.types
            let dataMap = types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                if let data = item.data(forType: type) {
                    return (type, data)
                }
                return nil
            }
            return dataMap
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let changeCountAfterSet = pasteboard.changeCount

        // simulateCommandV posts CGEvents which must be sent from main thread
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulateCommandV()

            if !keepInClipboard {
                self.scheduleClipboardRestore(
                    pasteboard: pasteboard,
                    originalItems: originalItems,
                    changeCountAfterSet: changeCountAfterSet,
                    attempt: 1
                )
            }
        }
    }

    private func scheduleClipboardRestore(
        pasteboard: NSPasteboard,
        originalItems: [[(NSPasteboard.PasteboardType, Data)]]?,
        changeCountAfterSet: Int,
        attempt: Int
    ) {
        let delay = TimeInterval(attempt) * 1.0

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // If the user manually copied something in between, changeCount will have changed.
            // Do NOT overwrite their clipboard in that case.
            guard pasteboard.changeCount == changeCountAfterSet else {
                return
            }

            self.restoreClipboardContents(pasteboard: pasteboard, originalItems: originalItems)

            // Retry if restore didn't take effect (changeCount still the same) and we haven't exhausted attempts.
            if pasteboard.changeCount == changeCountAfterSet && attempt < self.maxRestoreAttempts {
                self.scheduleClipboardRestore(
                    pasteboard: pasteboard,
                    originalItems: originalItems,
                    changeCountAfterSet: changeCountAfterSet,
                    attempt: attempt + 1
                )
            }
        }
    }

    private func restoreClipboardContents(
        pasteboard: NSPasteboard,
        originalItems: [[(NSPasteboard.PasteboardType, Data)]]?
    ) {
        pasteboard.clearContents()
        if let items = originalItems {
            var newItems: [NSPasteboardItem] = []
            for itemData in items {
                let newItem = NSPasteboardItem()
                for (type, data) in itemData {
                    newItem.setData(data, forType: type)
                }
                newItems.append(newItem)
            }
            pasteboard.writeObjects(newItems)
        }
    }

    private func simulateCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 'v' key
        vKeyDown?.flags = .maskCommand

        let vKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vKeyUp?.flags = .maskCommand

        vKeyDown?.post(tap: .cghidEventTap)
        vKeyUp?.post(tap: .cghidEventTap)
    }
}
