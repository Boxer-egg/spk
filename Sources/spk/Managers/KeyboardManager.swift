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

    var pressedKeys = Set<CGKeyCode>()

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
    
    // Internal for testability
    func handleFlagsChanged(_ event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let settings = SettingsManager.shared

        // Match chosen key
        let isMatch: Bool
        let isPressedFromFlags: Bool?

        switch settings.triggerKey {
        case "Fn":
            isMatch = keyCode == fnKeyCode
            isPressedFromFlags = flags.rawValue & 0x800000 != 0
        case "Left Ctrl":
            isMatch = keyCode == leftCtrlCode
            isPressedFromFlags = flags.contains(.maskControl)
        case "Left Option":
            isMatch = keyCode == leftOptionCode
            isPressedFromFlags = flags.contains(.maskAlternate)
        case "Right Option":
            isMatch = keyCode == rightOptionCode
            isPressedFromFlags = nil // Cannot distinguish L/R Option from flags alone
        default:
            return
        }

        guard isMatch else { return }

        let wasPressed = pressedKeys.contains(keyCode)

        // For Option keys (L/R), macOS flagsChanged event itself indicates a state toggle
        // because we cannot distinguish them via flags. For Fn and Ctrl, we can trust flags.
        let isPressed: Bool
        if let isPressedFromFlags = isPressedFromFlags {
            isPressed = isPressedFromFlags
            guard isPressed != wasPressed else { return }
        } else {
            isPressed = !wasPressed
        }

        if isPressed {
            pressedKeys.insert(keyCode)
        } else {
            pressedKeys.remove(keyCode)
        }

        if settings.isHoldToSpeak {
            delegate?.triggerPressed(down: isPressed)
        } else if isPressed {
            delegate?.triggerToggled()
        }
    }
}
