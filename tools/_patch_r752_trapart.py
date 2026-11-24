# -*- coding: utf-8 -*-
"""R752 补丁：TrapArt —— 三件新工具的主色与缺图兜底图案。"""
import io

ROOT = "e:/work/card_rogue/"


def patch(path, pairs):
    full = ROOT + path
    raw = io.open(full, "r", encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw
    src = raw.replace("\r\n", "\n")
    for old, new in pairs:
        n = src.count(old)
        assert n == 1, "%s: 锚点命中 %d 次\n%r" % (path, n, old[:160])
        src = src.replace(old, new)
    out = src.replace("\n", "\r\n") if crlf else src
    io.open(full, "w", encoding="utf-8", newline="").write(out)
    print("patched", path, "CRLF" if crlf else "LF")


patch("scripts/trap_art.gd", [
    (
        """		7008: return Color(0.76, 0.55, 0.30)   # 野性图腾 · 木赭
	return Color(0.80, 0.76, 0.66)
""",
        """		7008: return Color(0.76, 0.55, 0.30)   # 野性图腾 · 木赭
		7009: return Color(0.74, 0.53, 0.96)   # 万能牌 · 幻紫
		7010: return Color(0.96, 0.72, 0.28)   # 快送鸭 · 快递黄
		7011: return Color(0.42, 0.82, 0.78)   # 神秘牌 · 谜青
	return Color(0.80, 0.76, 0.66)
""",
    ),
    (
        """		7008: _totem(ci, c, s, ink)
		_: ci.draw_circle(c, s * 0.22, ink)
""",
        """		7008: _totem(ci, c, s, ink)
		7009: _wildcard(ci, c, s, ink)
		7010: _deliver(ci, c, s, ink)
		7011: _mystery(ci, c, s, ink)
		_: ci.draw_circle(c, s * 0.22, ink)
""",
    ),
    (
        """static func _potion(ci: CanvasItem, c: Vector2, s: float, col: Color, mana: bool) -> void:
""",
        """static func _wildcard(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R752：万能牌（使用型）—— 一张立着的牌 + 中央八角星芒。
	## 「万能」在卡牌语汇里就是这颗星标（王牌 / 百搭），比画一个「W」之类的字更跨语言。
	## 与药瓶 / 烤肉同一套「画实物」的路子；有 `trap_icon_7009.png` 时整段都不走。
	var w := maxf(1.5, s * 0.032)
	ci.draw_rect(Rect2(c.x - s * 0.20, c.y - s * 0.29, s * 0.40, s * 0.58), col, false, w)
	var d := s * 0.115
	var star := PackedVector2Array([
		c + Vector2(0.0, -d * 1.75), c + Vector2(d * 0.38, -d * 0.38),
		c + Vector2(d * 1.75, 0.0), c + Vector2(d * 0.38, d * 0.38),
		c + Vector2(0.0, d * 1.75), c + Vector2(-d * 0.38, d * 0.38),
		c + Vector2(-d * 1.75, 0.0), c + Vector2(-d * 0.38, -d * 0.38)])
	ci.draw_colored_polygon(star, col)


static func _deliver(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R752：快送鸭（使用型）—— 一只快递纸箱 + 上方向上的箭头。
	## 鸭子本身在 45px 里画不成形（R745 图腾那一轮的教训：小尺寸只留得住**结构**），
	## 所以缺图兜底走「箱子 + 箭头」这个更稳的「送到你手上」符号；正式素材仍然是鸭子。
	var w := maxf(1.5, s * 0.032)
	# 箱身
	ci.draw_rect(Rect2(c.x - s * 0.23, c.y - s * 0.06, s * 0.46, s * 0.31), col, false, w)
	# 箱盖（一条横线 + 中间竖缝）
	ci.draw_line(Vector2(c.x - s * 0.23, c.y + s * 0.05),
			Vector2(c.x + s * 0.23, c.y + s * 0.05), col, w, true)
	ci.draw_line(Vector2(c.x, c.y - s * 0.06), Vector2(c.x, c.y + s * 0.05), col, w, true)
	# 向上的箭头（「送上去 / 送到」）
	ci.draw_line(Vector2(c.x, c.y - s * 0.14), Vector2(c.x, c.y - s * 0.34), col, w, true)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y - s * 0.40), Vector2(c.x - s * 0.10, c.y - s * 0.26),
		Vector2(c.x + s * 0.10, c.y - s * 0.26)]), col)


static func _mystery(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	## R752：神秘牌（使用型）—— 一张立着的牌 + 中央问号（「不知道会来哪张」）。
	## 问号由「上半弧 + 短竖线 + 一点」三笔拼出来：这个尺寸下三段圆弧是能读出来的最小写法。
	var w := maxf(1.5, s * 0.032)
	ci.draw_rect(Rect2(c.x - s * 0.20, c.y - s * 0.29, s * 0.40, s * 0.58), col, false, w)
	var hc := c + Vector2(0.0, -s * 0.08)
	ci.draw_arc(hc, s * 0.115, PI * 0.92, PI * 2.28, 18, col, w, true)
	ci.draw_line(hc + Vector2(s * 0.075, s * 0.075), c + Vector2(0.0, s * 0.09),
			col, w, true)
	ci.draw_circle(c + Vector2(0.0, s * 0.175), s * 0.035, col)


static func _potion(ci: CanvasItem, c: Vector2, s: float, col: Color, mana: bool) -> void:
""",
    ),
])

print("OK")
