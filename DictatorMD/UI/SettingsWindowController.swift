import AppKit
import SwiftUI

final class InteractiveSettingsWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var hostingController: NSHostingController<SettingsView>?
    private weak var engine: DictationEngine?

    private init() {}

    func configure(engine: DictationEngine) {
        self.engine = engine
    }

    func show(engine: DictationEngine? = nil) {
        if let engine {
            self.engine = engine
        }
        guard let engine = self.engine else { return }

        if window == nil {
            let hostingController = NSHostingController(rootView: SettingsView(engine: engine))
            let window = InteractiveSettingsWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1200, height: 820),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Dictator-md"
            window.isReleasedWhenClosed = false
            window.contentViewController = hostingController
            window.minSize = NSSize(width: 920, height: 680)
            window.level = .normal
            window.collectionBehavior = [.managed, .fullScreenPrimary]
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.isMovableByWindowBackground = false
            window.standardWindowButton(.closeButton)?.isEnabled = true
            window.standardWindowButton(.miniaturizeButton)?.isEnabled = true
            window.standardWindowButton(.zoomButton)?.isEnabled = true
            window.centerOnMainScreen()
            self.hostingController = hostingController
            self.window = window
        }

        bringToFront()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.bringToFront()
            self?.logWindowState(prefix: "[SettingsWindowController] showAfterActivation")
        }
        logWindowState(prefix: "[SettingsWindowController] show")
    }

    private func bringToFront() {
        NSApp.setActivationPolicy(.regular)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        window?.centerOnMainScreenIfNeeded()
        window?.makeKeyAndOrderFront(nil)
        window?.makeMain()
        window?.orderFrontRegardless()
    }

    private func logWindowState(prefix: String) {
        DebugLog.shared.log("\(prefix) key=\(window?.isKeyWindow ?? false) main=\(window?.isMainWindow ?? false) visible=\(window?.isVisible ?? false) ignoresMouse=\(window?.ignoresMouseEvents ?? true)")
    }
}

extension NSWindow {
    func centerOnMainScreen() {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? frame
        let x = visibleFrame.midX - frame.width / 2
        let y = visibleFrame.midY - frame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func centerOnMainScreenIfNeeded() {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? frame
        if !visibleFrame.intersects(frame) || frame.minY < visibleFrame.minY || frame.maxY > visibleFrame.maxY + 80 {
            centerOnMainScreen()
        }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window, context: context)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: view.window, context: context)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func configure(window: NSWindow?, context: Context) {
        guard let window else { return }
        window.title = "Dictator-md"
        window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
        window.minSize = NSSize(width: 920, height: 680)
        window.isMovable = true
        window.ignoresMouseEvents = false
        if !context.coordinator.didConfigure {
            context.coordinator.didConfigure = true
            window.setContentSize(NSSize(width: 1200, height: 820))
            window.centerOnMainScreen()
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    final class Coordinator {
        var didConfigure = false
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = DictationEngine()
    private var localMouseMonitor: Any?
    private var statusItem: NSStatusItem?
    private var statusTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        installMainMenu()
        installStatusItem()
        installLocalMouseLogger()
        _ = FocusTracker.shared
        SettingsWindowController.shared.configure(engine: engine)
        FloatingNodeController.shared.openSettingsAction = { [weak self] in
            guard let self else { return }
            SettingsWindowController.shared.show(engine: self.engine)
        }
        FloatingNodeController.shared.configure(engine: engine)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            SettingsWindowController.shared.show(engine: self.engine)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show(engine: engine)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        DebugLog.shared.log("[AppDelegate] didBecomeActive")
    }

    @objc private func showSettingsFromMenu() {
        SettingsWindowController.shared.show(engine: engine)
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Show Dictator-md",
            action: #selector(showSettingsFromMenu),
            keyEquivalent: ","
        ).target = self
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit Dictator-md",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Paste and Match Style", action: #selector(NSTextView.pasteAsPlainText(_:)), keyEquivalent: "V")
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(toggleStatusMenu(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        updateStatusItem()

        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.updateStatusItem()
        }
        RunLoop.main.add(timer, forMode: .common)
        statusTimer = timer
    }

    @objc private func toggleStatusMenu(_ sender: Any?) {
        guard let statusItem else { return }
        statusItem.menu = makeStatusMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let status = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Open Settings", action: #selector(showSettingsFromMenu), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let language = NSMenuItem(title: "Language: \(AppSettings.shared.dictationLanguage.label)", action: nil, keyEquivalent: "")
        language.isEnabled = false
        menu.addItem(language)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Dictator-md", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: statusIconName, accessibilityDescription: statusTitle)
        button.image?.isTemplate = engine.state != .recording
        button.toolTip = statusTitle
    }

    private var statusTitle: String {
        switch engine.state {
        case .idle:
            engine.isModelLoaded ? "Dictator-md Ready" : "Dictator-md Loading Model"
        case .recording:
            "Dictator-md Listening"
        case .processing:
            "Dictator-md Transcribing"
        case .typing:
            "Dictator-md Typing"
        }
    }

    private var statusIconName: String {
        switch engine.state {
        case .idle: "waveform.badge.mic"
        case .recording: "mic.circle.fill"
        case .processing: "brain.head.profile.fill"
        case .typing: "text.cursor"
        }
    }

    private func installLocalMouseLogger() {
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { event in
            if event.type == .leftMouseDown || event.type == .leftMouseUp {
                let windowTitle = event.window?.title ?? "nil"
                DebugLog.shared.log("[AppDelegate] localMouseEvent type=\(event.type.rawValue) window=\(windowTitle) location=\(event.locationInWindow)")
            }
            return event
        }
    }
}
