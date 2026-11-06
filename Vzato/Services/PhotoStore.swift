// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Image handling without UIKit/AppKit so it works the same on every platform:
/// downscaling on import, JPEG encoding, thumbnails with a cache.
enum PhotoStore {
    /// Longest side of a stored photo, in pixels.
    static let maxPixelSize = 2000
    static let jpegQuality: CGFloat = 0.8

    // MARK: Encoding

    /// Re-encodes any image data as a JPEG no larger than `maxPixelSize` on its longest side,
    /// honoring EXIF orientation. Returns nil when the data is not an image.
    nonisolated static func downscaledJPEG(from data: Data, maxPixelSize: Int = maxPixelSize, quality: CGFloat = jpegQuality) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return jpegData(from: image, quality: quality)
    }

    nonisolated static func jpegData(from image: CGImage, quality: CGFloat = jpegQuality) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// Decodes image data, optionally limited to `maxPixelSize` on the longest side (fast for thumbnails).
    nonisolated static func image(from data: Data, maxPixelSize: Int? = nil) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        if let maxPixelSize {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    nonisolated static func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return CGSize(width: width, height: height)
    }

    // MARK: Storage

    /// Adds one photo (downscaled) to a medication. Leaflet pages get the next page index.
    @MainActor
    @discardableResult
    static func add(_ data: Data, kind: PhotoKind, to medication: Medication, context: NSManagedObjectContext) -> MedicationPhoto? {
        guard let jpeg = downscaledJPEG(from: data) else { return nil }
        let photo = MedicationPhoto(context: context)
        photo.kind = kind
        photo.imageData = jpeg
        photo.pageIndex = (medication.photos(of: kind).map(\.pageIndex).max() ?? -1) + 1
        photo.medication = medication
        save(context)
        return photo
    }

    /// Adds several images in order (scanner pages, multi-selection).
    @MainActor
    @discardableResult
    static func add(_ datas: [Data], kind: PhotoKind, to medication: Medication, context: NSManagedObjectContext) -> [MedicationPhoto] {
        datas.compactMap { add($0, kind: kind, to: medication, context: context) }
    }

    /// Deletes a photo and closes the gap in page numbering of its kind.
    @MainActor
    static func delete(_ photo: MedicationPhoto, context: NSManagedObjectContext) {
        let medication = photo.medication
        let kind = photo.kind
        ThumbnailCache.shared.remove(photo)
        context.delete(photo)
        if let medication {
            for (index, remaining) in medication.photos(of: kind).filter({ $0 != photo }).enumerated() {
                remaining.pageIndex = index
            }
        }
        save(context)
    }

    @MainActor
    private static func save(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do { try context.save() } catch {
            context.rollback()
            assertionFailure("Save failed: \(error)")
        }
    }
}

/// Decoded thumbnails keyed by photo and size, so lists do not decode JPEGs on every redraw.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, CGImage>()

    private init() {
        cache.countLimit = 200
    }

    func image(for photo: MedicationPhoto, pixelSize: Int) -> CGImage? {
        let key = "\(photo.id?.uuidString ?? photo.objectID.uriRepresentation().absoluteString)|\(pixelSize)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = photo.imageData, let image = PhotoStore.image(from: data, maxPixelSize: pixelSize) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func remove(_ photo: MedicationPhoto) {
        // NSCache has no prefix removal; entries for a deleted photo simply age out.
        _ = photo
    }
}
