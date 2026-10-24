import SwiftUI

struct DictationReviewView: View {
    @Binding var text: String
    let languageMessage: String?
    let canRetryLanguage: Bool
    let retry: (AppSettings.DictationLanguage) -> Void
    let discard: () -> Void
    let insert: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Review dictation").font(.headline)
            if let languageMessage {
                Text(languageMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Retry in English") { retry(.english) }
                    Button("Retry in Bulgarian") { retry(.bulgarian) }
                }
                .disabled(!canRetryLanguage)
                if canRetryLanguage {
                    Text("Audio stays in memory for up to 5 minutes, then is discarded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            TextEditor(text: $text)
                .accessibilityLabel("Dictation draft")
                .frame(minHeight: 180)
                .border(.separator)
            HStack {
                Spacer()
                Button("Discard", action: discard)
                Button("Insert", action: insert)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 280)
    }
}
