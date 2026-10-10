extends Control
## 肉鸽冒险地图（R128 重写）—— **7 列 × 5 行的相接正方形格子**。
##
## 与旧版的根本区别：旧版是「14 个分层列 + 圆节点 + 连线 + 上下滚动」，新版是一张
## 固定 5×7 的网格 —— 每格一个房间，房间之间用「门」相连，玩家在网格上自由走动。
##
## 规则（与 RogueMap 的生成约束一一对应）：
##   * 起点固定在最下一行中间 (3,4)；**左上 (0,0) 与右上 (6,0) 固定为大宝箱**；
##   * 每一格都写明房间类型；**「?」房要走进才揭晓**（揭晓后永久显示真实类型）；
##   * **只有走过的房间，玩家才看得到它通向哪些房间**（门）—— 这是本版的核心视野规则；
##     奖励道具「鹰哨」（6026）可以让全图的门立刻全部可见；
##   * 每层 12 块巧克力：进入**没走过**的房间扣 1 块（悬浮会提示 -1），
##     原路返回走过的房间不扣、并且什么都不发生；
##   * 巧克力扣到 0 → 当前房间结算完 → 「入夜了，强大的敌人来袭」→ Boss 战。
##
## 界面：每层一张背景图（缺图回退渐变）+ **半透明格子**（尽量不把背景图挡死）。
## 地图整体（826 × 590）能完整放进视口 —— 所以旧版的滚动 / 滚动提示 / 滚动条已全部移除。

const UiTheme = preload("res://scripts/ui_theme.gd")
const MapBridge = preload("res://scripts/map_bridge.gd")

const CELL := 118.0                  # 格子边长（正方形，相邻格共享边）
const MAP_W := 826.0                 # 7 × 118
const MAP_H := 590.0                 # 5 × 118
const MAP_X0 := 227.0                # (1280 - 826) / 2，水平居中
const MAP_Y0 := 94.0                 # 标题行 + 信息行之下

const VIEW_H := 720.0
const DRAG_THRESHOLD := 6.0          # 弃用（保留：点击判定仍用它区分按下/拖动）

# ---- 视觉常量（只服务本文件；跨文件的房间类型色在 UiTheme.MAP_NODE_COLORS）----
const COL_CELL_FILL := Color(0.06, 0.08, 0.12, 0.40)        # 未走过的格子底（半透明，露出背景图）
const COL_CELL_FILL_DONE := Color(0.14, 0.17, 0.22, 0.46)   # 走过的格子底（稍实一点）
const COL_CELL_LINE := Color(1, 1, 1, 0.14)                 # 格子分隔线
const COL_CELL_LINE_DONE := Color(0.94, 0.88, 0.72, 0.30)   # 走过的格子边（暖白）
                                                            # ⚠️ R130 起**不再是金**：
                                                            # 旧版金色格边与金色通路撞色 →
                                                            # 连接根本看不出来
# 通路（小桥）的画法与染色统一在 scripts/map_bridge.gd + UiTheme.MAP_BRIDGE_*。
const COL_PANEL := Color(0.08, 0.09, 0.13, 0.74)            # HUD 小面板底
const COL_PANEL_LINE := Color(1, 1, 1, 0.12)
const COL_CHOCO_FALLBACK := Color("6b3f24")                 # 巧克力缺图时的兜底「整块」底
const COL_CHOCO_SEG := Color("8c5a2e")                      # 兜底：小方格填充
const COL_CHOCO_SEG_HI := Color(0.86, 0.65, 0.40, 0.45)     # 兜底：小方格上沿高光
const COL_CHOCO_EDGE := Color(0.20, 0.12, 0.07, 0.90)       # 兜底：外描边

# ---- 进场过场（R131）----
## 走进**没去过的**房间时先播一段过场：那一格的图标一边放大一边飞到屏幕中心，
## 亮出房间类型文字，同时在右侧巧克力计数旁亮出「巧克力 -1」。播完才真的进入房间。
## ⚠️ **换图标不用改这里的任何一行**：房间图标走 `UiAssets.node_icon()`、
##    巧克力走 `UiAssets.chocolate()`，都按 `CardFace.fit_rect` **等比**缩放
##    （不预设素材长宽比、不拉伸），缺图各自有程序化回退。
const ANIM_DUR := 1.45            # 过场总时长（秒）
const ANIM_ICON_S := 168.0        # 图标放大到的边长
const ANIM_TEXT_DY := 122.0       # 类型文字在图标中心下方多少 px
const ANIM_COST_W := 82.0         # 过场里「巧克力 -1」小牌的宽度
## 房间类型 → 过场文字（**唯一出处**）。其余界面要同一套文案就读这里。
## 「unknown」= 玩家点它时还是「?」，所以是「不确定的命运」。
const ENTER_LABELS := {
	"battle": "战斗",
	"elite": "精英战斗",
	"event": "随机事件",
	"rest": "片刻休息",
	"unknown": "不确定的命运",
	"chest": "宝箱",
	"bigchest": "大宝箱",
	"start": "起点",
}

# ---- 巧克力计数（R131：素材改成「长方形整块」→ 图标槽改成横向的）----
const CHOCO_PANEL_W := 118.0
const CHOCO_PANEL_H := 30.0
const CHOCO_PANEL_Y := 56.0
const CHOCO_ICON_W := 52.0
const CHOCO_ICON_H := 24.0
const CHOCO_ROWS := 2             # 缺图兜底的小方格行数（与新素材的「2 行」呼应）
const CHOCO_COLS := 4

