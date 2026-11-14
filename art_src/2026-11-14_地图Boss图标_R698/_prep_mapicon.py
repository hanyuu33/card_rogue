# -*- coding: utf-8 -*-
"""R698 地图 Boss 图标后处理：raw 原图 → 256x256 RGBA（alpha 外框归一化）。

为什么按「透明外框」归一而不是直接缩整张：
  素材是 AI 出的，主体在画布里的占比每次都不一样（可能 76%，也可能 99%）。
  现有 9 张 map_icons 的主体占幅实测 79~99%（多数 89~98%），所以这里统一把
  主体缩到画布 92% 再居中 —— 与 `battle / elite / start` 那几张并排时大小一致，
  且天然保证四周有透明边、主体绝不会被画布切掉。

用法：python _prep_mapicon.py raw/boss_v2.png [输出名，默认 boss]
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "ui", "map_icons")
CANVAS = 256
BODY_RATIO = 0.92          # 主体长边占画布比例（对齐现有图标）


def prep(src_path, name="boss"):
    im = Image.open(src_path).convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        raise SystemExit("源图整张全透明：%s" % src_path)
    cut = im.crop(bbox)
    target = int(round(CANVAS * BODY_RATIO))
    scale = min(target / float(cut.width), target / float(cut.height))
    nw = max(1, int(round(cut.width * scale)))
    nh = max(1, int(round(cut.height * scale)))
    cut = cut.resize((nw, nh), Image.LANCZOS)

    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    out.paste(cut, ((CANVAS - nw) // 2, (CANVAS - nh) // 2), cut)
    dst = os.path.join(OUT_DIR, name + ".png")
    out.save(dst, optimize=True)

    b = out.getchannel("A").getbbox()
    print("源 %s %s → %s %dx%d" % (os.path.basename(src_path), im.size, dst, CANVAS, CANVAS))
    print("主体占比 宽 %.0f%% / 高 %.0f%%，四边留白 左%d 上%d 右%d 下%d px" % (
        100 * (b[2] - b[0]) / CANVAS, 100 * (b[3] - b[1]) / CANVAS,
        b[0], b[1], CANVAS - b[2], CANVAS - b[3]))
    return dst


if __name__ == "__main__":
    src = sys.argv[1]
    nm = sys.argv[2] if len(sys.argv) > 2 else "boss"
    prep(src, nm)
