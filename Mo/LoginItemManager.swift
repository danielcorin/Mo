import Combine
import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
    enum State: Equatable {
        case enabled
        case disabled
        case requiresApproval
        case unavailable
    }

    @Published private(set) var state: State = .disabled
    @Published private(set) var errorMessage: String?

    var isEnabled: Bool { state == .enabled || state == .requiresApproval }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled: state = .enabled
        case .notRegistered: state = .disabled
        case .requiresApproval: state = .requiresApproval
        case .notFound: state = .unavailable
        @unknown default: state = .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
