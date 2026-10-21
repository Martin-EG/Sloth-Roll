import os

/// os.Logger categories for the app (subsystem "SlothRoll", one category per folder).
enum Log {
    static let subsystem = "SlothRoll"

    static let app = Logger(subsystem: subsystem, category: "app")
    /// Extraction attempts, parse failures, OCR errors.
    static let pipeline = Logger(subsystem: subsystem, category: "pipeline")
    /// Debug eval screen: per-image timings and the run summary.
    static let eval = Logger(subsystem: subsystem, category: "eval")
}
