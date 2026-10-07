extends Control
## 肉鸽冒险地图（参考杀戮尖塔）—— 起点 + 11 个普通层 + Boss，自下而上推进。
## 节点类型：起点（初始位置，非战斗）/ 普通战斗 / 精英战斗 / 休息 / 事件 /
## 宝箱层（第六层：整层都是宝箱，开箱得 1 个随机奖励道具）/ Boss。
## 玩家从起点（最下列）出发，点击当前节点可达的下一列节点前进；
## 战斗胜利领卡牌奖励回地图，失败返回标题。侧栏显示生命 / 卡组 / 战斗记录。
##
## 节点图标可换：assets/ui/map_<类型>.png（start/battle/elite/rest/event/chest/boss），
## 缺图时回退为内置的彩色圆牌 + 「起/战/英/息/事/箱/王」文字。
## 详见 assets/ui/图片命名说明.txt。
##
## 分层：本张地图属于 RunState.current_layer（当前为第一层），标题栏会显示层名；
## 地图上的战斗关卡与事件都只从该层的内容池里取（见 GameLayers）。

const NODE_R := 17.5                 # 节点半径（留出层间呼吸空间）
const SLOT_CX := 640.0               # 横向槽位中心 = 窗口水平中线（起点/Boss 居中）
const SLOT_DX := 210.0               # 槽位间距（5 个槽位：640±2×210）
const COL_Y0 := 668.0                # 起点层 y（下）
const COL_DY := -96.0                # 层间距（向上推进；起点 + 12 层 + Boss = 14 层，见 RogueMap.COLS）
## 层间距 96px × 12 层 = 1152px，远超 720 的视口高度 —— 所以地图支持
## 上下拖动 + 滚轮滚动（见 _scroll_y / _clamp_scroll），把纵向空间让出来。

const VIEW_H := 720.0                # 视口高度（project.godot 的 viewport_height）
const SCROLL_TOP_MARGIN := 78.0      # 顶部让开标题栏
const SCROLL_BOT_MARGIN := 16.0      # 底部留白
const DRAG_THRESHOLD := 6.0          # 按下后移动超过这个距离才算「拖动」而非点击

const COL_LINE := Color(0.70, 0.81, 1.00, 0.52)   # 未走过的连线（芯·亮蓝白，不用灰）
const COL_LINE_DONE := Color("e6c86a")            # 已走过的连线（金）
const COL_LINE_NEXT := Color("a8d8ff")            # 当前可走的连线（亮青白）
const COL_EDGE_DARK := Color(0.07, 0.08, 0.11, 0.60)   # 连线暗描边

const TYPE_COLORS := {
	"start": Color("7a94b8"),    # 起点 蓝灰
	"battle": Color("c6503c"),   # 普通战斗 红
	"elite": Color("8a30b8"),    # 精英 紫
	"rest": Color("3f9b5f"),     # 休息 绿
	"event": Color("d1a12a"),    # 事件 金
	"chest": Color("e0912a"),    # 宝箱层 橙金（与事件金区分）
	"boss": Color("33323b"),     # Boss 黑
}

var _font: SystemFont
var _font_bold: SystemFont
var sfx: Sfx
var _t := 0.0
var _hover_id := -1
var _records_visible := false
var _records_scroll := 0.0
var _records: Array = []
var _deck_visible := false       # 卡组查看面板
var _deck_scroll := 0.0
var _deck_rows: Array = []       # [{id, count}] 按卡组首次出现顺序聚合
var _hover_deck := -1
var _mouse := Vector2.ZERO      # 鼠标位置（道具徽章悬停提示用）
var _relics_visible := false    # 道具详情面板（R75：徽章装不下时才可点开，字号放大）
var _relic_scroll := 0.0
var _whisper_auto := false      # 道具「鸭之低语」：前进方向由系统随机决定
var _whisper_next: Dictionary = {}   # 系统为本次选定的前进节点
# -- 纵向拖动 / 滚动 --
var _scroll_y := 0.0            # 地图纵向偏移（0 = 起点层贴着视口底部）
var _scroll_min := 0.0          # 偏移下界（不能往下拖过头）
var _scroll_max := 0.0          # 偏移上界（不能往上拖过头）
var _drag_press_pos := Vector2.ZERO   # 按下位置
var _drag_press_scroll := 0.0        # 按下时的 scroll
var _press_active := false           # 左键当前还按着
var _dragging := false               # 本次按下是否已越过阈值（越过后松手不触发点击）
var _scrollbar := Rect2()# 右侧滚动条（绘制 + 命中拖动）
var _boss_name := ""      # 本层 Boss 关卡名（Boss 节点上方名牌；懒加载一次）


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	_font_bold = SystemFont.new()
	_font_bold.font_names = _font.font_names
	sfx = Sfx.new()
	add_child(sfx)
	_records = RunState.load_records()
	if not RunState.run_active or RunState.map_columns.is_empty():
		# 直接打开地图（调试）：临时开一局（第一层），避免空场景
		RunState.start_run(RogueMap.generate(_rng(), GameLayers.LAYER_DEFAULT),
				GameLayers.LAYER_DEFAULT)
	if RunState.current_node_id < 0 and not RunState.map_columns.is_empty():
		RunState.current_node_id = int(RunState.map_columns[0][0]["id"])
	# -- --relics：演示道具栏（截图验证用；须在重定向检查前，模拟已选完道具的状态）
	if "--relics" in OS.get_cmdline_user_args():
		RunState.relics = [6001, 6005, 6010]   # 初始白 / 奖励黄 / 事件紫
		RunState.relic_choice = []
	# -- --deck：直接打开卡组查看面板（截图验证用）
	if "--deck" in OS.get_cmdline_user_args():
		_deck_rows = _build_deck_rows()
		_deck_visible = true
	# 起点三选一：本局还没选初始道具 → 先进道具选择（选完回地图）
	if RunState.run_active and not RunState.relic_choice.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scenes/relic_pick.tscn")
		return
	# 有即时道具等待卡组选择（源数之力 / 失忆药水）→ 先进卡组编辑
	if RunState.run_active and RunState.pending_relic > 0:
		get_tree().change_scene_to_file.call_deferred("res://scenes/deck_edit.tscn")
		return
	# 事件「遗忘之泉」留下的待办：从卡组删一张卡（删完回地图）
	if RunState.run_active and RunState.pending_deck_edit != "":
		get_tree().change_scene_to_file.call_deferred("res://scenes/deck_edit.tscn")
		return
	# 纵向视野初始化：先夹一次范围，再把视野对准玩家当前所在层
	_scroll_to_current()
	var quit_btn := Button.new()
	quit_btn.text = "回到标题"
	quit_btn.position = Vector2(14, 14)
	quit_btn.pressed.connect(func():
		if ReplayLog.recording:
			ReplayLog.finish("quit")
		ReplayLog.stop_playback()
		get_tree().change_scene_to_file("res://scenes/title.tscn"))
	_style_button(quit_btn)
	add_child(quit_btn)
	var rec_btn := Button.new()
	rec_btn.text = "战斗记录"
	rec_btn.position = Vector2(120, 14)
	rec_btn.pressed.connect(_toggle_records)
	_style_button(rec_btn)
	add_child(rec_btn)
	var deck_btn := Button.new()
	deck_btn.text = "查看卡组"
	deck_btn.position = Vector2(226, 14)
	deck_btn.pressed.connect(_toggle_deck)
	_style_button(deck_btn)
	add_child(deck_btn)
	# 道具「鸭之低语」（6010）：玩家失去选择权 → 系统随机挑路并自动前进
	if RunState.run_active and RunState.has_relic(6010) and not ReplayLog.playing:
		_start_whisper()
	# 命令行 -- --screenshot：自动截图退出（视觉验证用）
	if "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	# 回放模式：自动执行下一条「前进」决策（R46）
	if ReplayLog.playing:
		var rt := Timer.new()
		rt.wait_time = 0.5
		rt.timeout.connect(_replay_tick)
		add_child(rt)
		rt.start()


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r


