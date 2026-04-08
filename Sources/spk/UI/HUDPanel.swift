import Cocoa
import SwiftUI

class HUDPanel: NSPanel {
    static let shared = HUDPanel()
    
    private var hostingView: NSHostingView<HUDView>?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1), // Initial small size, will resize
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.hidesOnDeactivate = false
        self.appearance = NSAppearance(named: .vibrantDark)
        
        setupHostingView()
    }
    
    private func setupHostingView() {
        let view = HUDView()
        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        
        // Ensure the hosting view itself doesn't have an opaque background
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        
        self.contentView = hosting
        self.hostingView = hosting
        
        // Use constraints to let the hosting view determine its own size,
        // but we'll manually update the window frame to match it.
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: self.contentView!.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: self.contentView!.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: self.contentView!.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: self.contentView!.bottomAnchor)
        ])
    }
    
    func show() {
        updateFrame()
        self.alphaValue = 1
        self.orderFront(nil)
    }
    
    func hide() {
        self.orderOut(nil)
    }
    
    func updateFrame() {
        guard let hostingView = hostingView else { return }
        
        // Calculate the required size based on SwiftUI content
        let targetSize = hostingView.intrinsicContentSize
        if targetSize.width <= 0 || targetSize.height <= 0 { return }
        
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = (screenRect.width - targetSize.width) / 2 + screenRect.minX
            let y = screenRect.minY + 40
            
            let newFrame = NSRect(x: x, y: y, width: targetSize.width, height: targetSize.height)
            self.setFrame(newFrame, display: true, animate: false)
        }
    }
    
    private func centerBottom() {
        updateFrame()
    }
}
