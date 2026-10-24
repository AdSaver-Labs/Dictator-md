import AppKit
import SwiftUI

@main
struct ReviewPreview: App {
    var body: some Scene {
        WindowGroup("Disposable language review verification") { ReviewFixture() }
            .defaultSize(width: 520, height: 480)
    }
}

private struct ReviewFixture: View {
    @State private var text = "A local draft. Благоевград."
    @State private var canRetry = true
    @State private var message = "Auto could not confidently distinguish English from Bulgarian. Nothing has been pasted."
    @State private var action = "No action"

    var body: some View {
        VStack {
            DictationReviewView(text: $text, languageMessage: message, canRetryLanguage: canRetry,
                retry: { action = "Retry \($0.rawValue) requested" },
                discard: { action = "Discard requested" },
                insert: { action = "Insert requested" })
            Text(action).accessibilityLabel("Last test action: \(action)")
            Button("Simulate expiry") {
                canRetry = false
                message = "Audio retry is unavailable or expired. You can still edit and insert the draft, or record again with EN or BG selected."
            }
        }.padding(.bottom, 12)
    }
}
