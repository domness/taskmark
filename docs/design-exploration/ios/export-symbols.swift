// Design-only SF Symbol rasterization. Run from the repository root with Swift.
import AppKit

let symbols = [
    "sun": "sun.max", "inbox": "tray", "browse": "square.grid.2x2",
    "search": "magnifyingglass", "plus": "plus", "options": "slider.horizontal.3",
    "more": "ellipsis.circle", "back": "chevron.left", "forward": "chevron.right",
    "down": "chevron.down", "folder": "folder", "calendar": "calendar",
    "repeat": "repeat", "flag": "flag", "check": "checkmark", "cloud": "icloud",
    "wifi": "wifi", "battery": "battery.100percent", "signal": "cellularbars",
    "next": "arrow.right.circle", "waiting": "hourglass", "someday": "archivebox",
    "all": "checklist", "tag": "tag", "settings": "gearshape", "area": "square.stack",
    "filter": "line.3.horizontal.decrease", "document": "doc.text", "keyboard": "keyboard.chevron.compact.down",
    "shift": "shift", "delete": "delete.left", "globe": "globe", "mic": "mic",
    "warning": "exclamationmark.circle", "refresh": "arrow.clockwise", "lock": "lock",
    "sidebar": "sidebar.left", "close": "xmark", "download": "arrow.down.circle"
]
let directory = URL(fileURLWithPath: "docs/design-exploration/ios/symbols", isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for (name, symbol) in symbols {
    guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 22, weight: .regular)) else {
        fatalError("Missing SF Symbol: \(symbol)")
    }
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 72, pixelsHigh: 72,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Unable to create bitmap")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let scale = min(66 / image.size.width, 66 / image.size.height)
    let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    image.draw(in: NSRect(x: (72 - size.width) / 2, y: (72 - size.height) / 2, width: size.width, height: size.height))
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to encode symbol")
    }
    try data.write(to: directory.appendingPathComponent("\(name).png"))
}
print("Exported \(symbols.count) SF Symbols for design mockups.")
