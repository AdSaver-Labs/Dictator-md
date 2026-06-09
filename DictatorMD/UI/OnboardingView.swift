import SwiftUI
import Carbon.HIToolbox

struct OnboardingView: View {
    @ObservedObject private var permissions = PermissionManager.shared
    @ObservedObject private var modelManager = ModelManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @Binding var isPresented: Bool
    @State private var step = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.colorScheme) private var colorScheme

    private let steps: [OnboardingStep] = [
        OnboardingStep(title: "Dictate Anywhere", subtitle: "A private local voice layer for every text box on your Mac.", icon: "waveform"),
        OnboardingStep(title: "System Access", subtitle: "Microphone captures your voice. Accessibility inserts the text where you started.", icon: "lock.shield.fill"),
        OnboardingStep(title: "Choose Your Trigger", subtitle: "Pick the key and recording style that feel natural for long work sessions.", icon: "keyboard.fill"),
        OnboardingStep(title: "Language & Intelligence", subtitle: "Set English, Bulgarian, or auto mode, then tune cleanup and intonation.", icon: "sparkles"),
        OnboardingStep(title: "Local Engine", subtitle: "Select the offline Whisper model that balances speed and quality.", icon: "brain.head.profile.fill")
    ]

    var body: some View {
        HStack(spacing: 0) {
            introRail
            Divider().opacity(colorScheme == .dark ? 0.25 : 0.45)
            stepContent
        }
        .frame(width: 820, height: 520)
        .background(
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(red: 0.055, green: 0.06, blue: 0.068), Color(red: 0.11, green: 0.115, blue: 0.125)]
                        : [Color(red: 1.0, green: 0.975, blue: 0.91), Color(red: 0.94, green: 0.955, blue: 0.97)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(DictatorBrand.yellow.opacity(colorScheme == .dark ? 0.18 : 0.24))
                    .blur(radius: 70)
                    .frame(width: 260, height: 260)
                    .offset(x: -300, y: -210)
                Circle()
                    .fill(DictatorBrand.cyan.opacity(colorScheme == .dark ? 0.12 : 0.16))
                    .blur(radius: 76)
                    .frame(width: 280, height: 280)
                    .offset(x: 360, y: 230)
            }
        )
        .onAppear {
            permissions.checkPermissions()
        }
    }

    private var introRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            DictatorLogoMark(size: 62)

            VStack(alignment: .leading, spacing: 6) {
                Text("Dictator-md")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Local AI dictation setup")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(steps.indices, id: \.self) { index in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(index <= step ? DictatorBrand.yellow : Color.secondary.opacity(0.16))
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(index <= step ? DictatorBrand.ink : .secondary)
                        }
                        .frame(width: 22, height: 22)

                        Text(steps[index].title)
                            .font(.system(size: 12, weight: index == step ? .semibold : .regular))
                            .foregroundStyle(index == step ? .primary : .secondary)
                    }
                }
            }
            .padding(.top, 8)

            Spacer()

            HStack(spacing: 7) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? DictatorBrand.yellow : Color.secondary.opacity(0.22))
                        .frame(width: index == step ? 26 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.22), value: step)
                }
            }
        }
        .padding(28)
        .frame(width: 250, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? Color.black.opacity(0.20) : Color.white.opacity(0.42))
    }

    private var stepContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(steps[step].title, systemImage: steps[step].icon)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                    Text(steps[step].subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    finish()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.secondary.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }

            Group {
                switch step {
                case 0: welcomeStep
                case 1: permissionsStep
                case 2: hotkeyStep
                case 3: intelligenceStep
                default: modelStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        step = max(0, step - 1)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(step == 0)

                Spacer()

                Button(step == steps.count - 1 ? "Start Dictating" : "Continue") {
                    if step == steps.count - 1 {
                        finish()
                    } else {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            step = min(steps.count - 1, step + 1)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(DictatorBrand.yellow)
                .foregroundStyle(DictatorBrand.ink)
            }
        }
        .padding(30)
    }

    private var welcomeStep: some View {
        HStack(spacing: 16) {
            OnboardingFeatureCard(icon: "cursorarrow.click.2", title: "Works anywhere", text: "Dictate into chats, docs, terminals, browsers, and native apps.", color: DictatorBrand.green)
            OnboardingFeatureCard(icon: "lock.fill", title: "Fully local", text: "Speech, history, and vocabulary stay on your machine.", color: DictatorBrand.yellow)
            OnboardingFeatureCard(icon: "globe.europe.africa.fill", title: "EN + BG", text: "Designed around English, Bulgarian, and mixed tech vocabulary.", color: DictatorBrand.cyan)
        }
    }

    private var permissionsStep: some View {
        VStack(spacing: 12) {
            PermissionRow(
                icon: "mic.fill",
                title: "Microphone",
                description: "Captures your voice for local transcription.",
                isGranted: permissions.microphoneGranted,
                action: { permissions.requestMicrophone() }
            )
            PermissionRow(
                icon: "hand.raised.fill",
                title: "Accessibility",
                description: "Lets Dictator-md paste text back into the app you started from.",
                isGranted: permissions.accessibilityGranted,
                action: { permissions.openAccessibilitySettings() }
            )
            Button {
                permissions.checkPermissions()
            } label: {
                Label("Refresh access status", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private var hotkeyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            OnboardingHotkeyRecorder(keyCode: $settings.hotkeyKeyCode)
            Picker("Mode", selection: $settings.hotkeyMode) {
                Text("Hold to dictate").tag(AppSettings.HotkeyMode.pushToTalk)
                Text("Press to start / stop").tag(AppSettings.HotkeyMode.toggle)
            }
            .pickerStyle(.segmented)
            Text(settings.hotkeyMode == .pushToTalk
                 ? "Best for short commands and fast corrections."
                 : "Best for long prompts because you do not need to keep holding the key.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var intelligenceStep: some View {
        VStack(spacing: 14) {
            Picker("Language", selection: $settings.dictationLanguage) {
                ForEach(AppSettings.DictationLanguage.allCases) { language in
                    Text(language.label).tag(language)
                }
            }
            .pickerStyle(.segmented)

            ToggleRow(title: "Grammar cleanup", subtitle: "Fix casing, punctuation, and common dictation roughness.", isOn: $settings.grammarCorrectionEnabled)
            ToggleRow(title: "Number conversion", subtitle: "Turn spoken numbers into digits when it makes sense.", isOn: $settings.numberConversionEnabled)
            ToggleRow(title: "Intonation formatting", subtitle: "Experimental: use voice cues for questions and emphasis.", isOn: $settings.intonationFormattingEnabled)
        }
    }

    private var modelStep: some View {
        VStack(spacing: 12) {
            ModelDownloadRow(modelManager: modelManager)
            ToggleRow(title: "Floating node", subtitle: "Show the tiny overlay controller while Dictator-md is running.", isOn: $settings.floatingNodeEnabled)
            ToggleRow(title: "Sound feedback", subtitle: "Play short start/stop sounds so recording state is obvious.", isOn: $settings.soundFeedbackEnabled)
        }
    }

    private func finish() {
        hasCompletedOnboarding = true
        isPresented = false
    }
}

private struct OnboardingStep {
    let title: String
    let subtitle: String
    let icon: String
}

private struct OnboardingFeatureCard: View {
    let icon: String
    let title: String
    let text: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(DictatorBrand.ink)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9).fill(color))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.11), lineWidth: 1))
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isGranted ? DictatorBrand.green : DictatorBrand.yellow)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isGranted {
                Button("Grant", action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.11), lineWidth: 1))
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}