func _style_button(b: Button) -> void:
	## 顶部按钮统一暗色圆角胶囊风格（替代引擎默认的灰白按钮）。
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("343947")
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	sb.border_width_bottom = 2
	sb.border_color = Color(0, 0, 0, 0.35)
	b.add_theme_stylebox_override("normal", sb)
	var hv := sb.duplicate() as StyleBoxFlat
	hv.bg_color = Color("414860")
	b.add_theme_stylebox_override("hover", hv)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = Color("272b37")
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color("e6e2d8"))
	b.add_theme_color_override("font_hover_color", Color("ffffff"))
	b.add_theme_color_override("font_pressed_color", Color("cfcabb"))
	b.add_theme_font_override("font", _font_bold)
	b.add_theme_font_size_override("font_size", 14)


func _start_whisper() -> void:
	## 道具「鸭之低语」：玩家不再能自己选路 —— 随机挑一个可走的节点，
	## 高亮展示片刻后自动走进去（战斗/休息/事件照常结算）。
	_whisper_auto = true
	var opts := RunState.available_nodes()
	if opts.is_empty():
		return
	_whisper_next = opts[RunState.run_rng.randi() % opts.size()]
	queue_redraw()
	var t := Timer.new()
	t.wait_time = 1.6
	t.one_shot = true
	t.timeout.connect(_whisper_advance)
	add_child(t)
	t.start()


func _whisper_advance() -> void:
	## 鸭之低语：定时器到点 → 自动走进系统选定的节点。
	if not RunState.run_active or not RunState.has_relic(6010):
		return
	if _whisper_next.is_empty() or not _is_available(_whisper_next):
		return
	sfx.play("click")
	_enter_node(_whisper_next)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _node_pos(node: Dictionary) -> Vector2:
	## 节点屏幕坐标：层（列）自下而上，横向按随机槽位分布（起点/Boss 居中）。
	## 纵向加上 _scroll_y —— 拖动/滚轮改的就是这个偏移量。
	var col := int(node["col"])
	var slot := int(node.get("slot", 2))
	var x := SLOT_CX + (slot - 2) * SLOT_DX
	var y := COL_Y0 + col * COL_DY + _scroll_y
	return Vector2(x, y)


func _map_content_bounds() -> Vector2:
	## 地图内容在没有滚动时的纵向范围 [顶, 底]（世界坐标，未加 _scroll_y）。
	## 顶部留出标题栏的空间，底部留出节点半径，避免拖到边界时节点被切掉。
	var top := COL_Y0 + (RogueMap.COLS - 1) * COL_DY - NODE_R - 40.0
	var bottom := COL_Y0 + NODE_R + 28.0
	return Vector2(top, bottom)


func _clamp_scroll() -> void:
	## 把 _scroll_y 夹到合法范围：地图内容始终至少有一部分留在视口内。
	## 内容比视口矮时（横屏放大 / 节点少）直接居中，不允许拖动。
	var b := _map_content_bounds()
	var content_h := b.y - b.x
	if content_h <= VIEW_H - SCROLL_TOP_MARGIN - SCROLL_BOT_MARGIN:
		# GDScript 不支持链式赋值，分两句写
		_scroll_min = 0.5 * (VIEW_H - b.x - b.y)
		_scroll_max = _scroll_min
		_scroll_y = _scroll_min
		return
	# scroll 越大 = 看得越靠上（Boss 方向）。上界：内容顶边贴到标题栏下方。
	_scroll_max = SCROLL_TOP_MARGIN - b.x
	# 下界：内容底边贴到视口底部。
	_scroll_min = _scroll_max - (content_h - (VIEW_H - SCROLL_TOP_MARGIN - SCROLL_BOT_MARGIN))
	if _scroll_min > _scroll_max:
		_scroll_min = _scroll_max
	_scroll_y = clampf(_scroll_y, _scroll_min, _scroll_max)


func _scroll_to_current() -> void:
	## 进入地图时把视野对准玩家当前所在层（起点在最下面时就是底部视图）。
	var col := 0
	for node in _all_nodes():
		if int(node["id"]) == RunState.current_node_id:
			col = int(node["col"])
			break
	_clamp_scroll()
	# 让当前层落在视口偏上位置（上方留出将要走的几层）
	var want := COL_Y0 + col * COL_DY + _scroll_y
	var target := SCROLL_TOP_MARGIN + (VIEW_H - SCROLL_TOP_MARGIN) * 0.55
	_scroll_y += target - want
	_clamp_scroll()


func _node_at(pos: Vector2) -> Dictionary:
	for node in _all_nodes():
		if _node_pos(node).distance_to(pos) <= NODE_R + 8.0:
			return node
	return {}


func _is_available(node: Dictionary) -> bool:
	for n in RunState.available_nodes():
		if int(n["id"]) == int(node["id"]):
			return true
	return false


func _all_nodes() -> Array:
	var out: Array = []
	for col_nodes in RunState.map_columns:
		out.append_array(col_nodes)
	return out


