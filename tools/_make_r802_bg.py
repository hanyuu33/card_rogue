# -*- coding: utf-8 -*-
"""R802 落图：重出的两张事件整屏背景 → 项目规格（1280x720）。

背景：
- 原图 1536x864（本身就是 16:9），**不裁**，直接缩放；
- 右下角「AI生成 WORKBUDDY」水印：取左侧等宽条带镜像覆盖 + 高斯模糊；
- 主体已按「上半部 / 偏两侧」构图，下方 45% 留给对话框。

用法：python tools/_make_r802_bg.py
"""
import struct
from PIL import Image, ImageFilter

RAW = "E:/tmp/r802_art/"
UI = "E:/tmp/wt_shot/assets/ui/"

# 原图文件名 → 目标名
JOBS = [
    ("Painted_illustration__16_9_wid_2026-11-18T12-24-03.png", "bg_sword.png"),
    ("Painted_illustration__16_9_wid_2026-11-18T12-24-29.png", "bg_factory.png"),
]


def kill_wm(im):
    """右下角水印：取其左侧等宽条带水平镜像覆盖，再对该块高斯模糊一次。"""
    w, h = im.size
    bw, bh = int(w * 0.16), int(h * 0.075)
    x0, y0 = w - bw, h - bh
    src = im.crop((x0 - bw, y0, x0, y0 + bh)).transpose(Image.FLIP_LEFT_RIGHT)
    src = src.filter(ImageFilter.GaussianBlur(3))
    im.paste(src, (x0, y0))
    return im


def png_size(path):
    with open(path, "rb") as f:
        b = f.read(33)
    return struct.unpack(">II", b[16:24])


for src_name, dst_name in JOBS:
    im = Image.open(RAW + src_name).convert("RGB")
    print("in ", src_name, im.size)
    im = kill_wm(im)
    im = im.resize((1280, 720), Image.LANCZOS)
    out = UI + dst_name
    im.save(out, optimize=True)
    print("out", out, png_size(out))
print("all done")
