# Privacy

Mo does not collect, store, or transmit personal data.

## Data stored on the Mac

Mo stores only these preferences in its standard macOS preferences container:

- the configured keyboard shortcut;
- the automatic rehide policy;
- whether the Mo menu-bar button is shown;
- whether first-run setup has completed;
- whether launch-at-login registration has been initialized;
- status-item positions persisted by AppKit.

If compact menu-bar spacing is enabled, Mo also writes the `NSStatusItemSpacing` and `NSStatusItemSelectionPadding` values to the current Mac's global preferences. Disabling the option removes both values and restores the macOS default.

Deleting Mo's preferences removes the data in its standard container, but it does not remove a global spacing override. Disable compact spacing in Mo before deleting the app to restore the macOS default. Unregister launch at login from Mo's settings or System Settings before deleting the app if you no longer want it to start automatically.

## Command-line automation

The bundled `mo` command can inspect Mo's current state, show or hide the configured menu-bar section, open settings, change the same spacing values available in the app, or quit Mo. It exchanges typed request and response data with the running app through a current-user-only local socket inside Mo's sandbox container. Commands and responses are not logged or persisted by Mo and never leave the Mac.

## Permissions

Mo does not request Accessibility, Input Monitoring, Screen Recording, Automation, microphone, camera, location, contacts, or file access. Its sandbox entitlement allows read/write access only to the global preferences domain used by the optional menu-bar spacing setting. The separately launched CLI is limited to local command handling and does not require elevated privileges. Mo uses `SMAppService` to register as a login item, which remains visible and controllable in macOS System Settings.

## Network access and analytics

Mo contains no networking feature, analytics SDK, telemetry, crash reporter, advertising SDK, or third-party dependency. Release downloads are provided by the distribution channel, not by the running app.
