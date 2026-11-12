# -*- coding: utf-8 -*-
"""R631 补丁：道具悬停提示面板严格限定（换行 + 缩字号 + 不出框 + 不裁字）。

两条硬伤：
  ① draw_string(..., width=inner, ...) 的 width 会**把超宽部分直接裁掉** ——
     折行贴边的「力量 -1」整段消失（用户口径「暗影斗篷看不到 -力量」）。
  ② 面板高度 = 行数 × 固定行距，没有上限 —— 长描述一路顶出窗口。

CRLF 文件，必须逐字节保留换行。
"""
import io
import sys

P = "scripts/battle_scene.gd"

NEW = '''const RELIC_TIP_W := 480.0
const RELIC_TIP_PAD := 12.0
const RELIC_TIP_SIZE := 13
const RELIC_TIP_SIZE_MIN := 10
const RELIC_TIP_LINE := 18.0


func _draw_relic_tip_panel() -> void:
	## 道具悬停说明：浮动折行面板（长描述如「叠加态的鸭」不溢出）。
	## 位置优先贴在道具栏上方；上方放不下就翻到下方。两个轴都夹进窗口内。
	##
	## R631（用户口径「暗影斗篷看不到力量 -1」「描述超过格子」）修掉两个硬伤：
	##   ① 以前每行是 `draw_string(..., width = inner, ...)` —— draw_string 的 width
	##      **不只是对齐宽度，超出部分会被直接裁掉**。折行时贴在右边界的那一小段
	##      （幻影斗篷的「力量 -1」正好卡在那儿）整块消失，玩家永远读不到。
	##      现在 width 一律传 -1（不裁），「每行不超宽」由折行 + 安全余量保证。
	##   ② 面板高 = 行数 × 固定行距，没有上限 —— 长描述会一路顶到窗口外。
	##      现在先按「道具栏上方 / 下方各自能腾出的高度」取大的那侧，放不下
	##      先缩字号（13 → 10），缩到底仍放不下才按高度截断补「…」。
	var w := RELIC_TIP_W
	var inner := w - RELIC_TIP_PAD * 2.0
	var z := _relic_zone_rect()
	var x: float = clampf(z.position.x + z.size.x - w, 8.0, maxf(8.0, WINDOW_W - w - 8.0))
	# 两个候选位置各自能腾出的高度（贴着窗口内边距 8）
	var room_up: float = z.position.y - 10.0 - 8.0
	var room_dn: float = WINDOW_H - (z.position.y + z.size.y + 10.0) - 8.0
	var max_h: float = minf(WINDOW_H - 16.0, maxf(room_up, maxf(room_dn, 60.0)))
	var fs := RELIC_TIP_SIZE
	var lines := CardFace.wrap_text(_font, _hover_relic_tip, inner, fs)
	var lh: float = maxf(_font.get_height(fs), float(fs))
	while fs > RELIC_TIP_SIZE_MIN:
		if RELIC_TIP_PAD * 2.0 + lines.size() * lh <= max_h:
			break
		fs -= 1
		lines = CardFace.wrap_text(_font, _hover_relic_tip, inner, fs)
		lh = maxf(_font.get_height(fs), float(fs))
	# 缩到下限仍超高 → 按可用高度截断（末行补「…」），绝不画到窗口外
	var max_lines: int = maxi(1, int(floor((max_h - RELIC_TIP_PAD * 2.0) / lh)))
	if lines.size() > max_lines:
		var keep: Array[String] = []
		for li in max_lines:
			keep.append(lines[li])
		keep[max_lines - 1] = CardFace.ellipsize(_font,
				keep[max_lines - 1] + "…", inner, fs)
		lines = keep
	var h: float = RELIC_TIP_PAD * 2.0 + lines.size() * lh
	var y: float = z.position.y - h - 10.0
	if y < 8.0:
		y = z.position.y + z.size.y + 10.0
	y = clampf(y, 8.0, maxf(8.0, WINDOW_H - h - 8.0))
	draw_rect(Rect2(x, y, w, h), Color(0.10, 0.11, 0.15, 0.95), true)
	draw_rect(Rect2(x, y, w, h), UiTheme.ACCENT_GOLD, false, 1.2)
	for li in lines.size():
		# 行槽 = [y+pad + li*lh, +lh]，基线取槽中心下方 0.36em（与 _draw_string_center 同约定）
		var by: float = y + RELIC_TIP_PAD + lh * (float(li) + 0.5) + fs * 0.36
		draw_string(_font, Vector2(x + RELIC_TIP_PAD, by), lines[li],
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f0ead8"))


'''

raw = io.open(P, encoding="utf-8", newline="").read()
start_mark = "const RELIC_TIP_W := 480.0"
end_mark = "func _draw_log_panel() -> void:"
i = raw.find(start_mark)
j = raw.find(end_mark)
assert i >= 0 and j > i, (i, j)
old = raw[i:j]
assert old.count("func _draw_relic_tip_panel") == 1, old.count("func _draw_relic_tip_panel")
new = NEW.replace("\n", "\r\n")
raw2 = raw[:i] + new + raw[j:]
io.open(P, "w", encoding="utf-8", newline="").write(raw2)

b = io.open(P, "rb").read()
print("CRLF", b.count(b"\r\n"), "bareLF", b.count(b"\n") - b.count(b"\r\n"))
print("patched", len(old), "->", len(new))
