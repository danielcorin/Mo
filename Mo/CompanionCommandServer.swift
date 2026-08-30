import AppKit
import Foundation
import MoCore

@MainActor
final class CompanionCommandServer {
    private let controller: MenuBarController
    private let preferences: MoPreferences
    private let spacingManager: MenuBarSpacingManager
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void
    private var socketServer: MoLocalSocketServer?

    init(
        controller: MenuBarController,
        preferences: MoPreferences,
        spacingManager: MenuBarSpacingManager,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.controller = controller
        self.preferences = preferences
        self.spacingManager = spacingManager
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    func start() {
        guard socketServer == nil, let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }
        let path = MoCompanionPaths.socketURL(bundleIdentifier: bundleIdentifier).path
        let server = MoLocalSocketServer(path: path) { [weak self] request in
            guard let self else {
                return MoCompanionResponse(
                    requestID: request.id,
                    success: false,
                    message: "Mo is shutting down.",
                    errorCode: "unavailable"
                )
            }
            return await self.handle(request)
        }
        do {
            try server.start()
            socketServer = server
        } catch {
            NSLog("Mo companion service failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        socketServer?.stop()
        socketServer = nil
    }

    private func handle(_ request: MoCompanionRequest) -> MoCompanionResponse {
        let response: MoCompanionResponse

        switch request.command {
        case .status:
            response = success(request, message: nil)
        case .showItems:
            controller.setItemsShown(true)
            response = success(request, message: "Hidden menu bar items are shown.")
        case .hideItems:
            controller.setItemsShown(false)
            response = success(request, message: "Hidden menu bar items are hidden.")
        case .toggleItems:
            controller.toggle()
            let state = controller.state == .shown ? "shown" : "hidden"
            response = success(request, message: "Hidden menu bar items are \(state).")
        case .openSettings:
            onOpenSettings()
            response = success(request, message: "Opened Mo Settings.")
        case .setSpacing:
            guard
                let spacing = request.spacing,
                MenuBarSpacingPreferences.allowedSpacing.contains(spacing)
            else {
                return MoCompanionResponse(
                    requestID: request.id,
                    success: false,
                    message: "Spacing must be between 0 and 6 points.",
                    errorCode: "invalid_spacing"
                )
            }
            guard spacingManager.setCustomSpacing(spacing) else {
                response = MoCompanionResponse(
                    requestID: request.id,
                    success: false,
                    message: spacingManager.errorMessage
                        ?? "Mo couldn’t update the macOS menu bar spacing.",
                    errorCode: "spacing_write_failed",
                    status: makeStatus()
                )
                break
            }
            response = success(
                request,
                message: "Menu bar spacing is \(spacing) pt. Sign out and back in to apply it."
            )
        case .resetSpacing:
            spacingManager.setCustomSpacingEnabled(false)
            guard !spacingManager.usesCustomSpacing else {
                response = MoCompanionResponse(
                    requestID: request.id,
                    success: false,
                    message: spacingManager.errorMessage
                        ?? "Mo couldn’t restore the default menu bar spacing.",
                    errorCode: "spacing_write_failed",
                    status: makeStatus()
                )
                break
            }
            response = success(
                request,
                message: "Restored the default menu bar spacing. Sign out and back in to apply it."
            )
        case .quit:
            response = success(request, message: "Quitting Mo.")
        }

        if request.command == .quit {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [onQuit] in
                onQuit()
            }
        }
        return response
    }

    private func success(
        _ request: MoCompanionRequest,
        message: String?
    ) -> MoCompanionResponse {
        MoCompanionResponse(
            requestID: request.id,
            success: true,
            message: message,
            status: makeStatus()
        )
    }

    private func makeStatus() -> MoCompanionStatus {
        let version =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "unknown"
        return MoCompanionStatus(
            appName: "Mo",
            version: version,
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            hiddenItemsVisible: controller.state == .shown,
            toggleVisible: controller.isToggleVisible ?? !preferences.hideToggle,
            autoHidePolicy: preferences.autoHidePolicy.rawValue,
            hotkey: preferences.hotkey.displayName,
            menuBarSpacing: MenuBarSpacingPreferences.read(),
            spacingChangeRequiresSignOut: spacingManager.requiresSignOut
        )
    }

}
