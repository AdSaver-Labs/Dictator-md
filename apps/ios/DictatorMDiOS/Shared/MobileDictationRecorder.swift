import Foundation

final class MobileDictationRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var status = "Ready"

    func start() {
        isRecording = true
        status = "Recording prototype"
    }

    func stop() {
        isRecording = false
        status = "Stopped"
    }
}

