extends Control
## 录像回放列表（R46）—— 选择一份录像开始完整回放。
## 每份录像 = 一局完整 run（角色 → 地图 → 战斗/事件/奖励 → 通关或失败），
## 回放时从 run 种子重建全部随机，再逐条执行录下的玩家决策。
## 文件保存在 user://replays/（自动保留最近 30 份）。

const UiTheme = preload("res://scripts/ui_theme.gd")

var _font: SystemFont
var _font_bold: SystemFont
var sfx: Sfx
var _items: Array[Dictionary] = []   # ReplayLog.list_replays() 结果
var _err := ""                       # 读取失败提示
var _hover := -1
var _hover_del := -1


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	DeckViewer.attach(self)
	RelicViewer.attach(self, Vector2(1044, 6))
	_refresh()
	# -- --screenshot：自动截图退出（视觉验证用）
	if "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_replay.png"))
			get_tree().quit())
		add_child(t)
		t.start()


func _refresh() -> void:
	_items = ReplayLog.list_replays()
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()   # 悬停跟随


# ------------------------------------------------------------ 布局

const ROW_H := 64.0
const ROW_W := 980.0
const LIST_Y := 120.0

func _row_rect(i: int) -> Rect2:
	return Rect2((size.x - ROW_W) / 2.0, LIST_Y + i * ROW_H, ROW_W, ROW_H - 10.0)


func _del_rect(i: int) -> Rect2:
	var r := _row_rect(i)
	return Rect2(r.end.x - 66.0, r.position.y + 10.0, 56.0, r.size.y - 20.0)


func _back_rect() -> Rect2:
	## 左上角「← 返回标题」按钮（R58 修复：此前**只画不响应** —— _gui_input 里漏了它的
	## 点击分支，按钮画得出来但点不动，只有 ESC 能退回去）。
	return Rect2(14, 14, 110, 34)


func _row_at(pos: Vector2) -> int:
	for i in _items.size():
		if _row_rect(i).has_point(pos):
			return i
	return -1


# ------------------------------------------------------------ 输入

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _row_at(event.position)
		if h != _hover:
			_hover = h
		var hd := -1
		for i in _items.size():
			if _del_rect(i).has_point(event.position):
				hd = i
				break
		if hd != _hover_del:
			_hover_del = hd
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# 左上角「返回标题」（R58 修复：这条分支原先缺失，按钮点不动）
		if _back_rect().has_point(event.position):
			sfx.play("click")
			_back_to_title()
			return
		for i in _items.size():
			if _del_rect(i).has_point(event.position):
				sfx.play("click")
				DirAccess.remove_absolute(ProjectSettings.globalize_path(
						str(_items[i]["path"])))
				_refresh()
				return
		var pick := _row_at(event.position)
		if pick >= 0:
			sfx.play("click")
			_play(str(_items[pick]["path"]))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_back_to_title()


func _back_to_title() -> void:
	## 返回标题：先停掉回放状态（title_scene._ready 里也会兜一次，双保险），
	## 再切场景 —— 否则中途退出回放会留下一份「正在播放」的录像。
	if ReplayLog.playing:
		ReplayLog.stop_playback()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _play(path: String) -> void:
	var meta := ReplayLog.start_playback(path)
	if meta.is_empty():
		_err = "录像读取失败（格式不符或文件损坏）"
		queue_redraw()
		return
	# 重建 run：种子与角色来自录像 → 地图/初始道具/全部摇卡按种子重放；
	# 玩家决策逐条由录像驱动（各场景自动执行）。
	RunState.run_seed = int(meta.get("run_seed", 0))
	# 难度档位同样来自录像（缺字段 = R47 之前录的，按当时的第 2 档「困难」还原）
	RunState.set_difficulty(int(meta.get("difficulty", 2)))
	RunState.end_run()   # 清掉残留的 run 状态（不动 run_seed / difficulty）
	# 角色名走 legacy_id：旧录像 meta 里存的是改名前的「德鲁伊 / 游荡者」
	RunState.start_run([], GameLayers.LAYER_DEFAULT,
			PlayerClass.legacy_id(str(meta.get("class", PlayerClass.default_id()))))
	get_tree().change_scene_to_file("res://scenes/map.tscn")


# ------------------------------------------------------------ 绘制

func _result_label(meta: Dictionary) -> String:
	match str(meta.get("result", "")):
		"win":
			return "通关"
		"lose":
			return "失败"
		"quit":
			return "中途放弃"
	return "未结束"


