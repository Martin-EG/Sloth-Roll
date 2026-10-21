import Foundation

/// A short message shown briefly over the screen, e.g. the result of a swipe.
struct Toast: Equatable, Identifiable {
    let id = UUID()
    let message: String
    /// Errors are tinted so a failed action doesn't read like a success.
    let isError: Bool
}
