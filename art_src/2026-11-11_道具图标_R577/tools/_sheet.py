# -*- coding: utf-8 -*-
"""R577b 联系表：把 processed/ 里已存在的图标排成棋盘格 PNG（可反复增量跑）。"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-11_道具图标_R577"
PROC = D / "processed"
OUT = D / "_review" / "r577_contact_sheet.png"

relics = json.loads((ROOT / "relics.json").read_text(encoding="utf-8"))["relics"]
NAMES = {int(r["id"]): str(r["name"]) for r in relics}
CELL = 116
COLS = 10
PAD = 8

files = sorted(PROC.glob("relic_icon_*.png"), key=lambda p: int(p.stem.rsplit("_", 1)[1]))
rows = max(1, (len(files) + COLS - 1) // COLS)
W = COLS * CELL + PAD * 2
H = rows * (CELL + 24) + PAD * 2 + 28
sheet = Image.new("RGB", (W, H), (245, 242, 234))
d = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 12)
    big = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 15)
except Exception:
    font = big = ImageFont.load_default()
d.text((PAD, 6), "R577b 道具图标联系表 · 已出 %d / 60（棋盘格 = 透明底）" % len(files),
       font=big, fill=(60, 52, 40))

for i, p in enumerate(files):
    cid = int(p.stem.rsplit("_", 1)[1])
    x = PAD + (i % COLS) * CELL
    y = PAD + 28 + (i // COLS) * (CELL + 24)
    tile = Image.new("RGB", (CELL - 6, CELL - 6), (217, 213, 204))
    td = ImageDraw.Draw(tile)
    for cy in range(0, CELL - 6, 12):
        for cx in range(0, CELL - 6, 12):
            if (cx // 12 + cy // 12) % 2 == 0:
                td.rectangle([cx, cy, cx + 11, cy + 11], fill=(200, 195, 184))
    ic = Image.open(p).convert("RGBA").resize((96, 96), Image.LANCZOS)
    tile.paste(ic, ((tile.width - 96) // 2, (tile.height - 96) // 2), ic)
    sheet.paste(tile, (x, y))
    d.text((x + 2, y + CELL - 4), "%d %s" % (cid, NAMES.get(cid, "?")),
           font=font, fill=(60, 52, 40))

OUT.parent.mkdir(parents=True, exist_ok=True)
sheet.save(OUT)
print("OK", OUT, sheet.size, "icons", len(files))
