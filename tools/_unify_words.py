#!/usr/bin/env python3
"""统一状态词素材大小：字 bbox 等比缩放到统一字高 + 统一四周留白。

店长口径「统一大小，实际播放时再缩放」：所有状态词素材让「字高 / 文件高」一致，
这样 status_badge 统一缩放到 BASE_H 时，各词视觉大小一致。装饰（冰凌/火星/毒泡）随
bbox 一起算，整体视觉高度对齐。

用法：
  python tools/_unify_words.py [--target-h 750] [--pad 15]
"""
import os
from PIL import Image

SRC = "assets/fx/status_words"
TARGET_H = 750
PAD = 15

WORDS = [
    "bingfeng.png", "chaofeng.png", "gandian.png", "liliang.png",
    "nengliang.png", "pingzhang.png", "ranshao.png", "siwang.png",
    "xuanyun.png", "zhiliao.png", "zhongdu.png",
]


def unify(im, target_h, pad):
    bbox = im.getbbox()
    if bbox is None:
        return im
    crop = im.crop(bbox)
    w, h = crop.size
    nh = target_h
    nw = max(1, round(w * target_h / h))
    crop = crop.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGBA", (nw + pad * 2, nh + pad * 2), (0, 0, 0, 0))
    out.paste(crop, (pad, pad))
    return out


def main():
    for f in WORDS:
        p = os.path.join(SRC, f)
        im = Image.open(p).convert("RGBA")
        res = unify(im, TARGET_H, PAD)
        res.save(p)
        print(f"[unify] {f} -> {res.size[0]}x{res.size[1]}")


if __name__ == "__main__":
    main()
