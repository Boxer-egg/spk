import Cocoa
import Carbon

class ClipboardManager {
    static let shared = ClipboardManager()
    
    func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        let originalItems = pasteboard.pasteboardItems
        
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Handle CJK switching if needed (optional implementation for now)
        // simulateCommandV()
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            self.simulateCommandV()
            
            // Restore original pasteboard content after a short delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                if let _ = originalItems {
                    // This is a simplification; full restoration is more complex
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