var _font: SystemFont
var _font_bold: SystemFont
var sfx: Sfx
var _t := 0.0
var _hover_id := -1
var _mouse := Vector2.ZERO
var _records_visible := false
var _records_scroll := 0.0
var _records: Array = []
var _deck_visible := false
var _deck_scroll := 0.0
var _deck_rows: Array = []
var _hover_deck := -1
var _relics_visible := false
var _relic_scroll := 0.0
var _whisper_auto := false
var _whisper_next: Dictionary = {}
var _reward_panel: RewardPanel = null
var _drag_press_pos := Vector2.ZERO
var _press_active := false
var _dragging := false
var _boss_name := ""            # 本层 Boss 关卡名（名牌显示；懒加载一次）
var _boss_alert := false        # 「入夜了…」提示是否正在显示（防止重复触发）
var _move_note := ""            # 上一次移动的短提示（如「你已走过这里」）
var _move_note_t := 0.0
var _anim_cell: Dictionary = {}  # 正在播进场过场的房间（空 = 没在播）
var _anim_t := 0.0               # 过场已播时长（秒）
var _anim_hold := false          # 演示用：停在过场末尾不真的进入（截图核验）


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	_records = RunState.load_records()
	# 兜底：直接打开地图场景（调试）时临时开一局，避免空场景
	if not RunState.run_active or RunState.map_cells.is_empty():
		RunState.start_run(RogueMap.generate(_rng(), GameLayers.LAYER_DEFAULT),
				GameLayers.LAYER_DEFAULT)
	# -- --relics：演示道具栏（截图验证用）
	if "--relics" in OS.get_cmdline_user_args():
		RunState.relics = [6001, 6005, 6010]
		RunState.relic_choice = []
	# -- --whistle：演示鹰哨（全图的门都可见）
	if "--whistle" in OS.get_cmdline_user_args():
		RunState.relics = [6001, 6005, 6026]
		RunState.relic_choice = []
	# -- --midway：演示「走过一片区域」的状态（截图核验视野规则用）
	if "--midway" in OS.get_cmdline_user_args():
		_prep_midway_demo()
	# -- --deck：直接打开卡组查看面板
	if "--deck" in OS.get_cmdline_user_args():
		_deck_rows = _build_deck_rows()
		_deck_visible = true
	# 起点三选一 / 待办卡组操作：先走它们，别停在地图上。
	# ⚠️ **截图核验模式要跳过**：否则刚开的一局带着「起点道具三选一」，
	# 会立刻把场景切走 → 截图截到的是别的界面（甚至什么都截不到）。
	if "--screenshot" not in OS.get_cmdline_user_args():
		if RunState.run_active and not RunState.relic_choice.is_empty():
			get_tree().change_scene_to_file.call_deferred("res://scenes/relic_pick.tscn")
			return
		if RunState.run_active and RunState.pending_relic > 0:
			get_tree().change_scene_to_file.call_deferred("res://scenes/deck_edit.tscn")
			return
		if RunState.run_active and RunState.pending_deck_edit != "":
			get_tree().change_scene_to_file.call_deferred("res://scenes/deck_edit.tscn")
			return
	var quit_btn := Button.new()
	quit_btn.text = "回到标题"
	quit_btn.position = Vector2(14, 14)
	quit_btn.pressed.connect(func():
		if ReplayLog.recording:
			ReplayLog.finish("quit")
		ReplayLog.stop_playback()
		get_tree().change_scene_to_file("res://scenes/title.tscn"))
	UiTheme.apply_chip(quit_btn, true)
	add_child(quit_btn)
	var rec_btn := Button.new()
	rec_btn.text = "战斗记录"
	rec_btn.position = Vector2(120, 14)
	rec_btn.pressed.connect(_toggle_records)
	UiTheme.apply_chip(rec_btn, true)
	add_child(rec_btn)
	var deck_btn := Button.new()
	deck_btn.text = "查看卡组"
	deck_btn.position = Vector2(226, 14)
	deck_btn.pressed.connect(_toggle_deck)
	UiTheme.apply_chip(deck_btn, true)
	add_child(deck_btn)
	_reward_panel = RewardPanel.attach(self, Vector2(12, 40))
	# 道具「鸭之低语」（6010）：玩家失去选择权 → 系统随机挑路并自动前进
	if RunState.run_active and RunState.has_relic(6010) and not ReplayLog.playing:
		_start_whisper()
	# -- --bossalert：演示「入夜了」提示（只显示不切场景，截图核验用）
	if "--bossalert" in OS.get_cmdline_user_args():
		_boss_alert = true
	# -- --enteranim：演示进场过场（截图核验用；停在过场末尾不真的进入）
	if "--enteranim" in OS.get_cmdline_user_args():
		_anim_hold = true
		for c: Dictionary in RunState.available_nodes():
			if not _visited(c) and str(c["type"]) != "start":
				_anim_cell = c
				_anim_t = 0.0
				break
	# 命令行 -- --screenshot：自动截图退出
	#（`-- --enteranim --shotwait 1.0` 可以指定延迟，用来截过场的不同时刻）
	if "--screenshot" in OS.get_cmdline_user_args():
		var wait := 0.6
		var args := OS.get_cmdline_user_args()
		var si := args.find("--shotwait")
		if si >= 0 and si + 1 < args.size():
			wait = maxf(0.05, float(args[si + 1]))
		var t := Timer.new()
		t.wait_time = wait
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	# 回放模式：自动执行下一条「前进」决策
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


func _prep_midway_demo() -> void:
	## 演示：把玩家挪到中路，并标记一条走过的路线 —— 用于核验
	## 「只有走过的房间才画通路（小桥）」「走过的格子边变暖白」这两条视野规则。
	var cells := RunState.map_cells
	if cells.size() != RogueMap.CELLS:
		return
	RunState.cleared_ids = []
	# 沿起点一路向上走 3 格（找有路的邻居）
	var cur := int(RogueMap.start_cell(cells)["id"])
	RunState.cleared_ids.append(cur)
	for step in 3:
		var nxt := -1
		for nid in RogueMap.neighbor_ids(cells[cur]):
			var c: Dictionary = cells[int(nid)]
			if int(c["row"]) < int(cells[cur]["row"]) and not RunState.cleared_ids.has(int(nid)):
				nxt = int(nid)
				break
		if nxt < 0:
			break
		RunState.cleared_ids.append(nxt)
		cur = nxt
	RunState.current_node_id = cur
	RunState.chocolate = RogueMap.MAX_STEPS - (RunState.cleared_ids.size() - 1)


## 顶部按钮样式统一走 `UiTheme.apply_chip(b, true)`（地图页底色是暗的 → 实心档）。


# ------------------------------------------------------------ 坐标

func _cell_rect(cell: Dictionary) -> Rect2:
	var col := int(cell["col"])
	var row := int(cell["row"])
	return Rect2(MAP_X0 + col * CELL, MAP_Y0 + row * CELL, CELL, CELL)


func _cell_center(cell: Dictionary) -> Vector2:
	var r := _cell_rect(cell)
	return r.position + r.size * 0.5


func _cell_at(pos: Vector2) -> Dictionary:
	var col := int((pos.x - MAP_X0) / CELL)
	var row := int((pos.y - MAP_Y0) / CELL)
	if not RogueMap.in_bounds(col, row):
		return {}
	return RunState.map_cells[RogueMap.idx(col, row)]


