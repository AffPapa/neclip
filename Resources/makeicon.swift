import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Background: dark rounded square (macOS icon grid inset ~10%)
let inset: CGFloat = size * 0.10
let bgRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.20, yRadius: size * 0.20)
NSColor(red: 0.078, green: 0.086, blue: 0.094, alpha: 1).setFill() // #141618
bgPath.fill()

let green = NSColor(red: 0.357, green: 0.894, blue: 0.608, alpha: 1) // #5be49b

// Clipboard board
let bw = size * 0.42
let bh = size * 0.52
let bx = (size - bw) / 2 - size * 0.04
let by = (size - bh) / 2 - size * 0.03
let board = NSBezierPath(roundedRect: NSRect(x: bx, y: by, width: bw, height: bh), xRadius: size * 0.05, yRadius: size * 0.05)
board.lineWidth = size * 0.028
NSColor(white: 0.62, alpha: 1).setStroke()
board.stroke()

// Clip at top
let cw = size * 0.16
let clipRect = NSRect(x: bx + (bw - cw) / 2, y: by + bh - size * 0.025, width: cw, height: size * 0.05)
let clip = NSBezierPath(roundedRect: clipRect, xRadius: size * 0.02, yRadius: size * 0.02)
NSColor(white: 0.62, alpha: 1).setFill()
clip.fill()

// Front sheet, offset — green, the "history" layer
let sw = bw
let sh = bh
let sx = bx + size * 0.09
let sy = by - size * 0.07
let sheet = NSBezierPath(roundedRect: NSRect(x: sx, y: sy, width: sw, height: sh), xRadius: size * 0.05, yRadius: size * 0.05)
NSColor(red: 0.078, green: 0.086, blue: 0.094, alpha: 1).setFill()
sheet.fill()
sheet.lineWidth = size * 0.028
green.setStroke()
sheet.stroke()

// Text lines on the sheet
green.setFill()
let lineH = size * 0.022
let lineX = sx + size * 0.055
for (i, wfrac) in [0.30, 0.22, 0.27, 0.16].enumerated() {
    let ly = sy + sh - size * 0.10 - CGFloat(i) * size * 0.085
    let lr = NSRect(x: lineX, y: ly, width: size * wfrac, height: lineH)
    NSBezierPath(roundedRect: lr, xRadius: lineH / 2, yRadius: lineH / 2).fill()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("render failed")
}
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("written")
