import Cocoa
import Carbon

class ClipboardManager {
    static let shared = ClipboardManager()
    
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
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            self.simulateCommandV()
            
            // Only restore if keepInClipboard is false
            if !keepInClipboard {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
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
            }
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
