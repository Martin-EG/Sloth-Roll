import Foundation

/// The outcome of one extraction plus what it took to get there (for evaluation and logs).
struct ExtractionReport: Sendable, Equatable {
    let result: ActionResult
    /// Model calls made: 1, or 2 when the first answer was unusable.
    let attempts: Int
    /// Raw model text for each attempt that produced any.
    let rawOutputs: [String]
    /// Why each failed attempt failed.
    let problems: [String]
    /// True when every attempt failed and `result` is the safe fallback.
    let usedFallback: Bool
    let duration: Duration
}
