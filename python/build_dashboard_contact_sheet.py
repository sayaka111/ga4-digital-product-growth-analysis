"""Combine the four validated dashboard page captures into one overview image."""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PROJECT = Path(__file__).resolve().parent.parent
PREVIEWS = PROJECT / "dashboard" / "screenshots"
OUTPUT = PREVIEWS / "dashboard_overview.png"
FILES = [
    ("page_1.png", "01  增长与获客"),
    ("page_2.png", "02  行为与漏斗"),
    ("page_3.png", "03  留存与生命周期"),
    ("page_4.png", "04  早期信号与价值"),
]


def load_font(size: int) -> ImageFont.ImageFont:
    candidates = [
        Path(os.environ.get("WINDIR", "")) / "Fonts" / "msyh.ttc",
        Path("/System/Library/Fonts/PingFang.ttc"),
        Path("/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc"),
    ]
    for font_path in candidates:
        if font_path.exists():
            return ImageFont.truetype(str(font_path), size)
    return ImageFont.load_default()


def main() -> None:
    card_width = 680
    gap = 24
    label_height = 54
    margin = 32
    title_height = 82
    font = load_font(24)
    title_font = load_font(32)

    cards = []
    for filename, label in FILES:
        image = Image.open(PREVIEWS / filename).convert("RGB")
        card_height = round(image.height * card_width / image.width)
        resized = image.resize((card_width, card_height), Image.Resampling.LANCZOS)
        cards.append((label, resized))

    row_heights = []
    for row_start in range(0, len(cards), 2):
        row_heights.append(max(image.height for _, image in cards[row_start : row_start + 2]) + label_height)
    canvas_width = margin * 2 + card_width * 2 + gap
    canvas_height = margin * 2 + title_height + sum(row_heights) + gap * (len(row_heights) - 1)
    canvas = Image.new("RGB", (canvas_width, canvas_height), "#f4f7fb")
    draw = ImageDraw.Draw(canvas)
    draw.text((margin, margin), "GA4数字产品增长分析｜四页看板总览", fill="#142033", font=title_font)

    y = margin + title_height
    for row_index, row_start in enumerate(range(0, len(cards), 2)):
        for column, (label, image) in enumerate(cards[row_start : row_start + 2]):
            x = margin + column * (card_width + gap)
            draw.rounded_rectangle(
                (x, y, x + card_width, y + label_height + image.height),
                radius=12,
                fill="#ffffff",
                outline="#d9e2ef",
                width=2,
            )
            draw.text((x + 18, y + 12), label, fill="#26364d", font=font)
            canvas.paste(image, (x, y + label_height))
        y += row_heights[row_index] + gap

    canvas.save(OUTPUT, optimize=True)
    print(f"Built contact sheet at {OUTPUT}")


if __name__ == "__main__":
    main()
