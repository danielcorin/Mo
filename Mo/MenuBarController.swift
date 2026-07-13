import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject, ObservableObject {
    enum VisibilityState: Equatable {
        case hidden
        case shown
    }

    @Published private(set) var state: VisibilityState = .hidden
    @Published private(set) var hotkeyError: String?
    var onOpenSettings: (() -> Void)?

    private enum StatusItemName {
        static let toggle = "Mo.Toggle"
        static let divider = "Mo.Divider"
    }

    private enum Length {
        static let toggle: CGFloat = 14
        static let hiddenToggle: CGFloat = 0
        static let divider: CGFloat = 8
        static let collapsed: CGFloat = 10_000
    }

    private let preferences: MoPreferences
    private let hotkeyMonitor = GlobalHotkeyMonitor()
    private var toggleItem: NSStatusItem?
    private var dividerItem: NSStatusItem?
    private var autoHideTimer: Timer?
    private var isObservingAppSwitches = false
    private var cancellables = Set<AnyCancellable>()
    private lazy var showItemsImage = makeToggleImage(
        systemName: "chevron.left",
        accessibilityDescription: "Show hidden menu bar items"
    )
    private lazy var hideItemsImage = makeToggleImage(
        systemName: "chevron.right",
        accessibilityDescription: "Hide menu bar items"
    )
    private lazy var visibleDividerImage = makeDividerImage()

    var dividerLength: CGFloat? { dividerItem?.length }
    var toggleLength: CGFloat? { toggleItem?.length }
    var isToggleVisible: Bool? {
        guard let toggleItem, let button = toggleItem.button else { return nil }
        return toggleItem.isVisible
            && toggleItem.length > Length.hiddenToggle
            && !button.isHidden
    }
    var toggleItemIdentity: ObjectIdentifier? {
        toggleItem.map(ObjectIdentifier.init)
    }

    init(preferences: MoPreferences) {
        self.preferences = preferences
        super.init()
    }

    func start() {
        guard toggleItem == nil, dividerItem == nil else { return }
        seedInitialStatusItemPositions()
        createStatusItems()

        hotkeyMonitor.onHotkey = { [weak self] in self?.toggle() }
        preferences.$hotkey
            .removeDuplicates()
            .sink { [weak self] hotkey in
                guard let self else { return }
                hotkeyMonitor.start(hotkey: hotkey)
                hotkeyError = hotkeyMonitor.registrationError
                applyState(hotkey: hotkey)
            }
            .store(in: &cancellables)

        preferences.$autoHidePolicy
            .removeDuplicates()
            .sink { [weak self] autoHidePolicy in
                self?.configureAutoHideForCurrentState(autoHidePolicy: autoHidePolicy)
            }
            .store(in: &cancellables)

        preferences.$hideToggle
            .removeDuplicates()
            .sink { [weak self] hideToggle in
                self?.applyState(hideToggle: hideToggle)
            }
            .store(in: &cancellables)

    }

    func stop() {
        cancelAutoHide()
        hotkeyMonitor.stop()
        cancellables.removeAll()
        if let toggleItem { NSStatusBar.system.removeStatusItem(toggleItem) }
        if let dividerItem { NSStatusBar.system.removeStatusItem(dividerItem) }
        toggleItem = nil
        dividerItem = nil
    }

    func toggle() {
        setItemsShown(state == .hidden)
    }

    func setItemsShown(_ shown: Bool) {
        let newState: VisibilityState = shown ? .shown : .hidden
        guard newState != state else {
            if shown { configureAutoHideForCurrentState() }
            return
        }
        state = newState
        applyState()
        configureAutoHideForCurrentState()
    }

    func showSettings() {
        onOpenSettings?()
    }

    private func seedInitialStatusItemPositions() {
        let defaults = UserDefaults.standard
        let toggleKey = "NSStatusItem Preferred Position \(StatusItemName.toggle)"
        let dividerKey = "NSStatusItem Preferred Position \(StatusItemName.divider)"
        if defaults.object(forKey: toggleKey) == nil { defaults.set(0, forKey: toggleKey) }
        if defaults.object(forKey: dividerKey) == nil { defaults.set(1, forKey: dividerKey) }
    }

    private func createStatusItems() {
        let initialToggleLength = preferences.hideToggle ? Length.hiddenToggle : Length.toggle
        let toggle = NSStatusBar.system.statusItem(withLength: initialToggleLength)
        toggle.autosaveName = StatusItemName.toggle
        toggle.isVisible = true
        toggle.behavior = [.terminationOnRemoval, .removalAllowed]
        if let button = toggle.button {
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.isHidden = preferences.hideToggle
            button.toolTip = "Show or hide Mo's menu bar section"
        }
        toggleItem = toggle

        let divider = NSStatusBar.system.statusItem(withLength: Length.collapsed)
        divider.autosaveName = StatusItemName.divider
        divider.isVisible = true
        divider.behavior = [.terminationOnRemoval, .removalAllowed]
        if let button = divider.button {
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Items left of this divider are hidden by Mo"
        }
        dividerItem = divider
    }

    private func applyState(hideToggle: Bool? = nil, hotkey: Hotkey? = nil) {
        guard let toggleItem, let toggleButton = toggleItem.button, let dividerItem else { return }
        let shouldShowToggle = !(hideToggle ?? preferences.hideToggle)
        let hotkeyDisplayName = (hotkey ?? preferences.hotkey).displayName

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false

            if !shouldShowToggle {
                toggleButton.isHidden = true
                if toggleItem.length != Length.hiddenToggle {
                    toggleItem.length = Length.hiddenToggle
                }
            }

            switch state {
            case .hidden:
                toggleButton.image = showItemsImage
                toggleButton.toolTip = "Show hidden menu bar items (\(hotkeyDisplayName))"
                dividerItem.button?.image = nil
                dividerItem.button?.cell?.isEnabled = false
                if dividerItem.length != Length.collapsed {
                    dividerItem.length = Length.collapsed
                }
            case .shown:
                toggleButton.image = hideItemsImage
                toggleButton.toolTip = "Hide menu bar items (\(hotkeyDisplayName))"
                dividerItem.button?.cell?.isEnabled = true
                dividerItem.button?.image = visibleDividerImage
                if dividerItem.length != Length.divider {
                    dividerItem.length = Length.divider
                }
            }

            if shouldShowToggle {
                if toggleItem.length != Length.toggle {
                    toggleItem.length = Length.toggle
                }
                toggleButton.isHidden = false
            }
        }
    }

    private func makeToggleImage(
        systemName: String,
        accessibilityDescription: String
    ) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        let image = NSImage(
            systemSymbolName: systemName,
            accessibilityDescription: accessibilityDescription
        )?.withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }

    private func makeDividerImage() -> NSImage {
        let size = NSSize(width: 2, height: 14)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.labelColor.withAlphaComponent(0.55).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0), xRadius: 0.5, yRadius: 0.5).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Mo hidden-items divider"
        return image
    }

    private func configureAutoHideForCurrentState(autoHidePolicy: AutoHidePolicy? = nil) {
        cancelAutoHide()
        guard state == .shown else { return }
        let autoHidePolicy = autoHidePolicy ?? preferences.autoHidePolicy

        if let delay = autoHidePolicy.delay {
            autoHideTimer = .scheduledTimer(
                timeInterval: delay,
                target: self,
                selector: #selector(autoHideTimerFired),
                userInfo: nil,
                repeats: false
            )
        } else if autoHidePolicy == .appSwitch {
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(activeApplicationDidChange),
                name: NSWorkspace.didActivateApplicationNotification,
                object: nil,
            )
            isObservingAppSwitches = true
        }
    }

    private func cancelAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        if isObservingAppSwitches {
            NSWorkspace.shared.notificationCenter.removeObserver(
                self,
                name: NSWorkspace.didActivateApplicationNotification,
                object: nil
            )
            isObservingAppSwitches = false
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu(relativeTo: sender)
        } else {
            toggle()
        }
    }

    private func showContextMenu(relativeTo statusBarButton: NSStatusBarButton) {
        let menu = NSMenu(title: "Mo")
        let toggleMenuItem = NSMenuItem(
            title: state == .hidden ? "Show Hidden Items" : "Hide Items",
            action: #selector(toggleFromMenu),
            keyEquivalent: ""
        )
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Mo Settings…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Mo",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = NSApp
        menu.addItem(quitItem)
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: statusBarButton.bounds.minX, y: statusBarButton.bounds.minY - 4),
            in: statusBarButton
        )
    }

    @objc private func toggleFromMenu() {
        toggle()
    }

    @objc private func openSettingsFromMenu() {
        showSettings()
    }

    @objc private func autoHideTimerFired() {
        setItemsShown(false)
    }

    @objc private func activeApplicationDidChange() {
        setItemsShown(false)
    }
}