func _is_available(cell: Dictionary) -> bool:
	## 从当前房间能否走到它（必须真的有门 —— 与 RunState.can_move_to 同源）。
	return RunState.can_move_to(int(cell["id"]))


func _visited(cell: Dictionary) -> bool:
	return RunState.cleared_ids.has(int(cell["id"]))


func _is_current(cell: Dictionary) -> bool:
	return int(cell["id"]) == RunState.current_node_id


# ------------------------------------------------------------ 输入

func _gui_input(event: InputEvent) -> void:
	# 进场过场播放中：屏蔽一切输入（这 1.5 秒地图不接受操作，免得点穿）
	if not _anim_cell.is_empty():
		return
	if event is InputEventMouseMotion:
		_mouse = event.position
		if _deck_visible:
			_hover_deck = _deck_row_at(event.position)
			queue_redraw()
			return
		var c := _cell_at(event.position)
		var nid := int(c.get("id", -1))
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
		if _relic_bar_overflowed() and _relic_rect(_relic_shown()).has_point(event.position):
			_relics_visible = true
			_relic_scroll = 0.0
			queue_redraw()
			return
		if _deck_visible:
			if _deck_row_at(event.position) < 0:
				_deck_visible = false
			queue_redraw()
			return
		_drag_press_pos = event.position
		_press_active = true
		_dragging = false
	elif event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_press_active = false
		if _dragging:
			_dragging = false
			return
		if ReplayLog.playing:
			return   # 回放模式：前进由驱动执行
		var cell := _cell_at(event.position)
		if cell.is_empty() or not _is_available(cell):
			return
		if _whisper_auto:
			return   # 鸭之低语：前路由命运决定，玩家点不动
		sfx.play("click")
		_enter_node(cell)


func _enter_node(cell: Dictionary, animate := true) -> void:
	## 走进一个房间。
	## * **没去过的**房间 → 先播一段进场过场（`animate = false` 可跳过，回放用）；
	## * 回到**走过的**房间 → 不播过场，直接走原逻辑（什么都不会发生）。
	if cell.is_empty() or not _anim_cell.is_empty():
		return
	if animate and not _visited(cell) and RunState.can_move_to(int(cell["id"])):
		_anim_cell = cell
		_anim_t = 0.0
		queue_redraw()
		return
	_commit_enter(cell)


func _commit_enter(cell: Dictionary) -> void:
	## 真正的「进入」：结算 + 按房间类型分流。**只能由过场结束（或回放）调用。**
	var id := int(cell["id"])
	var res := RunState.advance(id)
	if not bool(res.get("ok", false)):
		return
	ReplayLog.ev("map", {"node": id})
	if not bool(res.get("is_new", false)):
		# 原路返回：不扣巧克力、不结算 —— 给一句轻提示，免得玩家以为点击失效。
		_set_note("这里是走过的房间，什么都不会发生（不消耗巧克力）")
		return
	RunState.pending_node = cell
	var dtype := RogueMap.display_type(cell)
	match dtype:
		"battle", "elite":
			RunState.pending_level = RunState.next_level(cell)
			get_tree().change_scene_to_file("res://scenes/battle.tscn")
		"rest", "event":
			# 事件房不再遭遇战斗：本层事件池已去掉「遭遇怪物」（见 GameLayers）。
			get_tree().change_scene_to_file("res://scenes/event.tscn")
		"chest":
			# 普通宝箱：一次卡牌奖励（就地弹奖励悬浮窗，不切界面）
			RunState.queue_card_reward("normal")
			_open_reward_panel()
		"bigchest":
			# 大宝箱：**1 个道具 + 一次卡牌奖励**
			RunState.queue_relic_reward(RunState.roll_reward_relic())
			RunState.queue_card_reward("normal")
			_open_reward_panel()


func _open_reward_panel() -> void:
	queue_redraw()
	if _reward_panel != null:
		_reward_panel.open()


func _set_note(text: String) -> void:
	_move_note = text
	_move_note_t = 2.4
	queue_redraw()


# ------------------------------------------------------------ Boss 触发

func _process(delta: float) -> void:
	_t += delta
	if _move_note_t > 0.0:
		_move_note_t = maxf(0.0, _move_note_t - delta)
	# 进场过场：走完才**真的进房间**（过场期间 RunState 一动不动）
	if not _anim_cell.is_empty():
		_anim_t += delta
		if _anim_t >= ANIM_DUR and not _anim_hold:
			var entered := _anim_cell
			_anim_cell = {}
			_commit_enter(entered)
	queue_redraw()
	# 巧克力耗尽 → 等当前房间的内容结算完（奖励弹窗关掉 / 战斗与事件回来）再开 Boss 战。
	# ⚠️ 回放模式同样要触发（boss_pending 由 advance 确定性地置位），只是不等那 2 秒。
	if RunState.run_active and RunState.boss_pending and not _boss_alert \
			and (_reward_panel == null or not _reward_panel.is_open()):
		_trigger_boss_alert()


func _trigger_boss_alert() -> void:
	_boss_alert = true
	sfx.play("click")
	queue_redraw()
	var t := Timer.new()
	t.wait_time = 0.1 if ReplayLog.playing else 2.2
	t.one_shot = true
	t.timeout.connect(_start_boss_battle)
	add_child(t)
	t.start()


func _start_boss_battle() -> void:
	RunState.boss_pending = false
	RunState.pending_level = RunState.boss_level()
	RunState.pending_node = {"type": "boss"}
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _boss_label() -> String:
	if _boss_name == "":
		_boss_name = str(RunState.boss_level().get("name", ""))
	return _boss_name


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	_draw_background()
	# ⚠️ 顺序不可换：格子底 → **通路（小桥）** → 图标。
	#    桥夹在中间，两端才会被房间图标盖住（可见部分正好是「两间房之间那一段」）。
	_draw_cell_tiles()
	_draw_bridges()
	_draw_cell_icons()
	_draw_states()
	_draw_hud()
	_draw_sidebar()
	_draw_relics()
	if _relics_visible:
		_draw_relic_panel()
	if _deck_visible:
		_draw_deck_panel()
	if _records_visible:
		_draw_records_panel()
	_draw_move_note()
	if _boss_alert:
		_draw_boss_alert()
	if not _anim_cell.is_empty():
		_draw_enter_anim()          # 过场永远在最上层


