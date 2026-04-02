import Cocoa
import SwiftUI

class HUDPanel: NSPanel {
    static let shared = HUDPanel()
    
    private var hostingView: NSHostingView<HUDView>?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hasShadow = false
        self.ignoresMouseEvents = true
        
        setupHostingView()
    }
    
    private func setupHostingView() {
        let view = HUDView()
        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        self.contentView = hosting
        self.hostingView = hosting
        
        NSLayoutConstraint.activate([
            hosting.centerXAnchor.constraint(equalTo: self.contentView!.centerXAnchor),
            hosting.centerYAnchor.constraint(equalTo: self.contentView!.centerYAnchor)
        ])
    }
    
    func show() {
        self.centerBottom()
        self.alphaValue = 1 // HUDView handles inner animation via viewModel.isVisible
        self.orderFront(nil)
    }
    
    func hide() {
        self.orderOut(nil)
    }
    
    private func centerBottom() {
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = (screenRect.width - self.frame.width) / 2 + screenRect.minX
            let y = screenRect.minY + 40
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
