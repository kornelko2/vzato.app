// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Puts App Store screenshots on a green background with a headline above them.
// Headlines come from Docs/app-store/screenshot-headlines.tsv (file, language, headline, subline).
// The output keeps the size of the input, so it fits the same App Store display type.
//
//   swift Scripts/frame-screenshots.swift <headlines.tsv> <input folder>/<lang>/*.png → <output folder>
//   swift Scripts/frame-screenshots.swift Docs/app-store/screenshot-headlines.tsv shots/iphone framed/iphone
import AppKit

let args = CommandLine.arguments
guard args.count == 4 else { print("usage: frame-screenshots.swift <tsv> <in> <out>"); exit(1) }
let (tsv, input, output) = (args[1], args[2], args[3])

var headlines: [String: (String, String)] = [:]
for line in try! String(contentsOfFile: tsv, encoding: .utf8).split(separator: "\n") where !line.hasPrefix("#") {
    let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
    guard f.count >= 3 else { continue }
    headlines["\(f[1])/\(f[0])"] = (f[2], f.count > 3 ? f[3] : "")
}

let top = NSColor(srgbRed: 0x23 / 255, green: 0x8a / 255, blue: 0x50 / 255, alpha: 1)
let bottom = NSColor(srgbRed: 0x14 / 255, green: 0x5a / 255, blue: 0x33 / 255, alpha: 1)

func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    return NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size) ?? base
}

func frame(_ shot: NSImage, pixels: NSSize, headline: String, subline: String) -> Data {
    let w = pixels.width, h = pixels.height
    let landscape = w > h
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w), pixelsHigh: Int(h), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = pixels
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGradient(starting: top, ending: bottom)!.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)

    // Headline block at the top.
    let margin = w * (landscape ? 0.08 : 0.07)
    let headSize = landscape ? h * 0.058 : min(w * 0.074, h * 0.04)
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineBreakMode = .byWordWrapping
    let text = NSMutableAttributedString(string: headline, attributes: [
        .font: rounded(headSize, .heavy), .foregroundColor: NSColor.white, .paragraphStyle: style])
    if !subline.isEmpty {
        text.append(NSAttributedString(string: "\n" + subline, attributes: [
            .font: rounded(headSize * 0.52, .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85), .paragraphStyle: style]))
    }
    // A fixed band for the text, so every screenshot of a set sits at the same height.
    let textWidth = w - 2 * margin
    let textHeight = text.boundingRect(with: NSSize(width: textWidth, height: h), options: [.usesLineFragmentOrigin]).height
    let band = h * (landscape ? 0.20 : 0.165)
    text.draw(with: NSRect(x: margin, y: h - band / 2 - textHeight / 2 - h * 0.008, width: textWidth, height: textHeight),
              options: [.usesLineFragmentOrigin])

    // The screenshot below, scaled down, running off the bottom edge.
    let scale: CGFloat = landscape ? 0.80 : 0.84
    let sw = w * scale, sh = h * scale
    let rect = NSRect(x: (w - sw) / 2, y: h - band - sh, width: sw, height: sh)
    let radius = (landscape ? 0.012 : 0.05) * sw
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = w * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -w * 0.006)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    shot.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
for lang in try! fm.contentsOfDirectory(atPath: input).sorted() where !lang.hasPrefix(".") {
    let dir = "\(input)/\(lang)"
    try? fm.createDirectory(atPath: "\(output)/\(lang)", withIntermediateDirectories: true)
    for file in try! fm.contentsOfDirectory(atPath: dir).sorted() where file.hasSuffix(".png") {
        let name = String(file.dropLast(4))
        guard let (headline, subline) = headlines["\(lang)/\(name)"],
              let image = NSImage(contentsOfFile: "\(dir)/\(file)"),
              let bitmap = image.representations.first as? NSBitmapImageRep else {
            print("skipped \(lang)/\(file): no headline"); continue
        }
        let pixels = NSSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        try! frame(image, pixels: pixels, headline: headline, subline: subline).write(to: URL(fileURLWithPath: "\(output)/\(lang)/\(file)"))
    }
    print("\(lang) framed")
}
