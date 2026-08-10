#!/usr/bin/env swift
//
//  make-starter-plans.swift
//  Draws the plan sheets that ship with the starter projects.
//
//  The starter content in `Workshop/App/StarterProjects.swift` is written from
//  scratch rather than scraped, so its drawings have to be original too — these
//  sheets are generated here instead of borrowed from a plans site. Running this
//  script rewrites `Workshop/Resources/StarterPlans/*.png`; the dimensions below
//  are the same ones the seeded cut lists use, so if you change a part size,
//  change it in both places.
//
//  Deliberately monochrome. The signal lamp is user-swappable (amber, signal,
//  platform, beacon, violet) and these bytes are baked at build time, so a sheet
//  drawn in amber would clash for four users out of five.
//
//  Usage:  swift Scripts/make-starter-plans.swift [output-dir] [fonts-dir]
//

import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// MARK: - Paper

let sheetW: CGFloat = 1600
let sheetH: CGFloat = 1100

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

enum Ink {
    static let ground = rgb(0x0F1315)   // the sheet itself
    static let frame = rgb(0x2C3335)    // border rule
    static let object = rgb(0xEFF2ED)   // visible edges
    static let hidden = rgb(0x6E7A78)   // edges behind something
    static let dim = rgb(0x8B9794)      // dimensions and their text
    static let faint = rgb(0x3A4245)    // hatching, grid
}

// MARK: - Type

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent().standardizedFileURL
let repoRoot = scriptDir.deletingLastPathComponent()

let outDir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : repoRoot.appendingPathComponent("Workshop/Resources/StarterPlans")
let fontsDir = CommandLine.arguments.count > 2
    ? URL(fileURLWithPath: CommandLine.arguments[2])
    : repoRoot.appendingPathComponent("Fonts")

func loadFont(_ file: String, size: CGFloat) -> CTFont {
    let url = fontsDir.appendingPathComponent(file) as CFURL
    guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor],
          let first = descs.first else {
        FileHandle.standardError.write("warning: could not load \(file), falling back to Menlo\n".data(using: .utf8)!)
        return CTFontCreateWithName("Menlo" as CFString, size, nil)
    }
    return CTFontCreateWithFontDescriptor(first, size, nil)
}

enum Align { case left, center, right }

/// CoreText's own attribute keys — `NSAttributedString.Key.font` and friends
/// live in AppKit/UIKit, which this script deliberately doesn't import.
func ctAttrs(font: CTFont, color: CGColor?, tracking: CGFloat) -> [NSAttributedString.Key: Any] {
    var attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTKernAttributeName as String): tracking,
    ]
    if let color {
        attrs[NSAttributedString.Key(kCTForegroundColorAttributeName as String)] = color
    }
    return attrs
}

// MARK: - Sheet

final class Sheet {
    let ctx: CGContext

    init() {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let c = CGContext(data: nil, width: Int(sheetW), height: Int(sheetH),
                                bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            fatalError("could not create bitmap context")
        }
        ctx = c
        ctx.setFillColor(Ink.ground)
        ctx.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
        ctx.setLineCap(.butt)
        ctx.setLineJoin(.miter)
    }

    // MARK: Primitives

    func line(_ a: CGPoint, _ b: CGPoint, _ color: CGColor = Ink.object, _ width: CGFloat = 3.5,
              dash: [CGFloat]? = nil) {
        ctx.saveGState()
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        if let dash { ctx.setLineDash(phase: 0, lengths: dash) }
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.strokePath()
        ctx.restoreGState()
    }

    func rect(_ r: CGRect, _ color: CGColor = Ink.object, _ width: CGFloat = 3.5,
              dash: [CGFloat]? = nil) {
        ctx.saveGState()
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        if let dash { ctx.setLineDash(phase: 0, lengths: dash) }
        ctx.stroke(r)
        ctx.restoreGState()
    }

    func fill(_ r: CGRect, _ color: CGColor) {
        ctx.setFillColor(color)
        ctx.fill(r)
    }

