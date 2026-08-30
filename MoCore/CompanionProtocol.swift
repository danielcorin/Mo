import Foundation

public enum MoCompanionCommand: String, Codable, CaseIterable, Sendable {
    case status
    case showItems
    case hideItems
    case toggleItems
    case openSettings
    case setSpacing
    case resetSpacing
    case quit
}

public struct MoCompanionRequest: Codable, Equatable, Sendable {
    public var id: UUID
    public var command: MoCompanionCommand
    public var spacing: Int?

    public init(id: UUID = UUID(), command: MoCompanionCommand, spacing: Int? = nil) {
        self.id = id
        self.command = command
        self.spacing = spacing
    }
}

public struct MoCompanionStatus: Codable, Equatable, Sendable {
    public var appName: String
    public var version: String
    public var processIdentifier: Int32
    public var hiddenItemsVisible: Bool
    public var toggleVisible: Bool
    public var autoHidePolicy: String
    public var hotkey: String
    public var menuBarSpacing: MenuBarSpacingState
    public var spacingChangeRequiresSignOut: Bool

    public init(
        appName: String,
        version: String,
        processIdentifier: Int32,
        hiddenItemsVisible: Bool,
        toggleVisible: Bool,
        autoHidePolicy: String,
        hotkey: String,
        menuBarSpacing: MenuBarSpacingState,
        spacingChangeRequiresSignOut: Bool
    ) {
        self.appName = appName
        self.version = version
        self.processIdentifier = processIdentifier
        self.hiddenItemsVisible = hiddenItemsVisible
        self.toggleVisible = toggleVisible
        self.autoHidePolicy = autoHidePolicy
        self.hotkey = hotkey
        self.menuBarSpacing = menuBarSpacing
        self.spacingChangeRequiresSignOut = spacingChangeRequiresSignOut
    }
}

public struct MoCompanionResponse: Codable, Equatable, Sendable {
    public var requestID: UUID
    public var success: Bool
    public var message: String?
    public var errorCode: String?
    public var status: MoCompanionStatus?

    public init(
        requestID: UUID,
        success: Bool,
        message: String? = nil,
        errorCode: String? = nil,
        status: MoCompanionStatus? = nil
    ) {
        self.requestID = requestID
        self.success = success
        self.message = message
        self.errorCode = errorCode
        self.status = status
    }
}

public enum MoCompanionProtocol {
    public static func makeEncoder(prettyPrinted: Bool = false) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        if prettyPrinted {
            encoder.outputFormatting.insert(.prettyPrinted)
        }
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }
}
