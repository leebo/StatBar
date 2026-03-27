#!/usr/bin/env swift

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// 图标尺寸
let sizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]

// 创建图标输出目录
let outputDir = "Sources/StatBar/Assets/AppIcon.appiconset"
try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

// 为每个尺寸生成图标
for size in sizes {
    let scale = size >= 512 ? 2 : 1
    let actualSize = size >= 512 ? size / 2 : size
    
    let context = CGContext(
        data: nil,
        width: actualSize,
        height: actualSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
    )!
    
    context.scaleBy(x: CGFloat(actualSize) / 1024, y: CGFloat(actualSize) / 1024)
    
    // 绘制圆角背景
    let bgPath = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: 1024, height: 1024),
        cornerWidth: 180,
        cornerHeight: 180,
        transform: nil
    )
    context.addPath(bgPath)
    
    // 渐变背景：深蓝到紫色
    let colors: [CGColor] = [
        CGColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0),  // 蓝色
        CGColor(red: 0.5, green: 0.3, blue: 0.9, alpha: 1.0)   // 紫色
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 1024, y: 1024), options: [])
    
    // 绘制 CPU 符号（简化的 CPU 芯片图形）
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    
    // CPU 主体（圆角矩形）
    let cpuBody = CGPath(
        roundedRect: CGRect(x: 312, y: 312, width: 400, height: 400),
        cornerWidth: 60,
        cornerHeight: 60,
        transform: nil
    )
    context.addPath(cpuBody)
    context.fillPath()
    
    // CPU 引脚
    let pinWidth: CGFloat = 40
    let pinHeight: CGFloat = 100
    let pinSpacing: CGFloat = 100
    let pinStartX: CGFloat = 372
    let pinEndX: CGFloat = 652
    
    for i in 0..<3 {
        // 上方引脚
        let topPin = CGRect(x: pinStartX + CGFloat(i) * pinSpacing, y: 212, width: pinWidth, height: pinHeight)
        context.fill(topPin)
        
        // 下方引脚
        let bottomPin = CGRect(x: pinStartX + CGFloat(i) * pinSpacing, y: 712, width: pinWidth, height: pinHeight)
        context.fill(bottomPin)
        
        // 左侧引脚
        context.saveGState()
        context.translateBy(x: 512, y: 512)
        context.rotate(by: .pi / 2)
        context.translateBy(x: -512, y: -512)
        let leftPin = CGRect(x: pinStartX + CGFloat(i) * pinSpacing, y: 212, width: pinWidth, height: pinHeight)
        context.fill(leftPin)
        let rightPin = CGRect(x: pinStartX + CGFloat(i) * pinSpacing, y: 712, width: pinWidth, height: pinHeight)
        context.fill(rightPin)
        context.restoreGState()
    }
    
    // CPU 内部图案（三个竖条表示活动状态）
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0))
    
    let barWidth: CGFloat = 60
    let barSpacing: CGFloat = 90
    let barHeights: [CGFloat] = [140, 200, 120]  // 不同高度表示活动
    let barStartY: CGFloat = 512 - 100
    
    for (index, height) in barHeights.enumerated() {
        let bar = CGRect(
            x: 412 + CGFloat(index) * barSpacing,
            y: barStartY,
            width: barWidth,
            height: height
        )
        context.fill(bar)
    }
    
    // 保存图片
    let image = context.makeImage()!
    let url = URL(fileURLWithPath: "\(outputDir)/icon_\(size)x\(size).png")
    
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    
    print("Generated: icon_\(size)x\(size).png")
}

// 生成 Contents.json
let contentsJson = """
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16",
      "filename" : "icon_16x16.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16",
      "filename" : "icon_32x32.png"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32",
      "filename" : "icon_32x32.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32",
      "filename" : "icon_64x64.png"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128",
      "filename" : "icon_128x128.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128",
      "filename" : "icon_256x256.png"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256",
      "filename" : "icon_256x256.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256",
      "filename" : "icon_512x512.png"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512",
      "filename" : "icon_512x512.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512",
      "filename" : "icon_1024x1024.png"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

try contentsJson.write(to: URL(fileURLWithPath: "\(outputDir)/Contents.json"), atomically: true, encoding: .utf8)
print("Generated: Contents.json")
print("\n✅ All icons generated successfully!")