    func circle(_ center: CGPoint, radius: CGFloat, _ color: CGColor = Ink.object,
                _ width: CGFloat = 3.5, dash: [CGFloat]? = nil) {
        ctx.saveGState()
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        if let dash { ctx.setLineDash(phase: 0, lengths: dash) }
        ctx.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                  width: radius * 2, height: radius * 2))
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// 45° hatching, the convention for "this face is a cut through solid stock".
    func hatch(_ r: CGRect, spacing: CGFloat = 11, color: CGColor = Ink.faint, width: CGFloat = 1.4) {
        ctx.saveGState()
        ctx.clip(to: r)
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        var x = r.minX - r.height
        while x < r.maxX {
            ctx.move(to: CGPoint(x: x, y: r.minY))
            ctx.addLine(to: CGPoint(x: x + r.height, y: r.maxY))
            x += spacing
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: Text

    @discardableResult
    func text(_ s: String, at p: CGPoint, font: CTFont, color: CGColor = Ink.object,
              align: Align = .left, tracking: CGFloat = 0) -> CGFloat {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: s, attributes: ctAttrs(font: font, color: color, tracking: tracking)))
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let w = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let x: CGFloat
        switch align {
        case .left: x = p.x
        case .center: x = p.x - w / 2
        case .right: x = p.x - w
        }
        ctx.textPosition = CGPoint(x: x, y: p.y)
        CTLineDraw(line, ctx)
        return w
    }

    func textWidth(_ s: String, font: CTFont, tracking: CGFloat = 0) -> CGFloat {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: s, attributes: ctAttrs(font: font, color: nil, tracking: tracking)))
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    // MARK: Dimensions

    /// Architectural tick — a 45° slash rather than an arrowhead, which reads
    /// better at thumbnail size than a filled triangle.
    private func tick(_ p: CGPoint) {
        line(CGPoint(x: p.x - 6, y: p.y - 6), CGPoint(x: p.x + 6, y: p.y + 6), Ink.dim, 1.8)
    }

    func dimH(_ x1: CGFloat, _ x2: CGFloat, y: CGFloat, _ label: String, font: CTFont,
              witnessFrom: CGFloat? = nil) {
        line(CGPoint(x: x1, y: y), CGPoint(x: x2, y: y), Ink.dim, 1.4)
        tick(CGPoint(x: x1, y: y))
        tick(CGPoint(x: x2, y: y))
        if let from = witnessFrom {
            let dir: CGFloat = y < from ? -1 : 1
            line(CGPoint(x: x1, y: from), CGPoint(x: x1, y: y + 7 * dir), Ink.dim, 1.0, dash: [3, 3])
            line(CGPoint(x: x2, y: from), CGPoint(x: x2, y: y + 7 * dir), Ink.dim, 1.0, dash: [3, 3])
        }
        let w = textWidth(label, font: font, tracking: 0.5)
        fill(CGRect(x: (x1 + x2) / 2 - w / 2 - 7, y: y - 8, width: w + 14, height: 24), Ink.ground)
        text(label, at: CGPoint(x: (x1 + x2) / 2, y: y - 1), font: font,
             color: Ink.dim, align: .center, tracking: 0.5)
    }

    func dimV(_ y1: CGFloat, _ y2: CGFloat, x: CGFloat, _ label: String, font: CTFont,
              witnessFrom: CGFloat? = nil) {
        line(CGPoint(x: x, y: y1), CGPoint(x: x, y: y2), Ink.dim, 1.4)
        tick(CGPoint(x: x, y: y1))
        tick(CGPoint(x: x, y: y2))
        if let from = witnessFrom {
            let dir: CGFloat = x < from ? -1 : 1
            line(CGPoint(x: from, y: y1), CGPoint(x: x + 7 * dir, y: y1), Ink.dim, 1.0, dash: [3, 3])
            line(CGPoint(x: from, y: y2), CGPoint(x: x + 7 * dir, y: y2), Ink.dim, 1.0, dash: [3, 3])
        }
        // Rotated so the text reads up the page, the way a drafter would set it.
        ctx.saveGState()
        ctx.translateBy(x: x - 9, y: (y1 + y2) / 2)
        ctx.rotate(by: .pi / 2)
        let w = textWidth(label, font: font, tracking: 0.5)
        fill(CGRect(x: -w / 2 - 7, y: -8, width: w + 14, height: 24), Ink.ground)
        text(label, at: .zero, font: font, color: Ink.dim, align: .center, tracking: 0.5)
        ctx.restoreGState()
    }

    /// A leader line with a note on the end, for calling out a detail.
    func note(_ label: String, from: CGPoint, to: CGPoint, font: CTFont, align: Align = .left) {
        line(from, to, Ink.dim, 1.2)
        circle(from, radius: 3.5, Ink.dim, 1.2)
        let pad: CGFloat = align == .right ? -8 : 8
        text(label, at: CGPoint(x: to.x + pad, y: to.y - 5), font: font,
             color: Ink.dim, align: align, tracking: 0.5)
    }

    func write(to url: URL) {
        guard let image = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            fatalError("could not encode \(url.lastPathComponent)")
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(url.lastPathComponent)") }
    }
}

// MARK: - Projection

/// Maps inches to sheet points for one orthographic view.
struct Proj {
    let ox: CGFloat, oy: CGFloat, s: CGFloat

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: ox + x * s, y: oy + y * s, width: w * s, height: h * s)
    }
    func x(_ v: CGFloat) -> CGFloat { ox + v * s }
    func y(_ v: CGFloat) -> CGFloat { oy + v * s }
    func d(_ v: CGFloat) -> CGFloat { v * s }
}

