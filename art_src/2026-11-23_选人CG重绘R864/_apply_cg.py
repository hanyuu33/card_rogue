# -*- coding: utf-8 -*-
"""R864b：选人 CG 落地脚本 —— 保证**头部完整**的取景口径。

背景：class_pick_scene 用 CardFace.cover_region_top() 把 CG「顶部优先」铺满整窗，
而窗口顶部还有一条 30px 的标题栏压在 CG 上。源图（1672×941）本身是 16:9，
人物头顶离源图顶边只有 5~8% 卡高 —— 铺上去就被标题栏啃掉一截。

单纯裁切救不了（裁哪儿都会更切头），所以改用：
  ① 源图等比缩放到 1280×720；
  ② 顶部 48px **垂直镜像**出一条延伸带，缩放成 1280×HEAD_ROOM 再高斯模糊 ——
     森林的树影 / 废墟的夜空 / 工坊的木梁都能接住，看不出是补的；
  ③ 延伸带贴顶，原图整体下移 HEAD_ROOM，底部等量裁掉（底部本来被头像行压着）。

结果：人物头顶离屏幕顶边 ≈ 原距离 + HEAD_ROOM，稳定落在标题栏之下。

用法：python _apply_cg.py            # 按 PICKS 表重出四张
      改 PICKS 的 head_room 可单独给某张留更多/更少
"""
import os
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RAW = os.path.join(HERE, "raw", "cg")
OUT = os.path.join(ROOT, "assets", "ui")

W, H = 1280, 720
HEAD_ROOM = 40          # 顶部为头部让出的高度（px @1280×720）
BAND_SRC = 48           # 镜像延伸带取源图顶部多少像素
BAND_BLUR = 12.0

PICKS = {
    "forest": ("cg_forest_v3_1941.png", HEAD_ROOM),
    "bard":   ("cg_bard_v2_1903.png",   HEAD_ROOM),
    "mech":   ("cg_mech_v2_1929.png",   HEAD_ROOM),
    "rogue":  ("cg_rogue_v2_1931.png",  HEAD_ROOM),
}


def head_room_image(src_path: str, room: int) -> Image.Image:
    im = Image.open(src_path).convert("RGB").resize((W, H), Image.LANCZOS)
    # ① 顶部延伸带：取最上面 BAND_SRC 行，上下翻转 → 变「往上继续长的景」
    band = im.crop((0, 0, W, BAND_SRC)).transpose(Image.FLIP_TOP_BOTTOM)
    band = band.resize((W, room), Image.LANCZOS).filter(ImageFilter.GaussianBlur(BAND_BLUR))
    # ② 拼：延伸带在顶，原图下移 room，底部裁 room
    canvas = Image.new("RGB", (W, H))
    canvas.paste(band, (0, 0))
    canvas.paste(im.crop((0, 0, W, H - room)), (0, room))
    return canvas


if __name__ == "__main__":
    for k, (f, room) in PICKS.items():
        src = os.path.join(RAW, f)
        cv = head_room_image(src, room)
        dst = os.path.join(OUT, "class_cg_%s.png" % k)
        cv.save(dst, optimize=True)
        print("%-7s <- %-28s head_room=%d  %.0fKB" % (k, f, room, os.path.getsize(dst) / 1024))