func _find_node(id: int) -> Dictionary:
	for node in _all_nodes():
		if int(node["id"]) == id:
			return node
	return {}


# ------------------------------------------------------------ 输入

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
		# 拖动中：纵向跟手移动地图（横向不拖，地图只有纵向自由度）
		if _dragging:
			_scroll_y = _drag_press_scroll + (event.position.y - _drag_press_pos.y)
			_clamp_scroll()
			queue_redraw()
			return
		# 按下后还没动：累计位移，越过阈值才算拖动（否则松手会误进节点）
		if _press_active and not _dragging \
				and event.position.distance_to(_drag_press_pos) > DRAG_THRESHOLD:
			_dragging = true
			_scroll_y = _drag_press_scroll + (event.position.y - _drag_press_pos.y)
			_clamp_scroll()
			queue_redraw()
			return
		# 拖动滚动条
		if _scrollbar.size.y > 0.0 and _scrollbar.has_point(event.position):
			_scroll_by_scrollbar(event.position.y)
			return
		if _deck_visible:
			_hover_deck = _deck_row_at(event.position)
			queue_redraw()
			return
		var nid := int(_node_at(event.position).get("id", -1))
		if nid != _hover_id:
			_hover_id = nid
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _relics_visible:
			_relics_visible = false
			queue_redraw()
			return
		if _records_visible:
			_records_visible = false
			queue_redraw()
			return
		# 道具「+N」摘要块：装不下全部道具时的详情入口（悬浮已能看已列出的那些）
		if _relic_bar_overflowed() and _relic_rect(_relic_shown()).has_point(event.position):
			_relics_visible = true
			_relic_scroll = 0.0
			queue_redraw()
			return
		if _deck_visible:
			# 点在卡牌行上保持打开（暂无操作），点空白处关闭
			if _deck_row_at(event.position) < 0:
				_deck_visible = false
			queue_redraw()
			return
		# 按下：先记下起点，还不动地图（超过阈值才算拖动）
		_drag_press_pos = event.position
		_drag_press_scroll = _scroll_y
		_press_active = true
		_dragging = false
	elif event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_press_active = false
		# 松手：拖过就不算点击（避免「想拖地图却走进了节点」）
		if _dragging:
			_dragging = false
			return
		if ReplayLog.playing:
			return   # 回放模式：前进由驱动执行
		var node := _node_at(event.position)
		if node.is_empty() or not _is_available(node):
			return
		if _whisper_auto:
			return# 鸭之低语：前路由命运决定，玩家点不动
		sfx.play("click")
		_enter_node(node)


func _enter_node(node: Dictionary) -> void:
	## 走进一个节点：按类型分流（战斗 → battle 场景；休息/事件 → event 场景）。
	ReplayLog.ev("map", {"node": int(node["id"])})   # 录像：地图前进
	RunState.advance(int(node["id"]))
	match str(node["type"]):
		"battle", "elite", "boss":
			# 战斗不写在地图上：进入时按本局进度决定难度与具体关卡
			RunState.pending_level = RunState.next_level(node)
			RunState.pending_node = node
			get_tree().change_scene_to_file("res://scenes/battle.tscn")
		"rest":
			RunState.pending_node = node
			get_tree().change_scene_to_file("res://scenes/event.tscn")
		"chest":
			# 宝箱层（第六层整层）：进事件场景的开箱分支 → 获得 1 个随机奖励道具
			RunState.pending_node = node
			RunState.pending_event = "relic_chest"
			get_tree().change_scene_to_file("res://scenes/event.tscn")
		"event":
			RunState.pending_node = node
			# 事件子类型在生成地图时已定：宝箱（卡牌奖励）/ 鸭鸭低语（事件道具）/
			# 挣扎（失去生命换金属龙）/ 鸭之凝视（一袋米抗几楼）/ 鸭梨山大（鸭梨）/
			# 蓝色大肥鱼（鲸鱼之怒）/ 怪物（遭遇战）。已经拥有对应的事件道具时不再
			# 重复出现该事件，退回卡牌宝箱。
			var kind := str(node.get("event_kind", "treasure"))
			if kind == "monster":
				# 事件节点遭遇怪物 → 按普通战斗进入（难度同普通战斗节点）
				RunState.pending_level = RunState.next_level(node)
				get_tree().change_scene_to_file("res://scenes/battle.tscn")
			elif kind == "whisper" and not RunState.has_relic(RunState.WHISPER_RELIC_ID):
				RunState.pending_event = "whisper"
				get_tree().change_scene_to_file("res://scenes/event.tscn")
			elif kind == "gaze" and not RunState.has_relic(RunState.RICE_RELIC_ID):
				RunState.pending_event = "gaze"
				get_tree().change_scene_to_file("res://scenes/event.tscn")
			elif kind == "arcane":
				# 奥秘之泉（第一层专属）：获得「奥秘护符」 / 或者从 3 张随机效果·技能牌里选一张
				RunState.pending_event = "arcane"
				get_tree().change_scene_to_file("res://scenes/event.tscn")
			elif kind == "oblivion":
				# 遗忘之泉（全层通用）：从卡组删一张卡，或直接离开
				RunState.pending_event = "oblivion"
				get_tree().change_scene_to_file("res://scenes/event.tscn")
			elif kind == "pear" and not RunState.has_relic(RunState.PEAR_RELIC_ID):
				RunState.pending_event = "pear"
				get_tree().change_scene_to_file("res://scenes/event.tscn")
			elif kind == "bluefish":
				# 蓝色大肥鱼（第二层专属）：可将一张「鲸鱼之怒」加入卡组
				RunState.pending_event = "bluefish"
				get_tree().change_scene_to_file("res://scenes/event.tscn")
			elif kind == "hero":
				# 绝赞五换一（第二层专属）：卡组不足 5 种不同名的卡时，
				# 仍然进事件界面（界面里只留「退出事件」一个选项）。
				RunState.pending_event = "hero"
				get_tree().change_scene_to_file("res://scenes/event.tscn")
			elif kind == "struggle":
				RunState.pending_event = "struggle"
				get_tree().change_scene_to_file("res://scenes/event.tscn")
			else:
				RunState.pending_event = "treasure"
				RunState.reward_context = "event"
				get_tree().change_scene_to_file("res://scenes/card_reward.tscn")


func _toggle_records() -> void:
	sfx.play("click")
	_records = RunState.load_records()
	_records_visible = not _records_visible
	if _records_visible:
		_deck_visible = false
	queue_redraw()


