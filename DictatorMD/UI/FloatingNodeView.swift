import AppKit
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

    private let panelSize = NSSize(width: 420, height: 150)
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
                contentRect: NSRect(x: 0, y: 0, width: panelSize.width, height: panelSize.height),
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

        let view = FloatingNodeView(engine: engine)
        let host = NSHostingView(rootView: view)
        hostingView = host
        panel?.contentView = host
        positionPanel(collapsed: true)
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

    func positionPanel(collapsed: Bool) {
        guard let panel else { return }
        let size = panelSize
        panel.setContentSize(size)

        let screenFrame = preferredScreen()?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let x = screenFrame.midX - (size.width / 2)
        let y = screenFrame.minY + bottomOffset
        panel.setFrameOrigin(NSPoint(x: x, y: y))
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

    @objc private func displayConfigurationDidChange() {
        positionPanel(collapsed: true)
    }

    func openSettingsWindow() {
        openSettingsAction?()
    }
}

extension Notification.Name {
    static let floatingNodeOpenSettings = Notification.Name("floatingNodeOpenSettings")
}

struct FloatingNodeView: View {
    let engine: DictationEngine
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
                        insertion: .offset(y: 8).combined(with: .scale(scale: 0.94, anchor: .bottom)),
                        removal: .offset(y: 6).combined(with: .scale(scale: 0.96, anchor: .bottom))
                    ))
            } else {
                collapsedNode
                    .transition(.asymmetric(
                        insertion: .offset(y: -4).combined(with: .scale(scale: 0.96, anchor: .bottom)),
                        removal: .offset(y: 6).combined(with: .scale(scale: 0.92, anchor: .bottom))
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86, blendDuration: 0.04), value: isHovering)
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
        .onAppear {
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                activityPulse = true
            }
        }
    }

    private var collapsedNode: some View {
        Capsule()
            .fill(statusColor.opacity(0.58))
            .frame(width: isWorking ? 74 : 92, height: isWorking ? 12 : 5)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(0.65)
            )
            .overlay(
                Capsule()
                    .stroke(statusColor.opacity(0.78), lineWidth: 1.2)
            )
            .overlay {
                if isWorking {
                    LoadingDots(color: .white, dotSize: 3.6, spacing: 4)
                }
            }
            .shadow(color: statusColor.opacity(isWorking ? 0.38 : 0.22), radius: isWorking ? 8 : 4)
            .padding(.bottom, 10)
            .contentShape(Capsule())
            .onHover { hovering in
                handleHover(hovering)
            }
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
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color.black.opacity(0.88) : Color.white.opacity(0.94))
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.26 : 0.10), radius: 10, y: 4)
        .padding(.bottom, 5)
        .contentShape(Capsule())
        .onHover { hovering in
            handleHover(hovering)
        }
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
                .background(Capsule().fill(statusColor.opacity(0.13)))
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
                .overlay(Circle().stroke(Color.white.opacity(engine.state == .idle ? 0.26 : 0.16), lineWidth: 1))
                .shadow(color: statusColor.opacity(0.42), radius: 10)
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
                .background(Circle().fill(statusColor.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .help("Open settings")
    }

    private var statusColor: Color {
        switch engine.state {
        case .idle: engine.isModelLoaded ? DictatorBrand.yellow : .orange
        case .recording: .red
        case .processing, .preview: DictatorBrand.cyan
        case .typing: DictatorBrand.cyan
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
        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.92, blendDuration: 0.04)) {
            isHovering = hovering
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
                    let phase = (sin((time * 5.2) - Double(index) * 0.72) + 1) / 2
                    Circle()
                        .fill(color.opacity(0.36 + phase * 0.64))
                        .frame(width: dotSize, height: dotSize)
                        .offset(y: CGFloat(-phase * 2.4))
                        .scaleEffect(0.82 + phase * 0.24)
                }
            }
        }
    }
}
