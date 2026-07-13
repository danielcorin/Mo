# Contributing

Thanks for helping improve Mo.

1. Open an issue before starting a large behavioral or architectural change.
2. Keep the app focused on spatial menu-bar visibility, a global toggle, and a small settings surface.
3. Avoid private APIs and do not add a broad permission unless the feature cannot be delivered safely without it.
4. Do not commit Apple Team IDs, provisioning profiles, signing certificates, archives, build output, or notarization credentials.
5. Run the Mo scheme's tests and an unsigned Release build before opening a pull request.
6. Describe changes to permissions, login-item behavior, privacy, status-item layout, or supported macOS versions explicitly in the pull request.

Useful commands:

```sh
xcodebuild \
  -project Mo.xcodeproj \
  -scheme Mo \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test

xcodebuild \
  -project Mo.xcodeproj \
  -scheme Mo \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Unless stated otherwise, contributions submitted to this project are licensed under Apache-2.0, the repository's license.
