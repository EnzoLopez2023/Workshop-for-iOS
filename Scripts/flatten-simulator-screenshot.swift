#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard (3...4).contains(CommandLine.arguments.count) else {
    fputs("usage: flatten-simulator-screenshot.swift <input> <output.jpg> [display-mask.png]\n", stderr)
    exit(64)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    fputs("error: could not decode \(inputURL.path)\n", stderr)
    exit(65)
}

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

guard let context = CGContext(
    data: nil,
    width: image.width,
    height: image.height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: bitmapInfo.rawValue
) else {
    fputs("error: could not create output context\n", stderr)
    exit(70)
}

context.setFillColor(CGColor(gray: 0, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))

if CommandLine.arguments.count == 4 {
    let maskURL = URL(fileURLWithPath: CommandLine.arguments[3])
    guard let maskSource = CGImageSourceCreateWithURL(maskURL as CFURL, nil),
          let mask = CGImageSourceCreateImageAtIndex(maskSource, 0, nil),
          mask.width == image.width,
          mask.height == image.height
    else {
        fputs("error: display mask must match the source dimensions\n", stderr)
        exit(65)
    }
    context.clip(
        to: CGRect(x: 0, y: 0, width: image.width, height: image.height),
        mask: mask
    )
}

context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

guard let flattened = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
          outputURL as CFURL,
          UTType.jpeg.identifier as CFString,
          1,
          nil
      )
else {
    fputs("error: could not create \(outputURL.path)\n", stderr)
    exit(73)
}

let properties = [
    kCGImageDestinationLossyCompressionQuality: 0.95
] as CFDictionary
CGImageDestinationAddImage(destination, flattened, properties)

guard CGImageDestinationFinalize(destination) else {
    fputs("error: could not write \(outputURL.path)\n", stderr)
    exit(74)
}
