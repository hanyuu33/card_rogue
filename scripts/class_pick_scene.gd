extends Control
## 角色选择 —— 出发前先定角色，再生成地图进冒险。
## 角色决定两件事（见 PlayerClass）：
##   * 初始卡组追加的专属卡（森林精魄 → 熊 8004 ×1）；
##   * 进入战斗时自动获得的角色赠品道具（森林精魄 → 荒野形态 6022）。
## 往 PlayerClass.ids() 加新角色，这里会自动多出一张卡面（卡面数 × CARD_W + 间隙
## 需放得下视口 1280：3 张 = 1056px OK；4 张 = 1448px 就要改 CARD_W/GAP 了）。

const CARD_W := 320.0
const CARD_H := 400.0
const GAP := 48.0
const AREA_Y := 150.0
const LIFT := 12.0

var _font: SystemFont
var _font_bold: SystemFont
var sfx: Sfx
var _hover := -1
var _picked := false


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	_font_bold = SystemFont.new()
	_font_bold.font_names = _font.font_names
	sfx = Sfx.new()
	add_child(sfx)
	DeckViewer.attach(self)
	RelicViewer.attach(self, Vector2(1044, 6))
	# -- --screenshot：自动截图退出（视觉验证用）
	if "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("screenshot_class_pick.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()   # 鼠标悬停跟随


func _card_rect(i: int) -> Rect2:
	var n := PlayerClass.ids().size()
	var total := n * CARD_W + maxi(0, n - 1) * GAP
	var x0 := (size.x - total) / 2.0
	return Rect2(x0 + i * (CARD_W + GAP),
			AREA_Y - (LIFT if i == _hover and not _picked else 0.0), CARD_W, CARD_H)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("252a35"))
	if _picked:
		return
	draw_string(_font, Vector2(0, 110), "出发之前，先决定你以什么身份走进这片森林……",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color("b8b4aa"))
	var ids := PlayerClass.ids()
	var relics := RelicRepo.load_json()
	for i in ids.size():
		var cid: String = ids[i]
		var rect := _card_rect(i)
		if i == _hover:
			draw_rect(rect.grow(10.0), Color(1, 1, 1, 0.10), true)
		draw_rect(rect, Color(0.16, 0.18, 0.23), true)
		draw_rect(rect, Color("4caf50"), false, 2.5)
		var band := Rect2(rect.position, Vector2(rect.size.x, 34))
		draw_rect(band, Color(0.30, 0.69, 0.31, 0.30), true)
		draw_string(_font_bold, band.position + Vector2(0, 23), "角色",
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 15, Color("8ce09a"))
		draw_string(_font_bold, rect.position + Vector2(0, 82), PlayerClass.name_of(cid),
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 30, Color("f2ead0"))
		var y := 116.0
		draw_string(_font, rect.position + Vector2(0, y), PlayerClass.subtitle_of(cid),
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, Color("9fd7a5"))
		y += 26.0
		# 概括性介绍（PlayerClass.desc_of）：只讲打法取向，**不列具体卡牌**。
		for para: String in PlayerClass.desc_of(cid).split("\n"):
			for line: String in _wrap_text(para, rect.size.x - 40.0, 14):
				draw_string(_font, rect.position + Vector2(20, y), line,
						HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40.0, 14, Color("cfcabb"))
				y += 22.0
			y += 6.0
		# 初始道具：名字 + 完整效果（读 relics.json 的 desc，R55 起展示；不列初始卡组明细）。
		var rel := relics.get_relic(PlayerClass.relic_of(cid))
		if rel != null:
			y = maxi(y + 10.0, rect.size.y - 150.0)
			draw_rect(Rect2(rect.position + Vector2(20, y - 16.0),
					Vector2(rect.size.x - 40.0, 1)), Color(1, 1, 1, 0.10), true)
			draw_string(_font_bold, rect.position + Vector2(20, y + 2.0),
					"初始道具：%s" % rel.relic_name, HORIZONTAL_ALIGNMENT_LEFT,
					rect.size.x - 40.0, 14, Color("e0b23c"))
			y += 20.0
			# 预折行再逐行画（Godot 的 draw_string 不自动换行，长文本会溢出卡面）。
			for line: String in _wrap_text(rel.desc, rect.size.x - 40.0, 12):
				if y > rect.size.y - 34.0:
					break
				draw_string(_font, rect.position + Vector2(20, y), line,
						HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40.0, 12, Color("b8b0a0"))
				y += 17.0
		draw_string(_font, rect.position + Vector2(0, rect.size.y - 18),
				"点击选择", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, Color("8a867c"))


func _wrap_text(t: String, max_w: float, px: int) -> Array[String]:
	var out: Array[String] = []
	var cur := ""
	for ch in t:
		if _font.get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w \
				and cur != "":
			out.append(cur)
			cur = ch
		else:
			cur += ch
	out.append(cur)
	return out


func _gui_input(event: InputEvent) -> void:
	if _picked:
		return
	if event is InputEventMouseMotion:
		var idx := _index_at(event.position)
		if idx != _hover:
			_hover = idx
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var pick := _index_at(event.position)
		if pick >= 0:
			_choose(PlayerClass.ids()[pick])


func _index_at(pos: Vector2) -> int:
	for i in PlayerClass.ids().size():
		if _card_rect(i).grow(6.0).has_point(pos):
			return i
	return -1


func _choose(cid: String) -> void:
	_picked = true
	sfx.play("click")
	# 角色决定：初始卡组追加的专属卡 + 战斗赠品道具（见 PlayerClass）。
	# 地图由 RunState.start_run 用本局种子生成（R46：录像回放可完整复现）。
	RunState.start_run([], GameLayers.LAYER_DEFAULT, cid)
	ReplayLog.begin_run(cid)   # 从这里开始录制本局完整流程
	get_tree().change_scene_to_file("res://scenes/map.tscn")
