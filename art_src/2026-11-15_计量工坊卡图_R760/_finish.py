# -*- coding: utf-8 -*-
"""R760 收尾：把 raw 裁成项目口径 448x404 写进 assets/pics/_pending/，并出验收页。

⚠️ 尺寸口径（R644 之后，**不要**再用旧 tools/cardart_prep.py 的 448x403）：
   素材统一 **448x404**；卡面按 CardFace.cover_region() 居中裁成 1.51:1
   （UiTheme.CARD_ART_RATIO = 0.662）→ 只显示第 53..350 行，上下各 53 行永远看不见。
   本脚本先裁 1.51:1 横带 → 448x297 → 上下补边 → 448x404。宽高都可被 4 整除。

⚠️ 本批是**插画**（有主体 + 暗背景），不能套 R759 的 clean_flat()（那是纯色底标志图用的，
   会把主体外的画面全部涂成底色）。补边用相邻行高斯模糊拉伸，接缝看不出来即可。

纪律 J：成品只落 _pending，**不自动覆盖主目录**、不 approve，等店长选版。

用法：
    python _finish.py            # 三张都裁进 _pending/ 并出验收页
    python _finish.py 9261       # 只处理指定卡
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-15_计量工坊卡图_R760")
RAW = os.path.join(D, "raw")
PEND = os.path.join(ROOT, "assets", "pics", "_pending")

RATIO = 1.0 / 0.662
W, H = 448, 404
BAND_H = round(W / RATIO)   # 297
PAD = (H - BAND_H) // 2     # 53
FONT = "C:/Windows/Fonts/msyh.ttc"

JOBS = [(9260, "常数测量员"), (9261, "精密计算者"), (9262, "负载增量员")]


def cut(src, dst):
    """1.51:1 居中横带 → 448x297 → 上下补边 → 448x404（RGBA）。"""
    im = Image.open(src).convert("RGB")
    w, h = im.size
    bw = int(round(h * RATIO))
    if bw <= w:
        left = (w - bw) // 2
        band = im.crop((left, 0, left + bw, h))
    else:
        bh = int(round(w / RATIO))
        top = (h - bh) // 2
        band = im.crop((0, top, w, top + bh))
    band = band.resize((W, BAND_H), Image.LANCZOS)

    full = Image.new("RGB", (W, H), (0, 0, 0))
    strip_t = band.crop((0, 0, W, 1)).resize((W, PAD)).filter(ImageFilter.GaussianBlur(3))
    strip_b = band.crop((0, BAND_H - 1, W, BAND_H)).resize(
        (W, H - BAND_H - PAD)).filter(ImageFilter.GaussianBlur(3))
    full.paste(strip_t, (0, 0))
    full.paste(band, (0, PAD))
    full.paste(strip_b, (0, PAD + BAND_H))

    os.makedirs(os.path.dirname(dst), exist_ok=True)
    full.convert("RGBA").save(dst, optimize=True)
    return Image.open(dst).size


def sheet(items, out, cell_w=300):
    cell_h = int(round(cell_w * H / float(W)))
    padx, lb = 14, 28
    Wd = padx + len(items) * (cell_w + padx)
    Hd = padx + cell_h + lb + padx
    s = Image.new("RGB", (Wd, Hd), (20, 22, 28))
    d = ImageDraw.Draw(s)
    f = ImageFont.truetype(FONT, 17)
    for i, (label, p) in enumerate(items):
        x = padx + i * (cell_w + padx)
        im = Image.open(p).convert("RGB").resize((cell_w, cell_h), Image.LANCZOS)
        s.paste(im, (x, padx))
        top = padx + int(round(PAD * cell_h / float(H)))
        bot = padx + int(round((PAD + BAND_H) * cell_h / float(H)))
        d.rectangle([x, top, x + cell_w - 1, bot], outline=(90, 200, 130), width=2)
        d.text((x + 3, padx + cell_h + 5), label, fill=(235, 235, 240), font=f)
    s.save(os.path.join(D, out))
    print(out, s.size)


def main():
    args = sys.argv[1:]
    ver = "v2" if "--v2" in args else "v1"
    want = [int(a) for a in args if a.startswith("9")]
    items = []
    for cid, name in JOBS:
        if want and cid not in want:
            continue
        raw = os.path.join(RAW, "%d_%s_%s.png" % (cid, name, ver))
        if not os.path.exists(raw):
            print("缺 raw:", os.path.basename(raw))
            continue
        if ver == "v1":
            # v1 才落 _pending（纪律 J：成品只落暂存区，等店长定版再 approve）
            dst = os.path.join(PEND, "%d.png" % cid)
            print("cut %s(v1) -> _pending/%d.png %s" % (name, cid, cut(raw, dst)))
        else:
            # v2 只出对照图，不动 _pending
            dst = os.path.join(D, "_R760_448x404_v2_%d.png" % cid)
            print("cut %s(v2) -> %s %s" % (name, os.path.basename(dst), cut(raw, dst)))
        items.append(("%d %s" % (cid, name), dst))
    if items:
        sheet(items, "_R760_卡面验收%s.png" % ("" if ver == "v1" else "_v2"))
        for _, p in items:
            im = Image.open(p)
            assert im.size == (W, H), (p, im.size)
        print("规格校验 OK：%d 张，全部 448x404（RGBA 见 .mode=%s）" % (
            len(items), Image.open(items[0][1]).mode))


if __name__ == "__main__":
    main()
