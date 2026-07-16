#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

// dimmi 品牌资源的唯一生成入口。
// 彩色标沿用已确认方案：橙红 d + 金黄 i、相向的交流留白与双眼。
// 菜单栏标是同源的单色 di 线标，专门针对 16pt 做光学加粗。

private let fileManager = FileManager.default
private let projectRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let assetsRoot = projectRoot.appendingPathComponent("Resources/Assets.xcassets", isDirectory: true)
private let appIconRoot = assetsRoot.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
private let brandMarkRoot = assetsRoot.appendingPathComponent("DimmiBrandMark.imageset", isDirectory: true)
private let menuBarRoot = assetsRoot.appendingPathComponent("MenuBarIcon.imageset", isDirectory: true)
private let brandRoot = projectRoot.appendingPathComponent("Resources/Brand", isDirectory: true)

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}

private struct NormalizedCanvas {
    let rect: CGRect

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }

    func ellipse(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX + x * rect.width,
            y: rect.minY + y * rect.height,
            width: width * rect.width,
            height: height * rect.height
        )
    }
}

private func makeBitmap(size: Int, draw: (CGContext, CGFloat) -> Void) -> NSBitmapImageRep? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    guard let context = NSGraphicsContext.current?.cgContext else { return nil }

    let side = CGFloat(size)
    context.clear(CGRect(x: 0, y: 0, width: side, height: side))
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    // 下面所有路径均使用更直观的左上角原点。
    context.translateBy(x: 0, y: side)
    context.scaleBy(x: 1, y: -1)
    draw(context, side)
    return bitmap
}

private func writePNG(size: Int, to url: URL, draw: (CGContext, CGFloat) -> Void) throws {
    guard let bitmap = makeBitmap(size: size, draw: draw),
          let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "dimmi.brand", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法渲染 \(url.lastPathComponent)"])
    }
    try data.write(to: url, options: .atomic)
}

private func gradient(
    _ context: CGContext,
    path: CGPath,
    colors: [NSColor],
    start: CGPoint,
    end: CGPoint
) {
    guard let value = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors.map(\.cgColor) as CFArray,
        locations: [0, 1]
    ) else { return }

    context.saveGState()
    context.addPath(path)
    context.clip()
    context.drawLinearGradient(value, start: start, end: end, options: [])
    context.restoreGState()
}

private func brandPaths(in rect: CGRect) -> (left: CGPath, right: CGPath, dot: CGRect) {
    let c = NormalizedCanvas(rect: rect)

    // d：圆润的大写意轮廓，右侧鼻尖和内凹共同形成对话气泡的负形。
    let left = CGMutablePath()
    left.move(to: c.point(0.515, 0.055))
    left.addCurve(to: c.point(0.625, 0.175), control1: c.point(0.585, 0.055), control2: c.point(0.625, 0.105))
    left.addLine(to: c.point(0.625, 0.485))
    left.addCurve(to: c.point(0.672, 0.560), control1: c.point(0.625, 0.525), control2: c.point(0.640, 0.548))
    left.addCurve(to: c.point(0.610, 0.575), control1: c.point(0.690, 0.568), control2: c.point(0.665, 0.574))
    left.addCurve(to: c.point(0.555, 0.635), control1: c.point(0.572, 0.588), control2: c.point(0.550, 0.607))
    left.addCurve(to: c.point(0.610, 0.705), control1: c.point(0.555, 0.674), control2: c.point(0.578, 0.695))
    left.addCurve(to: c.point(0.670, 0.716), control1: c.point(0.632, 0.711), control2: c.point(0.651, 0.712))
    left.addLine(to: c.point(0.670, 0.835))
    left.addCurve(to: c.point(0.585, 0.940), control1: c.point(0.670, 0.900), control2: c.point(0.645, 0.940))
    left.addLine(to: c.point(0.285, 0.940))
    left.addCurve(to: c.point(0.070, 0.700), control1: c.point(0.150, 0.940), control2: c.point(0.070, 0.845))
    left.addCurve(to: c.point(0.300, 0.315), control1: c.point(0.070, 0.495), control2: c.point(0.180, 0.345))
    left.addCurve(to: c.point(0.420, 0.295), control1: c.point(0.340, 0.302), control2: c.point(0.385, 0.295))
    left.addLine(to: c.point(0.420, 0.175))
    left.addCurve(to: c.point(0.515, 0.055), control1: c.point(0.420, 0.105), control2: c.point(0.455, 0.055))
    left.closeSubpath()

    // i：面向 d 的轻微鼻尖和腰部收窄，保留原稿的角色感。
    let right = CGMutablePath()
    right.move(to: c.point(0.805, 0.345))
    right.addCurve(to: c.point(0.700, 0.475), control1: c.point(0.735, 0.345), control2: c.point(0.700, 0.400))
    right.addLine(to: c.point(0.700, 0.535))
    right.addCurve(to: c.point(0.666, 0.580), control1: c.point(0.700, 0.555), control2: c.point(0.687, 0.570))
    right.addCurve(to: c.point(0.716, 0.592), control1: c.point(0.650, 0.587), control2: c.point(0.682, 0.589))
    right.addCurve(to: c.point(0.775, 0.660), control1: c.point(0.755, 0.600), control2: c.point(0.775, 0.622))
    right.addLine(to: c.point(0.775, 0.825))
    right.addCurve(to: c.point(0.855, 0.940), control1: c.point(0.775, 0.895), control2: c.point(0.808, 0.940))
    right.addCurve(to: c.point(0.945, 0.830), control1: c.point(0.912, 0.940), control2: c.point(0.945, 0.895))
    right.addLine(to: c.point(0.945, 0.500))
    right.addCurve(to: c.point(0.805, 0.345), control1: c.point(0.945, 0.405), control2: c.point(0.888, 0.345))
    right.closeSubpath()

    return (left, right, c.ellipse(x: 0.765, y: 0.125, width: 0.135, height: 0.135))
}

