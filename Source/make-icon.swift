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

        // 브랜드 A안: 실버·캔버스 중립 타일 (#ECEEF1 ~ #FCFCFD) + 테두리 (#D9DDE1)
        let tileRect = NSRect(x: 70, y: 70, width: 884, height: 884)
        let tile = NSBezierPath(roundedRect: tileRect, xRadius: 205, yRadius: 205)
        let gradient = NSGradient(
            starting: NSColor(srgbRed: 0.925, green: 0.933, blue: 0.945, alpha: 1),
            ending: NSColor(srgbRed: 0.988, green: 0.988, blue: 0.992, alpha: 1)
        )!
        gradient.draw(in: tile, angle: 90)
        NSColor(srgbRed: 0.851, green: 0.867, blue: 0.882, alpha: 1).setStroke()
        tile.lineWidth = 14
        tile.stroke()

        // 흑연색(#202124) 화면 윤곽 및 하단 받침선
        let graphite = NSColor(srgbRed: 0.125, green: 0.129, blue: 0.141, alpha: 1)
        graphite.setStroke()

        let screen = NSBezierPath(roundedRect: NSRect(x: 288, y: 392, width: 448, height: 308), xRadius: 42, yRadius: 42)
        screen.lineWidth = 42
        screen.lineJoinStyle = .round
        screen.stroke()

        let base = NSBezierPath()
        base.move(to: NSPoint(x: 232, y: 316))
        base.line(to: NSPoint(x: 792, y: 316))
        base.lineWidth = 50
        base.lineCapStyle = .round
        base.stroke()

        // 중앙 초록 상태점 (#237A4B)
        let activeGreen = NSColor(srgbRed: 0.137, green: 0.478, blue: 0.294, alpha: 1)
        activeGreen.setFill()
        NSBezierPath(ovalIn: NSRect(x: 512 - 63, y: 546 - 63, width: 126, height: 126)).fill()

        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let url = URL(fileURLWithPath: folder).appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try rep.representation(using: .png, properties: [:])!.write(to: url)
    }
}
