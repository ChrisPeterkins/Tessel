import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences.shared
    private let engine = SnapEngine()
    private let hotkeys = HotkeyManager()
    private let pinManager = PinManager()
    private let stashManager = StashManager()
    private let arrangementManager = ArrangementManager()
    private let throwPanel = ThrowPanelController()
    private let doubleTap = DoubleTapManager()
    private var router: ActionRouter!
    private var dragSnap: DragSnapController?
    private var statusBar: StatusBarController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine.pinManager = pinManager
        router = ActionRouter(engine: engine, stash: stashManager, arrangements: arrangementManager, pin: pinManager)
        router.throwPanel = throwPanel
        throwPanel.onSelect = { [weak self] action, window in
            self?.router.perform(action, on: window)
        }
        throwPanel.onSelectCustomSize = { [weak self] index, window in
            self?.router.applyCustomSize(at: index, on: window)
        }

        statusBar = StatusBarController(router: router)

        hotkeys.onAction = { [weak self] action in self?.router.perform(action) }
        hotkeys.onArrangement = { [weak self] index in self?.router.applyArrangement(at: index) }
        hotkeys.onCustomSize = { [weak self] index in self?.router.applyCustomSize(at: index) }
        hotkeys.arrangementCount = { [weak self] in self?.arrangementManager.arrangements.count ?? 0 }
        hotkeys.customSizeCount = { Preferences.shared.customSizes.count }

        doubleTap.onTrigger = { [weak self] in self?.router.performConfiguredDoubleTapAction() }

        installPreferenceObservers()

        AccessibilityPermission.ensureTrusted { [weak self] in
            self?.startManagedFeatures()
        }
    }

    /// With the menu bar icon hidden, reopening the app (open Tessel.app) is
    /// the way back into settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBar?.showSettings()
        return false
    }

    // MARK: - Private

    private func installPreferenceObservers() {
        preferences.$hideMenuBarIcon
            .dropFirst()
            .sink { [weak self] hidden in
                self?.statusBar?.setIconVisible(!hidden)
            }
            .store(in: &cancellables)

        // receive(on:) defers past @Published's willSet so the new value is
        // readable from Preferences.shared inside the handlers.
        preferences.$customShortcuts
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.hotkeys.reload()
                self?.statusBar?.refresh()
            }
            .store(in: &cancellables)

        preferences.$customSizes
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.hotkeys.reload()
                self?.statusBar?.refresh()
            }
            .store(in: &cancellables)

        arrangementManager.$arrangements
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.hotkeys.reload()
                self?.statusBar?.refresh()
            }
            .store(in: &cancellables)

        preferences.$hiddenMenuGroups
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statusBar?.refresh()
            }
            .store(in: &cancellables)

        preferences.$doubleTapModifier
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, AccessibilityPermission.isTrusted else { return }
                self.doubleTap.reconfigure()
            }
            .store(in: &cancellables)

        preferences.$pinnedBundleID
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pinManager.applyPin()
                self?.statusBar?.refresh()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(preferences.$pinnedSide, preferences.$pinnedWidthFraction)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.pinManager.applyPin()
            }
            .store(in: &cancellables)
    }

    private func startManagedFeatures() {
        statusBar?.accessibilityGranted = true
        hotkeys.start()
        doubleTap.reconfigure()

        let controller = DragSnapController(engine: engine)
        dragSnap = controller
        setDragSnap(enabled: preferences.dragSnapEnabled)

        preferences.$dragSnapEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                self?.setDragSnap(enabled: enabled)
            }
            .store(in: &cancellables)
    }

    private func setDragSnap(enabled: Bool) {
        guard let dragSnap else { return }
        if enabled {
            // A freshly-granted permission sometimes isn't visible to tapCreate
            // until the process relaunches; surface that instead of failing silently.
            if !dragSnap.start() {
                statusBar?.showRelaunchHint = true
            }
        } else {
            dragSnap.stop()
        }
    }
}
