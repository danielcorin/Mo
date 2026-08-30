# Mo development guide

Mo is a sandboxed SwiftUI/AppKit menu-bar app with an embedded, non-interactive
`mo` companion command.

## Project layout

- `Mo/` contains the app, controllers, preferences, and CLI request handler.
- `MoCore/` contains the shared Codable protocol and menu-bar spacing store.
- `MoCLI/` contains the thin command-line client.
- `MoTests/` tests app behavior and shared protocol compatibility.

## Build and test

```sh
xcodebuild -project Mo.xcodeproj -scheme Mo -destination 'platform=macOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build test
```

Confirm each app build embeds an executable helper at
`build/Build/Products/Debug/Mo.app/Contents/Helpers/mo`. Use the installed app's
helper or `~/.local/bin/mo` for live smoke tests; `mo status --json` is the
primary inspection surface.

## CLI parity

Meaningful app actions and state should remain available through the companion
CLI. Add shared request, response, and status fields in `MoCore`, execute
mutations through the running app's existing model, update `mo help` and the
README, and add Codable round-trip coverage. Keep stdout machine-readable when
`--json` is passed and use stderr plus exit code 2 for usage errors.
