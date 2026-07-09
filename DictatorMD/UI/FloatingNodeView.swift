import AppKit
import QuartzCore
import SwiftUI

final class FloatingNodePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class FloatingNodeController {
    static let shared = FloatingNodeController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingNodeView>?
    private weak var engine: DictationEngine?
    var openSettingsAction: (() -> Void)?

    private let collapsedIdlePanelSize = NSSize(width: 92, height: 5)
    private let collapsedWorkingPanelSize = NSSize(width: 74, height: 12)
    private let expandedPanelSize = NSSize(width: 276, height: 58)
    private let previewPanelSize = NSSize(width: 360, height: 132)
    private let bottomOffset: CGFloat = 14

    private init() {}

    func configure(engine: DictationEngine) {
        self.engine = engine
        if AppSettings.shared.floatingNodeEnabled {
            show(engine: engine)
        } else {
            hide()
        }
    }

    func show(engine: DictationEngine) {
        if panel == nil {
            let panel = FloatingNodePanel(
                contentRect: NSRect(x: 0, y: 0, width: collapsedIdlePanelSize.width, height: collapsedIdlePanelSize.height),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel.isReleasedWhenClosed = false
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = false
            panel.acceptsMouseMovedEvents = true
            panel.isMovableByWindowBackground = false
            panel.title = "Dictator-md Floating Node"
            self.panel = panel
        }

        let view = FloatingNodeView(engine: engine) { [weak self] presentation in
            self?.setPresentation(presentation)
        }
        let host = NSHostingView(rootView: view)
        hostingView = host
        panel?.contentView = host
        setPresentation(.collapsed, animated: false)
        panel?.orderFrontRegardless()

        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func hide() {
        panel?.orderOut(nil)
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func setPresentation(_ presentation: FloatingNodePresentation, animated: Bool = true) {
        guard let panel else { return }
        let size: NSSize
        switch presentation {
        case .collapsed:
            size = collapsedPanelSize()
        case .expanded:
            size = expandedPanelSize
        case .preview:
            size = previewPanelSize
        }

        let screenFrame = preferredScreen()?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let x = screenFrame.midX - (size.width / 2)
        let y = screenFrame.minY + bottomOffset
        let targetFrame = NSRect(x: x, y: y, width: size.width, height: size.height)

        if animated, panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }
    }

    private func preferredScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return mouseScreen
        }
        if let panelScreen = panel?.screen {
            return panelScreen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func collapsedPanelSize() -> NSSize {
        guard let engine else { return collapsedIdlePanelSize }
        return isWorking(engine.state) ? collapsedWorkingPanelSize : collapsedIdlePanelSize
    }

    private func isWorking(_ state: DictationState) -> Bool {
        state == .processing || state == .preview || state == .typing
    }

    @objc private func displayConfigurationDidChange() {
        setPresentation(.collapsed, animated: false)
    }

    func openSettingsWindow() {
        openSettingsAction?()
    }
}

enum FloatingNodePresentation {
    case collapsed
    case expanded
    case preview
}

extension Notification.Name {
    static let floatingNodeOpenSettings = Notification.Name("floatingNodeOpenSettings")
}

struct FloatingNodeView: View {
    let engine: DictationEngine
    let presentationChanged: (FloatingNodePresentation) -> Void
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var collapseWorkItem: DispatchWorkItem?
    @State private var activityPulse = false

    var body: some View {
        ZStack(alignment: .center) {
            if isHovering {
                expandedNode
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                        removal: .identity
                    ))
            } else {
                collapsedNode
                    .transition(.identity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onHover { hovering in
            handleHover(hovering)
        }
        .onChange(of: settings.floatingNodeEnabled) { _, enabled in
            if enabled {
                FloatingNodeController.shared.show(engine: engine)
            } else {
                FloatingNodeController.shared.hide()
            }
        }
        .onDisappear {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
        }
        .onChange(of: engine.state) { _, state in
            if isHovering {
                presentationChanged(state == .preview ? .preview : .expanded)
            } else {
                presentationChanged(.collapsed)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                activityPulse = true
            }
        }
    }

    private var collapsedNode: some View {
        Capsule()
            .fill(statusColor.opacity(0.72))
            .frame(width: isWorking ? 74 : 92, height: isWorking ? 12 : 5)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(0.76)
            )
            .overlay(
                Capsule()
                    .stroke(statusColor.opacity(0.92), lineWidth: 1.2)
            )
            .overlay {
                if isWorking {
                    LoadingDots(color: .white, dotSize: 3.6, spacing: 4)
                }
            }
            .shadow(color: statusColor.opacity(isWorking ? 0.44 : 0.28), radius: isWorking ? 8 : 4)
            .contentShape(Capsule())
            .accessibilityLabel("Dictation node")
            .onTapGesture {
                DebugLog.shared.log("[FloatingNode] collapsed tapped")
                collapseWorkItem?.cancel()
                collapseWorkItem = nil
                animateHover(true)
            }
    }

    private var expandedNode: some View {
        VStack(spacing: 8) {
            if engine.state == .preview {
                TextEditor(text: Binding(
                    get: { engine.previewText },
                    set: { engine.previewText = $0 }
                ))
                .font(.system(size: 12))
                .frame(height: 58)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
            } else if !engine.partialTranscription.isEmpty {
                Text(engine.partialTranscription)
                    .font(.system(size: 11))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let error = engine.userFacingError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                languageButton
                if engine.state == .preview {
                    Button("Discard") { engine.discardPreview() }
                        .buttonStyle(.borderless)
                    Button("Insert") { engine.acceptPreview() }
                        .buttonStyle(.borderedProminent)
                } else {
                    micButton
                    if engine.state != .idle {
                        Button { engine.cancelCurrentOperation() } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                        .help("Cancel (Escape)")
                    }
                    if isWorking { processingIndicator }
                    if engine.canUndoLastInsertion {
                        Button { engine.undoLastInsertion() } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .buttonStyle(.plain)
                        .help("Undo last insertion")
                    }
                }
                settingsButton
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color.black.opacity(0.88) : Color.white.opacity(0.94))
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 8, y: 3)
        .contentShape(Capsule())
    }

    private var languageButton: some View {
        Button {
            cycleLanguage()
        } label: {
            Text(languageLabel)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(width: 42, height: 28)
                .foregroundStyle(statusColor)
                .background(Capsule().fill(statusColor.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .help("Switch language")
    }

    private var micButton: some View {
        Button {
            DebugLog.shared.log("[FloatingNode] micButton clicked state=\(engine.state.rawValue)")
            engine.toggleDictationFromUI()
        } label: {
            Image(systemName: micIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(engine.state == .idle ? DictatorBrand.ink : .white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(statusColor))
                .overlay(Circle().stroke(Color.white.opacity(engine.state == .idle ? 0.30 : 0.20), lineWidth: 1))
                .shadow(color: statusColor.opacity(0.48), radius: 10)
        }
        .buttonStyle(.plain)
        .help(engine.state == .recording ? "Stop dictation" : "Start dictation")
    }

    private var processingIndicator: some View {
        LoadingDots(color: statusColor, dotSize: 5, spacing: 4)
        .frame(width: 24, height: 28)
        .help(engine.state == .processing ? "Transcribing..." : "Pasting...")
    }

    private var settingsButton: some View {
        Button {
            FloatingNodeController.shared.openSettingsWindow()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(statusColor.opacity(0.14)))
        }
        .buttonStyle(.plain)
        .help("Open settings")
    }

    private var statusColor: Color {
        switch engine.state {
        case .idle: engine.isModelLoaded ? DictatorBrand.yellow : .orange
        case .recording: Color(red: 1.0, green: 0.18, blue: 0.22)
        case .processing, .preview: Color(red: 0.24, green: 0.72, blue: 1.0)
        case .typing: Color(red: 0.24, green: 0.72, blue: 1.0)
        }
    }

    private var isWorking: Bool {
        engine.state == .processing || engine.state == .preview || engine.state == .typing
    }

    private var micIcon: String {
        switch engine.state {
        case .idle: "mic.fill"
        case .recording: "stop.fill"
        case .processing: "brain.head.profile.fill"
        case .preview: "pencil.and.list.clipboard"
        case .typing: "text.cursor"
        }
    }

    private var languageLabel: String {
        switch settings.dictationLanguage {
        case .auto: "Auto"
        case .bulgarian: "BG"
        case .english: "EN"
        }
    }

    private func cycleLanguage() {
        switch settings.dictationLanguage {
        case .auto:
            settings.dictationLanguage = .bulgarian
        case .bulgarian:
            settings.dictationLanguage = .english
        case .english:
            settings.dictationLanguage = .auto
        }
    }

    private func animateHover(_ hovering: Bool) {
        if hovering {
            presentationChanged(engine.state == .preview ? .preview : .expanded)
        }
        withAnimation(.easeOut(duration: hovering ? 0.14 : 0.10)) {
            isHovering = hovering
        }
        if !hovering {
            presentationChanged(.collapsed)
        }
    }

    private func handleHover(_ hovering: Bool) {
        if hovering {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
            animateHover(true)
        } else {
            let work = DispatchWorkItem {
                animateHover(false)
            }
            collapseWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
        }
    }
}

private struct LoadingDots: View {
    let color: Color
    let dotSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { index in
                    let wave = sin((time * 5.2) - Double(index) * 0.72)
                    let intensity = (wave + 1) / 2
                    Circle()
                        .fill(color.opacity(0.40 + intensity * 0.60))
                        .frame(width: dotSize, height: dotSize)
                        .offset(y: CGFloat(wave * 2.1))
                        .scaleEffect(0.86 + intensity * 0.18)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