// MARK: - Fonts

let fTitle = loadFont("MartianMonoBoard-Bold.ttf", size: 30)
let fSub = loadFont("MartianMonoBoard-Regular.ttf", size: 15)
let fView = loadFont("MartianMonoBoard-SemiBold.ttf", size: 17)
let fDim = loadFont("MartianMonoBoard-Regular.ttf", size: 14)
let fNote = loadFont("ArchivoWS-Medium.ttf", size: 16)

// MARK: - Chrome

/// Border rule plus the title block every sheet carries.
func chrome(_ sh: Sheet, title: String, subtitle: String) {
    let inset: CGFloat = 34
    sh.rect(CGRect(x: inset, y: inset, width: sheetW - inset * 2, height: sheetH - inset * 2),
            Ink.frame, 2)

    let blockY: CGFloat = 118
    sh.line(CGPoint(x: inset, y: blockY), CGPoint(x: sheetW - inset, y: blockY), Ink.frame, 2)

    sh.text(title.uppercased(), at: CGPoint(x: inset + 30, y: blockY - 52),
            font: fTitle, color: Ink.object, align: .left, tracking: 1.5)
    sh.text(subtitle.uppercased(), at: CGPoint(x: inset + 30, y: blockY - 80),
            font: fSub, color: Ink.dim, align: .left, tracking: 2)

    sh.text("WORKSHOP", at: CGPoint(x: sheetW - inset - 30, y: blockY - 52),
            font: fView, color: Ink.dim, align: .right, tracking: 3)
    sh.text("STARTER PLAN — NOT TO SCALE", at: CGPoint(x: sheetW - inset - 30, y: blockY - 80),
            font: fSub, color: Ink.frame, align: .right, tracking: 2)
}

func viewLabel(_ sh: Sheet, _ s: String, at p: CGPoint) {
    sh.text(s.uppercased(), at: p, font: fView, color: Ink.dim, align: .center, tracking: 3)
}

// MARK: - Sheet 1 — Hand Tool Storage Cabinet

func handToolCabinet() -> Sheet {
    let sh = Sheet()
    chrome(sh, title: "Hand Tool Storage Cabinet",
           subtitle: "30 × 36 × 8 in — french cleat — baltic birch + walnut")

    // Front elevation: 30w × 36h at 15 pt/in.
    let f = Proj(ox: 210, oy: 300, s: 15)
    sh.rect(f.r(0, 0, 30, 36))                       // carcase
    sh.rect(f.r(0.75, 0.75, 28.5, 34.5), Ink.object, 2)   // inside face of case

    // Two fixed shelves.
    for y in [12.5, 24.0] {
        sh.rect(f.r(0.75, CGFloat(y), 28.5, 0.75), Ink.object, 2)
    }
    // Door swing centre line.
    sh.line(f.p(15, -1), f.p(15, 37), Ink.hidden, 1.4, dash: [14, 5, 3, 5])

    // Doors, drawn open-face so the frame-and-panel reads.
    for ox in [0.0, 15.0] {
        let d = CGFloat(ox)
        sh.rect(f.r(d, 0.25, 15, 35.5), Ink.object, 2.5)
        sh.rect(f.r(d + 2.5, 2.75, 10, 30.5), Ink.hidden, 1.8)   // panel
        for y in [8.0, 16.0, 24.0] {                              // tool racks
            sh.rect(f.r(d + 2.5, CGFloat(y), 10, 0.75), Ink.hidden, 1.5)
        }
    }

    sh.dimH(f.x(0), f.x(30), y: f.y(-1.6), "30\"", font: fDim, witnessFrom: f.y(0))
    sh.dimH(f.x(0), f.x(15), y: f.y(38.4), "15\"", font: fDim, witnessFrom: f.y(36))
    sh.dimH(f.x(15), f.x(30), y: f.y(38.4), "15\"", font: fDim, witnessFrom: f.y(36))
    sh.dimV(f.y(0), f.y(36), x: f.x(-1.6), "36\"", font: fDim, witnessFrom: f.x(0))
    viewLabel(sh, "Front elevation", at: CGPoint(x: f.x(15), y: 208))

    // Side section: 8 deep × 36 high.
    let g = Proj(ox: 1010, oy: 300, s: 15)
    sh.rect(g.r(0, 0, 8, 36))
    sh.hatch(g.r(0, 0, 0.75, 36))          // back panel, cut
    sh.hatch(g.r(0, 0, 8, 0.75))           // bottom, cut
    sh.hatch(g.r(0, 35.25, 8, 0.75))       // top, cut
    for y in [12.5, 24.0] {
        sh.hatch(g.r(0.75, CGFloat(y), 7.25, 0.75))
        sh.rect(g.r(0.75, CGFloat(y), 7.25, 0.75), Ink.object, 2)
    }
    // French cleat pair — the 45° rip is the whole point of the detail.
    let cleatY: CGFloat = 30
    sh.line(g.p(0.75, cleatY), g.p(2.25, cleatY + 1.5), Ink.object, 2.5)
    sh.line(g.p(0.75, cleatY), g.p(0.75, cleatY + 4), Ink.object, 2.5)
    sh.line(g.p(0.75, cleatY + 4), g.p(2.25, cleatY + 1.5), Ink.object, 2.5)
    sh.note("FRENCH CLEAT, 45° RIP", from: g.p(1.4, cleatY + 2),
            to: CGPoint(x: g.x(8) + 60, y: g.y(cleatY + 5)), font: fNote)

    // Door in section, hinged at the front edge.
    sh.rect(g.r(8, 0.25, 0.75, 35.5), Ink.object, 2.5)
    sh.note("DOOR, 3½\" DEEP", from: g.p(8.4, 6),
            to: CGPoint(x: g.x(8) + 60, y: g.y(4)), font: fNote)

    sh.dimH(g.x(0), g.x(8), y: g.y(-1.6), "8\"", font: fDim, witnessFrom: g.y(0))
    sh.dimV(g.y(0), g.y(12.5), x: g.x(-1.6), "12½\"", font: fDim, witnessFrom: g.x(0))
    sh.dimV(g.y(12.5), g.y(24), x: g.x(-1.6), "11½\"", font: fDim, witnessFrom: g.x(0))
    viewLabel(sh, "Section A-A", at: CGPoint(x: g.x(4), y: 208))

    return sh
}

