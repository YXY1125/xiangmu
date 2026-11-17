from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
SIZE = 1024
DEEP_CINNABAR = (110, 30, 36, 255)
PAPER_WHITE = (247, 238, 219, 255)
TRANSPARENT = (0, 0, 0, 0)
STROKE = 62


def draw_mark(image: Image.Image, color: tuple[int, int, int, int]) -> None:
    draw = ImageDraw.Draw(image)
    lines = [
        [(256, 348), (768, 348)],
        [(304, 348), (352, 268), (672, 268), (720, 348)],
        [(360, 442), (664, 442)],
        [(320, 536), (704, 536)],
        [(512, 396), (512, 748)],
        [(512, 564), (352, 736)],
        [(512, 564), (672, 736)],
    ]
    for points in lines:
        draw.line(points, fill=color, width=STROKE, joint="curve")


def save_layers() -> None:
    foreground = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
    draw_mark(foreground, PAPER_WHITE)
    foreground.save(ROOT / "foreground.png")
    foreground.save(ROOT / "foreground-1024.png")

    background = Image.new("RGBA", (SIZE, SIZE), DEEP_CINNABAR)
    background.convert("RGB").save(ROOT / "background.png")
    background.convert("RGB").save(ROOT / "background-1024.png")

    preview = background.copy()
    preview.alpha_composite(foreground)
    preview.convert("RGB").save(ROOT / "preview-1024.png")
    preview.resize((216, 216), Image.Resampling.LANCZOS).convert("RGB").save(ROOT / "agc-216.png")


if __name__ == "__main__":
    save_layers()
