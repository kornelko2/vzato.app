// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// The official package leaflet for a medicine picked from the register. Runs only when the person
/// taps the button; the request carries the medicine code and nothing else.
enum LeafletService {
    enum Failure: Error, Equatable {
        case notAvailable, network, notPDF
    }

    /// SÚKL serves the leaflet PDF by code. ŠÚKL has no such interface; the app opens its search page.
    static func downloadURL(source: MedicineSource, code: String) -> URL? {
        guard source == .cz, !code.isEmpty,
              let escaped = code.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return URL(string: "https://prehledy.sukl.gov.cz/dlp/v1/dokumenty/\(escaped)/pil")
    }

    /// ŠÚKL's search for the code; the medicine's page there lists its leaflets.
    static func webURL(source: MedicineSource, code: String) -> URL? {
        guard source == .sk, let escaped = code.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return URL(string: "https://www.sukl.sk/vysledky-vyhladavania?search=\(escaped)")
    }

    /// SÚKL sends "application/octet-stream"; check the bytes instead of the content type.
    static func isPDF(_ data: Data) -> Bool {
        data.starts(with: Array("%PDF".utf8))
    }

    static func download(source: MedicineSource, code: String, session: URLSession = .shared) async throws -> Data {
        guard let url = downloadURL(source: source, code: code) else { throw Failure.notAvailable }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("application/pdf, application/octet-stream", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Failure.network
        }
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { throw Failure.notAvailable }
        guard isPDF(data) else { throw Failure.notPDF }
        return data
    }
}
