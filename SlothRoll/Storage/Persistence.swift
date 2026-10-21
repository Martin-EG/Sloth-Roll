import SwiftData

/// Builds the app's SwiftData container (scan cache and expenses).
enum Persistence {
    static let schema = Schema([ScreenshotItem.self, Expense.self])

    /// On-disk store; falls back to memory (and logs) if the store can't be opened, so a
    /// corrupt cache costs a rescan instead of a crash.
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        if !inMemory {
            do {
                return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
            } catch {
                Log.storage.error(
                    "store_open_failed error=\(String(describing: error), privacy: .public)")
            }
        }
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        } catch {
            // An in-memory store failing means SwiftData itself is broken; nothing to fall back to.
            fatalError("SwiftData in-memory store failed: \(error)")
        }
    }
}
