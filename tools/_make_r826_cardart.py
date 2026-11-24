# -*- coding: utf-8 -*-
"""R826：7 张音符卡图 9277~9283 → 448×404（含可见带预览，挑垂直偏移）。

复用 R805 的 prep / band_pv（RATIO 自适应裁剪 + 上下可见带 68~335）。

用法：
    python _make_r826_cardart.py            # 对比页：所有已出的卡，各 dy0/25/51
    python _make_r826_cardart.py 9277 dy0   # 把 9277 的 dy0 候选落盘 assets/pics/9277.png
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = "E:/work/card_rogue/"
D = ROOT + "art_src/2026-11-19_音符与音乐盒_R826/"
RAW = D + "raw/"
OUT = D + "processed/"
TARGET = (448, 404)
RATIO = TARGET[0] / float(TARGET[1])
BAND = (68, 335)
CARD_IDS = [9277, 9278, 9279, 9280, 9281, 9282, 9283]
DYS = [("dy0", 0), ("dy25", 25), ("dy51", 51)]

os.makedirs(OUT, exist_ok=True)


def prep(im, dy=0):
    w, h = im.size
    tw = int(round(h * RATIO))
    if tw <= w:
        left = (w - tw) // 2
        box = (left, 0, left + tw, h)
    else:
        th = int(round(w / RATIO))
        top = max(0, min(h - th, (h - th) // 2 + dy))
        box = (0, top, w, top + th)
    return im.crop(box).resize(TARGET, Image.LANCZOS), box


def band_pv(im404, dim=0.8):
    pv = im404.copy().convert("RGB")
    ov = Image.new("RGB", pv.size, (0, 0, 0))
    pv.paste(Image.blend(pv.crop((0, 0, 448, BAND[0])), ov.crop((0, 0, 448, BAND[0])), dim), (0, 0))
    pv.paste(Image.blend(pv.crop((0, BAND[1], 448, 404)), ov.crop((0, BAND[1], 448, 404)), dim),
             (0, BAND[1]))
    d = ImageDraw.Draw(pv)
    d.line([(0, BAND[0]), (447, BAND[0])], fill=(255, 70, 70), width=1)
    d.line([(0, BAND[1]), (447, BAND[1])], fill=(255, 70, 70), width=1)
    return pv


def compare(cids):
    """每张卡拼一张 3 候选对比页（上排 dy 三张，下排可见带预览）。"""
    W, H = 448, 404
    for cid in cids:
        src = RAW + "card_%d.png" % cid
        if not os.path.exists(src):
            print("skip %d（还没出图）" % cid)
            continue
        im = Image.open(src).convert("RGB")
        sheet = Image.new("RGB", (W * 3 + 40, H * 2 + 60), (22, 18, 28))
        d = ImageDraw.Draw(sheet)
        for i, (tag, dy) in enumerate(DYS):
            x = i * (W + 20) + 20
            c, box = prep(im, dy)
            c.save(OUT + "card_%d_%s.png" % (cid, tag))
            sheet.paste(c, (x, 0))
            sheet.paste(band_pv(c), (x, H + 28))
            d.text((x + 8, H + 8), "%d %s top=%d" % (cid, tag, box[1]), fill=(236, 222, 255))
        sheet.save(OUT + "_compare_%d.png" % cid)
        print("compare %d -> %s" % (cid, OUT + "_compare_%d.png" % cid))


def commit(cid, dy):
    src = RAW + "card_%d.png" % cid
    assert os.path.exists(src), "缺 raw 图 %d" % cid
    im = Image.open(src).convert("RGB")
    c, box = prep(im, dy)
    dst = ROOT + "assets/pics/%d.png" % cid
    c.save(dst)
    print("commit %d dy=%d top=%d -> %s" % (cid, dy, box[1], dst))


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) >= 2:
        commit(int(args[0]), int(args[1]))
    else:
        compare(CARD_IDS)
        print("=== 对比页生成完毕 ===")
