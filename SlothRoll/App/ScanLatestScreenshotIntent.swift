import AppIntents

/// "Scan Latest Screenshot": opens Sloth Roll on the Scan tab and reads only the newest
/// screenshot into a card. Meant for the Action Button, Back Tap, Siri, or a Shortcut.
struct ScanLatestScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan Latest Screenshot"
    static var description: IntentDescription {
        IntentDescription("Opens Sloth Roll and reads your newest screenshot into a card you can swipe.")
    }
    /// The model runs on the GPU, which iOS gives only to the app in the foreground.
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Returns right away: Shortcuts would time out waiting for the model; the app shows
        // the progress and the card instead.
        AppDependencies.live.scanRequests.requestLatestScreenshot()
        return .result()
    }
}
