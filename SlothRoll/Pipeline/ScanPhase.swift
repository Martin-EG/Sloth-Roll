/// What the scan is doing right now, for the progress UI.
enum ScanPhase: Equatable, Sendable {
    case idle
    /// Asking for Photos access and listing new images.
    case preparing
    /// OCR over every new image.
    case triage
    /// Downloading (first time) and loading the extraction model.
    case loadingModel
    /// The model reads each candidate.
    case extract
    /// Finished normally.
    case finished
    /// The user stopped it; work so far is saved.
    case cancelled
    /// iOS warned about memory: the current item finished, the model was unloaded.
    case pausedForMemory
    /// Couldn't start or load the model; `message` is user-facing.
    case failed(message: String)

    var isRunning: Bool {
        switch self {
        case .preparing, .triage, .loadingModel, .extract: true
        case .idle, .finished, .cancelled, .pausedForMemory, .failed: false
        }
    }
}
