import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var arrangements: ArrangementManager

    var body: some View {
        TabView {
            GeneralTab(preferences: preferences)
                .tabItem { Label("General", systemImage: "gearshape") }
            ShortcutsTab(preferences: preferences)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            DragZonesTab(preferences: preferences)
                .tabItem { Label("Drag Zones", systemImage: "rectangle.dashed") }
            WorkspacesTab(arrangements: arrangements)
                .tabItem { Label("Workspaces", systemImage: "macwindow.on.rectangle") }
            CustomSizesTab(preferences: preferences)
                .tabItem { Label("Sizes", systemImage: "ruler") }
            AppsTab(preferences: preferences)
                .tabItem { Label("Apps", systemImage: "app.badge") }
        }
        .frame(width: 580, height: 620)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject var preferences: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private static let doubleTapActions: [SnapAction] = [
        .showThrowPanel, .maximize, .almostMaximize, .center, .restore, .leftHalf, .rightHalf,
    ]

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Cycle half sizes on repeated presses (½ → ⅔ → ⅓)", isOn: $preferences.cycleHalves)
                Slider(value: $preferences.gapSize, in: 0...30, step: 1) {
                    Text("Gap between windows: \(Int(preferences.gapSize)) pt")
                }
            }

            Section("Double-Tap Modifier") {
                Picker("Double-tapping", selection: $preferences.doubleTapModifier) {
                    Text("Off").tag("off")
                    Text("Control (⌃⌃)").tag("control")
                    Text("Option (⌥⌥)").tag("option")
                    Text("Command (⌘⌘)").tag("command")
                    Text("Shift (⇧⇧)").tag("shift")
                }
                Picker("Triggers", selection: $preferences.doubleTapAction) {
                    ForEach(Self.doubleTapActions, id: \.rawValue) { action in
                        Text(action.title).tag(action.rawValue)
                    }
                }
                .disabled(preferences.doubleTapModifier == "off")
            }

            Section("Menu Bar Menu") {
                DisclosureGroup("Visible sections") {
                    ForEach(MenuGroups.all, id: \.key) { group in
                        Toggle(group.title, isOn: menuGroupBinding(group.key))
                    }
                }
            }

            Section("App") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Toggle("Hide menu bar icon", isOn: $preferences.hideMenuBarIcon)
                if preferences.hideMenuBarIcon {
                    Text("To get back here with the icon hidden, open Tessel.app again — the settings window will appear.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Configuration") {
                HStack {
                    Button("Export…") { exportConfig() }
                    Button("Import…") { importConfig() }
                }
                Text("Workspace arrangements live in Application Support and are not part of the export.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func menuGroupBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { !preferences.hiddenMenuGroups.contains(key) },
            set: { visible in
                if visible {
                    preferences.hiddenMenuGroups.removeAll { $0 == key }
                } else if !preferences.hiddenMenuGroups.contains(key) {
                    preferences.hiddenMenuGroups.append(key)
                }
            }
        )
    }

    private func exportConfig() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Tessel-config.json"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = preferences.exportJSON() else { return }
        try? data.write(to: url)
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        preferences.importJSON(data)
    }
}

// MARK: - Shortcuts

