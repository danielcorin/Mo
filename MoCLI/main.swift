import Darwin
import Foundation
import MoCore

private enum ExitCode: Int32 {
    case failure = 1
    case usage = 2
}

private struct CLIError: LocalizedError {
    var message: String
    var isUsageError: Bool

    init(_ message: String, usage: Bool = false) {
        self.message = message
        isUsageError = usage
    }

    var errorDescription: String? { message }
}

private enum Action {
    case help
    case install
    case status
    case show
    case hide
    case toggle
    case settings
    case spacingStatus
    case setSpacing(Int)
    case resetSpacing
    case quit

    var request: MoCompanionRequest? {
        switch self {
        case .help, .install:
            nil
        case .status, .spacingStatus:
            MoCompanionRequest(command: .status)
        case .show:
            MoCompanionRequest(command: .showItems)
        case .hide:
            MoCompanionRequest(command: .hideItems)
        case .toggle:
            MoCompanionRequest(command: .toggleItems)
        case .settings:
            MoCompanionRequest(command: .openSettings)
        case .setSpacing(let spacing):
            MoCompanionRequest(command: .setSpacing, spacing: spacing)
        case .resetSpacing:
            MoCompanionRequest(command: .resetSpacing)
        case .quit:
            MoCompanionRequest(command: .quit)
        }
    }
}

private struct Invocation {
    var action: Action
    var json: Bool

    init(arguments: [String]) throws {
        json = arguments.contains("--json")
        let positional = try arguments.filter { argument in
            if argument == "--json" { return false }
            if argument.hasPrefix("-")
                && Int(argument) == nil
                && !["--help", "-h"].contains(argument)
            {
                throw CLIError(
                    "Unknown option '\(argument)'. Run `mo help` for usage.",
                    usage: true
                )
            }
            return true
        }

        let name = positional.first ?? "help"
        let values = Array(positional.dropFirst())
        switch name {
        case "help", "--help", "-h":
            guard values.isEmpty else { throw Self.tooManyArguments() }
            action = .help
        case "install":
            guard values.isEmpty else { throw Self.tooManyArguments() }
            action = .install
        case "status":
            guard values.isEmpty else { throw Self.tooManyArguments() }
            action = .status
        case "show":
            guard values.isEmpty else { throw Self.tooManyArguments() }
            action = .show
        case "hide":
            guard values.isEmpty else { throw Self.tooManyArguments() }
            action = .hide
        case "toggle":
            guard values.isEmpty else { throw Self.tooManyArguments() }
            action = .toggle
        case "settings":
            guard values.isEmpty else { throw Self.tooManyArguments() }
            action = .settings
        case "spacing":
            if values.isEmpty {
                action = .spacingStatus
            } else if values.count == 1,
                ["default", "reset", "system"].contains(values[0])
            {
                action = .resetSpacing
            } else if values.count == 1 {
                let rawValue = values[0]
                guard
                    let spacing = Int(rawValue),
                    MenuBarSpacingPreferences.allowedSpacing.contains(spacing)
                else {
                    throw CLIError(
                        "Spacing must be an integer from 0 through 6, or `default`.",
                        usage: true
                    )
                }
                action = .setSpacing(spacing)
            } else {
                throw CLIError(
                    "Usage: mo spacing [0-6|default] [--json]",
                    usage: true
                )
            }
        case "quit":
            guard values.isEmpty else { throw Self.tooManyArguments() }
            action = .quit
        default:
            throw CLIError(
                "Unknown command '\(name)'. Run `mo help` for usage.",
                usage: true
            )
        }
    }

    private static func tooManyArguments() -> CLIError {
        CLIError("Too many arguments. Run `mo help` for usage.", usage: true)
    }
}

