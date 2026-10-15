# -*- coding: utf-8 -*-
"""R174 卡图第一批管线：ImageGen 原图 → 裁掉底部水印带 → 缩放 → assets/pics/<id>.png

- 原图 1024x1024，右下角「AI生成」水印位于 y>=~950 区域
- 卡图显示区（CardFace._draw_art，cover 铺满）比例 ≈ w : h*0.745 ≈ 1.12:1
- 故从顶部裁 1024x913（=1024/1.1216），水印整条移除，且比例与显示区一致、
  运行时 cover 不再二次裁切
- 缩放到 512 宽入库（战场/手牌/图鉴详情最大显示宽 ~250px，2x 余量足够）
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

# 生成文件名前缀 -> 卡 id
MAP = {
    "Cute_chibi_white_duck_wizard_c": 9008,   # 鸭子巫师
    "Cute_chibi_white_duck_archer_c": 9017,   # 鸭子弓手
    "Cute_chibi_white_duck_with_a_m": 9020,   # 爆炎鸭
    "A_mystical_forest_spirit_chara": 9007,   # 火球术
}

SRC_W = 1024
DST_W = 512
BOX_RATIO = 1.1216          # 99 : 119*0.745
CROP_H = round(SRC_W / BOX_RATIO)   # 913


def main() -> None:
    for prefix, cid in MAP.items():
        src = [f for f in os.listdir(HERE)
               if f.startswith(prefix) and f.endswith(".png")]
        assert len(src) == 1, "前缀 %s 应恰好命中 1 张，实际 %d" % (prefix, len(src))
        im = Image.open(os.path.join(HERE, src[0])).convert("RGB")
        assert im.size == (SRC_W, SRC_W), im.size
        out = im.crop((0, 0, SRC_W, CROP_H))
        out = out.resize((DST_W, round(DST_W / BOX_RATIO)), Image.LANCZOS)
        dst = os.path.join(ROOT, "assets", "pics", "%d.png" % cid)
        out.save(dst, optimize=True)
        print(cid, "<-", src[0][:44], "->", out.size,
              "%.0f KB" % (os.path.getsize(dst) / 1024))


if __name__ == "__main__":
    main()