func _toggle_deck() -> void:
	sfx.play("click")
	if _records_visible:
		_records_visible = false
	_deck_rows = _build_deck_rows()
	_deck_scroll = 0.0
	_deck_visible = not _deck_visible
	queue_redraw()


func _build_deck_rows() -> Array:
	## 卡组聚合：[{id, count}]（按首次出现顺序）。
	var seen := {}
	var out: Array = []
	for id in RunState.deck_ids:
		if seen.has(id):
			out[seen[id]]["count"] += 1
		else:
			seen[id] = out.size()
			out.append({"id": id, "count": 1})
	return out


# ------------------------------------------------------------ 卡组面板

const DECK_ROW_H := 80.0
const DECK_COL_W := 470.0
const DECK_INNER := Rect2(180, 142, 920, 350)   # 与记录面板内区一致


func _deck_row_rect(i: int) -> Rect2:
	## 双列布局：左列 180 起，右列 650 起；行高 80（含间距）。
	var col := i % 2
	var row := int(i / 2.0)
	return Rect2(DECK_INNER.position.x + col * DECK_COL_W,
			DECK_INNER.position.y + row * DECK_ROW_H - _deck_scroll * DECK_ROW_H,
			450.0, 72.0)


func _deck_row_at(pos: Vector2) -> int:
	for i in _deck_rows.size():
		if _deck_row_rect(i).has_point(pos):
			return i
	return -1


func _draw_deck_panel() -> void:
	## 卡组查看面板：双列卡行（小卡面 + 数值 + 效果），滚轮翻页。
	var rect := Rect2(160, 90, size.x - 320, size.y - 150)
	draw_rect(rect, Color("22242c"), true)
	draw_rect(rect, Color("6a665c"), false, 2.0)
	draw_string(_font_bold, rect.position + Vector2(20, 34),
			"我的卡组（共 %d 张 · 滚轮翻页 · 点击空白处关闭）" % RunState.deck_ids.size(),
			HORIZONTAL_ALIGNMENT_LEFT, 520, 17, Color("e8e4da"))
	if _deck_rows.is_empty():
		draw_string(_font, rect.position + Vector2(20, 90), "卡组是空的。",
				HORIZONTAL_ALIGNMENT_LEFT, 300, 14, Color("8a867c"))
		return
	var repo := CardRepo.load_json()
	var max_scroll := maxi(0, ceili(_deck_rows.size() / 2.0) - 4)
	_deck_scroll = clampf(_deck_scroll, 0.0, float(max_scroll))
	for i in _deck_rows.size():
		var r := _deck_row_rect(i)
		if r.end.y < DECK_INNER.position.y or r.position.y > DECK_INNER.end.y:
			continue
		var c := repo.get_card(_deck_rows[i]["id"])
		var hovered := i == _hover_deck
		if hovered:
			draw_rect(r.grow(4.0), Color(1, 1, 1, 0.16), true)
		if c != null:
			CardFace.draw(self, c,
					Rect2(r.position + Vector2(0, 1), Vector2(58, 70)),
					c.health, false, false, _font, _font_bold)
			var kcol := Color("d8c890") if hovered else Color("eee6c8")
			draw_string(_font_bold, r.position + Vector2(68, 24),
					"%s × %d" % [c.card_name, _deck_rows[i]["count"]],
					HORIZONTAL_ALIGNMENT_LEFT, 340, 16, kcol)
			draw_string(_font, r.position + Vector2(68, 45),
					"费用 %d · %s" % [c.cost, CardFace.stats_line(c)],
					HORIZONTAL_ALIGNMENT_LEFT, 372, 11, Color("9a968c"))
			# R106：卡组浏览的一行摘要也走「纯文本降级」（去 Markdown 标记 + 隐藏括号补注）。
			var eff: String = CardText.naturalize(c.effect_text).replace("\n", " ")
			if eff.length() > 30:
				eff = eff.substr(0, 29) + "…"
			draw_string(_font, r.position + Vector2(68, 63), eff,
					HORIZONTAL_ALIGNMENT_LEFT, 372, 11, Color("7d8590"))


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	_draw_background()
	_draw_title()
	_draw_edges()
	_draw_nodes()
	_draw_scrollbar()
	_draw_sidebar()
	_draw_relics()
	if _relics_visible:
		_draw_relic_panel()
	if _deck_visible:
		_draw_deck_panel()
	if _records_visible:
		_draw_records_panel()


func _draw_scrollbar() -> void:
	## 右侧纵向滚动条：地图比视口高时给出「还有内容」的可视提示，
	## 同时可点可拖。滑块位置反映 _scroll_y 在 [_scroll_min, _scroll_max] 里的比例。
	var track_top := SCROLL_TOP_MARGIN
	var track_h := VIEW_H - SCROLL_TOP_MARGIN - SCROLL_BOT_MARGIN
	if track_h <= 0.0:
		_scrollbar = Rect2()
		return
	var b := _map_content_bounds()
	var content_h := b.y - b.x
	var view_h := VIEW_H - SCROLL_TOP_MARGIN - SCROLL_BOT_MARGIN
	# 内容不够高（横屏放大 / 节点少）→ 不需要滚动条
	if content_h <= view_h or _scroll_max <= _scroll_min + 0.5:
		_scrollbar = Rect2()
		return
	var track := Rect2(size.x - 14.0, track_top, 6.0, track_h)
	draw_rect(track, Color(1, 1, 1, 0.06), true)
	var knob_h: float = maxf(28.0, track_h * (view_h / content_h))
	var t: float = clampf((_scroll_y - _scroll_min) / maxf(1.0, _scroll_max - _scroll_min),
			0.0, 1.0)
	# t=0（看得最靠下/起点侧）时滑块在底部
	var knob_y: float = track.position.y + (track_h - knob_h) * (1.0 - t)
	draw_rect(Rect2(track.position.x, knob_y, track.size.x, knob_h),
			Color(0.85, 0.87, 0.93, 0.42), true)
	# 整个轨道都可拖（命中区比视觉宽，好点）
	_scrollbar = Rect2(track.position.x - 5.0, track.position.y,
			track.size.x + 10.0, track_h)


