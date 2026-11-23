# -*- coding: utf-8 -*-
"""把已生成的鸭子字形候选与旧版并排，缺图自动跳过，便于增量验收。"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
D = os.path.join(ROOT, "art_src", "2026-11-22_title_en")
RAW = os.path.join(D, "raw")
ITEMS = [
    ("Chinese reference", os.path.join(ROOT, "assets", "ui", "title_art.png")),
    ("Old English - plain type", os.path.join(ROOT, "assets", "ui", "title_art_en.png")),
    ("Codex duck lettering v1", os.path.join(RAW, "title_duck_v1.png")),
    ("Codex duck lettering v2", os.path.join(RAW, "title_duck_v2.png")),
]

def main():
    cells = []
    for label, path in ITEMS:
        if not os.path.exists(path):
            continue
        im = Image.open(path).convert("RGB")
        im = im.resize((768, 432), Image.LANCZOS)
        cell = Image.new("RGB", (768, 470), (245, 239, 222))
        cell.paste(im, (0, 38))
        draw = ImageDraw.Draw(cell)
        font = ImageFont.truetype(r"C:\Windows\Fonts\arial.ttf", 22)
        draw.text((14, 7), label, font=font, fill=(55, 35, 20))
        cells.append(cell)
    if not cells:
        raise SystemExit("no images")
    cols = 2 if len(cells) > 1 else 1
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 768, rows * 470), (245, 239, 222))
    for i, cell in enumerate(cells):
        sheet.paste(cell, ((i % cols) * 768, (i // cols) * 470))
    out = os.path.join(D, "review_duck_candidates.png")
    sheet.save(out, optimize=True)
    print(out)

if __name__ == "__main__":
    main()
