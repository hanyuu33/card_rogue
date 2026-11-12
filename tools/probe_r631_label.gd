extends SceneTree
## R631 只读探针：实例化图鉴页，量 `detail_text` 这个 Label 的真实几何 / 字号 / 折行。
## 用法：Godot --headless --path . --script res://tools/probe_r631_label.gd

const CardRepo = preload("res://scripts/card_repo.gd")


func _initialize() -> void:
	_m.call_deferred()


func _m() -> void:
	var ps := load("res://scenes/gallery.tscn") as PackedScene
	var inst: Node = ps.instantiate()
	get_root().add_child(inst)
	for i in 8:
		await process_frame
	var repo := CardRepo.load_json()
	var card = null
	for c in repo.all_cards():
		if c.id == 9241:
			card = c
			break
	if card != null:
		inst._group = "enemy"
		inst._selected = card
		inst._refresh_detail()
	for i in 4:
		await process_frame
	var lb: Label = inst.detail_text
	print("[label] size=", lb.size, " pos=", lb.position)
	print("[label] font_size=", lb.get_theme_font_size("font_size"),
			" wrap=", lb.autowrap_mode, " clip=", lb.clip_text,
			" visible=", lb.visible, " modulate=", lb.modulate)
	print("[label] 文本长度=", lb.text.length())
	print("[label] 文本前40=", lb.text.substr(0, 40).replace("\n", "\\n"))
	var f: Font = lb.get_theme_font("font")
	print("[font] ", f, " h16=", f.get_height(16), " d16=", f.get_descent(16),
			" h11=", f.get_height(11), " d11=", f.get_descent(11))
	for fs in [16, 14, 13, 12, 11]:
		var probe := ""
		for ch in lb.text:
			if f.get_string_size(probe + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= lb.size.x:
				probe += ch
			else:
				break
		print("[%dpx] 首行 %2d 字 [%s]" % [fs, probe.length(), probe])
	quit()
