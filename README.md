# Tessel

Windows-style window management for macOS: snap windows to halves, quarters,
thirds, fourths, and sixths with hotkeys, throw them between monitors, and drag
windows to screen edges to snap them — with a live preview overlay, like
Windows Snap. Plus workspace arrangements, window stashing, a throw panel,
custom sizes, app pinning, and double-tap-modifier triggers.

Menu bar app, no Dock icon. Native Swift, no dependencies.

## Build & run

```sh
make run        # builds, kills any running instance, launches the app
make build      # just build + sign build/Tessel.app
make test       # unit tests for the layout/coordinate/zone logic
make clean
```

On first launch, grant permission in **System Settings → Privacy & Security →
Accessibility** (the app prompts you and detects the grant automatically —
no relaunch needed for hotkeys; if drag snapping doesn't start, the menu will
offer a one-click relaunch).

**Always launch via `open build/Tessel.app`** (or `make run`), never the bare
binary — macOS would attribute the permission to your terminal instead.

### Code signing note

`build.sh` signs with `$CODESIGN_IDENTITY`, or the first code-signing identity
in your keychain (an Apple Development certificate from Xcode works). With a
stable identity, the Accessibility grant survives rebuilds. If it falls back to
ad-hoc signing, every rebuild invalidates the grant — create a self-signed
"Code Signing" certificate in Keychain Access and export
`CODESIGN_IDENTITY='<its name>'`.

## Default hotkeys

All customizable in Settings → Shortcuts (record any ⌃/⌥/⌘ combo).

| Keys | Action |
|---|---|
| ⌃⌥ ← / → / ↑ / ↓ | Left / right / top / bottom half |
| *(repeat a half)* | Cycles the size ½ → ⅔ → ⅓ (toggle in Settings) |
| ⌃⌥ U / I / J / K | Top-left / top-right / bottom-left / bottom-right quarter |
| ⌃⌥ D / F / G | Left / center / right third |
| ⌃⌥ E / T | First / last two-thirds |
| ⌃⌥ ↩ | Maximize (fills the screen; not macOS fullscreen) |
| ⌃⌥ A | Almost maximize (90%, centered) |
| ⌃⌥⇧ ↑ | Maximize height (keep width) |
| ⌃⌥ C | Center (keep size) |
| ⌃⌥ = / - | Make larger / smaller |
| ⌃⌥ ⌫ | Restore the window's pre-snap size and position |
| ⌃⌥⌘ ← / → | Move window to previous / next display |
| ⌃⌥ Space | Window Throw panel |
| ⌃⌥⇧ ← / → | Stash window to left / right edge |
| ⌃⌥⇧ ⌫ | Unstash all windows |
| ⌃⌥ 1–9 | Apply saved workspace 1–9 |
| ⌃⌥⇧ 1–9 | Apply custom size 1–9 |

Fourths, sixths, and move-to-edge actions have no default keys — use the menu
bar dropdown or assign shortcuts in Settings.

## Power features

- **Window Throw panel** (⌃⌥Space or a double-tapped modifier): a floating grid
  of 16 targets with mini previews; one unmodified keystroke or a click throws
  the focused window. Digits 1–9 apply custom sizes.
- **Workspace arrangements**: save every window's position as a named
  workspace; re-apply from the menu or ⌃⌥1–9. Flag one "auto-apply" and it
  triggers automatically when that display configuration connects.
- **Window stashing**: ⌃⌥⇧←/→ slides a window off the edge leaving a 12 pt
  sliver; touch the sliver with the cursor and it slides back out, leave it and
  it re-stashes. Stash again (or ⌃⌥⇧⌫) to restore.
- **Custom sizes**: named sizes as percentages of the screen, applied via menu,
  hotkey, or throw-panel digits.
- **App pinning**: reserve a strip of the screen for one app (Settings → Apps);
  every other snap tiles within the remaining space.
- **Double-tap modifier**: e.g. tap ⌥ twice to open the throw panel (or any
  action) — configure in Settings → General.
- **Menu customization**: hide menu sections you don't use (Settings → General).

## Drag snapping

Drag a window and release at:
- **Left / right edge** → that half of the screen
- **Top edge** → maximize
- **Any edge near a corner** → that quarter
- **Bottom edge** → off by default (avoids accidental snaps near the Dock)

Every zone is remappable in Settings → Drag Zones (any fixed layout, or Off).
A translucent overlay previews the target area while you drag.

## Settings

Menu bar icon → **Settings…**
- **General** — half-size cycling, gap between windows (0–30 pt), launch at
  login, hide menu bar icon (reopen the app to get settings back), config
  export/import as JSON.
- **Shortcuts** — record/clear/reset every action's hotkey.
- **Drag Zones** — drag-snap toggle, preview overlay, edge sensitivity, and
  per-zone action mapping.
- **Ignored Apps** — apps Tessel never touches (hotkeys or dragging).

## Manual test checklist

1. `make run` → menu bar icon appears, no Dock icon, permission prompt once.
2. Grant Accessibility → hotkeys start working within a second, no relaunch.
3. `make build` again, relaunch → grant still works (signing identity is stable).
4. Hotkey matrix against TextEdit, Safari, Terminal (grid resize), VS Code
   (Electron), and a non-resizable window (centers in the zone instead).
5. ⌃⌥← inside a text field types nothing (keystroke is consumed).
6. Repeated ⌃⌥← cycles ½ → ⅔ → ⅓ widths.
7. Restore: hand-place → left half → right half → ⌃⌥⌫ returns the original frame.
8. Multi-monitor: snapping respects each display's Dock/menu bar insets;
   ⌃⌥⌘→ wraps around; drag-snap works on every display.
9. Dragging to select text or resizing a window never shows the snap overlay.
10. Set a gap in Settings → snapped windows leave padding; two halves leave one
    gap between them.
