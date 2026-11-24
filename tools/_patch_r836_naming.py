# -*- coding: utf-8 -*-
"""R836：往 assets/ui/图片命名说明.txt 追加钟面素材的命名契约（LF 文件，别用 Edit）。"""
ROOT = "E:/work/card_rogue/"
P = ROOT + "assets/ui/图片命名说明.txt"

BLOCK = """
2026-11-20（R836）：缺陷时钟「时针转动」演出的大钟面 —— codex 文生图产出，放 assets/fx/，
  不进 assets/ui/（战斗特效，与 R669 陷阱触发特效同一档）。
  clock_face.png       512×512 RGBA，正面正圆怀表盘（12 个刻度 / 一道裂纹 / 底部露齿轮），
                       **不画指针** —— 指针由 battle_scene 按角度实时绘制（连续旋转贴图会有
                       像素偏移与描边锯齿，角度也对不上刻度）。
  · 唯一取图口 UiAssets.clock_face_path() / clock_face()；
    绘制口 battle_scene._draw_clock_fx()；缺图回退 `_draw_clock_face_fallback()` 的程序化表盘，
    不空白、不报错（项目既有纪律）。
  · 轴座相对纹理中心偏 (+6, +9)（512 空间，代码测的质心）→ 绘制时按 CLOCK_FACE_PIVOT 反向平移，
    指针从**轴座**出发而不是从几何中心出发。
  · 出图 prompt 与抠图：art_src/2026-11-20_缺陷时钟时针_R836/ + tools/_make_r836_clock.py。
  · ⚠️ 抠图必须走边缘泛洪（R755 的 `_bg_mask`）：表盘是米白 #EFE6D2，与白底只差一点亮度，
    按亮度抠会把整个盘面吃掉。
"""

with open(P, "rb") as f:
    old = f.read()
tail = "\n" if not old.endswith(b"\n") else ""
with open(P, "ab") as f:
    f.write((tail + BLOCK).encode("utf-8"))
print("命名说明已追加")
