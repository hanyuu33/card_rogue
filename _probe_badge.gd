extends SceneTree
## 一次性探针（headless，不弹窗）：量数值徽章上数字的真实尺寸，用来定
## CARD_BADGE_R / CARD_FS_BADGE 的取值（避免「字号够了但两位数字撑爆圆盘」）。
## 用法：godot --headless --path . --script res://_probe_badge.gd

const UiTheme = preload("res://scripts/ui_theme.gd")


func _init() -> void:
	var f := UiTheme.font_bold()
	print("== 微软雅黑 Bold 数字宽度（get_string_size）==")
	for sz: int in [9, 10, 11, 12, 13, 14]:
		var parts := PackedStringArray()
		for v: String in ["1", "2", "8", "10", "30", "50", "150", "X"]:
			parts.append("%s=%.1f" % [v, f.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x])
		print("  sz=%-2d  " % sz + "  ".join(parts))
	print()
	print("== 行高 / 上伸（判断数字墨迹高度）==")
	for sz: int in [9, 11, 12, 13, 14]:
		print("  sz=%-2d height=%.1f ascent=%.1f descent=%.1f" % [
			sz, f.get_height(sz), f.get_ascent(sz), f.get_descent(sz)])
	print()
	print("== 当前/候选参数在两种格子下的表现 ==")
	var cases := [
		{"tag": "R116 旧（战场 k=1.0）", "k": 1.0, "R": 8.5, "fs": 9.0},
		{"tag": "R117 战场（k=1.086）", "k": 76.0 / 70.0, "R": 9.2, "fs": 11.0},
		{"tag": "手牌 k=1.7", "k": 1.7, "R": 9.2, "fs": 11.0},
		{"tag": "图鉴/牌库 k=1.314", "k": 92.0 / 70.0, "R": 9.2, "fs": 11.0},
		{"tag": "奖励大卡 k=3.7", "k": 3.7, "R": 9.2, "fs": 11.0},
	]
	for c: Dictionary in cases:
		var k: float = minf(c["k"], UiTheme.CARD_BADGE_SCALE_CAP)
		var r: float = c["R"] * k
		var fs: int = maxi(7, roundi(c["fs"] * k))
		var line := "  %s：R=%.2f（直径 %.1f） 基字号=%d" % [c["tag"], r, r * 2.0, fs]
		for v: String in ["1", "30", "150"]:
			var sz := fs
			while sz > 6 and f.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > r * 1.75:
				sz -= 1
			line += "  [%s→%dpx]" % [v, sz]
		print(line)
	quit()
