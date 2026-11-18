# -*- coding: utf-8 -*-
"""R794 落图：五张原图 → 项目规格。

- bg_sword / bg_factory   : 1536x1024 → 中心裁 16:9 → 1280x720（assets/ui/）
- event_sword / event_factory : 1536x1024 → 中心裁 4:3 → 640x480（assets/ui/）
- card_9271               : 1024x1024 → 中心裁 448:404 → 448x404（assets/pics/9271.png）
- 水印：右下角「AI生成 WORKBUDDY」——用其左侧同高条带的镜像覆盖后再轻模糊。
"""
import struct
from PIL import Image, ImageFilter

RAW = "E:/work/card_rogue/art_src/2026-11-18_圣剑与巧克力工厂_R794/raw/"
UI = "assets/ui/"
PICS = "assets/pics/"


def kill_wm(im):
    """右下角水印：取其左侧等宽条带水平镜像覆盖，再对该块高斯模糊一次。"""
    w, h = im.size
    bw, bh = int(w * 0.16), int(h * 0.075)  # 水印块
    x0, y0 = w - bw, h - bh
    src = im.crop((x0 - bw, y0, x0, y0 + bh)).transpose(Image.FLIP_LEFT_RIGHT)
    src = src.filter(ImageFilter.GaussianBlur(3))
    im.paste(src, (x0, y0))
    return im


def crop_to(im, ratio):
    w, h = im.size
    if w / h > ratio:  # 太宽 → 裁左右
        nw = int(h * ratio)
        x0 = (w - nw) // 2
        return im.crop((x0, 0, x0 + nw, h))
    nh = int(w / ratio)
    y0 = (h - nh) // 2
    return im.crop((0, y0, w, y0 + nh))


def save(im, path, size, crlf_ignore=None):
    out = im.resize(size, Image.LANCZOS)
    out.save(path, optimize=True)
    b = open(path, "rb").read(33)
    w, h = struct.unpack(">II", b[16:24])
    print("saved", path, w, "x", h)


for name, ratio, size, dst in [
    ("bg_sword", 16 / 9, (1280, 720), UI + "bg_sword.png"),
    ("bg_factory", 16 / 9, (1280, 720), UI + "bg_factory.png"),
    ("event_sword", 4 / 3, (640, 480), UI + "event_sword.png"),
    ("event_factory", 4 / 3, (640, 480), UI + "event_factory.png"),
    ("card_9271", 448 / 404, (448, 404), PICS + "9271.png"),
]:
    im = Image.open(RAW + name + ".png").convert("RGB")
    im = kill_wm(im)
    im = crop_to(im, ratio)
    save(im, dst, size)
print("all done")
