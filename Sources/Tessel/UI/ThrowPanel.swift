import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The Window Throw panel: ⌃⌥Space (or double-tap) opens a floating grid of
/// snap targets; one unmodified keystroke (or a click) throws the focused
/// window there. The panel is non-activating so the target window keeps focus.
final class ThrowPanelController {
    /// (action, window captured when the panel opened)
    var onSelect: ((SnapAction, AXWindow?) -> Void)?
    var onSelectCustomSize: ((Int, AXWindow?) -> Void)?

    private var panel: NSPanel?
    private var keyMonitor: Any?
    private var snapshotWindow: AXWindow?

    static let targets: [(action: SnapAction, hint: String, keyCode: Int)] = [
        (.leftHalf, "←", kVK_LeftArrow), (.rightHalf, "→", kVK_RightArrow),
        (.topHalf, "↑", kVK_UpArrow), (.bottomHalf, "↓", kVK_DownArrow),
        (.topLeftQuarter, "U", kVK_ANSI_U), (.topRightQuarter, "I", kVK_ANSI_I),
        (.bottomLeftQuarter, "J", kVK_ANSI_J), (.bottomRightQuarter, "K", kVK_ANSI_K),
        (.leftThird, "D", kVK_ANSI_D), (.centerThird, "F", kVK_ANSI_F),
        (.rightThird, "G", kVK_ANSI_G), (.firstTwoThirds, "E", kVK_ANSI_E),
        (.lastTwoThirds, "T", kVK_ANSI_T), (.maximize, "↩", kVK_Return),
        (.almostMaximize, "A", kVK_ANSI_A), (.center, "C", kVK_ANSI_C),
    ]

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        isVisible ? close() : show()
    }

    func show() {
        snapshotWindow = AXWindow.focused()

        let content = ThrowPanelView(
            customSizes: Preferences.shared.customSizes,
            onSelect: { [weak self] action in self?.select(action) },
            onSelectCustomSize: { [weak self] index in self?.selectCustomSize(index) }
        )
        let hosting = NSHostingController(rootView: content)

        let panel = KeyablePanel(contentViewController: hosting)
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.setContentSize(hosting.view.fittingSize)

        // Center on the screen holding the focused window (fall back to main).
        let screen = snapshotWindow.flatMap { Displays.screen(containing: $0.frame) } ?? NSScreen.main
        if let screen {
            let v = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(CGPoint(
                x: v.midX - size.width / 2,
                y: v.midY - size.height / 2
            ))
        }

        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func close() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
        snapshotWindow = nil
    }

    // MARK: - Private

    private func select(_ action: SnapAction) {
        let window = snapshotWindow
        close()
        onSelect?(action, window)
    }

    private func selectCustomSize(_ index: Int) {
        let window = snapshotWindow
        close()
        onSelectCustomSize?(index, window)
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }
            let code = Int(event.keyCode)
            if code == kVK_Escape || code == kVK_Space {
                self.close()
                return nil
            }
            if let target = Self.targets.first(where: { $0.keyCode == code }) {
                self.select(target.action)
                return nil
            }
            // Digits 1–9 apply custom sizes.
            let digits = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                          kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
            if let index = digits.firstIndex(of: code),
               Preferences.shared.customSizes.indices.contains(index) {
                self.selectCustomSize(index)
                return nil
            }
            return nil // swallow everything else while the panel is up
        }
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - SwiftUI content

private struct ThrowPanelView: View {
    let customSizes: [CustomSize]
    let onSelect: (SnapAction) -> Void
    let onSelectCustomSize: (Int) -> Void

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(96), spacing: 8), count: 4), spacing: 8) {
                ForEach(ThrowPanelController.targets, id: \.action) { target in
                    ThrowCell(action: target.action, hint: target.hint) {
                        onSelect(target.action)
                    }
                }
            }
            if !customSizes.isEmpty {
                Divider()
                HStack(spacing: 8) {
                    ForEach(Array(customSizes.prefix(9).enumerated()), id: \.element.id) { index, size in
                        Button {
                            onSelectCustomSize(index)
                        } label: {
                            VStack(spacing: 2) {
                                Text(size.name).font(.caption)
                                Text("\(index + 1)").font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            Text("Press a key to throw the window · Esc to dismiss")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary))
        .padding(8)
    }
}

private struct ThrowCell: View {
    let action: SnapAction
    let hint: String
    let select: () -> Void

    @State private var hovering = false

    private static let diagram = CGRect(x: 0, y: 0, width: 72, height: 45)

    var body: some View {
        let region = SnapLayout.target(for: action, on: Self.diagram) ?? Self.diagram
        Button(action: select) {
            VStack(spacing: 4) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.quaternary)
                        .frame(width: Self.diagram.width, height: Self.diagram.height)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.75))
                        .frame(width: region.width, height: region.height)
                        // SwiftUI is top-left-origin; SnapLayout is Cocoa
                        // (bottom-left), so flip the Y offset.
                        .offset(x: region.minX, y: Self.diagram.height - region.maxY)
                }
                HStack(spacing: 4) {
                    Text(hint)
                        .font(.system(.caption, design: .monospaced).bold())
                    Text(action.title)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(hovering ? Color.accentColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
