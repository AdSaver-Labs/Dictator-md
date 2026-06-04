import AVFoundation
import Cocoa

final class PermissionManager: ObservableObject, @unchecked Sendable {
    static nonisolated(unsafe) let shared = PermissionManager()

    @Published var microphoneGranted = false
    @Published var accessibilityGranted = false
    private var lastAccessibilityPromptAt = Date.distantPast

    var allPermissionsGranted: Bool {
        microphoneGranted && accessibilityGranted
    }

    init() {
        checkPermissions()
        requestMicrophoneIfNotDetermined()
    }

    func checkPermissions() {
        checkMicrophone()
        checkAccessibility()
    }

    // MARK: - Microphone

    func checkMicrophone() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneGranted = true
        case .notDetermined:
            microphoneGranted = false
        case .denied, .restricted:
            microphoneGranted = false
        @unknown default:
            microphoneGranted = false
        }
    }

    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.microphoneGranted = granted
                DebugLog.shared.log("[PermissionManager] requestMicrophone granted=\(granted)")
            }
        }
    }

    func requestMicrophoneIfNotDetermined() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return }
        DebugLog.shared.log("[PermissionManager] requestMicrophoneIfNotDetermined")
        requestMicrophone()
    }

    // MARK: - Accessibility

    func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        accessibilityGranted = trusted
        DebugLog.shared.log("[PermissionManager] checkAccessibility trusted=\(trusted) eventTapOperational=\(HotkeyMonitor.eventTapOperational) shownGranted=\(accessibilityGranted)")
    }

    func requestAccessibilityPromptIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        promptForAccessibilityIfNeeded()
    }

    func markAccessibilityOperational() {
        let trusted = AXIsProcessTrusted()
        accessibilityGranted = trusted
        DebugLog.shared.log("[PermissionManager] markAccessibilityOperational trusted=\(trusted)")
    }

    private func promptForAccessibilityIfNeeded(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastAccessibilityPromptAt) > 30 else { return }
        lastAccessibilityPromptAt = Date()
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        promptForAccessibilityIfNeeded(force: true)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }
}
