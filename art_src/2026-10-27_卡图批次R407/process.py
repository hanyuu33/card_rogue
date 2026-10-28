# -*- coding: utf-8 -*-
"""R407 卡图批次：raw → assets/pics/<id>.png

流程（与 ART.md「出图链」一致）：
  ① 切底部 11%（去右下角「AI生成」水印）
  ② 按 448×403（1.1117）cover 裁切（居中，只裁多出来的那一边）
  ③ LANCZOS 缩到 448×403、RGB 存 png

用法：python process.py            # 全跑
      python process.py 9074 8065  # 只跑指定 id（后出的补图别重压定稿）
"""
import os
import sys
from PIL import Image

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "pics")

W, H = 448, 403
RATIO = W / H
WATERMARK_CUT = 0.11   # 底部按比例切掉
NO_WM_CUT = {"9001"}   # 已手工处理过边，别再切

# 采用稿（被弃的 v1 不在这里，留在 raw/ 存档）
ADOPT = {
    "9067": "9067_大树守卫_v1.png",
    "9068": "9068_水元素_v2_采用.png",
    "9082": "9082_风元素_v1.png",
    "9074": "9074_小精灵_v2_采用.png",
    "9073": "9073_猫头鹰_v1.png",
    "9019": "9019_箭塔_v1.png",
    "8028": "8028_清泉_v1.png",
    "8065": "8065_货物_v1.png",
    "1013": "1013_灰烬龙_v1_候选.png",
    "1071": "1071_熔岩巨人_v1_候选.png",
    "8011": "8011_爆炸陷阱_v3_候选.png",
    "8019": "8019_地狱猫_v4_候选.png",
    "8041": "8041_充电装置_v1_候选.png",
    "8042": "8042_护盾生成器_v1.png",
    "8058": "8058_重甲战车_v1_候选.png",
    "9001": "9001_鸭子骑士_v2_候选.png",
    "9006": "9006_闪电链_v3_候选.png",
    "9021": "9021_白魔法鸭_v2_候选.png",
    "9050": "9050_鲸鱼之怒_v3_候选.png",
    "9077": "9077_陨石术_v1_候选.png",
    "9083": "9083_流星雨_v1_候选.png",
    "9084": "9084_火墙术_v7_候选.png",
    "9124": "9124_鸭之暗面_v1.png",
    "9152": "9152_废弃机器人_v1_候选.png",
    "9155": "9155_夜行_v2_候选.png",
    "9159": "9159_落石陷阱_v1_候选.png",
    "9166": "9166_集束炮台_v1_候选.png",
    "9169": "9169_烈火之剑_v3_候选.png",
    "9170": "9170_应急电源_v2_候选.png",
    "9172": "9172_激光扫射_v4_候选.png",
    "9176": "9176_本能_v7_候选.png",
    "9179": "9179_惊奇盒子_v1_候选.png",
    "9182": "9182_摇篮曲_v2_候选.png",
    "9183": "9183_森林的朋友们_v4_候选.png",
    "9184": "9184_库存整理_v2_候选.png",
    "9186": "9186_漩涡_v2_候选.png",
    "9187": "9187_鹅_v1.png",
    "9189": "9189_独行_v4_候选.png",
    "9204": "9204_赏金猎人_v4_候选.png",
    "9205": "9205_猎杀_v3_候选.png",
    "9206": "9206_秃鹰_v1.png",
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
