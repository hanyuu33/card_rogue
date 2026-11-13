extends SceneTree
## R656 出图：状态槽位图标一览 —— 眩晕 / 冰封 / 沉睡 2 / 倒数 3 / 可发动 / 嘲讽。
## 用法：Godot --path . --resolution 1280x720 --script res://tools/_shot_r656_slots.gd
## ⚠️ 不要加 --headless（否则渲染不出图）。结果写到 res://screenshot.png。
## ⚠️ 为什么单独出这张：battle 里槽位是 1.8 秒轮播的，随机抓帧拍到的可能是字段图标，
##    看不出「状态图标本身画对了没有」。这里每张卡只喂一个状态、`now_ms` 钉在 0，
##    队列第 0 项必然是状态 —— 一次看全六个符号。

const UiTheme := preload("res://scripts/ui_theme.gd")

class Painter extends Node2D:
	var base: CardData = null

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("22262e"), true)
		var f: FontFile = UiTheme.font()
		var fb: FontFile = UiTheme.font_bold()
		var demo: Array = [
			{"glyph": "stun", "label": "眩晕", "count": 0, "cap": "眩晕"},
			{"glyph": "frozen", "label": "冰封", "count": 0, "cap": "冰封"},
			{"glyph": "sleep", "label": "沉睡", "count": 2, "cap": "沉睡 2"},
			{"glyph": "fuse", "label": "铸造", "count": 3, "cap": "倒数 3"},
			{"glyph": "activate", "label": "可发动", "count": 0, "cap": "可发动"},
			{"glyph": "taunt", "label": "嘲讽", "count": 0, "cap": "嘲讽"},
		]
		for i in demo.size():
			var d: Dictionary = demo[i]
			var card := CardData.from_dict(base.to_dict())
			card.affixes = []                      # 清掉字段 → 槽位里只剩状态
			var x := 70.0 + float(i) * 196.0
			var rect := Rect2(x, 150.0, 150.0, 181.0)
			CardFace.draw(self, card, rect, 5, false, false, f, fb,
					-1, true, false, true, 0, -1, -1, true, true, [d])
			draw_string(fb, Vector2(x, 375.0), String(d["cap"]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		draw_string(f, Vector2(70.0, 90.0),
				"R656 状态槽位（右上角圆徽 = 图标；沉睡/倒数带数字角标）",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffd54f"))
		draw_string(f, Vector2(70.0, 470.0),
				"每张卡只喂一个状态、轮播钉在第 0 项 —— 所以看到的必然是状态图标，不是字段。",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b8c4d6"))


func _initialize() -> void:
	_m.call_deferred()


func _m() -> void:
	var repo := CardRepo.load_json()
	var painter := Painter.new()
	painter.base = repo.get_card(8003)
	get_root().add_child(painter)
	for i in 6:
		await process_frame
	painter.queue_redraw()
	for i in 3:
		await process_frame
	var img := get_root().get_texture().get_image()
	var p := ProjectSettings.globalize_path("res://screenshot.png")
	img.save_png(p)
	print("[r656] saved %s %s" % [p, str(img.get_size())])
	quit()
