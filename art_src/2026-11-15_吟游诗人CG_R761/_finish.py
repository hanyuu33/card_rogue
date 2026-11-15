# -*- coding: utf-8 -*-
"""R761 吟游诗人：CG 落地 1280×720 + 头像洋红抠底 320²（纯 PIL，本机没 numpy）。

用法：
    python _finish.py          # 两个都出，并拼一张跟其它职业 CG 的对比页
    python _finish.py cg
    python _finish.py avatar
"""
import os
import sys

from PIL import Image, ImageChops, ImageFilter

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-15_吟游诗人CG_R761")
RAW = os.path.join(D, "raw")
UI = os.path.join(ROOT, "assets", "ui")

CG_OUT = os.path.join(UI, "class_cg_bard.png")
AV_OUT = os.path.join(UI, "class_avatar_bard.png")

CG_W, CG_H = 1280, 720
AV = 320
# 洋红判据：r、b 都高，且 g 明显低于两者。人物身上没有这种色（肤色 / 米白 / 浅绿 / 金）。
MAG_MIN = 110
MAG_G_RATIO = 0.78
MAG_SPAN = 55          # (r-g) 与 (b-g) 至少要这么多才算洋红


def finish_cg():
    # 定稿取 v2（多版本取最新）：v1 人物偏小、头离顶边太远，与其它职业 CG 的取景不一致。
    src = Image.open(os.path.join(RAW, "cg_bard_v2.png")).convert("RGB")
    w, h = src.size
    # 目标 16:9；原图 1672×941 ≈ 1.7768，按宽定标后纵向裁/补不超过 2px —— 走 LANCZOS 直缩即可。
    out = src.resize((CG_W, CG_H), Image.LANCZOS)
    out.save(CG_OUT)
    print("CG   %d×%d → %d×%d  %s" % (w, h, CG_W, CG_H, CG_OUT))
    return out


def finish_avatar():
    src = Image.open(os.path.join(RAW, "avatar_bard_v1.png")).convert("RGB")
    px = src.load()
    w, h = src.size
    rgba = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = rgba.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            lo = r if r < b else b
            if r >= MAG_MIN and b >= MAG_MIN and g < lo * MAG_G_RATIO \
                    and (r - g) > MAG_SPAN and (b - g) > MAG_SPAN:
                continue                      # 洋红底 → 全透明
            # 去溢色：只有「r、b 同时高过 g」的像素才可能是洋红边缘，把这两路压回去。
            if (r - g) > MAG_SPAN and (b - g) > MAG_SPAN:
                r = g + int((r - g) * 0.25)
                b = g + int((b - g) * 0.25)
            dst[x, y] = (r, g, b, 255)

    # 边缘毛刺：把 alpha 轻微模糊 1px —— 硬切会在缩到 320 后留一圈亮边。
    alpha = rgba.split()[3]
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.6))
    rgba.putalpha(alpha)

    # 按内容裁掉透明边，留 1.5% 呼吸，再居中铺成正方形 320²（与其它职业头像同构）。
    bbox = alpha.point(lambda v: 255 if v > 8 else 0).getbbox()
    if bbox:
        x0, y0, x1, y1 = bbox
        pad = int(max(x1 - x0, y1 - y0) * 0.015)
        x0 = max(0, x0 - pad)
        y0 = max(0, y0 - pad)
        x1 = min(w, x1 + pad)
        y1 = min(h, y1 + pad)
        rgba = rgba.crop((x0, y0, x1, y1))

    side = max(rgba.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(rgba, ((side - rgba.size[0]) // 2, (side - rgba.size[1]) // 2))
    out = canvas.resize((AV, AV), Image.LANCZOS)
    out.save(AV_OUT)
    print("AVATAR 抠底 %d×%d → %d×%d  %s" % (w, h, AV, AV, AV_OUT))
    return out


def compare(cg):
    """验收页：三张现有职业 CG + 新图，横向四格，看人物位置/朝向是否同一套。"""
    names = ["class_cg_forest.png", "class_cg_rogue.png", "class_cg_mech.png"]
    tiles = []
    for n in names:
        im = Image.open(os.path.join(UI, n)).convert("RGB")
        tiles.append(im.resize((CG_W // 2, CG_H // 2), Image.LANCZOS))
    tiles.append(cg.resize((CG_W // 2, CG_H // 2), Image.LANCZOS))
    tw, th = tiles[0].size
    sheet = Image.new("RGB", (tw * 2, th * 2), (24, 24, 24))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 2) * tw, (i // 2) * th))
    out = os.path.join(D, "_R761_CG对比_森林_刺客_机械_吟游.png")
    sheet.save(out)
    print("对比页 %s" % out)

    # 头像验收：320² 贴到深色底上，看得见边缘有没有洋红残留
    av = Image.open(AV_OUT).convert("RGBA")
    bg = Image.new("RGBA", (AV * 2, AV * 2), (32, 34, 40, 255))
    big = av.resize((AV * 2 - 20, AV * 2 - 20), Image.LANCZOS)
    bg.alpha_composite(big, (10, 10))
    av_out = os.path.join(D, "_R761_头像预览.png")
    bg.convert("RGB").save(av_out)
    print("头像预览 %s" % av_out)


def main():
    keys = [a.lower() for a in sys.argv[1:]] or ["cg", "avatar"]
    cg = None
    if "cg" in keys:
        cg = finish_cg()
    if "avatar" in keys:
        finish_avatar()
    if cg is None:
        cg = Image.open(CG_OUT).convert("RGB")
    compare(cg)


if __name__ == "__main__":
    main()
