from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
STORE = ROOT / "store" / "logo"
DESIGN = ROOT / "design" / "logo"
DEEP = (46, 73, 56, 255)
CREAM = (255, 248, 238, 255)


def petal_layer(size: int) -> Image.Image:
    scale = size / 1024.0
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    def ellipse(cx: int, cy: int, rx: int, ry: int, angle: float) -> None:
        pad = int(max(rx, ry) * 2.2 * scale)
        piece = Image.new("RGBA", (pad, pad), (0, 0, 0, 0))
        draw = ImageDraw.Draw(piece)
        box = (
            pad // 2 - int(rx * scale),
            pad // 2 - int(ry * scale),
            pad // 2 + int(rx * scale),
            pad // 2 + int(ry * scale),
        )
        draw.ellipse(box, fill=CREAM)
        rotated = piece.rotate(angle, resample=Image.Resampling.BICUBIC, expand=False)
        layer.alpha_composite(rotated, (int(cx * scale - pad / 2), int(cy * scale - pad / 2)))

    ellipse(512, 346, 92, 154, 0)
    ellipse(387, 414, 92, 154, 56)
    ellipse(637, 414, 92, 154, -56)
    ellipse(425, 526, 86, 138, 122)
    ellipse(599, 526, 86, 138, -122)
    draw = ImageDraw.Draw(layer)
    draw.ellipse((440 * scale, 382 * scale, 584 * scale, 526 * scale), fill=CREAM)
    draw.polygon(
        [
            (402 * scale, 566 * scale),
            (622 * scale, 566 * scale),
            (594 * scale, 756 * scale),
            (570 * scale, 796 * scale),
            (528 * scale, 814 * scale),
            (496 * scale, 814 * scale),
            (454 * scale, 796 * scale),
            (430 * scale, 756 * scale),
        ],
        fill=CREAM,
    )
    return layer


def save_assets() -> None:
    STORE.mkdir(parents=True, exist_ok=True)
    DESIGN.mkdir(parents=True, exist_ok=True)
    size = 1024
    foreground = petal_layer(size)
    background = Image.new("RGBA", (size, size), DEEP)
    preview = background.copy()
    preview.alpha_composite(foreground)
    preview = preview.convert("RGB")

    foreground.save(STORE / "foreground.png")
    foreground.save(STORE / "foreground-1024.png")
    background.convert("RGB").save(STORE / "background.png")
    background.convert("RGB").save(STORE / "background-1024.png")
    preview.save(STORE / "preview-1024.png")
    preview.resize((216, 216), Image.Resampling.LANCZOS).save(STORE / "agc-216.png")

    preview.save(DESIGN / "logo_source.png")
    preview.save(DESIGN / "logo_export.png")
    preview.save(DESIGN / "icon_single.png")
    foreground.save(DESIGN / "icon_foreground.png")
    background.convert("RGB").save(DESIGN / "icon_background.png")


if __name__ == "__main__":
    save_assets()
