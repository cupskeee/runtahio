#!/usr/bin/env swift
//
// generate-icon.swift — renders Runtahio's original "bloom" app icon into an .iconset.
// Run: swift Scripts/generate-icon.swift
//
// Draws a calm radial sunburst (echoing the Runtah Map) on a soft teal squircle — an
// original mark, not derived from any other app's icon.

import AppKit

let outputDir = "Sources/Runtahio/Resources/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

// Cool "bloom" palette hues (0...1), matching the in-app Runtah Map.
let hues: [CGFloat] = [0.55, 0.45, 0.62, 0.58, 0.78, 0.50]

func draw(_ ctx: CGContext, _ s: CGFloat) {
    // Background squircle with a soft vertical gradient.
    let inset = s * 0.035
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let squircle = CGPath(roundedRect: rect, cornerWidth: s * 0.224, cornerHeight: s * 0.224, transform: nil)
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let top = NSColor(hue: 0.55, saturation: 0.45, brightness: 0.30, alpha: 1).cgColor
    let bottom = NSColor(hue: 0.60, saturation: 0.55, brightness: 0.16, alpha: 1).cgColor
    if let grad = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])
    }
    ctx.restoreGState()

    // Radial bloom.
    let center = CGPoint(x: s / 2, y: s / 2)
    func wedge(_ rInner: CGFloat, _ rOuter: CGFloat, _ a0: CGFloat, _ a1: CGFloat, _ color: NSColor) {
        ctx.beginPath()
        ctx.addArc(center: center, radius: rOuter, startAngle: a0, endAngle: a1, clockwise: false)
        ctx.addArc(center: center, radius: rInner, startAngle: a1, endAngle: a0, clockwise: true)
        ctx.closePath()
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
    }

    let rings: [(inner: CGFloat, outer: CGFloat, count: Int, brightness: CGFloat)] = [
        (0.115, 0.235, 6, 0.78),
        (0.245, 0.375, 10, 0.66),
    ]
    let gap = CGFloat.pi / 140
    for ring in rings {
        let rInner = s * ring.inner
        let rOuter = s * ring.outer
        let step = (.pi * 2) / CGFloat(ring.count)
        for i in 0..<ring.count {
            let a0 = step * CGFloat(i) + gap
            let a1 = step * CGFloat(i + 1) - gap
            let hue = hues[i % hues.count]
            let color = NSColor(hue: hue, saturation: 0.42, brightness: ring.brightness, alpha: 1)
            wedge(rInner, rOuter, a0, a1, color)
        }
    }

    // Center disk.
    let rDisk = s * 0.095
    ctx.setFillColor(NSColor(hue: 0.55, saturation: 0.10, brightness: 0.96, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - rDisk, y: center.y - rDisk, width: rDisk * 2, height: rDisk * 2))
}

func render(px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    draw(gctx.cgContext, CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// (filename, pixel size) for a standard macOS .iconset.
let outputs: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

var cache: [Int: Data] = [:]
for (name, px) in outputs {
    let data = cache[px] ?? render(px: px)
    cache[px] = data
    let path = "\(outputDir)/\(name).png"
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}
print("Done. Run ./Scripts/make-app.sh to bundle the icon.")