func _draw_background() -> void:
	## 本层背景图铺满整屏（保持比例裁切）；缺图时回退成纵向渐变 —— 不空白也不报错。
	var tex := UiAssets.map_bg(RunState.current_layer)
	if tex != null:
		draw_texture_rect(tex, Rect2(0, 0, size.x, size.y), false)
		# 压一层很淡的暗罩：保证格子上的文字在任何背景上都读得清。
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.02, 0.03, 0.05, 0.42), true)
		return
	var top := Color("1c1f28")
	var bottom := Color("303443")
	var bands := 36
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(0, size.y * float(i) / bands, size.x, size.y / bands + 1.0),
				top.lerp(bottom, t), true)


func _draw_cell_tiles() -> void:
	## 半透明格子底 + 类型染色 + 分隔线。**格子底刻意做得很淡**，让背景图透出来。
	## ⚠️ 与图标分两趟画：中间要夹一层「通路（小桥）」—— 桥必须压在格子底之上、
	##    房间图标之下。
	for cell: Dictionary in RunState.map_cells:
		var r := _cell_rect(cell)
		var done := _visited(cell)
		var dtype := RogueMap.display_type(cell)
		var base: Color = UiTheme.MAP_NODE_COLORS.get(dtype, UiTheme.INK_500)
		# 底：未走过的更淡（还没探索），走过的稍实
		draw_rect(r, COL_CELL_FILL_DONE if done else COL_CELL_FILL, true)
		# 类型色只做**极淡的染色**，不铺满（否则背景图被挡死）
		draw_rect(r, Color(base.r, base.g, base.b, 0.14 if done else 0.09), true)
		# 分隔线（走过的偏暖白，一眼看出探索范围）
		draw_rect(r, COL_CELL_LINE_DONE if done else COL_CELL_LINE, false, 1.4)


func _draw_cell_icons() -> void:
	## 房间内容：**只用图标**（R129 起地图上不再写文字 —— 房间类型全靠图标区分）。
	## 图标缺图时才回退成格子中央的汉字（规范要求「缺图不空白也不报错」）。
	for cell: Dictionary in RunState.map_cells:
		var r := _cell_rect(cell)
		var done := _visited(cell)
		var dtype := RogueMap.display_type(cell)
		var cx := r.position.x + r.size.x * 0.5
		var cy := r.position.y + r.size.y * 0.5
		var icon := UiAssets.node_icon(dtype)
		if icon != null:
			# 图标占格子约 62%：四周留出格子边框与「通路」的位置，不互相压。
			var ib := CELL * 0.62
			var box := Rect2(cx - ib * 0.5, cy - ib * 0.5, ib, ib)
			draw_texture_rect(icon, CardFace.fit_rect(icon.get_size(), box), false,
					Color(1, 1, 1, 0.55) if done else Color.WHITE)
		else:
			var mark := RogueMap.type_mark(dtype)
			var gs := 40
			draw_string(_font_bold, Vector2(cx - 30.0 + 1.5, cy + 15.0 + 1.5), mark,
					HORIZONTAL_ALIGNMENT_CENTER, 60, gs, Color(0, 0, 0, 0.55))
			draw_string(_font_bold, Vector2(cx - 30.0, cy + 15.0), mark,
					HORIZONTAL_ALIGNMENT_CENTER, 60, gs,
					Color(0.96, 0.93, 0.86) if not done else Color(0.82, 0.78, 0.66))


func _bridge_kind(cell: Dictionary, nb: Dictionary) -> int:
	## 通路语义（本函数是判定口，绘制只是消费）—— 与战斗内地图总览同一口径。
	##   LIT    一端是当前房、另一端是它**真能走过去**的房 → 亮青（会呼吸）
	##   DONE   两端至少一端走过 → 暖白（已知的通道）
	##   UNSEEN 两端都没走过（只在鹰哨下出现）→ 灰蓝、更小
	var lit := (_is_current(cell) and _is_available(nb)) \
			or (_is_current(nb) and _is_available(cell))
	return MapBridge.kind_for(_visited(cell), _visited(nb), lit)


func _draw_bridges() -> void:
	## 通路（R130）：**两格之间的墙上盖一枚小桥图标** —— 左右连通用侧视图、
	## 上下连通用俯视图（见 `scripts/map_bridge.gd`）。
	## 画在格子底之上、图标之下（`_draw()` 里夹在 `_draw_cell_tiles` 与
	## `_draw_cell_icons` 之间）→ 桥的两端被图标盖住，可见部分正好是「两间房之间
	## 那一段」。
	## ⚠️ 旧版是在墙中点画一小段与「走过的格子边」**同色**的金线 → 不站在那格上、
	##    没有金色高亮时根本看不出连接；鹰哨全揭示时更糊（灰 0.50 半透明压在暗格子上）。
	## **视野规则**：只有**走过的**房间才把它通向哪几间画出来；
	## 道具「鹰哨」（6026）在场时 → 全图的通路立刻可见。
	var reveal_all := RunState.has_relic(RunState.EAGLE_WHISTLE_RELIC_ID)
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	var drawn := {}          # 去重：两格之间只盖一座桥（两个方向是同一处）
	for cell: Dictionary in RunState.map_cells:
		if not _visited(cell) and not reveal_all:
			continue
		var ctr := _cell_center(cell)
		for nid in cell["doors"]:
			var nb: Dictionary = RunState.map_cells[int(nid)]
			var key := mini(int(cell["id"]), int(nid)) * RogueMap.CELLS \
					+ maxi(int(cell["id"]), int(nid))
			if drawn.has(key):
				continue
			drawn[key] = true
			var kind := _bridge_kind(cell, nb)
			MapBridge.draw_bridge(self, ctr, _cell_center(nb), kind, CELL,
					pulse if kind == MapBridge.LIT else 0.0)


