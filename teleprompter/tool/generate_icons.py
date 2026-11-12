#!/usr/bin/env python3
"""生成「大皖提词器」三端应用图标。

设计：靛蓝渐变底 + 白色「台本行 → 声波」简形符号，无文字。
所有尺寸由同一套几何参数在 4 倍超采样下绘制后降采样，保证小尺寸边缘干净。

用法（在 teleprompter/ 目录）：
    python3 tool/generate_icons.py

产物：
    assets/branding/icon_master_1024.png                 # 1024 母版（圆角、透明外角）
    assets/branding/android/                             # 自适应前景/背景/单色各密度
    assets/branding/macos/AppIcon.iconset/ + .icns       # macOS 图标集与 icns
    assets/branding/windows/app_icon.ico                 # Windows 多尺寸 ico
    docs/assets/branding/icon-preview.png                # 尺寸预览（仓库根 docs/）
并同步写入 apps/app 对应平台的资源目录。
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]  # teleprompter/
APP = ROOT / "apps" / "app"
BRAND = ROOT / "assets" / "branding"
DOC_BRAND = ROOT.parent / "docs" / "assets" / "branding"

# 深蓝底色（Material 3 blue 700 → 900），与 design_system indigo seed 同族但更深更蓝。
BG_TOP = (21, 101, 192)  # #1565C0
BG_BOTTOM = (13, 71, 161)  # #0D47A1
BRAND_SOLID = (21, 101, 192)  # #1565C0，自适应图标背景层实色
# 中黄色点缀（Material 3 amber 600）：当前跟读行。
ACCENT = (255, 179, 0, 255)  # #FFB300
GLYPH = (255, 255, 255, 255)
SUPERSAMPLE = 4

# 1024 画布内的几何（中心 512,512）
BAR_X = 286
BAR_W_1 = 452
BAR_W_2 = 356
BAR_H = 70
BAR_R = 35
BAR_Y_1 = 311
BAR_Y_2 = 421
WAVE_BAR_W = 62
WAVE_GAP = 42
WAVE_CENTER_Y = 617
WAVE_HEIGHTS = (80, 128, 192, 128, 80)
GLYPH_BOX = (273, 311, 751, 713)  # x0, y0, x1, y1

DENSITIES = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}
LEGACY_SIZES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def _gradient(size: int) -> Image.Image:
    """竖向靛蓝渐变 + 左上柔光。"""
    y = np.linspace(0.0, 1.0, size)[:, None]
    top = np.array(BG_TOP, dtype=np.float64)
    bottom = np.array(BG_BOTTOM, dtype=np.float64)
    column = (top * (1.0 - y) + bottom * y).astype(np.uint8)
    rgb = np.repeat(column[:, None, :], size, axis=1)
    image = Image.fromarray(rgb, "RGB").convert("RGBA")

    yy, xx = np.mgrid[0:size, 0:size]
    cx, cy = size * 0.18, size * 0.12
    distance = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (size * 0.85)
    alpha = (np.clip(1.0 - distance, 0.0, 1.0) ** 2 * 0.16 * 255).astype(np.uint8)
    glow = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    glow.putalpha(Image.fromarray(alpha, "L"))
    return Image.alpha_composite(image, glow)


def _draw_glyph(image: Image.Image, width_fraction: float, accent: bool = True) -> None:
    """在图像中心画符号；宽度占比相对画布。

    第二条（较短）台本行使用中黄色表达「当前跟读行」；
    accent=False 时全部白色（用于 monochrome 主题图标）。
    """
    w, h = image.size
    scale = w * width_fraction / (GLYPH_BOX[2] - GLYPH_BOX[0])
    draw = ImageDraw.Draw(image)

    def rect(x0: float, y0: float, x1: float, y1: float, radius: float, fill=GLYPH) -> None:
        left = (x0 - 512) * scale + w / 2
        top = (y0 - 512) * scale + h / 2
        right = (x1 - 512) * scale + w / 2
        bottom = (y1 - 512) * scale + h / 2
        draw.rounded_rectangle(
            (left, top, right, bottom), radius=radius * scale, fill=fill
        )

    # 第一行台本（白色）
    rect(BAR_X, BAR_Y_1, BAR_X + BAR_W_1, BAR_Y_1 + BAR_H, BAR_R)
    # 第二行台本（中黄，当前跟读行）
    rect(
        BAR_X, BAR_Y_2, BAR_X + BAR_W_2, BAR_Y_2 + BAR_H, BAR_R,
        fill=ACCENT if accent else GLYPH,
    )

    # 声波（白色）
    wave_x = 512 - (5 * WAVE_BAR_W + 4 * WAVE_GAP) / 2
    for index, height in enumerate(WAVE_HEIGHTS):
        x0 = wave_x + index * (WAVE_BAR_W + WAVE_GAP)
        rect(
            x0,
            WAVE_CENTER_Y - height / 2,
            x0 + WAVE_BAR_W,
            WAVE_CENTER_Y + height / 2,
            WAVE_BAR_W / 2,
        )


def _rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=radius, fill=255
    )
    return mask


def render_master(px: int = 1024, rounded: bool = True) -> Image.Image:
    size = px * SUPERSAMPLE
    art = _gradient(size)
    _draw_glyph(art, 0.467)
    if rounded:
        art.putalpha(_rounded_mask(size, round(size * 224 / 1024)))
    return art.resize((px, px), Image.LANCZOS)


def render_background(px: int) -> Image.Image:
    size = max(px * SUPERSAMPLE, 1024)
    return _gradient(size).resize((px, px), Image.LANCZOS)


def render_foreground(px: int) -> Image.Image:
    size = max(px * SUPERSAMPLE, 1024)
    art = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    _draw_glyph(art, 0.50)
    return art.resize((px, px), Image.LANCZOS)


def render_monochrome(px: int) -> Image.Image:
    """Android 13+ 主题图标：全部白色剪影，由系统按主题着色。"""
    size = max(px * SUPERSAMPLE, 1024)
    art = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    _draw_glyph(art, 0.50, accent=False)
    return art.resize((px, px), Image.LANCZOS)


def render_macos(px: int) -> Image.Image:
    """macOS Big Sur 风格：内容区留白 + 圆角 + 柔和投影。"""
    size = px * SUPERSAMPLE
    margin = round(size * 100 / 1024)
    content = size - margin * 2
    radius = round(size * 185 / 1024)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (margin, margin + round(size * 10 / 1024), margin + content, margin + content),
        radius=radius,
        fill=(0, 0, 0, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(round(size * 18 / 1024)))
    canvas = Image.alpha_composite(canvas, shadow)

    art = _gradient(content)
    _draw_glyph(art, 0.56)
    art.putalpha(_rounded_mask(content, round(content * 185 / 824)))
    canvas.paste(art, (margin, margin), art)
    return canvas.resize((px, px), Image.LANCZOS)


def _save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)


def write_android(master: Image.Image) -> None:
    res = APP / "android" / "app" / "src" / "main" / "res"
    for density, scale in DENSITIES.items():
        folder = res / f"mipmap-{density}"
        legacy = master.resize((LEGACY_SIZES[density],) * 2, Image.LANCZOS)
        _save(legacy, folder / "ic_launcher.png")
        dp = round(108 * scale)
        _save(render_background(dp), folder / "ic_launcher_background.png")
        foreground = render_foreground(dp)
        _save(foreground, folder / "ic_launcher_foreground.png")
        _save(render_monochrome(dp), folder / "ic_launcher_monochrome.png")

    anydpi = res / "mipmap-anydpi-v26" / "ic_launcher.xml"
    anydpi.parent.mkdir(parents=True, exist_ok=True)
    anydpi.write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
""",
        encoding="utf-8",
    )

    for density, scale in DENSITIES.items():
        folder = BRAND / "android" / f"mipmap-{density}"
        dp = round(108 * scale)
        _save(master.resize((LEGACY_SIZES[density],) * 2, Image.LANCZOS), folder / "ic_launcher.png")
        _save(render_background(dp), folder / "ic_launcher_background.png")
        foreground = render_foreground(dp)
        _save(foreground, folder / "ic_launcher_foreground.png")
        _save(render_monochrome(dp), folder / "ic_launcher_monochrome.png")


