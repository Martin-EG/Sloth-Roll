#if DEBUG
import Foundation

/// JSON snapshot of an eval run, saved to Documents so results and marks survive relaunches
/// and can be copied off the device.
struct EvalReport: Codable, Sendable {
    struct Row: Codable, Sendable {
        let assetID: String
        let result: ActionResult
        let attempts: Int
        let usedFallback: Bool
        let rawOutputs: [String]
        let problems: [String]
        let extractionSeconds: Double
        let ocrSeconds: Double
        let ocrCharacters: Int
        let ocrLines: Int
        let ocrTextPreview: String
        let mark: EvalMark?
    }

    let modelID: String
    let createdAt: Date
    /// Images in the album, including ones that couldn't be loaded. Optional so reports
    /// saved before this field existed still load (and keep their marks).
    let albumCount: Int?
    /// Assets that couldn't be read from the device (usually iCloud-only originals).
    let skippedAssetIDs: [String]?
    let rows: [Row]

    init(
        modelID: String, createdAt: Date, albumCount: Int, skippedAssetIDs: [String],
        rows: [EvalRow]
    ) {
        self.modelID = modelID
        self.createdAt = createdAt
        self.albumCount = albumCount
        self.skippedAssetIDs = skippedAssetIDs
        self.rows = rows.map { row in
            Row(
                assetID: row.assetID,
                result: row.report.result,
                attempts: row.report.attempts,
                usedFallback: row.report.usedFallback,
                rawOutputs: row.report.rawOutputs,
                problems: row.report.problems,
                extractionSeconds: row.report.duration.seconds,
                ocrSeconds: row.textScan.duration.seconds,
                ocrCharacters: row.textScan.characterCount,
                ocrLines: row.textScan.lineCount,
                ocrTextPreview: String(
                    row.textScan.text.prefix(EvalConfig.reportTextPreviewCharacters)),
                mark: row.mark)
        }
    }
}
#endif
