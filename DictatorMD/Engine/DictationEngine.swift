import Foundation
import Observation
import Cocoa

enum DictationState: String {
    case idle
    case recording
    case processing
    case preview
    case typing
}

@Observable
final class DictationEngine {
    private(set) var state: DictationState = .idle
    private(set) var lastTranscription: String = ""
    private(set) var isModelLoaded: Bool = false
    private(set) var modelLoadError: String?
    private(set) var userFacingError: String?
    private(set) var partialTranscription: String = ""
    var previewText: String = ""
    private(set) var canUndoLastInsertion = false

    /// True while the user is holding the hotkey but the toggle-mode threshold hasn't yet fired.
    /// Drives the menu bar hold indicator.
    private(set) var isHoldingForToggle: Bool = false

    private var whisperBridge: WhisperBridge?
    private let audioCapture = AudioCapture()
    private let textInjector = TextInjector()
    private let soundFeedback = SoundFeedback()
    private var hotkeyMonitor: HotkeyMonitor?

    private let minRecordingDuration: TimeInterval = 0.3
    private var recordingStartTime: Date?
    private var insertionTargetApp: NSRunningApplication?
    private var insertionTarget: InsertionTarget?
    private var pendingPreviewTarget: InsertionTarget?
    private var pendingPreviewLanguage: AppSettings.DictationLanguage?
    private var pendingPreviewAudioDuration: Double = 0
    private var pendingPreviewCleanupCutCount: Int = 0
    private var operationID = UUID()
    private var escapeMonitor: Any?
    private var localEscapeMonitor: Any?

    private var accessibilityPoller: Timer?

    /// Pending toggle-mode hold timer. Cancelled if the user releases the key
    /// before the threshold; cleared after firing.
    private var holdWorkItem: DispatchWorkItem?
    private var lastUIStartAt: Date?

    private enum ActiveRecordingMode {
        case pushHold
        case doubleTapToggle
    }

    private var activeRecordingMode: ActiveRecordingMode?
    private var pendingPushHoldStart: DispatchWorkItem?
    private var hotkeyDownAt: Date?
    private var lastQuickTapAt: Date?
    private var ignoreNextPushKeyUp = false

    private let pushHoldStartDelay: TimeInterval = 0.16
    private let quickTapMaxDuration: TimeInterval = 0.24
    private let doubleTapInterval: TimeInterval = 0.42

    init() {
        let axTrusted = AXIsProcessTrusted()
        fputs("[DictationEngine] Init. Accessibility: \(axTrusted)\n", stderr)
        DebugLog.shared.clear()
        DebugLog.shared.log("[DictationEngine] init AX=\(axTrusted) log=\(DebugLog.shared.path)")
        setupHotkeyMonitor()
        hotkeyMonitor?.start()
        PermissionManager.shared.checkPermissions()
        loadModelAsync()
        installEscapeMonitor()
        LaunchAtLoginHelper.reconcile()

        if !axTrusted {
            startAccessibilityPoller()
        }
    }

    deinit {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        if let localEscapeMonitor { NSEvent.removeMonitor(localEscapeMonitor) }
    }

    private func startAccessibilityPoller() {
        accessibilityPoller?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                fputs("[DictationEngine] Accessibility granted! Restarting hotkey monitor.\n", stderr)
                timer.invalidate()
                self?.accessibilityPoller = nil
                self?.restartHotkeyMonitor()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        accessibilityPoller = timer
    }

    func restartHotkeyMonitor() {
        cancelPendingHotkeyActions()
        hotkeyMonitor?.stop()
        setupHotkeyMonitor()
        hotkeyMonitor?.start()
    }

    // MARK: - Model Loading

    private func loadModelAsync() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let modelPath = ModelManager.shared.activeModelPath()
                guard let modelPath else {
                    await MainActor.run {
                        self.modelLoadError = "No model found. Open Settings to download a model."
                    }
                    return
                }
                let bridge = try WhisperBridge(modelPath: modelPath)

                // Pre-warm GPU: JIT-compile Metal shaders with a tiny dummy inference
                bridge.warmup()

