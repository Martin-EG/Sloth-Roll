import Foundation

/// Failures inside the scan pipeline: unusable model output or unreadable photos.
enum PipelineError: LocalizedError, Equatable, Sendable {
    case noJSONObject
    case malformedJSON(reason: String)
    /// Valid JSON, but no "type" key (e.g. {"error": "..."} or a half-filled object).
    case missingType
    case invalidDate(String)
    case invalidTime(String)
    case negativeAmount(Decimal)
    case missingTitle
    case photoAccessDenied
    case albumNotFound(String)
    /// Photos refused the deletion for a reason other than the user tapping "Don't Allow".
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .noJSONObject, .malformedJSON, .missingType, .invalidDate, .invalidTime, .negativeAmount,
            .missingTitle:
            "The model's answer couldn't be used."
        case .photoAccessDenied:
            "Sloth Roll needs access to your photos. Allow it in Settings."
        case .albumNotFound(let name):
            "No album named “\(name)” was found."
        case .deleteFailed:
            "Couldn't delete the screenshots. Try again."
        }
    }
}
