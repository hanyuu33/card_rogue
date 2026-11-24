# -*- coding: utf-8 -*-
"""R753：石头图标折面改 Y 形（原来两道折线连成一条对角线，读起来像「禁止」），
顺手删掉按钮栏里的两行 DBG 打印。"""
import io
import sys

ROOT = "E:/work/card_rogue/"

OLD = """	ci.draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.28))
	# 描边（首尾闭合，逐段画才吃得到线宽）
	for i in pts.size():
		ci.draw_line(pts[i], pts[(i + 1) % pts.size()], col, w, true)
	# 内部一道折面：让平面读成「立体的石头」
	ci.draw_line(Vector2(c.x - s * 0.17, c.y - s * 0.16),
			Vector2(c.x + s * 0.02, c.y + s * 0.02), col, w * 0.8, true)
	ci.draw_line(Vector2(c.x + s * 0.02, c.y + s * 0.02),
			Vector2(c.x + s * 0.20, c.y + s * 0.16), col, w * 0.8, true)
"""

NEW = """	ci.draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.28))
	# 受光面（左上那一片）先铺一层更亮的底，折面才有厚度感
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - s * 0.26, c.y + s * 0.10),
		Vector2(c.x - s * 0.17, c.y - s * 0.16),
		Vector2(c.x + s * 0.04, c.y - s * 0.25),
		Vector2(c.x - s * 0.02, c.y + s * 0.06)]),
		Color(1, 1, 1, 0.10))
	# 描边（首尾闭合，逐段画才吃得到线宽）
	for i in pts.size():
		ci.draw_line(pts[i], pts[(i + 1) % pts.size()], col, w, true)
	# 内部折面：**Y 形**（一竖两撇），把平面切成三片。
	# ⚠️ 别写成「左上角 → 右下角」一条直线 —— 那样整块石头读起来像「禁止」符号
	#    （R753 实测：截图里第一眼就是禁行标志）。
	ci.draw_line(Vector2(c.x + s * 0.04, c.y - s * 0.25),
			Vector2(c.x - s * 0.02, c.y + s * 0.06), col, w * 0.8, true)
	ci.draw_line(Vector2(c.x - s * 0.02, c.y + s * 0.06),
			Vector2(c.x - s * 0.26, c.y + s * 0.10), col, w * 0.8, true)
	ci.draw_line(Vector2(c.x - s * 0.02, c.y + s * 0.06),
			Vector2(c.x + s * 0.20, c.y + s * 0.16), col, w * 0.8, true)
"""

OLD2 = """	print("[DBG] paint arm=", _tool_use_arm, " until=", _tool_use_until, " now=", Time.get_ticks_msec())
"""
NEW2 = ""

OLD3 = """	print("[DBG] painting bar at ", _tool_bar_layout(slot)["bar"])
"""
NEW3 = ""


def patch(path, pairs, crlf):
    raw = io.open(ROOT + path, "r", encoding="utf-8", newline="").read()
    for old, new in pairs:
        old_e = old.replace("\n", "\r\n") if crlf else old
        new_e = new.replace("\n", "\r\n") if crlf else new
        n = raw.count(old_e)
        assert n == 1, "%s: expected 1, got %d for %r" % (path, n, old_e[:50])
        raw = raw.replace(old_e, new_e)
    io.open(ROOT + path, "w", encoding="utf-8", newline="").write(raw)
    print("patched", path)


patch("scripts/trap_art.gd", [(OLD, NEW)], False)
patch("scripts/battle_scene.gd", [(OLD2, NEW2), (OLD3, NEW3)], True)
print("ok")
