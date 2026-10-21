import Foundation

/// Failures inside the scan pipeline: unusable model output or unreadable photos.
enum PipelineError: LocalizedError, Equatable, Sendable {
    case noJSONObject
    case malformedJSON(reason: String)
    case invalidDate(String)
    case invalidTime(String)
    case negativeAmount(Decimal)
    case missingTitle
    case photoAccessDenied
    case albumNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noJSONObject, .malformedJSON, .invalidDate, .invalidTime, .negativeAmount,
            .missingTitle:
            "The model's answer couldn't be used."
        case .photoAccessDenied:
            "Sloth Roll needs access to your photos. Allow it in Settings."
        case .albumNotFound(let name):
            "No album named “\(name)” was found."
        }
    }
}
