import AppKit

// Vector artwork rendered at each macOS icon size. No external artwork or fonts.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func drawIcon(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    let tile = NSBezierPath(roundedRect: NSRect(x: 90, y: 90, width: 844, height: 844), xRadius: 190, yRadius: 190)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    NSColor(red: 0.08, green: 0.12, blue: 0.29, alpha: 1).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colorsAndLocations:
        (NSColor(red: 0.20, green: 0.36, blue: 0.69, alpha: 1), 0),
        (NSColor(red: 0.12, green: 0.19, blue: 0.48, alpha: 1), 0.52),
        (NSColor(red: 0.075, green: 0.095, blue: 0.27, alpha: 1), 1)
    )!.draw(in: tile, angle: -65)
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    NSGradient(starting: NSColor(red: 0.45, green: 0.76, blue: 1, alpha: 0.23), ending: NSColor(red: 0.25, green: 0.48, blue: 1, alpha: 0))!.draw(fromCenter: NSPoint(x: 240, y: 890), radius: 0, toCenter: NSPoint(x: 240, y: 890), radius: 730, options: .drawsAfterEndingLocation)
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.23).setStroke()
    tile.lineWidth = 2
    tile.stroke()

    // Original monogram: a broad, rounded bowl and a decisive diagonal leg.
    // The leg's blue edge is the distinctive 'Right' accent, without extra marks.
    let mark = NSBezierPath()
    mark.windingRule = .evenOdd
    mark.move(to: NSPoint(x: 304, y: 270))
    mark.line(to: NSPoint(x: 304, y: 780))
    mark.line(to: NSPoint(x: 517, y: 780))
    mark.curve(to: NSPoint(x: 715, y: 620), controlPoint1: NSPoint(x: 650, y: 780), controlPoint2: NSPoint(x: 715, y: 723))
    mark.curve(to: NSPoint(x: 608, y: 474), controlPoint1: NSPoint(x: 715, y: 548), controlPoint2: NSPoint(x: 680, y: 501))
    mark.line(to: NSPoint(x: 748, y: 270))
    mark.line(to: NSPoint(x: 612, y: 270))
    mark.line(to: NSPoint(x: 491, y: 456))
    mark.line(to: NSPoint(x: 418, y: 456))
    mark.line(to: NSPoint(x: 418, y: 270))
    mark.close()
    mark.move(to: NSPoint(x: 418, y: 681))
    mark.line(to: NSPoint(x: 514, y: 681))
    mark.curve(to: NSPoint(x: 597, y: 619), controlPoint1: NSPoint(x: 574, y: 681), controlPoint2: NSPoint(x: 597, y: 660))
    mark.curve(to: NSPoint(x: 514, y: 554), controlPoint1: NSPoint(x: 597, y: 576), controlPoint2: NSPoint(x: 574, y: 554))
    mark.line(to: NSPoint(x: 418, y: 554))
    mark.close()

    NSGraphicsContext.saveGraphicsState()
    let depth = NSShadow()
    depth.shadowColor = NSColor(red: 0.02, green: 0.04, blue: 0.15, alpha: 0.55)
    depth.shadowBlurRadius = 36
    depth.shadowOffset = NSSize(width: 0, height: -25)
    depth.set()
    NSColor(red: 0.27, green: 0.40, blue: 0.66, alpha: 1).setFill()
    mark.fill()
    NSGraphicsContext.restoreGraphicsState()
    for step in stride(from: 16, through: 1, by: -1) {
        let edge = mark.copy() as! NSBezierPath
        var transform = AffineTransform()
        transform.translate(x: CGFloat(step) * 0.35, y: -CGFloat(step))
        edge.transform(using: transform)
        NSColor(red: 0.36, green: 0.53, blue: 0.77, alpha: 1).setFill()
        edge.fill()
    }
    NSGradient(colorsAndLocations:
        (NSColor(red: 0.99, green: 1, blue: 1, alpha: 1), 0),
        (NSColor(red: 0.91, green: 0.96, blue: 1, alpha: 1), 0.48),
        (NSColor(red: 0.65, green: 0.79, blue: 0.95, alpha: 1), 1)
    )!.draw(in: mark, angle: -75)

    NSGraphicsContext.saveGraphicsState()
    mark.addClip()
    let leg = NSBezierPath()
    leg.move(to: NSPoint(x: 491, y: 456))
    leg.line(to: NSPoint(x: 608, y: 474))
    leg.line(to: NSPoint(x: 748, y: 270))
    leg.line(to: NSPoint(x: 612, y: 270))
    leg.close()
    NSGradient(starting: NSColor(red: 0.68, green: 0.88, blue: 1, alpha: 0.1), ending: NSColor(red: 0.33, green: 0.68, blue: 1, alpha: 0.95))!.draw(in: leg, angle: -70)
    // A restrained top-light gives the monogram a milled-glass surface.
    NSColor.white.withAlphaComponent(0.62).setStroke()
    mark.lineWidth = 4
    mark.stroke()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try drawIcon(size: points * scale).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
try drawIcon(size: 512).write(to: root.appendingPathComponent("Resources/AppIcon-preview.png"))

func bigEndianLength(_ length: Int) -> Data {
    var value = UInt32(length).bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var payload = Data()
for (type, filename) in [
    ("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"), ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
] {
    let png = try Data(contentsOf: iconset.appendingPathComponent(filename))
    payload.append(Data(type.utf8))
    payload.append(bigEndianLength(png.count + 8))
    payload.append(png)
}
var icon = Data("icns".utf8)
icon.append(bigEndianLength(payload.count + 8))
icon.append(payload)
try icon.write(to: root.appendingPathComponent("Resources/AppIcon.icns"))
