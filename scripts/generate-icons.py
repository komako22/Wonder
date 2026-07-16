#!/usr/bin/env python3
"""Generate macOS and Windows app icon resources from the Wonder master PNG."""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "assets" / "wonder-icon-master.png"
MAC_RESOURCES = ROOT / "macos" / "Resources"
WINDOWS_ASSETS = ROOT / "windows" / "GlassTranslate.Windows" / "Assets"


def square_master() -> Image.Image:
    image = Image.open(MASTER).convert("RGBA")
    side = min(image.size)
    left = (image.width - side) // 2
    top = (image.height - side) // 2
    image = image.crop((left, top, left + side, top + side))

    # Generated liquid-glass artwork can contain translucent canvas pixels.
    # Composite those onto the intended white tile before applying the final
    # rounded alpha mask, otherwise hidden RGB values can appear as dark bands.
    white_tile = Image.new("RGBA", (side, side), (255, 255, 255, 255))
    image = Image.alpha_composite(white_tile, image)

    # App-icon artwork is a rounded white tile. Keep the exterior transparent so
    # neither macOS nor Windows renders the source canvas as black square corners.
    mask = Image.new("L", (side, side), 0)
    radius = round(side * 0.16)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, side - 1, side - 1), radius=radius, fill=255)
    image.putalpha(mask)
    return image


def main() -> None:
    image = square_master()
    image.save(MASTER)
    MAC_RESOURCES.mkdir(parents=True, exist_ok=True)
    WINDOWS_ASSETS.mkdir(parents=True, exist_ok=True)

    iconset = MAC_RESOURCES / "Wonder.iconset"
    iconset.mkdir(exist_ok=True)
    entries = {
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
    for filename, size in entries.items():
        image.resize((size, size), Image.Resampling.LANCZOS).save(iconset / filename)
    image.save(MAC_RESOURCES / "Wonder.icns", format="ICNS")

    image.resize((1024, 1024), Image.Resampling.LANCZOS).save(MAC_RESOURCES / "WonderIcon-1024.png")
    image.save(
        WINDOWS_ASSETS / "Wonder.ico",
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    image.resize((256, 256), Image.Resampling.LANCZOS).save(WINDOWS_ASSETS / "Wonder.png")


if __name__ == "__main__":
    main()
