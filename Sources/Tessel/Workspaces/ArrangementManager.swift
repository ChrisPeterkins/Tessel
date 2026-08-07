import AppKit
import Combine

/// A saved workspace: every manageable window's app, index, and frame.
struct Arrangement: Codable, Identifiable {
    var id = UUID()
    var name: String
    var displaySignature: String
    var autoApply: Bool = false
    var entries: [Entry]

    struct Entry: Codable {
        var bundleID: String
        var windowIndex: Int
        var frame: CGRect      // absolute Cocoa coords (used when displays match)
        var displayIndex: Int  // index into Displays.ordered at capture time
        var fractional: CGRect // relative to that display's visibleFrame (fallback)
    }
}

/// Captures, persists, and re-applies workspace arrangements; auto-applies a
/// matching flagged arrangement when the display configuration changes.
final class ArrangementManager: ObservableObject {
    @Published private(set) var arrangements: [Arrangement] = []

    private let fileURL: URL
    private var debounceTimer: Timer?

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tessel", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("arrangements.json")
        load()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    static func currentDisplaySignature() -> String {
        Displays.ordered.map { screen in
            let f = screen.frame
            return "\(Int(f.width))x\(Int(f.height))@\(Int(f.minX)),\(Int(f.minY))"
        }.joined(separator: "|")
    }

    func saveCurrent(named name: String) {
        let screens = Displays.ordered
        var entries: [Arrangement.Entry] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let bundleID = app.bundleIdentifier else { continue }
            for (index, window) in AXWindow.windows(ofPID: app.processIdentifier).enumerated() {
                guard window.isManageable, !window.isMinimized else { continue }
                let frame = window.frame
                guard frame.width > 0, frame.height > 0,
                      let screen = Displays.screen(containing: frame),
                      let displayIndex = screens.firstIndex(where: { $0.frame == screen.frame })
                else { continue }
                let v = screen.visibleFrame
                entries.append(Arrangement.Entry(
                    bundleID: bundleID,
                    windowIndex: index,
                    frame: frame,
                    displayIndex: displayIndex,
                    fractional: CGRect(
                        x: (frame.minX - v.minX) / v.width,
                        y: (frame.minY - v.minY) / v.height,
                        width: frame.width / v.width,
                        height: frame.height / v.height
                    )
                ))
            }
        }
        arrangements.append(Arrangement(
            name: name,
            displaySignature: Self.currentDisplaySignature(),
            entries: entries
        ))
        persist()
    }

    func apply(_ arrangement: Arrangement) {
        let screens = Displays.ordered
        let exactDisplayMatch = arrangement.displaySignature == Self.currentDisplaySignature()
        for (bundleID, entries) in Dictionary(grouping: arrangement.entries, by: \.bundleID) {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { continue }
            let windows = AXWindow.windows(ofPID: app.processIdentifier)
            for entry in entries where entry.windowIndex < windows.count {
                let window = windows[entry.windowIndex]
                guard window.isManageable, !window.isMinimized else { continue }
                let target: CGRect
                if exactDisplayMatch {
                    target = entry.frame
                } else {
                    // Different display setup: re-project the fractional frame
                    // onto the same display slot (clamped to what exists).
                    let screen = screens[min(entry.displayIndex, screens.count - 1)]
                    let v = screen.visibleFrame
                    target = CGRect(
                        x: v.minX + entry.fractional.minX * v.width,
                        y: v.minY + entry.fractional.minY * v.height,
                        width: entry.fractional.width * v.width,
                        height: entry.fractional.height * v.height
                    ).integral
                }
                window.setFrame(target)
            }
        }
    }

    func apply(at index: Int) {
        guard arrangements.indices.contains(index) else { return }
        apply(arrangements[index])
    }

    func delete(_ arrangement: Arrangement) {
        arrangements.removeAll { $0.id == arrangement.id }
        persist()
    }

    func setAutoApply(_ enabled: Bool, for arrangement: Arrangement) {
        guard let index = arrangements.firstIndex(where: { $0.id == arrangement.id }) else { return }
        arrangements[index].autoApply = enabled
        persist()
    }

    // MARK: - Private

    @objc private func displaysChanged() {
        // Displays flap while macOS settles; debounce before auto-applying.
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            let signature = Self.currentDisplaySignature()
            if let match = self.arrangements.first(where: { $0.autoApply && $0.displaySignature == signature }) {
                self.apply(match)
            }
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        arrangements = (try? JSONDecoder().decode([Arrangement].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(arrangements) else { return }
        try? data.write(to: fileURL)
    }
}
