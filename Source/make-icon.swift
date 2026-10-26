import AppKit
let folder = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let tile = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 205, yRadius: 205)
        let gradient = NSGradient(starting: NSColor(calibratedRed: 0.10, green: 0.20, blue: 0.39, alpha: 1),
            ending: NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.18, alpha: 1))!
        gradient.draw(in: tile, angle: 70)
        NSColor(calibratedRed: 0.88, green: 0.94, blue: 1, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 233, y: 283, width: 558, height: 366), xRadius: 34, yRadius: 34).fill()
        NSColor(calibratedRed: 0.10, green: 0.23, blue: 0.34, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 255, y: 305, width: 514, height: 321), xRadius: 17, yRadius: 17).fill()
        NSColor(calibratedRed: 0.90, green: 0.95, blue: 1, alpha: 1).setFill()
        let base = NSBezierPath()
        base.move(to: NSPoint(x: 186, y: 275)); base.line(to: NSPoint(x: 838, y: 275))
        base.curve(to: NSPoint(x: 788, y: 231), controlPoint1: NSPoint(x: 838, y: 242), controlPoint2: NSPoint(x: 814, y: 231))
        base.line(to: NSPoint(x: 236, y: 231))
        base.curve(to: NSPoint(x: 186, y: 275), controlPoint1: NSPoint(x: 210, y: 231), controlPoint2: NSPoint(x: 186, y: 242))
        base.close(); base.fill()
        let mint = NSColor(calibratedRed: 0.29, green: 0.94, blue: 0.75, alpha: 1)
        mint.setStroke(); mint.setFill()
        for radius: CGFloat in [92, 154, 216] {
            let wave = NSBezierPath()
            wave.appendArc(withCenter: NSPoint(x: 512, y: 508), radius: radius, startAngle: 45, endAngle: 135)
            wave.lineWidth = 25; wave.lineCapStyle = .round; wave.stroke()
        }
        NSBezierPath(ovalIn: NSRect(x: 492, y: 504, width: 40, height: 40)).fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let url = URL(fileURLWithPath: folder).appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try rep.representation(using: .png, properties: [:])!.write(to: url)
    }
}
