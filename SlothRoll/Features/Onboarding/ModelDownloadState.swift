/// Where the one-time model download stands on the last onboarding screen.
enum ModelDownloadState: Equatable {
    /// Looking on disk for an earlier download.
    case checking
    /// Not downloaded yet; waiting for the user to start.
    case idle
    /// Running; `fraction` is 0...1.
    case downloading(fraction: Double)
    /// Failed; `message` is user-facing. The user can retry.
    case failed(message: String)
    /// On disk and ready to load.
    case done
}
