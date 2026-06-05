import Foundation

struct ProsodyFeatures {
    let duration: Double
    let speechRatio: Double
    let longestSilence: Double
    let pauseCount: Int
    let endingPitchRise: Bool
    let emphasizedEnding: Bool

    var debugSummary: String {
        "duration=\(String(format: "%.2f", duration)) speechRatio=\(String(format: "%.2f", speechRatio)) longestSilence=\(String(format: "%.2f", longestSilence)) pauses=\(pauseCount) pitchRise=\(endingPitchRise) emphasizedEnding=\(emphasizedEnding)"
    }
}

enum ProsodyAnalyzer {
    private static let sampleRate = 16_000.0
    private static let frameSize = 400
    private static let hopSize = 160

    static func analyze(_ audioBuffer: [Float]) -> ProsodyFeatures {
        let duration = Double(audioBuffer.count) / sampleRate
        guard audioBuffer.count >= frameSize else {
            return ProsodyFeatures(
                duration: duration,
                speechRatio: 0,
                longestSilence: duration,
                pauseCount: 0,
                endingPitchRise: false,
                emphasizedEnding: false
            )
        }

        let frames = makeFrames(audioBuffer)
        let rmsValues = frames.map(\.rms)
        let threshold = speechThreshold(from: rmsValues)
        let voicedFrames = frames.filter { $0.rms >= threshold }
        let speechRatio = Double(voicedFrames.count) / Double(max(frames.count, 1))
        let silence = silenceStats(frames: frames, threshold: threshold)
        let pitchRise = hasEndingPitchRise(frames: voicedFrames)
        let emphasizedEnding = hasEmphasizedEnding(frames: voicedFrames)

        return ProsodyFeatures(
            duration: duration,
            speechRatio: speechRatio,
            longestSilence: silence.longest,
            pauseCount: silence.count,
            endingPitchRise: pitchRise,
            emphasizedEnding: emphasizedEnding
        )
    }

    private struct AudioFrame {
        let samples: ArraySlice<Float>
        let rms: Double
    }

    private static func makeFrames(_ audioBuffer: [Float]) -> [AudioFrame] {
        var frames: [AudioFrame] = []
        var start = 0
        while start + frameSize <= audioBuffer.count {
            let slice = audioBuffer[start..<(start + frameSize)]
            frames.append(AudioFrame(samples: slice, rms: rms(slice)))
            start += hopSize
        }
        return frames
    }

    private static func rms(_ samples: ArraySlice<Float>) -> Double {
        guard !samples.isEmpty else { return 0 }
        var sum = 0.0
        for sample in samples {
            sum += Double(sample * sample)
        }
        return sqrt(sum / Double(samples.count))
    }

    private static func speechThreshold(from rmsValues: [Double]) -> Double {
        guard !rmsValues.isEmpty else { return 0.004 }
        let sorted = rmsValues.sorted()
        let median = sorted[sorted.count / 2]
        let percentile90 = sorted[Int(Double(sorted.count - 1) * 0.90)]
        return max(0.0035, min(0.020, max(median * 1.8, percentile90 * 0.18)))
    }

    private static func silenceStats(frames: [AudioFrame], threshold: Double) -> (longest: Double, count: Int) {
        var current = 0
        var longest = 0
        var count = 0
        let pauseFrames = Int(0.42 / (Double(hopSize) / sampleRate))

        for frame in frames {
            if frame.rms < threshold {
                current += 1
            } else {
                if current >= pauseFrames { count += 1 }
                longest = max(longest, current)
                current = 0
            }
        }

        if current >= pauseFrames { count += 1 }
        longest = max(longest, current)
        return (Double(longest * hopSize) / sampleRate, count)
    }

    private static func hasEndingPitchRise(frames: [AudioFrame]) -> Bool {
        let pitched = frames.compactMap { pitchHz($0.samples) }
        guard pitched.count >= 8 else { return false }

        let early = Array(pitched.prefix(max(4, pitched.count / 3)))
        let late = Array(pitched.suffix(max(4, pitched.count / 4)))
        guard let earlyMedian = median(early), let lateMedian = median(late) else { return false }

        return lateMedian >= earlyMedian * 1.12 && (lateMedian - earlyMedian) >= 18
    }

    private static func hasEmphasizedEnding(frames: [AudioFrame]) -> Bool {
        guard frames.count >= 8 else { return false }
        let allRMS = frames.map(\.rms)
        guard let medianRMS = median(allRMS), medianRMS > 0 else { return false }
        let endingRMS = frames.suffix(max(4, frames.count / 5)).map(\.rms)
        guard let endingMedian = median(Array(endingRMS)) else { return false }
        return endingMedian >= medianRMS * 1.35
    }

    private static func pitchHz(_ samples: ArraySlice<Float>) -> Double? {
        let minLag = Int(sampleRate / 320.0)
        let maxLag = Int(sampleRate / 75.0)
        guard samples.count > maxLag + 2 else { return nil }

        let values = Array(samples)
        let mean = values.reduce(0, +) / Float(values.count)
        let centered = values.map { Double($0 - mean) }
        var bestLag = 0
        var bestCorrelation = 0.0

        for lag in minLag...maxLag {
            var numerator = 0.0
            var leftEnergy = 0.0
            var rightEnergy = 0.0

            for index in 0..<(centered.count - lag) {
                let left = centered[index]
                let right = centered[index + lag]
                numerator += left * right
                leftEnergy += left * left
                rightEnergy += right * right
            }

            let denominator = sqrt(leftEnergy * rightEnergy)
            guard denominator > 0 else { continue }
            let correlation = numerator / denominator
            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }

        guard bestLag > 0, bestCorrelation >= 0.38 else { return nil }
        return sampleRate / Double(bestLag)
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
