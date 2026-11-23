# -*- coding: utf-8 -*-
"""从 R855 英文主视觉裁出商店宣传用 QUACKILL 标题横幅。"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "ui", "title_art_en.png")
OUT = os.path.join(ROOT, "release", "store", "quackill_title_en.png")
# 1920×1080 原图坐标：完整包住 Q 鸭头、八字母、顶部小鸭子和末尾鸭掌。
CROP_BOX = (80, 60, 1840, 630)


def main():
    im = Image.open(SRC).convert("RGB")
    if im.size != (1920, 1080):
        raise SystemExit("unexpected source size: %s" % (im.size,))
    logo = im.crop(CROP_BOX)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    logo.save(OUT, optimize=True)
    print("%s  %dx%d  crop=%s" % (OUT, logo.width, logo.height, CROP_BOX))


if __name__ == "__main__":
    main()
