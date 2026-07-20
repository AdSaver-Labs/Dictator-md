import UIKit

final class KeyboardViewController: UIInputViewController {
    private let appGroupId = "group.com.dictatormd.shared"
    private let eventsKey = "dictator-md.mobile.events"

    override func viewDidLoad() {
        super.viewDidLoad()
        buildKeyboard()
    }

    private func buildKeyboard() {
        view.backgroundColor = .systemBackground

        let insertButton = UIButton(type: .system)
        insertButton.setTitle("Insert Last Dictation", for: .normal)
        insertButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        insertButton.addTarget(self, action: #selector(insertLatestDictation), for: .touchUpInside)

        let nextKeyboardButton = UIButton(type: .system)
        nextKeyboardButton.setTitle("Next Keyboard", for: .normal)
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        let stack = UIStackView(arrangedSubviews: [insertButton, nextKeyboardButton])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -12)
        ])
    }

    @objc private func insertLatestDictation() {
        textDocumentProxy.insertText(latestDictationText())
    }

    private func latestDictationText() -> String {
        let defaults = UserDefaults(suiteName: appGroupId) ?? .standard
        guard let data = defaults.data(forKey: eventsKey),
              let objects = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let text = objects.first?["text"] as? String,
              !text.isEmpty else {
            return "Dictator-md iOS insertion test."
        }
        return text
    }
}

