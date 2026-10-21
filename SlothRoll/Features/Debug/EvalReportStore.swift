#if DEBUG
import Foundation

/// Reads and writes `EvalReport` as JSON in the app's Documents folder (debug builds only).
struct EvalReportStore: Sendable {
    private let fileURL: URL

    init(fileURL: URL = URL.documentsDirectory.appending(path: EvalConfig.reportFileName)) {
        self.fileURL = fileURL
    }

    func load() -> EvalReport? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(EvalReport.self, from: data)
    }

    func save(_ report: EvalReport) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            try encoder.encode(report).write(to: fileURL, options: .atomic)
        } catch {
            Log.eval.error("report_save_failed error=\(String(describing: error), privacy: .public)")
        }
    }
}
#endif
