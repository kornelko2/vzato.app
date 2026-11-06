// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreGraphics
import Foundation
import Testing
@testable import Vzato

@MainActor
struct PhotoStoreTests {
    /// A solid-color JPEG of the given size.
    private func sampleJPEG(width: Int, height: Int) -> Data {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.3, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return PhotoStore.jpegData(from: context.makeImage()!, quality: 0.9)!
    }

    @Test func downscalesLongestSideAndKeepsAspect() {
        let big = sampleJPEG(width: 4000, height: 3000)
        let small = PhotoStore.downscaledJPEG(from: big, maxPixelSize: 2000)
        #expect(small != nil)
        let size = PhotoStore.pixelSize(of: small!)
        #expect(size == CGSize(width: 2000, height: 1500))
        #expect(small!.count < big.count)
    }

    @Test func smallImagesAreNotEnlarged() {
        let tiny = sampleJPEG(width: 300, height: 200)
        let result = PhotoStore.downscaledJPEG(from: tiny, maxPixelSize: 2000)
        #expect(PhotoStore.pixelSize(of: result!) == CGSize(width: 300, height: 200))
    }

    @Test func rejectsNonImageData() {
        #expect(PhotoStore.downscaledJPEG(from: Data("not an image".utf8)) == nil)
    }

    @Test func leafletPagesAreNumberedAndRenumberedAfterDelete() {
        let store = TestStore()
        let medication = store.medication()
        let pages = PhotoStore.add([sampleJPEG(width: 100, height: 100), sampleJPEG(width: 100, height: 100), sampleJPEG(width: 100, height: 100)],
                                   kind: .leaflet, to: medication, context: store.context)
        #expect(pages.map(\.pageIndex) == [0, 1, 2])
        #expect(medication.photos(of: .leaflet).count == 3)
        #expect(medication.photos(of: .pill).isEmpty)

        PhotoStore.delete(pages[1], context: store.context)
        #expect(medication.photos(of: .leaflet).map(\.pageIndex) == [0, 1])
    }

    @Test func deletingMedicationDeletesPhotos() throws {
        let store = TestStore()
        let medication = store.medication()
        PhotoStore.add(sampleJPEG(width: 50, height: 50), kind: .pill, to: medication, context: store.context)
        store.context.delete(medication)
        try store.context.save()
        let count = try store.context.count(for: MedicationPhoto.fetchRequest())
        #expect(count == 0)
    }
}
