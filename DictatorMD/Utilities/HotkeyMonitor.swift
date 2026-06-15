import Cocoa
import CoreGraphics
import os

final class HotkeyMonitor {
    static private(set) var eventTapOperational = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retainedSelfPtr: UnsafeMutableRawPointer?
    private var globalMonitors: [Any] = []
    private let onKeyDown: () -> Void
    private let onKeyUp: () -> Void
    private let lock = os_unfair_lock_t.allocate(capacity: 1)

    private var monitoredKeyCode: CGKeyCode {
        CGKeyCode(AppSettings.shared.hotkeyKeyCode)
    }

    private var isModifierKey: Bool {
        let code = Int(monitoredKeyCode)
        return [54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(code)
    }

    private var isKeyHeld = false

    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
        lock.initialize(to: os_unfair_lock())
    }

    deinit {
        stop()
        lock.deallocate()
    }

    func start() {
        guard eventTap == nil else { return }
        let axTrusted = AXIsProcessTrusted()
        fputs("[HotkeyMonitor] Starting... keyCode=\(monitoredKeyCode) isModifier=\(isModifierKey)\n", stderr)
        DebugLog.shared.log("[HotkeyMonitor] start keyCode=\(monitoredKeyCode) isModifier=\(isModifierKey) AX=\(axTrusted)")

        guard axTrusted else {
            DebugLog.shared.log("[HotkeyMonitor] AX not trusted; using NSEvent fallback only")
            Self.eventTapOperational = false
            startGlobalFallbackMonitor()
            DispatchQueue.main.async {
                PermissionManager.shared.requestAccessibilityPromptIfNeeded()
            }
            return
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.leftMouseDown.rawValue)

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return monitor.handleEvent(type: type, event: event)
            },
            userInfo: selfPtr
        )

        guard let eventTap else {
            fputs("[HotkeyMonitor] FAILED to create event tap! Grant Accessibility permission in System Settings.\n", stderr)
            DebugLog.shared.log("[HotkeyMonitor] eventTap FAILED")
            Self.eventTapOperational = false
            Unmanaged<HotkeyMonitor>.fromOpaque(selfPtr).release()
            startGlobalFallbackMonitor()
            DispatchQueue.main.async {
                PermissionManager.shared.requestAccessibilityPromptIfNeeded()
            }
            return
        }

        fputs("[HotkeyMonitor] Event tap created successfully\n", stderr)
        DebugLog.shared.log("[HotkeyMonitor] eventTap created")
        Self.eventTapOperational = true
        DispatchQueue.main.async {
            PermissionManager.shared.markAccessibilityOperational()
        }
        retainedSelfPtr = selfPtr

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        startGlobalFallbackMonitor()

        // Watchdog: macOS silently disables taps when Accessibility permission is stale.
        // Schedule explicitly on main run loop to guarantee it fires.
        startTapWatchdog()
    }

    private var watchdogTimer: Timer?

    private func startGlobalFallbackMonitor() {
        stopGlobalFallbackMonitor()

        if let flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged], handler: { [weak self] event in
            self?.handleNSEvent(event, type: .flagsChanged)
        }) {
            globalMonitors.append(flagsMonitor)
        }

        if let keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp], handler: { [weak self] event in
            self?.handleNSEvent(event, type: event.type == .keyDown ? .keyDown : .keyUp)
        }) {
            globalMonitors.append(keyMonitor)
        }

        DebugLog.shared.log("[HotkeyMonitor] globalFallbackMonitors=\(globalMonitors.count)")
    }

    private func stopGlobalFallbackMonitor() {
        for monitor in globalMonitors {
            NSEvent.removeMonitor(monitor)
        }
        globalMonitors.removeAll()
    }

    private func startTapWatchdog() {
        watchdogTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, let tap = self.eventTap else { return }
            if !CGEvent.tapIsEnabled(tap: tap) {
                fputs("[HotkeyMonitor] Event tap was disabled by macOS! Re-enabling...\n", stderr)
                DebugLog.shared.log("[HotkeyMonitor] eventTap disabled; re-enabling")
                CGEvent.tapEnable(tap: tap, enable: true)
                Self.eventTapOperational = CGEvent.tapIsEnabled(tap: tap)
                if Self.eventTapOperational {
                    DispatchQueue.main.async {
                        PermissionManager.shared.markAccessibilityOperational()
                    }
                }
                // The tap was disabled — any in-flight key-down lost its key-up event.
                // Reset isKeyHeld so the next press is accepted, AND synthesize the missed
                // key-up so DictationEngine can recover (otherwise it stays stuck in
                // .recording for push-to-talk, or in `isHoldingForToggle = true` with a
                // pending work item for toggle mode).
                os_unfair_lock_lock(self.lock)
                let wasHeld = self.isKeyHeld
                self.isKeyHeld = false
                os_unfair_lock_unlock(self.lock)
                if wasHeld {
                    DebugLog.shared.log("[HotkeyMonitor] synthetic keyUp after tap disable")
                    DispatchQueue.main.async { self.onKeyUp() }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdogTimer = timer
    }

    func stop() {
        DebugLog.shared.log("[HotkeyMonitor] stop")
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        stopGlobalFallbackMonitor()
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            self.eventTap = nil
            self.runLoopSource = nil
        }
        if let ptr = retainedSelfPtr {
            Unmanaged<HotkeyMonitor>.fromOpaque(ptr).release()
            retainedSelfPtr = nil
        }
    }

    private func handleNSEvent(_ event: NSEvent, type: CGEventType) {
        let keyCode = CGKeyCode(event.keyCode)

        if isModifierKey {
            guard type == .flagsChanged, keyCode == monitoredKeyCode else { return }
            let isPressed = isModifierPressed(event.modifierFlags.cgEventFlags)
            os_unfair_lock_lock(lock)
            let wasHeld = isKeyHeld
            if isPressed && !wasHeld {
                isKeyHeld = true
                os_unfair_lock_unlock(lock)
                DebugLog.shared.log("[HotkeyMonitor] NSEvent modifier down keyCode=\(keyCode)")
                DispatchQueue.main.async { self.onKeyDown() }
            } else if !isPressed && wasHeld {
                isKeyHeld = false
                os_unfair_lock_unlock(lock)
                DebugLog.shared.log("[HotkeyMonitor] NSEvent modifier up keyCode=\(keyCode)")
                DispatchQueue.main.async { self.onKeyUp() }
            } else {
                os_unfair_lock_unlock(lock)
            }
        } else if keyCode == monitoredKeyCode {
            os_unfair_lock_lock(lock)
            let wasHeld = isKeyHeld
            if type == .keyDown && !wasHeld {
                isKeyHeld = true
                os_unfair_lock_unlock(lock)
                DebugLog.shared.log("[HotkeyMonitor] NSEvent keyDown keyCode=\(keyCode)")
                DispatchQueue.main.async { self.onKeyDown() }
            } else if type == .keyUp && wasHeld {
                isKeyHeld = false
                os_unfair_lock_unlock(lock)
                DebugLog.shared.log("[HotkeyMonitor] NSEvent keyUp keyCode=\(keyCode)")
                DispatchQueue.main.async { self.onKeyUp() }
            } else {
                os_unfair_lock_unlock(lock)
            }
        }
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .leftMouseDown {
            FocusTracker.shared.recordMouseDown(screenPoint: event.location)
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if isModifierKey {
            if type == .flagsChanged && keyCode == monitoredKeyCode {
                let flags = event.flags
                let isPressed = isModifierPressed(flags)
                os_unfair_lock_lock(lock)
                let wasHeld = isKeyHeld
                if isPressed && !wasHeld {
                    isKeyHeld = true
                    os_unfair_lock_unlock(lock)
                    DebugLog.shared.log("[HotkeyMonitor] CGEvent modifier down keyCode=\(keyCode)")
                    DispatchQueue.main.async { self.onKeyDown() }
                    return Unmanaged.passUnretained(event)
                } else if !isPressed && wasHeld {
                    isKeyHeld = false
                    os_unfair_lock_unlock(lock)
                    DebugLog.shared.log("[HotkeyMonitor] CGEvent modifier up keyCode=\(keyCode)")
                    DispatchQueue.main.async { self.onKeyUp() }
                    return Unmanaged.passUnretained(event)
                }
                os_unfair_lock_unlock(lock)
            }
        } else {
            if keyCode == monitoredKeyCode {
                os_unfair_lock_lock(lock)
                let wasHeld = isKeyHeld
                if type == .keyDown && !wasHeld {
                    isKeyHeld = true
                    os_unfair_lock_unlock(lock)
                    DebugLog.shared.log("[HotkeyMonitor] CGEvent keyDown keyCode=\(keyCode)")
                    DispatchQueue.main.async { self.onKeyDown() }
                    return Unmanaged.passUnretained(event)
                } else if type == .keyUp && wasHeld {
                    isKeyHeld = false
                    os_unfair_lock_unlock(lock)
                    DebugLog.shared.log("[HotkeyMonitor] CGEvent keyUp keyCode=\(keyCode)")
                    DispatchQueue.main.async { self.onKeyUp() }
                    return Unmanaged.passUnretained(event)
                }
                os_unfair_lock_unlock(lock)
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func isModifierPressed(_ flags: CGEventFlags) -> Bool {
        let code = Int(monitoredKeyCode)
        switch code {
        case 58, 61: return flags.contains(.maskAlternate)
        case 59, 62: return flags.contains(.maskControl)
        case 56, 60: return flags.contains(.maskShift)
        case 54, 55: return flags.contains(.maskCommand)
        case 57:     return flags.contains(.maskAlphaShift)
        case 63:     return flags.contains(.maskSecondaryFn)
        default:     return false
        }
    }
}

private extension NSEvent.ModifierFlags {
    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.capsLock) { flags.insert(.maskAlphaShift) }
        if contains(.function) { flags.insert(.maskSecondaryFn) }
        return flags
    }
}
