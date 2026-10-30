/// How a "scan my latest screenshot" request ended, for the one line on the Scan tab.
enum LatestScanOutcome: Equatable, Sendable {
    /// The newest screenshot is a card waiting for a swipe (just read, or read before).
    case card(ActionType)
    /// The user already swiped its card.
    case alreadyDone
    /// Too little text, or the model found no event, place, or receipt (or couldn't read it).
    case nothingFound
    /// No screenshot or saved image among the newest images on the device.
    case noScreenshot
    /// Photos access is off.
    case noPhotoAccess
    /// The model couldn't be loaded; `message` is user-facing.
    case modelLoadFailed(message: String)
    /// A scan was already running; it reads the newest images first anyway.
    case busy
}
