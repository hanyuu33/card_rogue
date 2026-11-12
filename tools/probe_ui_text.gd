extends SceneTree
## R602 只读探针：把 `scenes/*.tscn` 逐个实例化，用**真实字体 + 真实布局**测量
## 所有 Label / RichTextLabel / Button 的文字是否超出控件矩形
## （超出 = 压到框线 / 画到框外；有 autowrap 的再看纵向是否撑出控件高度）。
##
## 为什么不用静态解析 tscn：① 大量文案是运行时赋值的（图鉴详情的卡名就是）；
## ② 字号 / 字体 / 内边距都有 theme override，静态算不准；③ 容器布局（HBox/VBox/
## MarginContainer）只有进树才结算。所以这里一律「实例化 → 等两帧 → 量真值」。
##
## 用法：
##   Godot_v4.3-stable_win64_console.exe --headless --path . --script tools/probe_ui_text.gd
## 产出：`res://_ui_text_audit.json` + 控制台摘要。
##
## ⚠️ 只读：不改任何场景 / 存档；每个场景实例化后立刻 queue_free。
## ⚠️ 有的场景 `_ready` 会读存档 / 起计时器，报错不影响本探针的树遍历（错误只在 stderr）。

const UiTheme = preload("res://scripts/ui_theme.gd")

var _rows: Array = []
var _dump: Array = []
var _scene_errors: Array = []
var _stat := {"label": 0, "label_text": 0, "rtl": 0, "btn": 0, "btn_text": 0}


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var paths: Array[String] = []
	var d := DirAccess.open("res://scenes")
	if d == null:
		print("[probe] NO scenes dir")
		quit()
		return
	for f in d.get_files():
		if f.ends_with(".tscn"):
			paths.append("res://scenes/" + f)
	paths.sort()
	print("[probe] scenes=%d" % paths.size())
	for p in paths:
		await _audit_scene(p)
	_write_report()
	quit()


func _audit_scene(path: String) -> void:
	var ps := load(path) as PackedScene
	if ps == null:
		_scene_errors.append({"scene": path, "error": "load failed"})
		return
	var inst: Node = ps.instantiate()
	if inst == null:
		_scene_errors.append({"scene": path, "error": "instantiate failed"})
		return
	get_root().add_child(inst)
	await process_frame
	await process_frame
	await process_frame
	_walk(inst, path)
	inst.queue_free()
	await process_frame


func _walk(n: Node, scene: String) -> void:
	if n is Label:
		_check_label(n as Label, scene)
	elif n is RichTextLabel:
		_check_rtl(n as RichTextLabel, scene)
	elif n is Button:
		_check_button(n as Button, scene)
	for c in n.get_children():
		_walk(c, scene)


## 最近一层「有框」的祖先（Panel / PanelContainer / 名字像框的 Control）——
## 用来判断文字有没有越出**这一层的框**（而不只是越出 Label 自己）。
func _frame_of(n: Node) -> Control:
	var p := n.get_parent()
	while p != null:
		if p is Panel or p is PanelContainer:
			return p as Control
		var nm := String(p.name).to_lower()
		if p is Control and (nm.contains("panel") or nm.contains("frame") or nm.contains("box") or nm.contains("plate")):
			return p as Control
		p = p.get_parent()
	return null


func _is_masked(c: Control) -> bool:
	## 祖先里有 clip_contents=true 的（滚动视口 / 裁剪子节点）→ 溢出会被裁掉，
	## 不会压在别人身上，但仍然是「框里放不下」。报告里分开标注。
	var p := c.get_parent()
	while p != null:
		if p is Control and (p as Control).clip_contents:
			return true
		p = p.get_parent()
	return false


func _check_label(l: Label, scene: String) -> void:
	_stat["label"] += 1
	var t := l.text
	# 全量清单（不只溢出，连空文本也记）：空文本的 Label 往往就是「运行时才填数据」的
	# 那些框 —— 它们才是长文本溢出的真正风险点，默认冒烟测试根本量不到。
	if l.is_visible_in_tree():
		_dump.append({
			"scene": scene, "node": str(l.get_path()), "kind": "Label", "text": t,
			"empty": t.strip_edges() == "",
			"fs": l.get_theme_font_size("font_size"),
			"size": [snappedf(l.size.x, 0.1), snappedf(l.size.y, 0.1)],
			"wrap": l.autowrap_mode != TextServer.AUTOWRAP_OFF,
			"clip": l.clip_text,
			"frame": str(_frame_of(l).name) if _frame_of(l) != null else "",
		})
	if t.strip_edges() == "":
		return
	_stat["label_text"] += 1
	if not l.is_visible_in_tree():
		return
	var f := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	if f == null or fs <= 0:
		return
	var sz := l.size
	if sz.x <= 1.0 or sz.y <= 1.0:
		return
	var wrap := l.autowrap_mode != TextServer.AUTOWRAP_OFF
	var ox := 0.0
	var oy := 0.0
	var need := Vector2.ZERO
	if wrap:
		need = f.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, sz.x, fs)
		oy = need.y - sz.y
		ox = 0.0            # 折行模式下横向不会溢出（超宽单元除外，忽略）
	else:
		need = Vector2(f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
				float(f.get_height(fs)))
		ox = need.x - sz.x
		oy = need.y - sz.y
	if ox <= 1.0 and oy <= 1.0:
		return
	_rows.append({
		"scene": scene,
		"node": str(l.get_path()),
		"type": "Label",
		"text": t,
		"fs": fs,
		"wrap": wrap,
		"clip": l.clip_text,
		"size": [snappedf(sz.x, 0.1), snappedf(sz.y, 0.1)],
		"need": [snappedf(need.x, 0.1), snappedf(need.y, 0.1)],
		"over_x": snappedf(ox, 0.1),
		"over_y": snappedf(oy, 0.1),
		"masked": _is_masked(l),
		"frame": str(_frame_of(l).name) if _frame_of(l) != null else "",
	})


