import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    private var hostingView: NSHostingView<OverlayView>?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Constants.overlayWidth, height: Constants.overlayHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden

        let overlayView = OverlayView()
        let hosting = NSHostingView(rootView: overlayView)
        hosting.frame = self.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        self.contentView?.addSubview(hosting)
        self.hostingView = hosting
    }

    /// Show compact pill at bottom-center of screen
    func showCompact() {
        let w = Constants.compactWidth
        let h = Constants.compactHeight
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - w / 2
            let y = screenFrame.minY + 60
            self.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true, animate: false)
        }
        self.orderFrontRegardless()
    }

    /// Show expanded panel at bottom-center of screen
    func showExpanded() {
        let w = Constants.overlayWidth
        let h = Constants.overlayHeight
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - w / 2
            let y = screenFrame.minY + 60
            self.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true, animate: true)
        }
        self.orderFrontRegardless()
    }

    /// Hide the panel
    func hide() {
        self.orderOut(nil)
    }
}
