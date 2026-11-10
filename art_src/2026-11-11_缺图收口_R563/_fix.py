# -*- coding: utf-8 -*-
"""R563 返工工具。

  python _fix.py pad 9242 9243 9244 ...   → 画布延展兜底（纪律 G），裁窗不变，输出 _v2.png 并覆盖 _pending
  python _fix.py retry 9158 8084 ...     → 用 <id>_<name>_v2.txt 重出图（suffix=_v2），再裁切

pad 用于「内容合格但四周贴边」；retry 用于「内容画错」。两者都不碰 cardart_prep.py 的裁窗。
"""
import importlib.util
import os
import subprocess
import sys
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-11_缺图收口_R563")
RAW = os.path.join(D, "raw")

spec = importlib.util.spec_from_file_location("r563", os.path.join(D, "_run_all.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
NAME = {c: n for c, n, _b in m.JOBS}
BUCKET = {c: b for c, _n, b in m.JOBS}
PREP = os.path.join(ROOT, "tools", "cardart_prep.py")


def cut(path, cid):
    r = subprocess.run([sys.executable, PREP, path, str(cid)],
                       capture_output=True, text=True, encoding="utf-8")
    print(r.stdout.strip() or ("cut %d FAIL %s" % (cid, r.stderr.strip()[:120])))


def pad(ids):
    for cid in ids:
        name = NAME[cid]
        src = os.path.join(RAW, "%d_%s_v1.png" % (cid, name))
        dst = os.path.join(RAW, "%d_%s_v2.png" % (cid, name))
        im = Image.open(src).convert("RGB")
        S = im.width
        w = int(S * 0.84)
        off = (S - w) // 2
        small = im.resize((w, w), Image.LANCZOS)
        bg = ImageEnhance.Brightness(im.filter(ImageFilter.GaussianBlur(30))).enhance(0.80)
        mask = Image.new("L", (w, w), 0)
        ImageDraw.Draw(mask).rectangle([24, 24, w - 24, w - 24], fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(12))
        canvas = bg.copy()
        canvas.paste(small, (off, off), mask)
        canvas.save(dst)
        cut(dst, cid)
        print("PAD  %d %s -> %s" % (cid, name, os.path.basename(dst)))


def retry(ids):
    for cid in ids:
        name = NAME[cid]
        p = os.path.join(D, "%d_%s_v2.txt" % (cid, name))
        if not os.path.exists(p):
            print("MISS prompt", p)
            continue
        ok = m.run_one(cid, name, m.REFS[BUCKET[cid]], "_v2")
        if ok:
            cut(os.path.join(RAW, "%d_%s_v2.png" % (cid, name)), cid)
            print("RETRY OK", cid, name)
        else:
            print("RETRY FAIL", cid, name)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    mode, ids = sys.argv[1], [int(x) for x in sys.argv[2:]]
    (pad if mode == "pad" else retry)(ids)
