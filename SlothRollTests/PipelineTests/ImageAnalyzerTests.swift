import Testing

@testable import SlothRoll

struct ImageAnalyzerTests {
    private let side = 32

    private func image(_ value: (Int, Int) -> UInt8) -> [UInt8] {
        (0..<side).flatMap { y in (0..<side).map { x in value(x, y) } }
    }

    @Test func flatImageIsNeitherSharpNorBlurry() {
        let measures = ImageAnalyzer.measure(gray: image { _, _ in 128 }, width: side, height: side)
        #expect(measures.sharpness == 0)
        #expect(measures.contrast == 0)
        #expect(!ImageSignals.isBlurry(sharpness: measures.sharpness, contrast: measures.contrast))
    }

    @Test func hardEdgesAreSharp() {
        let checkerboard = image { x, y in (x + y).isMultiple(of: 2) ? 0 : 255 }
        let measures = ImageAnalyzer.measure(gray: checkerboard, width: side, height: side)
        #expect(!ImageSignals.isBlurry(sharpness: measures.sharpness, contrast: measures.contrast))
    }

    @Test func smoothGradientIsBlurry() {
        let gradient = image { x, _ in UInt8(x * 255 / (side - 1)) }
        let measures = ImageAnalyzer.measure(gray: gradient, width: side, height: side)
        #expect(ImageSignals.isBlurry(sharpness: measures.sharpness, contrast: measures.contrast))
    }

    @Test func tooSmallImagesMeasureZero() {
        let measures = ImageAnalyzer.measure(gray: [0, 255, 0, 255], width: 2, height: 2)
        #expect(measures.sharpness == 0 && measures.contrast == 0)
    }
}
