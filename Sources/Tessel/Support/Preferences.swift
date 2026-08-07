import Combine
import Foundation

/// Status bar menu sections that can be hidden via Settings.
enum MenuGroups {
    static let all: [(key: String, title: String)] = [
        ("halves", "Halves"),
        ("maximizeGroup", "Maximize / Center / Restore"),
        ("quarters", "Quarters"),
        ("thirds", "Thirds"),
        ("fourths", "Fourths"),
        ("sixths", "Sixths"),
        ("resizeMove", "Resize & Move"),
        ("stash", "Stash"),
        ("workspaces", "Workspaces"),
        ("customSizes", "Custom Sizes"),
        ("displays", "Displays"),
        ("throwPanel", "Throw Panel"),
    ]
}

final class Preferences: ObservableObject {
    static let shared = Preferences()

    @Published var dragSnapEnabled: Bool {
        didSet { defaults.set(dragSnapEnabled, forKey: Keys.dragSnapEnabled) }
    }
    @Published var showPreviewOverlay: Bool {
        didSet { defaults.set(showPreviewOverlay, forKey: Keys.showPreviewOverlay) }
    }
    @Published var edgeThreshold: Double {
        didSet { defaults.set(edgeThreshold, forKey: Keys.edgeThreshold) }
    }
    @Published var gapSize: Double {
        didSet { defaults.set(gapSize, forKey: Keys.gapSize) }
    }
    @Published var cycleHalves: Bool {
        didSet { defaults.set(cycleHalves, forKey: Keys.cycleHalves) }
    }
    @Published var hideMenuBarIcon: Bool {
        didSet { defaults.set(hideMenuBarIcon, forKey: Keys.hideMenuBarIcon) }
    }
    @Published var ignoredBundleIDs: [String] {
        didSet { defaults.set(ignoredBundleIDs, forKey: Keys.ignoredBundleIDs) }
    }
    /// Drag zone → SnapAction rawValue, or "off". Zones absent from the dict
    /// use their default.
    @Published var zoneActions: [String: String] {
        didSet { defaults.set(zoneActions, forKey: Keys.zoneActions) }
    }
    /// SnapAction rawValue → ["keyCode": Int, "modifiers": Int]. keyCode -1
    /// means "explicitly unassigned" (suppresses the default binding).
    @Published var customShortcuts: [String: [String: Int]] {
        didSet { defaults.set(customShortcuts, forKey: Keys.customShortcuts) }
    }
    @Published var customSizes: [CustomSize] {
        didSet {
            if let data = try? JSONEncoder().encode(customSizes) {
                defaults.set(data, forKey: Keys.customSizes)
            }
        }
    }
    /// Bundle ID of the pinned app (Todo-mode style); nil/empty = no pinning.
    @Published var pinnedBundleID: String? {
        didSet { defaults.set(pinnedBundleID, forKey: Keys.pinnedBundleID) }
    }
    @Published var pinnedSide: String { // "left" | "right"
        didSet { defaults.set(pinnedSide, forKey: Keys.pinnedSide) }
    }
    @Published var pinnedWidthFraction: Double {
        didSet { defaults.set(pinnedWidthFraction, forKey: Keys.pinnedWidthFraction) }
    }
    /// "off" | "control" | "option" | "command" | "shift"
    @Published var doubleTapModifier: String {
        didSet { defaults.set(doubleTapModifier, forKey: Keys.doubleTapModifier) }
    }
    @Published var doubleTapAction: String {
        didSet { defaults.set(doubleTapAction, forKey: Keys.doubleTapAction) }
    }
    /// Menu group keys (see MenuGroups.all) hidden from the status bar menu.
    @Published var hiddenMenuGroups: [String] {
        didSet { defaults.set(hiddenMenuGroups, forKey: Keys.hiddenMenuGroups) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let dragSnapEnabled = "dragSnapEnabled"
        static let showPreviewOverlay = "showPreviewOverlay"
        static let edgeThreshold = "edgeThreshold"
        static let gapSize = "gapSize"
        static let cycleHalves = "cycleHalves"
        static let hideMenuBarIcon = "hideMenuBarIcon"
        static let ignoredBundleIDs = "ignoredBundleIDs"
        static let zoneActions = "zoneActions"
        static let customShortcuts = "customShortcuts"
        static let customSizes = "customSizes"
        static let pinnedBundleID = "pinnedBundleID"
        static let pinnedSide = "pinnedSide"
        static let pinnedWidthFraction = "pinnedWidthFraction"
        static let doubleTapModifier = "doubleTapModifier"
        static let doubleTapAction = "doubleTapAction"
        static let hiddenMenuGroups = "hiddenMenuGroups"
    }

    private init() {
        defaults.register(defaults: [
            Keys.dragSnapEnabled: true,
            Keys.showPreviewOverlay: true,
            Keys.edgeThreshold: 10.0,
            Keys.gapSize: 0.0,
            Keys.cycleHalves: true,
            Keys.hideMenuBarIcon: false,
        ])
        dragSnapEnabled = defaults.bool(forKey: Keys.dragSnapEnabled)
        showPreviewOverlay = defaults.bool(forKey: Keys.showPreviewOverlay)
        edgeThreshold = defaults.double(forKey: Keys.edgeThreshold)
        gapSize = defaults.double(forKey: Keys.gapSize)
        cycleHalves = defaults.bool(forKey: Keys.cycleHalves)
        hideMenuBarIcon = defaults.bool(forKey: Keys.hideMenuBarIcon)
        ignoredBundleIDs = defaults.stringArray(forKey: Keys.ignoredBundleIDs) ?? []
        zoneActions = defaults.dictionary(forKey: Keys.zoneActions) as? [String: String] ?? [:]
        customShortcuts = defaults.dictionary(forKey: Keys.customShortcuts) as? [String: [String: Int]] ?? [:]
        if let data = defaults.data(forKey: Keys.customSizes),
           let sizes = try? JSONDecoder().decode([CustomSize].self, from: data) {
            customSizes = sizes
        } else {
            customSizes = []
        }
        pinnedBundleID = defaults.string(forKey: Keys.pinnedBundleID)
        pinnedSide = defaults.string(forKey: Keys.pinnedSide) ?? "right"
        pinnedWidthFraction = defaults.object(forKey: Keys.pinnedWidthFraction) as? Double ?? 0.25
        doubleTapModifier = defaults.string(forKey: Keys.doubleTapModifier) ?? "off"
        doubleTapAction = defaults.string(forKey: Keys.doubleTapAction) ?? SnapAction.showThrowPanel.rawValue
        hiddenMenuGroups = defaults.stringArray(forKey: Keys.hiddenMenuGroups) ?? []
    }

    // MARK: - Drag zones

    static let defaultZoneActions: [SnapZone.Zone: SnapAction?] = [
        .leftEdge: .leftHalf,
        .rightEdge: .rightHalf,
        .topEdge: .maximize,
        .bottomEdge: nil, // off by default: avoids accidental snaps near the Dock
        .topLeftCorner: .topLeftQuarter,
        .topRightCorner: .topRightQuarter,
        .bottomLeftCorner: .bottomLeftQuarter,
        .bottomRightCorner: .bottomRightQuarter,
    ]

    static let zoneOffValue = "off"

    func action(for zone: SnapZone.Zone) -> SnapAction? {
        if let raw = zoneActions[zone.rawValue] {
            return raw == Self.zoneOffValue ? nil : SnapAction(rawValue: raw)
        }
        return Self.defaultZoneActions[zone] ?? nil
    }

    func setAction(_ action: SnapAction?, for zone: SnapZone.Zone) {
        zoneActions[zone.rawValue] = action?.rawValue ?? Self.zoneOffValue
    }

    // MARK: - Shortcuts

    func setShortcut(for action: SnapAction, keyCode: Int, modifiers: Int) {
        var dict = customShortcuts
        // Evict the same combo from any other action (custom or default).
        for (raw, value) in dict where raw != action.rawValue {
            if value["keyCode"] == keyCode, value["modifiers"] == modifiers {
                dict[raw] = ["keyCode": -1, "modifiers": 0]
            }
        }
        for binding in Keycodes.defaultBindings where binding.action != action {
            if Int(binding.keyCode) == keyCode, Int(binding.modifiers) == modifiers,
               dict[binding.action.rawValue] == nil {
                dict[binding.action.rawValue] = ["keyCode": -1, "modifiers": 0]
            }
        }
        dict[action.rawValue] = ["keyCode": keyCode, "modifiers": modifiers]
        customShortcuts = dict
    }

    func clearShortcut(for action: SnapAction) {
        customShortcuts[action.rawValue] = ["keyCode": -1, "modifiers": 0]
    }

    func resetShortcuts() {
        customShortcuts = [:]
    }

    // MARK: - Export / import

    func exportJSON() -> Data? {
        var snapshot: [String: Any] = [
            Keys.dragSnapEnabled: dragSnapEnabled,
            Keys.showPreviewOverlay: showPreviewOverlay,
            Keys.edgeThreshold: edgeThreshold,
            Keys.gapSize: gapSize,
            Keys.cycleHalves: cycleHalves,
            Keys.hideMenuBarIcon: hideMenuBarIcon,
            Keys.ignoredBundleIDs: ignoredBundleIDs,
            Keys.zoneActions: zoneActions,
            Keys.customShortcuts: customShortcuts,
            Keys.pinnedSide: pinnedSide,
            Keys.pinnedWidthFraction: pinnedWidthFraction,
            Keys.doubleTapModifier: doubleTapModifier,
            Keys.doubleTapAction: doubleTapAction,
            Keys.hiddenMenuGroups: hiddenMenuGroups,
        ]
        if let pinnedBundleID { snapshot[Keys.pinnedBundleID] = pinnedBundleID }
        if let data = try? JSONEncoder().encode(customSizes),
           let sizes = try? JSONSerialization.jsonObject(with: data) {
            snapshot[Keys.customSizes] = sizes
        }
        return try? JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys])
    }

    @discardableResult
    func importJSON(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else { return false }
        if let v = dict[Keys.dragSnapEnabled] as? Bool { dragSnapEnabled = v }
        if let v = dict[Keys.showPreviewOverlay] as? Bool { showPreviewOverlay = v }
        if let v = dict[Keys.edgeThreshold] as? Double { edgeThreshold = v }
        if let v = dict[Keys.gapSize] as? Double { gapSize = v }
        if let v = dict[Keys.cycleHalves] as? Bool { cycleHalves = v }
        if let v = dict[Keys.hideMenuBarIcon] as? Bool { hideMenuBarIcon = v }
        if let v = dict[Keys.ignoredBundleIDs] as? [String] { ignoredBundleIDs = v }
        if let v = dict[Keys.zoneActions] as? [String: String] { zoneActions = v }
        if let v = dict[Keys.pinnedBundleID] as? String { pinnedBundleID = v }
        if let v = dict[Keys.pinnedSide] as? String { pinnedSide = v }
        if let v = dict[Keys.pinnedWidthFraction] as? Double { pinnedWidthFraction = v }
        if let v = dict[Keys.doubleTapModifier] as? String { doubleTapModifier = v }
        if let v = dict[Keys.doubleTapAction] as? String { doubleTapAction = v }
        if let v = dict[Keys.hiddenMenuGroups] as? [String] { hiddenMenuGroups = v }
        if let v = dict[Keys.customSizes],
           let data = try? JSONSerialization.data(withJSONObject: v),
           let sizes = try? JSONDecoder().decode([CustomSize].self, from: data) {
            customSizes = sizes
        }
        if let v = dict[Keys.customShortcuts] as? [String: [String: Int]] {
            customShortcuts = v
        } else if let v = dict[Keys.customShortcuts] as? [String: [String: Any]] {
            // JSON numbers may decode as NSNumber/Double; normalize to Int.
            var normalized: [String: [String: Int]] = [:]
            for (key, value) in v {
                var entry: [String: Int] = [:]
                for (k2, v2) in value {
                    if let n = v2 as? NSNumber { entry[k2] = n.intValue }
                }
                normalized[key] = entry
            }
            customShortcuts = normalized
        }
        return true
    }
}
