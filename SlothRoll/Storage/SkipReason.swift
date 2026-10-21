/// Why an image was marked `skipped`, so a later cleanup pass can treat each kind differently.
enum SkipReason: String, Codable, Sendable, CaseIterable {
    /// A photo taken with a camera (has camera metadata); not scanned.
    case camera
    /// Triage: too little text for an action to be in it.
    case littleText
    /// The model read it and found no action (type "none").
    case noAction
    /// The user swiped its card left.
    case swipedLeft
}
