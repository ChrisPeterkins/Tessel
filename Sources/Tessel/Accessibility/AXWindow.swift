import AppKit
import ApplicationServices

// Private but long-stable SPI (used by Rectangle, yabai, etc.) mapping an
// AXUIElement window to its CGWindowID for restore bookkeeping.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: inout CGWindowID) -> AXError

/// Wrapper around an AXUIElement of role AXWindow. All frames exposed by this
/// type are in Cocoa (bottom-left-origin) coordinates.
struct AXWindow {
    let element: AXUIElement
    let pid: pid_t

    // MARK: - Lookup

    static func focused() -> AXWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        var error = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value)
        if error != .success {
            // Some Electron apps expose no AX tree until this is enabled.
            AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            error = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value)
        }
        guard error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let window = AXWindow(element: value as! AXUIElement, pid: app.processIdentifier)
        return window.isManageable ? window : nil
    }

    static func window(atCocoaPoint point: CGPoint) -> AXWindow? {
        let ax = Coordinates.axPoint(fromCocoa: point)
        let systemWide = AXUIElementCreateSystemWide()
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(ax.x), Float(ax.y), &hit) == .success,
              let start = hit else { return nil }

        var candidate = elementAttribute(start, kAXWindowAttribute as String)
        if candidate == nil {
            var current: AXUIElement? = start
            while let el = current {
                if stringAttribute(el, kAXRoleAttribute as String) == kAXWindowRole as String {
                    candidate = el
                    break
                }
                current = elementAttribute(el, kAXParentAttribute as String)
            }
        }
        guard let windowElement = candidate else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(windowElement, &pid) == .success else { return nil }
        let window = AXWindow(element: windowElement, pid: pid)
        return window.isManageable ? window : nil
    }

    static func windows(ofPID pid: pid_t) -> [AXWindow] {
        let appElement = AXUIElementCreateApplication(pid)
        guard let value = copyAttribute(appElement, kAXWindowsAttribute as String),
              let array = value as? [AnyObject] else { return [] }
        return array.compactMap { item in
            guard CFGetTypeID(item) == AXUIElementGetTypeID() else { return nil }
            return AXWindow(element: item as! AXUIElement, pid: pid)
        }
    }

    // MARK: - Properties

    var isMinimized: Bool {
        (Self.copyAttribute(element, kAXMinimizedAttribute as String) as? Bool) ?? false
    }

    func raise() {
        AXUIElementPerformAction(element, "AXRaise" as CFString)
    }

    var isManageable: Bool {
        guard Self.stringAttribute(element, kAXRoleAttribute as String) == kAXWindowRole as String else { return false }
        let subrole = Self.stringAttribute(element, kAXSubroleAttribute as String)
        return subrole != "AXSheet" && subrole != "AXSystemDialog"
    }

    var windowID: CGWindowID? {
        var id: CGWindowID = 0
        guard _AXUIElementGetWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    var isResizable: Bool {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &settable) == .success else { return false }
        return settable.boolValue
    }

    var frame: CGRect {
        var position = CGPoint.zero
        var size = CGSize.zero
        if let value = Self.copyAttribute(element, kAXPositionAttribute as String),
           CFGetTypeID(value) == AXValueGetTypeID() {
            AXValueGetValue(value as! AXValue, .cgPoint, &position)
        }
        if let value = Self.copyAttribute(element, kAXSizeAttribute as String),
           CFGetTypeID(value) == AXValueGetTypeID() {
            AXValueGetValue(value as! AXValue, .cgSize, &size)
        }
        return Coordinates.cocoaFrame(fromAX: CGRect(origin: position, size: size))
    }

    // MARK: - Mutation

    func setFrame(_ cocoaRect: CGRect) {
        let axRect = Coordinates.axFrame(fromCocoa: cocoaRect)
        withEnhancedUserInterfaceDisabled {
            // Size first (apps clamp size against screen edges at the old
            // position), then position, then size again (Terminal re-quantizes
            // to its character grid after moving; some apps clamp minimums late).
            setSize(axRect.size)
            setPosition(axRect.origin)
            setSize(axRect.size)
        }
    }

    /// Moves the window without resizing it. `size` is the window's current
    /// size, needed for the Cocoa→AX Y flip.
    func move(toCocoaOrigin origin: CGPoint, size: CGSize) {
        let axRect = Coordinates.axFrame(fromCocoa: CGRect(origin: origin, size: size))
        withEnhancedUserInterfaceDisabled {
            setPosition(axRect.origin)
        }
    }

    // MARK: - Private

    private func setPosition(_ point: CGPoint) {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    private func setSize(_ size: CGSize) {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else { return }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    /// When AXEnhancedUserInterface is set on the app (VoiceOver, or left stuck
    /// on by some apps), position/size sets get animated and mangled. Disable it
    /// around frame changes and restore afterwards.
    private func withEnhancedUserInterfaceDisabled(_ body: () -> Void) {
        let appElement = AXUIElementCreateApplication(pid)
        let key = "AXEnhancedUserInterface"
        var wasEnabled = false
        if let value = Self.copyAttribute(appElement, key),
           CFGetTypeID(value) == CFBooleanGetTypeID() {
            wasEnabled = CFBooleanGetValue((value as! CFBoolean))
        }
        if wasEnabled {
            AXUIElementSetAttributeValue(appElement, key as CFString, kCFBooleanFalse)
        }
        body()
        if wasEnabled {
            AXUIElementSetAttributeValue(appElement, key as CFString, kCFBooleanTrue)
        }
    }

    private static func copyAttribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = copyAttribute(element, name),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        copyAttribute(element, name) as? String
    }
}
