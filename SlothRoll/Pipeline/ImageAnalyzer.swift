import CoreGraphics
import Foundation
import Vision

/// Live `ImageAnalyzing`: Laplacian variance on a small grayscale copy for blur, and Vision's
/// image feature print for near-duplicates. Both run off the main actor.
struct ImageAnalyzer: ImageAnalyzing {
    /// A 3x3 Laplacian needs at least one interior pixel.
    private static let minSide = 3

    func signals(for image: CGImage) async -> ImageSignals? {
        await analyze(image)
    }

    @concurrent
    private func analyze(_ image: CGImage) async -> ImageSignals? {
        let clock = ContinuousClock()
        let start = clock.now
        guard let gray = Self.grayscale(image, maxPixels: PipelineConfig.blurImageMaxPixels)
        else { return nil }
        let measures = Self.measure(gray: gray.pixels, width: gray.width, height: gray.height)
        let featurePrint = Self.featurePrint(of: image)
        Log.pipeline.debug(
            "analyze sharpness=\(measures.sharpness, format: .fixed(precision: 1)) contrast=\(measures.contrast, format: .fixed(precision: 1)) print=\(featurePrint != nil) s=\(start.duration(to: clock.now).seconds, format: .fixed(precision: 3))"
        )
        return ImageSignals(
            sharpness: measures.sharpness, contrast: measures.contrast, featurePrint: featurePrint)
    }

    /// Variance of the 4-neighbour Laplacian (sharpness) and standard deviation of the pixels
    /// (contrast), on 8-bit grayscale stored row by row.
    static func measure(gray: [UInt8], width: Int, height: Int) -> (sharpness: Double, contrast: Double) {
        guard width >= minSide, height >= minSide, gray.count >= width * height else { return (0, 0) }
        var pixelSum = 0.0
        var pixelSquares = 0.0
        for value in gray.prefix(width * height) {
            pixelSum += Double(value)
            pixelSquares += Double(value) * Double(value)
        }
        let pixelCount = Double(width * height)
        let pixelMean = pixelSum / pixelCount
        let contrast = (max(0, pixelSquares / pixelCount - pixelMean * pixelMean)).squareRoot()

        var laplacianSum = 0.0
        var laplacianSquares = 0.0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = y * width + x
                let laplacian =
                    4 * Double(gray[center]) - Double(gray[center - 1]) - Double(gray[center + 1])
                    - Double(gray[center - width]) - Double(gray[center + width])
                laplacianSum += laplacian
                laplacianSquares += laplacian * laplacian
            }
        }
        let interior = Double((width - 2) * (height - 2))
        let laplacianMean = laplacianSum / interior
        let sharpness = max(0, laplacianSquares / interior - laplacianMean * laplacianMean)
        return (sharpness, contrast)
    }

    // MARK: - Private

    /// Draws the image into an 8-bit grayscale buffer whose long side is at most `maxPixels`.
    private static func grayscale(
        _ image: CGImage, maxPixels: Int
    ) -> (pixels: [UInt8], width: Int, height: Int)? {
        let scale = min(1, Double(maxPixels) / Double(max(image.width, image.height, 1)))
        let width = Int((Double(image.width) * scale).rounded())
        let height = Int((Double(image.height) * scale).rounded())
        guard width >= minSide, height >= minSide else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? (pixels, width, height) : nil
    }

    /// Revision 2 is pinned so `PipelineConfig.duplicateDistanceThreshold` keeps its meaning.
    private static func featurePrint(of image: CGImage) -> [Float]? {
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision2
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            Log.pipeline.error("feature_print_failed error=\(String(describing: error), privacy: .public)")
            return nil
        }
        guard let observation = request.results?.first, observation.elementType == .float else {
            return nil
        }
        let print = ImageSignals.featurePrint(from: observation.data)
        return print.count == observation.elementCount ? print : nil
    }
}