private struct OnboardingHotkeyRecorder: View {
    @Binding var keyCode: Int
    @State private var isRecording = false
    @State private var eventMonitors: [Any] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                toggleRecording()
            } label: {
                HStack {
                    Image(systemName: isRecording ? "record.circle.fill" : "keyboard.fill")
                        .foregroundStyle(isRecording ? .red : DictatorBrand.yellow)
                    Text(isRecording ? "Press any key..." : keyName(for: keyCode))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    Text("Change")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isRecording ? DictatorBrand.yellow.opacity(0.65) : Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: 7) {
                quickKey("Right Option", 61)
                quickKey("Left Option", 58)
                quickKey("Fn", 63)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func quickKey(_ title: String, _ code: Int) -> some View {
        Button(title) {
            keyCode = code
            stopRecording()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            keyCode = Int(event.keyCode)
            stopRecording()
            return nil
        }
        let flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            let code = Int(event.keyCode)
            if [54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(code) {
                keyCode = code
                stopRecording()
            }
            return nil
        }
        if let keyMonitor { eventMonitors.append(keyMonitor) }
        if let flagsMonitor { eventMonitors.append(flagsMonitor) }
    }

    private func stopRecording() {
        isRecording = false
        for monitor in eventMonitors { NSEvent.removeMonitor(monitor) }
        eventMonitors.removeAll()
    }

    private func keyName(for code: Int) -> String {
        switch code {
        case 61: return "Right Option"
        case 58: return "Left Option"
        case 63: return "Fn"
        case 62: return "Right Control"
        case 59: return "Left Control"
        case 49: return "Space"
        default: return "Key \(code)"
        }
    }
}

private struct ModelDownloadRow: View {
    @ObservedObject var modelManager: ModelManager

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: modelManager.activeModelPath() != nil ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(modelManager.activeModelPath() != nil ? DictatorBrand.green : DictatorBrand.yellow)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text("Offline Whisper model")
                    .font(.system(size: 14, weight: .semibold))
                if modelManager.isDownloading {
                    ProgressView(value: modelManager.downloadProgress)
                    Text("Downloading... \(Int(modelManager.downloadProgress * 100))%")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else if modelManager.activeModelPath() != nil {
                    Text("A local model is ready.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Download a local model before serious dictation.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if modelManager.activeModelPath() == nil && !modelManager.isDownloading {
                Button("Download Small") {
                    Task { try? await modelManager.downloadModel(.smallEn) }
                }
                .buttonStyle(.borderedProminent)
                .tint(DictatorBrand.yellow)
                .foregroundStyle(DictatorBrand.ink)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.11), lineWidth: 1))
    }
}
