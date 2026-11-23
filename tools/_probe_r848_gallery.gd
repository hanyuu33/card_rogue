extends SceneTree
## 临时验收探针（R848）：图鉴右栏正文「全卡 × 四语言」是否都落在框内。
## 跑法：godot --headless --path . -s tools/probe_r848_body.gd

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var g = load("res://scenes/gallery.tscn").instantiate()
	get_root().add_child(g)
	await process_frame
	await process_frame
	GameSettings.ensure_loaded()
	var box_h := float(g.BODY_H)
	var scale := float(g.BODY_LINE_SCALE)
	var worst := 0.0
	var worst_info := ""
	var over := 0
	var total := 0
	for lang in ["zh", "en", "ja", "es"]:
		GameSettings.language = lang
		GameI18n.reset_cache()
		for c in g._all:
			g._selected = c
			g._refresh_detail()
			var fs := int(g._body_fs)
			var n: int = g._body_lines.size()
			var need := float(n) * float(fs) * scale
			total += 1
			if need > box_h + 0.5:
				over += 1
				if over <= 6:
					print("  OVER %s id=%d fs=%d lines=%d need=%.0f" % [lang, c.id, fs, n, need])
			if need > worst:
				worst = need
				worst_info = "%s id=%d fs=%d lines=%d" % [lang, c.id, fs, n]
	GameSettings.language = "zh"
	GameI18n.reset_cache()
	print("=== R848 全量：%d 段，越界 %d，最坏 %.0f px（框 %.0f）—— %s" % [total, over, worst, box_h, worst_info])
	# 用户截图那张
	g._selected = null
	for c in g._all:
		if c.id == 9260:
			g._selected = c
			break
	g._refresh_detail()
	print("9260 常数测量员：fs=%d 行数=%d" % [int(g._body_fs), g._body_lines.size()])
	for ln in g._body_lines:
		print("   |", str(ln))
	quit()