func _draw_background() -> void:
	## 深色纵向渐变 + 极淡点阵 + Boss/起点柔光 —— 告别一块平板底色。
	var top := Color("1c1f28")
	var bottom := Color("303443")
	var bands := 36
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(0, size.y * float(i) / bands, size.x, size.y / bands + 1.0),
				top.lerp(bottom, t), true)
	# 细点阵（只提供质感，不抢戏）
	var dot := Color(1, 1, 1, 0.03)
	var gy := 64.0
	while gy < size.y - 8.0:
		var gx := 44.0
		while gx < size.x - 8.0:
			draw_circle(Vector2(gx, gy), 1.0, dot)
			gx += 48.0
		gy += 48.0
	# Boss 层（顶）暖金光晕 / 起点层（底）冷蓝光晕
	if not RunState.map_columns.is_empty():
		_soft_glow(_node_pos(RunState.map_columns.back()[0]), 88.0,
				Color(0.95, 0.80, 0.45))
		_soft_glow(_node_pos(RunState.map_columns[0][0]), 80.0,
				Color(0.45, 0.65, 0.95))


func _soft_glow(center: Vector2, radius: float, col: Color) -> void:
	## 多层同心圆叠出的柔光（中心最亮，向外衰减）。
	for i in 6:
		var k := float(i) / 5.0
		draw_circle(center, lerpf(radius, radius * 0.3, k),
				Color(col.r, col.g, col.b, 0.042 * (1.0 - k)))


# ------------------------------------------------------------ 道具栏

## 地图顶部道具徽章区（R75：悬浮即看说明；一行放不下时才出现「+N」可点开详情）
const RELIC_BADGE_W := 106.0     # 单个徽章占位宽（含间隔）
const RELIC_BADGE_MAX := 7       # 一行最多几个徽章（再多就压到标题了）
const RELIC_P_W := 900.0         # 详情面板宽
const RELIC_P_NAME := 17         # 详情面板：名称字号（徽章上是 14）
const RELIC_P_TAG := 13
const RELIC_P_DESC := 13         # 详情面板：说明字号（悬浮提示是 12）
const RELIC_P_ROWH := 24.0
const RELIC_P_LINE := 17.0


func _relic_rect(i: int) -> Rect2:
	## 顶部右侧道具徽章矩形（从右往左排）。
	return Rect2(size.x - 24.0 - (i + 1) * RELIC_BADGE_W, 14.0, 98.0, 26.0)


func _relic_bar_overflowed() -> bool:
	## 徽章行装不下全部道具 —— 点开详情面板的**唯一**判定口。
	return RunState.relics.size() > RELIC_BADGE_MAX


func _relic_shown() -> int:
	## 实际画几个徽章：装不下时末位让给「+N」摘要块。
	var n := RunState.relics.size()
	return (RELIC_BADGE_MAX - 1) if _relic_bar_overflowed() else n


func _draw_relics() -> void:
	if not RunState.run_active or RunState.relics.is_empty():
		return
	var repo := RelicRepo.load_json()
	var hovered := -1
	var shown := _relic_shown()
	for i in shown:
		var rel := repo.get_relic(RunState.relics[i])
		if rel == null:
			continue
		var rect := _relic_rect(i)
		var scol := rel.source_color()
		draw_rect(rect, Color(scol, 0.18), true)
		draw_rect(rect, scol, false, 1.4)
		# 来源色块：初始白 / 奖励黄 / 事件紫（白色描边在深底上不够醒目，配实心块）
		var chip := Rect2(rect.position + Vector2(5, 5), Vector2(7, rect.size.y - 10))
		draw_rect(chip, scol, true)
		draw_rect(chip, Color(0, 0, 0, 0.55), false, 1.0)
		draw_string(_font_bold, rect.position + Vector2(14, 18), rel.relic_name,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 18, 14, Color("eee6c8"))
		if rect.has_point(_mouse):
			hovered = i
	# 装不下 → 末位换成「+N 点击看详情」摘要块
	if _relic_bar_overflowed():
		var more := _relic_rect(shown)
		draw_rect(more, Color(0.96, 0.95, 0.88, 0.92), true)
		draw_rect(more, Color("9a8f70"), false, 1.2)
		draw_string(_font_bold, more.position + Vector2(0, 18),
				"+%d" % (RunState.relics.size() - shown),
				HORIZONTAL_ALIGNMENT_CENTER, more.size.x, 15, Color("6a6040"))
		if more.has_point(_mouse):
			hovered = -2      # -2 = 悬停在「+N」摘要上
	if hovered >= 0:
		var rel2 := repo.get_relic(RunState.relics[hovered])
		if rel2 != null:
			_draw_relic_tip(repo, rel2, RunState.relic_state_note(RunState.relics[hovered]))
	elif hovered == -2:
		var miss := RunState.relics.size() - shown
		var w2 := 420.0
		var lines2 := CardFace.wrap_text(_font,
				"还有 %d 件未列出：%s。点击这枚「+N」看完整详情（字号更大）。"
				% [miss, _relic_names_tail(shown)], w2 - 20.0, 13)
		var tx2: float = clampf(_mouse.x - w2 / 2, 8, size.x - w2 - 8)
		var panel2 := Rect2(tx2, 46, w2, 12.0 + lines2.size() * 18.0)
		draw_rect(panel2, Color(0.10, 0.11, 0.15, 0.95), true)
		draw_rect(panel2, Color("c8951c"), false, 1.2)
		for i in lines2.size():
			draw_string(_font, panel2.position + Vector2(10, 22 + i * 18), lines2[i],
					HORIZONTAL_ALIGNMENT_LEFT, w2 - 20, 13, Color("eee6c8"))


func _relic_names_tail(from_i: int) -> String:
	## 未列出部分的道具名（顿号连接，最多 6 个，超出用「等」收尾）。
	var names: Array[String] = []
	for i in range(from_i, RunState.relics.size()):
		var rel := RelicRepo.load_json().get_relic(RunState.relics[i])
		names.append(rel.relic_name if rel != null else str(RunState.relics[i]))
		if names.size() >= 6:
			names.append("等")
			break
	return "、".join(names)


func _draw_relic_tip(repo: RelicRepo, rel: RelicData, note: String) -> void:
	## 单个道具的悬浮说明：浮动折行面板画在徽章行下方。
	# 叠加态的鸭之类的动态状态备注并到说明末尾
	var text := "「%s」（%s · %s）：%s%s" % [rel.relic_name, rel.source_label(),
			rel.kind, rel.desc, ("  " + note) if note != "" else ""]
	var w := 480.0
	var lines := CardFace.wrap_text(_font, text, w - 20.0, 13)
	var tx: float = clampf(_mouse.x - w / 2, 8, size.x - w - 8)
	var panel := Rect2(tx, 46, w, 12.0 + lines.size() * 18.0)
	draw_rect(panel, Color(0.10, 0.11, 0.15, 0.95), true)
	draw_rect(panel, rel.source_color(), false, 1.2)
	for i in lines.size():
		draw_string(_font, panel.position + Vector2(10, 22 + i * 18), lines[i],
				HORIZONTAL_ALIGNMENT_LEFT, w - 20, 13, Color("eee6c8"))


