// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Renders the Vzato app icon (green field, white tablet with a check mark) as a 1024 px PNG.
// Usage: swift Scripts/make-app-icon.swift <output.png>

import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// Background
ctx.setFillColor(CGColor(red: 0.118, green: 0.482, blue: 0.275, alpha: 1)) // #1E7B46
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Tablet: a rotated capsule, white with a subtle split line
ctx.saveGState()
ctx.translateBy(x: size / 2, y: size / 2)
ctx.rotate(by: -.pi / 4)
let capsule = CGRect(x: -330, y: -150, width: 660, height: 300)
let path = CGPath(roundedRect: capsule, cornerWidth: 150, cornerHeight: 150, transform: nil)
ctx.addPath(path)
ctx.setFillColor(CGColor(gray: 1, alpha: 1))
ctx.fillPath()
ctx.setStrokeColor(CGColor(red: 0.118, green: 0.482, blue: 0.275, alpha: 0.35))
ctx.setLineWidth(14)
ctx.move(to: CGPoint(x: 0, y: -150)); ctx.addLine(to: CGPoint(x: 0, y: 150)); ctx.strokePath()
ctx.restoreGState()

// Check mark, green, over the tablet
ctx.setStrokeColor(CGColor(red: 0.118, green: 0.482, blue: 0.275, alpha: 1))
ctx.setLineWidth(96)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: 330, y: 520))
ctx.addLine(to: CGPoint(x: 470, y: 380))
ctx.addLine(to: CGPoint(x: 720, y: 660))
ctx.strokePath()

image.unlockFocus()
guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(2) }
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
