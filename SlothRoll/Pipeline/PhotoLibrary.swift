import CoreGraphics
import Foundation
import ImageIO
import Photos
import UIKit

/// Live PhotoKit implementation of `PhotoLibraryProviding`. Never downloads from iCloud, and
/// never deletes permanently: deleted assets go to Recently Deleted.
struct PhotoLibrary: PhotoLibraryProviding {
    func requestAccess() async -> PhotoAccess {
        switch await PHPhotoLibrary.requestAuthorization(for: .readWrite) {
        case .authorized: .full
        case .limited: .limited
        default: .denied
        }
    }

    func recentImageIDs(limit: Int) async -> [String] {
        let options = PHFetchOptions()
        options.predicate = Self.imagesOnly
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        // With limited access PhotoKit returns only the photos the user picked.
        return Self.identifiers(of: PHAsset.fetchAssets(with: options))
    }

    func assetIDs(inAlbum title: String) async throws(PipelineError) -> [String] {
        let albumOptions = PHFetchOptions()
        albumOptions.predicate = NSPredicate(format: "localizedTitle == %@", title)
        let albums = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: albumOptions)
        guard let album = albums.firstObject else { throw .albumNotFound(title) }

        let assetOptions = PHFetchOptions()
        // Every image, camera photos included: a photo of a flyer is as useful as a screenshot.
        assetOptions.predicate = Self.imagesOnly
        assetOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        return Self.identifiers(of: PHAsset.fetchAssets(in: album, options: assetOptions))
    }

    /// Reads the original file once: its metadata decides the `ImageSource`, and ImageIO
    /// decodes straight to the downscaled sizes, so the full-size bitmap is never in memory.
    func loadImage(assetID: String) async -> LibraryImage? {
        guard
            let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
                .firstObject,
            let data = await Self.imageData(for: asset),
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = Self.downscaled(source, maxPixels: PipelineConfig.modelImageMaxPixels)
        else { return nil }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let origin = ImageSource(
            isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot), properties: properties)
        return LibraryImage(
            assetID: assetID, image: image,
            thumbnail: Self.downscaled(source, maxPixels: PipelineConfig.thumbnailMaxPixels),
            capturedAt: asset.creationDate, source: origin)
    }

    /// Asks Photos for a resized image instead of decoding the original, which is cheaper
    /// for a card than `loadImage`.
    func loadPreview(assetID: String, maxPixels: Int) async -> CGImage? {
        guard
            let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
                .firstObject
        else { return nil }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        let size = CGSize(width: maxPixels, height: maxPixels)
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset, targetSize: size, contentMode: .aspectFit, options: options
            ) { image, _ in
                continuation.resume(returning: image?.cgImage)
            }
        }
    }

    /// `PHAssetChangeRequest.deleteAssets` makes iOS ask the user first; the assets then sit
    /// in Recently Deleted for 30 days.
    func deleteAssets(ids: [String]) async throws(PipelineError) -> Bool {
        guard PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).count > 0 else {
            return true
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(
                    PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil))
            }
            return true
        } catch let error as PHPhotosError where error.code == .userCancelled {
            return false
        } catch {
            Log.pipeline.error("delete_failed error=\(String(describing: error), privacy: .public)")
            throw .deleteFailed
        }
    }

    // MARK: - Private

    private static var imagesOnly: NSPredicate {
        NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
    }

    private static func identifiers(of assets: PHFetchResult<PHAsset>) -> [String] {
        var ids: [String] = []
        ids.reserveCapacity(assets.count)
        assets.enumerateObjects { asset, _, _ in ids.append(asset.localIdentifier) }
        return ids
    }

    /// Never upscales: an image already under `maxPixels` comes back at its own size.
    private static func downscaled(_ source: CGImageSource, maxPixels: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func imageData(for asset: PHAsset) async -> Data? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.version = .current
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) {
                data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
