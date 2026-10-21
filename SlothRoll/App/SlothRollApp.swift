import SwiftUI

/// App entry point.
@main
struct SlothRollApp: App {
    private let dependencies = AppDependencies.live

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .modelContainer(dependencies.modelContainer)
        }
    }
}
