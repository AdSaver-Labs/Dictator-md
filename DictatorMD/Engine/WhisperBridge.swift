import Foundation

/// Context passed to the C callback for streaming segment output.
/// Retained via Unmanaged for the duration of whisper_full.
private final class SegmentCallbackContext {
    let onSegment: (String) -> Void

    init(onSegment: @escaping (String) -> Void) {
        self.onSegment = onSegment
    }
}

/// C-compatible callback for new_segment_callback
private func segmentCallback(
    _ ctx: OpaquePointer?,
    _ state: OpaquePointer?,
    _ nNew: Int32,
    _ userData: UnsafeMutableRawPointer?
) {
    guard let userData, let ctx else { return }
    let callbackCtx = Unmanaged<SegmentCallbackContext>.fromOpaque(userData).takeUnretainedValue()

    let totalSegments = whisper_full_n_segments(ctx)
    let start = max(0, totalSegments - nNew)
    for i in start..<totalSegments {
        if let text = whisper_full_get_segment_text(ctx, i) {
            let segment = String(cString: text).trimmingCharacters(in: .whitespaces)
            if !segment.isEmpty {
                callbackCtx.onSegment(segment)
            }
        }
    }
}

final class WhisperBridge: @unchecked Sendable {
    private let context: OpaquePointer
    private let queue = DispatchQueue(label: "com.DictatorMD.whisper", qos: .userInitiated)
    private let vadModelPath: String?

    private static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    init(modelPath: String) throws {
        var contextParams = whisper_context_default_params()
        contextParams.use_gpu = Self.isAppleSilicon
        contextParams.flash_attn = Self.isAppleSilicon

        fputs("[WhisperBridge] Loading model: \(modelPath)\n", stderr)

        guard let ctx = whisper_init_from_file_with_params(modelPath, contextParams) else {
            throw WhisperError.modelLoadFailed(modelPath)
        }
        self.context = ctx

        let vadPath = ModelManager.shared.vadModelPath()
        self.vadModelPath = vadPath
        fputs("[WhisperBridge] Model loaded | GPU: \(Self.isAppleSilicon) | VAD: \(vadPath != nil)\n", stderr)
    }

    deinit {
        whisper_free(context)
    }

    // MARK: - GPU Pre-warming

    /// Run a tiny dummy inference to JIT-compile Metal shaders.
    /// Call once after model load so the first real inference isn't slower.
    func warmup() {
        queue.sync {
            let silence = [Float](repeating: 0, count: 8000) // 0.5s of silence
            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            params.n_threads = 1
            params.single_segment = true
            params.no_context = true
            let langCStr = strdup("en")
            params.language = UnsafePointer(langCStr)
            defer { free(langCStr) }

            silence.withUnsafeBufferPointer { ptr in
                _ = whisper_full(context, params, ptr.baseAddress, Int32(silence.count))
            }
            fputs("[WhisperBridge] GPU pre-warmed\n", stderr)
        }
    }

    // MARK: - Streaming Transcription