func _result_color(result: String) -> Color:
	match result:
		"win":
			return Color("7fd18a")
		"lose":
			return Color("e07a6a")
	return Color("b8b4aa")


func _draw() -> void:
	# 背景：与地图同款深色渐变
	var top := Color("1c1f28")
	var bottom := Color("303443")
	for i in 36:
		var t := float(i) / 35.0
		draw_rect(Rect2(0, size.y * float(i) / 36.0, size.x, size.y / 36.0 + 1.0),
				top.lerp(bottom, t), true)
	draw_string(_font_bold, Vector2(0, 62), "录 像 回 放",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_HEADING, Color("e8e4da"))
	draw_string(_font, Vector2(0, 92),
			"完整记录并回放一局冒险：地图 / 战斗 / 事件 / 奖励（文件在 user://replays/，保留最近 %d 份）" % ReplayLog.KEEP,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_LABEL, Color("8a867c"))
	var back := _back_rect()
	var hov_back := back.has_point(get_local_mouse_position())
	draw_rect(back, Color("414860") if hov_back else Color("343947"), true)
	draw_rect(back, Color(0, 0, 0, 0.35), false, 2.0)
	draw_string(_font_bold, back.position + Vector2(0, 22), "← 返回标题",
			HORIZONTAL_ALIGNMENT_CENTER, back.size.x, UiTheme.FS_LABEL, Color("e6e2d8"))
	if _err != "":
		draw_string(_font, Vector2(0, LIST_Y + 30), _err,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, Color("e07a6a"))
	if _items.is_empty():
		draw_string(_font, Vector2(0, LIST_Y + 60),
				"还没有录像 —— 先从标题「开始冒险」打一局，之后就能在这里完整回放。",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, Color("8a867c"))
		return
	var max_rows := int((size.y - LIST_Y - 20.0) / ROW_H)
	var count := mini(_items.size(), max_rows)
	for i in count:
		var meta: Dictionary = _items[i]["meta"]
		var r := _row_rect(i)
		var hov := i == _hover
		draw_rect(r, Color("3a4152") if hov else Color("22242c"), true)
		draw_rect(r, Color("6a768c") if hov else Color("4a4e58"), false, 1.6)
		draw_string(_font_bold, r.position + Vector2(16, 26),
				str(meta.get("time", "?")),
				HORIZONTAL_ALIGNMENT_LEFT, 200, UiTheme.FS_BODY, Color("e8e4da"))
		draw_string(_font_bold, r.position + Vector2(230, 26),
				"角色：%s" % PlayerClass.legacy_id(str(meta.get("class", "?"))),
				HORIZONTAL_ALIGNMENT_LEFT, 180, UiTheme.FS_BODY, Color("9fd7a5"))
		var res := str(meta.get("result", ""))
		draw_string(_font_bold, r.position + Vector2(420, 26),
				_result_label(meta), HORIZONTAL_ALIGNMENT_LEFT, 120, UiTheme.FS_BODY,
				_result_color(res))
		draw_string(_font, r.position + Vector2(540, 26),
				"战斗 %d 场 · 种子 %d" % [int(meta.get("battles", 0)),
				int(meta.get("run_seed", 0))],
				HORIZONTAL_ALIGNMENT_LEFT, 240, UiTheme.FS_LABEL, Color("b8b4aa"))
		draw_string(_font, r.position + Vector2(16, 48),
				"点击播放（空格切倍速）· 难度 %d" % int(meta.get("difficulty", 2)),
				HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_CAPTION, Color("7d8590"))
		# 删除按钮
		var dr := _del_rect(i)
		var hd := i == _hover_del
		draw_rect(dr, Color("8a3030") if hd else Color("522c2c"), true)
		draw_rect(dr, Color("c85858") if hd else Color("6a4040"), false, 1.2)
		draw_string(_font_bold, dr.position + Vector2(0, 17), "删",
				HORIZONTAL_ALIGNMENT_CENTER, dr.size.x, UiTheme.FS_LABEL,
				Color("ffd8d8") if hd else Color("c8a8a8"))
	if _items.size() > count:
		draw_string(_font, Vector2(0, size.y - 18),
				"（只显示最近 %d 份）" % count, HORIZONTAL_ALIGNMENT_CENTER,
				size.x, UiTheme.FS_CAPTION, Color("8a867c"))
