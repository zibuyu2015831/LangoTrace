import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct IconSpec {
    let filename: String
    let pixels: Int
}

let specs: [IconSpec] = [
    .init(filename: "Icon-16@1x.png", pixels: 16),
    .init(filename: "Icon-16@2x.png", pixels: 32),
    .init(filename: "Icon-20@1x.png", pixels: 20),
    .init(filename: "Icon-20@2x.png", pixels: 40),
    .init(filename: "Icon-20@3x.png", pixels: 60),
    .init(filename: "Icon-29@1x.png", pixels: 29),
    .init(filename: "Icon-29@2x.png", pixels: 58),
    .init(filename: "Icon-29@3x.png", pixels: 87),
    .init(filename: "Icon-32@1x.png", pixels: 32),
    .init(filename: "Icon-32@2x.png", pixels: 64),
    .init(filename: "Icon-40@1x.png", pixels: 40),
    .init(filename: "Icon-40@2x.png", pixels: 80),
    .init(filename: "Icon-40@3x.png", pixels: 120),
    .init(filename: "Icon-60@2x.png", pixels: 120),
    .init(filename: "Icon-60@3x.png", pixels: 180),
    .init(filename: "Icon-76@1x.png", pixels: 76),
    .init(filename: "Icon-76@2x.png", pixels: 152),
    .init(filename: "Icon-83.5@2x.png", pixels: 167),
    .init(filename: "Icon-128@1x.png", pixels: 128),
    .init(filename: "Icon-128@2x.png", pixels: 256),
    .init(filename: "Icon-256@1x.png", pixels: 256),
    .init(filename: "Icon-256@2x.png", pixels: 512),
    .init(filename: "Icon-512@1x.png", pixels: 512),
    .init(filename: "Icon-512@2x.png", pixels: 1024),
    .init(filename: "Icon-1024.png", pixels: 1024),
]

let outputURL = URL(fileURLWithPath: "LangoTraceApp/Resources/Assets.xcassets/AppIcon.appiconset")

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func renderIcon(size: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Failed to create CGContext")
    }

    let scale = CGFloat(size) / 1024.0
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    context.setFillColor(color(0.035, 0.255, 0.235))
    context.fill(rect)

    let pageRect = CGRect(x: 242 * scale, y: 176 * scale, width: 540 * scale, height: 672 * scale)
    let pagePath = CGPath(
        roundedRect: pageRect,
        cornerWidth: 86 * scale,
        cornerHeight: 86 * scale,
        transform: nil
    )
    context.setFillColor(color(0.940, 0.920, 0.865))
    context.addPath(pagePath)
    context.fillPath()

    let tracePath = CGMutablePath()
    tracePath.move(to: CGPoint(x: 330 * scale, y: 640 * scale))
    tracePath.addCurve(
        to: CGPoint(x: 698 * scale, y: 360 * scale),
        control1: CGPoint(x: 420 * scale, y: 784 * scale),
        control2: CGPoint(x: 600 * scale, y: 250 * scale)
    )
    context.addPath(tracePath)
    context.setStrokeColor(color(0.035, 0.255, 0.235))
    context.setLineWidth(max(2, 52 * scale))
    context.setLineCap(.round)
    context.strokePath()

    let accentRect = CGRect(x: 645 * scale, y: 635 * scale, width: 112 * scale, height: 112 * scale)
    context.setFillColor(color(0.700, 0.520, 0.220))
    context.fillEllipse(in: accentRect)

    guard let image = context.makeImage() else {
        fatalError("Failed to render icon")
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        fatalError("Failed to create destination for \(url.lastPathComponent)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Failed to write \(url.lastPathComponent)")
    }
}

for spec in specs {
    writePNG(renderIcon(size: spec.pixels), to: outputURL.appendingPathComponent(spec.filename))
}
