# -*- coding: utf-8 -*-
## R801：爆炸蘑菇 7016 —— trap_art.gd（颜色 / 分发 / 程序化兜底图案）
import os

os.chdir("E:/work/card_rogue")
P = "scripts/trap_art.gd"
d = open(P, "rb").read().decode("utf-8")
N = "\n"
assert d.count("\r\n") == 0, "trap_art.gd 应是纯 LF"

# ① 颜色
old = '\t\t7015: return Color(0.94, 0.62, 0.38)   # 河豚 · 河豚橙' + N
new = old + '\t\t7016: return Color(0.86, 0.32, 0.28)   # 爆炸蘑菇 · 蘑菇红' + N
assert d.count(old) == 1
d = d.replace(old, new)

# ② 分发
old = '\t\t7015: _puffer(ci, c, s, ink)' + N
new = old + '\t\t7016: _mushroom(ci, c, s, ink)' + N
assert d.count(old) == 1
d = d.replace(old, new)

# ③ 程序化图案（兜底：有 png 时整段不走）
anchor = N + N + 'static func _bomb('
assert d.count(anchor) == 1

BLOCK = '''
static func _mushroom(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
\t## R801 爆炸蘑菇 7016：半圆伞盖 + 短柄 + 弯曲引信 + 火花（程序化兜底；有 png 时整段不走）。
\t## 单色剪影 —— 与 `_bomb` / `_spike` 同一路数：斑点在同色剪影里看不见，索性不画，
\t## 44px 下靠「伞盖 + 柄 + 引信」三件认形状。
\tvar w := maxf(1.3, s * 0.028)
\tvar ty := c.y + s * 0.04
\t# 柄：上窄下宽的梯形
\tci.draw_colored_polygon(PackedVector2Array([
\t\t\tVector2(c.x - s * 0.09, ty), Vector2(c.x + s * 0.09, ty),
\t\t\tVector2(c.x + s * 0.13, ty + s * 0.28),
\t\t\tVector2(c.x - s * 0.13, ty + s * 0.28)]), col)
\t# 伞盖：上半圆（PI → TAU 那半圈，底边压在 ty 上）
\tvar pts := PackedVector2Array()
\tvar steps := 18
\tfor k in steps + 1:
\t\tvar a := PI + PI * float(k) / float(steps)
\t\tpts.append(Vector2(c.x + cos(a) * s * 0.31, ty + sin(a) * s * 0.31))
\tci.draw_colored_polygon(pts, col)
\t# 引信：从伞盖顶部往右上弯两折
\tvar base := Vector2(c.x, ty - s * 0.31)
\tvar mid := base + Vector2(s * 0.09, -s * 0.16)
\tvar tip := mid + Vector2(-s * 0.05, -s * 0.14)
\tci.draw_line(base, mid, col, w, true)
\tci.draw_line(mid, tip, col, w, true)
\t# 火花：端点一个实心点 + 两根射线，和小血瓶那种「一眼能看出是引信」的量级一致
\tci.draw_circle(tip, s * 0.05, col)
\tci.draw_line(tip, tip + Vector2(s * 0.10, -s * 0.05), col, w * 0.8, true)
\tci.draw_line(tip, tip + Vector2(-s * 0.04, -s * 0.10), col, w * 0.8, true)
'''
BLOCK = BLOCK.replace("\n", N)
d = d.replace(anchor, N + N + BLOCK.strip("\n") + N + N + "static func _bomb(")

open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
print("CRLF", b.count(b"\r\n"), "LFonly", b.count(b"\n") - b.count(b"\r\n"))
print("_mushroom 定义:", d.count("static func _mushroom("),
      "调用:", d.count("_mushroom(ci, c, s, ink)"))
