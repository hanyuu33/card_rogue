# -*- coding: utf-8 -*-
"""R780b 加强版：免伤力场在**亮青水面**上立得住。

问题（实拍）：正面是亮色水面，单画一条半透明金线几乎看不见，
再叠到卡牌自己的金色边框上就彻底糊成一片。改法 = 先压一道深色底线，再画亮金。
同时把六边形从「贴卡框 +3px」推到 +5 / +11，避免和卡框描边重合。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"
NL = "\r\n"
P = ROOT + "scripts/battle_scene.gd"
s = io.open(P, encoding="utf-8", newline="").read()

START = "func _draw_damage_cap_aura("
END = "func _draw_stun_aura("
i = s.find(START)
j = s.find(END, i)
if i < 0 or j < 0:
    sys.exit("定位失败 i=%d j=%d" % (i, j))
old_block = s[i:j]
if "0.05 + dc_pulse * 0.04" not in old_block:
    sys.exit("旧函数特征不匹配（可能已升级过）")

NEW = NL.join([
    "func _draw_damage_cap_aura(center: Vector2, w: float, h: float) -> void:",
    "\t## 免伤力场（`GameEngine.damage_cap_left(p) == 0` 的唯一表现口，R780b）。",
    "\t## 赫尔墨斯 9140 / 量产型赫尔墨斯 9188 本回合的 20 点伤害额度已经吃满，",
    "\t## 接下来所有伤害都被上限吃掉、一点血也扣不动。",
    "\t## ⚠️ 形状必须和现有那几个环分开：实线圆环已被嘲讽（橙）/ 冰封（冷蓝）/ 沉睡（紫）/",
    "\t##    屏障（青）/ 可发动（黄绿）用满，虚线圆环是眩晕（金）。这里用**贴卡框的六边形** ——",
    "\t##    力场 / 结界是硬的、有棱角的语义，形状上一眼就能和「状态环」分开。",
    "\t## ⚠️ **必须先压一道深色底线，再画亮金**：实战背景是亮青色水面（R780b 实拍），",
    "\t##    单画一条半透明金线在亮背景上几乎看不见；它还会和卡牌自己的金色边框",
    "\t##    糊成一片，看起来像「卡框描边加粗了」而不是「多了个力场」。",
    "\t##    深底 + 亮金是亮底上唯一立得住的画法，顶点方块同样双层。",
    "\t## ⚠️ 六边形**不旋转**：按椭圆参数化转起来会变形（看起来像在抖），",
    "\t##    改成呼吸式缩放 + 顶点亮点明暗，动感够而不晃眼。",
    "\t## ⚠️ 薄金罩只压 6%→11%：再厚就把卡图糊了，玩家会看不清那到底是谁。",
    "\tvar dc_t := float(_now()) / 1000.0",
    "\tvar dc_pulse := (sin(dc_t * 2.6) + 1.0) * 0.5",
    "\tvar dc_col := Color(1.0, 0.90, 0.55)",
    "\tdraw_rect(Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h)),",
    "\t\t\tColor(dc_col.r, dc_col.g, dc_col.b, 0.06 + dc_pulse * 0.05), true)",
    "\tfor k in 2:",
    "\t\tvar hw := w * 0.5 + 5.0 + float(k) * 6.0 + dc_pulse * 1.6",
    "\t\tvar hh := h * 0.5 + 5.0 + float(k) * 6.0 + dc_pulse * 1.6",
    "\t\tvar pts := PackedVector2Array()",
    "\t\tfor i in 6:",
    "\t\t\tvar a: float = -PI * 0.5 + TAU * float(i) / 6.0",
    "\t\t\tpts.append(center + Vector2(cos(a) * hw, sin(a) * hh))",
    "\t\tpts.append(pts[0])",
    "\t\tdraw_polyline(pts, Color(0.10, 0.07, 0.02, 0.62), 4.4 if k == 0 else 3.0, true)",
    "\t\tdraw_polyline(pts, Color(dc_col.r, dc_col.g, dc_col.b,",
    "\t\t\t\t(0.72 if k == 0 else 0.42) + dc_pulse * 0.26), 2.6 if k == 0 else 1.5, true)",
    "\t# 六个顶点各点一颗小方块（深底 + 亮金）：呼吸时跟着亮，远看也认得出「有东西罩着」",
    "\tfor i in 6:",
    "\t\tvar a2: float = -PI * 0.5 + TAU * float(i) / 6.0",
    "\t\tvar vp := center + Vector2(cos(a2) * (w * 0.5 + 5.0 + dc_pulse * 1.6),",
    "\t\t\t\tsin(a2) * (h * 0.5 + 5.0 + dc_pulse * 1.6))",
    "\t\tvar sq := 2.4 + dc_pulse * 1.2",
    "\t\tdraw_rect(Rect2(vp - Vector2(sq, sq) * 1.5, Vector2(sq, sq) * 3.0),",
    "\t\t\t\tColor(0.10, 0.07, 0.02, 0.55), true)",
    "\t\tdraw_rect(Rect2(vp - Vector2(sq, sq), Vector2(sq, sq) * 2.0),",
    "\t\t\t\tColor(dc_col.r, dc_col.g, dc_col.b, 0.62 + dc_pulse * 0.34), true)",
    "",
    "",
])

s = s[:i] + NEW + s[j:]
io.open(P, "w", encoding="utf-8", newline="").write(s)

back = io.open(P, encoding="utf-8", newline="").read()
for needle in ("0.72 if k == 0 else 0.42", "Color(0.10, 0.07, 0.02, 0.62)", "5.0 + float(k) * 6.0"):
    if back.count(needle) != 1:
        sys.exit("回读 %r 计数 %d" % (needle, back.count(needle)))
b = io.open(P, "rb").read()
print("AURA_OK CRLF", b.count(b"\r\n"), "bareLF", b.count(b"\n") - b.count(b"\r\n"))
