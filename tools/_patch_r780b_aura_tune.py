# -*- coding: utf-8 -*-
"""R780b：把免伤力场（`_draw_damage_cap_aura`）在亮水面上的对比度拉起来。

实测（`_shots/r780b_cap.png`）：几何形状没问题（洋红验证：六边形恰好套在卡框外，
第三张没有），但**金色线在亮青色水面上几乎看不见**，玩家只会以为「卡框好像有点亮」。

原因：暗底只有 4.4/3.0 宽、alpha 0.62，亮金 2.6/1.5 宽、alpha 0.72 —— 亮底上
线宽小于 3px 的半透明色会被背景吃掉。这里统一「深底加宽 + 亮金提高不透明度」，
不改形状、不改动画节奏。

⚠️ 之前 `_patch_r780b_aura_strong.py` 报 OK 但**数字没变**（搜索串与实际不符 → no-op），
所以本次不按「行替换」写，改成**整段替换**：从 `var dc_col` 到函数末尾一次换掉。
"""
import io
import sys

P = "E:/work/card_rogue/scripts/battle_scene.gd"
NL = "\r\n"

s = io.open(P, encoding="utf-8", newline="").read()

START = "\tvar dc_col := Color(1.0, 0.90, 0.55)"
END = NL + "func _draw_stun_aura("

i = s.find(START)
j = s.find(END, i)
if i < 0 or j < 0:
    sys.exit("找不到 aura 主体（i=%d j=%d）" % (i, j))

NEW = NL.join([
    "\tvar dc_col := Color(1.0, 0.90, 0.55)",
    "\t# 整张卡压一层极薄的金：读作「隔着玻璃罩」，但绝不能糊掉卡图（7%→13%）",
    "\tdraw_rect(Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h)),",
    "\t\t\tColor(dc_col.r, dc_col.g, dc_col.b, 0.07 + dc_pulse * 0.06), true)",
    "\tfor k in 2:",
    "\t\tvar hw := w * 0.5 + 5.0 + float(k) * 6.0 + dc_pulse * 1.6",
    "\t\tvar hh := h * 0.5 + 5.0 + float(k) * 6.0 + dc_pulse * 1.6",
    "\t\tvar pts := PackedVector2Array()",
    "\t\tfor i in 6:",
    "\t\t\tvar a: float = -PI * 0.5 + TAU * float(i) / 6.0",
    "\t\t\tpts.append(center + Vector2(cos(a) * hw, sin(a) * hh))",
    "\t\tpts.append(pts[0])",
    "\t\t# 深底必须比亮金**宽一倍**：亮水面上细半透线会被背景吃掉（实拍调出来的）",
    "\t\tdraw_polyline(pts, Color(0.06, 0.05, 0.02, 0.80), 6.2 if k == 0 else 4.2, true)",
    "\t\tdraw_polyline(pts, Color(dc_col.r, dc_col.g, dc_col.b,",
    "\t\t\t\t(0.94 if k == 0 else 0.60) + dc_pulse * 0.06), 3.4 if k == 0 else 1.9, true)",
    "\t# 六个顶点各点一颗小方块（深底 + 亮金）：呼吸时跟着亮，远看也认得出「有东西罩着」",
    "\tfor i in 6:",
    "\t\tvar a2: float = -PI * 0.5 + TAU * float(i) / 6.0",
    "\t\tvar vp := center + Vector2(cos(a2) * (w * 0.5 + 5.0 + dc_pulse * 1.6),",
    "\t\t\t\tsin(a2) * (h * 0.5 + 5.0 + dc_pulse * 1.6))",
    "\t\tvar sq := 2.6 + dc_pulse * 1.2",
    "\t\tdraw_rect(Rect2(vp - Vector2(sq, sq) * 1.6, Vector2(sq, sq) * 3.2),",
    "\t\t\t\tColor(0.06, 0.05, 0.02, 0.80), true)",
    "\t\tdraw_rect(Rect2(vp - Vector2(sq, sq), Vector2(sq, sq) * 2.0),",
    "\t\t\t\tColor(dc_col.r, dc_col.g, dc_col.b, 0.84 + dc_pulse * 0.16), true)",
    "",
])

old = s[i:j]
if "draw_polyline" not in old or len(old.split(NL)) < 18:
    sys.exit("待替换段落异常，行数 %d" % len(old.split(NL)))

s2 = s[:i] + NEW + s[j:]

# 回读校验（不只看「替换成功」，要看数字真的变了）
if "0.94 if k == 0 else 0.60" not in s2:
    sys.exit("回读失败：亮金 alpha 未写入")
if s2.count("6.2 if k == 0 else 4.2") != 1:
    sys.exit("回读失败：暗底线宽计数异常")
if "0.72 if k == 0 else 0.42" in s2:
    sys.exit("回读失败：旧 alpha 仍在")
if s2.count("func _draw_damage_cap_aura(") != 1 or s2.count("func _draw_stun_aura(") != 1:
    sys.exit("回读失败：函数边界异常")

io.open(P, "w", encoding="utf-8", newline="").write(s2)
b = io.open(P, "rb").read()
print("AURA_TUNED ok  CRLF=%d bareLF=%d  lines=%d"
      % (b.count(b"\r\n"), b.count(b"\n") - b.count(b"\r\n"), s2.count(NL)))