func _check_rtl(r: RichTextLabel, scene: String) -> void:
	_stat["rtl"] += 1
	var t := r.text
	if t.strip_edges() == "":
		return
	if not r.is_visible_in_tree():
		return
	var sz := r.size
	if sz.x <= 1.0 or sz.y <= 1.0:
		return
	var ch := r.get_content_height()
	var oy := float(ch) - sz.y
	if oy <= 1.0:
		return
	_rows.append({
		"scene": scene, "node": str(r.get_path()), "type": "RichTextLabel",
		"text": t.substr(0, 60), "fs": r.get_theme_font_size("normal_font_size"),
		"wrap": true, "clip": true,
		"size": [snappedf(sz.x, 0.1), snappedf(sz.y, 0.1)],
		"need": [snappedf(sz.x, 0.1), float(ch)],
		"over_x": 0.0, "over_y": snappedf(oy, 0.1),
		"masked": _is_masked(r),
		"frame": str(_frame_of(r).name) if _frame_of(r) != null else "",
	})


func _check_button(b: Button, scene: String) -> void:
	_stat["btn"] += 1
	var t := b.text
	if t.strip_edges() == "":
		return
	_stat["btn_text"] += 1
	if not b.is_visible_in_tree():
		return
	var f := b.get_theme_font("font")
	var fs := b.get_theme_font_size("font_size")
	if f == null or fs <= 0:
		return
	var sz := b.size
	if sz.x <= 1.0:
		return
	var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# 按钮文字左右各有内边距（stylebox content_margin，取不到就按 12 估）
	var pad := 12.0
	var sb := b.get_theme_stylebox("normal")
	if sb is StyleBox:
		pad = (sb as StyleBox).get_content_margin(SIDE_LEFT) + (sb as StyleBox).get_content_margin(SIDE_RIGHT)
	var ox := tw + pad - sz.x
	if ox <= 1.0:
		return
	_rows.append({
		"scene": scene, "node": str(b.get_path()), "type": "Button",
		"text": t, "fs": fs, "wrap": false, "clip": b.clip_text,
		"size": [snappedf(sz.x, 0.1), snappedf(sz.y, 0.1)],
		"need": [snappedf(tw, 0.1), float(f.get_height(fs))],
		"over_x": snappedf(ox, 0.1), "over_y": 0.0,
		"masked": _is_masked(b),
		"frame": str(_frame_of(b).name) if _frame_of(b) != null else "",
	})


func _write_report() -> void:
	var fa := FileAccess.open("res://_ui_text_audit.json", FileAccess.WRITE)
	if fa != null:
		fa.store_string(JSON.stringify({"rows": _rows, "labels": _dump,
				"errors": _scene_errors}, "  "))
		fa.close()
	print("[probe] overflow_rows=%d scene_errors=%d" % [_rows.size(), _scene_errors.size()])
	print("[probe] stat=%s" % str(_stat))
	# 控制台摘要：按场景聚合，最多 120 条明细
	var by_scene := {}
	for r: Dictionary in _rows:
		var k: String = str(r["scene"])
		if not by_scene.has(k):
			by_scene[k] = []
		by_scene[k].append(r)
	var keys := by_scene.keys()
	keys.sort()
	var shown := 0
	for k: String in keys:
		print("── %s  (%d)" % [k, by_scene[k].size()])
		for r: Dictionary in by_scene[k]:
			if shown >= 120:
				break
			shown += 1
			print("   %s [%s] fs=%d clip=%s size=%s need=%s over=(%s,%s) frame=%s" % [
				r["node"], r["type"], int(r["fs"]), str(r["clip"]),
				str(r["size"]), str(r["need"]), str(r["over_x"]), str(r["over_y"]),
				str(r.get("frame", ""))])
			print("      txt=%s" % str(r["text"]).substr(0, 80))
	for e: Dictionary in _scene_errors:
		print("[skip] %s : %s" % [e["scene"], e["error"]])