// MARK: - Sheet 2 — Walnut Serving Tray

func servingTray() -> Sheet {
    let sh = Sheet()
    chrome(sh, title: "Walnut Serving Tray",
           subtitle: "18 × 12 × 2¼ in — mitred corners — splined")

    // Plan view.
    let p = Proj(ox: 250, oy: 330, s: 32)
    sh.rect(p.r(0, 0, 18, 12))
    sh.rect(p.r(0.625, 0.625, 16.75, 10.75), Ink.object, 2.5)
    // Mitres.
    for (a, b) in [((0.0, 0.0), (0.625, 0.625)),
                   ((18.0, 0.0), (17.375, 0.625)),
                   ((0.0, 12.0), (0.625, 11.375)),
                   ((18.0, 12.0), (17.375, 11.375))] {
        sh.line(p.p(CGFloat(a.0), CGFloat(a.1)), p.p(CGFloat(b.0), CGFloat(b.1)), Ink.object, 2)
    }
    // Cut-in handles, 4 × ¾, centred on the short sides.
    for x in [0.0, 17.375] {
        let r = p.r(CGFloat(x), 4.0, 0.625, 4)
        sh.fill(r, Ink.ground)
        sh.rect(r, Ink.object, 2.5)
    }
    sh.note("CUT-IN HANDLE, 4 × ¾", from: p.p(0.3, 6),
            to: CGPoint(x: p.x(9), y: p.y(13.6)), font: fNote, align: .center)

    sh.dimH(p.x(0), p.x(18), y: p.y(-1), "18\"", font: fDim, witnessFrom: p.y(0))
    sh.dimV(p.y(0), p.y(12), x: p.x(-1), "12\"", font: fDim, witnessFrom: p.x(0))
    sh.dimV(p.y(4), p.y(8), x: p.x(19.2), "4\"", font: fDim, witnessFrom: p.x(18))
    viewLabel(sh, "Plan", at: CGPoint(x: p.x(9), y: 244))

    // End section, showing the rabbet the bottom sits in.
    let e = Proj(ox: 980, oy: 430, s: 44)
    sh.rect(e.r(0, 0, 12, 2.25))
    sh.hatch(e.r(0, 0, 0.625, 2.25))
    sh.hatch(e.r(11.375, 0, 0.625, 2.25))
    sh.rect(e.r(0, 0, 0.625, 2.25), Ink.object, 2.5)
    sh.rect(e.r(11.375, 0, 0.625, 2.25), Ink.object, 2.5)
    // ¼ bottom panel in a ⅜-deep rabbet.
    sh.rect(e.r(0.375, 0.375, 11.25, 0.25), Ink.object, 2.5)
    sh.note("¼\" PANEL IN ⅜\" RABBET", from: e.p(6, 0.5),
            to: CGPoint(x: e.x(6), y: e.y(4.2)), font: fNote, align: .center)

    sh.dimV(e.y(0), e.y(2.25), x: e.x(-0.7), "2¼\"", font: fDim, witnessFrom: e.x(0))
    // Martian Mono has no ⅝ glyph — spelling it out beats a fallback box.
    sh.dimH(e.x(0), e.x(0.625), y: e.y(2.9), "5/8\"", font: fDim, witnessFrom: e.y(2.25))
    viewLabel(sh, "End section", at: CGPoint(x: e.x(6), y: 244))

    return sh
}

