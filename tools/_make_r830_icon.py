# -*- coding: utf-8 -*-
"""R830：首饰盒 6088 道具图标 → 128×128 真透明 PNG。

复用 R755 的 cut()（亮且不饱和 → 4-连通泛洪取背景 → bbox 居中 → 128）。
⚠️ 别给 cut() 传 bright=（R810 教训）；背景阈值走默认（纯白 255 底够用）。
"""
import sys

sys.path.insert(0, "E:/work/card_rogue/tools")
from _make_r755_icons import cut, preview  # noqa: E402

RAW = "E:/work/card_rogue/art_src/2026-11-19_首饰盒_R830/raw/"
DST = "assets/ui/relic_icon_6088.png"   # ⚠️ cut() 内部拼 ROOT，这里只能给相对路径
SRC = RAW + "你是本项目的插画委托执行者_请生成_1_张_1024_102_2026-11-19T15-28-54.png"

cut(SRC, DST, pad_pct=0.06)
preview([DST], "art_src/2026-11-19_首饰盒_R830/processed/_preview_128.png", scale=3)
print("done")