private func drawBrandMark(_ context: CGContext, in rect: CGRect) {
    let canvas = NormalizedCanvas(rect: rect)
    let paths = brandPaths(in: rect)

    gradient(
        context,
        path: paths.left,
        colors: [NSColor(hex: 0xF27A52), NSColor(hex: 0xDF5C3D)],
        start: canvas.point(0.15, 0.20),
        end: canvas.point(0.68, 0.92)
    )

    let dotPath = CGPath(ellipseIn: paths.dot, transform: nil)
    gradient(
        context,
        path: paths.right,
        colors: [NSColor(hex: 0xF6BD58), NSColor(hex: 0xEAA03D)],
        start: canvas.point(0.72, 0.20),
        end: canvas.point(0.93, 0.94)
    )
    gradient(
        context,
        path: dotPath,
        colors: [NSColor(hex: 0xF7C15C), NSColor(hex: 0xEAA03D)],
        start: canvas.point(0.77, 0.12),
        end: canvas.point(0.90, 0.27)
    )

    context.setFillColor(NSColor(hex: 0x432619).cgColor)
    context.fillEllipse(in: canvas.ellipse(x: 0.490, y: 0.440, width: 0.058, height: 0.058))
    context.fillEllipse(in: canvas.ellipse(x: 0.790, y: 0.475, width: 0.058, height: 0.058))
}

private func drawAppIcon(_ context: CGContext, side: CGFloat) {
    let canvas = CGRect(x: 0, y: 0, width: side, height: side)
    let background = CGPath(
        roundedRect: canvas,
        cornerWidth: side * 0.225,
        cornerHeight: side * 0.225,
        transform: nil
    )
    context.addPath(background)
    context.setFillColor(NSColor(hex: 0xFBF7EF).cgColor)
    context.fillPath()

    // 只放符号，不塞小字号字标；16px 依旧能认出 d/i 双角色。
    drawBrandMark(context, in: CGRect(x: side * 0.145, y: side * 0.115, width: side * 0.710, height: side * 0.770))
}

private func drawTransparentBrandMark(_ context: CGContext, side: CGFloat) {
    drawBrandMark(context, in: CGRect(x: side * 0.075, y: side * 0.045, width: side * 0.850, height: side * 0.910))
}

private func drawMenuBarMark(_ context: CGContext, side: CGFloat) {
    // 16pt 时约 1.7pt 的笔画；不带眼睛、渐变或底板，由 macOS template 着色。
    let stroke = max(1.65, side * 0.104)
    context.setStrokeColor(NSColor.black.cgColor)
    context.setFillColor(NSColor.black.cgColor)
    context.setLineWidth(stroke)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    let dCenter = CGPoint(x: side * 0.315, y: side * 0.590)
    let dRadius = side * 0.205
    context.strokeEllipse(in: CGRect(
        x: dCenter.x - dRadius,
        y: dCenter.y - dRadius,
        width: dRadius * 2,
        height: dRadius * 2
    ))
    context.move(to: CGPoint(x: side * 0.480, y: side * 0.170))
    context.addLine(to: CGPoint(x: side * 0.480, y: side * 0.590))
    context.strokePath()

    context.move(to: CGPoint(x: side * 0.760, y: side * 0.505))
    context.addLine(to: CGPoint(x: side * 0.760, y: side * 0.805))
    context.strokePath()
    context.fillEllipse(in: CGRect(
        x: side * 0.695,
        y: side * 0.200,
        width: side * 0.130,
        height: side * 0.130
    ))
}

for directory in [appIconRoot, brandMarkRoot, menuBarRoot, brandRoot] {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
}

let appIconSizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]
for (size, name) in appIconSizes {
    try writePNG(size: size, to: appIconRoot.appendingPathComponent(name), draw: drawAppIcon)
}

try writePNG(size: 128, to: brandMarkRoot.appendingPathComponent("DimmiBrandMark.png"), draw: drawTransparentBrandMark)
try writePNG(size: 256, to: brandMarkRoot.appendingPathComponent("DimmiBrandMark@2x.png"), draw: drawTransparentBrandMark)
try writePNG(size: 512, to: brandRoot.appendingPathComponent("DimmiBrandMark-master.png"), draw: drawTransparentBrandMark)

let menuSizes: [(Int, String)] = [
    (16, "MenuBarIcon_16x16.png"),
    (32, "MenuBarIcon_16x16@2x.png"),
    (32, "MenuBarIcon_32x32.png"),
    (64, "MenuBarIcon_32x32@2x.png"),
]
for (size, name) in menuSizes {
    try writePNG(size: size, to: menuBarRoot.appendingPathComponent(name), draw: drawMenuBarMark)
}
try writePNG(size: 256, to: brandRoot.appendingPathComponent("DimmiMenuBarIcon-master.png"), draw: drawMenuBarMark)

print("Generated dimmi AppIcon, in-app brand mark and menu bar template assets.")
