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
    struct Transcription {
        let text: String
        let language: AppSettings.DictationLanguage
    }

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
        vocabulary: RecognitionVocabulary.Context? = nil,
        recheckUncertainSegments: Bool = true,
        onSegment: ((String) -> Void)? = nil
    ) -> Transcription {
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
            let hintContext = vocabulary ?? RecognitionVocabulary.Context(basePrompt: prompt)
            let decodePrompt = recognitionPrompt(hintContext, language: effectiveLanguage)
            DebugLog.shared.log("[WhisperBridge] vocabularyTokens=\(tokenCount(decodePrompt)) budget=216")

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
            params.n_max_text_ctx = Int32(min(224, Int(whisper_n_text_ctx(context)) / 2))

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
                return Transcription(text: "", language: effectiveLanguage)
            }

            // Copy segment data before another whisper_full call overwrites the context.
            let segmentCount = whisper_full_n_segments(context)
            var segments: [RecognizedSegment] = []
            for i in 0..<segmentCount {
                if let text = whisper_full_get_segment_text(context, i) {
                    segments.append(RecognizedSegment(text: String(cString: text),
                        start: max(0, Double(whisper_full_get_segment_t0(context, i)) / 100),
                        end: min(audioDuration, Double(whisper_full_get_segment_t1(context, i)) / 100),
                        score: meanLogProbability(segment: i)))
                }
            }
            if recheckUncertainSegments {
                var rechecks = 0
                var recheckedSeconds = 0.0
                for index in segments.indices {
                    let segment = segments[index]
                    let duration = segment.end - segment.start
                    guard rechecks < 2, recheckedSeconds + duration <= 15,
                          RecognitionQuality.shouldRecheck(meanLogProbability: segment.score, duration: duration, usedBeamSearch: useBeamSearch) else { continue }
                    rechecks += 1
                    recheckedSeconds += duration
                    if let revised = recheck(segment, audioBuffer: audioBuffer, language: effectiveLanguage,
                                             vocabulary: hintContext, threadCount: threadCount) {
                        segments[index].text = revised
                    }
                }
                if rechecks > 0 {
                    DebugLog.shared.log("[WhisperBridge] qualityRechecks=\(rechecks) seconds=\(String(format: "%.2f", recheckedSeconds))")
                }
            }
            let transcription = segments.map(\.text).joined()

            let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
            DebugLog.shared.log("[WhisperBridge] done elapsed=\(String(format: "%.2f", elapsed)) segments=\(segmentCount) length=\(trimmed.count)")
            return Transcription(text: trimmed, language: effectiveLanguage)
        }
    }

    private struct RecognizedSegment {
        var text: String
        let start: Double
        let end: Double
        let score: Double
    }

    private func meanLogProbability(segment: Int32) -> Double {
        let tokenCount = whisper_full_n_tokens(context, segment)
        var logSum = 0.0
        var count = 0
        for index in 0..<tokenCount {
            let token = whisper_full_get_token_data(context, segment, index)
            guard token.id < whisper_token_eot(context), token.p > 0 else { continue }
            logSum += log(Double(token.p))
            count += 1
        }
        return count == 0 ? 0 : logSum / Double(count)
    }

    private func recognitionPrompt(_ hints: RecognitionVocabulary.Context, language: AppSettings.DictationLanguage, recognizedContext: String = "") -> String {
        let confirmed = hints.confirmedCorrections.filter { $0.language == "auto" || $0.language == language.rawValue }.map(\.spelling)
        return RecognitionVocabulary.prompt(language: language, customTerms: hints.customTerms,
            confirmedTerms: confirmed + hints.confirmedTerms, learnedTerms: hints.learnedTerms,
            basePrompt: hints.basePrompt, recognizedContext: recognizedContext,
            tokenBudget: min(216, Int(whisper_n_text_ctx(context)) / 2 - 8),
            tokenCount: { self.tokenCount($0) })
    }

    private func tokenCount(_ text: String) -> Int {
        // Byte count bounds BPE token count and avoids the C API's noisy max=0 probe.
        var tokens = [whisper_token](repeating: 0, count: max(1, text.utf8.count))
        return text.withCString { string in
            tokens.withUnsafeMutableBufferPointer { buffer in
                Int(whisper_tokenize(context, string, buffer.baseAddress, Int32(buffer.count)))
            }
        }
    }

    private func recheck(_ segment: RecognizedSegment, audioBuffer: [Float], language: AppSettings.DictationLanguage,
                         vocabulary: RecognitionVocabulary.Context, threadCount: Int) -> String? {
        // Use only the captured segment, no neighbouring speech that could be duplicated.
        let start = max(0, Int(segment.start * 16000))
        let end = min(audioBuffer.count, Int(segment.end * 16000))
        guard end > start else { return nil }
        let samples = Array(audioBuffer[start..<end])
        var params = whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH)
        params.beam_search.beam_size = 3
        params.n_threads = Int32(threadCount)
        params.no_context = true
        params.translate = false
        params.single_segment = true
        params.temperature_inc = 0
        params.suppress_nst = true
        params.print_progress = false
        params.print_realtime = false
        let prompt = recognitionPrompt(vocabulary, language: language, recognizedContext: segment.text)
        let status = language.whisperCode.withCString { languageString in
            prompt.withCString { promptString in
                params.language = languageString
                params.initial_prompt = promptString
                return samples.withUnsafeBufferPointer { whisper_full(context, params, $0.baseAddress, Int32(samples.count)) }
            }
        }
        guard status == 0, whisper_full_n_segments(context) == 1,
              let candidateText = whisper_full_get_segment_text(context, 0) else { return nil }
        let candidate = String(cString: candidateText)
        guard RecognitionQuality.accepts(original: segment.text, candidate: candidate,
            originalScore: segment.score, candidateScore: meanLogProbability(segment: 0)),
            language != .english || !RecognitionVocabulary.containsCyrillic(candidate),
            RecognitionVocabulary.allows(candidate, language: language) else { return nil }
        return " " + candidate.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let englishID = whisper_lang_id("en")
        let bulgarianID = whisper_lang_id("bg")
        let openingSamples = min(audioBuffer.count, 2 * 16000)
        var cachedDetection: (sampleCount: Int, english: Float, bulgarian: Float, top: String)?

        func detect(sampleCount: Int, requireStrongEvidence: Bool) -> AppSettings.DictationLanguage? {
            if let cachedDetection, cachedDetection.sampleCount == sampleCount {
                return AutoLanguageDecision.choose(
                    english: cachedDetection.english,
                    bulgarian: cachedDetection.bulgarian,
                    topLanguage: cachedDetection.top,
                    requireStrongEvidence: requireStrongEvidence
                )
            }
            let melStatus = audioBuffer.withUnsafeBufferPointer { ptr in
                whisper_pcm_to_mel(context, ptr.baseAddress, Int32(sampleCount), Int32(threadCount))
            }
            guard melStatus == 0 else {
                DebugLog.shared.log("[WhisperBridge] autoDetection melFailed status=\(melStatus)")
                return nil
            }

            var probabilities = [Float](repeating: 0, count: Int(maxLanguageID) + 1)
            let topLanguageID = probabilities.withUnsafeMutableBufferPointer { ptr in
                whisper_lang_auto_detect(context, 0, Int32(threadCount), ptr.baseAddress)
            }
            guard topLanguageID >= 0 else { return nil }

            let englishProbability = Self.probability(probabilities, id: englishID)
            let bulgarianProbability = Self.probability(probabilities, id: bulgarianID)
            let topLanguage = Self.languageCode(for: topLanguageID) ?? "unknown"
            cachedDetection = (sampleCount, englishProbability, bulgarianProbability, topLanguage)
            let chosen = AutoLanguageDecision.choose(
                english: englishProbability,
                bulgarian: bulgarianProbability,
                topLanguage: topLanguage,
                requireStrongEvidence: requireStrongEvidence
            )
            DebugLog.shared.log("[WhisperBridge] autoDetection seconds=\(String(format: "%.2f", Double(sampleCount) / 16000)) top=\(topLanguage) en=\(String(format: "%.4f", englishProbability)) bg=\(String(format: "%.4f", bulgarianProbability)) chosen=\(chosen?.whisperCode ?? "uncertain")")
            return chosen
        }

        if openingSamples >= 16000,
           let openingLanguage = detect(sampleCount: openingSamples, requireStrongEvidence: true) {
            return openingLanguage
        }
        if let fullLanguage = detect(sampleCount: audioBuffer.count, requireStrongEvidence: false) {
            return fullLanguage
        }
        return .english
    }

    private static func probability(_ probabilities: [Float], id: Int32) -> Float {
        guard id >= 0, Int(id) < probabilities.count else { return 0 }
        return probabilities[Int(id)]
    }

    private static func languageCode(for id: Int32) -> String? {
        guard id >= 0, let cString = whisper_lang_str(id) else { return nil }
        return String(cString: cString)
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
