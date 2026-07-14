import AppKit
import XCTest

@testable import Mo

@MainActor
final class MoPreferencesTests: XCTestCase {
    func testDefaultHotkeyDisplayName() {
        XCTAssertEqual(Hotkey.defaultHotkey.displayName, "⌃⌥M")
    }

    func testHotkeyModifierDisplayOrder() {
        let hotkey = Hotkey(
            keyCode: 0,
            modifierFlags: NSEvent.ModifierFlags([.command, .shift, .option, .control]).rawValue,
            keyName: "A"
        )

        XCTAssertEqual(hotkey.displayName, "⌃⌥⇧⌘A")
    }

    func testCommandCommaIsReserved() {
        let commandComma = Hotkey(
            keyCode: 43,
            modifierFlags: NSEvent.ModifierFlags.command.rawValue,
            keyName: ","
        )
        let commandShiftComma = Hotkey(
            keyCode: 43,
            modifierFlags: NSEvent.ModifierFlags([.command, .shift]).rawValue,
            keyName: ","
        )

        XCTAssertTrue(commandComma.isReservedBySystem)
        XCTAssertFalse(commandShiftComma.isReservedBySystem)

        let monitor = GlobalHotkeyMonitor()
        monitor.start(hotkey: commandComma)
        XCTAssertEqual(
            monitor.registrationError,
            "⌘, is reserved for the active app's Settings command."
        )
    }

    func testAutoHideDelays() {
        XCTAssertNil(AutoHidePolicy.never.delay)
        XCTAssertNil(AutoHidePolicy.appSwitch.delay)
        XCTAssertEqual(AutoHidePolicy.fiveSeconds.delay, 5)
        XCTAssertEqual(AutoHidePolicy.tenSeconds.delay, 10)
        XCTAssertEqual(AutoHidePolicy.thirtySeconds.delay, 30)
        XCTAssertEqual(AutoHidePolicy.oneMinute.delay, 60)
    }

    func testPreferencesPersist() {
        let suiteName = "MoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = MoPreferences(defaults: defaults)
        preferences.autoHidePolicy = .thirtySeconds
        preferences.hideToggle = true
        preferences.hotkey = Hotkey(
            keyCode: 49,
            modifierFlags: NSEvent.ModifierFlags.command.rawValue,
            keyName: "Space"
        )

        let reloaded = MoPreferences(defaults: defaults)
        XCTAssertEqual(reloaded.autoHidePolicy, .thirtySeconds)
        XCTAssertTrue(reloaded.hideToggle)
        XCTAssertEqual(reloaded.hotkey.displayName, "⌘Space")
    }

    func testMenuBarControllerTogglesDividerLength() {
        let suiteName = "MoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = MoPreferences(defaults: defaults)
        preferences.autoHidePolicy = .never
        let controller = MenuBarController(preferences: preferences)
        controller.start()
        defer { controller.stop() }

        XCTAssertEqual(controller.state, .hidden)
        XCTAssertEqual(controller.dividerLength, 10_000)
        XCTAssertEqual(controller.toggleLength, 14)
        XCTAssertEqual(controller.isToggleVisible, true)
        let originalToggleIdentity = controller.toggleItemIdentity

        preferences.hideToggle = true
        XCTAssertEqual(controller.isToggleVisible, false)
        XCTAssertEqual(controller.toggleLength, 0)
        XCTAssertEqual(controller.toggleItemIdentity, originalToggleIdentity)

        controller.setItemsShown(true)
        XCTAssertEqual(controller.state, .shown)
        XCTAssertEqual(controller.dividerLength, 8)
        XCTAssertEqual(controller.isToggleVisible, false)
        XCTAssertEqual(controller.toggleLength, 0)
        XCTAssertEqual(controller.toggleItemIdentity, originalToggleIdentity)

        controller.setItemsShown(false)
        XCTAssertEqual(controller.state, .hidden)
        XCTAssertEqual(controller.dividerLength, 10_000)
        XCTAssertEqual(controller.isToggleVisible, false)
        XCTAssertEqual(controller.toggleItemIdentity, originalToggleIdentity)

        preferences.hideToggle = false
        XCTAssertEqual(controller.isToggleVisible, true)
        XCTAssertEqual(controller.toggleLength, 14)
        XCTAssertEqual(controller.toggleItemIdentity, originalToggleIdentity)
    }

    func testLegacyTogglePreferenceMigrates() {
        let suiteName = "MoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "hideToggleWhenHidden")

        let preferences = MoPreferences(defaults: defaults)

        XCTAssertTrue(preferences.hideToggle)
    }

    func testMenuBarControllerUsesItsSettingsCallback() {
        let suiteName = "MoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = MoPreferences(defaults: defaults)
        let controller = MenuBarController(preferences: preferences)
        var didRequestSettings = false
        controller.onOpenSettings = {
            didRequestSettings = true
        }

        controller.showSettings()

        XCTAssertTrue(didRequestSettings)
    }

    func testAppDelegateShowsAndReopensSettingsWindow() {
        let delegate = AppDelegate()

        delegate.openSettings()
        guard let window = delegate.settingsWindowController?.window else {
            XCTFail("Expected a settings window")
            return
        }
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(window.contentLayoutRect.size, SettingsWindowLayout.contentSize)

        window.close()
        XCTAssertFalse(window.isVisible)

        delegate.openSettings()
        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(delegate.settingsWindowController?.window === window)
        window.close()
    }
}