    /// Transcribe with streaming: calls `onSegment` as each text segment is decoded.
    /// Returns the full concatenated transcription when complete.
    func transcribe(
        audioBuffer: [Float],
        language: AppSettings.DictationLanguage = .auto,
        useVAD: Bool = true,
        prompt: String = "",
        onSegment: ((String) -> Void)? = nil
    ) -> String {
        queue.sync {
            let startTime = CFAbsoluteTimeGetCurrent()
            let audioDuration = Double(audioBuffer.count) / 16000.0

            // Adaptive decoding: beam search is much more reliable for short phrases,
            // especially with auto language detection. Keep the fast greedy path for
            // genuinely long dictations where beam search becomes the main delay.
            let useBeamSearch = Self.isAppleSilicon && audioDuration <= 18.0
            var params = useBeamSearch
                ? whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH)
                : whisper_full_default_params(WHISPER_SAMPLING_GREEDY)

            if useBeamSearch {
                params.beam_search.beam_size = 5
            }

            // Threads
            let threadCount = Self.isAppleSilicon
                ? max(1, ProcessInfo.processInfo.activeProcessorCount - 2)
                : max(1, ProcessInfo.processInfo.activeProcessorCount)

            let effectiveLanguage = Self.resolveLanguage(
                requestedLanguage: language,
                audioBuffer: audioBuffer,
                context: context,
                threadCount: threadCount
            )
            let decodePrompt = Self.decodePrompt(prompt, for: effectiveLanguage)

            // Allocate C strings (freed in defer)
            let langCStr = strdup(effectiveLanguage.whisperCode)
            let suppressCStr = strdup("(Thank you|Thanks for watching|Please subscribe|you)")
            let promptCStr = decodePrompt.isEmpty ? nil : strdup(decodePrompt)
            var vadPathCStr: UnsafeMutablePointer<CChar>?

            params.language = UnsafePointer(langCStr)
            params.translate = false
            params.suppress_nst = true
            params.suppress_regex = UnsafePointer(suppressCStr)
            // true = each transcription is independent (prevents hallucination carry-over)
            params.no_context = true

            // Must be false for streaming — allows multiple segment callbacks during decode
            params.single_segment = false

            // Temperature fallback (disable for beam search — causes unexpected re-decodes)
            params.temperature = 0.0
            params.temperature_inc = useBeamSearch ? 0.0 : 0.2
            params.entropy_thold = 2.4
            params.logprob_thold = -1.0
            params.no_speech_thold = 0.6

            params.n_threads = Int32(threadCount)

            // VAD
            if useVAD, let vadPath = self.vadModelPath {
                params.vad = true
                vadPathCStr = strdup(vadPath)
                params.vad_model_path = UnsafePointer(vadPathCStr)
            }

            // Vocabulary prompt
            params.initial_prompt = promptCStr.map { UnsafePointer($0) }

            // Streaming callback setup
            var callbackCtxPtr: Unmanaged<SegmentCallbackContext>?
            if let onSegment {
                let ctx = SegmentCallbackContext(onSegment: onSegment)
                let ptr = Unmanaged.passRetained(ctx)
                callbackCtxPtr = ptr
                params.new_segment_callback = segmentCallback
                params.new_segment_callback_user_data = ptr.toOpaque()
            }

            defer {
                free(langCStr)
                free(suppressCStr)
                if let p = promptCStr { free(p) }
                if let v = vadPathCStr { free(v) }
                callbackCtxPtr?.release()
            }

            let strategy = useBeamSearch ? "beam(5)" : "greedy"
            fputs("[WhisperBridge] \(String(format: "%.1f", audioDuration))s | \(strategy) | \(threadCount)T | language=\(effectiveLanguage.whisperCode) requested=\(language.whisperCode) | vad=\(useVAD) | streaming: \(onSegment != nil)\n", stderr)
            DebugLog.shared.log("[WhisperBridge] start seconds=\(String(format: "%.2f", audioDuration)) strategy=\(strategy) threads=\(threadCount) language=\(effectiveLanguage.whisperCode) requested=\(language.whisperCode) vad=\(useVAD)")

            let result = audioBuffer.withUnsafeBufferPointer { bufferPtr in
                whisper_full(context, params, bufferPtr.baseAddress, Int32(audioBuffer.count))
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime

            guard result == 0 else {
                fputs("[WhisperBridge] Failed (\(result)) in \(String(format: "%.2f", elapsed))s\n", stderr)
                DebugLog.shared.log("[WhisperBridge] failed code=\(result) elapsed=\(String(format: "%.2f", elapsed))")
                return ""
            }

            // Collect full transcription (callback already typed segments incrementally)
            let segmentCount = whisper_full_n_segments(context)
            var transcription = ""
            for i in 0..<segmentCount {
                if let text = whisper_full_get_segment_text(context, i) {
                    transcription += String(cString: text)
                }
            }

            let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
            fputs("[WhisperBridge] Done (\(String(format: "%.2f", elapsed))s): \"\(trimmed)\"\n", stderr)
            DebugLog.shared.log("[WhisperBridge] done elapsed=\(String(format: "%.2f", elapsed)) segments=\(segmentCount) length=\(trimmed.count) text=\"\(trimmed)\"")
            return trimmed
        }
    }

