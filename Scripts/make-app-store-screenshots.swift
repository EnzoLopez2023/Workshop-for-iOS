#!/usr/bin/env swift
//
// Composes raw Simulator captures into App Store-ready iPhone 6.9-inch and
// iPad 13-inch marketing screenshots.
//
// Usage:
//   swift Scripts/make-app-store-screenshots.swift <capture-dir> [output-dir]
//

import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

private let scriptDirectory = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent().standardizedFileURL
private let repositoryRoot = scriptDirectory.deletingLastPathComponent()
private let sourceDirectory = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : repositoryRoot.appendingPathComponent("AppStore/Captures")
private let outputDirectory = CommandLine.arguments.count > 2
    ? URL(fileURLWithPath: CommandLine.arguments[2])
    : repositoryRoot.appendingPathComponent("AppStore/Screenshots")
private let fontsDirectory = repositoryRoot.appendingPathComponent("Fonts")

private func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

private enum Ink {
    static let ground = color(0x0C0F10)
    static let flap = color(0x171B1D)
    static let line = color(0x2C3335)
    static let steel = color(0x2B3238)
    static let steelLight = color(0x566269)
    static let text = color(0xEFF2ED)
    static let muted = color(0xA8B3B0)
    static let amber = color(0xFFB400)
}

private func font(_ file: String, size: CGFloat) -> CTFont {
    let url = fontsDirectory.appendingPathComponent(file) as CFURL
    guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor],
          let descriptor = descriptors.first
    else {
        return CTFontCreateWithName("Menlo-Bold" as CFString, size, nil)
    }
    return CTFontCreateWithFontDescriptor(descriptor, size, nil)
}

private let boardBold = { (size: CGFloat) in font("MartianMonoBoard-Bold.ttf", size: size) }
private let boardSemibold = { (size: CGFloat) in font("MartianMonoBoard-SemiBold.ttf", size: size) }
private let uiRegular = { (size: CGFloat) in font("ArchivoWS-Regular.ttf", size: size) }

private func attributes(font: CTFont, color: CGColor, tracking: CGFloat) -> [NSAttributedString.Key: Any] {
    [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        NSAttributedString.Key(kCTKernAttributeName as String): tracking,
    ]
}

private struct ScreenshotSpec {
    enum Device: Equatable {
        case iPhone
        case iPad

        var canvas: CGSize {
            switch self {
            case .iPhone: CGSize(width: 1320, height: 2868)
            case .iPad: CGSize(width: 2064, height: 2752)
            }
        }

        var folder: String {
            switch self {
            case .iPhone: "iPhone-6.9"
            case .iPad: "iPad-13"
            }
        }
    }

    let device: Device
    let source: String
    let output: String
    let title: [String]
    let subtitle: String
}

private let specs: [ScreenshotSpec] = [
    .init(
        device: .iPhone,
        source: "workshop-iphone-dashboard.png",
        output: "01-every-build-on-the-board.png",
        title: ["EVERY BUILD,", "ON THE BOARD."],
        subtitle: "Projects, plans, parts, and costs—legible before the first cut."
    ),
    .init(
        device: .iPhone,
        source: "workshop-iphone-project.png",
        output: "02-the-whole-build-together.png",
        title: ["THE WHOLE BUILD,", "STILL TOGETHER."],
        subtitle: "Plans, parts, materials, photos, and finish notes stay together."
    ),
    .init(
        device: .iPhone,
        source: "workshop-iphone-shopping.png",
        output: "03-one-shopping-list.png",
        title: ["ONE LIST FOR", "THE WHOLE SHOP."],
        subtitle: "Every project's materials, together and ready to check off."
    ),
    .init(
        device: .iPhone,
        source: "workshop-iphone-tables.png",
        output: "04-measure-twice-type-less.png",
        title: ["MEASURE TWICE.", "TYPE LESS."],
        subtitle: "Millimeters, decimal inches, and fractions—live at the bench."
    ),
    .init(
        device: .iPad,
        source: "workshop-ipad-dashboard.png",
        output: "01-the-whole-shop-one-glance.png",
        title: ["THE WHOLE SHOP.", "ONE GLANCE."],
        subtitle: "A real iPad workspace for projects, Shaper files, templates, and the numbers that matter."
    ),
    .init(
        device: .iPad,
        source: "workshop-ipad-project.png",
        output: "02-plans-become-the-record.png",
        title: ["PLANS BECOME", "THE BUILD RECORD."],
        subtitle: "Your drawing, cut list, materials, costs, and progress—without the clutter."
    ),
    .init(
        device: .iPad,
        source: "workshop-ipad-shopping.png",
        output: "03-the-supply-run-sorted.png",
        title: ["THE SUPPLY RUN,", "ALREADY SORTED."],
        subtitle: "Every material grouped by project, ready to check off in the aisle."
    ),
]

private final class Canvas {
    let size: CGSize
    let context: CGContext

