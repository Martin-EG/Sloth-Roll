import Foundation

/// Failures from the Inference layer, with user-facing messages.
enum InferenceError: LocalizedError, Equatable {
    case modelNotLoaded
    case downloadFailed(reason: String)
    case loadFailed(reason: String)
    case generationFailed(reason: String)
    case emptyOutput

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "The model isn't loaded yet. Load it first."
        case .downloadFailed:
            "Couldn't download the model. Check your connection and free space, then try again."
        case .loadFailed:
            "Couldn't download or load the model. Check your connection and free space, then try again."
        case .generationFailed:
            "The model couldn't read this image. Try another one."
        case .emptyOutput:
            "The model returned an empty answer. Try again."
        }
    }
}
