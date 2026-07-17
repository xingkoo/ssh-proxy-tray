import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: generate-icon.swift OUTPUT\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high

NSColor(calibratedRed: 0.075, green: 0.086, blue: 0.098, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 190, yRadius: 190).fill()

let connector = NSBezierPath()
connector.move(to: NSPoint(x: 328, y: 512))
connector.curve(
    to: NSPoint(x: 696, y: 512),
    controlPoint1: NSPoint(x: 430, y: 700),
    controlPoint2: NSPoint(x: 594, y: 324)
)
connector.lineWidth = 72
connector.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.92).setStroke()
connector.stroke()

NSColor(calibratedRed: 0.18, green: 0.82, blue: 0.58, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 186, y: 370, width: 284, height: 284)).fill()

NSColor(calibratedRed: 0.20, green: 0.68, blue: 0.94, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 554, y: 370, width: 284, height: 284)).fill()

NSColor(calibratedWhite: 0.07, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 270, y: 454, width: 116, height: 116)).fill()
NSBezierPath(ovalIn: NSRect(x: 638, y: 454, width: 116, height: 116)).fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    exit(1)
}
try png.write(to: outputURL, options: .atomic)
