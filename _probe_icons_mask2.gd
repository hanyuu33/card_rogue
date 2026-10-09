extends SceneTree
## 一次性素材处理探针（纯 CPU 的 Image 操作，headless 可用）。
##
## 把 5 张徽章图标洗成「透明底 + 主体填满 + 圆形裁剪」。三步：
##   ① 抠底：从**图像边界**四连通扩散判背景（不然会把主体高光一起抠穿：
##      实测血滴中间破洞、弓的内圈变棋盘格）；封闭近白且面积 ≥10% 也算背景。
##   ② **裁掉透明外边距，再把主体放大到填满圆盘**（关键一步！）
##      —— 生成图的主体只占方框中间一小块，直接用会变成「深色圆盘 + 白数字」，
##      根本看不出图标是什么。放大后图标才真正成为徽章的"底"。
##   ③ 圆形遮罩（半径 = 半边长，2px 羽化）—— 徽章必须是圆。
##
## 用法：godot --headless --path . --script res://_probe_icons_mask2.gd

const KEYS := ["cost", "power", "range", "health", "speed"]
const SIZE := 192
const WHITE_LO := 226.0     # 三通道最小值 ≥ 此值 → 判为「近白」
const BIG_HOLE := 0.10      # 封闭近白区域占比 ≥ 此值 → 也算背景
const FILL := 0.92          # 主体最长边占方框的比例（留一点边，免得贴死圆盘边）


func _process_one(key: String) -> void:
	var path := "res://assets/ui/icon_%s.png" % key
	var img := Image.new()
	if img.load(path) != OK:
		print("  MISS ", path)
		return
	img.convert(Image.FORMAT_RGBA8)
	img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)

	var n := SIZE * SIZE
	var white := PackedByteArray()
	white.resize(n)
	for y in SIZE:
		for x in SIZE:
			var c := img.get_pixel(x, y)
			white[y * SIZE + x] = 1 if minf(c.r, minf(c.g, c.b)) * 255.0 >= WHITE_LO else 0

	# ── ① 连通域判背景 ──
	var label := PackedInt32Array()
	label.resize(n)
	for i in n:
		label[i] = -1
	var areas: Array[int] = []
	var touches: Array[bool] = []
	for i in n:
		if white[i] == 0 or label[i] >= 0:
			continue
		var id := areas.size()
		areas.append(0)
		touches.append(false)
		var stack: Array[int] = [i]
		label[i] = id
		while not stack.is_empty():
			var p: int = stack.pop_back()
			areas[id] += 1
			var px := p % SIZE
			var py := p / SIZE
			if px == 0 or py == 0 or px == SIZE - 1 or py == SIZE - 1:
				touches[id] = true
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx: int = px + int(d[0])
				var ny: int = py + int(d[1])
				if nx < 0 or ny < 0 or nx >= SIZE or ny >= SIZE:
					continue
				var q := ny * SIZE + nx
				if white[q] == 1 and label[q] < 0:
					label[q] = id
					stack.append(q)
	var big: int = int(float(n) * BIG_HOLE)
	for y in SIZE:
		for x in SIZE:
			var i2 := y * SIZE + x
			if white[i2] == 1:
				var kk := label[i2]
				if touches[kk] or areas[kk] >= big:
					var c := img.get_pixel(x, y)
					c.a = 0.0
					img.set_pixel(x, y, c)

	# ── ② 裁透明边 + 放大填满 ──
	var minx := SIZE
	var miny := SIZE
	var maxx := -1
	var maxy := -1
	for y in SIZE:
		for x in SIZE:
			if img.get_pixel(x, y).a > 0.5:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	if maxx < minx or maxy < miny:
		print("  %-8s 全透明？跳过" % key)
		return
	var cw := maxx - minx + 1
	var ch := maxy - miny + 1
	var crop := img.get_region(Rect2i(minx, miny, cw, ch))
	var target := float(SIZE) * FILL
	var s := target / float(maxi(cw, ch))
	var nw := maxi(1, roundi(cw * s))
	var nh := maxi(1, roundi(ch * s))
	crop.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blend_rect(crop, Rect2i(0, 0, nw, nh), Vector2i((SIZE - nw) / 2, (SIZE - nh) / 2))

	# ── ③ 圆形遮罩 ──
	var cc := float(SIZE) / 2.0
	for y in SIZE:
		for x in SIZE:
			var col := out.get_pixel(x, y)
			var d := Vector2(float(x) + 0.5 - cc, float(y) + 0.5 - cc).length()
			col.a = col.a * clampf((cc - d) / 2.0 + 0.5, 0.0, 1.0)
			out.set_pixel(x, y, col)
	out.save_png(path)
	print("  %-8s 主体 %dx%d → 放大到 %dx%d（目标填满 %.0f%%）"
			% [key, cw, ch, nw, nh, FILL * 100.0])


func _init() -> void:
	print("=== 徽章图标：抠底 + 裁边放大 + 圆形裁剪 ===")
	for k in KEYS:
		_process_one(k)
	print("完成（已就地写回 assets/ui/icon_*.png）")
	quit()
