# Changelog

All notable changes to Mo will be documented here. This project follows [Semantic Versioning](https://semver.org/).

## Unreleased

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