func _draw_states() -> void:
	## 当前房间（金框 + 光晕）/ 可走房间（绿脉动框）/ 悬停（白框）。
	for cell: Dictionary in RunState.map_cells:
		var r := _cell_rect(cell)
		var id := int(cell["id"])
		if _is_current(cell):
			draw_rect(r.grow(3.0), UiTheme.ACCENT_LIT, false, 3.0)
			draw_rect(r.grow(8.0), Color(0.95, 0.76, 0.31, 0.28), false, 5.0)
		elif _is_available(cell):
			var pulse := 0.5 + 0.5 * sin(_t * 4.0)
			draw_rect(r.grow(2.0),
					Color(0.45, 0.90, 0.50, 0.42 + 0.42 * pulse), false, 2.6)
		if _hover_id == id and _is_available(cell):
			draw_rect(r.grow(5.0), Color(1, 1, 1, 0.75), false, 2.0)
		# 鸭之低语：命运替玩家选中的那间（紫色脉动圈）
		if _whisper_auto and not _whisper_next.is_empty() and id == int(_whisper_next["id"]):
			var p2 := 0.5 + 0.5 * sin(_t * 6.0)
			draw_rect(r.grow(4.0 + p2 * 3.0),
					Color(0.72, 0.38, 0.95, 0.55 + 0.40 * p2), false, 3.0)


func _draw_hud() -> void:
	# 标题行
	draw_string(_font_bold, Vector2(size.x / 2 - 90, 30), "冒 险 地 图",
			HORIZONTAL_ALIGNMENT_CENTER, 180, UiTheme.FS_HEADING, UiTheme.SAND)
	var hp_txt := "%s    生命 %d/%d    卡组 %d 张" % [
			GameLayers.layer_name(RunState.current_layer),
			RunState.hp, RunState.max_hp, RunState.deck_ids.size()]
	draw_string(_font, Vector2(size.x / 2 - 140, 52), hp_txt,
			HORIZONTAL_ALIGNMENT_CENTER, 280, UiTheme.FS_LABEL, UiTheme.INK_300)
	# 信息行：左边 Boss 名牌（玩家要能提前知道打谁），右边巧克力计数
	_draw_boss_chip()
	_draw_chocolate()


func _draw_boss_chip() -> void:
	var text := "本层 Boss：%s" % _boss_label()
	var w := 320.0
	var h := 26.0
	var rect := Rect2(14, 60, w, h)
	draw_rect(rect, COL_PANEL, true)
	draw_rect(rect, UiTheme.ACCENT_LIT, false, 1.3)
	draw_string(_font_bold, rect.position + Vector2(10, 18), _ellipsis(text, w - 20.0,
			UiTheme.FS_LABEL), HORIZONTAL_ALIGNMENT_LEFT, w - 20, UiTheme.FS_LABEL,
			Color("f7e6b0"))


func _choco_panel_rect() -> Rect2:
	## 巧克力计数面板（HUD 右上角）。过场里的「-1」小牌贴它的左边。
	return Rect2(size.x - 24.0 - CHOCO_PANEL_W, CHOCO_PANEL_Y,
			CHOCO_PANEL_W, CHOCO_PANEL_H)


func _draw_choco_icon(box: Rect2, alpha: float = 1.0) -> void:
	## 巧克力图标的**唯一画法** —— 计数区 / 悬浮提示 / 过场「-1」小牌三处共用。
	## ⚠️ 用 `fit_rect` **等比**缩放：以后换成任何长宽比的巧克力都不会被压扁
	##    （R131 就是从正方形换成长方形整块的，这里一行都没改）。
	var icon := UiAssets.chocolate()
	if icon != null:
		draw_texture_rect(icon, CardFace.fit_rect(icon.get_size(), box), false,
				Color(1, 1, 1, alpha))
		return
	# 缺图回退：**照新素材的形态画**（长方块 + 小方格刻痕），不是一块圆角砖
	draw_rect(box, Color(COL_CHOCO_FALLBACK.r, COL_CHOCO_FALLBACK.g,
			COL_CHOCO_FALLBACK.b, alpha), true)
	var gap := maxf(1.0, box.size.x * 0.03)
	var cw := (box.size.x - gap * (CHOCO_COLS + 1)) / CHOCO_COLS
	var ch := (box.size.y - gap * (CHOCO_ROWS + 1)) / CHOCO_ROWS
	for r in CHOCO_ROWS:
		for c in CHOCO_COLS:
			var seg := Rect2(box.position.x + gap + c * (cw + gap),
					box.position.y + gap + r * (ch + gap), cw, ch)
			draw_rect(seg, Color(COL_CHOCO_SEG.r, COL_CHOCO_SEG.g,
					COL_CHOCO_SEG.b, alpha), true)
			draw_rect(seg, Color(COL_CHOCO_SEG_HI.r, COL_CHOCO_SEG_HI.g,
					COL_CHOCO_SEG_HI.b, COL_CHOCO_SEG_HI.a * alpha), true)
	draw_rect(box, Color(COL_CHOCO_EDGE.r, COL_CHOCO_EDGE.g,
			COL_CHOCO_EDGE.b, COL_CHOCO_EDGE.a * alpha), false, 1.2)


func _draw_chocolate() -> void:
	## 每层行动力：图标 + ×N（素材在左，数量在右 —— 用户口径）。
	var n := RunState.chocolate
	var rect := _choco_panel_rect()
	draw_rect(rect, COL_PANEL, true)
	draw_rect(rect, COL_PANEL_LINE, false, 1.2)
	_draw_choco_icon(Rect2(rect.position.x + 5.0, rect.position.y + 3.0,
			CHOCO_ICON_W, CHOCO_ICON_H))
	var col := Color("f4e3c8") if n > 0 else Color("e07a6a")
	draw_string(_font_bold, Vector2(rect.position.x + 5.0 + CHOCO_ICON_W + 6.0,
			rect.position.y + 21.0), "×%d" % n,
			HORIZONTAL_ALIGNMENT_LEFT, 46, UiTheme.FS_BODY, col)
	# 悬停在「没走过」的相邻房间上 → 提示这次移动要花 1 块
	if _hover_id >= 0 and _hover_id < RunState.map_cells.size():
		var hc: Dictionary = RunState.map_cells[_hover_id]
		if _is_available(hc) and not _visited(hc) and hc["type"] != "start":
			_draw_cost_tip()


func _draw_cost_tip() -> void:
	## 悬浮提示：巧克力图标 -1（图标槽与计数区/过场共用同一个画法）
	var w := 104.0
	var h := 30.0
	var px: float = clampf(_mouse.x + 14.0, 8.0, size.x - w - 8.0)
	var py: float = clampf(_mouse.y - h - 8.0, 8.0, size.y - h - 8.0)
	var rect := Rect2(px, py, w, h)
	draw_rect(rect, Color(0.08, 0.09, 0.13, 0.94), true)
	draw_rect(rect, UiTheme.ACCENT_GOLD, false, 1.3)
	_draw_choco_icon(Rect2(px + 5.0, py + 5.0, 34.0, 20.0))
	draw_string(_font_bold, Vector2(px + 43, py + 20), "-1",
			HORIZONTAL_ALIGNMENT_LEFT, 60, UiTheme.FS_BODY, Color("f2c14e"))


