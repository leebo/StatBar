#!/usr/bin/env python3
"""
StatBar App Icon Generator
生成现代化简洁的应用图标
"""

from PIL import Image, ImageDraw
import math
import os

# 图标尺寸
SIZES = [16, 32, 64, 128, 256, 512, 1024]

def create_rounded_rect_mask(size, radius):
    """创建圆角矩形蒙版"""
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), (size-1, size-1)], radius=radius, fill=255)
    return mask

def draw_gradient_rect(draw, width, height, color1, color2):
    """绘制渐变矩形"""
    for y in range(height):
        ratio = y / height
        r = int(color1[0] + (color2[0] - color1[0]) * ratio)
        g = int(color1[1] + (color2[1] - color1[1]) * ratio)
        b = int(color1[2] + (color2[2] - color1[2]) * ratio)
        draw.line([(0, y), (width-1, y)], fill=(r, g, b))

def create_icon(size):
    """创建指定尺寸的图标"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 计算比例
    scale = size / 1024
    radius = int(180 * scale)
    
    # 绘制圆角背景（渐变：深蓝到紫色）
    for y in range(size):
        ratio = y / size
        # 对角线渐变
        r = int(51 + (128 - 51) * ratio)   # 0.2 -> 0.5
        g = int(102 + (77 - 102) * ratio)  # 0.4 -> 0.3
        b = int(230 + (230 - 230) * ratio) # 0.9 -> 0.9
        draw.line([(0, y), (size-1, y)], fill=(r, g, b, 255))
    
    # 应用圆角蒙版
    mask = create_rounded_rect_mask(size, radius)
    img.putalpha(mask)
    
    # 创建临时图像用于绘制白色元素
    overlay = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    
    # CPU 主体位置
    cpu_x = int(312 * scale)
    cpu_y = int(312 * scale)
    cpu_w = int(400 * scale)
    cpu_h = int(400 * scale)
    cpu_r = int(60 * scale)
    
    # 绘制 CPU 主体（白色圆角矩形）
    overlay_draw.rounded_rectangle(
        [(cpu_x, cpu_y), (cpu_x + cpu_w, cpu_y + cpu_h)],
        radius=cpu_r,
        fill=(255, 255, 255, 242)  # 95% 白色
    )
    
    # 绘制 CPU 引脚
    pin_w = int(40 * scale)
    pin_h = int(100 * scale)
    pin_spacing = int(100 * scale)
    pin_start_x = int(372 * scale)
    
    for i in range(3):
        px = pin_start_x + i * pin_spacing
        
        # 上方引脚
        overlay_draw.rectangle(
            [(px, int(212 * scale)), (px + pin_w, int(212 * scale) + pin_h)],
            fill=(255, 255, 255, 242)
        )
        
        # 下方引脚
        overlay_draw.rectangle(
            [(px, int(712 * scale)), (px + pin_w, int(712 * scale) + pin_h)],
            fill=(255, 255, 255, 242)
        )
        
        # 左侧引脚（旋转90度）
        center_x = size // 2
        center_y = size // 2
        # 简化：直接画上下旋转后的位置
        overlay_draw.rectangle(
            [(int(212 * scale), px), (int(212 * scale) + pin_h, px + pin_w)],
            fill=(255, 255, 255, 242)
        )
        
        # 右侧引脚
        overlay_draw.rectangle(
            [(int(712 * scale), px), (int(712 * scale) + pin_h, px + pin_w)],
            fill=(255, 255, 255, 242)
        )
    
    # 合并图层
    img = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img)
    
    # CPU 内部图案（三个竖条表示活动状态）- 蓝色
    bar_w = int(60 * scale)
    bar_spacing = int(90 * scale)
    bar_heights = [140, 200, 120]
    bar_start_x = int(412 * scale)
    bar_start_y = int(412 * scale)
    
    for i, h in enumerate(bar_heights):
        bx = bar_start_x + i * bar_spacing
        by = bar_start_y
        bh = int(h * scale)
        
        draw.rectangle(
            [(bx, by), (bx + bar_w, by + bh)],
            fill=(51, 102, 230, 255)  # 主蓝色
        )
    
    return img

def main():
    # 创建输出目录
    output_dir = "Sources/StatBar/Assets/AppIcon.appiconset"
    os.makedirs(output_dir, exist_ok=True)
    
    # 生成各尺寸图标
    for size in SIZES:
        img = create_icon(size)
        output_path = os.path.join(output_dir, f"icon_{size}x{size}.png")
        img.save(output_path, "PNG")
        print(f"Generated: {output_path}")
    
    # 生成 Contents.json
    contents = '''{
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
}'''
    
    contents_path = os.path.join(output_dir, "Contents.json")
    with open(contents_path, 'w') as f:
        f.write(contents)
    print(f"Generated: {contents_path}")
    
    print("\n✅ All icons generated successfully!")

if __name__ == "__main__":
    main()
