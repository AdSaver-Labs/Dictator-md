#!/usr/bin/env python3
"""Generate the Dictator-md app icon using AppKit/CoreGraphics."""
import os
import subprocess
import sys
import tempfile

SWIFT_ICON_RENDERER = r'''
import AppKit

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

func roundedPath(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func sparklePath(center: CGPoint, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let short = radius * 0.34
    let points = [
        CGPoint(x: center.x, y: center.y - radius),
        CGPoint(x: center.x + short, y: center.y - short),
        CGPoint(x: center.x + radius, y: center.y),
        CGPoint(x: center.x + short, y: center.y + short),
        CGPoint(x: center.x, y: center.y + radius),
        CGPoint(x: center.x - short, y: center.y + short),
        CGPoint(x: center.x - radius, y: center.y),
        CGPoint(x: center.x - short, y: center.y - short),
    ]
    path.move(to: points[0])
    for point in points.dropFirst() {
        path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

func renderIcon(size: Int) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    guard let nsContext = NSGraphicsContext.current else {
        img.unlockFocus()
        return img
    }

    let ctx = nsContext.cgContext
    let s = CGFloat(size)
    ctx.clear(CGRect(x: 0, y: 0, width: s, height: s))

    // Keep the artwork slightly inset so it visually matches standard macOS app icons.
    let tileInset = s * 0.075
    let tile = CGRect(x: tileInset, y: tileInset, width: s - tileInset * 2, height: s - tileInset * 2)
    let tileRadius = tile.width * 0.215

    ctx.saveGState()
    ctx.addPath(roundedPath(tile, tileRadius))
    ctx.clip()

    let yellowColors = [
        CGColor(red: 1.00, green: 0.91, blue: 0.35, alpha: 1.0),
        CGColor(red: 1.00, green: 0.73, blue: 0.10, alpha: 1.0),
    ]
    let yellowGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: yellowColors as CFArray, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(
        yellowGradient,
        start: CGPoint(x: tile.minX, y: tile.maxY),
        end: CGPoint(x: tile.maxX, y: tile.minY),
        options: []
    )

    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    ctx.fill(CGRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2))
    ctx.restoreGState()

    ctx.addPath(roundedPath(tile.insetBy(dx: tile.width * 0.008, dy: tile.height * 0.008), tileRadius))
    ctx.setStrokeColor(CGColor(red: 0.08, green: 0.08, blue: 0.07, alpha: 0.16))
    ctx.setLineWidth(max(1, tile.width * 0.012))
    ctx.strokePath()

    let center = CGPoint(x: tile.midX, y: tile.midY)
    let ink = CGColor(red: 0.08, green: 0.08, blue: 0.07, alpha: 1.0)
    let symbolPointSize = tile.width * 0.47
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .bold)
    if let symbol = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {
        let symbolHeight = tile.width * 0.49
        let aspect = max(0.35, symbol.size.width / max(symbol.size.height, 1))
        let symbolWidth = symbolHeight * aspect
        let symbolRect = CGRect(
            x: center.x - symbolWidth / 2,
            y: center.y - symbolHeight / 2,
            width: symbolWidth,
            height: symbolHeight
        )
        NSGraphicsContext.saveGraphicsState()
        NSColor(cgColor: ink)?.set()
        let transform = NSAffineTransform()
        transform.translateX(by: symbolRect.midX, yBy: symbolRect.midY)
        transform.rotate(byDegrees: -7)
        transform.translateX(by: -symbolRect.midX, yBy: -symbolRect.midY)
        transform.concat()
        symbol.isTemplate = true
        symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()
    }

    ctx.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.07, alpha: 0.82))
    ctx.addPath(sparklePath(center: CGPoint(x: tile.minX + tile.width * 0.27, y: tile.minY + tile.height * 0.28), radius: tile.width * 0.022))
    ctx.fillPath()
    ctx.addPath(sparklePath(center: CGPoint(x: tile.minX + tile.width * 0.75, y: tile.minY + tile.height * 0.24), radius: tile.width * 0.034))
    ctx.fillPath()
    ctx.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.07, alpha: 0.68))
    ctx.addPath(sparklePath(center: CGPoint(x: tile.minX + tile.width * 0.78, y: tile.minY + tile.height * 0.76), radius: tile.width * 0.020))
    ctx.fillPath()

    img.unlockFocus()
    return img
}

let outputDir = CommandLine.arguments[1]
let iconsetPath = outputDir + "/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetPath)
try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, name) in sizes {
    let image = renderIcon(size: size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()

    let pngData = rep.representation(using: .png, properties: [:])!
    try! pngData.write(to: URL(fileURLWithPath: iconsetPath + "/" + name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", outputDir + "/AppIcon.icns"]
try! process.run()
process.waitUntilExit()

try? FileManager.default.removeItem(atPath: iconsetPath)
print("[Icon] Generated \(outputDir)/AppIcon.icns")
'''


def generate_icon(resources_dir: str) -> None:
    os.makedirs(resources_dir, exist_ok=True)

    with tempfile.NamedTemporaryFile(mode="w", suffix=".swift", delete=False) as file:
        file.write(SWIFT_ICON_RENDERER)
        swift_path = file.name

    binary_path = swift_path.removesuffix(".swift")
    try:
        subprocess.run(
            ["swiftc", swift_path, "-framework", "AppKit", "-o", binary_path],
            check=True,
            capture_output=True,
        )
        subprocess.run([binary_path, resources_dir], check=True)
    finally:
        try:
            os.unlink(swift_path)
        except FileNotFoundError:
            pass
        try:
            os.unlink(binary_path)
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: generate-icon.py <Resources_dir>")
        sys.exit(1)

    generate_icon(sys.argv[1])
