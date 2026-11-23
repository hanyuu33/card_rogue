# -*- coding: utf-8 -*-
"""R847b：场地边框「开口要装得下卡」—— 修 FRAME_INSET / 加 OPEN_FIT。

背景（R847b 店长反馈「为什么有的卡片超出了框」）：
  · 格子 124×110，场上单位卡 76.6×92.4（竖长），卡在格内上下各只留 8.8px；
  · v1 素材开口只有 60% 高 → 缩到格子后 66px，卡 92.4 直接顶穿上下边；
  · v2 素材改细边（开口 82.5%）→ 缩到格子后 90.8px，仍差 1.6px。

修法两件（都不改卡面尺寸，避免连带影响其它 300+ 张卡的显示）：
  1. FRAME_INSET 2.0 → 0.0：内缩会白送掉 4px 高度，本身就是「框比格小」的来源；
  2. OPEN_FIT 1.02：按 2% 微放大，把 90.8 → 92.6，刚好装下 92.4 的卡（余 0.2px）。
     溢出格子 1.1px/边，正好落进相邻格的缝隙里，肉眼不可见。

⚠️ 事后复盘（最终代码里**没有** OPEN_FIT）：素材重出到开口 85%~93% 之后，
   绘制侧放大就纯属多余（反而让框溢出格子压到邻格）。最终只保留 ①，并把「开口 ≥84%」
   改成抠图脚本 + 测试的硬断言 —— 让素材负责装得下，代码不替它擦屁股。
"""
import io
import sys

P = r"E:\work\card_rogue\scripts\field_art.gd"
raw = io.open(P, "rb").read().decode("utf-8")

EDITS = [
    # 1) 头注释：把「内缩 2px」那段换成开口口径
    (
        "## 边框相对格子的内缩：相邻格的边框会**边贴边**，不留缝会连成一片大网格，\n"
        "## 看不出「哪个格子挂着场地」。2px（1280×720 下）刚好把相邻两格分开，又不吃掉格内空间。\n"
        "const FRAME_INSET := 2.0",
        "## 边框相对格子的内缩。R847b：**从 2 改 0** —— 框是用来包住卡面的，内缩每 1px 就把\n"
        "## 开口高度白送掉 2px；格子 110 高、卡面 92.4 高，本来就只剩 8.8px 余量，再内缩 2px\n"
        "## 就必然露馅（实机：卡片上下顶出边框）。相邻格靠边框自己的深色外描边分格，不需要留缝。\n"
        "const FRAME_INSET := 0.0\n"
        "\n"
        "## 开口补偿系数（R847b）。素材开口约占 82.5% 高，缩到 110px 格子后是 90.8px，\n"
        "## 比卡面 92.4px 差一点点。按 2% 微放大 → 开口 92.6px，刚好装下；\n"
        "## 溢出格子 1.1px/边，落在相邻格缝隙里，肉眼不可见。\n"
        "## ⚠️ 这是**兜底**，不是替代：素材开口仍必须 ≥ 84% 高（`_cut_frames.py` 里有断言），\n"
        "##    否则再怎么放大都不够，必须重出那张图。\n"
        "const OPEN_FIT := 1.02",
    ),
    # 2) draw_frame 里换算式
    (
        "\tvar r := rect.grow(-FRAME_INSET)\n",
        "\tvar r := rect.grow(-FRAME_INSET)\n"
        "\tif OPEN_FIT != 1.0:\n"
        "\t\t# 以中心为基准微放大：开口随之变大，卡面才装得进去（见 OPEN_FIT 注释）。\n"
        "\t\tvar half := r.size * (OPEN_FIT - 1.0) * 0.5\n"
        "\t\tr = Rect2(r.position - half, r.size * OPEN_FIT)\n",
    ),
]

for old, new in EDITS:
    c = raw.count(old)
    if c != 1:
        print("!! 命中 %d 次：%r" % (c, old[:60]))
        sys.exit(2)
    raw = raw.replace(old, new, 1)

io.open(P, "wb").write(raw.encode("utf-8"))
print("PATCH OK")
