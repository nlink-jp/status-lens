// Generates assets/AppIcon-1024.png: a dark rounded plate with a magnifying
// lens (the -lens family motif) holding a green status checkmark.
// Run from the project root: swift scripts/gen-icon.swift
import AppKit

let size = 1024

guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("could not create CGContext")
}

// Dark rounded plate on transparent background (macOS icon grid margins).
let plateRect = CGRect(x: 64, y: 64, width: 896, height: 896)
let plate = CGPath(roundedRect: plateRect, cornerWidth: 200, cornerHeight: 200, transform: nil)
context.addPath(plate)
context.setFillColor(CGColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1))
context.fillPath()

// Lens ring, slightly up-left of center.
let lensCenter = CGPoint(x: 470, y: 580)
let lensRadius: CGFloat = 250
context.setStrokeColor(CGColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1))
context.setLineWidth(60)
context.addArc(center: lensCenter, radius: lensRadius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
context.strokePath()

// Handle toward the bottom-right corner.
let handleAngle: CGFloat = -.pi / 4
let handleStart = CGPoint(
    x: lensCenter.x + cos(handleAngle) * (lensRadius + 26),
    y: lensCenter.y + sin(handleAngle) * (lensRadius + 26)
)
let handleEnd = CGPoint(
    x: lensCenter.x + cos(handleAngle) * (lensRadius + 250),
    y: lensCenter.y + sin(handleAngle) * (lensRadius + 250)
)
context.setLineCap(.round)
context.setLineWidth(96)
context.move(to: handleStart)
context.addLine(to: handleEnd)
context.strokePath()

// Green checkmark inside the lens.
context.setStrokeColor(CGColor(red: 0.24, green: 0.78, blue: 0.35, alpha: 1))
context.setLineWidth(80)
context.setLineJoin(.round)
context.setLineCap(.round)
context.move(to: CGPoint(x: 350, y: 600))
context.addLine(to: CGPoint(x: 445, y: 490))
context.addLine(to: CGPoint(x: 600, y: 700))
context.strokePath()

guard let image = context.makeImage() else {
    fatalError("could not render image")
}
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not encode PNG")
}
let outputURL = URL(fileURLWithPath: "assets/AppIcon-1024.png")
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL)
print("wrote \(outputURL.path)")
