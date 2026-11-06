// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import PhotosUI
import SwiftUI

/// The "Photos" section of a medication: package, pill and leaflet, each with its own add menu.
struct MedicationPhotosSection: View {
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var medication: Medication

    @State private var pickerKind: PhotoKind?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var cameraKind: PhotoKind?
    @State private var showingScanner = false
    @State private var importKind: PhotoKind?
    @State private var viewerKind: PhotoKind?

    var body: some View {
        Section {
            if medication.photoList.isEmpty {
                Text("No photos yet. Add the package, the pill or the leaflet so you always have them at hand.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(PhotoKind.allCases) { kind in
                row(for: kind)
            }
        } header: {
            Text("Photos")
        }
        .photosPicker(isPresented: Binding(get: { pickerKind != nil }, set: { if !$0 { pickerKind = nil } }),
                      selection: $pickerItems, maxSelectionCount: pickerKind?.maxSelection ?? 1, matching: .images)
        .onChange(of: pickerItems) { _, items in
            guard let kind = pickerKind, !items.isEmpty else { return }
            Task { await importPicked(items, kind: kind) }
        }
        #if os(iOS)
        .fullScreenCover(item: $cameraKind) { kind in
            CameraPicker { data in
                PhotoStore.add(data, kind: kind, to: medication, context: context)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingScanner) {
            DocumentScannerView { pages in
                PhotoStore.add(pages, kind: .leaflet, to: medication, context: context)
            }
            .ignoresSafeArea()
        }
        #endif
        .fileImporter(isPresented: Binding(get: { importKind != nil }, set: { if !$0 { importKind = nil } }),
                      allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            guard let kind = importKind, case .success(let urls) = result else { return }
            let datas: [Data] = urls.compactMap { url in
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                return try? Data(contentsOf: url)
            }
            PhotoStore.add(datas, kind: kind, to: medication, context: context)
        }
        .photoViewer(isPresented: Binding(get: { viewerKind != nil }, set: { if !$0 { viewerKind = nil } }),
                     photos: viewerKind.map { medication.photos(of: $0) } ?? [],
                     title: Text(viewerKind?.label ?? PhotoKind.package.label))
    }

    @ViewBuilder
    private func row(for kind: PhotoKind) -> some View {
        let photos = medication.photos(of: kind)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(kind.label, systemImage: kind.symbolName)
                Spacer()
                addMenu(for: kind)
            }
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos) { photo in
                            Button {
                                viewerKind = kind
                            } label: {
                                PhotoThumbnail(photo: photo, size: 72)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(kind == .leaflet ? Text("Page \(photo.pageIndex + 1)") : Text(kind.label))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func addMenu(for kind: PhotoKind) -> some View {
        Menu {
            #if os(iOS)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { cameraKind = kind } label: { Label("Take photo", systemImage: "camera") }
            }
            if kind == .leaflet, DocumentScannerView.isSupported {
                Button { showingScanner = true } label: { Label("Scan leaflet", systemImage: "doc.viewfinder") }
            }
            #endif
            Button {
                pickerItems = []
                pickerKind = kind
            } label: {
                Label("Choose from library", systemImage: "photo.on.rectangle")
            }
            Button { importKind = kind } label: { Label("Import file", systemImage: "folder") }
        } label: {
            Label("Add photo", systemImage: "plus.circle")
                .labelStyle(.iconOnly)
                .font(.title3)
        }
        .accessibilityLabel(Text("Add photo"))
    }

    private func importPicked(_ items: [PhotosPickerItem], kind: PhotoKind) async {
        var datas: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                datas.append(data)
            }
        }
        PhotoStore.add(datas, kind: kind, to: medication, context: context)
        pickerItems = []
        pickerKind = nil
    }
}