// MARK: - Sheet 3 — Bread Box

func breadBox() -> Sheet {
    let sh = Sheet()
    chrome(sh, title: "DIY Bread Box",
           subtitle: "16 × 10½ × 9½ in — flip-up front — vented back")

    // Front elevation.
    let f = Proj(ox: 200, oy: 300, s: 36)
    sh.rect(f.r(0, 0, 16, 9.5))
    sh.rect(f.r(0.75, 0.75, 14.5, 8), Ink.object, 2.5)
    // Flip-up door.
    sh.rect(f.r(0.8, 0.8, 14.4, 7.5), Ink.object, 2.5)
    // Pull.
    sh.rect(f.r(5, 6.6, 6, 1), Ink.object, 2.5)
    sh.note("WALNUT PULL, 6 × 1", from: f.p(8, 7.1),
            to: CGPoint(x: f.x(0) + 24, y: f.y(11.2)), font: fNote)
    // Hinge marks along the bottom edge of the door.
    for x in [3.0, 13.0] {
        sh.line(f.p(CGFloat(x) - 0.75, 0.8), f.p(CGFloat(x) + 0.75, 0.8), Ink.hidden, 4)
    }
    sh.note("HINGE AT BOTTOM EDGE", from: f.p(13, 0.8),
            to: CGPoint(x: f.x(16) + 24, y: f.y(-1.0)), font: fNote)

    sh.dimH(f.x(0), f.x(16), y: f.y(-0.75), "16\"", font: fDim, witnessFrom: f.y(0))
    sh.dimV(f.y(0), f.y(9.5), x: f.x(-0.75), "9½\"", font: fDim, witnessFrom: f.x(0))
    viewLabel(sh, "Front elevation", at: CGPoint(x: f.x(8), y: 208))

    // Side section.
    let g = Proj(ox: 980, oy: 300, s: 36)
    sh.rect(g.r(0, 0, 10.5, 9.5))
    sh.hatch(g.r(0, 8.75, 10.5, 0.75))      // top
    sh.hatch(g.r(0, 0, 10.5, 0.75))         // bottom
    sh.hatch(g.r(0, 0.75, 0.5, 8))          // vented back
    sh.rect(g.r(0, 0.75, 0.5, 8), Ink.object, 2)
    // Vent holes.
    for i in 0..<5 {
        sh.circle(g.p(0.25, 2 + CGFloat(i) * 1.4), radius: 4, Ink.dim, 1.6)
    }
    sh.note("VENT HOLES, ⅜\" DIA", from: g.p(0.25, 4.8),
            to: CGPoint(x: g.x(0) - 24, y: g.y(10.6)), font: fNote, align: .right)
    // Door, swung open to show the arc.
    sh.rect(g.r(9.75, 0.75, 0.75, 7.5), Ink.object, 2.5)
    sh.ctx.saveGState()
    sh.ctx.setStrokeColor(Ink.hidden)
    sh.ctx.setLineWidth(1.6)
    sh.ctx.setLineDash(phase: 0, lengths: [8, 6])
    sh.ctx.addArc(center: g.p(10.125, 0.75), radius: g.d(7.5),
                  startAngle: .pi / 2, endAngle: 0, clockwise: true)
    sh.ctx.strokePath()
    sh.ctx.restoreGState()
    sh.note("FLIPS DOWN 90°", from: g.p(10.125, 4.5),
            to: CGPoint(x: g.x(10.5) + 40, y: g.y(7)), font: fNote)

    sh.dimH(g.x(0), g.x(10.5), y: g.y(-0.75), "10½\"", font: fDim, witnessFrom: g.y(0))
    viewLabel(sh, "Section B-B", at: CGPoint(x: g.x(5.25), y: 208))

    return sh
}

// MARK: - Sheet 4 — Dartboard Cabinet

