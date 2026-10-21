import Foundation

/// Tunables for the actions (event length, Maps lookup).
enum ActionsConfig {
    /// Length of an event that has a start time but no end time.
    static let defaultEventDuration: TimeInterval = 60 * 60

    /// URL scheme and query key for the Maps fallback when the place search finds nothing.
    static let mapsFallbackScheme = "maps"
    static let mapsFallbackQueryKey = "q"
}