    private static func resolveLanguage(
        requestedLanguage: AppSettings.DictationLanguage,
        audioBuffer: [Float],
        context: OpaquePointer,
        threadCount: Int
    ) -> AppSettings.DictationLanguage {
        switch requestedLanguage {
        case .english, .bulgarian:
            return requestedLanguage
        case .auto:
            break
        }

        let maxLanguageID = whisper_lang_max_id()
        guard maxLanguageID > 0 else { return .english }

        let melStatus = audioBuffer.withUnsafeBufferPointer { ptr in
            whisper_pcm_to_mel(context, ptr.baseAddress, Int32(audioBuffer.count), Int32(threadCount))
        }
        guard melStatus == 0 else {
            DebugLog.shared.log("[WhisperBridge] restrictedAuto melFailed status=\(melStatus) fallback=en")
            return .english
        }

        var probabilities = [Float](repeating: 0, count: Int(maxLanguageID) + 1)
        let topLanguageID = probabilities.withUnsafeMutableBufferPointer { ptr in
            whisper_lang_auto_detect(context, 0, Int32(threadCount), ptr.baseAddress)
        }

        let englishID = whisper_lang_id("en")
        let bulgarianID = whisper_lang_id("bg")
        let englishProbability = Self.probability(probabilities, id: englishID)
        let bulgarianProbability = Self.probability(probabilities, id: bulgarianID)
        let topLanguage = Self.languageCode(for: topLanguageID) ?? "unknown"

        // Auto mode is intentionally restricted to the two languages the app supports.
        // Default to English unless Bulgarian is clearly stronger.
        let chosen: AppSettings.DictationLanguage =
            bulgarianProbability >= 0.05 && bulgarianProbability > englishProbability * 1.25
            ? .bulgarian
            : .english

        DebugLog.shared.log("[WhisperBridge] restrictedAuto top=\(topLanguage) en=\(String(format: "%.4f", englishProbability)) bg=\(String(format: "%.4f", bulgarianProbability)) chosen=\(chosen.whisperCode)")
        return chosen
    }

    private static func probability(_ probabilities: [Float], id: Int32) -> Float {
        guard id >= 0, Int(id) < probabilities.count else { return 0 }
        return probabilities[Int(id)]
    }

    private static func languageCode(for id: Int32) -> String? {
        guard id >= 0, let cString = whisper_lang_str(id) else { return nil }
        return String(cString: cString)
    }

    private static func decodePrompt(_ prompt: String, for language: AppSettings.DictationLanguage) -> String {
        let languagePrompt: String
        let userPrompt: String

        switch language {
        case .english:
            languagePrompt = """
            Transcribe in English only. Use the Latin alphabet only. Never output Russian, Bulgarian, Cyrillic, or Cyrillic transliteration. If speech is unclear, choose the closest English words. Preserve technical terms such as Openclaw, Hermes, Codex, Notion, Telegram, SEO, Wix, ChatGPT, API, backend, frontend, prompt, agent, account, authentication, re-authentication.
            """
            userPrompt = prompt
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !Self.containsCyrillic(String($0)) }
                .joined(separator: "\n")
        case .bulgarian:
            languagePrompt = """
            Транскрибирай на български език с българска кирилица. Не използвай руски думи и не превключвай към руски. Запазвай английски технически термини като Openclaw, Hermes, Codex, Notion, Telegram, SEO, Wix, ChatGPT, API, backend, frontend, prompt, agent.
            """
            userPrompt = prompt
        case .auto:
            languagePrompt = ""
            userPrompt = prompt
        }

        let trimmedPrompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPrompt.isEmpty ? languagePrompt : languagePrompt + "\n" + trimmedPrompt
    }

    private static func containsCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0400...0x04FF).contains(Int(scalar.value))
        }
    }
}

enum WhisperError: LocalizedError {
    case modelLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let path):
            return "Failed to load Whisper model at: \(path)"
        }
    }
}
