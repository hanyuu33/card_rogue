extends SceneTree
## 一次性探针（headless，不弹窗）：把出图裁成若干区块并放大，用于目视核对界面。
## 用法：
##   godot --headless --path . --script res://_probe_crop.gd -- <src.png> <out_prefix> <zoom>
## 区块表写在 REGIONS（设计坐标 1280x720）。不传参时用默认值。

var REGIONS := [
	{"name": "top", "r": Rect2i(0, 0, 1280, 140)},
	{"name": "board", "r": Rect2i(280, 100, 540, 520)},
	{"name": "right", "r": Rect2i(780, 60, 500, 620)},
	{"name": "bottom", "r": Rect2i(200, 560, 780, 160)},
]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var src := "res://screenshot.png"
	if a.size() >= 1:
		src = a[0]
	var prefix := "_crop"
	if a.size() >= 2:
		prefix = a[1]
	var zoom := 1.0
	if a.size() >= 3:
		zoom = float(a[2])
	if a.size() >= 4:
		# 覆盖区块：-- <src> <prefix> <zoom> x,y,w,h
		var parts := a[3].split(",")
		if parts.size() == 4:
			REGIONS = [{"name": "one", "r": Rect2i(int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]))}]
	var im := Image.load_from_file(ProjectSettings.globalize_path(src))
	if im == null:
		im = Image.load_from_file(src)
	if im == null:
		print("!! 无法读取：", src)
		quit()
		return
	print("源尺寸：", im.get_width(), "x", im.get_height(), "  缩放：", zoom)
	for reg: Dictionary in REGIONS:
		var r: Rect2i = reg["r"]
		r = r.intersection(Rect2i(0, 0, im.get_width(), im.get_height()))
		if r.size.x <= 0 or r.size.y <= 0:
			continue
		var sub := im.get_region(r)
		if zoom != 1.0:
			sub.resize(int(r.size.x * zoom), int(r.size.y * zoom), Image.INTERPOLATE_NEAREST)
		var out := "%s_%s.png" % [prefix, reg["name"]]
		sub.save_png(ProjectSettings.globalize_path("res://" + out))
		print("  ", out, "  ", sub.get_width(), "x", sub.get_height())
	quit()
