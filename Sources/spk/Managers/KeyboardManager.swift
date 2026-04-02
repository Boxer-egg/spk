import Cocoa
import CoreGraphics

protocol KeyboardManagerDelegate: AnyObject {
    func triggerPressed(down: Bool)
    func triggerToggled()
}

class KeyboardManager {
    weak var delegate: KeyboardManagerDelegate?
    private var eventTap: CFMachPort?
    
    private let fnKeyCode: CGKeyCode = 63
    private let leftCtrlCode: CGKeyCode = 59
    private let leftOptionCode: CGKeyCode = 58
    private let rightOptionCode: CGKeyCode = 61
    
    init() {
        setupEventTap()
    }

    private func setupEventTap() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isAppTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !isAppTrusted {
            print("ERROR: Application is not trusted for Accessibility.")
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
                    manager.handleFlagsChanged(event)
                }
                
                return Unmanaged.passRetained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        if let eventTap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }
    
    private func handleFlagsChanged(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let settings = SettingsManager.shared
        
        // Match chosen key
        let isMatch: Bool
        let isPressed: Bool
        
        switch settings.triggerKey {
        case "Fn":
            isMatch = keyCode == Int64(fnKeyCode)
            isPressed = flags.rawValue & 0x800000 != 0
        case "Left Ctrl":
            isMatch = keyCode == Int64(leftCtrlCode)
            isPressed = flags.contains(.maskControl)
        case "Left Option":
            isMatch = keyCode == Int64(leftOptionCode)
            isPressed = flags.contains(.maskAlternate)
        case "Right Option":
            isMatch = keyCode == Int64(rightOptionCode)
            isPressed = flags.contains(.maskAlternate) // macOS doesn't easily distinguish L/R Option in flags alone, but keycode helps
        default:
            return
        }
        
        if isMatch {
            if settings.isHoldToSpeak {
                delegate?.triggerPressed(down: isPressed)
            } else if isPressed {
                delegate?.triggerToggled()
            }
        }
    }
}
