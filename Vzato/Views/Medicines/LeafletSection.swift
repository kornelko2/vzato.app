// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import PDFKit
import SwiftUI

/// The official package leaflet for a medication added from the medicines database.
struct LeafletSection: View {
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var medication: Medication
    @State private var downloading = false
    @State private var failure: LeafletService.Failure?
    /// Owned by the screen, not this section: a sheet on a list section closes when the list redraws.
    @Binding var showing: Bool

    var body: some View {
        if let source = medication.registrySource, let code = medication.registryCode, !code.isEmpty {
            Section {
                if medication.leafletData != nil {
                    Button {
                        showing = true
                    } label: {
                        Label("Open package leaflet", systemImage: "doc.text")
                    }
                    .accessibilityIdentifier("openLeaflet")
                    Button {
                        Task { await download(source: source, code: code) }
                    } label: {
                        Label("Download again", systemImage: "arrow.clockwise")
                    }
                    .disabled(downloading)
                } else if LeafletService.downloadURL(source: source, code: code) != nil {
                    Button {
                        Task { await download(source: source, code: code) }
                    } label: {
                        HStack {
                            Label("Download package leaflet", systemImage: "arrow.down.doc")
                            if downloading {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(downloading)
                    .accessibilityIdentifier("downloadLeaflet")
                } else if let url = LeafletService.webURL(source: source, code: code) {
                    Link(destination: url) {
                        Label("Leaflet on sukl.sk", systemImage: "safari")
                    }
                }
                if let failure {
                    Text(message(for: failure)).font(.footnote).foregroundStyle(Palette.missed)
                }
            } header: {
                Text("Package leaflet")
            } footer: {
                if source == .cz {
                    Text("Downloads the official leaflet from SÚKL. Only the medicine code is sent. The leaflet is kept with the medication.")
                } else {
                    Text("Opens the medicine on the ŠÚKL website, where you can open its leaflet.")
                }
            }
        }
    }

    private func message(for failure: LeafletService.Failure) -> LocalizedStringKey {
        switch failure {
        case .notAvailable: "SÚKL has no leaflet for this medicine."
        case .network: "Could not connect. Check the internet connection and try again."
        case .notPDF: "SÚKL did not send a leaflet. Try again later."
        }
    }

    private func download(source: MedicineSource, code: String) async {
        downloading = true
        failure = nil
        defer { downloading = false }
        do {
            let data = try await LeafletService.download(source: source, code: code)
            medication.leafletData = data
            medication.leafletFetchedAt = Date()
            try? context.save()
            showing = true
        } catch let error as LeafletService.Failure {
            failure = error
        } catch {
            failure = .network
        }
    }
}

/// The downloaded leaflet, full screen.
struct LeafletViewer: View {
    @ObservedObject var medication: Medication
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let data = medication.leafletData {
                    PDFKitView(data: data).ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle(Text("Package leaflet"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 700)
        #endif
    }
}

#if os(iOS)
struct PDFKitView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(data: data)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {}
}
#else
struct PDFKitView: NSViewRepresentable {
    let data: Data
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(data: data)
        return view
    }
    func updateNSView(_ view: PDFView, context: Context) {}
}
#endif