private enum CompanionClient {
    static func sendLaunchingAppIfNeeded(_ request: MoCompanionRequest) throws
        -> MoCompanionResponse
    {
        let location = try AppLocation.resolve()
        if request.command == .status {
            if let response = try? send(request, location: location) {
                return response
            }
            try launchApp(at: location.appURL)
            for _ in 0..<50 {
                Thread.sleep(forTimeInterval: 0.1)
                if let response = try? send(request, location: location) {
                    return response
                }
            }
            throw CLIError("Mo could not be started. Open it and try again.")
        }

        let probe = MoCompanionRequest(command: .status)
        if (try? send(probe, location: location)) == nil {
            try launchApp(at: location.appURL)
            var isReady = false
            for _ in 0..<50 {
                Thread.sleep(forTimeInterval: 0.1)
                if (try? send(probe, location: location)) != nil {
                    isReady = true
                    break
                }
            }
            guard isReady else {
                throw CLIError("Mo could not be started. Open it and try again.")
            }
        }
        return try send(request, location: location)
    }

    static func sendIfRunning(_ request: MoCompanionRequest) throws -> MoCompanionResponse? {
        let location = try AppLocation.resolve()
        return try? send(request, location: location)
    }

    private static func send(
        _ request: MoCompanionRequest,
        location: AppLocation
    ) throws -> MoCompanionResponse {
        try MoLocalSocketClient.send(request, path: location.socketPath)
    }

    private static func launchApp(at appURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-g", appURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CLIError("Could not find Mo. Install or open the app and try again.")
        }
    }
}

private struct AppLocation {
    var appURL: URL
    var socketPath: String

    static func resolve() throws -> AppLocation {
        let fileManager = FileManager.default
        let executable = URL(fileURLWithPath: CommandLine.arguments[0])
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let containingApp =
            executable
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidates = [
            containingApp,
            URL(fileURLWithPath: "/Applications/Mo.app", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
                .appendingPathComponent("Mo.app", isDirectory: true),
        ]

        guard
            let appURL = candidates.first(where: {
                $0.pathExtension == "app"
                    && fileManager.fileExists(
                        atPath: $0.appendingPathComponent("Contents/Info.plist").path
                    )
            }),
            let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier
        else {
            throw CLIError("Could not find Mo. Install the app and try again.")
        }
        return AppLocation(
            appURL: appURL,
            socketPath: MoCompanionPaths.socketURL(bundleIdentifier: bundleIdentifier).path
        )
    }
}

private struct InstallOutput: Codable {
    var path: String
    var target: String
}

private enum CLIInstaller {
    static func install() throws -> InstallOutput {
        let fileManager = FileManager.default
        let executable = URL(fileURLWithPath: CommandLine.arguments[0])
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let appURL =
            executable
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard
            appURL.pathExtension == "app",
            executable.lastPathComponent == "mo",
            executable.deletingLastPathComponent().lastPathComponent == "Helpers"
        else {
            throw CLIError(
                "Install Mo.app first, then run /Applications/Mo.app/Contents/Helpers/mo install."
            )
        }

        let destination = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin", isDirectory: true)
            .appendingPathComponent("mo")
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if destinationExists(destination, fileManager: fileManager) {
            if resolves(destination, to: executable, fileManager: fileManager) {
                return InstallOutput(path: destination.path, target: executable.path)
            }
            guard isStaleMoLink(destination, fileManager: fileManager) else {
                throw CLIError(
                    "A file already exists at \(destination.path). Move it before installing Mo's CLI."
                )
            }
            try fileManager.removeItem(at: destination)
        }

        try fileManager.createSymbolicLink(at: destination, withDestinationURL: executable)
        return InstallOutput(path: destination.path, target: executable.path)
    }

