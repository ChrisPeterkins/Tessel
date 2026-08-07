import AppKit
import Carbon.HIToolbox

final class StatusBarController: NSObject, NSMenuDelegate {
    private let router: ActionRouter
    private let statusItem: NSStatusItem
    private var settingsController: SettingsWindowController?

    /// Snapshot of the focused window taken when the menu opens, because by the
    /// time a menu item fires, focus may have moved.
    private var snapshotWindow: AXWindow?

    var accessibilityGranted = false {
        didSet { rebuildMenu() }
    }
    var showRelaunchHint = false {
        didSet { rebuildMenu() }
    }

    init(router: ActionRouter) {
        self.router = router
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Tessel")
            image?.isTemplate = true
            button.image = image
        }
        setIconVisible(!Preferences.shared.hideMenuBarIcon)
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        snapshotWindow = AXWindow.focused()
    }

    func refresh() {
        rebuildMenu()
    }

    func setIconVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(arrangements: router.arrangements)
        }
        settingsController?.show()
    }

    // MARK: - Menu construction

    private var hiddenGroups: Set<String> { Set(Preferences.shared.hiddenMenuGroups) }

    private func groupVisible(_ key: String) -> Bool { !hiddenGroups.contains(key) }

    private func rebuildMenu() {
        let bindings = Dictionary(
            uniqueKeysWithValues: Keycodes.effectiveBindings(customShortcuts: Preferences.shared.customShortcuts)
                .map { ($0.action, $0) }
        )
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        if !accessibilityGranted {
            let item = NSMenuItem(
                title: "Grant Accessibility Permission…",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            item.target = self
            menu.addItem(item)
            menu.addItem(.separator())
        }
        if showRelaunchHint {
            let item = NSMenuItem(
                title: "Relaunch Tessel to Finish Setup",
                action: #selector(relaunch),
                keyEquivalent: ""
            )
            item.target = self
            menu.addItem(item)
            menu.addItem(.separator())
        }

        if groupVisible("halves") {
            for action in [SnapAction.leftHalf, .rightHalf, .topHalf, .bottomHalf] {
                menu.addItem(menuItem(for: action, bindings: bindings))
            }
            menu.addItem(.separator())
        }
        if groupVisible("maximizeGroup") {
            for action in [SnapAction.maximize, .almostMaximize, .center, .restore] {
                menu.addItem(menuItem(for: action, bindings: bindings))
            }
            menu.addItem(.separator())
        }

        if groupVisible("quarters") {
            addSubmenu("Quarters", actions: [.topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter], to: menu, bindings: bindings)
        }
        if groupVisible("thirds") {
            addSubmenu("Thirds", actions: [.leftThird, .centerThird, .rightThird, .firstTwoThirds, .lastTwoThirds], to: menu, bindings: bindings)
        }
        if groupVisible("fourths") {
            addSubmenu("Fourths", actions: [.firstFourth, .secondFourth, .thirdFourth, .lastFourth, .firstThreeFourths, .lastThreeFourths], to: menu, bindings: bindings)
        }
        if groupVisible("sixths") {
            addSubmenu("Sixths", actions: [.topLeftSixth, .topCenterSixth, .topRightSixth, .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth], to: menu, bindings: bindings)
        }
        if groupVisible("resizeMove") {
            addSubmenu("Resize & Move", actions: [.maximizeHeight, .larger, .smaller, .moveLeft, .moveRight, .moveUp, .moveDown], to: menu, bindings: bindings)
        }
        if groupVisible("stash") {
            addSubmenu("Stash", actions: [.stashLeft, .stashRight, .unstashAll], to: menu, bindings: bindings)
        }
        if groupVisible("workspaces") {
            addWorkspacesSubmenu(to: menu)
        }
        if groupVisible("customSizes"), !Preferences.shared.customSizes.isEmpty {
            addCustomSizesSubmenu(to: menu)
        }

        menu.addItem(.separator())
        if groupVisible("throwPanel") {
            menu.addItem(menuItem(for: .showThrowPanel, bindings: bindings))
        }
        if groupVisible("displays") {
            for action in [SnapAction.nextDisplay, .previousDisplay] {
                menu.addItem(menuItem(for: action, bindings: bindings))
            }
        }

        menu.addItem(.separator())
        addPinItems(to: menu)

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettingsItem), keyEquivalent: ",")
        settings.keyEquivalentModifierMask = [.command]
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Tessel", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = [.command]
        quit.target = NSApp
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func addWorkspacesSubmenu(to menu: NSMenu) {
        let item = NSMenuItem(title: "Workspaces", action: nil, keyEquivalent: "")
        item.isEnabled = accessibilityGranted
        let submenu = NSMenu(title: "Workspaces")
        submenu.autoenablesItems = false

        for (index, arrangement) in router.arrangements.arrangements.enumerated() {
            let entry = NSMenuItem(title: arrangement.name, action: #selector(applyArrangement(_:)), keyEquivalent: index < 9 ? "\(index + 1)" : "")
            entry.keyEquivalentModifierMask = [.control, .option]
            entry.target = self
            entry.representedObject = index
            entry.isEnabled = accessibilityGranted
            submenu.addItem(entry)
        }
        if !router.arrangements.arrangements.isEmpty {
            submenu.addItem(.separator())
        }
        let save = NSMenuItem(title: "Save Current Workspace…", action: #selector(saveWorkspace), keyEquivalent: "")
        save.target = self
        save.isEnabled = accessibilityGranted
        submenu.addItem(save)

        item.submenu = submenu
        menu.addItem(item)
    }

    private func addCustomSizesSubmenu(to menu: NSMenu) {
        let item = NSMenuItem(title: "Custom Sizes", action: nil, keyEquivalent: "")
        item.isEnabled = accessibilityGranted
        let submenu = NSMenu(title: "Custom Sizes")
        submenu.autoenablesItems = false
        for (index, size) in Preferences.shared.customSizes.enumerated() {
            let entry = NSMenuItem(title: size.name, action: #selector(applyCustomSize(_:)), keyEquivalent: index < 9 ? "\(index + 1)" : "")
            entry.keyEquivalentModifierMask = [.control, .option, .shift]
            entry.target = self
            entry.representedObject = index
            entry.isEnabled = accessibilityGranted
            submenu.addItem(entry)
        }
        item.submenu = submenu
        menu.addItem(item)
    }

    private func addPinItems(to menu: NSMenu) {
        if let bundleID = Preferences.shared.pinnedBundleID, !bundleID.isEmpty {
            let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
                .map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID
            let unpin = NSMenuItem(title: "Unpin \(name)", action: #selector(unpinApp), keyEquivalent: "")
            unpin.target = self
            unpin.isEnabled = accessibilityGranted
            menu.addItem(unpin)
        } else {
            let pin = NSMenuItem(title: "Pin Frontmost App", action: #selector(pinFrontmost), keyEquivalent: "")
            pin.target = self
            pin.isEnabled = accessibilityGranted
            menu.addItem(pin)
        }
    }

    private func addSubmenu(_ title: String, actions: [SnapAction], to menu: NSMenu, bindings: [SnapAction: Keycodes.Binding]) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = accessibilityGranted
        let submenu = NSMenu(title: title)
        submenu.autoenablesItems = false
        for action in actions {
            submenu.addItem(menuItem(for: action, bindings: bindings))
        }
        item.submenu = submenu
        menu.addItem(item)
    }

    private func menuItem(for action: SnapAction, bindings: [SnapAction: Keycodes.Binding]) -> NSMenuItem {
        let binding = bindings[action]
        let item = NSMenuItem(
            title: action.title,
            action: #selector(performSnap(_:)),
            keyEquivalent: keyEquivalent(for: binding)
        )
        item.keyEquivalentModifierMask = modifierMask(for: binding)
        item.target = self
        item.representedObject = action.rawValue
        item.isEnabled = accessibilityGranted
        return item
    }

    /// Key equivalents on these items are display-only (the Carbon hotkeys do
    /// the real work); they give the menu the standard shortcut column.
    private func keyEquivalent(for binding: Keycodes.Binding?) -> String {
        guard let binding else { return "" }
        switch Int(binding.keyCode) {
        case kVK_LeftArrow: return String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        case kVK_RightArrow: return String(UnicodeScalar(NSRightArrowFunctionKey)!)
        case kVK_UpArrow: return String(UnicodeScalar(NSUpArrowFunctionKey)!)
        case kVK_DownArrow: return String(UnicodeScalar(NSDownArrowFunctionKey)!)
        case kVK_Return: return "\r"
        case kVK_Delete: return "\u{8}"
        case kVK_Space: return " "
        default:
            let label = Keycodes.keyLabel(for: binding.keyCode)
            return label.count == 1 ? label.lowercased() : ""
        }
    }

    private func modifierMask(for binding: Keycodes.Binding?) -> NSEvent.ModifierFlags {
        guard let binding else { return [] }
        var flags: NSEvent.ModifierFlags = []
        if binding.modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if binding.modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if binding.modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if binding.modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        return flags
    }

    // MARK: - Actions

    @objc private func performSnap(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let action = SnapAction(rawValue: raw) else { return }
        router.perform(action, on: snapshotWindow ?? AXWindow.focused())
    }

    @objc private func applyArrangement(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        router.applyArrangement(at: index)
    }

    @objc private func applyCustomSize(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        router.applyCustomSize(at: index, on: snapshotWindow ?? AXWindow.focused())
    }

    @objc private func saveWorkspace() {
        let alert = NSAlert()
        alert.messageText = "Save Current Workspace"
        alert.informativeText = "Every visible window's position will be captured."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "Workspace name"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.isEmpty ? "Workspace \(router.arrangements.arrangements.count + 1)" : field.stringValue
        router.arrangements.saveCurrent(named: name)
    }

    @objc private func pinFrontmost() {
        // The frontmost app at click time is Tessel's menu context; use the
        // snapshot window's app instead.
        if let window = snapshotWindow,
           let app = NSRunningApplication(processIdentifier: window.pid),
           let bundleID = app.bundleIdentifier,
           bundleID != Bundle.main.bundleIdentifier {
            Preferences.shared.pinnedBundleID = bundleID
            router.pin.applyPin()
        } else {
            router.pin.pinFrontmost()
        }
        rebuildMenu()
    }

    @objc private func unpinApp() {
        router.pin.unpin()
        rebuildMenu()
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermission.openSystemSettings()
    }

    @objc private func openSettingsItem() {
        showSettings()
    }

    @objc private func relaunch() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }
}
