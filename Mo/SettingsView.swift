import AppKit
import ServiceManagement
import SwiftUI

enum SettingsWindowLayout {
    static let width: CGFloat = 560
    static let height: CGFloat = 520
    static let contentSize = NSSize(width: width, height: height)
}

struct SettingsView: View {
    @ObservedObject var controller: MenuBarController
    @ObservedObject var preferences: MoPreferences
    @ObservedObject var loginItemManager: LoginItemManager

    var body: some View {
        Form {
            Section("Startup") {
                Toggle(
                    "Launch Mo at login",
                    isOn: Binding(
                        get: { loginItemManager.isEnabled },
                        set: { loginItemManager.setEnabled($0) }
                    )
                )
                if loginItemManager.state == .requiresApproval {
                    HStack {
                        Label("Approve Mo in Login Items to finish setup.", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Open Login Items") { loginItemManager.openSystemSettings() }
                    }
                }
                if let error = loginItemManager.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Section("Visibility") {
                LabeledContent("Hidden section") {
                    Button(controller.state == .hidden ? "Show now" : "Hide now") {
                        controller.toggle()
                    }
                }

                Picker("Automatically hide", selection: $preferences.autoHidePolicy) {
                    ForEach(AutoHidePolicy.allCases) { policy in
                        Text(policy.title).tag(policy)
                    }
                }

                Toggle("Hide Mo's menu bar button", isOn: $preferences.hideToggle)
                Text("While enabled, the button stays out of the menu bar in both states. Use \(preferences.hotkey.displayName) to toggle items, or reopen Mo to access settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Keyboard shortcut") {
                LabeledContent("Toggle hidden items") {
                    HotkeyRecorder(hotkey: $preferences.hotkey)
                }
                if let error = controller.hotkeyError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                } else {
                    Text("Mo registers one system shortcut and does not monitor or store your keystrokes. ⌘, remains reserved for the active app and cannot be assigned.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

        }
        .formStyle(.grouped)
        .frame(
            width: SettingsWindowLayout.width,
            height: SettingsWindowLayout.height
        )
        .onAppear { loginItemManager.refresh() }
    }
}

private struct HotkeyRecorder: View {
    @Binding var hotkey: Hotkey
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            Button(isRecording ? "Press shortcut…" : hotkey.displayName) {
                isRecording = true
            }
            .buttonStyle(.bordered)
            .frame(minWidth: 115)
            .background {
                KeyCaptureView(isCapturing: $isRecording) { captured in
                    if let captured { hotkey = captured }
                }
            }

            if hotkey != .defaultHotkey {
                Button("Reset") { hotkey = .defaultHotkey }
                    .buttonStyle(.link)
            }
        }
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    @Binding var isCapturing: Bool
    let onCapture: (Hotkey?) -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onCapture = finishCapture
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.onCapture = finishCapture
        guard isCapturing, nsView.window?.firstResponder !== nsView else { return }
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    private func finishCapture(_ hotkey: Hotkey?) {
        onCapture(hotkey)
        isCapturing = false
    }
}

private final class ShortcutCaptureNSView: NSView {
    var onCapture: ((Hotkey?) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCapture?(nil)
            return
        }
        guard let hotkey = Hotkey.from(event: event) else {
            NSSound.beep()
            return
        }
        onCapture?(hotkey)
    }
}
