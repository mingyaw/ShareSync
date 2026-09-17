import AppKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: swift scripts/generate-app-icon.swift OUTPUT_PNG\n".utf8))
    exit(2)
}

let size = NSSize(width: 1024, height: 1024)
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("Unable to create icon bitmap.\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

NSColor(calibratedRed: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

func drawPhone(_ rect: NSRect) {
    let outline = NSBezierPath(roundedRect: rect, xRadius: 72, yRadius: 72)
    outline.lineWidth = 44
    NSColor.white.withAlphaComponent(0.96).setStroke()
    outline.stroke()

    let speaker = NSBezierPath(roundedRect: NSRect(x: rect.midX - 54, y: rect.maxY - 78, width: 108, height: 18), xRadius: 9, yRadius: 9)
    NSColor.white.withAlphaComponent(0.96).setFill()
    speaker.fill()
}

drawPhone(NSRect(x: 150, y: 170, width: 300, height: 650))
drawPhone(NSRect(x: 574, y: 204, width: 300, height: 650))

let syncDisc = NSBezierPath(ovalIn: NSRect(x: 336, y: 336, width: 352, height: 352))
NSColor(calibratedRed: 14 / 255, green: 116 / 255, blue: 144 / 255, alpha: 1).setFill()
syncDisc.fill()

let upperArrow = NSBezierPath()
upperArrow.move(to: NSPoint(x: 414, y: 548))
upperArrow.curve(to: NSPoint(x: 586, y: 574), controlPoint1: NSPoint(x: 454, y: 616), controlPoint2: NSPoint(x: 544, y: 628))
upperArrow.line(to: NSPoint(x: 566, y: 624))
upperArrow.line(to: NSPoint(x: 652, y: 578))
upperArrow.line(to: NSPoint(x: 584, y: 510))
upperArrow.line(to: NSPoint(x: 584, y: 548))
upperArrow.curve(to: NSPoint(x: 446, y: 526), controlPoint1: NSPoint(x: 548, y: 584), controlPoint2: NSPoint(x: 476, y: 576))
upperArrow.close()

let lowerArrow = NSBezierPath()
lowerArrow.move(to: NSPoint(x: 610, y: 476))
lowerArrow.curve(to: NSPoint(x: 438, y: 450), controlPoint1: NSPoint(x: 570, y: 408), controlPoint2: NSPoint(x: 480, y: 396))
lowerArrow.line(to: NSPoint(x: 458, y: 400))
lowerArrow.line(to: NSPoint(x: 372, y: 446))
lowerArrow.line(to: NSPoint(x: 440, y: 514))
lowerArrow.line(to: NSPoint(x: 440, y: 476))
lowerArrow.curve(to: NSPoint(x: 578, y: 498), controlPoint1: NSPoint(x: 476, y: 440), controlPoint2: NSPoint(x: 548, y: 448))
lowerArrow.close()

NSColor.white.setFill()
upperArrow.fill()
lowerArrow.fill()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Unable to render app icon.\n".utf8))
    exit(1)
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
