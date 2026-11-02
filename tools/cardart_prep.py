# -*- coding: utf-8 -*-
"""R478 卡图后处理：裁成项目规格 448x403（居中）+ 去掉右下角平台水印 + 改名 <id>.png。

为什么要居中裁：原图 1536x1024，按 1.112 比例居中裁出 1139 宽（左 198 ~ 右 1337），
而平台水印在 x≈1415 之后 —— 裁窗口天然不包含它，不必做涂抹。

用法（在仓库根跑）：
  python tools/cardart_prep.py <源图路径> <卡牌id>
  python tools/cardart_prep.py --batch            # 处理 _pending/raw 下的新图（跳过已归档的 id）
  python tools/cardart_prep.py --only 9137,9138   # 强制重裁指定 id（即使主目录已有，用于重做）

⚠️ --batch 默认**跳过主目录 assets/pics/<id>.png 已存在的 id**：
   raw/ 里的原图是长期留档的，天真的全量重裁会把已归档的图重新生成回 _pending，
   看起来像「又冒出 28 张待确认」（2026-11-01 踩过一次）。
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PEND = os.path.join(ROOT, "assets", "pics", "_pending")
TARGET = (448, 403)
RATIO = TARGET[0] / float(TARGET[1])


def prep(src: str, dst: str) -> None:
    im = Image.open(src).convert("RGB")
    w, h = im.size
    tw = int(round(h * RATIO))
    if tw <= w:
        left = (w - tw) // 2
        box = (left, 0, left + tw, h)
    else:
        th = int(round(w / RATIO))
        top = (h - th) // 2
        box = (0, top, w, top + th)
    im.crop(box).resize(TARGET, Image.LANCZOS).save(dst)
    print("  %s -> %s  (%s)" % (os.path.basename(src)[:40] + "…", os.path.basename(dst), box))


def batch(only: set = None) -> None:
    raw = os.path.join(PEND, "raw")
    if not os.path.isdir(raw):
        print("没有 _pending/raw 目录")
        return
    done = skipped = 0
    for f in sorted(os.listdir(raw)):
        if not f.endswith(".png"):
            continue
        cid = f.split("_")[0]
        if not cid.isdigit():
            print("  跳过（文件名不是 <id>_xxx.png）：%s" % f)
            continue
        if only is not None:
            if cid not in only:
                continue
        elif os.path.exists(os.path.join(ROOT, "assets", "pics", "%s.png" % cid)):
            skipped += 1          # 已归档，别把它重新刷回 _pending
            continue
        prep(os.path.join(raw, f), os.path.join(PEND, "%s.png" % cid))
        done += 1
    print("裁切 %d 张，跳过已归档 %d 张" % (done, skipped))


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--batch":
        batch()
    elif len(sys.argv) >= 3 and sys.argv[1] == "--only":
        batch({x.strip() for x in ",".join(sys.argv[2:]).split(",") if x.strip()})
    elif len(sys.argv) == 3:
        cid = sys.argv[2]
        prep(sys.argv[1], os.path.join(PEND, "%s.png" % cid))
    else:
        print(__doc__)
