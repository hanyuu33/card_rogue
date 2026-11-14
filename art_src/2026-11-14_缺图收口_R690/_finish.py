# -*- coding: utf-8 -*-
"""R690 收尾：把 raw 裁成项目口径 448x404 写进 assets/pics/_pending/，并出验收总览。

⚠️ 尺寸口径（R644 之后，取代旧 cardart_prep.py 的 448x403）：
   素材统一 **448x404**；卡面按 CardFace.cover_region() 居中裁成 1.51:1
   （UiTheme.CARD_ART_RATIO = 0.662）→ **只显示第 53..350 行**，上下各 53 行永远看不见。
   所以本脚本先裁 1.51:1 横带 → 448x297 → 上下补「模糊边缘带」填成 448x404，
   主体天然落在可见横带里（与 R644 的 _recrop.py 同一套做法，只是通用化）。
   宽高都必须能被 4 整除（404 满足，403 不满足）。

纪律 F：验收必须看裁好的 448x404，不能只看 raw。
纪律 J：成品只落 _pending，**不自动覆盖主目录**、不 approve，等店长选版。
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-14_缺图收口_R690")
RAW = os.path.join(D, "raw")
PEND = os.path.join(ROOT, "assets", "pics", "_pending")

RATIO = 1.0 / 0.662      # 卡图区宽高比 = 1/0.662 ≈ 1.5106
W, H = 448, 404          # 全项目卡图统一尺寸
BAND_H = round(W / RATIO)   # 297
PAD = (H - BAND_H) // 2     # 53

FONT = "C:/Windows/Fonts/msyh.ttc"

JOBS = [(9248, "种子"), (9249, "被眷顾者"), (9250, "鸭妈妈"), (9251, "小鸭")]


def cut(src, dst):
    """1.51:1 居中横带 → 448x297 → 上下补模糊边缘带 → 448x404（RGBA）。"""
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
    strip_t = band.crop((0, 0, W, 1)).resize((W, PAD)).filter(ImageFilter.GaussianBlur(4))
    strip_b = band.crop((0, BAND_H - 1, W, BAND_H)).resize((W, H - BAND_H - PAD)).filter(
        ImageFilter.GaussianBlur(4))
    full.paste(strip_t, (0, 0))
    full.paste(band, (0, PAD))
    full.paste(strip_b, (0, PAD + BAND_H))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    full.convert("RGBA").save(dst, optimize=True)
    return Image.open(dst).size


def sheet(rows, out, cell_w, cell_h, use_card):
    COLS, PADX, LB = 4 if len(rows) > 2 else len(rows), 10, 24
    n = max(1, len(rows))
    r_ = (n + COLS - 1) // COLS
    Wd = COLS * (cell_w + PADX) + PADX
    Hd = r_ * (cell_h + LB + PADX) + PADX
    s = Image.new("RGB", (Wd, Hd), (20, 22, 28))
    d = ImageDraw.Draw(s)
    f = ImageFont.truetype(FONT, 18)
    for i, (cid, name) in enumerate(rows):
        rr, cc = divmod(i, COLS)
        x, y = PADX + cc * (cell_w + PADX), PADX + rr * (cell_h + LB + PADX)
        p = os.path.join(PEND, "%d.png" % cid) if use_card else os.path.join(
            RAW, "%d_%s_v1.png" % (cid, name))
        if not os.path.exists(p):
            d.text((x + 6, y + 20), "%d %s  MISSING" % (cid, name), fill=(240, 90, 90), font=f)
            continue
        im = Image.open(p).convert("RGB").resize((cell_w, cell_h), Image.LANCZOS)
        s.paste(im, (x, y))
        if use_card:
            # 画出卡面真实可见窗口（53..350 行）的边界，方便看主体有没有落到横带外
            top = y + int(round(PAD * cell_h / float(H)))
            bot = y + int(round((PAD + BAND_H) * cell_h / float(H)))
            d.rectangle([x, top, x + cell_w - 1, bot], outline=(90, 200, 130), width=2)
        d.text((x + 4, y + cell_h + 2), "%d %s" % (cid, name), fill=(235, 235, 240), font=f)
    # 交付页落在批次目录内（art_src 有 .gdignore），不放仓库根 —— 避免被 Godot 导入进包
    s.save(os.path.join(D, out))
    print(out, s.size)


def main():
    miss = []
    for cid, name in JOBS:
        raw = os.path.join(RAW, "%d_%s_v1.png" % (cid, name))
        if not os.path.exists(raw):
            miss.append(cid)
            continue
        size = cut(raw, os.path.join(PEND, "%d.png" % cid))
        print("cut %d %s -> %s" % (cid, name, size))
    print("缺 raw:", miss or "无")

    sheet(JOBS, "_R690_联系表_raw.png", 360, 360, False)
    sheet(JOBS, "_R690_448x404卡面.png", 448, 404, True)

    bad = [(cid, name) for cid, name in JOBS
           if not os.path.exists(os.path.join(PEND, "%d.png" % cid))
           or Image.open(os.path.join(PEND, "%d.png" % cid)).size != (W, H)]
    print("规格/缺图不符:", bad or "无")
    print("已裁切张数:", len([1 for cid, _n in JOBS
                            if os.path.exists(os.path.join(PEND, "%d.png" % cid))]))
    return 0 if not miss and not bad else 1


if __name__ == "__main__":
    sys.exit(main())
