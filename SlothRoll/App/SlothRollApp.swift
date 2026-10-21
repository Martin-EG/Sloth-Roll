import SwiftUI

/// App entry point.
@main
struct SlothRollApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(dependencies: .live)
        }
    }
}