# ------------------------------------------------------------ 进场过场

func _enter_label(cell: Dictionary) -> String:
	## 过场文字。读 `display_type`：「?」房此刻**还没**揭晓 → 落到「不确定的命运」。
	var dt := RogueMap.display_type(cell)
	return str(ENTER_LABELS.get(dt, RogueMap.type_label(dt)))


func _ramp(p: float, a: float, b: float) -> float:
	## 过场的每一层各占一段时间：把总进度 p 映射到 [a,b] 段内的 0→1。
	if b <= a:
		return 1.0 if p >= b else 0.0
	return clampf((p - a) / (b - a), 0.0, 1.0)


func _draw_enter_anim() -> void:
	## 进场过场：压暗全屏 → 那一格的图标一边放大一边飞到屏幕中心 → 亮出类型文字 →
	## 同时右侧巧克力计数旁亮出「巧克力图标 -1」。
	## ⚠️ 各段时机都写成 ANIM_DUR 的比例（下面只出现数字），改总时长不用动别处。
	var p := clampf(_anim_t / ANIM_DUR, 0.0, 1.0)
	var dim := _ramp(p, 0.0, 0.18)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.66 * dim), true)
	# 图标：先快后慢地飞到屏幕中心（略微上移，给文字留位置），同时放大
	var fly := 1.0 - pow(1.0 - _ramp(p, 0.0, 0.62), 3.0)
	var to := Vector2(size.x * 0.5, size.y * 0.44)
	var ctr := _cell_center(_anim_cell).lerp(to, fly)
	var s := lerpf(CELL * 0.62, ANIM_ICON_S, fly)
	# 图标后面垫一块暗光晕：任何背景上图标与文字都读得清
	# ⚠️ 半径别太大 —— 出图验证过，超过 0.62×图标就会读成「一块黑贴纸」。
	draw_circle(ctr, s * 0.58, Color(0.03, 0.04, 0.07, 0.48 * dim))
	_draw_anim_icon(_anim_cell, Rect2(ctr.x - s * 0.5, ctr.y - s * 0.5, s, s), dim)
	# 房间类型文字（淡入 + 轻微上浮）
	var ta := _ramp(p, 0.42, 0.64)
	if ta > 0.0:
		var label := _enter_label(_anim_cell)
		var w := 460.0
		var tx := size.x * 0.5 - w * 0.5
		var ty := ctr.y + ANIM_TEXT_DY + (1.0 - ta) * 10.0
		draw_string(_font_bold, Vector2(tx + 2.0, ty + 2.0), label,
				HORIZONTAL_ALIGNMENT_CENTER, w, UiTheme.FS_TITLE,
				Color(0, 0, 0, 0.62 * ta))
		draw_string(_font_bold, Vector2(tx, ty), label,
				HORIZONTAL_ALIGNMENT_CENTER, w, UiTheme.FS_TITLE,
				Color(UiTheme.SAND.r, UiTheme.SAND.g, UiTheme.SAND.b, ta))
	# 巧克力 -1：在右侧计数旁（图标槽与计数区同源）
	_draw_anim_cost(_ramp(p, 0.34, 0.52), fly)


func _draw_anim_icon(cell: Dictionary, box: Rect2, alpha: float) -> void:
	## 过场里放大的房间图标。**槽位与地图格子完全同源**（`node_icon`）→ 换素材两边一起变。
	var dtype := RogueMap.display_type(cell)
	var icon := UiAssets.node_icon(dtype)
	if icon != null:
		draw_texture_rect(icon, CardFace.fit_rect(icon.get_size(), box), false,
				Color(1, 1, 1, alpha))
		return
	# 缺图回退：与格子里的兜底同一套（汉字），只是字号放大
	draw_string(_font_bold, Vector2(box.position.x, box.position.y + box.size.y * 0.8),
			RogueMap.type_mark(dtype), HORIZONTAL_ALIGNMENT_CENTER, box.size.x,
			UiTheme.FS_DISPLAY, Color(0.96, 0.93, 0.86, alpha))


func _draw_anim_cost(alpha: float, pop: float) -> void:
	## 过场里在**巧克力计数旁**（左侧）亮出「巧克力图标 -1」。
	if alpha <= 0.0:
		return
	var panel := _choco_panel_rect()
	var k := lerpf(0.86, 1.0, pop)          # 跟着图标一起「落定」的小弹跳
	var w := ANIM_COST_W * k
	var h := CHOCO_PANEL_H * k
	var rect := Rect2(panel.position.x - 10.0 - w,
			panel.position.y + (CHOCO_PANEL_H - h) * 0.5, w, h)
	draw_rect(rect, Color(0.10, 0.08, 0.05, 0.92 * alpha), true)
	draw_rect(rect, Color(0.95, 0.76, 0.31, 0.92 * alpha), false, 1.4)
	var ib := Rect2(rect.position.x + 5.0, rect.position.y + 3.0, 36.0, rect.size.y - 6.0)
	_draw_choco_icon(ib, alpha)
	draw_string(_font_bold, Vector2(ib.end.x + 3.0, rect.position.y + rect.size.y * 0.7),
			"-1", HORIZONTAL_ALIGNMENT_LEFT, 40, UiTheme.FS_BODY,
			Color(0.95, 0.76, 0.31, alpha))