    private static func destinationExists(_ url: URL, fileManager: FileManager) -> Bool {
        fileManager.fileExists(atPath: url.path)
            || ((try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true)
    }

    private static func resolves(_ link: URL, to target: URL, fileManager: FileManager) -> Bool {
        guard let rawDestination = try? fileManager.destinationOfSymbolicLink(atPath: link.path)
        else { return false }
        let destination = URL(fileURLWithPath: rawDestination, relativeTo: link.deletingLastPathComponent())
            .standardizedFileURL
            .resolvingSymlinksInPath()
        return destination == target.standardizedFileURL.resolvingSymlinksInPath()
    }

    private static func isStaleMoLink(_ link: URL, fileManager: FileManager) -> Bool {
        guard let target = try? fileManager.destinationOfSymbolicLink(atPath: link.path) else {
            return false
        }
        return target.hasSuffix("/Mo.app/Contents/Helpers/mo")
    }
}

private func printResponse(_ response: MoCompanionResponse, for action: Action, json: Bool) throws {
    if json {
        let data = try MoCompanionProtocol.makeEncoder(prettyPrinted: true).encode(response)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
        return
    }

    if case .status = action, let status = response.status {
        print("App: \(status.appName) \(status.version)")
        print("Running: yes (pid \(status.processIdentifier))")
        print("Hidden items: \(status.hiddenItemsVisible ? "shown" : "hidden")")
        print("Toggle: \(status.toggleVisible ? "visible" : "hidden")")
        print("Automatically hide: \(status.autoHidePolicy)")
        print("Hotkey: \(status.hotkey)")
        printSpacing(status.menuBarSpacing)
    } else if case .spacingStatus = action, let status = response.status {
        printSpacing(status.menuBarSpacing)
    } else if let message = response.message {
        print(message)
    }
}

private func printSpacing(_ spacing: MenuBarSpacingState) {
    if spacing.usesCustomSpacing {
        print("Menu bar spacing: \(spacing.spacing) pt")
        if spacing.itemSpacing != spacing.selectionPadding {
            print(
                "Stored values: item spacing \(spacing.itemSpacing.map(String.init) ?? "default"), "
                    + "selection padding \(spacing.selectionPadding.map(String.init) ?? "default")"
            )
        }
    } else {
        print("Menu bar spacing: macOS default")
    }
}

private func writeError(_ message: String) {
    FileHandle.standardError.write(Data("mo: \(message)\n".utf8))
}

private let help = """
    Mo companion CLI

    Usage:
      mo status [--json]                       Inspect Mo and menu-bar state
      mo show [--json]                         Show hidden menu bar items
      mo hide [--json]                         Hide Mo's menu bar section
      mo toggle [--json]                       Toggle hidden menu bar items
      mo settings [--json]                     Open Mo Settings
      mo spacing [--json]                      Show current system-wide spacing
      mo spacing <0-6> [--json]                Set compact system-wide spacing
      mo spacing default [--json]              Restore the macOS default
      mo quit [--json]                         Quit Mo if it is running
      mo install [--json]                      Link the bundled CLI into ~/.local/bin
      mo help                                  Show this help

    Commands launch Mo when needed and use a local, typed request/response channel.
    Spacing changes require signing out and back in before macOS applies them.
    """

do {
    let invocation = try Invocation(arguments: Array(CommandLine.arguments.dropFirst()))
    switch invocation.action {
    case .help:
        print(help)
    case .install:
        let output = try CLIInstaller.install()
        if invocation.json {
            let data = try MoCompanionProtocol.makeEncoder(prettyPrinted: true).encode(output)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } else {
            print("Installed \(output.path) -> \(output.target)")
        }
    case .quit:
        guard let request = invocation.action.request else { fatalError("Missing request") }
        if let response = try CompanionClient.sendIfRunning(request) {
            guard response.success else {
                throw CLIError(response.message ?? "Mo command failed.")
            }
            try printResponse(response, for: invocation.action, json: invocation.json)
        } else if invocation.json {
            let response = MoCompanionResponse(
                requestID: request.id,
                success: true,
                message: "Mo is not running."
            )
            try printResponse(response, for: invocation.action, json: true)
        } else {
            print("Mo is not running.")
        }
    default:
        guard let request = invocation.action.request else { fatalError("Missing request") }
        let response = try CompanionClient.sendLaunchingAppIfNeeded(request)
        guard response.success else {
            throw CLIError(response.message ?? "Mo command failed.")
        }
        try printResponse(response, for: invocation.action, json: invocation.json)
    }
} catch let error as CLIError {
    writeError(error.localizedDescription)
    if error.isUsageError {
        FileHandle.standardError.write(Data("\n\(help)\n".utf8))
        Darwin.exit(ExitCode.usage.rawValue)
    }
    Darwin.exit(ExitCode.failure.rawValue)
} catch {
    writeError(error.localizedDescription)
    Darwin.exit(ExitCode.failure.rawValue)
}
