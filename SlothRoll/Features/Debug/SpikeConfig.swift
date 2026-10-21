import Foundation

/// Constants for the temporary day-1 model spike screen.
enum SpikeConfig {
    static let prompt = """
        Describe this screenshot in one sentence. Then say if it contains an event, a place, \
        a receipt, or none.
        """

    /// How often memory is sampled while the model loads or runs, to catch the peak.
    static let memorySampleInterval: Duration = .milliseconds(100)

    static let byteFormat = ByteCountFormatStyle(style: .memory)
}