func _draw_sidebar() -> void:
	## 底部一行：图例（横排）+ 右下提示。
	var items := [["起点", "start"], ["战斗", "battle"], ["精英", "elite"], ["休息", "rest"],
			["事件", "event"], ["宝箱", "chest"], ["大宝箱", "bigchest"], ["未知", "unknown"]]
	var x := 14.0
	var y := size.y - 30.0
	for it: Array in items:
		var ty := str(it[1])
		var icon := UiAssets.node_icon(ty)
		if icon != null:
			draw_texture_rect(icon, CardFace.fit_rect(icon.get_size(),
					Rect2(x, y + 1, 16, 16)), false)
		else:
			draw_rect(Rect2(x + 1, y + 2, 14, 14),
					UiTheme.MAP_NODE_COLORS.get(ty, UiTheme.INK_500), true)
			draw_rect(Rect2(x + 1, y + 2, 14, 14), Color(0, 0, 0, 0.5), false, 1.0)
		draw_string(_font, Vector2(x + 20, y + 14), str(it[0]),
				HORIZONTAL_ALIGNMENT_LEFT, 64, UiTheme.FS_CAPTION, UiTheme.INK_300)
		x += 84.0
	# 右下提示
	var hint := "点击发绿光的房间前进 · 走过的房间可以随时免费返回 · 巧克力用完就要打 Boss"
	if _whisper_auto:
		hint = "【鸭之低语】前路已被命运选定，你无法自主选择……"
	if RunState.has_relic(RunState.EAGLE_WHISTLE_RELIC_ID):
		hint += "　｜　鹰哨：全图的门已全部可见"
	draw_string(_font, Vector2(size.x - 600.0, size.y - 30.0 + 14.0),
			_ellipsis(hint, 586.0, UiTheme.FS_CAPTION),
			HORIZONTAL_ALIGNMENT_RIGHT, 586.0, UiTheme.FS_CAPTION, UiTheme.INK_ON_DARK)


func _draw_move_note() -> void:
	if _move_note_t <= 0.0 or _move_note == "":
		return
	var w := 460.0
	var rect := Rect2(size.x / 2 - w / 2, MAP_Y0 + MAP_H + 2.0, w, 24.0)
	draw_rect(rect, Color(0.08, 0.09, 0.13, 0.88), true)
	draw_rect(rect, Color(1, 1, 1, 0.16), false, 1.1)
	draw_string(_font, rect.position + Vector2(10, 17), _move_note,
			HORIZONTAL_ALIGNMENT_CENTER, w - 20, UiTheme.FS_CAPTION, UiTheme.INK_300)


func _draw_boss_alert() -> void:
	## 巧克力耗尽：整屏暗罩 + 大字提示（2 秒后自动进 Boss 战）。
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.02, 0.01, 0.03, 0.72), true)
	draw_string(_font_bold, Vector2(0, size.y / 2 - 26), "入 夜 了",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_TITLE, Color("e8c27a"))
	draw_string(_font_bold, Vector2(0, size.y / 2 + 18), "强大的敌人来袭",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_HEADING, Color("f2d79a"))
	draw_string(_font_bold, Vector2(0, size.y / 2 + 54), "—— %s ——" % _boss_label(),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_LABEL, UiTheme.INK_300)


func _ellipsis(text: String, max_w: float, px: int) -> String:
	## 自绘文字的溢出策略（规范规则 6）：先量宽，超了就截断补 …
	if _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= max_w:
		return text
	var out := text
	while out.length() > 1 and _font.get_string_size(out + "…",
			HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
		out = out.substr(0, out.length() - 1)
	return out + "…"


# ------------------------------------------------------------ 道具栏

const RELIC_BADGE_W := 106.0
const RELIC_BADGE_MAX := 7
const RELIC_P_W := 900.0
const RELIC_P_NAME := 17
const RELIC_P_TAG := 13
const RELIC_P_DESC := 13
const RELIC_P_ROWH := 24.0
const RELIC_P_LINE := 17.0


func _relic_rect(i: int) -> Rect2:
	return Rect2(size.x - 24.0 - (i + 1) * RELIC_BADGE_W, 14.0, 98.0, 26.0)


func _relic_bar_overflowed() -> bool:
	return RunState.relics.size() > RELIC_BADGE_MAX


func _relic_shown() -> int:
	var n := RunState.relics.size()
	return (RELIC_BADGE_MAX - 1) if _relic_bar_overflowed() else n


func _draw_relics() -> void:
	if not RunState.run_active or RunState.relics.is_empty():
		return
	var hover_ok := not (_deck_visible or _records_visible or _relics_visible) \
			and not UiGate.blocked() \
			and (_reward_panel == null or not _reward_panel.is_open())
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
		var chip := Rect2(rect.position + Vector2(5, 5), Vector2(7, rect.size.y - 10))
		draw_rect(chip, scol, true)
		draw_rect(chip, Color(0, 0, 0, 0.55), false, 1.0)
		draw_string(_font_bold, rect.position + Vector2(14, 18), rel.relic_name,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 18, UiTheme.FS_LABEL, Color("eee6c8"))
		if hover_ok and rect.has_point(_mouse):
			hovered = i
	if _relic_bar_overflowed():
		var more := _relic_rect(shown)
		draw_rect(more, Color(0.96, 0.95, 0.88, 0.92), true)
		draw_rect(more, Color("9a8f70"), false, 1.2)
		draw_string(_font_bold, more.position + Vector2(0, 18),
				"+%d" % (RunState.relics.size() - shown),
				HORIZONTAL_ALIGNMENT_CENTER, more.size.x, UiTheme.FS_BODY, Color("6a6040"))
		if hover_ok and more.has_point(_mouse):
			hovered = -2
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
		draw_rect(panel2, UiTheme.ACCENT_GOLD, false, 1.2)
		for i in lines2.size():
			draw_string(_font, panel2.position + Vector2(10, 22 + i * 18), lines2[i],
					HORIZONTAL_ALIGNMENT_LEFT, w2 - 20, UiTheme.FS_LABEL, Color("eee6c8"))


func _relic_names_tail(from_i: int) -> String:
	var names: Array[String] = []
	for i in range(from_i, RunState.relics.size()):
		var rel := RelicRepo.load_json().get_relic(RunState.relics[i])
		names.append(rel.relic_name if rel != null else str(RunState.relics[i]))
		if names.size() >= 6:
			names.append("等")
			break
	return "、".join(names)


func _draw_relic_tip(repo: RelicRepo, rel: RelicData, note: String) -> void:
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
				HORIZONTAL_ALIGNMENT_LEFT, w - 20, UiTheme.FS_LABEL, Color("eee6c8"))


func _relic_panel_rows() -> Array:
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
	var rows := _relic_panel_rows()
	if rows.is_empty():
		return
	var M := _relic_panel_metrics(rows)
	var px: float = M["px"]
	var py: float = M["py"]
	var ph: float = minf(float(M["h"]) + 70.0, size.y - py - 60.0)
	var smax := maxf(0.0, float(M["h"]) + 70.0 - ph)
	_relic_scroll = clampf(_relic_scroll, 0.0, smax)
	draw_rect(Rect2(px, py, RELIC_P_W, ph), UiTheme.PAPER)
	draw_rect(Rect2(px, py, RELIC_P_W, ph), UiTheme.INK_600, false, 2.0)
	draw_string(_font_bold, Vector2(px + 22, py + 36),
			"我的道具（共 %d 件 · 完整效果 · 滚轮翻页 · 点击任意处关闭）"
			% RunState.relics.size(),
			HORIZONTAL_ALIGNMENT_LEFT, RELIC_P_W - 44, UiTheme.FS_SUBHEAD, UiTheme.INK_800)
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
				HORIZONTAL_ALIGNMENT_LEFT, 220, UiTheme.FS_CAPTION, UiTheme.INK_500)


