import AVFoundation
import CoreMedia

final class AudioCapture: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private var captureSession: AVCaptureSession?
    private var captureOutput: AVCaptureAudioDataOutput?
    private let captureQueue = DispatchQueue(label: "com.dictatormd.audioCapture")
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private var tapCount = 0
    private var rawFrameCount = 0
    private var appendedFrameCount = 0
    private var emptyTapCount = 0

    private static let sampleRate: Double = 16000

    func startRecording() throws {
        DebugLog.shared.log("[AudioCapture] startRecording")
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if microphoneStatus == .notDetermined {
            DebugLog.shared.log("[AudioCapture] microphonePermissionNotDetermined requesting")
            PermissionManager.shared.requestMicrophone()
        }
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            DebugLog.shared.log("[AudioCapture] microphonePermissionDenied")
            throw AudioCaptureError.microphonePermissionDenied
        }

        AudioDeviceManager.shared.refreshDevices()
        if let selected = AudioDeviceManager.shared.selectedDevice {
            DebugLog.shared.log("[AudioCapture] selectedDevice name=\(selected.name) uid=\(selected.uid)")
        } else {
            DebugLog.shared.log("[AudioCapture] selectedDevice systemDefault")
        }

        bufferLock.lock()
        audioBuffer.removeAll()
        tapCount = 0
        rawFrameCount = 0
        appendedFrameCount = 0
        emptyTapCount = 0
        bufferLock.unlock()

        let device = try Self.captureDevice()
        DebugLog.shared.log("[AudioCapture] captureDevice name=\(device.localizedName) uid=\(device.uniqueID)")

        let session = AVCaptureSession()
        session.beginConfiguration()

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            DebugLog.shared.log("[AudioCapture] cannotAddInput device=\(device.localizedName)")
            throw AudioCaptureError.cannotAddInput
        }
        session.addInput(input)

        let output = AVCaptureAudioDataOutput()
        output.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsNonInterleaved: false
        ]
        output.setSampleBufferDelegate(self, queue: captureQueue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            DebugLog.shared.log("[AudioCapture] cannotAddOutput")
            throw AudioCaptureError.cannotAddOutput
        }
        session.addOutput(output)
        session.commitConfiguration()

        captureSession = session
        captureOutput = output
        session.startRunning()
        guard session.isRunning else {
            captureOutput?.setSampleBufferDelegate(nil, queue: nil)
            captureOutput = nil
            captureSession = nil
            DebugLog.shared.log("[AudioCapture] sessionDidNotStart")
            throw AudioCaptureError.sessionDidNotStart
        }

        fputs("[AudioCapture] Recording started with \(device.localizedName)\n", stderr)
        DebugLog.shared.log("[AudioCapture] recordingStarted")
    }

    /// Stops capture and returns the captured buffer.
    /// - Parameter trimTrailingSeconds: optional number of seconds to trim from the END of the
    ///   buffer. Used by toggle hotkey mode to discard the silent hold-to-stop interval, which
    ///   would otherwise be transcribed by Whisper as hallucinated punctuation/filler.
    func stopRecording(trimTrailingSeconds: TimeInterval = 0) -> [Float] {
        captureOutput?.setSampleBufferDelegate(nil, queue: nil)
        captureSession?.stopRunning()
        captureOutput = nil
        captureSession = nil

        bufferLock.lock()
        var buffer = audioBuffer
        let finalTapCount = tapCount
        let finalRawFrameCount = rawFrameCount
        let finalAppendedFrameCount = appendedFrameCount
        let finalEmptyTapCount = emptyTapCount
        audioBuffer.removeAll()
        tapCount = 0
        rawFrameCount = 0
        appendedFrameCount = 0
        emptyTapCount = 0
        bufferLock.unlock()

        if trimTrailingSeconds > 0 {
            let samplesToTrim = Int(trimTrailingSeconds * Self.sampleRate)
            if buffer.count > samplesToTrim {
                buffer.removeLast(samplesToTrim)
            } else {
                buffer.removeAll()
            }
        }

        let rawEnergy = Self.energy(buffer)
        let boost = Self.quietVoiceBoost(for: rawEnergy)
        if boost > 1 {
            buffer = Self.applyingGain(boost, to: buffer)
        }
        let finalEnergy = Self.energy(buffer)
        let sec = Double(buffer.count) / Self.sampleRate
        fputs("[AudioCapture] Stopped. \(buffer.count) samples (\(String(format: "%.1f", sec))s, trimmed \(String(format: "%.1f", trimTrailingSeconds))s)\n", stderr)
        DebugLog.shared.log("[AudioCapture] stopped samples=\(buffer.count) seconds=\(String(format: "%.2f", sec)) trimmed=\(String(format: "%.2f", trimTrailingSeconds)) rms=\(String(format: "%.5f", finalEnergy.rms)) peak=\(String(format: "%.5f", finalEnergy.peak)) rawRms=\(String(format: "%.5f", rawEnergy.rms)) rawPeak=\(String(format: "%.5f", rawEnergy.peak)) quietBoost=\(String(format: "%.2f", boost)) taps=\(finalTapCount) rawFrames=\(finalRawFrameCount) appendedFrames=\(finalAppendedFrameCount) emptyTaps=\(finalEmptyTapCount)")
        return buffer
    }

    var isRecording: Bool {
        captureSession?.isRunning ?? false
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let rawFrameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        let samples = Self.samples(from: sampleBuffer)

        bufferLock.lock()
        tapCount += 1
        self.rawFrameCount += rawFrameCount
        if samples.isEmpty {
            emptyTapCount += 1
        } else {
            appendedFrameCount += samples.count
            audioBuffer.append(contentsOf: samples)
        }
        bufferLock.unlock()
    }

    private static func captureDevice() throws -> AVCaptureDevice {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        ).devices

        if let uid = AppSettings.shared.selectedAudioDeviceUID,
           let selected = devices.first(where: { $0.uniqueID == uid }) {
            return selected
        }

        if let selected = AudioDeviceManager.shared.selectedDevice,
           let matchingDevice = devices.first(where: { $0.uniqueID == selected.uid || $0.localizedName == selected.name }) {
            return matchingDevice
        }

        if let defaultDevice = AVCaptureDevice.default(for: .audio) {
            return defaultDevice
        }

        if let firstDevice = devices.first {
            return firstDevice
        }

        DebugLog.shared.log("[AudioCapture] noInputDevice")
        throw AudioCaptureError.noInputDevice
    }

    private static func samples(from sampleBuffer: CMSampleBuffer) -> [Float] {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return []
        }

        let format = streamDescription.pointee
        guard format.mFormatID == kAudioFormatLinearPCM,
              format.mSampleRate > 0,
              format.mChannelsPerFrame > 0,
              format.mBitsPerChannel > 0 else {
            return []
        }

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return []
        }

        var lengthAtOffset = 0
        var totalLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )
        guard status == kCMBlockBufferNoErr, let dataPointer, totalLength > 0 else {
            return []
        }

        let frames = CMSampleBufferGetNumSamples(sampleBuffer)
        let channels = max(1, Int(format.mChannelsPerFrame))
        let bitsPerSample = Int(format.mBitsPerChannel)
        let bytesPerSample = max(1, bitsPerSample / 8)
        let isFloat = (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let isSignedInteger = (format.mFormatFlags & kAudioFormatFlagIsSignedInteger) != 0
        let isNonInterleaved = (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0
        let streamBytesPerFrame = max(1, Int(format.mBytesPerFrame))
        let bytesPerFrame = isNonInterleaved
            ? max(bytesPerSample, streamBytesPerFrame)
            : max(bytesPerSample * channels, streamBytesPerFrame)
        let raw = UnsafeRawPointer(dataPointer)

        guard frames > 0 else { return [] }

        var mono = [Float]()
        mono.reserveCapacity(frames)

        for frame in 0..<frames {
            var sum: Float = 0
            var readChannels = 0

            for channel in 0..<channels {
                let offset: Int
                if isNonInterleaved {
                    let planeBytes = frames * bytesPerFrame
                    offset = (channel * planeBytes) + (frame * bytesPerFrame)
                } else {
                    offset = (frame * bytesPerFrame) + (channel * bytesPerSample)
                }

                guard offset >= 0, offset + bytesPerSample <= totalLength else { continue }
                sum += readSample(raw, offset: offset, bitsPerSample: bitsPerSample, isFloat: isFloat, isSignedInteger: isSignedInteger)
                readChannels += 1
            }

            if readChannels > 0 {
                mono.append(sum / Float(readChannels))
            }
        }

        return resampledMonoSamples(mono, inputSampleRate: format.mSampleRate)
    }

    private static func readSample(
        _ data: UnsafeRawPointer,
        offset: Int,
        bitsPerSample: Int,
        isFloat: Bool,
        isSignedInteger: Bool
    ) -> Float {
        if isFloat {
            if bitsPerSample == 32 {
                return data.load(fromByteOffset: offset, as: Float.self)
            }
            if bitsPerSample == 64 {
                return Float(data.load(fromByteOffset: offset, as: Double.self))
            }
        }

        if isSignedInteger {
            switch bitsPerSample {
            case 8:
                return Float(data.load(fromByteOffset: offset, as: Int8.self)) / Float(Int8.max)
            case 16:
                return Float(data.load(fromByteOffset: offset, as: Int16.self)) / Float(Int16.max)
            case 32:
                return Float(data.load(fromByteOffset: offset, as: Int32.self)) / Float(Int32.max)
            default:
                return 0
            }
        }

        switch bitsPerSample {
        case 8:
            return (Float(data.load(fromByteOffset: offset, as: UInt8.self)) - 128) / 128
        case 16:
            return (Float(data.load(fromByteOffset: offset, as: UInt16.self)) - 32768) / 32768
        case 32:
            return (Float(data.load(fromByteOffset: offset, as: UInt32.self)) - 2147483648) / 2147483648
        default:
            return 0
        }
    }

    private static func resampledMonoSamples(_ input: [Float], inputSampleRate: Double) -> [Float] {
        guard inputSampleRate > 0, !input.isEmpty else { return [] }

        if inputSampleRate == sampleRate {
            return input
        }

        let outputCount = max(1, Int((Double(input.count) * sampleRate / inputSampleRate).rounded()))
        var output = [Float](repeating: 0, count: outputCount)
        let step = inputSampleRate / sampleRate

        for outputIndex in 0..<outputCount {
            let sourcePosition = Double(outputIndex) * step
            let lower = Int(sourcePosition.rounded(.down))
            let upper = min(lower + 1, input.count - 1)
            let fraction = Float(sourcePosition - Double(lower))
            let a = input[min(lower, input.count - 1)]
            let b = input[upper]
            output[outputIndex] = a + (b - a) * fraction
        }

        return output
    }

    private static func energy(_ buffer: [Float]) -> (rms: Double, peak: Float) {
        guard !buffer.isEmpty else { return (0, 0) }

        var sumSquares = 0.0
        var maxPeak: Float = 0
        for sample in buffer {
            sumSquares += Double(sample * sample)
            maxPeak = max(maxPeak, abs(sample))
        }

        return (sqrt(sumSquares / Double(buffer.count)), maxPeak)
    }

    private static func quietVoiceBoost(for energy: (rms: Double, peak: Float)) -> Float {
        guard energy.rms >= 0.0008 || energy.peak >= 0.003 else { return 1 }
        guard energy.rms < 0.035, energy.peak < 0.75 else { return 1 }

        let targetRMS = 0.045
        let rmsGain = targetRMS / max(energy.rms, 0.0001)
        let peakSafeGain = 0.88 / max(Double(energy.peak), 0.01)
        return Float(min(8.0, max(1.0, min(rmsGain, peakSafeGain))))
    }

    private static func applyingGain(_ gain: Float, to buffer: [Float]) -> [Float] {
        buffer.map { sample in
            let boosted = sample * gain
            return max(-0.95, min(0.95, boosted))
        }
    }

}

enum AudioCaptureError: LocalizedError {
    case microphonePermissionDenied
    case noInputDevice
    case cannotAddInput
    case cannotAddOutput
    case sessionDidNotStart

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is not granted."
        case .noInputDevice:
            return "No microphone input device is available."
        case .cannotAddInput:
            return "The selected microphone could not be added."
        case .cannotAddOutput:
            return "Microphone capture output could not be added."
        case .sessionDidNotStart:
            return "Microphone capture session did not start."
        }
    }
}