                await MainActor.run {
                    self.whisperBridge = bridge
                    self.isModelLoaded = true
                    self.modelLoadError = nil
                    DebugLog.shared.log("[DictationEngine] modelLoaded path=\(modelPath)")
                }
            } catch {
                await MainActor.run {
                    self.modelLoadError = "Failed to load model: \(error.localizedDescription)"
                    DebugLog.shared.log("[DictationEngine] modelLoadFailed error=\(error.localizedDescription)")
                }
            }
        }
    }

    func reloadModel() {
        isModelLoaded = false
        modelLoadError = nil
        whisperBridge = nil
        loadModelAsync()
    }

    // MARK: - Hotkey

    private func setupHotkeyMonitor() {
        hotkeyMonitor = HotkeyMonitor(
            onKeyDown: { [weak self] in self?.handleKeyDown() },
            onKeyUp: { [weak self] in self?.handleKeyUp() }
        )
    }

    func startMonitoring() {
        hotkeyMonitor?.start()
    }

    func stopMonitoring() {
        cancelPendingHotkeyActions()
        hotkeyMonitor?.stop()
    }

    func toggleDictationFromUI() {
        DebugLog.shared.log("[DictationEngine] toggleFromUI state=\(state.rawValue)")
        switch state {
        case .idle:
            lastUIStartAt = Date()
            startRecording()
        case .recording:
            if let lastUIStartAt, Date().timeIntervalSince(lastUIStartAt) < 0.7 {
                return
            }
            self.lastUIStartAt = nil
            stopRecordingAndTranscribe()
        case .processing, .preview, .typing:
            break
        }
    }

    func startDictationFromUI() {
        lastUIStartAt = Date()
        startRecording()
    }

    func stopDictationFromUI() {
        lastUIStartAt = nil
        stopRecordingAndTranscribe()
    }

    // MARK: - Hotkey Mode Dispatch

    private func handleKeyDown() {
        DebugLog.shared.log("[DictationEngine] handleKeyDown mode=\(AppSettings.shared.hotkeyMode.rawValue) state=\(state.rawValue)")
        switch AppSettings.shared.hotkeyMode {
        case .pushToTalk:
            handlePushToTalkKeyDown()
        case .toggle:
            scheduleToggleAction()
        }
    }

    private func handleKeyUp() {
        DebugLog.shared.log("[DictationEngine] handleKeyUp mode=\(AppSettings.shared.hotkeyMode.rawValue) state=\(state.rawValue)")
        switch AppSettings.shared.hotkeyMode {
        case .pushToTalk:
            handlePushToTalkKeyUp()
        case .toggle:
            cancelPendingToggle()
        }
    }

    private func handlePushToTalkKeyDown() {
        let now = Date()
        hotkeyDownAt = now

        if activeRecordingMode == .doubleTapToggle, state == .recording {
            DebugLog.shared.log("[DictationEngine] doubleTapToggle stop")
            ignoreNextPushKeyUp = true
            activeRecordingMode = nil
            lastQuickTapAt = nil
            cancelPendingPushHoldStart()
            stopRecordingAndTranscribe()
            return
        }

        if let lastQuickTapAt, now.timeIntervalSince(lastQuickTapAt) <= doubleTapInterval {
            DebugLog.shared.log("[DictationEngine] doubleTapToggle start")
            ignoreNextPushKeyUp = true
            self.lastQuickTapAt = nil
            activeRecordingMode = .doubleTapToggle
            cancelPendingPushHoldStart()
            startRecording()
            return
        }

        cancelPendingPushHoldStart()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.hotkeyDownAt == now else { return }
            guard AppSettings.shared.hotkeyMode == .pushToTalk else { return }
            guard self.state == .idle else { return }
            self.activeRecordingMode = .pushHold
            DebugLog.shared.log("[DictationEngine] pushHold start afterDelay=\(String(format: "%.2f", self.pushHoldStartDelay))")
            self.startRecording()
        }
        pendingPushHoldStart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + pushHoldStartDelay, execute: work)
    }

    private func handlePushToTalkKeyUp() {
        let now = Date()
        let heldDuration = hotkeyDownAt.map { now.timeIntervalSince($0) } ?? 0
        hotkeyDownAt = nil

        if ignoreNextPushKeyUp {
            ignoreNextPushKeyUp = false
            DebugLog.shared.log("[DictationEngine] pushKeyUp ignored after doubleTap held=\(String(format: "%.2f", heldDuration))")
            return
        }

        cancelPendingPushHoldStart()

        if activeRecordingMode == .pushHold, state == .recording {
            DebugLog.shared.log("[DictationEngine] pushHold stop held=\(String(format: "%.2f", heldDuration))")
            activeRecordingMode = nil
            lastQuickTapAt = nil
            stopRecordingAndTranscribe()
            return
        }

        if activeRecordingMode == .doubleTapToggle {
            DebugLog.shared.log("[DictationEngine] doubleTapToggle keyUp keptRecording")
            return
        }

        if heldDuration <= quickTapMaxDuration {
            lastQuickTapAt = now
            DebugLog.shared.log("[DictationEngine] quickTap armed held=\(String(format: "%.2f", heldDuration))")
            DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapInterval) { [weak self] in
                guard let self, self.lastQuickTapAt == now else { return }
                self.lastQuickTapAt = nil
                DebugLog.shared.log("[DictationEngine] quickTap expired")
            }
        } else {
            lastQuickTapAt = nil
            DebugLog.shared.log("[DictationEngine] pushKeyUp noRecording held=\(String(format: "%.2f", heldDuration))")
        }
    }

    /// Toggle mode: schedule a deferred start/stop after `toggleHoldDuration` seconds.
    /// If the user releases the key first, `cancelPendingToggle()` aborts the work item.
    private func scheduleToggleAction() {
        cancelPendingToggle()
        isHoldingForToggle = true
        // Capture the duration ONCE at schedule time. We pass this same value to the
        // trim path so the audio trimmed at stop matches what was actually waited out,
        // even if the slider value changes between schedule and stop.
        let duration = AppSettings.shared.toggleHoldDuration
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.isHoldingForToggle = false
            self.holdWorkItem = nil
            // Defensive: settings may have changed mid-hold.
            guard AppSettings.shared.hotkeyMode == .toggle else { return }
            switch self.state {
            case .idle:
                self.startRecording()
            case .recording:
                self.stopRecordingAndTranscribe(trimTrailingSeconds: duration)
            case .processing, .preview, .typing:
                // Silent no-op: app is busy, ignore the gesture.
                break
            }
        }
        holdWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func cancelPendingToggle() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        if isHoldingForToggle { isHoldingForToggle = false }
    }

    private func cancelPendingPushHoldStart() {
        pendingPushHoldStart?.cancel()
        pendingPushHoldStart = nil
    }

    private func cancelPendingHotkeyActions() {
        cancelPendingToggle()
        cancelPendingPushHoldStart()
        hotkeyDownAt = nil
        lastQuickTapAt = nil
        ignoreNextPushKeyUp = false
        activeRecordingMode = nil
    }

    // MARK: - Recording Flow

    private func startRecording() {
        guard state == .idle else {
            DebugLog.shared.log("[DictationEngine] startRecording ignored state=\(state.rawValue)")
            return
        }
        guard isModelLoaded else {
            DebugLog.shared.log("[DictationEngine] startRecording ignored modelLoaded=false error=\(modelLoadError ?? "nil")")
            userFacingError = modelLoadError ?? "The speech model is still loading."
            return
        }

        operationID = UUID()
        userFacingError = nil
        partialTranscription = ""
        previewText = ""
        canUndoLastInsertion = false
        insertionTarget = currentInsertionTarget()
        insertionTargetApp = insertionTarget?.app
        DebugLog.shared.log("[DictationEngine] startRecording target=\(insertionTargetApp?.localizedName ?? "nil") bundle=\(insertionTargetApp?.bundleIdentifier ?? "nil")")
        state = .recording
        recordingStartTime = Date()
        soundFeedback.playStartSound()

        do {
            try audioCapture.startRecording()
        } catch {
            fputs("[DictationEngine] Failed to start recording: \(error)\n", stderr)
            DebugLog.shared.log("[DictationEngine] startRecording failed error=\(error.localizedDescription)")
            state = .idle
            userFacingError = "Could not start the microphone. Check microphone permission and the selected input device."
        }
    }

    func cancelCurrentOperation() {
        guard state != .idle else { return }
        operationID = UUID()
        if state == .recording {
            _ = audioCapture.stopRecording()
            soundFeedback.playStopSound()
        }
        partialTranscription = ""
        previewText = ""
        pendingPreviewTarget = nil
        pendingPreviewLanguage = nil
        userFacingError = "Dictation cancelled."
        state = .idle
        DebugLog.shared.log("[DictationEngine] operation cancelled")
    }

    func acceptPreview() {
        guard state == .preview else { return }
        let text = previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            cancelCurrentOperation()
            return
        }
        let target = pendingPreviewTarget
        let language = pendingPreviewLanguage ?? AppSettings.shared.dictationLanguage
        state = .typing
        let inserted = textInjector.insert(text: text, target: target)
        if inserted {
            DictationMemory.shared.record(
                text: text,
                language: language,
                targetApp: target?.app,
                audioDuration: pendingPreviewAudioDuration,
                cleanupCutCount: pendingPreviewCleanupCutCount
            )
            lastTranscription = text
            canUndoLastInsertion = true
            userFacingError = nil
        } else {
            userFacingError = "Text could not be inserted. It was copied to the clipboard."
        }
        clearPendingPreview()
        soundFeedback.playDoneSound()
        state = .idle
    }

    func discardPreview() {
        clearPendingPreview()
        previewText = ""
        partialTranscription = ""
        userFacingError = "Preview discarded."
        state = .idle
    }

    func undoLastInsertion() {
        guard canUndoLastInsertion, let target = insertionTarget else { return }
        _ = FocusTracker.shared.restoreAndSendUndo(target: target)
        canUndoLastInsertion = false
    }

    private func clearPendingPreview() {
        pendingPreviewTarget = nil
        pendingPreviewLanguage = nil
        pendingPreviewAudioDuration = 0
        pendingPreviewCleanupCutCount = 0
    }

    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, AppSettings.shared.escapeToCancelEnabled else { return }
            DispatchQueue.main.async { self?.cancelCurrentOperation() }
        }
        localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53,
                  AppSettings.shared.escapeToCancelEnabled,
                  self?.state != .idle else {
                return event
            }
            self?.cancelCurrentOperation()
            return nil
        }
    }

    /// - Parameter trimTrailingSeconds: number of seconds to trim from the end of the audio
    ///   buffer before transcription. Used by toggle mode to discard the silent hold-to-stop
    ///   interval (otherwise Whisper hallucinates trailing punctuation/filler from the silence).
    ///   Push-to-talk passes 0.
    private func stopRecordingAndTranscribe(trimTrailingSeconds: TimeInterval = 0) {
        guard state == .recording else {
            DebugLog.shared.log("[DictationEngine] stopRecording ignored state=\(state.rawValue)")
            return
        }

        let audioBuffer = audioCapture.stopRecording(trimTrailingSeconds: trimTrailingSeconds)
        soundFeedback.playStopSound()

        // Check minimum duration
        if let start = recordingStartTime,
           Date().timeIntervalSince(start) < minRecordingDuration {
            DebugLog.shared.log("[DictationEngine] dropped tooShort seconds=\(String(format: "%.2f", Date().timeIntervalSince(start)))")
            state = .idle
            return
        }

        guard !audioBuffer.isEmpty else {
            DebugLog.shared.log("[DictationEngine] dropped emptyAudioBuffer")
            state = .idle
            return
        }

        let audioDuration = Double(audioBuffer.count) / 16000.0
        state = .processing
        partialTranscription = ""
        let currentOperationID = operationID

        let bridge = self.whisperBridge
        let language = AppSettings.shared.dictationLanguage
        let basePrompt = AppSettings.shared.vocabularyPrompt
        let customTerms = AppSettings.shared.customTerms
        let learnedTerms = DictationMemory.shared.topPromptTerms(for: language)
        let voiceEnergy = Self.voiceEnergy(audioBuffer)
        let prosody = AppSettings.shared.intonationFormattingEnabled ? ProsodyAnalyzer.analyze(audioBuffer) : nil
        if let prosody {
            DebugLog.shared.log("[DictationEngine] prosody \(prosody.debugSummary)")
        }
        let prompt: String
        let allPromptTerms = Array((customTerms + learnedTerms).reduce(into: [String]()) { result, term in
            if !result.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame }) {
                result.append(term)
            }
        })
        if allPromptTerms.isEmpty {
            prompt = basePrompt
        } else {
            // Cap custom terms to stay under whisper's ~1024 token (~750 word) limit
            let baseWordCount = basePrompt.split(separator: " ").count
            let budget = max(0, 700 - baseWordCount)
            let termsToAdd = Array(allPromptTerms.prefix(budget))
            prompt = termsToAdd.isEmpty ? basePrompt : basePrompt + ", Learned user terms: " + termsToAdd.joined(separator: ", ")
        }
        let injector = self.textInjector
        let feedback = self.soundFeedback
        let target = self.insertionTarget
        let targetApp = target?.app

        Task.detached(priority: .userInitiated) { [weak self] in
            func resetToIdle() async {
                await MainActor.run { [weak self] in
                    feedback.playDoneSound()
                    self?.state = .idle
                }
            }

            guard let bridge else {
                await resetToIdle()
                return
            }

            var rawText = bridge.transcribe(
                audioBuffer: audioBuffer,
                language: language,
                prompt: prompt,
                onSegment: AppSettings.shared.streamingPreviewEnabled ? { [weak self] segment in
                    Task { @MainActor in
                        guard let self, self.operationID == currentOperationID else { return }
                        let separator = self.partialTranscription.isEmpty ? "" : " "
                        self.partialTranscription += separator + segment
                    }
                } : nil
            )
            DebugLog.shared.log("[DictationEngine] firstTranscription length=\(rawText.count)")

            if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, audioDuration >= 0.45 {
                if Self.shouldRetryWithoutVAD(voiceEnergy) {
                    fputs("[DictationEngine] Empty VAD result; retrying without VAD.\n", stderr)
                    DebugLog.shared.log("[DictationEngine] retryWithoutVAD audioDuration=\(String(format: "%.2f", audioDuration)) rms=\(String(format: "%.5f", voiceEnergy.rms)) peak=\(String(format: "%.5f", voiceEnergy.peak))")
                    rawText = bridge.transcribe(
                        audioBuffer: audioBuffer,
                        language: language,
                        useVAD: false,
                        prompt: prompt
                    )
                } else {
                    DebugLog.shared.log("[DictationEngine] skipRetryLowEnergy audioDuration=\(String(format: "%.2f", audioDuration)) rms=\(String(format: "%.5f", voiceEnergy.rms)) peak=\(String(format: "%.5f", voiceEnergy.peak))")
                }
            }

            if Self.shouldRetryForLanguageViolation(rawText, language: language) {
                let fallbackLanguage = Self.fallbackLanguage(for: language)
                DebugLog.shared.log("[DictationEngine] retryLanguageViolation requested=\(language.whisperCode) fallback=\(fallbackLanguage.whisperCode)")
                rawText = bridge.transcribe(
                    audioBuffer: audioBuffer,
                    language: fallbackLanguage,
                    useVAD: false,
                    prompt: prompt
                )
            }

            let outputStyle = AppSettings.shared.effectiveOutputStyle(for: target?.bundleIdentifier)
            let correctedText = TextCorrector.shared.correct(rawText, prosody: prosody, style: outputStyle)
            let fullText = Self.guardLanguageOutput(correctedText, language: language)
            let cleanupCutCount = DictationMemory.estimatedCleanupCutCount(raw: rawText, final: fullText)
            fputs("[DictationEngine] Final text: \(fullText)\n", stderr)
            DebugLog.shared.log("[DictationEngine] finalText length=\(fullText.count) text=\"\(fullText)\"")

            guard await MainActor.run(body: { [weak self] in self?.operationID == currentOperationID }) else {
                DebugLog.shared.log("[DictationEngine] discarded cancelled transcription")
                return
            }

            if !Self.isLikelySilenceHallucination(fullText, audioDuration: audioDuration), !fullText.isEmpty {
                if AppSettings.shared.previewBeforeInsert {
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        self.previewText = fullText
                        self.partialTranscription = fullText
                        self.pendingPreviewTarget = target
                        self.pendingPreviewLanguage = language
                        self.pendingPreviewAudioDuration = audioDuration
                        self.pendingPreviewCleanupCutCount = cleanupCutCount
                        self.state = .preview
                    }
                    return
                }
                DebugLog.shared.log("[DictationEngine] insertingText target=\(targetApp?.localizedName ?? "nil")")
                await MainActor.run {
                    DictationMemory.shared.record(
                        text: fullText,
                        language: language,
                        targetApp: targetApp,
                        audioDuration: audioDuration,
                        cleanupCutCount: cleanupCutCount
                    )
                }
                let inserted = injector.insert(text: fullText, target: target)
                DebugLog.shared.log("[DictationEngine] insertionResult success=\(inserted)")
                await MainActor.run { [weak self] in
                    self?.canUndoLastInsertion = inserted
                    self?.userFacingError = inserted ? nil : "Text could not be inserted. It was copied to the clipboard."
                }
            } else {
                DebugLog.shared.log("[DictationEngine] insertionSkipped emptyOrSilence audioDuration=\(String(format: "%.2f", audioDuration))")
                await MainActor.run { [weak self] in
                    self?.userFacingError = "No clear speech was detected."
                }
            }

            await MainActor.run { [weak self] in
                if !fullText.isEmpty {
                    self?.lastTranscription = fullText
                    self?.partialTranscription = ""
                }
            }

            await resetToIdle()
        }
    }

    private func currentInsertionTargetApp() -> NSRunningApplication? {
        FocusTracker.shared.currentTargetApp()
    }

    private func currentInsertionTarget() -> InsertionTarget {
        FocusTracker.shared.currentInsertionTarget()
    }

    private static func isLikelySilenceHallucination(_ text: String, audioDuration: Double) -> Bool {
        guard audioDuration < 1.0 else { return false }
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
        return [
            "thank you",
            "thanks for watching",
            "please subscribe"
        ].contains(normalized)
    }

    private static func voiceEnergy(_ audioBuffer: [Float]) -> (rms: Double, peak: Float) {
        guard !audioBuffer.isEmpty else { return (0, 0) }

        var sumSquares = 0.0
        var maxPeak: Float = 0
        for sample in audioBuffer {
            sumSquares += Double(sample * sample)
            maxPeak = max(maxPeak, abs(sample))
        }

        return (sqrt(sumSquares / Double(audioBuffer.count)), maxPeak)
    }

    private static func shouldRetryWithoutVAD(_ energy: (rms: Double, peak: Float)) -> Bool {
        energy.rms >= 0.001 || energy.peak >= 0.006
    }

    private static func fallbackLanguage(for language: AppSettings.DictationLanguage) -> AppSettings.DictationLanguage {
        switch language {
        case .bulgarian:
            return .bulgarian
        case .english, .auto:
            return .english
        }
    }

    private static func shouldRetryForLanguageViolation(_ text: String, language: AppSettings.DictationLanguage) -> Bool {
        switch language {
        case .english:
            return containsCyrillic(text)
        case .auto, .bulgarian:
            return looksRussian(text)
        }
    }

    private static func guardLanguageOutput(_ text: String, language: AppSettings.DictationLanguage) -> String {
        switch language {
        case .english:
            if containsCyrillic(text) {
                DebugLog.shared.log("[DictationEngine] blockedCyrillicInEnglish")
                return ""
            }
        case .auto, .bulgarian:
            if looksRussian(text) {
                DebugLog.shared.log("[DictationEngine] blockedRussianLikeOutput language=\(language.whisperCode)")
                return ""
            }
        }
        return text
    }

    private static func containsCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0400...0x04FF).contains(Int(scalar.value))
        }
    }

    private static func looksRussian(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        if lowercased.unicodeScalars.contains(where: { ["ы", "э", "ё"].contains(String($0)) }) {
            return true
        }

        let russianMarkers = [
            "мы", "вы", "для", "чтобы", "который", "которая", "которые",
            "должен", "должна", "сделайте", "внутри", "существует",
            "существуют", "анализируете", "представьте", "ставит"
        ]
        return russianMarkers.contains { marker in
            lowercased.range(of: "\\b\(marker)\\b", options: .regularExpression) != nil
        }
    }
}
