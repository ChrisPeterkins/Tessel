import AppKit

/// The translucent highlight showing where a dragged window will land. One
/// reusable borderless window; its frame is in global Cocoa coordinates, so a
/// single instance covers all monitors.
final class PreviewOverlay {
    private let window: NSWindow
    private var currentFrame: CGRect?

    init() {
        window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]

        let view = NSView()
        view.wantsLayer = true
        window.contentView = view
    }

    func show(zoneFrame: CGRect) {
        let target = zoneFrame.insetBy(dx: 4, dy: 4)
        guard currentFrame != target else { return }
        applyStyle()
        if window.isVisible, currentFrame != nil {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                window.animator().setFrame(target, display: true)
            }
        } else {
            window.setFrame(target, display: true)
            window.orderFront(nil)
        }
        currentFrame = target
    }

    func hide() {
        guard currentFrame != nil else { return }
        window.orderOut(nil)
        currentFrame = nil
    }

    private func applyStyle() {
        guard let layer = window.contentView?.layer else { return }
        let accent = NSColor.controlAccentColor
        layer.backgroundColor = accent.withAlphaComponent(0.18).cgColor
        layer.borderColor = accent.withAlphaComponent(0.8).cgColor
        layer.borderWidth = 2
        layer.cornerRadius = 10
    }
}
