import AppKit
let items = [("mood-normal", "0 ふつう"), ("mood-happy", "1 うれしい"), ("mood-encourage", "2 応援"), ("mood-focus", "3 集中")]
let cell = 360, h = 420
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: cell * 4, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(calibratedRed: 0.98, green: 0.976, blue: 0.96, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: cell * 4, height: h).fill()
for (i, (f, label)) in items.enumerated() {
    let img = NSImage(contentsOfFile: "outputs/\(f).png")!
    img.draw(in: NSRect(x: i * cell, y: 60, width: cell, height: cell))
    let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 26, weight: .semibold), .foregroundColor: NSColor(calibratedRed: 0.17, green: 0.12, blue: 0.09, alpha: 1)]
    let s = NSAttributedString(string: label, attributes: a)
    s.draw(at: NSPoint(x: CGFloat(i * cell) + (CGFloat(cell) - s.size().width) / 2, y: 20))
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "outputs/rikyu-moods.png"))
