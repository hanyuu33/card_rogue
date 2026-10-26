extends SceneTree

## R388b 探针：确认倍速按钮要用的符号在当前字体里能不能画出来、多宽。
## 按钮用的是 battle.tscn 里的 SystemFont(Microsoft YaHei UI)，不是工程的思源黑体。

func _init() -> void:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	var proj: Font = load("res://scripts/ui_theme.gd").font()
	var cps := [0x25B6, 0x23E9, 0x23F5, 0x25BA, 0x00BB, 0x25B8]
	for cp in cps:
		var ch := String.chr(cp)
		var w13 := sys.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var wp := proj.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		print("cp=U+%04X ch=[%s] sys_has=%s sys_w=%.1f proj_has=%s proj_w=%.1f"
				% [cp, ch, str(sys.has_char(cp)), w13, str(proj.has_char(cp)), wp])
	# 三种候选文案的整体宽度（13 号，SystemFont）
	for t in ["×1", "×1.5", "×2", "▶×1", "▶ ×1", "⏩×1.5", "⏩ ×1.5", "⏩×2", "▶▶×2"]:
		print("text=[%s] w=%.1f" % [t, sys.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x])
	quit()
