#!/usr/bin/env python3
"""
StatBar DMG Background Generator
生成简洁现代的 DMG 安装背景
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_dmg_background():
    """创建 DMG 背景"""
    width = 660
    height = 400
    
    # 创建背景
    img = Image.new('RGBA', (width, height), (245, 245, 247, 255))  # 浅灰背景
    draw = ImageDraw.Draw(img)
    
    # 渐变背景（从上到下，浅灰到白）
    for y in range(height):
        ratio = y / height
        r = int(245 - 20 * ratio)
        g = int(245 - 20 * ratio)
        b = int(247 - 20 * ratio)
        draw.line([(0, y), (width-1, y)], fill=(r, g, b, 255))
    
    # 左侧应用图标区域背景（圆形高亮）
    icon_x, icon_y = 180, 200
    icon_radius = 80
    
    # 绘制一个淡蓝色圆圈作为图标区域提示
    for r in range(icon_radius + 30, icon_radius, -1):
        alpha = int(30 * (1 - (r - icon_radius) / 30))
        draw.ellipse(
            [(icon_x - r, icon_y - r), (icon_x + r, icon_y + r)],
            fill=(100, 150, 255, alpha)
        )
    
    # 右侧应用程序文件夹区域背景（圆形高亮）
    folder_x, folder_y = 480, 200
    
    for r in range(icon_radius + 30, icon_radius, -1):
        alpha = int(30 * (1 - (r - icon_radius) / 30))
        draw.ellipse(
            [(folder_x - r, folder_y - r), (folder_x + r, folder_y + r)],
            fill=(100, 200, 100, alpha)
        )
    
    # 箭头（从左到右）
    arrow_y = 200
    arrow_start = 280
    arrow_end = 380
    
    # 箭头主体
    draw.line(
        [(arrow_start, arrow_y), (arrow_end - 20, arrow_y)],
        fill=(100, 100, 100, 180),
        width=3
    )
    
    # 箭头头部
    draw.polygon(
        [
            (arrow_end - 20, arrow_y - 15),
            (arrow_end - 20, arrow_y + 15),
            (arrow_end, arrow_y)
        ],
        fill=(100, 100, 100, 180)
    )
    
    # 标题文字
    try:
        # 尝试使用系统字体
        title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)
        subtitle_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    except:
        # 使用默认字体
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()
    
    # 顶部标题
    title = "StatBar"
    subtitle = "macOS 系统监控工具"
    
    # 计算文字位置（居中）
    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_width = title_bbox[2] - title_bbox[0]
    title_x = (width - title_width) // 2
    
    draw.text((title_x, 30), title, fill=(50, 50, 50, 255), font=title_font)
    
    subtitle_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
    subtitle_x = (width - subtitle_width) // 2
    draw.text((subtitle_x, 70), subtitle, fill=(120, 120, 120, 255), font=subtitle_font)
    
    # 底部提示
    hint = "将图标拖拽到 Applications 文件夹完成安装"
    hint_bbox = draw.textbbox((0, 0), hint, font=subtitle_font)
    hint_width = hint_bbox[2] - hint_bbox[0]
    hint_x = (width - hint_width) // 2
    draw.text((hint_x, height - 40), hint, fill=(150, 150, 150, 255), font=subtitle_font)
    
    return img

def main():
    # 创建输出目录
    output_dir = "Sources/StatBar/Assets"
    os.makedirs(output_dir, exist_ok=True)
    
    # 生成背景图
    img = create_dmg_background()
    
    # 保存为 PNG 和 TIFF（Retina 支持）
    output_path = os.path.join(output_dir, "dmg_background.png")
    img.save(output_path, "PNG")
    print(f"Generated: {output_path}")
    
    # 保存 @2x 版本
    img_2x = img.resize((img.width * 2, img.height * 2), Image.Resampling.LANCZOS)
    output_path_2x = os.path.join(output_dir, "dmg_background@2x.png")
    img_2x.save(output_path_2x, "PNG")
    print(f"Generated: {output_path_2x}")
    
    print("\n✅ DMG background generated successfully!")

if __name__ == "__main__":
    main()
