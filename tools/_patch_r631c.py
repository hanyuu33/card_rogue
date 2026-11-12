# -*- coding: utf-8 -*-
"""R631 补丁：卡牌详情浮层 / 卡组查看的效果正文严格限定在框内。

两处同款问题：
  ① `maxi(1, ...)` 强制「至少画一行」→ 可用高度不足时那一行直接压到面板下边框。
  ② `draw_string(..., width = w, ...)` 的 width 会裁掉超出部分（贴边的字消失）。
"""
import io

EDITS = [
    # ── card_detail_overlay.gd ──
    ("scripts/card_detail_overlay.gd",
     '''	var eff := CardText.naturalize(_card.effect_text)
	if eff != "":
		var avail_h := t.end.y - y
		var fit := CardFace.fit_text_lines(_font, eff, w, avail_h, UiTheme.FS_BODY, 10)
		var fs := int(fit["fs"])
		var line_h := float(fit["line_h"]) + 2.0
		var lines: Array = fit["lines"]
		var n := mini(lines.size(), maxi(1, int(avail_h / line_h)))
		for li in n:
			draw_string(_font, Vector2(x, y + fs * 0.9), lines[li],
					HORIZONTAL_ALIGNMENT_LEFT, w, fs, UiTheme.INK_800)
			y += line_h''',
     '''	var eff := CardText.naturalize(_card.effect_text)
	if eff != "":
		var avail_h := t.end.y - y
		# R631：缩字号下限 10 → 9，并按「末行墨迹底」判（与卡面同一套口径）。
		var fit := CardFace.fit_text_lines(_font, eff, w, avail_h, UiTheme.FS_BODY, 9, 99, true)
		var fs := int(fit["fs"])
		var line_h := float(fit["line_h"]) + 2.0
		var lines: Array = fit["lines"]
		for li in lines.size():
			# R631：以前是 `maxi(1, int(avail_h / line_h))` —— **强制至少画一行**，
			# 可用高度不够时那一行就压到面板下边框上（用户口径「描述超过了格子」）。
			# 现在逐行确认字脚还在框内，放不下就停。
			if y + fs + 4.0 > t.end.y:
				break
			# width 传 -1：`draw_string` 的 width 会把超出部分裁掉，贴边的字会凭空消失。
			draw_string(_font, Vector2(x, y + fs * 0.9), lines[li],
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.INK_800)
			y += line_h'''),
    # ── deck_viewer.gd ──
    ("scripts/deck_viewer.gd",
     '''		var avail_h: float = maxf(20.0, py + ph - 44.0 - y)
		var fit := CardFace.fit_text_lines(_font, eff, w, avail_h, UiTheme.FS_BODY, 10)
		var fs := int(fit["fs"])
		var lh := float(fit["line_h"]) + 2.0
		var lines: Array = fit["lines"]
		var n := mini(lines.size(), maxi(0, int(avail_h / lh)))
		for li in n:
			_panel.draw_string(_font, Vector2(x, y), lines[li],
					HORIZONTAL_ALIGNMENT_LEFT, w, fs, UiTheme.INK_800)
			y += lh''',
     '''		var avail_h: float = maxf(20.0, py + ph - 44.0 - y)
		# R631：缩字号下限 10 → 9，按「末行墨迹底」判。
		var fit := CardFace.fit_text_lines(_font, eff, w, avail_h, UiTheme.FS_BODY, 9, 99, true)
		var fs := int(fit["fs"])
		var lh := float(fit["line_h"]) + 2.0
		var lines: Array = fit["lines"]
		var limit_y: float = py + ph - 44.0   # 效果文不许压到「卡组中…张」那行
		for li in lines.size():
			# R631：逐行确认字脚还在框内；width 传 -1（width 会裁字）。
			if y + fs + 4.0 > limit_y:
				break
			_panel.draw_string(_font, Vector2(x, y), lines[li],
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.INK_800)
			y += lh'''),
]

for path, old, new in EDITS:
    s = io.open(path, encoding="utf-8", newline="").read()
    n = s.count(old)
    assert n == 1, (path, n)
    s = s.replace(old, new, 1)
    io.open(path, "w", encoding="utf-8", newline="").write(s)
    b = io.open(path, "rb").read()
    print(path, "CRLF", b.count(b"\r\n"), "bareLF", b.count(b"\n") - b.count(b"\r\n"))