func dartboardCabinet() -> Sheet {
    let sh = Sheet()
    chrome(sh, title: "DIY Dartboard Cabinet",
           subtitle: "26 × 26 × 4½ in — frame-and-panel doors — red oak")

    // Front elevation, doors open.
    let f = Proj(ox: 200, oy: 300, s: 17)
    sh.rect(f.r(0, 0, 26, 26))
    sh.rect(f.r(0.75, 0.75, 24.5, 24.5), Ink.object, 2)
    // Backer board + dartboard.
    sh.rect(f.r(3, 3, 20, 20), Ink.hidden, 1.8)
    sh.circle(f.p(13, 13), radius: f.d(8.875), Ink.object, 3)
    sh.circle(f.p(13, 13), radius: f.d(6.7), Ink.dim, 1.6)
    sh.circle(f.p(13, 13), radius: f.d(4.25), Ink.dim, 1.6)
    sh.circle(f.p(13, 13), radius: f.d(0.8), Ink.dim, 1.6)
    // Twenty wedges.
    for i in 0..<20 {
        let a = CGFloat(i) * .pi / 10 + .pi / 20
        sh.line(f.p(13, 13),
                CGPoint(x: f.x(13) + cos(a) * f.d(8.875), y: f.y(13) + sin(a) * f.d(8.875)),
                Ink.faint, 1.2)
    }
    sh.note("17¾\" DIA BOARD", from: f.p(13, 21.9),
            to: CGPoint(x: f.x(13), y: f.y(29)), font: fNote, align: .center)

    sh.dimH(f.x(0), f.x(26), y: f.y(-1.5), "26\"", font: fDim, witnessFrom: f.y(0))
    sh.dimV(f.y(0), f.y(26), x: f.x(-1.5), "26\"", font: fDim, witnessFrom: f.x(0))
    viewLabel(sh, "Front elevation — doors open", at: CGPoint(x: f.x(13), y: 208))

    // Plan section showing the doors swung out.
    let g = Proj(ox: 940, oy: 360, s: 17)
    sh.hatch(g.r(0, 0, 26, 0.5))
    sh.rect(g.r(0, 0, 26, 0.5), Ink.object, 2)       // back panel
    sh.hatch(g.r(0, 0, 0.75, 4.5))
    sh.hatch(g.r(25.25, 0, 0.75, 4.5))
    sh.rect(g.r(0, 0, 0.75, 4.5), Ink.object, 2.5)
    sh.rect(g.r(25.25, 0, 0.75, 4.5), Ink.object, 2.5)
    // Doors, hinged at each outer edge and swung 90°.
    sh.rect(g.r(-0.75, 4.5, 0.75, 13), Ink.object, 2.5)
    sh.rect(g.r(26, 4.5, 0.75, 13), Ink.object, 2.5)
    sh.note("DOORS SWING 90°", from: g.p(13, 0.25),
            to: CGPoint(x: g.x(13), y: g.y(19.4)), font: fNote, align: .center)
    sh.dimV(g.y(0), g.y(4.5), x: g.x(27.8), "4½\"", font: fDim, witnessFrom: g.x(26.75))
    viewLabel(sh, "Plan section", at: CGPoint(x: g.x(13), y: 208))

    return sh
}

// MARK: - Sheet 5 — Push Sticks

func pushSticks() -> Sheet {
    let sh = Sheet()
    chrome(sh, title: "Push Sticks",
           subtitle: "shaper origin — ⅛\" bit — ½ in baltic birch")

    // Two profiles side by side, drawn as outlines to cut.
    let a = Proj(ox: 220, oy: 400, s: 30)
    // Long push stick: 14 × 5 body with a heel and a grip.
    let path = CGMutablePath()
    let pts: [(CGFloat, CGFloat)] = [
        (0, 0), (14, 0), (14, 0.5), (2.5, 0.5), (2.5, 1.25), (13, 1.25),
        (13, 3), (10, 5.5), (4.5, 5.5), (2.5, 4), (0, 4),
    ]
    path.move(to: a.p(pts[0].0, pts[0].1))
    for p in pts.dropFirst() { path.addLine(to: a.p(p.0, p.1)) }
    path.closeSubpath()
    sh.ctx.saveGState()
    sh.ctx.setStrokeColor(Ink.object)
    sh.ctx.setLineWidth(3.5)
    sh.ctx.addPath(path)
    sh.ctx.strokePath()
    sh.ctx.restoreGState()
    sh.circle(a.p(7, 3.1), radius: a.d(0.9), Ink.object, 3)   // finger hole
    sh.note("HEEL, ½ × 1½", from: a.p(1.2, 0.25),
            to: CGPoint(x: a.x(0) - 30, y: a.y(-1.6)), font: fNote, align: .right)
    sh.dimH(a.x(0), a.x(14), y: a.y(-0.9), "14\"", font: fDim, witnessFrom: a.y(0))
    sh.dimV(a.y(0), a.y(5.5), x: a.x(15.2), "5½\"", font: fDim, witnessFrom: a.x(13))
    viewLabel(sh, "Profile — long stick", at: CGPoint(x: a.x(7), y: 290))

    // Short push block.
    let b = Proj(ox: 900, oy: 400, s: 30)
    let path2 = CGMutablePath()
    let pts2: [(CGFloat, CGFloat)] = [
        (0, 0), (8, 0), (8, 4.5), (6, 5.5), (1.5, 5.5), (0, 4.5),
    ]
    path2.move(to: b.p(pts2[0].0, pts2[0].1))
    for p in pts2.dropFirst() { path2.addLine(to: b.p(p.0, p.1)) }
    path2.closeSubpath()
    sh.ctx.saveGState()
    sh.ctx.setStrokeColor(Ink.object)
    sh.ctx.setLineWidth(3.5)
    sh.ctx.addPath(path2)
    sh.ctx.strokePath()
    sh.ctx.restoreGState()
    sh.rect(b.r(0, -0.5, 8, 0.5), Ink.hidden, 2)   // glued-on heel
    sh.circle(b.p(4, 3.2), radius: b.d(0.9), Ink.object, 3)
    sh.note("GLUE-ON HEEL", from: b.p(4, -0.25),
            to: CGPoint(x: b.x(8) + 40, y: b.y(-1.6)), font: fNote)
    sh.dimH(b.x(0), b.x(8), y: b.y(-1.9), "8\"", font: fDim, witnessFrom: b.y(-0.5))
    viewLabel(sh, "Profile — push block", at: CGPoint(x: b.x(4), y: 290))

    return sh
}

