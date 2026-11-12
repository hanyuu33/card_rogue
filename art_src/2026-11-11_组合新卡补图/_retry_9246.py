# -*- coding: utf-8 -*-
"""9246 宝石兽返工：以两张实图为形象参考各出一版候选。

候选不覆盖 _pending/9246.png；每成功一版立刻裁 448x403 并刷新
「旧版 / v2a / v2b」前后对比页（纪律 N：拿到一张就发，不等整批）。
"""
import importlib.util
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = r"E:\work\card_rogue"
D = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(D, "raw")
REFS = os.path.join(D, "refs")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")
PEND = os.path.join(ROOT, "assets", "pics", "_pending")
FONT = "C:/Windows/Fonts/msyh.ttc"
OUT = os.path.join(ROOT, "_组合新卡_9246_返工对比.png")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.D = D
m.RAW = RAW

prep_spec = importlib.util.spec_from_file_location(
    "prep", os.path.join(ROOT, "tools", "cardart_prep.py"))
prep = importlib.util.module_from_spec(prep_spec)
prep_spec.loader.exec_module(prep)

JOBS = [
    ("_v2a", os.path.join(REFS, "参考A_影之诗小幻兽.png"), "v2a 影之诗系 · 毛茸茸小幻兽"),
    ("_v2b", os.path.join(REFS, "参考B_红玉兽.png"), "v2b 红玉兽系 · 四耳小狐"),
]


def candidate(suffix):
    return os.path.join(D, "候选_9246_宝石兽%s.png" % suffix)


def cut_candidate(suffix):
    raw = os.path.join(RAW, "9246_宝石兽%s.png" % suffix)
    dst = candidate(suffix)
    if not os.path.exists(raw):
        return False
    if not os.path.exists(dst):
        prep.prep(raw, dst)
    return os.path.exists(dst)


def sheet():
    # v2a 转正后 _pending/9246.png 已是正式版，旧版必须从备份取，对比才不失真。
    v1_backup = os.path.join(D, "backup_9246", "9246_v1_几何矿石兽_448.png")
    old = v1_backup if os.path.exists(v1_backup) else os.path.join(PEND, "9246.png")
    items = [
        ("旧版 v1 · 矿石兽（已弃用）", old),
        ("正式 v2a · 小幻兽（已转正）", candidate("_v2a")),
        ("候选 v2b · 四耳小狐（保留）", candidate("_v2b")),
    ]
    cw, ch, pad, lb = 448, 403, 12, 30
    im = Image.new("RGB", (3 * cw + 4 * pad, ch + lb + 2 * pad), (20, 22, 28))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT, 18)
    for i, (label, path) in enumerate(items):
        x = pad + i * (cw + pad)
        if os.path.exists(path):
            tile = Image.open(path).convert("RGB").resize((cw, ch), Image.LANCZOS)
            im.paste(tile, (x, pad))
            if i == 1:  # 正式版描金边，一眼看出点名转正的是哪一版
                d.rectangle((x, pad, x + cw - 1, pad + ch - 1), outline=(235, 190, 90), width=4)
            d.text((x + 4, pad + ch + 4), label,
                   fill=(235, 190, 90) if i == 1 else (235, 235, 240), font=f)
        else:
            d.text((x + 12, pad + ch // 2), "MISSING / 待出图", fill=(240, 90, 90), font=f)
            d.text((x + 4, pad + ch + 4), label, fill=(160, 160, 170), font=f)
    im.save(OUT)
    print("  对比页:", OUT, im.size, flush=True)


def main():
    os.makedirs(RAW, exist_ok=True)
    sheet()                              # 先把「只有旧版」的页摆出来
    for suffix, ref, label in JOBS:
        ok = m.run_one(9246, "宝石兽", ref, suffix)
        if ok:
            cut_candidate(suffix)
            print("  候选:", os.path.basename(candidate(suffix)), flush=True)
        sheet()
    print("=== 9246 返工结束", flush=True)


if __name__ == "__main__":
    main()
