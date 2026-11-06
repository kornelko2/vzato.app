// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI

/// A square thumbnail of one photo, decoded once through the cache.
struct PhotoThumbnail: View {
    @ObservedObject var photo: MedicationPhoto
    var size: CGFloat = 88

    var body: some View {
        Group {
            if let image = ThumbnailCache.shared.image(for: photo, pixelSize: Int(size * 3)) {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
    }
}

/// Full-size, zoomable image.
struct ZoomableImage: View {
    @ObservedObject var photo: MedicationPhoto
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                Group {
                    if let data = photo.imageData, let image = PhotoStore.image(from: data) {
                        Image(decorative: image, scale: 1, orientation: .up)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Text("Could not read the image.").foregroundStyle(.secondary)
                    }
                }
                .frame(width: proxy.size.width * scale, height: proxy.size.height * scale)
            }
            .gesture(
                MagnifyGesture()
                    .onChanged { value in scale = min(max(lastScale * value.magnification, 1), 5) }
                    .onEnded { _ in lastScale = scale }
            )
            .onTapGesture(count: 2) {
                withAnimation { scale = scale > 1 ? 1 : 2.5; lastScale = scale }
            }
        }
        .background(.black)
    }
}

/// Pages through the photos of one kind; delete from here.
struct PhotoViewerView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    let photos: [MedicationPhoto]
    let title: Text
    @State private var selection: MedicationPhoto?
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Group {
                if photos.isEmpty {
                    ContentUnavailableView { Label("Photos", systemImage: "photo") }
                } else {
                    #if os(iOS)
                    TabView(selection: $selection) {
                        ForEach(photos) { photo in
                            ZoomableImage(photo: photo).tag(Optional(photo))
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
                    #else
                    VStack(spacing: 8) {
                        if let selection {
                            ZoomableImage(photo: selection)
                        }
                        if photos.count > 1 {
                            Picker("Page", selection: $selection) {
                                ForEach(Array(photos.enumerated()), id: \.element) { index, photo in
                                    Text("Page \(index + 1)").tag(Optional(photo))
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .padding(.horizontal)
                        }
                    }
                    #endif
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete photo", systemImage: "trash")
                    }
                    .disabled(selection == nil)
                }
            }
            .confirmationDialog("Delete photo", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let selection {
                        PhotoStore.delete(selection, context: context)
                    }
                    dismiss()
                }
            }
            .onAppear { if selection == nil { selection = photos.first } }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 560)
        #endif
    }
}

extension View {
    /// Full screen on iPhone/iPad, a sheet on the Mac.
    func photoViewer(isPresented: Binding<Bool>, photos: [MedicationPhoto], title: Text) -> some View {
        #if os(iOS)
        return fullScreenCover(isPresented: isPresented) {
            PhotoViewerView(photos: photos, title: title)
        }
        #else
        return sheet(isPresented: isPresented) {
            PhotoViewerView(photos: photos, title: title)
        }
        #endif
    }
}
