import Observation

/// Inbox for scan requests from outside the app's UI (the App Intent run by the Action
/// Button, Siri, or Shortcuts); `RootView` picks them up and runs them on the Scan tab.
@Observable
@MainActor
final class ScanRequests {
    /// A "scan my latest screenshot" request is waiting.
    private(set) var hasPendingLatest = false

    func requestLatestScreenshot() {
        hasPendingLatest = true
    }

    /// True once per request: clears it, so a second launch doesn't run it again.
    func takeLatestScreenshotRequest() -> Bool {
        defer { hasPendingLatest = false }
        return hasPendingLatest
    }
}
