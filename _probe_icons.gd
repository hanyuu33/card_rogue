extends SceneTree
## 一次性对照图探针（纯 CPU 的 Image 操作，headless 可用）。
##
## ⚠️ 必须用 `blend_rect`（真 alpha 混合）而不是 `blit_rect`（覆盖拷贝，连 alpha 一起抄）——
##    用 blit 的话「透明」与「不透明白」在成图里**完全一样**（看图工具把透明渲染成白），
##    于是根本验不出抠底有没有生效。
##
## 用法：godot --headless --path . --script res://_probe_icons.gd

const KEYS := ["cost", "power", "range", "health", "speed"]


func _load_icon(key: String) -> Image:
	var img := Image.new()
	if img.load("res://assets/ui/icon_%s.png" % key) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


func _alpha_ratio(img: Image) -> float:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < 0.5:
				n += 1
	return float(n) / float(img.get_width() * img.get_height())


func _place(sheet: Image, img: Image, col: int, row_y: int, disp: int, zoom: int) -> void:
	var t := img.duplicate() as Image
	if disp != 0:
		t.resize(disp, disp, Image.INTERPOLATE_LANCZOS)
		t.resize(disp * zoom, disp * zoom, Image.INTERPOLATE_NEAREST)
	else:
		t.resize(160, 160, Image.INTERPOLATE_LANCZOS)
	sheet.blend_rect(t, Rect2i(0, 0, t.get_width(), t.get_height()),
			Vector2i(24 + col * 248, row_y))


func _init() -> void:
	var sheet := Image.create(1280, 620, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("252a35"))
	var imgs: Array[Image] = []
	for i in KEYS.size():
		var img := _load_icon(KEYS[i])
		imgs.append(img)
		if img == null:
			print("  MISS icon_%s.png" % KEYS[i])
		else:
			print("  %-8s 透明像素占比 %.1f%%  (%dx%d)"
					% [KEYS[i], _alpha_ratio(img) * 100.0, img.get_width(), img.get_height()])
	for i in imgs.size():
		if imgs[i] != null:
			_place(sheet, imgs[i], i, 16, 0, 1)
	for i in imgs.size():
		if imgs[i] != null:
			_place(sheet, imgs[i], i, 200, 14, 8)
	for i in imgs.size():
		if imgs[i] != null:
			_place(sheet, imgs[i], i, 330, 28, 8)
	sheet.save_png("res://_icon_sheet.png")
	print("saved res://_icon_sheet.png  (上=细节 中=14px×8 下=28px×8)")
	quit()
