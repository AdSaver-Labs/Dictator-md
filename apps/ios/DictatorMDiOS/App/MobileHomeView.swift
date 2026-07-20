import SwiftUI

struct MobileHomeView: View {
    @ObservedObject var store: MobileSharedStore
    @StateObject private var recorder = MobileDictationRecorder()

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    LabeledContent("Language", value: store.profile.languageMode.displayName)
                    LabeledContent("Recent dictations", value: "\(store.events.count)")
                    LabeledContent("Recorder", value: recorder.status)
                }

                Section("Dictation") {
                    Button(recorder.isRecording ? "Stop Recording" : "Start Recording") {
                        recorder.isRecording ? recorder.stop() : recorder.start()
                    }

                    Button("Save Test Dictation") {
                        store.record(text: "Dictator-md iOS insertion test.", language: store.profile.languageMode)
                    }
                }

                Section("Keyboard Setup") {
                    Text("Enable the Dictator-md keyboard in iOS Settings, then use it to insert recent dictations into text fields.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Dictator-md")
        }
    }
}

