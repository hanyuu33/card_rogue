# -*- coding: utf-8 -*-
"""R563 收尾：裁切 27 张进 _pending + 生成两张验收总览 + 规格自检。

纪律 F：验收必须看裁好的 448x403，不能只看 raw。
"""
import os
import subprocess
import sys
import importlib.util
from PIL import Image, ImageDraw, ImageFont

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-11_缺图收口_R563")
RAW = os.path.join(D, "raw")
PEND = os.path.join(ROOT, "assets", "pics", "_pending")

spec = importlib.util.spec_from_file_location("r563", os.path.join(D, "_run_all.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

FONT = "C:/Windows/Fonts/msyh.ttc"


def cut_all():
    miss = []
    for cid, name, _bucket in m.JOBS:
        raw = os.path.join(RAW, "%d_%s_v1.png" % (cid, name))
        if not os.path.exists(raw):
            miss.append(cid)
            continue
        r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "cardart_prep.py"),
                            raw, str(cid)], capture_output=True, text=True, encoding="utf-8")
        print(r.stdout.strip() or "cut %d -> FAIL: %s" % (cid, r.stderr.strip()[:120]))
    print("缺 raw:", miss or "无")
    return miss


def sheet(cids_names, out, cell_w, cell_h, use_card):
    COLS, PAD, LB = 4, 10, 24
    rows = (len(cids_names) + COLS - 1) // COLS
    W = COLS * (cell_w + PAD) + PAD
    H = rows * (cell_h + LB + PAD) + PAD
    s = Image.new("RGB", (W, H), (20, 22, 28))
    d = ImageDraw.Draw(s)
    f = ImageFont.truetype(FONT, 18)
    for i, (cid, name) in enumerate(cids_names):
        r, c = divmod(i, COLS)
        x, y = PAD + c * (cell_w + PAD), PAD + r * (cell_h + LB + PAD)
        if use_card:
            p = os.path.join(PEND, "%d.png" % cid)
        else:
            p = os.path.join(RAW, "%d_%s_v1.png" % (cid, name))
        if not os.path.exists(p):
            d.text((x + 6, y + 20), "%d %s  MISSING" % (cid, name), fill=(240, 90, 90), font=f)
            continue
        im = Image.open(p).convert("RGB").resize((cell_w, cell_h), Image.LANCZOS)
        s.paste(im, (x, y))
        d.text((x + 4, y + cell_h + 2), "%d %s" % (cid, name), fill=(235, 235, 240), font=f)
    s.save(os.path.join(ROOT, out))
    print(out, s.size)


def main():
    cut_all()
    rows = [(cid, name) for cid, name, _b in m.JOBS]
    sheet(rows, "_R563_联系表_raw.png", 300, 300, False)
    sheet(rows, "_R563_27张_448卡面.png", 448, 403, True)
    bad = [(cid, name) for cid, name in rows
           if not os.path.exists(os.path.join(PEND, "%d.png" % cid))
           or Image.open(os.path.join(PEND, "%d.png" % cid)).size != (448, 403)]
    print("规格/缺图不符:", bad or "无")
    print("已裁切张数:", len([1 for cid, _n in rows
                            if os.path.exists(os.path.join(PEND, "%d.png" % cid))]))


if __name__ == "__main__":
    main()
