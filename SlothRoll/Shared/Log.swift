import os

/// os.Logger categories for the app (subsystem "SlothRoll", one category per folder).
enum Log {
    static let subsystem = "SlothRoll"

    static let app = Logger(subsystem: subsystem, category: "app")
    /// Day-1 model spike metrics (load time, inference time, memory).
    static let spike = Logger(subsystem: subsystem, category: "spike")
}
