from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageChops, ImageDraw
import math

ROOT = Path(__file__).resolve().parent
APP_ROOT = ROOT.parents[1]
MASTER = 1024
SCALE = 4
SIZE = MASTER * SCALE
BACKGROUND = (123, 47, 57, 255)
FOREGROUND = (255, 248, 240, 255)


def scaled(value: float) -> int:
    return round(value * SCALE)


def rotate_point(x: float, y: float, cx: float, cy: float, angle: float) -> tuple[float, float]:
    radians = math.radians(angle)
    dx = x - cx
    dy = y - cy
    return (
        cx + dx * math.cos(radians) - dy * math.sin(radians),
        cy + dx * math.sin(radians) + dy * math.cos(radians),
    )


def create_foreground() -> Image.Image:
    mask = Image.new("L", (SIZE, SIZE), 0)
    cx = cy = SIZE / 2
    for angle in range(0, 360, 72):
        petal = Image.new("L", (SIZE, SIZE), 0)
        draw = ImageDraw.Draw(petal)
        box = (
            scaled(427),
            scaled(232),
            scaled(597),
            scaled(570),
        )
        draw.ellipse(box, fill=255)
        petal = petal.rotate(-angle, resample=Image.Resampling.BICUBIC, center=(cx, cy))
        mask = ImageChops.lighter(mask, petal)

    cutter = ImageDraw.Draw(mask)
    blade = [
        (scaled(512), scaled(421)),
        (scaled(558), scaled(563)),
        (scaled(512), scaled(657)),
        (scaled(466), scaled(563)),
    ]
    cutter.polygon(blade, fill=0)
    cutter.rounded_rectangle(
        (scaled(484), scaled(395), scaled(540), scaled(456)),
        radius=scaled(8),
        fill=0,
    )

    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fill = Image.new("RGBA", (SIZE, SIZE), FOREGROUND)
    image.paste(fill, (0, 0), mask)
    return image.resize((MASTER, MASTER), Image.Resampling.LANCZOS)


def save_assets() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    foreground = create_foreground()
    background = Image.new("RGBA", (MASTER, MASTER), BACKGROUND)
    preview = background.copy()
    preview.alpha_composite(foreground)
    preview_rgb = preview.convert("RGB")

    foreground.save(ROOT / "foreground.png")
    background.convert("RGB").save(ROOT / "background.png")
    foreground.save(ROOT / "foreground-1024.png")
    background.convert("RGB").save(ROOT / "background-1024.png")
    preview_rgb.save(ROOT / "preview-1024.png")
    preview_rgb.resize((216, 216), Image.Resampling.LANCZOS).save(ROOT / "agc-216.png")

    design = APP_ROOT / "design" / "logo"
    design.mkdir(parents=True, exist_ok=True)
    preview_rgb.save(design / "logo_source.png")
    preview_rgb.save(design / "logo_export.png")
    preview_rgb.save(design / "icon_single.png")
    foreground.save(design / "icon_foreground.png")
    background.convert("RGB").save(design / "icon_background.png")


if __name__ == "__main__":
    save_assets()
