extends CanvasLayer
## 全局玩家状态条（R169 · autoload）：run 进行中任何界面都悬在左上角，
## 显示职业头像 + 当前生命 / 最大生命。
##
## 标题 / 选人 / 图鉴 / 录像列表等界面自动隐藏。

const UiTheme = preload("res://scripts/ui_theme.gd")

const SIZE := Vector2(234, 40)      # R181：加宽以容纳金币（血量右边）
const BG := Color("1a1c22")
const BORDER := Color("d4a84b")
const TEXT := Color("ece7db")
const GOLD_TEXT := Color("ffd75a")  # R181：金币数字（金色）

var _last_scene_path := ""
var _last_hp := -999
var _last_max := -999
var _last_gold := -999


func _ready() -> void:
	layer = 90
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(8, 8)
	panel.size = SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = BORDER
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.position = Vector2(6, 6)
	avatar.size = Vector2(28, 28)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(avatar)

	var hp := Label.new()
	hp.name = "HpLabel"
	hp.position = Vector2(40, 9)
	hp.size = Vector2(100, 22)
	hp.add_theme_font_override("font", UiTheme.font())
	hp.add_theme_font_size_override("font_size", 16)
	hp.add_theme_color_override("font_color", TEXT)
	hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hp)

	# R181：金币图标 + 数字，放在血量右边（同一个状态条框内）。
	var gold_icon := TextureRect.new()
	gold_icon.name = "GoldIcon"
	gold_icon.position = Vector2(146, 9)
	gold_icon.size = Vector2(22, 22)
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(gold_icon)

	var gold := Label.new()
	gold.name = "GoldLabel"
	gold.position = Vector2(170, 9)
	gold.size = Vector2(58, 22)
	gold.add_theme_font_override("font", UiTheme.font())
	gold.add_theme_font_size_override("font_size", 16)
	gold.add_theme_color_override("font_color", GOLD_TEXT)
	gold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(gold)

	visible = false


func _process(_delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var scene := tree.current_scene
	var path := scene.scene_file_path if scene != null else ""
	var need := RunState.run_active and path != "" \
			and not _is_menu_scene(path)
	if path != _last_scene_path:
		_last_scene_path = path
		visible = need
		if need:
			_update()
	if need and (_last_hp != RunState.hp or _last_max != RunState.max_hp \
			or _last_gold != RunState.gold):
		_update()


func _is_menu_scene(path: String) -> bool:
	for suffix in ["title.tscn", "class_pick.tscn", "replay_list.tscn", "gallery.tscn"]:
		if path.ends_with(suffix):
			return true
	return false


func _update() -> void:
	_last_hp = RunState.hp
	_last_max = RunState.max_hp
	var panel := get_child(0) as Panel
	if panel == null:
		return
	var avatar: TextureRect = panel.get_node("Avatar")
	avatar.texture = UiAssets.class_avatar(RunState.player_class)
	var hp: Label = panel.get_node("HpLabel")
	hp.text = "生命 %d / %d" % [RunState.hp, RunState.max_hp]
	_last_gold = RunState.gold
	var gicon: TextureRect = panel.get_node("GoldIcon")
	gicon.texture = UiAssets.get_tex("icon_gold")
	var gold: Label = panel.get_node("GoldLabel")
	gold.text = "%d" % RunState.gold
