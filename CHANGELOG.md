# Changelog

All notable changes to Mo will be documented here. This project follows [Semantic Versioning](https://semver.org/).

## Unreleased

## 1.0.2 - 2026-07-27

- Fixed a memory leak that grew Mo's footprint to hundreds of megabytes over days of use. The collapsed divider reserved a fixed 10,000 points, and AppKit backed that status item's window with a buffer sized to its width, reallocating it on every menu bar relayout without releasing the previous one.
- The collapsed divider is now sized to the widest attached screen, which is all it needs to push hidden items off the menu bar, and resizes when displays change.
- The collapsed divider's button is hidden while it is acting as pure spacing, so AppKit no longer backs it with a buffer it would redraw on every relayout.

## 1.0.1 - 2026-07-13

- Added a layered Icon Composer app icon for macOS 26, with flattened fallbacks for earlier macOS versions.
- Release tooling now natively supports `APPLE_ID`, `APPLE_ID_PASSWORD`, `DEVELOPER_ID_APPLICATION`, and `TEAM_ID`, with optional Keychain-profile and legacy-variable compatibility.

## 1.0.0 - 2026-07-13

- Initial native macOS menu bar visibility manager.
- Configurable system-wide toggle shortcut.
- Timed, app-switch, and disabled automatic rehide policies.
- Launch-at-login registration and approval status.
- Sandboxed, permission-free status-item implementation.
- Compact single-chevron toggle with an option to remove it from both visibility states.
- Direct settings-window management and protection for the standard Command-comma shortcut.
- Streamlined settings with only actionable configuration sections.
- Context menus anchor beneath whichever Mo status item was clicked.
- Settings window resized so all controls fit without scrolling.
- App icon simplified to a flat, shadow-free design.
- Hidden toggle retains its exact menu-bar position when restored.
