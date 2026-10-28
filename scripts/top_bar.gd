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

## R351：数值变化的反馈（用户口径「获得金币和回复 HP 需要添加特效，金币最好带音效」）。
## 只在**数值真的变了**时触发；切场景 / 首次显示走 `silent = true`，不播。
const COL_HP_UP := Color("8ef0a0")
const COL_HP_DOWN := Color("ff8a7a")
const COL_GOLD_UP := Color("ffd75a")
const COL_GOLD_DOWN := Color("e0a48a")
const FX_FLOAT_SEC := 0.9
var _sfx: Sfx


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

	_sfx = Sfx.new()
	add_child(_sfx)

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
			# R423：只有**第一次**露头才静默同步。原来一律 silent —— 而战斗内本条是隐藏的
			# （R391 防它压住战斗顶栏按钮），金币偏偏是战斗结束那一刻发的（战斗掉落 /
			# 硬币 / 赏金猎人），等回到地图又被静默，`+N` 飘字永远放不出来
			# （用户口径「赏金猎人或者硬币触发后 +金币 不明显」）。
			_update(_last_gold == -999)
	if need and (_last_hp != RunState.hp or _last_max != RunState.max_hp \
			or _last_gold != RunState.gold):
		_update(false)


func _is_menu_scene(path: String) -> bool:
	## 这些界面不显示全局状态条。R391 补了 `battle.tscn`：
	## 战斗界面**左下有自己的各项 UI、顶栏也有自己的血条与按钮**，而这条状态条钉在
	## 屏幕左上 (8, 8) 234×40 —— 正好整块压住战斗顶栏的「▶1x」与「记录」两颗按钮
	## （实测出图：两颗按钮整条消失，只剩状态条）。战斗内又不用金币，所以一律不显示。
	for suffix in ["title.tscn", "class_pick.tscn", "record_list.tscn",
			"settings.tscn", "gallery.tscn", "battle.tscn"]:
		if path.ends_with(suffix):
			return true
	return false


func _update(silent := false) -> void:
	var d_hp := RunState.hp - _last_hp if _last_hp != -999 else 0
	var d_gold := RunState.gold - _last_gold if _last_gold != -999 else 0
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
	if silent:
		return
	if d_hp != 0:
		_play_delta(panel, hp, d_hp, true)
	if d_gold != 0:
		_play_delta(panel, gold, d_gold, false)


func _play_delta(panel: Panel, lbl: Label, delta: int, is_hp: bool) -> void:
	## 一次数值变化的完整反馈：① 数字弹一下并染色 ② 上方浮出 ±N ③ 音效（只给「往好处走」的）。
	## ⚠️ 浮字必须加在 **panel 里**（不是本 CanvasLayer）：它要跟着面板的 8,8 偏移一起走，
	##    而且面板显隐由本层统一管，加在外面会在隐藏时留在屏幕上。
	var up := delta > 0
	var col := COL_HP_UP if is_hp else COL_GOLD_UP
	if not up:
		col = COL_HP_DOWN if is_hp else COL_GOLD_DOWN
	var base_col := TEXT if is_hp else GOLD_TEXT

	# ① 数字染色 + 弹一下（回弹用 BACK，才有「蹦」出来的手感）
	lbl.pivot_offset = lbl.size * 0.5
	lbl.add_theme_color_override("font_color", col)
	lbl.scale = Vector2(1.30, 1.30)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.34) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.34)
	tw.chain().tween_callback(func() -> void:
		lbl.add_theme_color_override("font_color", base_col))

	# ② 上方浮出的 ±N
	var fl := Label.new()
	fl.text = ("+%d" % delta) if up else ("-%d" % absi(delta))
	fl.add_theme_font_override("font", UiTheme.font_bold())
	fl.add_theme_font_size_override("font_size", 17)
	fl.add_theme_color_override("font_color", col)
	# 深底描边：顶栏是深色面板（不是羊皮纸），描边在这里是**加清晰度**（浅底才禁止描边）。
	# 不给描边的话金币浮字「+50」会直接压在金色数字「150」上糊成一片。
	fl.add_theme_constant_override("outline_size", 4)
	fl.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.04, 0.92))
	# 起点从数值上方 10px 起、再飘 30px —— 全程浮字与数字不重叠
	fl.position = lbl.position + Vector2(0, -10)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(fl)
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(fl, "position:y", fl.position.y - 30.0, FX_FLOAT_SEC) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(fl, "modulate:a", 0.0, FX_FLOAT_SEC * 0.7) \
			.set_delay(FX_FLOAT_SEC * 0.3)
	tw2.chain().tween_callback(fl.queue_free)

	# ③ 音效：拿到钱 / 回血才响；掉钱掉血是「负面」，不给奖励音。
	if not _sfx.enabled:
		return
	if is_hp and up:
		_sfx.play("heal")
	elif not is_hp and up:
		_sfx.play("coin")
