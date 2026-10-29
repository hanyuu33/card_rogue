# -*- coding: utf-8 -*-
"""R416 卡图批次：raw → assets/pics/<id>.png

流程（与 ART.md「出图链」一致）：
  ① 切底部 11%（去右下角「AI生成」水印）
  ② 按 448×403（1.1117）cover 裁切（居中，只裁多出来的那一边）
  ③ LANCZOS 缩到 448×403、RGB 存 png

⚠️ 只在用户点头后才跑（ART.md「每张图出完必须给用户过目，他点头才入库」）。

用法：python process.py            # 全跑
      python process.py 9022 9080  # 只跑指定 id
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(HERE, "..", "..", "assets", "pics")

W, H = 448, 403
RATIO = W / H
WATERMARK_CUT = 0.11   # 底部按比例切掉
NO_WM_CUT = {"9078"}   # 9078 水印已手工修补（`_r437_heal`），再切 11% 会把跪姿的脚切掉

# 采用稿（被弃的版本不在这里，留在 raw/ 存档）
ADOPT = {
    "1053": "1053_骷髅兵_v1_候选.png",          # 同形象覆盖 1054 / 1055（同名三张）
    "1054": "1053_骷髅兵_v1_候选.png",
    "1055": "1053_骷髅兵_v1_候选.png",
    "1011": "1011_铁壁卫兵_v2_盾形.png",        # v1 盾牌读成货柜（弃）
    "1050": "1050_腐化尸鬼_v1_候选.png",
    "9078": "9078_传承记忆_v3_修补水印.png",     # R437 改名 + 重画；水印走局部修补不切底（切 11% 会把跪姿的脚切掉）
    "9175": "9175_送葬_v2_无十字.png",          # v1 木牌被画成十字架（弃）
    "8006": "8006_影子猫_v1_候选.png",
    "8078": "8078_隐藏能源_v1_候选.png",
    "9023": "9023_英雄_v2_站姿.png",            # R437 换参考姿势；v1 半跪插剑构图（弃）
}


def cover(im: Image.Image, ratio: float) -> Image.Image:
    w, h = im.size
    if w / h > ratio:                       # 太宽 → 裁宽
        nw = int(round(h * ratio))
        x = (w - nw) // 2
        return im.crop((x, 0, x + nw, h))
    nh = int(round(w / ratio))              # 太高 → 裁高（上下各半）
    y = (h - nh) // 2
    return im.crop((0, y, w, y + nh))


def main() -> None:
    want = [a for a in sys.argv[1:] if a.strip()]
    todo = {k: v for k, v in ADOPT.items() if (not want or k in want)}
    missing = [k for k in want if k not in ADOPT]
    if missing:
        raise SystemExit("ADOPT 里没有这些 id: %s" % ", ".join(missing))
    if not todo:
        raise SystemExit("没有要处理的 id")
    os.makedirs(OUT, exist_ok=True)
    for cid, name in sorted(todo.items()):
        src = os.path.join(RAW, name)
        im = Image.open(src).convert("RGB")
        w, h = im.size
        cut = 0 if cid in NO_WM_CUT else int(round(h * WATERMARK_CUT))
        im = im.crop((0, 0, w, h - cut))    # ① 去水印
        im = cover(im, RATIO)               # ② cover
        im = im.resize((W, H), Image.LANCZOS)   # ③ 定稿尺寸
        dst = os.path.join(OUT, cid + ".png")
        im.save(dst, "PNG", optimize=True)
        print("%s  %s -> %s (%dx%d)" % (cid, name, dst, im.size[0], im.size[1]))


if __name__ == "__main__":
    main()
