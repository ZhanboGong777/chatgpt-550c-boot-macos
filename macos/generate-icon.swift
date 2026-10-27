import AppKit

// Original geometric typography for this macOS port; no OpenAI image assets.
guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-icon <output.iconset>\n", stderr)
    exit(1)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func drawIcon(size: Int, name: String) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else { exit(1) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    let s = CGFloat(size)
    let amber = NSColor(calibratedRed: 0.96, green: 0.66, blue: 0.16, alpha: 1)
    let background = NSRect(x: s * 0.065, y: s * 0.065, width: s * 0.87, height: s * 0.87)
    NSColor(calibratedRed: 0.035, green: 0.028, blue: 0.02, alpha: 1).setFill()
    NSBezierPath(roundedRect: background, xRadius: s * 0.18, yRadius: s * 0.18).fill()
    let border = NSBezierPath(roundedRect: background.insetBy(dx: s * 0.055, dy: s * 0.055), xRadius: s * 0.13, yRadius: s * 0.13)
    amber.withAlphaComponent(0.65).setStroke()
    border.lineWidth = max(1, s * 0.009)
    border.stroke()
    let word = "550C" as NSString
    let font = NSFont(name: "Menlo-Bold", size: s * 0.255) ?? NSFont.monospacedSystemFont(ofSize: s * 0.255, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: amber]
    let measure = word.size(withAttributes: attributes)
    word.draw(at: NSPoint(x: (s - measure.width) / 2, y: s * 0.39), withAttributes: attributes)
    if size >= 32 {
        let label = "B O O T" as NSString
        let labelAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: s * 0.065, weight: .medium), .foregroundColor: amber.withAlphaComponent(0.72)]
        let labelSize = label.size(withAttributes: labelAttributes)
        label.draw(at: NSPoint(x: (s - labelSize.width) / 2, y: s * 0.265), withAttributes: labelAttributes)
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
    try png.write(to: output.appendingPathComponent(name))
}

for base in [16, 32, 128, 256, 512] {
    try drawIcon(size: base, name: "icon_\(base)x\(base).png")
    try drawIcon(size: base * 2, name: "icon_\(base)x\(base)@2x.png")
}
