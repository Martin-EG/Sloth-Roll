/// How much of the photo library the user let the app read.
enum PhotoAccess: Sendable, Equatable {
    case full
    /// Only the photos the user picked; the scan works on those.
    case limited
    case denied

    var canRead: Bool { self != .denied }
}
