import Combine
import Foundation
import MoCore

@MainActor
final class MenuBarSpacingManager: ObservableObject {
    enum PreferenceKey {
        static let itemSpacing = MenuBarSpacingPreferences.itemSpacingKey
        static let selectionPadding = MenuBarSpacingPreferences.selectionPaddingKey
        static let all = [itemSpacing, selectionPadding]
    }

    static let allowedSpacing = MenuBarSpacingPreferences.allowedSpacing
    static let recommendedSpacing = MenuBarSpacingPreferences.recommendedSpacing

    @Published private(set) var usesCustomSpacing: Bool
    @Published private(set) var spacing: Int
    @Published private(set) var requiresSignOut = false
    @Published private(set) var errorMessage: String?

    private let store: any MenuBarSpacingPreferenceStoring

    convenience init() {
        self.init(store: CurrentHostGlobalPreferencesStore())
    }

    init(store: any MenuBarSpacingPreferenceStoring) {
        self.store = store

        let state = MenuBarSpacingPreferences.read(from: store)
        usesCustomSpacing = state.usesCustomSpacing
        spacing = state.spacing
    }

    func setCustomSpacingEnabled(_ enabled: Bool) {
        guard enabled != usesCustomSpacing else { return }
        let value = enabled ? spacing : nil
        guard write(value) else { return }
        usesCustomSpacing = enabled
    }

    func setSpacing(_ newValue: Int) {
        guard Self.allowedSpacing.contains(newValue), newValue != spacing else { return }
        let previousValue = spacing
        spacing = newValue

        guard usesCustomSpacing, !write(newValue) else { return }
        spacing = previousValue
    }

    @discardableResult
    func setCustomSpacing(_ newValue: Int) -> Bool {
        guard Self.allowedSpacing.contains(newValue) else { return false }
        guard write(newValue) else { return false }
        spacing = newValue
        usesCustomSpacing = true
        return true
    }

    private func write(_ value: Int?) -> Bool {
        guard MenuBarSpacingPreferences.write(value, to: store) else {
            errorMessage = "Mo couldn’t update the macOS menu bar spacing."
            return false
        }
        errorMessage = nil
        requiresSignOut = true
        return true
    }
}
