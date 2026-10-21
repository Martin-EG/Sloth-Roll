import Foundation

/// Tunables for the scan pipeline (prompting, retries, parsing, triage, library limits).
enum PipelineConfig {
    /// First try plus one stricter retry.
    static let maxExtractionAttempts = 2

    /// Title of the safe result returned when the model's answer can't be used.
    static let fallbackTitle = "Couldn't read this one"

    /// Days after today listed in the prompt so a small model can look up relative dates.
    static let promptCalendarDays = 7

    /// Triage: an image needs at least this many recognized characters (no spaces) to go to
    /// the model. Day-2 eval: 20 dropped 3 of 6 junk images and no real action (shortest: 40).
    static let triageMinTextCharacters = 20

    /// Longest side, in pixels, of thumbnails decoded from the photo library.
    static let thumbnailMaxPixels = 240

    /// Longest side, in pixels, of the image handed to OCR and the model.
    static let modelImageMaxPixels = 1024

    /// New images (screenshots and saved images) triaged per scan, unless Settings says otherwise.
    static let scanLimit = 50

    /// Choices for the per-scan limit in Settings.
    static let scanLimitOptions = [25, 50, 100]

    /// Newest library images looked at per scan; already-seen and camera photos are skipped
    /// inside this window, so it bounds the work when the library is mostly camera photos.
    static let libraryScanWindow = 500

    // MARK: Cleanup

    /// Longest side, in pixels, of the grayscale copy the blur score is measured on.
    static let blurImageMaxPixels = 512

    /// Laplacian variance (0-255 grayscale) below this counts as blurry. Text screenshots
    /// score in the thousands; tune with the `analyze sharpness=` debug log on device.
    static let blurSharpnessThreshold = 50.0

    /// Pixel standard deviation below this is a flat image (blank screen), not a blurry one.
    static let flatContrastThreshold = 8.0

    /// Euclidean distance between revision-2 feature prints under which two screenshots are
    /// near-duplicates. Kept low on purpose: a false match offers a real screenshot for deletion.
    static let duplicateDistanceThreshold: Float = 0.25
}
