# -*- coding: utf-8 -*-
"""R768：把某一档配色的四张卡按**可见带**拼成一张横向验收图。

为什么要单出这个：recolor/*.png 是 448×404 整图，上下一共 136 行是卡面裁掉的，
拿整图看会误判「主体太大/太靠边」。验收只认可见带（y=68..335）。

用法：
    python tools/_r768_band_h.py H        # 看 recolor 里某一档
    python tools/_r768_band_h.py pics     # 看**已落地**的 assets/pics/<卡号>.png（最终验收）
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"E:\work\card_rogue")
REC = ROOT / "art_src" / "2026-11-16_诅咒火柴人_R768" / "recolor"
OUT = ROOT / "art_src" / "2026-11-16_诅咒火柴人_R768" / "_review"

KEYS = [("regret_v2", 9265, "懊悔"), ("flaw", 9154, "破绽"),
        ("paralysis", 9185, "麻痹"), ("compensation", 9252, "代偿")]
BAND_TOP, BAND_BOT = 68, 335
BAND_H = BAND_BOT - BAND_TOP + 1

W = 224                      # 每格宽度（约卡面实宽的 1.5 倍，方便看细节）
SCALE = W / 448.0
H = int(BAND_H * SCALE)
PAD = 10
LABEL_H = 40


def font(sz, bold=False):
    names = ("msyhbd.ttc", "msyh.ttc") if bold else ("msyh.ttc", "msyhbd.ttc")
    for name in names + ("simhei.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype("C:/Windows/Fonts/" + name, sz)
        except Exception:
            continue
    return ImageFont.load_default()


def main(code):
    cells = []
    pics_mode = code == "pics"
    for key, cid, name in KEYS:
        if pics_mode:
            p = ROOT / "assets" / "pics" / ("%d.png" % cid)
        else:
            p = REC / ("%s_%s.png" % (key, code))
        if not p.exists():
            print("缺 %s，先跑 _recolor.py / 落地" % p.name)
            return 1
        im = Image.open(p).convert("RGB")
        band = im.crop((0, BAND_TOP, im.width, BAND_BOT + 1))
        cells.append((name, cid, band.resize((W, H), Image.LANCZOS)))

    cw, ch = PAD + len(cells) * (W + PAD), LABEL_H + PAD + H + PAD
    canvas = Image.new("RGB", (cw, ch), (18, 13, 24))
    dr = ImageDraw.Draw(canvas)
    dr.text((PAD, 10), "R768 方案 %s 四张卡 — 可见带 y=68..335（卡面真露出的部分）" % code,
            font=font(14, True), fill=(234, 222, 242))
    for i, (name, cid, band) in enumerate(cells):
        x = PAD + i * (W + PAD)
        canvas.paste(band, (x, LABEL_H))
        dr.text((x, LABEL_H - 14), "%s  %d" % (name, cid), font=font(11), fill=(168, 154, 184))

    OUT.mkdir(parents=True, exist_ok=True)
    dst = OUT / ("band_%s.png" % code)
    canvas.save(dst)
    print("->", dst, canvas.size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else "H"))
