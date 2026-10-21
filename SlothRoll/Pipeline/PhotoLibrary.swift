import CoreGraphics
import Foundation
import ImageIO
import Photos

/// Live PhotoKit implementation of `PhotoLibraryProviding`. Never downloads from iCloud.
struct PhotoLibrary: PhotoLibraryProviding {
    func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    func assetIDs(inAlbum title: String) async throws(PipelineError) -> [String] {
        let albumOptions = PHFetchOptions()
        albumOptions.predicate = NSPredicate(format: "localizedTitle == %@", title)
        let albums = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: albumOptions)
        guard let album = albums.firstObject else { throw .albumNotFound(title) }

        let assetOptions = PHFetchOptions()
        assetOptions.predicate = NSPredicate(
            format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        assetOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let assets = PHAsset.fetchAssets(in: album, options: assetOptions)

        var ids: [String] = []
        assets.enumerateObjects { asset, _, _ in ids.append(asset.localIdentifier) }
        return ids
    }

    func loadImage(assetID: String) async -> LibraryImage? {
        guard
            let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
                .firstObject,
            let data = await Self.imageData(for: asset),
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: PipelineConfig.thumbnailMaxPixels,
        ]
        let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source, 0, thumbnailOptions as CFDictionary)
        return LibraryImage(assetID: assetID, image: image, thumbnail: thumbnail)
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
