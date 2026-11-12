# -*- coding: utf-8 -*-
"""增量验收页（纪律 N）：按「当前已经存在的 raw」动态拼页，不要求全批齐全。

批量脚本每成功一张就调用本脚本一次；因此 1/4、2/4、3/4 时都能立刻给店长看。
产出（仓库根目录，同名覆盖，永远只含已出图的部分）：
  _组合新卡_448卡面_增量.png   裁好的 448x403 成品视角（纪律 F）
  _组合新卡_联系表_增量.png    raw 原图视角，看留白和有没有削头（纪律 E/G）
  _组合新卡_进度.txt           每轮一行进度
"""
import os
import subprocess
import sys
import time

from PIL import Image, ImageDraw, ImageFont

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(D))
RAW = os.path.join(D, "raw")
PEND = os.path.join(ROOT, "assets", "pics", "_pending")
FONT = "C:/Windows/Fonts/msyh.ttc"
OUT_CARD = os.path.join(ROOT, "_组合新卡_448卡面_增量.png")
OUT_RAW = os.path.join(ROOT, "_组合新卡_联系表_增量.png")
PROGRESS = os.path.join(ROOT, "_组合新卡_进度.txt")

sys.path.insert(0, D)
from _gen_prompts import CARDS  # noqa: E402

ROWS = [(cid, name) for cid, name, _bucket, _full, _card, _body in CARDS]

# 9246 已由店长点名转正为 v2a（影之诗系毛茸茸小幻兽）：联系表也跟着看正式版 raw，
# 而不是已弃用的 v1 矿石兽 raw。v1 raw 原样留档，绝不覆盖。
RAW_OVERRIDE = {9246: "9246_宝石兽_v2a.png"}


def card_path(cid):
    """成品取图：已 approve 的读主目录，未 approve 的回退 _pending。

    15:23 整批转正后必须优先读主目录，否则拼页会全变 MISSING，
    且 cut_one 会把正式图重新裁回待审区（等于把转正撤销）。
    """
    main = os.path.join(ROOT, "assets", "pics", "%d.png" % cid)
    return main if os.path.exists(main) else os.path.join(PEND, "%d.png" % cid)


def cut_one(cid, name):
    """裁进成品位；主目录或 _pending 已有就不覆盖（候选不覆盖纪律）。"""
    raw = os.path.join(RAW, "%d_%s_v1.png" % (cid, name))
    dst = card_path(cid)
    if not os.path.exists(raw):
        return False
    if os.path.exists(dst):
        return True
    r = subprocess.run(
        [sys.executable, os.path.join(ROOT, "tools", "cardart_prep.py"), raw, str(cid)],
        capture_output=True, text=True, encoding="utf-8", cwd=ROOT)
    print(r.stdout.strip() or "  cut %d FAIL: %s" % (cid, r.stderr.strip()[:150]))
    return os.path.exists(dst)


def sheet(items, out, cell_w, cell_h, use_card):
    cols, pad, label = 2, 10, 24
    rows = (len(items) + cols - 1) // cols
    sheet_im = Image.new("RGB", (cols * (cell_w + pad) + pad,
                                 rows * (cell_h + label + pad) + pad), (20, 22, 28))
    d = ImageDraw.Draw(sheet_im)
    f = ImageFont.truetype(FONT, 18)
    for i, (cid, name) in enumerate(items):
        r, c = divmod(i, cols)
        x = pad + c * (cell_w + pad)
        y = pad + r * (cell_h + label + pad)
        p = card_path(cid) if use_card else os.path.join(
            RAW, RAW_OVERRIDE.get(cid, "%d_%s_v1.png" % (cid, name)))
        if not os.path.exists(p):
            d.text((x + 6, y + 20), "%d %s  MISSING" % (cid, name), fill=(240, 90, 90), font=f)
            continue
        im = Image.open(p).convert("RGB").resize((cell_w, cell_h), Image.LANCZOS)
        sheet_im.paste(im, (x, y))
        d.text((x + 4, y + cell_h + 2), "%d %s" % (cid, name), fill=(235, 235, 240), font=f)
    sheet_im.save(out)
    return sheet_im.size


def main():
    os.makedirs(PEND, exist_ok=True)
    ready = []
    for cid, name in ROWS:
        p = os.path.join(RAW, "%d_%s_v1.png" % (cid, name))
        if os.path.exists(p) and os.path.getsize(p) > 50000:
            cut_one(cid, name)
            ready.append((cid, name))
    if not ready:
        print("[preview] 还没有 raw，跳过拼页")
        return 0
    print("[preview] 已完成 %d/%d: %s" % (len(ready), len(ROWS), [c for c, _ in ready]))
    print("  448 卡面页:", OUT_CARD, sheet(ready, OUT_CARD, 448, 403, True))
    snap = os.path.join(ROOT, "_组合新卡_448卡面_%dof%d.png" % (len(ready), len(ROWS)))
    print("  增量快照:", snap, sheet(ready, snap, 448, 403, True))
    print("  联系表:", OUT_RAW, sheet(ready, OUT_RAW, 300, 300, False))
    bad = [(cid, name) for cid, name in ready
           if not os.path.exists(card_path(cid))
           or Image.open(card_path(cid)).size != (448, 403)]
    print("  规格不符:", bad or "无")
    with open(PROGRESS, "a", encoding="utf-8", newline="\n") as f:
        f.write("[%s] %d/%d %s\n" % (time.strftime("%H:%M:%S"), len(ready), len(ROWS),
                                     " ".join(str(c) for c, _ in ready)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