    init(size: CGSize) {
        self.size = size
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            fatalError("Could not create screenshot canvas")
        }
        self.context = context
    }

    func rectFromTop(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: x, y: size.height - y - height, width: width, height: height)
    }

    func fill(_ rect: CGRect, color: CGColor) {
        context.setFillColor(color)
        context.fill(rect)
    }

    func stroke(_ rect: CGRect, color: CGColor, width: CGFloat) {
        context.setStrokeColor(color)
        context.setLineWidth(width)
        context.stroke(rect)
    }

    func text(
        _ value: String,
        x: CGFloat,
        y: CGFloat,
        font: CTFont,
        color: CGColor,
        tracking: CGFloat = 0
    ) {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(
                string: value,
                attributes: attributes(font: font, color: color, tracking: tracking)
            )
        )
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        context.textPosition = CGPoint(x: x, y: size.height - y - ascent)
        CTLineDraw(line, context)
    }

    func image(_ image: CGImage, topRect: CGRect, cornerRadius: CGFloat) {
        let rect = rectFromTop(
            x: topRect.minX,
            y: topRect.minY,
            width: topRect.width,
            height: topRect.height
        )
        context.saveGState()
        context.addPath(
            CGPath(
                roundedRect: rect,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )
        )
        context.clip()
        context.draw(image, in: rect)
        context.restoreGState()
    }

    func roundedRect(_ topRect: CGRect, radius: CGFloat, fill: CGColor, stroke: CGColor? = nil) {
        let rect = rectFromTop(
            x: topRect.minX,
            y: topRect.minY,
            width: topRect.width,
            height: topRect.height
        )
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        context.addPath(path)
        context.setFillColor(fill)
        context.fillPath()
        if let stroke {
            context.addPath(path)
            context.setStrokeColor(stroke)
            context.setLineWidth(3)
            context.strokePath()
        }
    }
}

private func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        fatalError("Could not load \(url.path)")
    }
    return image
}

private func write(_ image: CGImage, to url: URL) {
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        fatalError("Could not create \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write \(url.path)")
    }
}

private func drawBackground(_ canvas: Canvas) {
    canvas.fill(
        CGRect(origin: .zero, size: canvas.size),
        color: Ink.ground
    )
    canvas.context.setStrokeColor(color(0x2C3335, alpha: 0.45))
    canvas.context.setLineWidth(1)
    var x: CGFloat = 0
    while x <= canvas.size.width {
        canvas.context.move(to: CGPoint(x: x, y: 0))
        canvas.context.addLine(to: CGPoint(x: x, y: canvas.size.height))
        x += 96
    }
    var y: CGFloat = 0
    while y <= canvas.size.height {
        canvas.context.move(to: CGPoint(x: 0, y: y))
        canvas.context.addLine(to: CGPoint(x: canvas.size.width, y: y))
        y += 96
    }
    canvas.context.strokePath()
}

private func render(_ spec: ScreenshotSpec) {
    let canvas = Canvas(size: spec.device.canvas)
    drawBackground(canvas)

    let edge: CGFloat = spec.device == .iPhone ? 80 : 110
    let railWidth = canvas.size.width - edge * 2
    canvas.fill(
        canvas.rectFromTop(x: edge, y: 68, width: railWidth, height: 54),
        color: Ink.steel
    )
    canvas.fill(
        canvas.rectFromTop(x: edge + 18, y: 89, width: 12, height: 12),
        color: Ink.amber
    )
    canvas.text(
        "THE WORKSHOP",
        x: edge + 46,
        y: 80,
        font: boardSemibold(spec.device == .iPhone ? 28 : 30),
        color: Ink.text,
        tracking: 3
    )
    canvas.text(
        "FREE · IPHONE & IPAD · BUILT FOR THE SHOP",
        x: edge + 46,
        y: 140,
        font: boardSemibold(spec.device == .iPhone ? 19 : 21),
        color: Ink.muted,
        tracking: 2
    )

    let titleSize: CGFloat = spec.device == .iPhone ? 88 : 84
    let titleX = edge
    let titleY: CGFloat = spec.device == .iPhone ? 192 : 180
    let titleGap: CGFloat = spec.device == .iPhone ? 104 : 100
    for (index, line) in spec.title.enumerated() {
        canvas.text(
            line,
            x: titleX,
            y: titleY + CGFloat(index) * titleGap,
            font: boardBold(titleSize),
            color: index == spec.title.count - 1 ? Ink.amber : Ink.text,
            tracking: -1
        )
    }
    canvas.text(
        spec.subtitle,
        x: edge,
        y: titleY + CGFloat(spec.title.count) * titleGap + 24,
        font: uiRegular(spec.device == .iPhone ? 38 : 36),
        color: Ink.muted
    )

    let source = loadImage(sourceDirectory.appendingPathComponent(spec.source))
    let outer: CGRect
    let screen: CGRect
    let outerRadius: CGFloat
    let screenRadius: CGFloat
    switch spec.device {
    case .iPhone:
        outer = CGRect(x: 136, y: 650, width: 1048, height: 2200)
        screen = CGRect(x: 162, y: 676, width: 996, height: 2165)
        outerRadius = 92
        screenRadius = 72
    case .iPad:
        outer = CGRect(x: 214, y: 575, width: 1636, height: 2165)
        screen = CGRect(x: 244, y: 605, width: 1576, height: 2101)
        outerRadius = 70
        screenRadius = 48
    }
    canvas.roundedRect(outer, radius: outerRadius, fill: Ink.flap, stroke: Ink.steelLight)
    canvas.image(source, topRect: screen, cornerRadius: screenRadius)

    guard let image = canvas.context.makeImage() else {
        fatalError("Could not finish \(spec.output)")
    }
    let destination = outputDirectory
        .appendingPathComponent(spec.device.folder)
        .appendingPathComponent(spec.output)
    write(image, to: destination)
    print(destination.path)
}

for spec in specs {
    render(spec)
}
