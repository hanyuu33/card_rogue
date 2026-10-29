# -*- coding: utf-8 -*-
"""把 art_src/_ref/<slug>/ 里的参考图拼成联系表（带序号）"""
import os, sys, glob
from PIL import Image, ImageDraw, ImageFont

def font(sz):
    for fp in ["C:/Windows/Fonts/msyhbd.ttc", "C:/Windows/Fonts/msyh.ttc", "C:/Windows/Fonts/simhei.ttf"]:
        if os.path.exists(fp):
            try: return ImageFont.truetype(fp, sz)
            except Exception: pass
    return ImageFont.load_default()

def sheet(slug, cell=260, cols=4):
    d = os.path.join("art_src/_ref", slug)
    files = sorted([p for p in glob.glob(os.path.join(d, "*.jpg")) + glob.glob(os.path.join(d, "*.png"))])
    if not files:
        print("empty", d); return None
    rows = (len(files) + cols - 1) // cols
    PAD, LBL = 8, 22
    W = cols * cell + (cols + 1) * PAD
    H = rows * (cell + LBL) + (rows + 1) * PAD
    cv = Image.new("RGB", (W, H), (24, 23, 28)); dr = ImageDraw.Draw(cv)
    f = font(15)
    for i, p in enumerate(files):
        c, r = i % cols, i // cols
        x = PAD + c * (cell + PAD); y = PAD + r * (cell + LBL + PAD)
        try:
            im = Image.open(p).convert("RGB")
        except Exception:
            continue
        im.thumbnail((cell, cell), Image.LANCZOS)
        ox = x + (cell - im.width) // 2; oy = y + (cell - im.height) // 2
        cv.paste(im, (ox, oy))
        dr.rectangle([ox, oy, ox + im.width - 1, oy + im.height - 1], outline=(60, 58, 70))
        dr.text((x + 2, y + cell + 3), "%s  %02d" % (slug, i + 1), fill=(225, 225, 232), font=f)
    out = os.path.join("art_src/_ref", "_sheet_%s.png" % slug)
    cv.save(out); print(out, cv.size, len(files), "files")
    return out

if __name__ == "__main__":
    for s in sys.argv[1:]:
        sheet(s)
