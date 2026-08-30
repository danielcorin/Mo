import AppKit
import MoCore
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

    func testMenuBarSpacingStartsWithSystemDefault() {
        let store = TestMenuBarSpacingStore()
        let manager = MenuBarSpacingManager(store: store)

        XCTAssertFalse(manager.usesCustomSpacing)
        XCTAssertEqual(manager.spacing, 6)
        XCTAssertFalse(manager.requiresSignOut)
    }

    func testMenuBarSpacingAppliesBothPreferences() {
        let store = TestMenuBarSpacingStore()
        let manager = MenuBarSpacingManager(store: store)

        manager.setCustomSpacingEnabled(true)
        manager.setSpacing(3)

        XCTAssertTrue(manager.usesCustomSpacing)
        XCTAssertEqual(manager.spacing, 3)
        XCTAssertEqual(store.values[MenuBarSpacingManager.PreferenceKey.itemSpacing], 3)
        XCTAssertEqual(store.values[MenuBarSpacingManager.PreferenceKey.selectionPadding], 3)
        XCTAssertTrue(manager.requiresSignOut)
        XCTAssertNil(manager.errorMessage)
    }

    func testMenuBarSpacingRestoresSystemDefault() {
        let store = TestMenuBarSpacingStore(values: [
            MenuBarSpacingManager.PreferenceKey.itemSpacing: 4,
            MenuBarSpacingManager.PreferenceKey.selectionPadding: 4,
        ])
        let manager = MenuBarSpacingManager(store: store)

        XCTAssertTrue(manager.usesCustomSpacing)
        XCTAssertEqual(manager.spacing, 4)

        manager.setCustomSpacingEnabled(false)

        XCTAssertFalse(manager.usesCustomSpacing)
        XCTAssertNil(store.values[MenuBarSpacingManager.PreferenceKey.itemSpacing])
        XCTAssertNil(store.values[MenuBarSpacingManager.PreferenceKey.selectionPadding])
    }

    func testMenuBarSpacingReportsWriteFailure() {
        let store = TestMenuBarSpacingStore(synchronizeSucceeds: false)
        let manager = MenuBarSpacingManager(store: store)

        manager.setCustomSpacingEnabled(true)

        XCTAssertFalse(manager.usesCustomSpacing)
        XCTAssertFalse(manager.requiresSignOut)
        XCTAssertNotNil(manager.errorMessage)
    }

    func testCompanionProtocolRoundTripsEveryCommand() throws {
        let encoder = MoCompanionProtocol.makeEncoder()
        let decoder = MoCompanionProtocol.makeDecoder()

        for command in MoCompanionCommand.allCases {
            let request = MoCompanionRequest(
                command: command,
                spacing: command == .setSpacing ? 3 : nil
            )
            let decoded = try decoder.decode(
                MoCompanionRequest.self,
                from: encoder.encode(request)
            )
            XCTAssertEqual(decoded, request)
        }

        let status = MoCompanionStatus(
            appName: "Mo",
            version: "1.0.2",
            processIdentifier: 42,
            hiddenItemsVisible: true,
            toggleVisible: false,
            autoHidePolicy: AutoHidePolicy.tenSeconds.rawValue,
            hotkey: "⌃⌥M",
            menuBarSpacing: MenuBarSpacingState(
                usesCustomSpacing: true,
                spacing: 3,
                itemSpacing: 3,
                selectionPadding: 3
            ),
            spacingChangeRequiresSignOut: true
        )
        let response = MoCompanionResponse(
            requestID: UUID(),
            success: true,
            message: "Updated.",
            status: status
        )
        let decoded = try decoder.decode(
            MoCompanionResponse.self,
            from: encoder.encode(response)
        )
        XCTAssertEqual(decoded, response)
    }

    func testCompanionLocalSocketRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MoTests.\(UUID().uuidString)", isDirectory: true)
        let socketURL = directory.appendingPathComponent("mo.sock")
        defer { try? FileManager.default.removeItem(at: directory) }

        let server = MoLocalSocketServer(path: socketURL.path) { request in
            MoCompanionResponse(
                requestID: request.id,
                success: true,
                message: "ok"
            )
        }
        try server.start()
        defer { server.stop() }

        let request = MoCompanionRequest(command: .status)
        let response = try MoLocalSocketClient.send(request, path: socketURL.path)

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.requestID, request.id)
        XCTAssertEqual(response.message, "ok")
        let attributes = try FileManager.default.attributesOfItem(atPath: socketURL.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        XCTAssertEqual(permissions, 0o600)
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
        XCTAssertEqual(controller.dividerLength, MenuBarController.collapsedDividerLength)
        // The divider only hides items if it spans the menu bar it sits on, so
        // it has to be at least as wide as the widest attached screen.
        XCTAssertGreaterThanOrEqual(
            MenuBarController.collapsedDividerLength,
            NSScreen.screens.map(\.frame.width).max() ?? 0
        )
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
        XCTAssertEqual(controller.dividerLength, MenuBarController.collapsedDividerLength)
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

private final class TestMenuBarSpacingStore: MenuBarSpacingPreferenceStoring {
    var values: [String: Int]
    private let synchronizeSucceeds: Bool

    init(values: [String: Int] = [:], synchronizeSucceeds: Bool = true) {
        self.values = values
        self.synchronizeSucceeds = synchronizeSucceeds
    }

    func integer(forKey key: String) -> Int? {
        values[key]
    }

    func setInteger(_ value: Int?, forKeys keys: [String]) -> Bool {
        for key in keys {
            values[key] = value
        }
        return synchronizeSucceeds
    }
}
