# -*- coding: utf-8 -*-
"""R519h：休息处改成左右布局，侧图 = 正在燃烧的篝火。

为什么不是整屏背景：整屏试了 4 版，篝火每次都落在画面宽度 20%~25%，
而正文卡片左缘在 26% → 火堆右半必被切；改「整堆放上半部」那版更糟，火被挪到正中。
按 §4.55 的判据「主体避不开卡片就换布局」，改走 `side_rest.png`。

⚠️ 与 `side_martial` 不同：这张是**原生 1024×1024 方图**，没法靠「裁左方形」让水印出界
（水印在右下 x≈900..1010, y≈960..1015，就在画面里）→ 用 R515b 的镜像条带修补。

产物：`assets/ui/side_rest.png` 742×742（与 side_lake_lady / side_martial 同口径）。
旧整屏图 `assets/ui/adventure_shared/rest_clearing.png` 随之删除（左右布局不吃整屏图）。

用法：
    python process_side_rest.py           # 干跑
    python process_side_rest.py --write   # 修补水印 + 缩放 + 落盘
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from process_r519e import patch_wm, wm_box  # noqa: E402

ROOT = HERE.parents[2]
RAW = HERE.parent / "raw" / "side_rest.png"
PROC = HERE.parent / "processed"
UI = ROOT / "assets" / "ui"
NAME = "side_rest"
TARGET = (742, 742)


def main() -> None:
    write = "--write" in sys.argv
    im = Image.open(RAW).convert("RGB")
    bx = wm_box(im)
    print("原图 %s 水印框 %s → 在画面内，需修补" % (im.size, bx))
    if not write:
        return
    patch_wm(im, bx)
    out = im.resize(TARGET, Image.LANCZOS)
    PROC.mkdir(parents=True, exist_ok=True)
    UI.mkdir(parents=True, exist_ok=True)
    out.save(PROC / (NAME + ".png"), "PNG", optimize=True)
    out.save(UI / (NAME + ".png"), "PNG", optimize=True)
    print("→ %s.png %s %d KB" % (NAME, out.size, (UI / (NAME + ".png")).stat().st_size // 1024))


if __name__ == "__main__":
    main()
