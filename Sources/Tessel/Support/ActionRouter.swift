import AppKit

/// Single dispatch point for every trigger source (hotkeys, menu, throw panel,
/// double-tap): routes snap actions to the engine and app-level actions
/// (stash, throw panel) to their managers.
final class ActionRouter {
    let engine: SnapEngine
    let stash: StashManager
    let arrangements: ArrangementManager
    let pin: PinManager
    var throwPanel: ThrowPanelController?

    init(engine: SnapEngine, stash: StashManager, arrangements: ArrangementManager, pin: PinManager) {
        self.engine = engine
        self.stash = stash
        self.arrangements = arrangements
        self.pin = pin
    }

    func perform(_ action: SnapAction, on window: AXWindow? = nil) {
        let target = window ?? AXWindow.focused()
        switch action {
        case .showThrowPanel:
            throwPanel?.toggle()
        case .stashLeft:
            guard let target, !engine.isIgnored(target) else { return }
            stash.toggleStash(target, edge: .left)
        case .stashRight:
            guard let target, !engine.isIgnored(target) else { return }
            stash.toggleStash(target, edge: .right)
        case .unstashAll:
            stash.unstashAll()
        default:
            engine.perform(action, on: target)
        }
    }

    func applyArrangement(at index: Int) {
        arrangements.apply(at: index)
    }

    func applyCustomSize(at index: Int, on window: AXWindow? = nil) {
        let sizes = Preferences.shared.customSizes
        guard sizes.indices.contains(index) else { return }
        engine.applyCustomSize(sizes[index], on: window ?? AXWindow.focused())
    }

    func performConfiguredDoubleTapAction() {
        guard let action = SnapAction(rawValue: Preferences.shared.doubleTapAction) else { return }
        perform(action)
    }
}