# ------------------------------------------------------------ 面板

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
	## 卡组聚合：[{id, card, count}]（按首次出现顺序）。
	## ⚠️ R112 起卡组里不再有「运行时改写费用」的卡，同名卡费用必然相同 → 按 id 聚合即可。
	var repo := CardRepo.load_json()
	var seen := {}
	var out: Array = []
	for i in RunState.deck_ids.size():
		var id: int = RunState.deck_ids[i]
		if seen.has(id):
			out[seen[id]]["count"] += 1
			continue
		var c := repo.get_card(id)
		if c == null:
			continue
		seen[id] = out.size()
		out.append({"id": id, "card": c, "count": 1})
	return out


const DECK_ROW_H := 89.0
const DECK_COL_W := 470.0
const DECK_INNER := Rect2(180, 142, 920, 350)


func _deck_row_rect(i: int) -> Rect2:
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
	var rect := Rect2(160, 90, size.x - 320, size.y - 150)
	draw_rect(rect, Color("22242c"), true)
	draw_rect(rect, Color("6a665c"), false, 2.0)
	draw_string(_font_bold, rect.position + Vector2(20, 34),
			"我的卡组（共 %d 张 · 滚轮翻页 · 点击空白处关闭）" % RunState.deck_ids.size(),
			HORIZONTAL_ALIGNMENT_LEFT, 520, UiTheme.FS_BODY, UiTheme.SAND)
	if _deck_rows.is_empty():
		draw_string(_font, rect.position + Vector2(20, 90), "卡组是空的。",
				HORIZONTAL_ALIGNMENT_LEFT, 300, UiTheme.FS_LABEL, UiTheme.INK_ON_DARK)
		return
	var max_scroll := maxi(0, ceili(_deck_rows.size() / 2.0) - 4)
	_deck_scroll = clampf(_deck_scroll, 0.0, float(max_scroll))
	for i in _deck_rows.size():
		var r := _deck_row_rect(i)
		if r.end.y < DECK_INNER.position.y or r.position.y > DECK_INNER.end.y:
			continue
		var c: CardData = _deck_rows[i]["card"]
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
					HORIZONTAL_ALIGNMENT_LEFT, 340, UiTheme.FS_BODY, kcol)
			draw_string(_font, r.position + Vector2(68, 45),
					"费用 %d · %s" % [c.cost, CardFace.stats_line(c)],
					HORIZONTAL_ALIGNMENT_LEFT, 372, UiTheme.FS_CAPTION, Color("9a968c"))
			var eff: String = CardText.naturalize(c.effect_text).replace("\n", " ")
			if eff.length() > 30:
				eff = eff.substr(0, 29) + "…"
			draw_string(_font, r.position + Vector2(68, 63), eff,
					HORIZONTAL_ALIGNMENT_LEFT, 372, UiTheme.FS_CAPTION, Color("7d8590"))


func _draw_records_panel() -> void:
	var rect := Rect2(160, 90, size.x - 320, size.y - 150)
	draw_rect(rect, Color("22242c"), true)
	draw_rect(rect, Color("6a665c"), false, 2.0)
	draw_string(_font_bold, rect.position + Vector2(20, 34),
			"战斗记录（共 %d 场，滚动：滚轮）" % _records.size(),
			HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_BODY, UiTheme.SAND)
	var inner := Rect2(rect.position + Vector2(20, 52), rect.size - Vector2(40, 70))
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
				str(r["time"]), HORIZONTAL_ALIGNMENT_LEFT, 150, UiTheme.FS_LABEL, Color("9a968c"))
		draw_string(_font_bold, Vector2(inner.position.x + 155, y + 14),
				"%s（%s）" % [r["level"], GameLevels.tier_name(int(r["tier"]))],
				HORIZONTAL_ALIGNMENT_LEFT, 240, UiTheme.FS_LABEL, UiTheme.SAND)
		draw_string(_font_bold, Vector2(inner.position.x + 400, y + 14),
				res_txt, HORIZONTAL_ALIGNMENT_LEFT, 40, UiTheme.FS_LABEL, res_col)
		draw_string(_font, Vector2(inner.position.x + 445, y + 14),
				"最终血量 %d/%d" % [int(r["final_hp"]), int(r["max_hp"])],
				HORIZONTAL_ALIGNMENT_LEFT, 130, UiTheme.FS_LABEL, UiTheme.INK_300)
		var parts: Array[String] = []
		for d in r["deck"]:
			parts.append("%s×%d" % [d["name"], d["count"]])
		draw_string(_font, Vector2(inner.position.x, y + 32),
				"卡组：" + "、".join(parts), HORIZONTAL_ALIGNMENT_LEFT,
				inner.size.x, UiTheme.FS_CAPTION, UiTheme.INK_ON_DARK)
	if _records.is_empty():
		draw_string(_font, inner.position + Vector2(0, 30),
				"还没有战斗记录——去打第一场吧！", HORIZONTAL_ALIGNMENT_LEFT,
				400, UiTheme.FS_LABEL, UiTheme.INK_ON_DARK)


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


# ------------------------------------------------------------ 鸭之低语 / 回放

func _start_whisper() -> void:
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
	if not RunState.run_active or not RunState.has_relic(6010):
		return
	if _whisper_next.is_empty() or not _is_available(_whisper_next):
		return
	sfx.play("click")
	_enter_node(_whisper_next)


func _replay_tick() -> void:
	## 回放模式：按录像前进（地图条目由本场景消费）。
	if not ReplayLog.playing:
		return
	var e := ReplayLog.peek()
	if e.is_empty() or str(e.get("k", "")) != "map":
		return
	ReplayLog.advance()
	var cell := RunState.cell_of(int(e.get("node", -1)))
	if cell.is_empty():
		ReplayLog.stop_playback()
		return
	sfx.play("click")
	# 回放要一口气跑完一整局 → 跳过过场（过场只是给玩家看的）
	_enter_node(cell, false)
