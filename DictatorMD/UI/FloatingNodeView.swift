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

    private let panelSize = NSSize(width: 190, height: 50)
    private let bottomOffset: CGFloat = 8

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
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func positionPanel(collapsed: Bool) {
        guard let panel else { return }
        let size = panelSize
        panel.setContentSize(size)

        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let x = screenFrame.midX - (size.width / 2)
        let y = screenFrame.minY + bottomOffset
        panel.setFrameOrigin(NSPoint(x: x, y: y))
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

    var body: some View {
        ZStack(alignment: .center) {
            expandedNode
                .opacity(isHovering ? 1 : 0)
                .scaleEffect(isHovering ? 1 : 0.92, anchor: .bottom)
                .offset(y: isHovering ? 0 : 7)
                .allowsHitTesting(isHovering)

            collapsedNode
                .opacity(isHovering ? 0 : 1)
                .scaleEffect(isHovering ? 0.84 : 1, anchor: .bottom)
                .offset(y: isHovering ? 7 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .contentShape(Capsule())
        .onHover { hovering in
            if hovering {
                collapseWorkItem?.cancel()
                collapseWorkItem = nil
                animateHover(true)
            } else {
                let work = DispatchWorkItem {
                    animateHover(false)
                }
                collapseWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: work)
            }
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
    }

    private var collapsedNode: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(statusColor)
            .frame(width: 96, height: 4)
            .shadow(color: statusColor.opacity(0.35), radius: 8)
            .padding(.bottom, 10)
            .accessibilityLabel("Dictation node")
            .onTapGesture {
                DebugLog.shared.log("[FloatingNode] collapsed tapped")
                collapseWorkItem?.cancel()
                collapseWorkItem = nil
                animateHover(true)
            }
    }

    private var expandedNode: some View {
        HStack(spacing: 8) {
            languageButton
            micButton
            settingsButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color.black.opacity(0.92) : Color.white.opacity(0.96))
        )
        .overlay(
            Capsule()
                .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.30 : 0.12), radius: 10, y: 4)
        .padding(.bottom, 5)
    }

    private var languageButton: some View {
        Button {
            cycleLanguage()
        } label: {
            Text(languageLabel)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(width: 42, height: 28)
                .background(Capsule().fill(Color.white.opacity(0.10)))
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
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(statusColor))
                .shadow(color: statusColor.opacity(0.35), radius: 10)
        }
        .buttonStyle(.plain)
        .help(engine.state == .recording ? "Stop dictation" : "Start dictation")
    }

    private var settingsButton: some View {
        Button {
            FloatingNodeController.shared.openSettingsWindow()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .help("Open settings")
    }

    private var statusColor: Color {
        switch engine.state {
        case .idle: engine.isModelLoaded ? .green : .orange
        case .recording: .red
        case .processing: .orange
        case .typing: .blue
        }
    }

    private var micIcon: String {
        switch engine.state {
        case .idle: "mic.fill"
        case .recording: "stop.fill"
        case .processing: "brain.head.profile.fill"
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
        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.9, blendDuration: 0.08)) {
            isHovering = hovering
        }
    }
}
