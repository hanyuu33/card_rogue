# -*- coding: utf-8 -*-
"""R631 补丁：道具浏览面板的说明行距改成「字体真实行高」。

`RELIC_P_LINE := 17.0` 是按 10px 正文量的经验值。正文提到 13px 之后，
13px 的字高约 20 —— 行距 17 会让相邻两行**叠字**（R115 在卡面踩过的同一个坑：
行距必须取 `font.get_height()`，不能按字号乘系数估）。
"""
import io

P = "scripts/battle_scene.gd"

EDITS = [
    ('''func _relic_panel_rows_height() -> float:
	var h := 0.0
	for r in _relic_panel_rows():
		h += RELIC_P_ROWH + (r[2] as PackedStringArray).size() * RELIC_P_LINE + 10.0
	return h''',
     '''func _relic_panel_rows_height() -> float:
	## R631：行距改走 `_relic_p_line()`（字体真实行高）—— 写死的 17px 配 13px 正文会叠字。
	var h := 0.0
	for r in _relic_panel_rows():
		h += RELIC_P_ROWH + (r[2] as PackedStringArray).size() * _relic_p_line() + 10.0
	return h


func _relic_p_line() -> float:
	## 道具面板说明行的行距（R631）。**不许写死**：字号一变，按经验值给的行距就叠字。
	## 取「字体真实行高」与「字号 × 1.3」的较大者，任何字号下都不会压到上一行。
	return maxf(_font.get_height(RELIC_P_DESC), float(RELIC_P_DESC) * 1.3)'''),
    ('''		var row_h: float = RELIC_P_ROWH + dlines.size() * RELIC_P_LINE + 10.0''',
     '''		var row_h: float = RELIC_P_ROWH + dlines.size() * _relic_p_line() + 10.0'''),
    ('''			for d_i in dlines.size():
				_draw_string_nw(_font, RELIC_P_DESC, dlines[d_i],
						Vector2(px + 36, y + RELIC_P_ROWH - 8.0 + d_i * RELIC_P_LINE),
						UiTheme.INK_600, -1)''',
     '''			for d_i in dlines.size():
				_draw_string_nw(_font, RELIC_P_DESC, dlines[d_i],
						Vector2(px + 36, y + RELIC_P_ROWH - 8.0 + d_i * _relic_p_line()),
						UiTheme.INK_600, -1)'''),
]

raw = io.open(P, encoding="utf-8", newline="").read()
for old, new in EDITS:
    o = old.replace("\n", "\r\n")
    n = new.replace("\n", "\r\n")
    assert raw.count(o) == 1, (raw.count(o), old[:60])
    raw = raw.replace(o, n, 1)
io.open(P, "w", encoding="utf-8", newline="").write(raw)
b = io.open(P, "rb").read()
print("CRLF", b.count(b"\r\n"), "bareLF", b.count(b"\n") - b.count(b"\r\n"))
