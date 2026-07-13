import SwiftUI

@main
struct MoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                controller: appDelegate.menuBarController,
                preferences: appDelegate.preferences,
                loginItemManager: appDelegate.loginItemManager
            )
        }
        .commands {
            CommandGroup(replacing: .appSettings) {}
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = MoPreferences()
    let loginItemManager = LoginItemManager()
    lazy var menuBarController: MenuBarController = {
        let controller = MenuBarController(preferences: preferences)
        controller.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        return controller
    }()
    private(set) var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }
        NSApp.setActivationPolicy(.accessory)
        menuBarController.start()
        loginItemManager.refresh()

        if preferences.shouldEnableLaunchAtLoginOnFirstRun {
            loginItemManager.setEnabled(true)
            preferences.markLaunchAtLoginConfigured()
        }

        if !preferences.hasCompletedOnboarding {
            preferences.hasCompletedOnboarding = true
            DispatchQueue.main.async { [weak self] in
                self?.openSettings()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        openSettings()
        return false
    }

    @objc func openSettings() {
        let windowController: NSWindowController
        if let settingsWindowController {
            windowController = settingsWindowController
        } else {
            windowController = makeSettingsWindowController()
            settingsWindowController = windowController
        }

        NSApp.activate(ignoringOtherApps: true)
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
    }

    private func makeSettingsWindowController() -> NSWindowController {
        let rootView = SettingsView(
            controller: menuBarController,
            preferences: preferences,
            loginItemManager: loginItemManager
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(
                origin: .zero,
                size: SettingsWindowLayout.contentSize
            ),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mo Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.isExcludedFromWindowsMenu = true
        window.center()
        window.setFrameAutosaveName("Mo.SettingsWindow")
        window.setContentSize(SettingsWindowLayout.contentSize)
        return NSWindowController(window: window)
    }
}
