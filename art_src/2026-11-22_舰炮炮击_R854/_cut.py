# -*- coding: utf-8 -*-
"""9201 舰炮：raw 图 → 448x404 卡图素材（顶部优先 / 居中两种取图口径都安全）。

素材 448x404；卡图区 = 卡面高 x CARD_ART_RATIO(0.540)，卡面 99x119 → 图区比例 ≈ 1.54
  · 战斗 `_draw_art()` 走 cover_region_top：显示第 0..291 行
  · 商店 / 图鉴走 cover_region（居中）：显示第 56..347 行
  → **两张都露的只有 56..291 行**，主体必须落在这条带里。
底部 113 行永远不可见，用末行拉伸填充（不放有效内容）。

跑法：python _cut.py
"""
import os
from PIL import Image, ImageFilter

D = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(D, "raw", "9201_cannon_blast.png")
OUT = os.path.join(D, "processed")
W, H = 448, 404
BAND = 291          # 图区高（448 / 1.54）
TOP_OFF = 56        # 居中口径的行偏移


def main():
    os.makedirs(OUT, exist_ok=True)
    src = Image.open(RAW).convert("RGB")
    w, h = src.size

    # ① 裁成图区比例 448:291（左右对称裁，中心不动）
    ratio = W / float(BAND)
    cw = min(w, int(round(h * ratio)))
    left = (w - cw) // 2
    im = src.crop((left, 0, left + cw, h)).resize((W, BAND), Image.LANCZOS)
    print("① 图区 %dx%d（源 %dx%d 裁左右各 %d）" % (W, BAND, w, h, left))

    # ② 底部补到 404：末行向下拉伸 + 压暗模糊（卡框文字区盖住，不可见）
    tail = im.crop((0, BAND - 24, W, BAND)).resize((W, H - BAND), Image.LANCZOS)
    tail = tail.filter(ImageFilter.GaussianBlur(6.0))
    tail = Image.eval(tail, lambda v: int(v * 0.55))
    card = Image.new("RGB", (W, H))
    card.paste(im, (0, 0))
    card.paste(tail, (0, BAND))

    p = os.path.join(OUT, "9201.png")
    card.convert("RGBA").save(p, optimize=True)
    print("② wrote", p, card.size)

    # ③ 两张口径预览
    band_a = card.crop((0, 0, W, BAND))
    band_a.save(os.path.join(OUT, "9201_view_top.png"))
    band_b = card.crop((0, TOP_OFF, W, TOP_OFF + BAND))
    band_b.save(os.path.join(OUT, "9201_view_center.png"))

    # ④ 交集带（真正两边都看得见的部分）
    band_c = card.crop((0, TOP_OFF, W, BAND))
    band_c.save(os.path.join(OUT, "9201_view_safe.png"))
    print("③ 预览：top 0..%d / center %d..%d / 交集 %d..%d"
          % (BAND, TOP_OFF, TOP_OFF + BAND, TOP_OFF, BAND))


if __name__ == "__main__":
    main()
