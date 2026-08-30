import CoreFoundation
import Foundation

public protocol MenuBarSpacingPreferenceStoring {
    func integer(forKey key: String) -> Int?
    func setInteger(_ value: Int?, forKeys keys: [String]) -> Bool
}

public struct CurrentHostGlobalPreferencesStore: MenuBarSpacingPreferenceStoring {
    public init() {}

    public func integer(forKey key: String) -> Int? {
        let value = CFPreferencesCopyValue(
            key as CFString,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
        return (value as? NSNumber)?.intValue
    }

    public func setInteger(_ value: Int?, forKeys keys: [String]) -> Bool {
        for key in keys {
            CFPreferencesSetValue(
                key as CFString,
                value.map(NSNumber.init(value:)),
                kCFPreferencesAnyApplication,
                kCFPreferencesCurrentUser,
                kCFPreferencesCurrentHost
            )
        }
        return CFPreferencesSynchronize(
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
    }
}

public struct MenuBarSpacingState: Codable, Equatable, Sendable {
    public var usesCustomSpacing: Bool
    public var spacing: Int
    public var itemSpacing: Int?
    public var selectionPadding: Int?

    public init(
        usesCustomSpacing: Bool,
        spacing: Int,
        itemSpacing: Int?,
        selectionPadding: Int?
    ) {
        self.usesCustomSpacing = usesCustomSpacing
        self.spacing = spacing
        self.itemSpacing = itemSpacing
        self.selectionPadding = selectionPadding
    }
}

public enum MenuBarSpacingPreferences {
    public static let itemSpacingKey = "NSStatusItemSpacing"
    public static let selectionPaddingKey = "NSStatusItemSelectionPadding"
    public static let allKeys = [itemSpacingKey, selectionPaddingKey]
    public static let allowedSpacing = 0...6
    public static let recommendedSpacing = 6

    public static func read(
        from store: any MenuBarSpacingPreferenceStoring = CurrentHostGlobalPreferencesStore()
    ) -> MenuBarSpacingState {
        let itemSpacing = store.integer(forKey: itemSpacingKey)
        let selectionPadding = store.integer(forKey: selectionPaddingKey)
        let existingValue = itemSpacing ?? selectionPadding
        return MenuBarSpacingState(
            usesCustomSpacing: existingValue != nil,
            spacing: existingValue.map(clamp) ?? recommendedSpacing,
            itemSpacing: itemSpacing,
            selectionPadding: selectionPadding
        )
    }

    @discardableResult
    public static func write(
        _ value: Int?,
        to store: any MenuBarSpacingPreferenceStoring = CurrentHostGlobalPreferencesStore()
    ) -> Bool {
        store.setInteger(value, forKeys: allKeys)
    }

    public static func clamp(_ value: Int) -> Int {
        Swift.min(Swift.max(value, allowedSpacing.lowerBound), allowedSpacing.upperBound)
    }
}
