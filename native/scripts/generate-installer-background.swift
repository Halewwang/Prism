import AppKit

precondition(CommandLine.arguments.count == 2, "usage: generate-installer-background.swift <output.png>")
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1280, pixelsHigh: 800,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: 640, height: 400)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(srgbRed: 0.980, green: 0.984, blue: 0.976, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 640, height: 400)).fill()

func text(_ value: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (value as NSString).draw(in: NSRect(x: 24, y: y, width: 592, height: 36), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color, .paragraphStyle: paragraph,
    ])
}
let ink = NSColor(srgbRed: 0.133, green: 0.157, blue: 0.125, alpha: 1)
let secondary = NSColor(srgbRed: 0.384, green: 0.424, blue: 0.376, alpha: 1)
text("安装 Prism", y: 340, size: 26, weight: .semibold, color: ink)
text("将左侧 Prism 拖入右侧 Applications 文件夹", y: 306, size: 14, color: secondary)
// Keep all instructions above Finder's optional path and status bars.
text("安装完成后，从「应用程序」打开 Prism。", y: 104, size: 12, color: secondary)
text("Drag Prism into Applications to install.", y: 82, size: 12, color: secondary)

NSColor(srgbRed: 0.384, green: 0.545, blue: 0.239, alpha: 1).setStroke()
let arrow = NSBezierPath()
arrow.lineWidth = 2
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 299, y: 234))
arrow.line(to: NSPoint(x: 341, y: 234))
arrow.move(to: NSPoint(x: 333, y: 242))
arrow.line(to: NSPoint(x: 341, y: 234))
arrow.line(to: NSPoint(x: 333, y: 226))
arrow.stroke()
NSGraphicsContext.restoreGraphicsState()

try bitmap.representation(using: .png, properties: [:])!.write(
    to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
