# Mo

<p align="center">
  <img src="Artwork/AppIcon-Transparent.svg" width="128" height="128" alt="Mo app icon">
</p>

Mo is a small, native macOS menu bar app that keeps the menu bar tidy. Put items on the hidden side of Mo's divider, then reveal or collapse them with a click or a global shortcut.

## Features

- A minimal-width divider and compact 14-point toggle separate hidden and always-visible menu bar items.
- A configurable global shortcut toggles the hidden section (default: `⌃⌥M`).
- Command-comma remains reserved for each foreground app's Settings command and cannot be assigned globally.
- Hidden items can rehide after 5, 10, 30, or 60 seconds, when the active app changes, or never.
- Mo registers itself to launch at login on first run, subject to macOS approval.
- Settings and item positions persist between launches.
- No Accessibility, Input Monitoring, Screen Recording, analytics, or network access.

## Download

Signed and notarized builds are published on the [GitHub Releases page](https://github.com/danielcorin/Mo/releases).

## Set up Mo

1. Open Mo. Its settings window appears on the first launch.
2. Click Mo's compact chevron menu bar button to reveal the thin divider.
3. Hold Command and drag menu bar items to arrange them:
   - items to the left of Mo's divider are hidden when Mo collapses;
   - items to the right stay visible;
   - keep Mo's chevron button to the right of its divider.
4. Click the chevron button or press `⌃⌥M` to toggle the hidden section.

Right-click Mo's button to open settings or quit. The shortcut, rehide behavior, and whether the button appears at all are configurable in settings. When the button is disabled, it stays hidden in both visibility states; use the configured shortcut to toggle items and reopen Mo to access settings.

macOS controls whether an item can be Command-dragged. Some Control Center modules and custom third-party items may not be movable. On a notched or extremely crowded display, macOS can still omit revealed items when there is not enough physical space.

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later to build from source

## Build

1. Clone the repository and open `Mo.xcodeproj`.
2. Copy `Configuration/Local.xcconfig.example` to `Configuration/Local.xcconfig`.
3. Set `DEVELOPMENT_TEAM` to your Apple Developer Team ID and choose a unique `PRODUCT_BUNDLE_IDENTIFIER`.
4. Select the Mo scheme and run the app.

An unsigned command-line build and test run can be performed with:

```sh
xcodebuild \
  -project Mo.xcodeproj \
  -scheme Mo \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild \
  -project Mo.xcodeproj \
  -scheme Mo \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Regenerate all app icon sizes after changing `Artwork/AppIcon.svg` with:

```sh
scripts/generate-app-icon.sh
```

## Publishing a release

The release workflow follows the same signing approach as [Reco](https://github.com/danielcorin/Reco). Signing details can remain in the ignored `Configuration/Local.xcconfig`, or be supplied through environment variables. The release script resolves the version, build number, bundle ID, and development team from those inputs and Xcode.

For a non-interactive notarized build, export the release credentials from your shell, secret manager, or ignored `.envrc`:

```sh
export APPLE_ID="you@example.com"
export APPLE_ID_PASSWORD="your-app-specific-password"
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export TEAM_ID="TEAMID"
```

Before a release, update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, then commit and push the changes. Run:

```sh
GH_REPO=danielcorin/Mo \
scripts/publish-release.sh --publish
```

As a Keychain-based alternative, run `scripts/publish-release.sh --setup-notary-profile MoNotary` once, then publish with `NOTARY_PROFILE=MoNotary`. The setup command uses `APPLE_ID` and `APPLE_ID_PASSWORD` when available, or prompts securely when the password is absent. Legacy `DEVELOPMENT_TEAM`, `DEVELOPER_IDENTITY`, and `NOTARY_APPLE_ID` variables remain supported.

The script requires a clean branch synchronized with its upstream, creates a universal archive, Developer ID-signs and uploads it through Xcode, waits for notarization, verifies the exported app, produces ZIP and DMG artifacts, notarizes the outer DMG, writes SHA-256 checksums, and creates the GitHub release. Use `--dry-run` to inspect the release plan.

## Privacy and permissions

Mo is sandboxed and works by changing only the width of its own status item. It does not inspect, capture, or control other applications. The global shortcut uses macOS's system hotkey registration instead of a keyboard event tap, so it does not require Accessibility or Input Monitoring permission.

On first launch, Mo asks macOS to register it as a login item. If macOS requires approval, Mo links directly to System Settings → General → Login Items. See [PRIVACY.md](PRIVACY.md) for the complete privacy statement and [ARCHITECTURE.md](ARCHITECTURE.md) for implementation details.

## AI disclosure

Mo was developed with assistance from coding agent tools and language models.

## Contributing and security

Contributions are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). Please follow [SECURITY.md](SECURITY.md) when reporting a security issue.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).
