import ImageIO
import Testing

@testable import SlothRoll

struct ImageSourceTests {
    @Test func screenshotFlagWins() {
        let iPhone: [CFString: Any] = [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Apple"]]
        #expect(ImageSource(isScreenshot: true, properties: iPhone) == .screenshot)
    }

    @Test func cameraMakeOrLensMeansCamera() {
        let make: [CFString: Any] = [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Apple"]]
        let lens: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifLensModel: "iPhone 17 Pro back camera"]
        ]
        #expect(ImageSource(isScreenshot: false, properties: make) == .camera)
        #expect(ImageSource(isScreenshot: false, properties: lens) == .camera)
    }

    @Test func strippedMetadataMeansSaved() {
        // What a WhatsApp flyer looks like: pixel size and color info, no camera fields.
        let whatsApp: [CFString: Any] = [
            kCGImagePropertyPixelWidth: 1080,
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifColorSpace: 1],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "  "],
        ]
        #expect(ImageSource(isScreenshot: false, properties: whatsApp) == .saved)
        #expect(ImageSource(isScreenshot: false, properties: nil) == .saved)
    }
}
