# Architecture

Mo intentionally uses a small, dependency-free design built on public macOS frameworks.

## Runtime model

`AppDelegate` owns three long-lived services:

- `MenuBarController` creates the toggle and divider status items and manages visibility.
- `GlobalHotkeyMonitor` registers one system hotkey through Carbon's `RegisterEventHotKey` API.
- `LoginItemManager` manages `SMAppService.mainApp` registration and approval state.

`MoPreferences` persists the hotkey, auto-hide policy, toggle visibility, onboarding state, and login-item initialization state in `UserDefaults`. SwiftUI provides the settings window; AppKit owns the status items because precise item sizing and click behavior are central to the app.

## How hiding works

Mo creates two `NSStatusItem` instances with unique autosave names:

```text
hidden apps  |  Mo divider  |  visible apps  |  Mo toggle
```

When shown, the divider is 8 points wide. When hidden, it becomes 10,000 points wide and has no image. macOS lays status items out from the system side of the menu bar, so the oversized item consumes the available space to its left and moves the hidden section off-screen while preserving the visible section to its right.

The toggle is a fixed 14-point status item with a single chevron. Users can hide it completely and operate Mo only with the global shortcut. Mo keeps the same status-item instance and collapses it to zero width instead of removing it, so restoring the button preserves its exact menu-bar position. Status-item changes are applied without animation and images are cached.

This mechanism does not read or modify another process. Users define membership in each section using macOS's built-in Command-drag status-item arrangement. Unique `autosaveName` values let AppKit restore Mo's two positions between launches.

## Auto-hide behavior

Timed policies schedule a one-shot main-run-loop timer whenever the hidden section is shown. The app-switch policy listens for `NSWorkspace.didActivateApplicationNotification`. Hiding or changing policies invalidates the previous timer or observer before installing a new one.

## Permissions

- The app sandbox remains enabled.
- The global shortcut uses system registration, not an event tap, so Accessibility and Input Monitoring are unnecessary.
- The status-item technique does not require Screen Recording.
- Launch at login uses the supported `SMAppService` API. macOS may require the user to approve it in Login Items.

## Known platform constraints

- macOS decides which status items can be Command-dragged.
- macOS may suppress items when a menu bar is too crowded or intersects a display notch.
- The expanded-width technique depends on AppKit's status-item layout behavior. It uses public sizing APIs, but the resulting overflow layout is not a formal menu-bar-management contract. Builds should be smoke-tested on each major macOS release.
