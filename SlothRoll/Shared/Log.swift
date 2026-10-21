import os

/// os.Logger categories for the app (subsystem "SlothRoll", one category per folder).
enum Log {
    static let subsystem = "SlothRoll"

    static let app = Logger(subsystem: subsystem, category: "app")
    /// Extraction attempts, parse failures, OCR errors, scan progress and timings.
    static let pipeline = Logger(subsystem: subsystem, category: "pipeline")
    /// SwiftData store open and save failures.
    static let storage = Logger(subsystem: subsystem, category: "storage")
    /// Scan screen: user actions and the debug stats file.
    static let scan = Logger(subsystem: subsystem, category: "scan")
    /// Calendar, Maps, and expense actions: results and failures (no event contents).
    static let actions = Logger(subsystem: subsystem, category: "actions")
    /// Expenses screen.
    static let expenses = Logger(subsystem: subsystem, category: "expenses")
    /// Debug eval screen: per-image timings and the run summary.
    static let eval = Logger(subsystem: subsystem, category: "eval")
}