// MARK: - Sheet 6 — Clamping Squares

func clampingSquares() -> Sheet {
    let sh = Sheet()
    chrome(sh, title: "Clamping Squares",
           subtitle: "shaper origin — ⅛\" bit — ¾ in baltic birch")

    // The L, 8 × 8 with 2½ legs.
    let a = Proj(ox: 250, oy: 330, s: 52)
    let path = CGMutablePath()
    let pts: [(CGFloat, CGFloat)] = [(0, 0), (8, 0), (8, 2.5), (2.5, 2.5), (2.5, 8), (0, 8)]
    path.move(to: a.p(pts[0].0, pts[0].1))
    for p in pts.dropFirst() { path.addLine(to: a.p(p.0, p.1)) }
    path.closeSubpath()
    sh.ctx.saveGState()
    sh.ctx.setStrokeColor(Ink.object)
    sh.ctx.setLineWidth(3.5)
    sh.ctx.addPath(path)
    sh.ctx.strokePath()
    sh.ctx.restoreGState()

    // Relief at the inside corner — the detail that stops glue welding the jig on.
    sh.circle(a.p(2.5, 2.5), radius: a.d(0.5), Ink.object, 3)
    sh.note("RELIEF, 1\" DIA AT INSIDE CORNER", from: a.p(2.5, 2.5),
            to: CGPoint(x: a.x(8) + 40, y: a.y(5.5)), font: fNote)
    // Clamp windows.
    sh.rect(a.r(4.25, 0.75, 2.75, 1), Ink.object, 2.5)
    sh.rect(a.r(0.75, 4.25, 1, 2.75), Ink.object, 2.5)
    sh.note("CLAMP WINDOW", from: a.p(5.6, 1.25),
            to: CGPoint(x: a.x(8) + 40, y: a.y(1.4)), font: fNote)

    sh.dimH(a.x(0), a.x(8), y: a.y(-0.55), "8\"", font: fDim, witnessFrom: a.y(0))
    sh.dimV(a.y(0), a.y(8), x: a.x(-0.55), "8\"", font: fDim, witnessFrom: a.x(0))
    sh.dimH(a.x(0), a.x(2.5), y: a.y(8.7), "2½\"", font: fDim, witnessFrom: a.y(8))
    viewLabel(sh, "Profile", at: CGPoint(x: a.x(4), y: 244))

    // Nesting diagram — two squares off one blank, the second turned 180° so the
    // legs interlock. This is why the seed calls for a 10½ × 8 offcut rather
    // than a quarter sheet.
    let b = Proj(ox: 1010, oy: 420, s: 34)
    sh.rect(b.r(0, 0, 10.5, 8), Ink.frame, 2, dash: [8, 6])
    let outline: [(CGFloat, CGFloat)] = [(0, 0), (8, 0), (8, 2.5), (2.5, 2.5), (2.5, 8), (0, 8)]
    for (dx, dy, turned) in [(CGFloat(0), CGFloat(0), false), (CGFloat(10.5), CGFloat(8), true)] {
        let sign: CGFloat = turned ? -1 : 1
        let mapped = outline.map { (dx + $0.0 * sign, dy + $0.1 * sign) }
        let pathN = CGMutablePath()
        pathN.move(to: b.p(mapped[0].0, mapped[0].1))
        for p in mapped.dropFirst() { pathN.addLine(to: b.p(p.0, p.1)) }
        pathN.closeSubpath()
        sh.ctx.saveGState()
        sh.ctx.setStrokeColor(Ink.object)
        sh.ctx.setLineWidth(2.5)
        sh.ctx.addPath(pathN)
        sh.ctx.strokePath()
        sh.ctx.restoreGState()
    }
    sh.note("SECOND SQUARE TURNED 180°", from: b.p(6.5, 5.5),
            to: CGPoint(x: b.x(5.25), y: b.y(9.4)), font: fNote, align: .center)
    sh.dimH(b.x(0), b.x(10.5), y: b.y(-0.8), "10½ × 8 BLANK", font: fDim, witnessFrom: b.y(0))
    viewLabel(sh, "Nesting", at: CGPoint(x: b.x(5.25), y: 244))

    return sh
}

