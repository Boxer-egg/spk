import Cocoa
import CoreGraphics

protocol KeyboardManagerDelegate: AnyObject {
    func fnKeyPressed(down: Bool)
}

class KeyboardManager {
    weak var delegate: KeyboardManagerDelegate?
    private var eventTap: CFMachPort?
    private let fnKeyCode: CGKeyCode = 63 // Fn key on most Apple keyboards

    init() {
        setupEventTap()
    }

    private func setupEventTap() {
        // Check if we have accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isAppTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("Accessibility Trust Status: \(isAppTrusted)")
        
        if !isAppTrusted {
            print("ERROR: Application is not trusted for Accessibility. Please enable it in System Settings.")
            // Even if not trusted, we try to create the tap; it will return nil if unauthorized.
        }

        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<KeyboardManager>.fromOpaque(refcon).takeUnretainedValue()
                
                if type == .flagsChanged {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let flags = event.flags
                    print("KeyChanged: keyCode=\(keyCode), flags=\(flags.rawValue)")
                    
                    if keyCode == Int64(manager.fnKeyCode) {
                        // Fn key logic: bit 23 is often the secondary Fn mask
                        let isDown = flags.rawValue & 0x800000 != 0
                        print("Fn Key detected: \(isDown ? "DOWN" : "UP")")
                        manager.delegate?.fnKeyPressed(down: isDown)
                    }
                }
                
                return Unmanaged.passRetained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        if let eventTap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        } else {
            print("Failed to create event tap. Make sure Accessibility permissions are granted.")
        }
    }
}