def write_windows() -> None:
    master = render_master(1024)
    ico = BRAND / "windows" / "app_icon.ico"
    ico.parent.mkdir(parents=True, exist_ok=True)
    master.save(
        ico,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (40, 40), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    shutil.copy2(ico, APP / "windows" / "runner" / "resources" / "app_icon.ico")


def write_macos() -> None:
    iconset = BRAND / "macos" / "AppIcon.iconset"
    if iconset.exists():
        shutil.rmtree(iconset)
    iconset.mkdir(parents=True)
    names = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for name, px in names.items():
        _save(render_macos(px), iconset / name)

    icns = BRAND / "macos" / "AppIcon.icns"
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(icns)], check=True)

    appiconset = APP / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for px in (16, 32, 64, 128, 256, 512, 1024):
        _save(render_macos(px), appiconset / f"app_icon_{px}.png")


def write_preview(master: Image.Image) -> None:
    scale = 2
    width, height = 1800 * scale // 2, 1040 * scale // 2
    canvas = Image.new("RGBA", (width, height), (246, 247, 251, 255))
    draw = ImageDraw.Draw(canvas)
    font_path = "/System/Library/Fonts/Helvetica.ttc"
    title_font = ImageFont.truetype(font_path, 34)
    label_font = ImageFont.truetype(font_path, 20)
    small_font = ImageFont.truetype(font_path, 17)

    draw.text((48, 34), "Dawan Teleprompter - app icon", font=title_font, fill=(28, 32, 48))
    draw.text(
        (48, 82),
        "Same geometry, rendered at 4x and downsampled. No text.",
        font=small_font,
        fill=(92, 98, 118),
    )

    sizes = [16, 24, 32, 48, 64, 128, 256]
    panel_top, panel_height = 130, 300
    for index, panel_bg in enumerate(((255, 255, 255, 255), (32, 34, 44, 255))):
        x0 = 48 + index * 870
        draw.rounded_rectangle(
            (x0, panel_top, x0 + 820, panel_top + panel_height),
            radius=24,
            fill=panel_bg,
        )
        cursor = x0 + 34
        baseline = panel_top + panel_height // 2
        for px in sizes:
            icon = master.resize((px, px), Image.LANCZOS)
            canvas.alpha_composite(icon, (cursor, baseline - px // 2))
            cursor += px + 24
        label_color = (70, 76, 96) if index == 0 else (196, 201, 216)
        draw.text(
            (x0 + 34, panel_top + panel_height - 42),
            "16 / 24 / 32 / 48 / 64 / 128 / 256 px at 1x",
            font=label_font,
            fill=label_color,
        )

    draw.rounded_rectangle((48, 470, 468, 890), radius=28, fill=(255, 255, 255, 255))
    canvas.alpha_composite(master.resize((360, 360), Image.LANCZOS), (78, 500))
    draw.text((78, 866), "Master 1024 (rounded)", font=label_font, fill=(70, 76, 96))

    draw.rounded_rectangle((508, 470, 928, 890), radius=28, fill=(255, 255, 255, 255))
    canvas.alpha_composite(render_macos(360), (538, 500))
    draw.text((538, 866), "macOS 360 (squircle + margin)", font=label_font, fill=(70, 76, 96))

    draw.rounded_rectangle((968, 470, 1752, 890), radius=28, fill=(255, 255, 255, 255))
    adaptive = render_background(360)
    foreground = render_foreground(360)
    adaptive.alpha_composite(foreground)
    circle = Image.new("L", (360, 360), 0)
    ImageDraw.Draw(circle).ellipse((0, 0, 359, 359), fill=255)
    adaptive.putalpha(circle)
    canvas.alpha_composite(adaptive, (1000, 500))
    draw.text((1000, 866), "Adaptive: background + foreground (circle mask)", font=label_font, fill=(70, 76, 96))
    draw.text(
        (1000, 906),
        "Android foreground uses the 66 dp safe zone; monochrome reuses the same alpha.",
        font=small_font,
        fill=(92, 98, 118),
    )

    draw.text(
        (48, 940),
        "Palette: #1565C0 -> #0D47A1 deep blue bg / #FFFFFF glyph / #FFB300 accent line",
        font=small_font,
        fill=(92, 98, 118),
    )
    draw.text(
        (48, 972),
        "Regenerate: python3 tool/generate_icons.py",
        font=small_font,
        fill=(92, 98, 118),
    )

    _save(canvas, DOC_BRAND / "icon-preview.png")


def main() -> None:
    BRAND.mkdir(parents=True, exist_ok=True)
    master = render_master(1024)
    _save(master, BRAND / "icon_master_1024.png")
    _save(render_macos(1024), BRAND / "macos" / "icon_macos_1024.png")
    write_android(master)
    write_windows()
    write_macos()
    write_preview(master)
    print("icons written:")
    for path in sorted(BRAND.rglob("*")):
        if path.is_file():
            print(f"  {path.relative_to(ROOT)}  {path.stat().st_size} bytes")
    print(f"  {DOC_BRAND / 'icon-preview.png'}")


if __name__ == "__main__":
    main()
