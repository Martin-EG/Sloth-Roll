import AppIntents

/// Puts "Scan Latest Screenshot" in Siri, Spotlight, the Shortcuts app, and the Action
/// Button's Shortcut list, with no Shortcut for the user to build.
struct SlothRollShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanLatestScreenshotIntent(),
            phrases: [
                "Scan my latest screenshot with \(.applicationName)",
                "Read my last screenshot in \(.applicationName)",
            ],
            shortTitle: "Scan Latest Screenshot",
            systemImageName: "sparkle.magnifyingglass")
    }
}