func _relic_panel_rows() -> Array:
	## 详情面板的每行：[名称行, 说明折行, 来源色, 行高]
	var repo := RelicRepo.load_json()
	var rows: Array = []
	for id in RunState.relics:
		var rel := repo.get_relic(int(id))
		if rel == null:
			continue
		var body: String = rel.desc
		var note := RunState.relic_state_note(int(id))
		if note != "":
			body += "  （%s）" % note
		var lines := _wrap_relic_text(body, RELIC_P_W - 90.0, RELIC_P_DESC)
		rows.append(["「%s」（%s · %s）" % [rel.relic_name, rel.source_label(), rel.kind],
				lines, rel.source_color(),
				RELIC_P_ROWH + lines.size() * RELIC_P_LINE + 10.0])
	return rows


func _wrap_relic_text(text: String, max_w: float, px: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var cur := ""
	for i in text.length():
		var ch := text[i]
		if cur != "" and _font.get_string_size(cur + ch,
				HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
			out.append(cur)
			cur = ch
		else:
			cur += ch
	if cur != "":
		out.append(cur)
	return out


func _relic_panel_metrics(rows: Array) -> Dictionary:
	var h := 0.0
	for r in rows:
		h += float(r[3])
	return {"px": (size.x - RELIC_P_W) / 2.0, "py": 96.0, "h": h}


func _draw_relic_panel() -> void:
	## 道具详情面板：徽章行装不下时的兜底入口，**字号比悬浮提示大一档**。
	var rows := _relic_panel_rows()
	if rows.is_empty():
		return
	var M := _relic_panel_metrics(rows)
	var px: float = M["px"]
	var py: float = M["py"]
	var ph: float = minf(float(M["h"]) + 70.0, size.y - py - 60.0)
	var smax := maxf(0.0, float(M["h"]) + 70.0 - ph)
	_relic_scroll = clampf(_relic_scroll, 0.0, smax)
	draw_rect(Rect2(px, py, RELIC_P_W, ph), Color("f5f2ea"))
	draw_rect(Rect2(px, py, RELIC_P_W, ph), Color("555555"), false, 2.0)
	draw_string(_font_bold, Vector2(px + 22, py + 36),
			"我的道具（共 %d 件 · 完整效果 · 滚轮翻页 · 点击任意处关闭）"
			% RunState.relics.size(),
			HORIZONTAL_ALIGNMENT_LEFT, RELIC_P_W - 44, 20, Color("333333"))
	var y := py + 56.0 - _relic_scroll
	for r in rows:
		var row_h: float = float(r[3])
		if y + row_h > py + 46.0 and y < py + ph - 8.0:
			draw_rect(Rect2(px + 18, y - 16, 10, row_h - 8.0), r[2], true)
			draw_string(_font_bold, Vector2(px + 38, y), str(r[0]),
					HORIZONTAL_ALIGNMENT_LEFT, 460, RELIC_P_NAME, Color("2f2a20"))
			var dlines: PackedStringArray = r[1]
			for d_i in dlines.size():
				draw_string(_font, Vector2(px + 38,
						y + RELIC_P_ROWH - 8.0 + d_i * RELIC_P_LINE), dlines[d_i],
						HORIZONTAL_ALIGNMENT_LEFT, RELIC_P_W - 60, RELIC_P_DESC,
						Color("4a4438"))
		y += row_h
	if smax > 0.0:
		draw_string(_font, Vector2(px + RELIC_P_W - 240, py + ph - 14),
				"滚轮翻页（已滚 %.0f / %.0f）" % [_relic_scroll, smax],
				HORIZONTAL_ALIGNMENT_LEFT, 220, 12, Color("888888"))


func _draw_title() -> void:
	draw_string(_font_bold, Vector2(size.x / 2 - 90, 28), "冒 险 地 图",
			HORIZONTAL_ALIGNMENT_CENTER, 180, 24, Color("e8e4da"))
	# 地图所属层级（内容按层隔离：本层的事件与关卡只从本层的内容池里取）
	var hp_txt := "%s    生命 %d/%d    卡组 %d 张" % [
			GameLayers.layer_name(RunState.current_layer),
			RunState.hp, RunState.max_hp, RunState.deck_ids.size()]
	draw_string(_font, Vector2(size.x / 2 - 140, 54), hp_txt,
			HORIZONTAL_ALIGNMENT_CENTER, 280, 13, Color("b8b4aa"))


func _edge_points(a: Vector2, b: Vector2) -> PackedVector2Array:
	## 层间连线：两端竖直切线的 S 形贝塞尔 —— 比直线柔和，交叉处更容易分辨。
	var pts := PackedVector2Array()
	var c1 := a + Vector2(0, COL_DY * 0.45)
	var c2 := b - Vector2(0, COL_DY * 0.45)
	for i in 17:
		pts.append(a.bezier_interpolate(c1, c2, b, float(i) / 16.0))
	return pts


func _draw_edges() -> void:
	## 三层叠画：同色柔光（只给已走/可走）→ 暗描边 → 亮芯线。
	## 已走 = 金、当前可走 = 亮青白、其余 = 暗灰白，一眼分得清。
	for node in _all_nodes():
		var from := _node_pos(node)
		var fid := int(node["id"])
		var done: bool = RunState.cleared_ids.has(fid)
		for nid in node["next"]:
			var tnode := _find_node(int(nid))
			var pts := _edge_points(from, _node_pos(tnode))
			var next_edge: bool = fid == RunState.current_node_id \
					and _is_available(tnode)
			var col := COL_LINE
			var w := 2.2
			if done:
				col = COL_LINE_DONE
				w = 3.0
			elif next_edge:
				col = COL_LINE_NEXT
				w = 2.8
			if done or next_edge:
				draw_polyline(pts, Color(col.r, col.g, col.b, 0.10), w + 7.0, true)
			draw_polyline(pts, COL_EDGE_DARK, w + 2.4, true)
			draw_polyline(pts, col, w, true)


func _draw_nodes() -> void:
	for node in _all_nodes():
		var pos := _node_pos(node)
		var id := int(node["id"])
		var type := str(node["type"])
		var done: bool = RunState.cleared_ids.has(id)
		var current: bool = id == RunState.current_node_id
		var avail := _is_available(node)
		var boss := type == "boss"
		var r := NODE_R + (5.0 if boss else 0.0)
		var base: Color = TYPE_COLORS.get(type, Color("888888"))
		# 立体圆牌：投影 → 深色底盘 → 类型色内芯（走过的整体压暗）
		draw_circle(pos + Vector2(0, 2.5), r, Color(0, 0, 0, 0.35))
		draw_circle(pos, r, base.darkened(0.45))
		draw_circle(pos, r - 2.5, base.darkened(0.5) if done else base)
		# Boss 节点：上方小牌写明本层要打的是谁（与 next_level 的 boss 分支同源）
		if boss:
			_boss_name_chip(pos, r)
		# 当前位置：金色双环 + 下方小牌
		if current:
			draw_arc(pos, r + 4.0, 0, TAU, 40, Color("f2c14e"), 2.5, true)
			draw_arc(pos, r + 7.0, 0, TAU, 40, Color("f2c14e", 0.45), 1.2, true)
			var cw := 78.0
			var crect := Rect2(pos.x - cw / 2, pos.y + r + 6, cw, 17)
			draw_rect(crect, Color(0.09, 0.09, 0.12, 0.85), true)
			draw_rect(crect, Color("f2c14e"), false, 1.2)
			draw_string(_font_bold, crect.position + Vector2(0, 13.5), "当前位置",
					HORIZONTAL_ALIGNMENT_CENTER, cw, 11, Color("f2c14e"))
		elif avail:
			var pulse := 0.5 + 0.5 * sin(_t * 4.0)
			draw_arc(pos, r + 3.5 + pulse * 2.0, 0, TAU, 40,
					Color(0.45, 0.9, 0.5, 0.50 + 0.35 * pulse), 2.4, true)
		# 鸭之低语：命运替玩家选中的那个节点（紫色脉动圈）
		if _whisper_auto and not _whisper_next.is_empty() \
				and id == int(_whisper_next["id"]):
			var p2 := 0.5 + 0.5 * sin(_t * 6.0)
			draw_arc(pos, r + 6.0 + p2 * 3.0, 0, TAU, 40,
					Color(0.72, 0.38, 0.95, 0.6 + 0.4 * p2), 3.0, true)
		if _hover_id == id and avail:
			draw_arc(pos, r + 8.5, 0, TAU, 40, Color(1, 1, 1, 0.8), 2.0, true)
		# 节点图标：assets/ui/map_<类型>.png 存在则用图片，否则画内置文字。
		var icon := UiAssets.node_icon(type)
		if icon != null:
			var ib := r * 1.7
			var box := Rect2(pos - Vector2(ib, ib) * 0.5, Vector2(ib, ib))
			draw_texture_rect(icon, CardFace.fit_rect(icon.get_size(), box), false,
					Color(1, 1, 1, 0.45) if done else Color.WHITE)
		else:
			var label: String = str({"start": "起", "battle": "战", "elite": "英",
					"rest": "息", "event": "事", "chest": "箱", "boss": "王"}.get(type, "?"))
			var gs := 20 if boss else 17
			draw_string(_font_bold, pos + Vector2(-10, 6.5) + Vector2(1, 1), label,
					HORIZONTAL_ALIGNMENT_CENTER, 20, gs, Color(0, 0, 0, 0.45))
			draw_string(_font_bold, pos + Vector2(-10, 6.5), label,
					HORIZONTAL_ALIGNMENT_CENTER, 20, gs,
					Color("f7f4ec") if not done else Color(1, 1, 1, 0.45))
		# 类型名：只在悬停 / 命运指定时显示（平时不再铺一屏文字）
		var show_label := _hover_id == id \
				or (_whisper_auto and not _whisper_next.is_empty() \
						and id == int(_whisper_next["id"]))
		if show_label:
			_type_chip(pos, r, base, str(RogueMap.TYPE_LABELS.get(type, type)))


func _boss_name_chip(pos: Vector2, r: float) -> void:
	## Boss 节点上方的名牌：进本层 Boss 战前就知道要打谁。
	## 关卡名取自 RunState.boss_pick —— 开局用 run_rng 从本层 Boss 池摇定的那一份，
	## 与 RunState.next_level 的 boss 分支读的是**同一个字段**（R63：同层可能有多个 Boss），
	## 所以地图上写的就是真会遇到的那只。
	if _boss_name == "":
		var lv: Dictionary = RunState.boss_pick
		if lv.is_empty():
			lv = GameLevels.boss_level(RunState.current_layer)
		_boss_name = str(lv.get("name", ""))
	if _boss_name == "":
		return
	var text := "Boss：" + _boss_name
	var w := maxf(text.length() * 13.0 + 18.0, 62.0)
	var h := 22.0
	var rect := Rect2(pos.x - w / 2.0, pos.y - r - 8.0 - h, w, h)
	draw_rect(rect, Color(0.10, 0.09, 0.13, 0.90), true)
	draw_rect(rect, Color("f2c14e"), false, 1.3)
	draw_string(_font_bold, rect.position + Vector2(0, 15.0), text,
			HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color("f7e6b0"))


func _type_chip(pos: Vector2, r: float, base: Color, text: String) -> void:
	## 悬停时节点旁的小标签牌（节点靠右时标签挪到左侧，避免出屏）。
	var w := maxf(text.length() * 14.0 + 16.0, 44.0)
	var lx: float = pos.x - r - 8.0 - w if pos.x > size.x - 150.0 \
			else pos.x + r + 8.0
	var rect := Rect2(lx, pos.y - 11.0, w, 22.0)
	draw_rect(rect, Color(0.08, 0.09, 0.12, 0.88), true)
	draw_rect(rect, Color(base, 0.85), false, 1.2)
	draw_string(_font, rect.position + Vector2(8, 15), text,
			HORIZONTAL_ALIGNMENT_LEFT, w - 14, 13, Color("eee9dc"))


func _draw_sidebar() -> void:
	# 左下：图例（双列小面板，收拢不占地方）
	var items := [["起点", "start"], ["战斗", "battle"], ["精英", "elite"],
			["休息", "rest"], ["事件", "event"], ["宝箱层", "chest"], ["Boss", "boss"]]
	var pad := 10.0
	var cell_w := 92.0
	var cell_h := 26.0
	var rows := int(ceil(float(items.size()) / 2.0))
	var pw := pad * 2.0 + cell_w * 2.0
	var ph := pad * 2.0 + cell_h * rows
	var prect := Rect2(14, size.y - ph - 14, pw, ph)
	draw_rect(prect, Color(0.09, 0.10, 0.14, 0.55), true)
	draw_rect(prect, Color(1, 1, 1, 0.08), false, 1.0)
	for i in items.size():
		var cx: float = prect.position.x + pad + (i % 2) * cell_w
		var cy: float = prect.position.y + pad + float(i / 2) * cell_h
		var itype := str(items[i][1])
		var iicon := UiAssets.node_icon(itype)
		if iicon != null:
			var box := Rect2(cx, cy + 2.0, 14.0, 14.0)
			draw_texture_rect(iicon, CardFace.fit_rect(iicon.get_size(), box), false)
		else:
			draw_circle(Vector2(cx + 7, cy + 9), 7, TYPE_COLORS[itype])
		draw_string(_font, Vector2(cx + 20, cy + 13.5), str(items[i][0]),
				HORIZONTAL_ALIGNMENT_LEFT, 66, 13, Color("c8c4ba"))
	# 右下：提示
	if _whisper_auto:
		draw_string(_font_bold, Vector2(size.x - 430, size.y - 20),
				"【鸭之低语】前路已被命运选定，你无法自主选择……",
				HORIZONTAL_ALIGNMENT_RIGHT, 410, 13, Color("c9a0f0"))
	else:
		draw_string(_font, Vector2(size.x - 430, size.y - 20),
				"点击发绿光的节点前进 · 拖动 / 滚轮上下浏览 · 打败 Boss 通关",
				HORIZONTAL_ALIGNMENT_RIGHT, 410, 13, Color("8a867c"))


func _draw_records_panel() -> void:
	## 战斗记录面板：所有持久化记录（新在前），含卡组内容 / 胜负 / 最终血量。
	var rect := Rect2(160, 90, size.x - 320, size.y - 150)
	draw_rect(rect, Color("22242c"), true)
	draw_rect(rect, Color("6a665c"), false, 2.0)
	draw_string(_font_bold, rect.position + Vector2(20, 34),
			"战斗记录（共 %d 场，滚动：滚轮）" % _records.size(),
			HORIZONTAL_ALIGNMENT_LEFT, 400, 17, Color("e8e4da"))
	var inner := Rect2(rect.position + Vector2(20, 52),
			rect.size - Vector2(40, 70))
	var line_h := 40.0
	var max_lines := int(inner.size.y / line_h)
	_records_scroll = clampf(_records_scroll, 0.0,
			maxf(0.0, _records.size() - max_lines))
	for i in max_lines:
		var idx := _records.size() - 1 - int(_records_scroll) - i
		if idx < 0:
			break
		var r: Dictionary = _records[idx]
		var y := inner.position.y + i * line_h
		var res_txt := "胜" if bool(r["win"]) else "败"
		var res_col := Color("7fd18a") if bool(r["win"]) else Color("e07a6a")
		draw_string(_font_bold, Vector2(inner.position.x, y + 14),
				str(r["time"]), HORIZONTAL_ALIGNMENT_LEFT, 150, 13, Color("9a968c"))
		draw_string(_font_bold, Vector2(inner.position.x + 155, y + 14),
				"%s（%s）" % [r["level"], GameLevels.tier_name(int(r["tier"]))],
				HORIZONTAL_ALIGNMENT_LEFT, 240, 13, Color("e8e4da"))
		draw_string(_font_bold, Vector2(inner.position.x + 400, y + 14),
				res_txt, HORIZONTAL_ALIGNMENT_LEFT, 40, 14, res_col)
		draw_string(_font, Vector2(inner.position.x + 445, y + 14),
				"最终血量 %d/%d" % [int(r["final_hp"]), int(r["max_hp"])],
				HORIZONTAL_ALIGNMENT_LEFT, 130, 13, Color("c8c4ba"))
		# 卡组摘要（一行）
		var parts: Array[String] = []
		for d in r["deck"]:
			parts.append("%s×%d" % [d["name"], d["count"]])
		draw_string(_font, Vector2(inner.position.x, y + 32),
				"卡组：" + "、".join(parts), HORIZONTAL_ALIGNMENT_LEFT,
				inner.size.x, 12, Color("8a867c"))
	if _records.is_empty():
		draw_string(_font, inner.position + Vector2(0, 30),
				"还没有战斗记录——去打第一场吧！", HORIZONTAL_ALIGNMENT_LEFT,
				400, 14, Color("8a867c"))


func _scroll_by_scrollbar(pos_y: float) -> void:
	## 拖右侧滚动条：把点击位置映射到 scroll 区间。
	var track_top := SCROLL_TOP_MARGIN
	var track_h := VIEW_H - SCROLL_TOP_MARGIN - SCROLL_BOT_MARGIN
	if track_h <= 0.0:
		return
	var t := clampf((pos_y - track_top) / track_h, 0.0, 1.0)
	# 滚动条上端对应「看得最靠上」= _scroll_max
	_scroll_y = lerpf(_scroll_max, _scroll_min, t)
	_clamp_scroll()
	queue_redraw()


func set_scroll_ratio(t: float) -> void:
	## 按 0~1 的比例定位视野（0 = 起点侧底部，1 = Boss 侧顶部）。
	_clamp_scroll()
	_scroll_y = lerpf(_scroll_min, _scroll_max, clampf(t, 0.0, 1.0))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _records_visible and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_records_scroll += 1.0
		queue_redraw()
	elif _records_visible and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_records_scroll = maxf(0.0, _records_scroll - 1.0)
		queue_redraw()
	elif _relics_visible and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_relic_scroll += 34.0
		queue_redraw()
	elif _relics_visible and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_relic_scroll = maxf(0.0, _relic_scroll - 34.0)
		queue_redraw()
	elif _deck_visible and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_deck_scroll += 1.0
		queue_redraw()
	elif _deck_visible and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_deck_scroll = maxf(0.0, _deck_scroll - 1.0)
		queue_redraw()
	elif not _records_visible and not _deck_visible and event is InputEventMouseButton \
			and event.pressed:
		# 地图纵向滚动：滚轮向上=往 Boss 方向看，滚轮向下=往起点方向看
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_y += 64.0
			_clamp_scroll()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_y -= 64.0
			_clamp_scroll()
			get_viewport().set_input_as_handled()


func _replay_tick() -> void:
	## 回放模式：按录像前进（地图条目由本场景消费）。
	if not ReplayLog.playing:
		return
	var e := ReplayLog.peek()
	if e.is_empty() or str(e.get("k", "")) != "map":
		return
	ReplayLog.advance()
	var node := _find_node(int(e.get("node", -1)))
	if node.is_empty():
		ReplayLog.stop_playback()
		return
	sfx.play("click")
	_enter_node(node)