private struct ShortcutsTab: View {
    @ObservedObject var preferences: Preferences
    @StateObject private var capture = ShortcutCapture()

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(SnapAction.allCases, id: \.self) { action in
                    row(for: action)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Click Record, then press a combo with ⌃, ⌥, or ⌘. Esc cancels.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset All to Defaults") {
                        capture.cancel()
                        preferences.resetShortcuts()
                    }
                }
                Text("Reserved: ⌃⌥1–9 apply workspaces, ⌃⌥⇧1–9 apply custom sizes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }

    private func row(for action: SnapAction) -> some View {
        let binding = Keycodes.binding(for: action, customShortcuts: preferences.customShortcuts)
        let isRecording = capture.recordingAction == action
        return HStack {
            Text(action.title)
            Spacer()
            Text(isRecording ? "Press keys…" : binding.map(Keycodes.displayString(for:)) ?? "—")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(isRecording ? Color.accentColor : .secondary)
                .frame(minWidth: 90, alignment: .trailing)
            Button(isRecording ? "Cancel" : "Record") {
                if isRecording {
                    capture.cancel()
                } else {
                    capture.begin(for: action) { keyCode, modifiers in
                        preferences.setShortcut(for: action, keyCode: keyCode, modifiers: modifiers)
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button {
                capture.cancel()
                preferences.clearShortcut(for: action)
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(binding == nil)
            .help("Remove shortcut")
        }
    }
}

// MARK: - Drag zones

private struct DragZonesTab: View {
    @ObservedObject var preferences: Preferences

    private static let zoneChoices: [SnapAction] = SnapAction.allCases.filter(\.isFixedLayout)

    var body: some View {
        Form {
            Section("Drag Snapping") {
                Toggle("Snap windows dragged to screen edges", isOn: $preferences.dragSnapEnabled)
                Toggle("Show preview overlay while dragging", isOn: $preferences.showPreviewOverlay)
                    .disabled(!preferences.dragSnapEnabled)
                Slider(value: $preferences.edgeThreshold, in: 5...40, step: 1) {
                    Text("Edge zone size: \(Int(preferences.edgeThreshold)) pt")
                }
                .disabled(!preferences.dragSnapEnabled)
            }

            Section("Zone Actions") {
                ForEach(SnapZone.Zone.allCases, id: \.self) { zone in
                    Picker(zone.title, selection: zoneBinding(for: zone)) {
                        Text("Off").tag(Preferences.zoneOffValue)
                        Divider()
                        ForEach(Self.zoneChoices, id: \.self) { action in
                            Text(action.title).tag(action.rawValue)
                        }
                    }
                    .disabled(!preferences.dragSnapEnabled)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func zoneBinding(for zone: SnapZone.Zone) -> Binding<String> {
        Binding(
            get: { preferences.action(for: zone)?.rawValue ?? Preferences.zoneOffValue },
            set: { preferences.setAction(SnapAction(rawValue: $0), for: zone) }
        )
    }
}

// MARK: - Workspaces

private struct WorkspacesTab: View {
    @ObservedObject var arrangements: ArrangementManager
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            if arrangements.arrangements.isEmpty {
                Spacer()
                Text("No saved workspaces.\nArrange your windows, then save the layout below.\nThe first nine get ⌃⌥1–9 hotkeys.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(Array(arrangements.arrangements.enumerated()), id: \.element.id) { index, arrangement in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(arrangement.name)
                                Text("\(arrangement.entries.count) windows\(index < 9 ? "  ·  ⌃⌥\(index + 1)" : "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Auto-apply", isOn: Binding(
                                get: { arrangement.autoApply },
                                set: { arrangements.setAutoApply($0, for: arrangement) }
                            ))
                            .toggleStyle(.checkbox)
                            .help("Apply automatically when this display setup connects")
                            Button("Apply") { arrangements.apply(arrangement) }
                                .controlSize(.small)
                            Button {
                                arrangements.delete(arrangement)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Divider()
            HStack {
                TextField("New workspace name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                Button("Save Current Workspace") {
                    let name = newName.isEmpty ? "Workspace \(arrangements.arrangements.count + 1)" : newName
                    arrangements.saveCurrent(named: name)
                    newName = ""
                }
            }
            .padding(10)
        }
    }
}

// MARK: - Custom sizes

private struct CustomSizesTab: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        VStack(spacing: 0) {
            if preferences.customSizes.isEmpty {
                Spacer()
                Text("No custom sizes.\nDefine reusable window sizes as percentages of the screen.\nApply via the menu, ⌃⌥⇧1–9, or digits in the throw panel.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    ForEach($preferences.customSizes) { $size in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                TextField("Name", text: $size.name)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 180)
                                Spacer()
                                Button {
                                    preferences.customSizes.removeAll { $0.id == size.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 16) {
                                Stepper("X \(Int(size.x * 100))%", value: $size.x, in: 0...0.95, step: 0.05)
                                Stepper("Y \(Int(size.y * 100))%", value: $size.y, in: 0...0.95, step: 0.05)
                                Stepper("W \(Int(size.width * 100))%", value: $size.width, in: 0.05...1, step: 0.05)
                                Stepper("H \(Int(size.height * 100))%", value: $size.height, in: 0.05...1, step: 0.05)
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            Divider()
            HStack {
                Button("Add Custom Size") {
                    preferences.customSizes.append(.makeDefault())
                }
                Spacer()
                Text("Percentages of the screen's usable area.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }
}

// MARK: - Apps (ignored + pinning)

private struct AppsTab: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Form {
            Section("Pinned App") {
                HStack {
                    Text(pinnedAppLabel)
                    Spacer()
                    Button("Choose App…") { choosePinnedApp() }
                    if preferences.pinnedBundleID != nil {
                        Button("Unpin") { preferences.pinnedBundleID = nil }
                    }
                }
                Picker("Pin to side", selection: $preferences.pinnedSide) {
                    Text("Left").tag("left")
                    Text("Right").tag("right")
                }
                .disabled(preferences.pinnedBundleID == nil)
                Slider(value: $preferences.pinnedWidthFraction, in: 0.15...0.5, step: 0.05) {
                    Text("Reserved width: \(Int(preferences.pinnedWidthFraction * 100))%")
                }
                .disabled(preferences.pinnedBundleID == nil)
                Text("The pinned app keeps a strip of the screen; every other snap tiles within the remaining space.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Ignored Apps") {
                if preferences.ignoredBundleIDs.isEmpty {
                    Text("None — Tessel manages windows of every application.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preferences.ignoredBundleIDs, id: \.self) { bundleID in
                        HStack {
                            Text(appName(for: bundleID))
                            Text(bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                preferences.ignoredBundleIDs.removeAll { $0 == bundleID }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Add App…") { addIgnoredApp() }
            }
        }
        .formStyle(.grouped)
    }

    private var pinnedAppLabel: String {
        guard let bundleID = preferences.pinnedBundleID, !bundleID.isEmpty else {
            return "No app pinned"
        }
        return appName(for: bundleID)
    }

    private func appName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path)
    }

    private func choosePinnedApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
        preferences.pinnedBundleID = bundleID
    }

    private func addIgnoredApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let bundleID = Bundle(url: url)?.bundleIdentifier,
               !preferences.ignoredBundleIDs.contains(bundleID) {
                preferences.ignoredBundleIDs.append(bundleID)
            }
        }
    }
}
