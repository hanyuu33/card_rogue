extends Control
## 起点道具三选一 —— 新 run 在起点获得一次选择初始道具的机会：
## RunState.relic_choice 里是 3 个随机不重复的初始道具，选 1 个收下。
## 即时道具需要再选卡的（源数之力 / 失忆药水）→ 转交卡组编辑场景。

const UiTheme = preload("res://scripts/ui_theme.gd")

const CARD_W := 264.0
const CARD_H := 336.0
const GAP := 56.0
const AREA_Y := 168.0
const LIFT := 12.0

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null      # Esc 主菜单（R148）
var _hover := -1
var _picked := false

@onready var title_label: Label = $TopBar/TitleLabel


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	# 牌库任何时候都可以查看（无论在哪个界面）
	DeckViewer.attach(self)
	RelicViewer.attach(self, Vector2(1044, 6))
	title_label.text = "选择你的%s起始道具（三选一）" % GameLayers.layer_name(RunState.current_layer)
	# -- --layer2：演示第二层起始道具三选一（截图验证用）
	if "--layer2" in OS.get_cmdline_user_args():
		RunState.current_layer = GameLayers.LAYER_TWO
		RunState.relic_choice = []
		title_label.text = "选择你的%s起始道具（三选一）" % GameLayers.layer_name(RunState.current_layer)
	if RunState.relic_choice.is_empty():
		# 直接打开（调试/截图）：临时给一组候选（本层起始道具池的前 3 个）
		var pool: Array[int] = RelicRepo.load_json().start_ids_for_layer(RunState.current_layer)
		RunState.relic_choice = pool.slice(0, mini(3, pool.size()))
	# -- --screenshot：自动截图退出（视觉验证用）
	if "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("screenshot_relic_pick.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	queue_redraw()
	# R148：Esc 主菜单
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "继续选道具",
		"sub": "选择起始道具 · 按 Esc 返回",
	})


func _card_rect(i: int) -> Rect2:
	var total := 3 * CARD_W + 2 * GAP
	var x0 := (size.x - total) / 2.0
	return Rect2(x0 + i * (CARD_W + GAP),
			AREA_Y - (LIFT if i == _hover and not _picked else 0.0), CARD_W, CARD_H)


func _draw() -> void:
	# 背景（根节点自绘在子节点之下，BG 色块会盖住 _draw，故在这里画）
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.SCREEN_BG)   # R154：墨蓝夜色锚点（清单 §2.6）
	if _picked:
		return
	var repo := RelicRepo.load_json()
	draw_string(_font, Vector2(0, 120), "起点处的一位行商愿意送你一件随身之物……",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.INK_300)
	for i in RunState.relic_choice.size():
		var rel := repo.get_relic(RunState.relic_choice[i])
		if rel == null:
			continue
		var rect := _card_rect(i)
		if i == _hover:
			draw_rect(rect.grow(10.0), Color(1, 1, 1, 0.10), true)
		# 面板：深色底 + 来源色边框（初始白/奖励黄/事件紫）
		draw_rect(rect, UiTheme.PANEL_DARK, true)   # R154：暗底锚点
		draw_rect(rect, rel.source_color(), false, 2.5)
		# 顶部来源色带 + 类别名
		var band := Rect2(rect.position, Vector2(rect.size.x, 34))
		draw_rect(band, Color(rel.source_color(), 0.30), true)
		draw_string(_font_bold, band.position + Vector2(0, 23), "道具 · %s" % rel.kind,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, UiTheme.FS_BODY, rel.source_color())
		# 名称
		draw_string(_font_bold, rect.position + Vector2(0, 78), rel.relic_name,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, UiTheme.FS_HEADING, Color("f2ead0"))
		# 描述（字符级换行）
		var y := 116.0
		for line: String in _wrap_text(rel.desc, rect.size.x - 40.0, 15):
			draw_string(_font, rect.position + Vector2(20, y), line,
					HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40.0, UiTheme.FS_BODY, Color("cfcabb"))
			y += 24.0
		draw_string(_font, rect.position + Vector2(0, rect.size.y - 18),
				"点击收下", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, UiTheme.FS_LABEL, UiTheme.INK_ON_DARK)


func _wrap_text(text: String, max_w: float, px: int) -> Array[String]:
	var out: Array[String] = []
	var cur := ""
	for ch in text:
		if _font.get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w \
				and cur != "":
			out.append(cur)
			cur = ch
		else:
			cur += ch
	out.append(cur)
	return out


func _menu_items() -> Array:
	## 本界面的 Esc 菜单项（R148）。⚠️ 每次打开菜单都会重新调用（见 UiMenu.attach 注释），
	## 所以音效这类随状态变的文案永远是最新的。
	return [
		{"text": func(): return "音效：开" if sfx.enabled else "音效：关",
			"fn": _toggle_sound, "keep_open": true},
		{"text": "返回标题", "fn": _on_back_to_title},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _on_back_to_title() -> void:
	## R167：回标题 = **保留本局**（只复位内存状态，续档留着）。
	if ReplayLog.playing:
		ReplayLog.stop_playback()      # 回放中：只停回放，别碰玩家存档
	elif ReplayLog.recording:
		ReplayLog.finish("quit")
	if RunState.run_active:
		RunState.end_run(false)
	SceneFx.goto("res://scenes/title.tscn")


func _unhandled_input(event: InputEvent) -> void:
	# R148：Esc = 主菜单（菜单开着时它自己关掉自己）
	if _menu != null and _menu.handle_esc(event):
		return


func _gui_input(event: InputEvent) -> void:
	if _picked or ReplayLog.playing:
		return
	if event is InputEventMouseMotion:
		var idx := _index_at(event.position)
		if idx != _hover:
			_hover = idx
			queue_redraw()   # R186：悬停变化才重绘（原来靠 _process 每帧重绘）
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var pick := _index_at(event.position)
		if pick >= 0:
			_choose(RunState.relic_choice[pick])


func _index_at(pos: Vector2) -> int:
	for i in RunState.relic_choice.size():
		if _card_rect(i).grow(6.0).has_point(pos):
			return i
	return -1


func _choose(id: int) -> void:
	ReplayLog.ev("relic_pick", {"id": id})   # 录像：起点道具三选一
	_picked = true
	sfx.play("click")
	RunState.choose_start_relic(id)
	if RunState.pending_relic > 0:
		# 即时道具需要再选一张卡（源数之力 / 失忆药水）
		SceneFx.goto("res://scenes/deck_edit.tscn")
	else:
		SceneFx.goto("res://scenes/map.tscn")