// MARK: - Sheet 7 — Kapex Zero Clearance Fence

func kapexFence() -> Sheet {
    let sh = Sheet()
    chrome(sh, title: "Kapex Zero Clearance Fence",
           subtitle: "shaper origin — sub-fence pair — ½ in mdf or baltic birch")

    // Face view of one sub-fence: 13 × 3½.
    let f = Proj(ox: 230, oy: 560, s: 66)
    sh.rect(f.r(0, 0, 13, 3.5))
    // Counter-bored slots on the saw's bolt pattern.
    for x in [2.0, 6.5, 11.0] {
        let cx = CGFloat(x)
        sh.rect(f.r(cx - 0.25, 1.25, 0.5, 1), Ink.object, 2.5)
        sh.circle(f.p(cx, 1.75), radius: f.d(0.45), Ink.hidden, 1.8, dash: [7, 5])
    }
    sh.note("M6 SLOT + ⅞\" COUNTERBORE", from: f.p(6.5, 1.75),
            to: CGPoint(x: f.x(13) + 40, y: f.y(3.1)), font: fNote)
    sh.note("MEASURE SLOT SPACING OFF THE SAW", from: f.p(2, 1.75),
            to: CGPoint(x: f.x(6.5), y: f.y(5.9)), font: fNote, align: .center)

    sh.dimH(f.x(0), f.x(13), y: f.y(-0.5), "13\"", font: fDim, witnessFrom: f.y(0))
    sh.dimV(f.y(0), f.y(3.5), x: f.x(-0.4), "3½\"", font: fDim, witnessFrom: f.x(0))
    sh.dimH(f.x(2), f.x(6.5), y: f.y(4.2), "4½\"", font: fDim, witnessFrom: f.y(3.5))
    sh.dimH(f.x(6.5), f.x(11), y: f.y(4.2), "4½\"", font: fDim, witnessFrom: f.y(3.5))
    viewLabel(sh, "Face — one of two", at: CGPoint(x: f.x(6.5), y: 490))

    // Section through the fence and the kerf the saw opens for itself.
    let g = Proj(ox: 430, oy: 300, s: 66)
    sh.hatch(g.r(0, 0, 6, 0.5))
    sh.rect(g.r(0, 0, 6, 0.5), Ink.object, 3)
    sh.fill(g.r(2.6, -0.15, 0.16, 0.8), Ink.ground)
    sh.line(g.p(2.6, -0.15), g.p(2.6, 0.65), Ink.object, 2.5)
    sh.line(g.p(2.76, -0.15), g.p(2.76, 0.65), Ink.object, 2.5)
    sh.note("BLADE OPENS ITS OWN KERF ON THE FIRST CUT",
            from: g.p(2.68, 0.25), to: CGPoint(x: g.x(6) + 40, y: g.y(0.9)), font: fNote)
    sh.dimH(g.x(0), g.x(6), y: g.y(-0.7), "½\" STOCK", font: fDim, witnessFrom: g.y(0))
    viewLabel(sh, "Section — kerf detail", at: CGPoint(x: g.x(3), y: 200))

    return sh
}

// MARK: - Run

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let sheets: [(String, () -> Sheet)] = [
    ("plan-hand-tool-cabinet", handToolCabinet),
    ("plan-serving-tray", servingTray),
    ("plan-bread-box", breadBox),
    ("plan-dartboard-cabinet", dartboardCabinet),
    ("plan-push-sticks", pushSticks),
    ("plan-clamping-squares", clampingSquares),
    ("plan-kapex-fence", kapexFence),
]

for (name, make) in sheets {
    let url = outDir.appendingPathComponent("\(name).png")
    make().write(to: url)
    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
    let size = (attrs?[.size] as? Int) ?? 0
    print("wrote \(name).png  \(size / 1024) KB")
}
