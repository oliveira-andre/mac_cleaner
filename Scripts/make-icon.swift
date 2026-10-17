// Generates build/AppIcon.icns — a display with a broom in front, on a gradient.
// Colors are DESIGN.md tokens: deep violet → night background, dark-canvas
// screen, and a sticker-style pink + lime broom.
// Run: swift Scripts/make-icon.swift [output.icns]
// Also writes a <output>-preview.png (512px) for eyeballing.
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.icns"

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

func drawIcon(px: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: px, height: px)

    // Rounded gradient background (macOS squircle-ish).
    let radius = px * 0.2237
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    NSGradient(colors: [hex(0x422082), hex(0x150F23)])!.draw(in: rect, angle: -90)  // violet-deep → night

    // Centered monitor: white bezel with a dark screen.
    let body = NSRect(x: px * 0.16, y: px * 0.37, width: px * 0.68, height: px * 0.42)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: body, xRadius: px * 0.05, yRadius: px * 0.05).fill()

    let screen = body.insetBy(dx: px * 0.04, dy: px * 0.04)
    hex(0x1F1633).setFill()  // surface-canvas-dark
    NSBezierPath(roundedRect: screen, xRadius: px * 0.028, yRadius: px * 0.028).fill()

    // Stand: neck + base, white.
    let cx = body.midX
    let neck = NSBezierPath()
    neck.move(to: NSPoint(x: cx - px * 0.05, y: px * 0.37))
    neck.line(to: NSPoint(x: cx + px * 0.05, y: px * 0.37))
    neck.line(to: NSPoint(x: cx + px * 0.07, y: px * 0.285))
    neck.line(to: NSPoint(x: cx - px * 0.07, y: px * 0.285))
    neck.close()
    NSColor.white.setFill(); neck.fill()
    NSBezierPath(roundedRect: NSRect(x: cx - px * 0.13, y: px * 0.255, width: px * 0.26, height: px * 0.04),
                 xRadius: px * 0.018, yRadius: px * 0.018).fill()

    // Broom over the dark screen, in the accent colors so it stands out.
    drawBroom(px: px, screen: screen)
}

func drawBroom(px: CGFloat, screen: NSRect) {
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform()
    t.translateX(by: screen.midX - px * 0.015, yBy: screen.midY - px * 0.02)
    t.rotate(byDegrees: -26)
    t.concat()

    let handleColor = hex(0xFA7FAA)   // accent-pink
    let strawColor  = hex(0xC2EF4E)   // accent-lime
    let darkTan     = hex(0x150F23)   // surface-night — collar + bristle gaps

    // Handle (up from the junction at local origin).
    let hw = px * 0.034
    handleColor.setFill()
    NSBezierPath(roundedRect: NSRect(x: -hw / 2, y: 0, width: hw, height: px * 0.17),
                 xRadius: hw / 2, yRadius: hw / 2).fill()

    // Collar.
    darkTan.setFill()
    NSBezierPath(roundedRect: NSRect(x: -px * 0.045, y: -px * 0.012, width: px * 0.09, height: px * 0.03),
                 xRadius: px * 0.012, yRadius: px * 0.012).fill()

    // Bristle head (fans down).
    let head = NSBezierPath()
    head.move(to: NSPoint(x: -px * 0.05, y: -px * 0.005))
    head.line(to: NSPoint(x: px * 0.05, y: -px * 0.005))
    head.line(to: NSPoint(x: px * 0.085, y: -px * 0.155))
    head.line(to: NSPoint(x: -px * 0.085, y: -px * 0.155))
    head.close()
    strawColor.setFill(); head.fill()

    // Bristle gaps.
    darkTan.setStroke()
    for frac in stride(from: -0.62, through: 0.62, by: 0.31) {
        let line = NSBezierPath()
        line.lineWidth = px * 0.009
        line.move(to: NSPoint(x: px * 0.045 * CGFloat(frac), y: -px * 0.02))
        line.line(to: NSPoint(x: px * 0.082 * CGFloat(frac), y: -px * 0.145))
        line.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
}

func png(px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(px: CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = fm.temporaryDirectory.appendingPathComponent("MacCleaner-\(UUID().uuidString).iconset")
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256),
    ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes { try! png(px: px).write(to: iconset.appendingPathComponent("\(name).png")) }

let out = URL(fileURLWithPath: outPath)
try? fm.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
try! png(px: 512).write(to: out.deletingPathExtension().appendingPathExtension("preview.png"))

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try! proc.run(); proc.waitUntilExit()
try? fm.removeItem(at: iconset)
print(proc.terminationStatus == 0 ? "Wrote \(outPath) (+ preview.png)" : "iconutil failed (\(proc.terminationStatus))")
