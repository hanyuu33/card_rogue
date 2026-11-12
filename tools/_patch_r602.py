"""R602 补丁：battle_scene.gd（CRLF）—— 左栏详情三行文字加宽度约束。

跑法：python tools/_patch_r601.py [--check-only]
"""
import sys

P = r"scripts/battle_scene.gd"
CHECK = "--check-only" in sys.argv
s = open(P, "r", encoding="utf-8", newline="").read()
orig = s
ops = []


def rep(name, old, new):
    global s
    o = old.replace("\n", "\r\n")
    n = new.replace("\n", "\r\n")
    c = s.count(o)
    if c != 1:
        print(f"[FAIL] {name}: count={c}")
        sys.exit(1)
    s = s.replace(o, n)
    ops.append(name)
    print(f"[ok] {name}")


rep("sig", """func _draw_string_nw(font: Font, px: int, text: String, pos: Vector2, col: Color,
		outline := 0, outline_col := UiTheme.SURFACE) -> void:
	if px < 7:
		px = 7""", """func _draw_string_nw(font: Font, px: int, text: String, pos: Vector2, col: Color,
		outline := 0, outline_col := UiTheme.SURFACE, max_w := 0.0) -> void:
	if px < 7:
		px = 7
	# R602：给了宽度就按宽度**缩字号**（单行）。左栏的卡名 / 费用 / 词条行原本用
	# width=-1 硬画，长名字会直接冲出 296px 的信息栏、压到战场或面板框线上。
	if max_w > 1.0:
		px = UiTheme.fit_font_size(font, text, max_w, 9999.0, px, 8)""")

rep("name", """	_draw_string_nw(_font_bold, UI_FS_CAPTION, "#%d %s" % [card.id, card.card_name],
			Vector2(left, y), card.rarity_color(), -1)""", """	_draw_string_nw(_font_bold, UI_FS_CAPTION, "#%d %s" % [card.id, card.card_name],
			Vector2(left, y), card.rarity_color(), -1, UiTheme.SURFACE, inner_w)""")

rep("cost", """	_draw_string_nw(_font, UI_FS_MICRO, cost_line,
			Vector2(left, y), COL_COST_LOW_BG if cost_low else UiTheme.INK_600, -1)""", """	_draw_string_nw(_font, UI_FS_MICRO, cost_line,
			Vector2(left, y), COL_COST_LOW_BG if cost_low else UiTheme.INK_600, -1,
			UiTheme.SURFACE, inner_w)""")

rep("traits", """		_draw_string_nw(_font, UI_FS_MICRO, "词条：" + tt, Vector2(left, y),
				Color("886000"), -1)""", """		_draw_string_nw(_font, UI_FS_MICRO, "词条：" + tt, Vector2(left, y),
				Color("886000"), -1, UiTheme.SURFACE, inner_w)""")

if CHECK:
    print(f"[check] would apply {len(ops)} ops, changed={s != orig}")
    sys.exit(0)
open(P, "w", encoding="utf-8", newline="").write(s)
print(f"[written] {P} ops={len(ops)}")
b = open(P, "rb").read()
crlf = b.count(b"\r\n")
lf = b.count(b"\n") - crlf
print(f"[eol] crlf={crlf} bare_lf={lf}")
