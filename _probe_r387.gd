extends SceneTree
const UiTheme = preload("res://scripts/ui_theme.gd")
## R387 探针（**必须开窗口**，别加 --headless）：核验「程 / 速」数值徽章改为读
## 实际生效值之后，战场卡面的鞋子写的是 1（红）/ 0，而不是卡库原值 2。
## 用法：
##   Godot_v4.3-stable_win64_console.exe --path . --script res://_probe_r387.gd
## 出图：res://shot_r387_speed.png
## 判读：三张并排 ——
##   ① 左：不传 override（= 手牌 / 图鉴口径）→ 鞋 2、白字
##   ② 中：传 effective_speed()=1（启示者阶段 2）→ 鞋 1、红字
##   ③ 右：传 effective_speed()=0（阶段 3）→ 鞋 0、红字

const W := 1120
const H := 460
const CARD_W := 154.0
const CARD_H := 184.0

var _frames := 0
var _drawer: Control = null


class Drawer extends Control:
	var items: Array = []
	var f: Font
	var fb: Font

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("1b2233"), true)
		for it: Dictionary in items:
			var card: CardData = it["card"]
			var rect: Rect2 = it["rect"]
			CardFace.draw(self, card, rect, card.health, false, false, f, fb,
					-1, true, false, true, 0, int(it["spd"]), int(it["rng"]))
			draw_string(fb, Vector2(rect.position.x, rect.position.y - 18.0),
					str(it["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffe9c0"))
			draw_string(f, Vector2(rect.position.x, rect.end.y + 26.0),
					str(it["note"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("b9c6d8"))


func _initialize() -> void:
	var repo := CardRepo.load_json()
	var boss: CardData = CardData.from_dict(repo.get_card(GameEngine.REVELATOR_ID).to_dict())
	_drawer = Drawer.new()
	_drawer.size = Vector2(W, H)
	_drawer.f = UiTheme.font()
	_drawer.fb = UiTheme.font_bold()
	_drawer.items = [
		{"card": boss, "rect": Rect2(90, 130, CARD_W, CARD_H),
				"spd": -1, "rng": -1, "label": "① 不传 override（手牌 / 图鉴口径）",
				"note": "鞋 = 卡面原值 2，白字"},
		{"card": boss, "rect": Rect2(483, 130, CARD_W, CARD_H),
				"spd": 1, "rng": 2, "label": "② 阶段 2：effective_speed() = 1",
				"note": "鞋 = 1、红字（原值 2）"},
		{"card": boss, "rect": Rect2(876, 130, CARD_W, CARD_H),
				"spd": 0, "rng": 4, "label": "③ 阶段 3：effective_speed() = 0",
				"note": "鞋 = 0、红字；程 = 4、绿字"},
	]
	root.add_child(_drawer)
	root.size = Vector2i(W, H)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://shot_r387_speed.png"))
	print("PROBE R387: shot_r387_speed.png saved %s" % str(img.get_size()))
	return true
