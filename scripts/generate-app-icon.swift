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

func drawLinearGradient(
    in context: CGContext,
    colors: [CGColor],
    locations: [CGFloat],
    start: CGPoint,
    end: CGPoint
) {
    guard let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors as CFArray,
        locations: locations
    ) else {
        fatalError("Failed to create gradient")
    }
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
}

func drawRadialGradient(
    in context: CGContext,
    colors: [CGColor],
    locations: [CGFloat],
    center: CGPoint,
    radius: CGFloat
) {
    guard let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors as CFArray,
        locations: locations
    ) else {
        fatalError("Failed to create radial gradient")
    }
    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
}

func drawRoundedCapsule(
    in context: CGContext,
    rect: CGRect,
    angle: CGFloat,
    fill: CGColor
) {
    context.saveGState()
    context.translateBy(x: rect.midX, y: rect.midY)
    context.rotate(by: angle)
    let rotatedRect = CGRect(
        x: -rect.width / 2,
        y: -rect.height / 2,
        width: rect.width,
        height: rect.height
    )
    context.addPath(CGPath(
        roundedRect: rotatedRect,
        cornerWidth: rect.height / 2,
        cornerHeight: rect.height / 2,
        transform: nil
    ))
    context.setFillColor(fill)
    context.fillPath()
    context.restoreGState()
}

func drawBackground(in context: CGContext, rect: CGRect, scale: CGFloat) {
    drawLinearGradient(
        in: context,
        colors: [
            color(0.137, 0.208, 0.184),
            color(0.282, 0.384, 0.306),
            color(0.082, 0.247, 0.278),
        ],
        locations: [0, 0.52, 1],
        start: CGPoint(x: rect.minX, y: rect.minY),
        end: CGPoint(x: rect.maxX, y: rect.maxY)
    )

    drawRadialGradient(
        in: context,
        colors: [
            color(1.000, 0.961, 0.894, 0.140),
            color(1.000, 0.961, 0.894, 0.000),
        ],
        locations: [0, 1],
        center: CGPoint(x: 800 * scale, y: 205 * scale),
        radius: 260 * scale
    )

    drawRadialGradient(
        in: context,
        colors: [
            color(0.690, 0.761, 0.557, 0.145),
            color(0.690, 0.761, 0.557, 0.000),
        ],
        locations: [0, 1],
        center: CGPoint(x: 170 * scale, y: 790 * scale),
        radius: 330 * scale
    )
}

func drawGlint(in context: CGContext, scale: CGFloat) {
    let glintRect = CGRect(x: 312 * scale, y: 474 * scale, width: 418 * scale, height: 60 * scale)
    context.saveGState()
    context.translateBy(x: glintRect.midX, y: glintRect.midY)
    context.rotate(by: -18 * .pi / 180)
    let rotatedGlint = CGRect(
        x: -glintRect.width / 2,
        y: -glintRect.height / 2,
        width: glintRect.width,
        height: glintRect.height
    )
    context.addPath(CGPath(
        roundedRect: rotatedGlint,
        cornerWidth: rotatedGlint.height / 2,
        cornerHeight: rotatedGlint.height / 2,
        transform: nil
    ))
    context.clip()
    drawLinearGradient(
        in: context,
        colors: [
            color(0.675, 0.761, 0.557, 0.620),
            color(1.000, 0.961, 0.894, 0.700),
            color(0.780, 0.604, 0.294, 0.720),
        ],
        locations: [0, 0.56, 1],
        start: CGPoint(x: rotatedGlint.minX, y: rotatedGlint.midY),
        end: CGPoint(x: rotatedGlint.maxX, y: rotatedGlint.midY)
    )
    context.restoreGState()
}

func makeSeedPath(scale: CGFloat) -> CGPath {
    let seedPath = CGMutablePath()
    seedPath.move(to: CGPoint(x: 506 * scale, y: 221 * scale))
    seedPath.addLine(to: CGPoint(x: 763 * scale, y: 400 * scale))
    seedPath.addLine(to: CGPoint(x: 709 * scale, y: 679 * scale))
    seedPath.addLine(to: CGPoint(x: 474 * scale, y: 780 * scale))
    seedPath.addLine(to: CGPoint(x: 270 * scale, y: 573 * scale))
    seedPath.addLine(to: CGPoint(x: 313 * scale, y: 338 * scale))
    seedPath.closeSubpath()
    return seedPath
}

func drawSeed(in context: CGContext, scale: CGFloat) {
    let seedPath = makeSeedPath(scale: scale)

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: 18 * scale),
        blur: 30 * scale,
        color: color(0.012, 0.098, 0.086, 0.240)
    )
    context.addPath(seedPath)
    context.setFillColor(color(0.957, 0.925, 0.871))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(seedPath)
    context.clip()
    drawSeedSurface(in: context, scale: scale)
    context.restoreGState()
}

func drawSeedSurface(in context: CGContext, scale: CGFloat) {
    drawLinearGradient(
        in: context,
        colors: [
            color(1.000, 0.976, 0.933),
            color(0.961, 0.929, 0.871),
            color(0.835, 0.800, 0.745),
        ],
        locations: [0, 0.42, 1],
        start: CGPoint(x: 320 * scale, y: 240 * scale),
        end: CGPoint(x: 720 * scale, y: 760 * scale)
    )

    let highlightPath = CGMutablePath()
    highlightPath.move(to: CGPoint(x: 350 * scale, y: 605 * scale))
    highlightPath.addLine(to: CGPoint(x: 642 * scale, y: 310 * scale))
    context.addPath(highlightPath)
    context.setStrokeColor(color(1, 1, 1, 0.280))
    context.setLineWidth(max(1, 15 * scale))
    context.setLineCap(.round)
    context.strokePath()

    let shadePath = CGMutablePath()
    shadePath.move(to: CGPoint(x: 610 * scale, y: 390 * scale))
    shadePath.addLine(to: CGPoint(x: 709 * scale, y: 679 * scale))
    shadePath.addLine(to: CGPoint(x: 474 * scale, y: 780 * scale))
    shadePath.closeSubpath()
    context.addPath(shadePath)
    context.setFillColor(color(0.251, 0.353, 0.271, 0.105))
    context.fillPath()
}

func drawLanguageGlyph(in context: CGContext, scale: CGFloat) {
    context.saveGState()
    context.translateBy(x: 512 * scale, y: 502 * scale)
    context.rotate(by: -21 * .pi / 180)

    let glyphPath = CGMutablePath()
    glyphPath.move(to: CGPoint(x: -58 * scale, y: -126 * scale))
    glyphPath.addLine(to: CGPoint(x: -58 * scale, y: 76 * scale))
    glyphPath.addLine(to: CGPoint(x: 68 * scale, y: 76 * scale))
    context.addPath(glyphPath)
    context.setStrokeColor(color(0.204, 0.392, 0.306))
    context.setLineWidth(max(3, 44 * scale))
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()

    drawRoundedCapsule(
        in: context,
        rect: CGRect(x: -2 * scale, y: -46 * scale, width: 150 * scale, height: 38 * scale),
        angle: -2 * .pi / 180,
        fill: color(0.780, 0.604, 0.294)
    )
    context.restoreGState()
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

    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1, y: -1)

    drawBackground(in: context, rect: rect, scale: scale)
    drawGlint(in: context, scale: scale)
    drawSeed(in: context, scale: scale)
    drawLanguageGlyph(in: context, scale: scale)

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
