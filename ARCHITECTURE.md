# Architecture

Mo intentionally uses a small, dependency-free design built on public macOS frameworks.

## Runtime model

`AppDelegate` assembles five long-lived services:

- `MoPreferences` persists app settings in `UserDefaults`.
- `MenuBarController` creates the toggle and divider status items, manages visibility, and owns the `GlobalHotkeyMonitor` that registers one system hotkey through Carbon's `RegisterEventHotKey` API.
- `LoginItemManager` manages `SMAppService.mainApp` registration and approval state.
- `MenuBarSpacingManager` configures the two current-host global preferences that control menu-bar item spacing.
- `CompanionCommandServer` handles typed requests from the bundled `mo` command.

`MoCore` contains the Codable command protocol and shared menu-bar spacing store used by both the app and CLI. SwiftUI provides the settings window; AppKit owns the status items because precise item sizing and click behavior are central to the app.

## Companion CLI

The build embeds `mo` at `Mo.app/Contents/Helpers/mo`. The CLI launches its containing app when needed, then exchanges length-prefixed JSON request and response envelopes over a Unix socket inside Mo's sandbox container. The socket directory is mode `0700`, the socket is mode `0600`, frames are capped at 64 KB, client reads and writes have finite timeouts, and concurrent clients are bounded. Mutations are executed by the running app through the same controllers and managers used by the UI.

The CLI is not sandboxed, but the app remains sandboxed. The command surface is deliberately limited to inspecting Mo, showing or hiding its section, opening settings, changing the same global spacing preferences exposed in the UI, and quitting the app.

## How hiding works

Mo creates two `NSStatusItem` instances with unique autosave names:

```text
hidden apps  |  Mo divider  |  visible apps  |  Mo toggle
```

When shown, the divider is 8 points wide. When hidden, it grows to the width of the widest attached screen and has no image. macOS lays status items out from the system side of the menu bar, so the expanded item consumes the available space to its left and moves the hidden section off-screen while preserving the visible section to its right.

The toggle is a fixed 14-point status item with a single chevron. Users can hide it completely and operate Mo only with the global shortcut. Mo keeps the same status-item instance and collapses it to zero width instead of removing it, so restoring the button preserves its exact menu-bar position. Status-item changes are applied without animation and images are cached.

This mechanism does not read or modify another process. Users define membership in each section using macOS's built-in Command-drag status-item arrangement. Unique `autosaveName` values let AppKit restore Mo's two positions between launches.

## Auto-hide behavior

Timed policies schedule a one-shot main-run-loop timer whenever the hidden section is shown. The app-switch policy listens for `NSWorkspace.didActivateApplicationNotification`. Hiding or changing policies invalidates the previous timer or observer before installing a new one.

## Permissions

- The app sandbox remains enabled.
- A shared-preference exception is limited to the global preferences domain so Mo can set or remove `NSStatusItemSpacing` and `NSStatusItemSelectionPadding`.
- The global shortcut uses system registration, not an event tap, so Accessibility and Input Monitoring are unnecessary.
- The status-item technique does not require Screen Recording.
- Launch at login uses the supported `SMAppService` API. macOS may require the user to approve it in Login Items.

## Known platform constraints

- macOS decides which status items can be Command-dragged.
- macOS may suppress items when a menu bar is too crowded or intersects a display notch.
- The compact-spacing control uses undocumented macOS preference keys and may need adjustment on future macOS releases.
- The expanded-width technique depends on AppKit's status-item layout behavior. It uses public sizing APIs, but the resulting overflow layout is not a formal menu-bar-management contract. Builds should be smoke-tested on each major macOS release.
