# -*- coding: utf-8 -*-
"""R824：鸭子闹钟 6085 的道具图标 → 128×128 真透明 PNG。

复用 R755 的 `cut()`（亮且不饱和 → 4-连通泛洪取背景 → bbox 居中 → 128）。
⚠️ **别给 `cut()` 传 `bright=`**（R810 的教训）：那是成品亮度增强，不是背景阈值；
   背景阈值只能走 `**bg_kw` 的默认值 —— 这张底子是纯白 255，默认值够用。
"""
import sys

sys.path.insert(0, "E:/work/card_rogue/tools")
from _make_r755_icons import cut, preview  # noqa: E402

RAW = "E:/work/card_rogue/art_src/2026-11-19_鸭子闹钟图标_R824/raw/"
DST = "assets/ui/relic_icon_6085.png"   # ⚠️ cut() 内部会拼 ROOT，这里只能给相对路径
SRC = RAW + "A_cute_hand_drawn_cartoon_game_2026-11-19T11-38-58.png"

cut(SRC, DST, pad_pct=0.06)
preview([DST], "art_src/2026-11-19_鸭子闹钟图标_R824/processed/_preview_128.png", scale=3)
print("done")
