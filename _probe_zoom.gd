extends SceneTree
## 一次性放大探针（**全程 headless，不弹窗口**）：把截图裁区域放大，便于核对卡面版式。
## 用法：godot --headless --path . --script res://_probe_zoom.gd
##
## ⚠️ 只读 `screenshot*.png`，不改工程。产物 `_zoom_*.png` 看完即可删。
## ⚠️ 截图只走**会自退**的场景（`battle.tscn` / 标题页）。`gallery.tscn` 没有
##    `--screenshot` 实现，给它加这个参数它会一直开着不退出。

func _crop(src: Image, r: Rect2i, zoom: int, out: String) -> void:
	var sub := src.get_region(r)
	sub.resize(r.size.x * zoom, r.size.y * zoom, Image.INTERPOLATE_NEAREST)
	sub.save_png("res://" + out)
	print("  %-24s <- %s  %dx%d x%d" % [out, str(r), r.size.x, r.size.y, zoom])


func _init() -> void:
	var img := Image.new()
	var err := img.load("res://screenshot.png")
	print("screenshot.png load=", err, " size=", img.get_size())
	if err == OK:
		# 一整张战场小卡（58×70）+ 四周留量：能同时看到数值「骑在框上」的样子
		_crop(img, Rect2i(528, 190, 130, 122), 7, "_zoom_board.png")
		# 手牌一排（含悬停抬起的那张）
		_crop(img, Rect2i(320, 578, 480, 142), 3, "_zoom_hand.png")
		# 手牌**单张卡的整个下半**（文字区 + 底部一排数值）—— 检查文字是否被挤
		_crop(img, Rect2i(388, 600, 130, 120), 6, "_zoom_hand1.png")
	quit()
