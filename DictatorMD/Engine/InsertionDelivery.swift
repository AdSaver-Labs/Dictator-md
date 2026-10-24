import Foundation

enum InsertionOutcome: String, Codable {
    case confirmed
    case sentUnverified
    case failed

    var wasSent: Bool { self != .failed }
}

/// Local delivery metadata only. No destination text, selection or clipboard data.
struct InsertionDelivery: Codable, Equatable {
    let outcome: InsertionOutcome
    let strategy: String
    let reason: String
    let durationMilliseconds: Int

    var summary: String {
        switch outcome {
        case .confirmed: return "Delivery confirmed"
        case .sentUnverified: return "Sent; delivery not confirmed"
        case .failed: return "Not inserted"
        }
    }

    var explanation: String {
        switch reason {
        case "draftChanged": return "The original draft changed while processing."
        case "selectionChanged": return "The original selection could not be restored."
        case "secureField": return "Password fields are excluded."
        case "clipboardChanged": return "A newer clipboard copy was preserved."
        case "permissionMissing": return "macOS did not allow Accessibility access."
        case "cancelled": return "The operation was cancelled."
        case "destinationUnavailable": return "The original destination could not be restored."
        case "readbackUnavailable": return "The editor did not confirm the exact text. Check before pasting again."
        case "verified": return "The original field contains the expected edit."
        default: return "The text remains available in History."
        }
    }
}
