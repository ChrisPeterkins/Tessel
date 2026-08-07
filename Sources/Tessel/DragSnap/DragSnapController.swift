import AppKit
import ApplicationServices
import QuartzCore

/// Watches mouse events through a listen-only CGEventTap and turns "user
/// dragged a window to a screen edge" into snap actions, with a live preview
/// overlay. Distinguishes window drags from text selection/resizes by checking
/// that the window under the cursor actually moves with the mouse at constant
/// size.
final class DragSnapController {
    private let engine: SnapEngine
    private let overlay = PreviewOverlay()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private struct DragTracking {
        var startCocoa: CGPoint
        var window: AXWindow?
        var frameAtResolution: CGRect?
        var mouseAtResolution: CGPoint?
        var preDragFrame: CGRect?
        var confirmed = false
        var aborted = false
        var lastPoll: CFTimeInterval = 0
        var zone: SnapAction?
        var zoneScreenFrame: CGRect?
    }

    private var drag: DragTracking?

    init(engine: SnapEngine) {
        self.engine = engine
    }

    /// Returns false when the event tap could not be created (usually means the
    /// Accessibility grant needs a process relaunch to take effect).
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                if let userInfo {
                    let controller = Unmanaged<DragSnapController>.fromOpaque(userInfo).takeUnretainedValue()
                    controller.handle(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        overlay.hide()
        drag = nil
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
    }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        case .leftMouseDown:
            drag = DragTracking(startCocoa: Coordinates.cocoaPoint(fromAX: event.location))
        case .leftMouseDragged:
            handleDragged(event)
        case .leftMouseUp:
            handleUp()
        default:
            break
        }
    }

    private func handleDragged(_ event: CGEvent) {
        guard var d = drag, !d.aborted else { return }
        let mouse = Coordinates.cocoaPoint(fromAX: event.location)

        // Resolve the window under the mouse-down point once, after a small
        // debounce so ordinary clicks never pay the AX hit-test cost.
        if d.window == nil {
            let travel = hypot(mouse.x - d.startCocoa.x, mouse.y - d.startCocoa.y)
            guard travel > 20 else { return }
            guard let window = AXWindow.window(atCocoaPoint: d.startCocoa),
                  !engine.isIgnored(window) else {
                d.aborted = true
                drag = d
                return
            }
            let frame = window.frame
            d.window = window
            d.frameAtResolution = frame
            d.mouseAtResolution = mouse
            // Estimate the pre-drag frame by rolling back the mouse travel so far.
            d.preDragFrame = frame.offsetBy(dx: d.startCocoa.x - mouse.x, dy: d.startCocoa.y - mouse.y)
            drag = d
            return
        }

        if !d.confirmed {
            // Poll the window's frame at ~30 Hz until we can classify the drag.
            let now = CACurrentMediaTime()
            guard now - d.lastPoll > 1.0 / 30.0 else { return }
            d.lastPoll = now

            guard let window = d.window,
                  let frameAtRes = d.frameAtResolution,
                  let mouseAtRes = d.mouseAtResolution else { return }
            let current = window.frame

            if abs(current.width - frameAtRes.width) > 2 || abs(current.height - frameAtRes.height) > 2 {
                d.aborted = true // size changed: this is a resize, not a move
                drag = d
                return
            }
            let mouseDelta = CGPoint(x: mouse.x - mouseAtRes.x, y: mouse.y - mouseAtRes.y)
            let windowDelta = CGPoint(x: current.minX - frameAtRes.minX, y: current.minY - frameAtRes.minY)
            let windowMoved = hypot(windowDelta.x, windowDelta.y) > 5
            let tracksMouse = abs(windowDelta.x - mouseDelta.x) < 20 && abs(windowDelta.y - mouseDelta.y) < 20

            if windowMoved && tracksMouse {
                d.confirmed = true
            } else if hypot(mouseDelta.x, mouseDelta.y) > 150 {
                d.aborted = true // mouse traveled far but the window stayed: text selection etc.
            }
            drag = d
            guard d.confirmed else { return }
        }

        // Confirmed window drag: zone hit-testing on the cursor's screen. What
        // each zone does is remappable in Preferences.
        guard Preferences.shared.dragSnapEnabled,
              let screen = Displays.screen(containingPoint: mouse) else { return }
        let config = SnapZone.Config(
            edgeThreshold: CGFloat(Preferences.shared.edgeThreshold),
            cornerSize: 100
        )
        let zone = SnapZone.zone(at: mouse, screenFrame: screen.frame, config: config)
        let action = zone.flatMap { Preferences.shared.action(for: $0) }

        if action != d.zone || screen.frame != d.zoneScreenFrame {
            d.zone = action
            d.zoneScreenFrame = screen.frame
            drag = d
            if let action,
               Preferences.shared.showPreviewOverlay,
               let target = SnapLayout.target(
                   for: action,
                   on: engine.workArea(for: screen, pid: d.window?.pid),
                   gap: CGFloat(Preferences.shared.gapSize)
               ) {
                overlay.show(zoneFrame: target)
            } else {
                overlay.hide()
            }
        }
    }

    private func handleUp() {
        defer {
            drag = nil
            overlay.hide()
        }
        guard let d = drag, d.confirmed, !d.aborted,
              let action = d.zone,
              let screenFrame = d.zoneScreenFrame,
              let window = d.window,
              let preDrag = d.preDragFrame,
              Preferences.shared.dragSnapEnabled,
              let screen = NSScreen.screens.first(where: { $0.frame == screenFrame })
        else { return }

        let engine = self.engine
        // Defer one run-loop cycle so the dragged app finishes its own
        // mouse-up handling before we reposition its window.
        DispatchQueue.main.async {
            engine.snapFromDrag(window, action: action, preDragFrame: preDrag, on: screen)
        }
    }
}
