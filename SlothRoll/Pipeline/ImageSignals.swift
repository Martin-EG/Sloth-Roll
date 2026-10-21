import Foundation

/// Cheap per-image measurements taken at triage, used to offer useless screenshots for cleanup.
struct ImageSignals: Sendable, Equatable {
    /// Laplacian variance of the downscaled grayscale image; low means blurry.
    let sharpness: Double
    /// Standard deviation of the grayscale pixels; near zero means a flat (blank) image.
    let contrast: Double
    /// Vision feature print (revision 2); nil when Vision couldn't compute one.
    let featurePrint: [Float]?

    var isBlurry: Bool { Self.isBlurry(sharpness: sharpness, contrast: contrast) }

    /// Few sharp edges, but not a flat image: a blank screen has no edges and isn't "blurry".
    static func isBlurry(sharpness: Double, contrast: Double) -> Bool {
        contrast >= PipelineConfig.flatContrastThreshold
            && sharpness < PipelineConfig.blurSharpnessThreshold
    }

    /// Raw bytes for SwiftData.
    static func data(from featurePrint: [Float]) -> Data {
        featurePrint.withUnsafeBytes { Data($0) }
    }

    /// Reads back `data(from:)`; trailing bytes that don't fill a `Float` are ignored.
    static func featurePrint(from data: Data) -> [Float] {
        let size = MemoryLayout<Float>.size
        return data.withUnsafeBytes { bytes in
            (0..<(bytes.count / size)).map {
                bytes.loadUnaligned(fromByteOffset: $0 * size, as: Float.self)
            }
        }
    }
}
