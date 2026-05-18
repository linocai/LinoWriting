#!/usr/bin/env swift

import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first
    ?? "Resources/AppIcon/AppIcon-1024.png"
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let size: CGFloat = 1024
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let image = NSImage(size: rect.size)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func strokeLine(from start: NSPoint, to end: NSPoint, color: NSColor, width: CGFloat) {
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    path.lineWidth = width
    color.setStroke()
    path.stroke()
}

func fillCircle(center: NSPoint, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 0) {
    let path = NSBezierPath(ovalIn: NSRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    ))
    fill.setFill()
    path.fill()
    if let stroke, lineWidth > 0 {
        path.lineWidth = lineWidth
        stroke.setStroke()
        path.stroke()
    }
}

image.lockFocus()

let background = NSBezierPath(roundedRect: rect.insetBy(dx: 28, dy: 28), xRadius: 210, yRadius: 210)
NSGraphicsContext.saveGraphicsState()
background.addClip()
NSGradient(colors: [
    color(30, 60, 120),
    color(47, 112, 129),
    color(235, 167, 92)
])?.draw(in: rect, angle: -35)

color(255, 255, 255, 0.12).setStroke()
for offset in stride(from: -160, through: 1180, by: 92) {
    strokeLine(
        from: NSPoint(x: CGFloat(offset), y: 0),
        to: NSPoint(x: CGFloat(offset) + 360, y: size),
        color: color(255, 255, 255, 0.10),
        width: 3
    )
}
NSGraphicsContext.restoreGraphicsState()

let shadow = NSShadow()
shadow.shadowBlurRadius = 34
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.shadowColor = color(22, 30, 45, 0.32)

NSGraphicsContext.saveGraphicsState()
shadow.set()
let bookRect = NSRect(x: 196, y: 210, width: 632, height: 560)
let book = NSBezierPath(roundedRect: bookRect, xRadius: 54, yRadius: 54)
color(246, 247, 241).setFill()
book.fill()
NSGraphicsContext.restoreGraphicsState()

let leftPage = NSBezierPath(roundedRect: NSRect(x: 214, y: 228, width: 288, height: 524), xRadius: 38, yRadius: 38)
let rightPage = NSBezierPath(roundedRect: NSRect(x: 522, y: 228, width: 288, height: 524), xRadius: 38, yRadius: 38)
color(255, 253, 244).setFill()
leftPage.fill()
color(241, 245, 239).setFill()
rightPage.fill()

let spine = NSBezierPath(roundedRect: NSRect(x: 493, y: 232, width: 38, height: 516), xRadius: 18, yRadius: 18)
color(212, 220, 215).setFill()
spine.fill()

for y in [650, 600, 550, 500, 450] as [CGFloat] {
    strokeLine(from: NSPoint(x: 270, y: y), to: NSPoint(x: 442, y: y), color: color(80, 96, 105, 0.26), width: 12)
}
for y in [646, 596, 546, 496] as [CGFloat] {
    strokeLine(from: NSPoint(x: 574, y: y), to: NSPoint(x: 744, y: y), color: color(80, 96, 105, 0.22), width: 12)
}

let nodeStroke = color(255, 253, 244, 0.95)
let nodeFill = color(34, 88, 143)
let accentFill = color(226, 114, 73)
let nodeA = NSPoint(x: 592, y: 440)
let nodeB = NSPoint(x: 702, y: 518)
let nodeC = NSPoint(x: 684, y: 360)
let nodeD = NSPoint(x: 584, y: 588)

strokeLine(from: nodeA, to: nodeB, color: color(34, 88, 143, 0.46), width: 18)
strokeLine(from: nodeA, to: nodeC, color: color(34, 88, 143, 0.46), width: 18)
strokeLine(from: nodeB, to: nodeD, color: color(34, 88, 143, 0.38), width: 16)

fillCircle(center: nodeA, radius: 44, fill: accentFill, stroke: nodeStroke, lineWidth: 10)
fillCircle(center: nodeB, radius: 34, fill: nodeFill, stroke: nodeStroke, lineWidth: 8)
fillCircle(center: nodeC, radius: 30, fill: color(65, 132, 116), stroke: nodeStroke, lineWidth: 8)
fillCircle(center: nodeD, radius: 28, fill: color(64, 95, 167), stroke: nodeStroke, lineWidth: 8)

let bookmark = NSBezierPath()
bookmark.move(to: NSPoint(x: 342, y: 752))
bookmark.line(to: NSPoint(x: 428, y: 752))
bookmark.line(to: NSPoint(x: 428, y: 358))
bookmark.line(to: NSPoint(x: 385, y: 404))
bookmark.line(to: NSPoint(x: 342, y: 358))
bookmark.close()
color(222, 83, 77).setFill()
bookmark.fill()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let data = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to render icon PNG.\n", stderr)
    exit(1)
}

try data.write(to: outputURL, options: .atomic)
print("Wrote \(outputURL.path)")
