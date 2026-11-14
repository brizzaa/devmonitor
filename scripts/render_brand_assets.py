#!/usr/bin/env python3
"""Draw the DevMonitor app icon and README previews. Stdlib only."""

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def write_png(path: Path, width: int, height: int, pixels) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        row = y * width * 4
        raw.extend(pixels[row : row + width * 4])

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    blob = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(blob)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def clamp(value):
    return max(0, min(255, int(value)))


def rounded_sdf(x, y, width, height, radius):
    dx = abs(x - width / 2) - (width / 2 - radius)
    dy = abs(y - height / 2) - (height / 2 - radius)
    return math.hypot(max(dx, 0), max(dy, 0)) + min(max(dx, dy), 0) - radius


def icon_pixels(size: int) -> bytearray:
    pixels = bytearray(size * size * 4)
    radius = size * 0.225
    navy = (11, 16, 32, 255)
    teal = (27, 168, 154, 255)
    violet = (92, 72, 214, 255)
    for y in range(size):
        for x in range(size):
            sdf = rounded_sdf(x + 0.5, y + 0.5, size, size, radius)
            alpha = max(0.0, min(1.0, 0.5 - sdf))
            if alpha <= 0:
                continue
            tx = x / size
            ty = y / size
            color = mix(navy, teal, ty * 0.85)
            color = mix(color, violet, max(0, tx - 0.35) * 0.55)
            # soft inner highlight
            highlight = math.exp(-((tx - 0.28) ** 2 + (ty - 0.22) ** 2) * 8)
            color = mix(color, (180, 255, 245, 255), highlight * 0.28)
            # pulse
            pulse = pulse_alpha(tx, ty)
            if pulse > 0:
                color = mix(color, (236, 255, 250, 255), min(1, pulse))
            # end dot
            dx = tx - 0.74
            dy = ty - 0.58
            dist = math.hypot(dx, dy)
            if dist < 0.055:
                color = mix(color, (46, 230, 199, 255), 1)
            if dist < 0.022:
                color = mix(color, (255, 255, 255, 255), 1)
            index = (y * size + x) * 4
            pixels[index : index + 4] = bytes((color[0], color[1], color[2], clamp(color[3] * alpha)))
    return pixels


def pulse_alpha(tx, ty) -> float:
    if tx < 0.18 or tx > 0.72:
        return 0
    local = (tx - 0.18) / 0.54
    wave = 0.58
    if local < 0.35:
        wave += 0
    elif local < 0.48:
        wave -= (local - 0.35) / 0.13 * 0.22
    elif local < 0.62:
        wave += (local - 0.48) / 0.14 * 0.34 - 0.22
    else:
        wave += 0.12 - (local - 0.62) / 0.38 * 0.12
    distance = abs(ty - wave)
    return max(0.0, 1 - distance / 0.028)


def downsample(source, size, target):
    pixels = bytearray(target * target * 4)
    scale = size / target
    for y in range(target):
        for x in range(target):
            r = g = b = a = 0.0
            count = 0
            y0 = int(y * scale)
            y1 = int((y + 1) * scale)
            x0 = int(x * scale)
            x1 = int((x + 1) * scale)
            for sy in range(y0, max(y1, y0 + 1)):
                for sx in range(x0, max(x1, x0 + 1)):
                    index = (sy * size + sx) * 4
                    r += source[index]
                    g += source[index + 1]
                    b += source[index + 2]
                    a += source[index + 3]
                    count += 1
            index = (y * target + x) * 4
            pixels[index : index + 4] = bytes((clamp(r / count), clamp(g / count), clamp(b / count), clamp(a / count)))
    return pixels


def preview(path: Path, kind: str) -> None:
    width, height = 1400, 860
    pixels = bytearray(width * height * 4)
    for y in range(height):
        for x in range(width):
            tx, ty = x / width, y / height
            color = mix((8, 10, 18, 255), (14, 28, 36, 255), ty)
            if tx < 0.22:
                color = mix((12, 16, 28, 255), (18, 24, 40, 255), ty)
            glow = math.exp(-((tx - 0.15) ** 2 + (ty - 0.08) ** 2) * 6)
            color = mix(color, (30, 90, 86, 255), glow * 0.4)
            index = (y * width + x) * 4
            pixels[index : index + 4] = bytes(color)
    fill_round(pixels, width, height, 28, 28, 250, 804, 18, (255, 255, 255, 18))
    for index, tint in enumerate([(64, 224, 208), (140, 108, 255), (255, 184, 80), (120, 200, 160), (255, 120, 140)]):
        fill_round(pixels, width, height, 48, 70 + index * 58, 210, 40, 10, (*tint, 70))
    if kind == "dashboard":
        fill_round(pixels, width, height, 310, 36, 1060, 168, 18, (255, 255, 255, 24))
        for index, tint in enumerate([(64, 224, 208), (140, 108, 255), (255, 184, 80)]):
            fill_round(pixels, width, height, 340 + index * 330, 64, 300, 112, 16, (*tint, 55))
        for row in range(8):
            top = 230 + row * 70
            fill_round(pixels, width, height, 310, top, 1060, 58, 12, (255, 255, 255, 16))
            fill_round(pixels, width, height, 330, top + 16, 92, 26, 13, (64, 224, 208, 140))
            fill_round(pixels, width, height, 440, top + 20, 280, 16, 6, (255, 255, 255, 40))
    else:
        accents = [(64, 224, 208), (140, 108, 255), (255, 120, 140), (255, 184, 80), (90, 170, 255), (120, 200, 160)]
        for index in range(8):
            left = 310 + (index % 4) * 255
            top = 48 + (index // 4) * 380
            tint = accents[index % len(accents)]
            fill_round(pixels, width, height, left, top, 240, 340, 20, (*tint, 48))
            fill_round(pixels, width, height, left + 20, top + 28, 120, 48, 10, (255, 255, 255, 50))
            fill_round(pixels, width, height, left + 20, top + 100, 160, 18, 6, (255, 255, 255, 40))
            fill_round(pixels, width, height, left + 20, top + 250, 90, 36, 10, (*tint, 160))
    write_png(path, width, height, pixels)


def fill_round(pixels, width, height, left, top, box_w, box_h, radius, color):
    for y in range(top, min(height, top + box_h)):
        for x in range(left, min(width, left + box_w)):
            sdf = rounded_sdf(x - left + 0.5, y - top + 0.5, box_w, box_h, radius)
            if sdf > 0:
                continue
            index = (y * width + x) * 4
            base = pixels[index : index + 4]
            blended = mix(tuple(base), color, color[3] / 255)
            pixels[index : index + 4] = bytes((blended[0], blended[1], blended[2], 255))


def main() -> None:
    master = icon_pixels(1024)
    iconset = ROOT / "Assets" / "AppIcon.iconset"
    sizes = {
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
    for name, size in sizes.items():
        image = master if size == 1024 else downsample(master, 1024, size)
        write_png(iconset / name, size, size, image)
    docs = ROOT / "docs"
    preview(docs / "preview-dashboard.png", "dashboard")
    preview(docs / "preview-ports.png", "ports")
    print(f"wrote {iconset} and {docs}")


if __name__ == "__main__":
    main()
