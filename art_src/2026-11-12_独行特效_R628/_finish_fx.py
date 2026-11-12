# -*- coding: utf-8 -*-
"""R628 独行特效：codex 黑底图 → 透明 RGBA 贴图。

为什么是「黑底 → 亮度转 alpha」而不是白底抠图：这三张是**发光法术**，
边缘全是柔和辉光，白底 flood-fill 会把光雾一起啃掉。黑底图里每个像素的
亮度就等于它自己发的光，拿亮度当 alpha、色相归一化，叠到战斗背景上
读起来跟加色混合几乎一样。

用法：python _finish_fx.py            # 处理 raw/ 下已存在的
      python _finish_fx.py column    # 只处理指定 key
"""
import os
import sys

from PIL import Image

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-12_独行特效_R628")
RAW = os.path.join(D, "raw")
PROC = os.path.join(D, "processed")
FX = os.path.join(ROOT, "assets", "fx")

# key -> (成品文件名, 目标尺寸 (w,h) 或 None=只裁边不缩)
# key -> (成品文件名, 目标尺寸, 是否垫画布)
JOBS = {
    "column": ("fx_lone_column.png", (128, 512), False),  # 竖柱：按真实柱体出，不垫边
    "maw": ("fx_lone_maw.png", (256, 256), True),
    "ring": ("fx_lone_ring.png", (256, 256), True),
}


def black_to_alpha(path: str) -> Image.Image:
    """黑底发光图 → 直通 alpha：亮度当不透明度，色相归一化保饱和。

    不用 numpy（本机 python 没装），78 万像素纯循环约 1 秒，够快。
    """
    im = Image.open(path).convert("RGB")
    out = []
    for r, g, b in im.getdata():
        mx = r if r > g else g
        if b > mx:
            mx = b
        # mx < 10 直接归零：黑底图边缘有极淡的压缩噪点，不刨掉 bbox 会撑到全画布
        if mx < 10:
            out.append((0, 0, 0, 0))
            continue
        k = 255.0 / mx
        out.append((min(255, int(r * k)), min(255, int(g * k)),
                    min(255, int(b * k)), int(255.0 * ((mx / 255.0) ** 0.85))))
    dst = Image.new("RGBA", im.size)
    dst.putdata(out)
    return dst


def trim(im: Image.Image, pad: int = 6) -> Image.Image:
    """按 alpha 裁掉四周纯黑空边，只留一点点余量。"""
    bb = im.getbbox()
    if bb is None:
        return im
    x0, y0, x1, y1 = bb
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(im.width, x1 + pad), min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))


def fit(im: Image.Image, w: int, h: int, pad: bool = True) -> Image.Image:
    """等比缩进 w×h 的框里（不拉伸，避免光柱被压扁）。

    pad=False 时**不留画布**，成品就是裁边后的真实尺寸 —— 光柱必须这样：
    它只占裁边框宽度的四成多，垫进 128 宽画布后，代码里按 128 宽去拉
    就只剩一半粗（R628 首版踩过）。
    """
    r = min(w / im.width, h / im.height)
    nw, nh = max(1, int(round(im.width * r))), max(1, int(round(im.height * r)))
    im = im.resize((nw, nh), Image.LANCZOS)
    if not pad:
        return im
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(im, ((w - nw) // 2, (h - nh) // 2))
    return canvas


def main() -> int:
    os.makedirs(PROC, exist_ok=True)
    keys = sys.argv[1:] or list(JOBS)
    done, miss = [], []
    for key in keys:
        if key not in JOBS:
            print("SKIP 未知 key:", key)
            continue
        name, (w, h), pad = JOBS[key]
        src = os.path.join(RAW, "%s_codex.png" % key)
        if not os.path.exists(src):
            miss.append(key)
            print("MISS %s（还没出图）" % key)
            continue
        im = black_to_alpha(src)
        im = trim(im)
        sized = fit(im, w, h, pad)
        sized.save(os.path.join(PROC, name))
        sized.save(os.path.join(FX, name))
        alpha_ch = sized.split()[3]
        nz = sum(1 for v in alpha_ch.tobytes() if v > 8)
        print("OK   %-7s raw %dx%d → 裁边 %dx%d → 成品 %dx%d  非透光 %.1f%%  %d KB"
              % (key, *Image.open(src).size, im.width, im.height,
                 sized.width, sized.height,
                 100.0 * nz / (sized.width * sized.height),
                 os.path.getsize(os.path.join(FX, name)) // 1024))
        done.append(key)
    print("DONE", len(done), "MISS", miss)
    return 0 if not miss else 2


if __name__ == "__main__":
    raise SystemExit(main())
