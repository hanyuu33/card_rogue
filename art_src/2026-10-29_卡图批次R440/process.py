# -*- coding: utf-8 -*-
"""R440 卡图批次：raw → assets/pics/<id>.png

流程（与 ART.md「出图链」一致）：
  ① 切底部 11%（去右下角「AI生成」水印）
  ② 按 448×403（1.1117）cover 裁切（居中，只裁多出来的那一边）
  ③ LANCZOS 缩到 448×403、RGB 存 png

⚠️ 只在用户点头后才跑（ART.md「每张图出完必须给用户过目，他点头才入库」）。
⚠️ 被用户打回的版本**不写进 ADOPT**，留在 raw/ 存档。

本批口径（R440）：用户对 7 张返修的评价是
  「重启不如旧的 / 激光扫射有来源不明的分支激光 / 报废风格可以但构图要参考旧的 / 升级需要角色参与」
→ 被否的 8054、8071、9172、8027 **一律不入库**（8027 保持原图不动）。
→ 从未被否的 8052、8036、9170 三张入库。

用法：python process.py            # 全跑
      python process.py 8052 8036  # 只跑指定 id
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
NO_WM_CUT = set()      # 本批无水印需手工修补的图

# 采用稿（被弃的版本不在这里，留在 raw/ 存档）
ADOPT = {
    "8052": "8052_城墙_v1_装甲闸门.png",        # 四块巨型装甲闸门 + 冷青缝线，画面无人
    "8036": "8036_维修间_v1_无人整备库.png",    # 无人整备库，工位与器械叙事
    "9170": "9170_应急电源_v1_电容柜.png",      # 电容柜阵列，画面无人
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
