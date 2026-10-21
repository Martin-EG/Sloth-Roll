#if DEBUG
/// A human verdict on one eval row.
enum EvalMark: Codable, Sendable, Equatable {
    case correct
    /// Wrong; the screenshot should have been this type.
    case wrong(expected: ActionType)
}
#endif
