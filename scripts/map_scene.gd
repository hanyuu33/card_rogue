extends Control
## 肉鸽冒险地图（R128 重写）—— **7 列 × 5 行的相接正方形格子**。
##
## 与旧版的根本区别：旧版是「14 个分层列 + 圆节点 + 连线 + 上下滚动」，新版是一张
## 固定 5×7 的网格 —— 每格一个房间，房间之间用「门」相连，玩家在网格上自由走动。
##
## 规则（与 RogueMap 的生成约束一一对应）：
##   * 起点固定在最下一行中间 (3,4)；**左上 (0,0) 与右上 (6,0) 固定为大宝箱**；
##   * 每一格都写明房间类型；**「?」房要走进才揭晓**（揭晓后永久显示真实类型）；
##   * **R145 视野规则（本版核心，两条要分开看）**：
##     ① **通路（小桥）全图可见** —— 路线看得见，玩家才规划得了「怎么走到大宝箱」；
##     ② **格子里是什么默认被迷雾遮住**，只有以下四处看得见：走过的房间 /
##        当前房间 / 当前房间**有门的邻居**（=「下一步」能选的几间）/ 两处大宝箱地标。
##        判定口只有一个：`RunState.known_node()`（战斗内的地图总览也读它）。
##     奖励道具「鹰哨」（6026）可以让全图的迷雾立刻散尽；
##   * 每层 12 块巧克力：进入**没走过**的房间扣 1 块（悬浮会提示 -1），
##     原路返回走过的房间不扣、并且什么都不发生；
##   * 巧克力扣到 0 → 当前房间结算完 → 「入夜了，强大的敌人来袭」→ Boss 战。
##
## 界面：每层一张背景图（缺图回退渐变）+ **半透明格子**（尽量不把背景图挡死）。
## 地图整体（826 × 590）能完整放进视口 —— 所以旧版的滚动 / 滚动提示 / 滚动条已全部移除。

const UiTheme = preload("res://scripts/ui_theme.gd")
const MapBridge = preload("res://scripts/map_bridge.gd")
const UiRoll = preload("res://scripts/ui_roll.gd")

const CELL := 118.0                  # 格子边长（正方形，相邻格共享边）
const MAP_W := 826.0                 # 7 × 118
const MAP_H := 590.0                 # 5 × 118
const MAP_X0 := 227.0                # (1280 - 826) / 2，水平居中
const MAP_Y0 := 94.0                 # 标题行 + 信息行之下

const VIEW_H := 720.0
const DRAG_THRESHOLD := 6.0          # 弃用（保留：点击判定仍用它区分按下/拖动）

# ---- R177：地图标记（画图 / 旗子 / 橡皮；当局内任何入口进地图都看得到）----
const MARK_PEN := 0                  # 画图模式：拖动画任意线条（职业色）
const MARK_FLAG := 1                 # 标记模式：点放小旗子（职业色）
const MARK_ERASE := 2                # 擦除模式：拖动的橡皮擦
const MARK_LINE_W := 3.5             # 笔画宽度（另垫 2px 暗描边）
const MARK_ERASE_R := 12.0           # 橡皮命中半径
const MARK_MIN_STEP := 3.0           # 笔画取点最小间距（去掉手抖冗余点）
## R179：入夜前的缓冲（秒）—— 巧克力耗尽后，等**当前格结算完**再播「入夜」：
##   * 进场过场刚结束 → 留这点时间让玩家看清「当前格落定」（过场期间绝不触发入夜）；
##   * 从战斗 / 事件 / 奖励窗回到地图 → 也给同样长度的缓冲，别一回来就糊黑屏。
const BOSS_HOLD_AFTER_ENTER := 0.55
## R194：鸭之低语的行走节奏（秒）。进地图先等一拍，让玩家看清「命运选了哪一间」；
## 之后每步只隔一小段 —— 路过走过的旧房间时，看起来就是被一路拽着往前走。
const WHISPER_FIRST_DELAY := 1.6
const WHISPER_STEP_DELAY := 0.55
var _mark_mode := -1                 # 当前标记模式（-1 = 关，行为与旧版一致）
var _mark_drawing := false           # 左键按下中（画线中 / 擦拭中 / 预备放旗）
var _mark_cur: PackedVector2Array = PackedVector2Array()   # 正在画的笔画（松手才入栈）
var _mark_flag_press := Vector2(-1, -1)                    # 旗子按下位置（拖动则不触发放旗）
var _boss_hold := 0.0              # R179：入夜触发倒计时（> 0 时即使 boss_pending 也不播）

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

# ---- 迷雾（R145）----
## 「还看不清里面是什么」的格子：**只盖内容，不盖通路**。小桥画在两格之间的墙上、
## 本来就不在格子里 —— 所以「路线可见 / 内容不可见」这两件事互不打扰，
## 不需要任何裁剪或遮挡技巧。
const COL_CELL_FOG_FILL := Color(0.13, 0.16, 0.22, 0.60)    # 迷雾格的格子底
                                                            # ⚠️ **中性色，不按类型染色** ——
                                                            # 类型色一染就等于把内容漏了
const COL_FOG_BASE := Color(0.15, 0.18, 0.25, 0.85)         # 云雾底色（青灰，别太黑）
const COL_FOG_HI := Color(0.42, 0.49, 0.62, 0.13)           # 云团高光（低透明度 → 融成一片）
const COL_FOG_LO := Color(0.05, 0.06, 0.10, 0.16)           # 云团阴影
const FOG_PUFFS := 10       # 每格画几团云（位置/大小按格子 id 抖动，见 _fog_rand）

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
const ENTER_SLIDE := 0.30           # R151 P1-10：过场前「当前房间」金标先沿桥滑到目标房间（秒）
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
	"shop": "神秘商店",
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

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _t := 0.0
var _pulse_redraw_at := 0     # R186：呼吸/脉冲节流重绘的下次许可时刻（ms）
var _pulse_ms := 0            # R187：实际节流窗口（懒初始化；安卓 ×2，PC 45ms 不变）
var _hover_id := -1
var _mouse := Vector2.ZERO
var _records_visible := false
var _records_scroll := 0.0
var _records: Array = []
var _shot := false            # --screenshot 探针钉帧（R151：滚动类动画一律钉死）
var _deck_visible := false
var _deck_scroll := 0.0
var _deck_rows: Array = []
var _hover_deck := -1
var _relics_visible := false
var _menu: UiMenu = null          # Esc 主菜单（R148）
var _menu_btn: Button = null      # 上栏那个齿轮（**自绘图标**，需要它算尺寸/hover）
var _deck_btn: Button = null      # R155：右上「卡组」按钮（非战斗界面也能直接看卡组，不必先按 Esc）
var _relic_scroll := 0.0
var _whisper_auto := false
var _whisper_next: Dictionary = {}   # 命运本轮选中的下一间（画紫圈的目标）
var _whisper_wait := 0.0             # 距命运落下一步还有多少秒（<= 0 即可走）
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
	_shot = "--screenshot" in OS.get_cmdline_user_args()
	sfx = Sfx.new()
	add_child(sfx)
	_records = RunState.load_records()
	# 兜底：直接打开地图场景（调试）时临时开一局，避免空场景
	if not RunState.run_active or RunState.map_cells.is_empty():
		RunState.start_run(RogueMap.generate(_rng(), GameLayers.LAYER_DEFAULT),
				GameLayers.LAYER_DEFAULT)
	# R176：地图 BGM 按层取（第一层 Poema / 第二层 Strategy4）。
	# 位置必须在上面那段兜底 start_run **之后** —— 否则 current_layer 还没定。
	Bgm.play_map(RunState.current_layer)
	# -- --relics：演示道具栏（截图验证用）
	if "--relics" in OS.get_cmdline_user_args():
		RunState.relics = [6001, 6005, 6010]
		RunState.relic_choice = []
	# -- --whistle：演示鹰哨（R145 起 = 全图迷雾散尽，每格内容都可见）
	if "--whistle" in OS.get_cmdline_user_args():
		RunState.relics = [6001, 6005, 6026]
		RunState.relic_choice = []
	# -- --midway：演示「走过一片区域」的状态（截图核验视野规则用）
	if "--midway" in OS.get_cmdline_user_args():
		_prep_midway_demo()
	# -- --deck：直接打开卡组查看面板
	# R214：顺手给前两张塞附魔 —— 出图核验「卡面费用正下方有标记」+「列表行标出附魔名」。
	if "--deck" in OS.get_cmdline_user_args():
		RunState.ensure_deck_mods()
		var dm_ids := ["costdown", "save"]
		for dm_i in mini(dm_ids.size(), RunState.deck_ids.size()):
			RunState.deck_mods[dm_i] = RunState.enchant_mod(str(dm_ids[dm_i]))
		_deck_rows = _build_deck_rows()
		_deck_visible = true
	# -- --marks：演示玩家标记（R177：画图 / 旗子，截图核验用）
	if "--marks" in OS.get_cmdline_user_args():
		_prep_marks_demo()
	# 起点三选一 / 待办卡组操作：先走它们，别停在地图上。
	# ⚠️ **截图核验模式要跳过**：否则刚开的一局带着「起点道具三选一」，
	# 会立刻把场景切走 → 截图截到的是别的界面（甚至什么都截不到）。
	if "--screenshot" not in OS.get_cmdline_user_args():
		if RunState.run_active and not RunState.relic_choice.is_empty():
			SceneFx.goto("res://scenes/relic_pick.tscn", true)
			return
		var pick_scene := RunState.waiting_pick_scene()   # R216：唯一判据口
		if pick_scene != "":
			SceneFx.goto(pick_scene, true)
			return
	# 续档检查点：已确定停留在地图（没有转去道具 / 卡组场景）→ 存一份本地存档。
	# ⚠️ 只在真实游玩时存：截图（_shot）/ headless（测试探针）都不写。
	if RunState.run_active and not _shot and DisplayServer.get_name() != "headless":
		RunSave.save_run()
	# R179：带着 boss_pending 回到地图（刚打完最后一格里的战斗 / 事件）→ 也给同样长的缓冲，
	# 别一进地图就糊上「入夜」黑屏。
	if RunState.run_active and RunState.boss_pending:
		_boss_hold = BOSS_HOLD_AFTER_ENTER
	# R148：上栏原来挂着「回到标题 / 战斗记录 / 查看卡组」三个 chip —— 全部收进
	# Esc 菜单（点齿轮或按 Esc 打开），上栏只留**一个齿轮**。
	_menu_btn = Button.new()
	_menu_btn.position = Vector2(14, 14)
	_menu_btn.size = Vector2(44, 28)
	_menu_btn.pressed.connect(_open_menu)
	_menu_btn.draw.connect(_draw_menu_gear)
	UiTheme.apply_chip(_menu_btn, true)
	add_child(_menu_btn)
	# R155：右上「卡组」按钮 —— 贴在巧克力计数左边（原来卡组只能 Esc 菜单里看）
	_deck_btn = Button.new()
	_deck_btn.text = "卡组"
	_deck_btn.position = Vector2(size.x - 24.0 - CHOCO_PANEL_W - 12.0 - 76.0, CHOCO_PANEL_Y - 2.0)
	_deck_btn.size = Vector2(76, 30)
	_deck_btn.tooltip_text = "查看当前卡组（Esc 菜单里也有）"
	_deck_btn.pressed.connect(_toggle_deck)
	_deck_btn.pressed.connect(func(): sfx.play("click"))
	UiTheme.apply_chip(_deck_btn, true)
	add_child(_deck_btn)
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "返回地图",
		"sub": "冒险地图 · 按 Esc 返回",
	})
	_reward_panel = RewardPanel.attach(self, Vector2(12, 40))
	# 道具「鸭之低语」（6010）：玩家失去选择权 → 系统随机挑路并自动前进。
	# ⚠️ R194：这里只负责**接手**（`_start_whisper` 挑出第一间），真正一步步往下走
	#    由 `_process` → `_tick_whisper` 持续驱动 —— 原来只在 `_ready` 挑一次、
	#    抽中「走过的房间」时不会换场景、也就再没人挑路 → 当场卡死（用户上报）。
	if RunState.run_active and RunState.has_relic(RunState.WHISPER_RELIC_ID):
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
	# -- --slidepin：演示沿桥滑动（R151 P1-10，钉在中段出图核验；停在过场前不真的进入）
	if "--slidepin" in OS.get_cmdline_user_args():
		_anim_hold = true
		_slide_pin = true
		for c2: Dictionary in RunState.available_nodes():
			if not _visited(c2) and str(c2["type"]) != "start":
				_anim_cell = c2
				_anim_t = 0.0
				_slide_from = _cell_center(_cur_cell()) if not _cur_cell().is_empty() 						else _cell_center(c2)
				_slide_to = _cell_center(c2)
				break
	# -- --toastdemo：演示通用 Toast（R151 P2-17；0.6s 截图时 toast 仍可见）
	if "--toastdemo" in OS.get_cmdline_user_args():
		# ⚠️ _ready 期间 root 正忙（Parent busy），toast 的懒实例挂不上去 → 延迟一帧
		(func(): UiToast.toast("回放开始")).call_deferred()
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


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r


func _prep_midway_demo() -> void:
	## 演示：把玩家挪到中路，并标记一条走过的路线 —— 用于核验 R145 的三条规则：
	## 「走过的格子边变暖白」「走过的房间 + 下一步看得见内容」「其余盖迷雾」。
	var cells := RunState.map_cells
	if cells.size() != RogueMap.CELLS:
		return
	RunState.cleared_ids = []
	RunState.seen_ids = []
	# 沿起点一路向上走 3 格（找有路的邻居）
	var cur := int(RogueMap.start_cell(cells)["id"])
	RunState.cleared_ids.append(cur)
	RunState.reveal_known()   # R207：把「站在起点时已经看过的那一圈」记进记忆 ——
	                          #      走开之后它们**不该**重新被雾盖回去（本演示要核验这条）
	for step in 3:
		var nxt := -1
		var fallback := -1      # 没有向上的门时的兜底（起点可能只有左右两个门）
		for nid in RogueMap.neighbor_ids(cells[cur]):
			var c: Dictionary = cells[int(nid)]
			if RunState.cleared_ids.has(int(nid)):
				continue
			if fallback < 0:
				fallback = int(nid)
			if int(c["row"]) < int(cells[cur]["row"]):
				nxt = int(nid)
				break
		if nxt < 0:
			nxt = fallback
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
	# ---- R177：标记模式按钮 —— **任何状态都可点**（含「关」态激活）----
	# ⚠️ R184 修：按钮命中原来只判在 `_handle_mark_input` 里，而那个函数仅在
	# `_mark_mode >= 0` 之后才走 → 关态（-1）点按钮掉进下面的普通地图分支，
	# 该坐标又不在任何格子上 → 直接 return，**标记功能永远开不了口**。
	# 按钮必须判在模式分支**之前**；回放只读，按钮同样不响应。
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var mbi := _mark_btn_at(event.position)
		if mbi >= 0:
			# 再点一次当前模式的按钮 = 收起（回到纯地图模式）
			_mark_set_mode(-1 if _mark_mode == mbi else mbi)
			return
	# ---- R177：标记模式激活时，这一块输入全归标记所有 ----
	# 不 hover 房间、点击也不进房间（否则画一笔就进战斗了）。再点一次当前模式
	# 的按钮 = 收起，行为与旧版完全一致。
	if _mark_mode >= 0:
		_handle_mark_input(event)
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
		var cell := _cell_at(event.position)
		if cell.is_empty() or not _is_available(cell):
			return
		if _whisper_auto:
			return   # 鸭之低语：前路由命运决定，玩家点不动
		sfx.play("click")
		_enter_node(cell)


var _slide_from := Vector2.ZERO   # R151 P1-10：沿桥滑动起点（进入前的当前房间中心）
var _slide_to := Vector2.ZERO     # R151 P1-10：沿桥滑动终点（目标房间中心）
var _slide_pin := false           # --slidepin：把滑动钉在中段（出图核验）


func _cur_cell() -> Dictionary:
	## 当前房间的格子字典（拿不到就回退成空 —— 滑动退化为原地）。
	for c: Dictionary in RunState.map_cells:
		if int(c["id"]) == RunState.current_node_id:
			return c
	return {}


func _enter_node(cell: Dictionary, animate := true) -> void:
	## 走进一个房间。
	## * **没去过的**房间 → 先播一段进场过场（`animate = false` 可跳过，回放用）；
	## * 回到**走过的**房间 → 不播过场，直接走原逻辑（什么都不会发生）。
	if cell.is_empty() or not _anim_cell.is_empty():
		return
	if animate and not _visited(cell) and RunState.can_move_to(int(cell["id"])):
		_anim_cell = cell
		_anim_t = 0.0
		# R151 P1-10：过场前先把「当前房间」金标沿桥滑到目标房间（300ms，路径感）
		_slide_from = _cell_center(_cur_cell()) if not _cur_cell().is_empty() 				else _cell_center(cell)
		_slide_to = _cell_center(cell)
		queue_redraw()
		return
	_commit_enter(cell)


func _commit_enter(cell: Dictionary) -> void:
	## 真正的「进入」：结算 + 按房间类型分流。**只能由过场结束（或回放）调用。**
	var id := int(cell["id"])
	var res := RunState.advance(id)
	if not bool(res.get("ok", false)):
		return
	if not bool(res.get("is_new", false)):
		# 原路返回：不扣巧克力、不结算 —— 给一句轻提示，免得玩家以为点击失效。
		_set_note("这里是走过的房间，什么都不会发生（不消耗巧克力）")
		return
	# R200：持有货物 → 第二层第一个事件房替换成「委托完成」（一次性）。
	# ⚠️ 必须在 pending_node = cell **之前**改：Dictionary 是引用，后改会断开。
	var delivery_kind := RunState.delivery_override_kind()
	if delivery_kind != "" and str(cell.get("type", "")) == "event":
		cell = cell.duplicate()   # 别污染地图本体（map_cells 里那份）
		cell["event_kind"] = delivery_kind
	RunState.pending_node = cell
	var dtype := RogueMap.display_type(cell)
	match dtype:
		"battle", "elite":
			RunState.pending_level = RunState.next_level(cell)
			SceneFx.goto("res://scenes/battle.tscn")
		"rest", "event":
			# 事件房不再遭遇战斗：本层事件池已去掉「遭遇怪物」（见 GameLayers）。
			SceneFx.goto("res://scenes/event.tscn")
		"chest":
			# 普通宝箱：一次卡牌奖励 + 50 金币（R181）
			RunState.gain_gold(50)
			RunState.queue_card_reward("normal")
			_open_reward_panel()
		"bigchest":
			# 大宝箱：**1 个道具 + 一次卡牌奖励 + 80 金币**（R181）
			RunState.gain_gold(80)
			RunState.queue_relic_reward(RunState.roll_reward_relic())
			RunState.queue_card_reward("normal")
			_open_reward_panel()
		"shop":
			# R181：神秘商店 —— 进入商店场景（3 行商品，金币消费）。
			SceneFx.goto("res://scenes/shop.tscn")


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
	if _slide_pin:
		_anim_t = ENTER_SLIDE * 0.55   # R151 演示：把沿桥滑动钉在中段（出图核验）
	if not _anim_cell.is_empty():
		_anim_t += delta
		if _anim_t >= ANIM_DUR + ENTER_SLIDE and not _anim_hold:
			var entered := _anim_cell
			_anim_cell = {}
			# R179：过场刚结束 → 给一点缓冲再入夜（玩家先看清当前格落定）。
			_boss_hold = BOSS_HOLD_AFTER_ENTER
			_commit_enter(entered)
	elif _boss_hold > 0.0:
		_boss_hold = maxf(0.0, _boss_hold - delta)
	_map_pulse_redraw()   # R186：呼吸/脉冲动画 45ms 节流（R180 同款，原来每帧全量重绘）
	# 巧克力耗尽 → 等当前房间的内容结算完（进过场走完 / 奖励弹窗关掉 / 战斗与事件回来）
	# 再开 Boss 战。R179：原来这里没排除「进场过场播放中」，于是最后一格的过场还在播时
	# 入夜暗罩就已经盖上来了（用户报）；现在过场期间（`_anim_cell` 非空）与缓冲期内都不触发。
	# ⚠️ 回放模式同样要触发（boss_pending 由 advance 确定性地置位），只是不等那 2 秒。
	# R236：再加一道 `chocolate <= 0` 兜底 —— 体力若被商店买回 > 0，即使 boss_pending
	# 因故残留也不该入夜（正常流程 add_chocolate 已清掉它，这里是双保险）。
	if RunState.run_active and RunState.boss_pending and RunState.chocolate <= 0 \
			and not _boss_alert \
			and _boss_hold <= 0.0 and _anim_cell.is_empty() \
			and (_reward_panel == null or not _reward_panel.is_open()):
		_trigger_boss_alert()
	# 鸭之低语（R194）：本场景一空闲就继续走下一步 —— 过场中 / 奖励窗开着 / 已入夜
	# 都先按住（空闲判定见 `_tick_whisper`）。
	_tick_whisper(delta)


func _map_pulse_redraw() -> void:
	## R186：呼吸/脉冲动画的节流重绘 —— 每 45ms 才真正 queue_redraw。
	## 动画相位基于 _t（重绘时自动取当前相位），22fps 采样视觉依然平滑（R180 结论）。
	if _pulse_ms <= 0:
		# R187：安卓脉冲窗口 ×2（45→90ms）。⚠️ OS 门控：PC 端保持 45ms 原样。
		_pulse_ms = 90 if OS.get_name() == "Android" else 45
	var n := Time.get_ticks_msec()
	if n < _pulse_redraw_at:
		return
	_pulse_redraw_at = n + _pulse_ms
	queue_redraw()


func _trigger_boss_alert() -> void:
	_boss_alert = true
	sfx.play("click")
	queue_redraw()
	var t := Timer.new()
	t.wait_time = 2.2
	t.one_shot = true
	t.timeout.connect(_start_boss_battle)
	add_child(t)
	t.start()


func _start_boss_battle() -> void:
	RunState.boss_pending = false
	RunState.pending_level = RunState.boss_level()
	RunState.pending_node = {"type": "boss"}
	SceneFx.goto("res://scenes/battle.tscn")


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
	_draw_fog()          # R145：内容看不见的格子盖迷雾（**桥不盖** —— 通路要可见）
	_draw_states()
	_draw_marks()        # R177：玩家标记画在地图内容之上、HUD 之下
	_draw_hud()
	_draw_sidebar()
	_draw_mark_buttons()   # R177：三个标记模式按钮（最上层，不被任何面板盖）
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
	## R145：内容看不见的格子走**中性底** —— 按类型染色等于把「里面是什么」漏出去。
	for cell: Dictionary in RunState.map_cells:
		var r := _cell_rect(cell)
		var done := _visited(cell)
		if not RunState.known_node(int(cell["id"])):
			draw_rect(r, COL_CELL_FOG_FILL, true)
			draw_rect(r, COL_CELL_LINE, false, 1.4)
			continue
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
	## R145：`known_node` 说不看得见的，**一个像素都不画**（迷雾下面不许漏内容）。
	for cell: Dictionary in RunState.map_cells:
		var r := _cell_rect(cell)
		var done := _visited(cell)
		if not RunState.known_node(int(cell["id"])):
			continue
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


func _draw_fog() -> void:
	## R145 迷雾：**看不清里面是什么**的格子盖一层云雾。
	## ⚠️ 桥**不**在这里盖（它画在两格之间的墙上、不在格子里）→ 路线始终可见。
	## 判定口只有 `RunState.known_node()` 一个（战斗内地图总览读同一个）。
	for cell: Dictionary in RunState.map_cells:
		var id := int(cell["id"])
		if RunState.known_node(id):
			continue
		_draw_fog_cell(_cell_rect(cell), id)


func _fog_rand(id: int, i: int, salt: int) -> float:
	## 迷雾专用的**确定性伪随机**（0..1）：同一格、同一索引永远同一个值 ——
	## 所以雾的形状稳定（不会逐帧乱跳），而**相邻格的雾长得不一样**。
	## ⚠️ 不能用 `randf()`：那会让迷雾每帧换一个形状（看起来像在闪雪花）。
	var v := sin(float(id) * 12.9898 + float(i) * 78.233 + float(salt) * 37.719) * 43758.5453
	return v - floor(v)


func _draw_fog_cell(r: Rect2, id: int) -> void:
	## 一格的云雾：青灰底 + 云。**R154 起优先用 `map_fog.png`**（柔和蓝白云雾素材，
	## 替换深蓝程序云块 —— 清单 §2.3：旧云块与森林背景断裂）；缺图回退程序云团。
	## 云的位置 / 大小 / 明暗都由 `_fog_rand` 从格子 id 推出来 —— 同格稳定、格与格不同。
	## 整体只做极慢的呼吸，读起来是「雾」，不是「贴了块灰纸」。
	## ⚠️ 云团必须**整团留在本格内**：素材四周已做渐隐（透明边），所以即使贴边画，
	##    可见部分也不会溢到隔壁**看得见**的格子；程序云团走老的几何约束（`m`）。
	##    Godot 4.3 没有 `draw_set_clip_rect`（§4.11），只能用几何约束代替裁剪。
	var breathe := 0.90 + 0.10 * sin(_t * 0.9 + float(id) * 1.7)
	var inner := r.grow(-2.0)
	draw_rect(inner, Color(COL_FOG_BASE.r, COL_FOG_BASE.g, COL_FOG_BASE.b,
			COL_FOG_BASE.a * breathe), true)
	var fog_tex := UiAssets.map_fog()
	if fog_tex != null:
		# 主云：盖满整格（素材透明边 ≈15%，可见云体仍在格内）；位置按 id 轻抖。
		var jx := (_fog_rand(id, 0, 1) - 0.5) * 0.10
		var jy := (_fog_rand(id, 0, 2) - 0.5) * 0.10
		var grow := 1.02 + 0.10 * _fog_rand(id, 0, 3)
		var sz: Vector2 = inner.size * grow
		var ctr := inner.get_center() + Vector2(inner.size.x * jx, inner.size.y * jy)
		var tint := 0.82 + 0.18 * breathe
		# 半数格子水平镜像（按 id 定死）—— 相邻格不都是「同一张贴纸」。
		if _fog_rand(id, 2, 5) > 0.5:
			draw_set_transform(ctr, 0.0, Vector2(-1, 1))
			draw_texture_rect(fog_tex, Rect2(-sz * 0.5, sz), false,
					Color(0.92, 0.96, 1.0, tint))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(fog_tex, Rect2(ctr - sz * 0.5, sz), false,
					Color(0.92, 0.96, 1.0, tint))
		# 碎云：小一号、错位，让相邻格不重复（仍靠 _fog_rand 定死）。
		var sz2: Vector2 = inner.size * (0.42 + 0.14 * _fog_rand(id, 1, 3))
		var ctr2 := inner.get_center() + Vector2(
				inner.size.x * (0.20 - 0.40 * _fog_rand(id, 1, 1)),
				inner.size.y * (0.20 - 0.40 * _fog_rand(id, 1, 2)))
		draw_texture_rect(fog_tex, Rect2(ctr2 - sz2 * 0.5, sz2), false,
				Color(0.88, 0.94, 1.0, 0.55 * breathe))
		draw_rect(inner, Color(1, 1, 1, 0.05), false, 1.0)
		return
	for i in FOG_PUFFS:
		var rad := inner.size.x * (0.15 + 0.13 * _fog_rand(id, i, 3))
		var m := rad / inner.size.x            # 中心离边至少一个半径 → 整团不越界
		var span := maxf(0.0, 1.0 - 2.0 * m)
		var fx := m + span * _fog_rand(id, i, 1)
		var fy := m + span * _fog_rand(id, i, 2)
		var ctr := Vector2(inner.position.x + inner.size.x * fx,
				inner.position.y + inner.size.y * fy)
		var light := _fog_rand(id, i, 4) > 0.42
		var src := COL_FOG_HI if light else COL_FOG_LO
		draw_circle(ctr, rad, Color(src.r, src.g, src.b, src.a * breathe))
	draw_rect(inner, Color(1, 1, 1, 0.05), false, 1.0)


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
	## **R145 视野规则**：通路**全图可见**（路线看得见，玩家才规划得了去大宝箱的路），
	## 所以这里**不再按「走过没走过」过滤**。三档颜色仍然区分：
	##   亮青 = 当前房真能走过去的 / 暖白 = 至少一端走过 / 灰蓝最小 = 两端都还在雾里。
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	var drawn := {}          # 去重：两格之间只盖一座桥（两个方向是同一处）
	for cell: Dictionary in RunState.map_cells:
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
			_draw_player_marker(r)   # R166：当前格叠角色头像，一眼看到「我在这」
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


func _draw_player_marker(r: Rect2) -> void:
	## R166：当前格右上角叠一枚**角色头像**标记（只有头），按所选职业取图
	## （`RunState.player_class`）。缺图回退成我方色圆点 —— 不空白不报错。
	var tex := UiAssets.class_avatar(RunState.player_class)
	var d := 34.0
	var c := Vector2(r.position.x + r.size.x - d * 0.32, r.position.y + d * 0.32)
	draw_circle(c, d * 0.62, Color(0.05, 0.06, 0.09, 0.85))
	draw_arc(c, d * 0.62, 0.0, TAU, 24, UiTheme.ACCENT_LIT, 2.0, true)
	if tex != null:
		draw_texture_rect(tex, Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), false)
	else:
		draw_circle(c, d * 0.30, UiTheme.SIDE_SELF)


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
	## R151 P0-3：数量滚动（战斗/事件回来少了一块时从旧值滚到新值）；
	## 变化量反馈已有 R131 的「-1 小牌」过场，这里只补滚动。
	var n := _choco_shown()
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


func _choco_shown() -> int:
	## 巧克力计数的显示值：探针钉帧（--screenshot）直接钉死，否则走滚动唯一口。
	var target := float(RunState.chocolate)
	if _shot:
		UiRoll.snap("map.choco", target)
		return roundi(target)
	return roundi(UiRoll.value("map.choco", target))


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

func _draw_bridge_slide() -> void:
	## R151 P1-10：金标沿桥从当前房间滑到目标房间（与「当前房间」金框同一视觉语言）。
	var k := clampf(_anim_t / ENTER_SLIDE, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)   # ease-out
	var pos := _slide_from.lerp(_slide_to, e)
	var s := CELL * 0.62
	var r := Rect2(pos - Vector2(s, s) / 2.0, Vector2(s, s))
	draw_rect(r.grow(3.0), UiTheme.ACCENT_LIT, false, 3.0)
	draw_rect(r.grow(8.0), Color(0.95, 0.76, 0.31, 0.28), false, 5.0)


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
	var p := clampf((_anim_t - ENTER_SLIDE) / ANIM_DUR, 0.0, 1.0)
	if _anim_t < ENTER_SLIDE:
		_draw_bridge_slide()   # R151 P1-10：先沿桥滑 300ms，过场各段全部顺移
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
	## ⚠️ R145：这一行直接压在**彩绘背景图**上，12px 的灰字根本读不清（提示还很长）。
	##    按既定口径「画在底图上的文字要带底条」给它垫一条半透明底带，字色同步提亮。
	##    底带从地图下沿之下开始（`MAP_Y0 + MAP_H + 2`）—— 绝不压到棋盘最下一行。
	var bar_y := MAP_Y0 + MAP_H + 2.0
	var bar := Rect2(0.0, bar_y, size.x, maxf(0.0, size.y - bar_y))
	draw_rect(bar, Color(0.03, 0.04, 0.06, 0.60), true)
	draw_rect(Rect2(bar.position, Vector2(size.x, 1.2)), Color(1, 1, 1, 0.10), true)
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
				HORIZONTAL_ALIGNMENT_LEFT, 64, UiTheme.FS_CAPTION, UiTheme.SAND)
		x += 84.0
	# 右下提示
	var hint := "小桥＝通路，全图可见 · 迷雾遮住房间内容，只看得清「下一步」的几间 · 走过的房间可免费返回 · 巧克力用完即打 Boss"
	if _whisper_auto:
		hint = "【鸭之低语】前路已被命运选定，你无法自主选择……"
	elif RunState.has_relic(RunState.EAGLE_WHISTLE_RELIC_ID):
		hint = "鹰哨：全图迷雾已散，每一格都看得见 · 小桥＝通路 · 巧克力用完即打 Boss"
	draw_string(_font, Vector2(size.x - 600.0, size.y - 30.0 + 14.0),
			_ellipsis(hint, 586.0, UiTheme.FS_CAPTION),
			HORIZONTAL_ALIGNMENT_RIGHT, 586.0, UiTheme.FS_CAPTION, Color("efe9db"))


# ------------------------------------------------------------ R177 地图标记

func _mark_color() -> Color:
	## 标记颜色 = 当前职业色（唯一口 `UiTheme.class_color`）；取不到时回落金色。
	var c := UiTheme.class_color(RunState.player_class)
	return c if c.a > 0.0 else UiTheme.ACCENT_GOLD


func _mark_btn_rect(i: int) -> Rect2:
	## 三个模式按钮：左上角纵排。y 从 92 起 —— TopBar（0~40）与「本层 Boss」条
	## （约 50~80）之下，按钮和右侧中文标签都不与它们重叠；x 在地图区左侧空白。
	return Rect2(14.0, 92.0 + i * 40.0, 34.0, 34.0)


func _mark_btn_at(pos: Vector2) -> int:
	for i in 3:
		if _mark_btn_rect(i).has_point(pos):
			return i
	return -1


func _mark_set_mode(m: int) -> void:
	_mark_mode = m
	_mark_drawing = false
	_mark_cur = PackedVector2Array()
	_mark_flag_press = Vector2(-1, -1)
	sfx.play("click")
	queue_redraw()


func _mark_clamp(p: Vector2) -> Vector2:
	## 标记点限制在地图区内（否则战斗内总览做线性映射时会跑到面板外）。
	return Vector2(clampf(p.x, MAP_X0, MAP_X0 + MAP_W),
			clampf(p.y, MAP_Y0, MAP_Y0 + MAP_H))


func _handle_mark_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
		if _mark_drawing:
			if _mark_mode == MARK_PEN:
				_mark_stroke_add(event.position)
			elif _mark_mode == MARK_ERASE:
				_mark_erase_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# 按钮命中已在 `_gui_input` 前置处理（关态也要能激活），这里只认画布
		_mark_drawing = true
		if _mark_mode == MARK_PEN:
			_mark_cur = PackedVector2Array([_mark_clamp(event.position)])
		elif _mark_mode == MARK_ERASE:
			_mark_erase_at(event.position)
		elif _mark_mode == MARK_FLAG:
			_mark_flag_press = event.position
	elif event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if not _mark_drawing:
			return
		_mark_drawing = false
		if _mark_mode == MARK_PEN and _mark_cur.size() >= 2:
			RunState.map_strokes.append({"pts": _mark_cur, "col": _mark_color()})
			_mark_cur = PackedVector2Array()
			sfx.play("click")
		elif _mark_mode == MARK_FLAG and _mark_flag_press != Vector2(-1, -1):
			# 旗子：按下到松开位移很小才算「放旗」（按住拖动不触发放旗，避免误置）
			RunState.map_flags.append({"pos": _mark_clamp(_mark_flag_press),
					"col": _mark_color()})
			_mark_flag_press = Vector2(-1, -1)
			sfx.play("click")


func _mark_stroke_add(p: Vector2) -> void:
	var q := _mark_clamp(p)
	if _mark_cur.size() > 0 and q.distance_to(_mark_cur[_mark_cur.size() - 1]) < MARK_MIN_STEP:
		return
	_mark_cur.append(q)


func _mark_erase_at(p: Vector2) -> void:
	## 橡皮命中：旗子按圆心半径、笔画按「点到任一线段的距离」；整条 / 整个删。
	var hit := false
	for i in range(RunState.map_flags.size() - 1, -1, -1):
		var f: Dictionary = RunState.map_flags[i]
		if Vector2(f["pos"]).distance_to(p) <= MARK_ERASE_R + 8.0:
			RunState.map_flags.remove_at(i)
			hit = true
	for i in range(RunState.map_strokes.size() - 1, -1, -1):
		var pts: PackedVector2Array = RunState.map_strokes[i]["pts"]
		for j in range(pts.size() - 1):
			if _dist_to_seg(p, pts[j], pts[j + 1]) <= MARK_ERASE_R:
				RunState.map_strokes.remove_at(i)
				hit = true
				break
	if hit:
		queue_redraw()


static func _dist_to_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _draw_marks() -> void:
	## R177 玩家标记：笔画（先垫 2px 暗描边再画本色，压亮色节点仍可辨）+ 小旗。
	## 画在格子 / 图标 / 迷雾之上、HUD 之下 —— 标记是「玩家自己的笔记」，
	## 不该被迷雾盖住（迷雾遮的是房间内容）。
	for s: Dictionary in RunState.map_strokes:
		var pts: PackedVector2Array = s["pts"]
		if pts.size() < 2:
			continue
		draw_polyline(pts, Color(0, 0, 0, 0.45), MARK_LINE_W + 2.0)
		draw_polyline(pts, Color(s["col"]), MARK_LINE_W)
	for f: Dictionary in RunState.map_flags:
		_draw_mark_flag(Vector2(f["pos"]), Color(f["col"]))
	# 正在画的笔画：松手才入栈，但拖拽中要实时可见
	if _mark_mode == MARK_PEN and _mark_drawing and _mark_cur.size() >= 2:
		draw_polyline(_mark_cur, Color(0, 0, 0, 0.45), MARK_LINE_W + 2.0)
		draw_polyline(_mark_cur, _mark_color(), MARK_LINE_W)
	# 橡皮：擦拭中画一个光标圈，提示擦除半径
	if _mark_mode == MARK_ERASE and _mark_drawing:
		draw_circle(_mouse, MARK_ERASE_R, Color(1, 1, 1, 0.10))
		draw_arc(_mouse, MARK_ERASE_R, 0, TAU, 24, Color(1, 1, 1, 0.55), 1.2)


func _draw_mark_flag(p: Vector2, col: Color) -> void:
	## 小旗（程序绘制）：杆 + 三角旗面（职业色）+ 暗描边 + 底座。
	var pole := Vector2(p.x, p.y - 26.0)
	draw_line(p, pole, UiTheme.SAND, 2.2)
	var tri := PackedVector2Array([pole, pole + Vector2(16, 5), pole + Vector2(0, 10)])
	draw_colored_polygon(tri, col)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]),
			Color(0, 0, 0, 0.55), 1.2)
	draw_circle(p, 2.6, Color(0, 0, 0, 0.55))


func _draw_mark_buttons() -> void:
	## 三个模式按钮（左上纵排）+ 各自的中文小标签。
	for i in 3:
		var r := _mark_btn_rect(i)
		var on := _mark_mode == i
		draw_rect(r, Color(0.07, 0.08, 0.12, 0.85), true)
		draw_rect(r, UiTheme.ACCENT_GOLD if on else Color(1, 1, 1, 0.16),
				false, 2.0 if on else 1.0)
		var c := r.get_center()
		match i:
			MARK_PEN:
				_draw_mark_icon_pen(c, on)
			MARK_FLAG:
				_draw_mark_icon_flag(c, on)
			MARK_ERASE:
				_draw_mark_icon_erase(c, on)
		var label: String = ["画图", "标记", "擦除"][i]
		draw_string(_font, Vector2(r.end.x + 8.0, c.y + 4.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, 48.0, UiTheme.FS_CAPTION,
				UiTheme.ACCENT_LIT if on else UiTheme.INK_300)


func _draw_mark_icon_pen(c: Vector2, on: bool) -> void:
	var col := UiTheme.ACCENT_LIT if on else UiTheme.INK_300
	var a := c + Vector2(-6, 7)
	var b := c + Vector2(6, -7)
	draw_line(a, b, col, 2.6)
	var tip := PackedVector2Array([b + Vector2(-1, -4), b + Vector2(5, -1), b + Vector2(-1, 2)])
	draw_colored_polygon(tip, col)


func _draw_mark_icon_flag(c: Vector2, on: bool) -> void:
	var col := UiTheme.ACCENT_LIT if on else UiTheme.INK_300
	var base := c + Vector2(-5, 8)
	draw_line(base, base + Vector2(0, -16), col, 2.2)
	var tri := PackedVector2Array([base + Vector2(0, -16),
			base + Vector2(12, -12), base + Vector2(0, -8)])
	draw_colored_polygon(tri, col)


func _draw_mark_icon_erase(c: Vector2, on: bool) -> void:
	var col := UiTheme.ACCENT_LIT if on else UiTheme.INK_300
	var a := c + Vector2(-7, 5)
	var pts := PackedVector2Array([a, a + Vector2(12, -4), a + Vector2(8, 4), a + Vector2(-4, 12)])
	draw_colored_polygon(pts, col)
	draw_line(a + Vector2(1, 1), a + Vector2(9, -1), Color(0.07, 0.08, 0.12, 0.85), 2.0)


func _prep_marks_demo() -> void:
	## --marks：演示玩家标记（R177 截图核验用）。两笔 + 两旗，职业色。
	var col := _mark_color()
	RunState.map_strokes = [
		{"pts": PackedVector2Array([Vector2(300, 300), Vector2(380, 260),
				Vector2(460, 320), Vector2(540, 250)]), "col": col},
		{"pts": PackedVector2Array([Vector2(640, 500), Vector2(720, 460),
				Vector2(800, 520)]), "col": col},
	]
	RunState.map_flags = [
		{"pos": Vector2(520, 400), "col": col},
		{"pos": Vector2(880, 200), "col": col},
	]
	_mark_mode = MARK_PEN


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

func _open_menu() -> void:
	## 上栏齿轮按钮 / Esc 键。
	if _menu != null:
		_menu.open()


func _menu_items() -> Array:
	## 冒险地图的菜单项（R148）—— 上栏原来那三个 chip 都搬到这里了。
	## ⚠️ 每次打开菜单都会重新调用本函数（attach 传的是函数引用）→ 音效文案是当下值。
	return [
		{"text": "战斗记录", "fn": _toggle_records},
		{"text": "查看卡组", "fn": _toggle_deck},
		{"text": func(): return "音效：开" if sfx.enabled else "音效：关",
			"fn": _toggle_sound, "keep_open": true},
		{"text": "回到标题", "fn": _on_back_to_title},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _on_back_to_title() -> void:
	## 回到标题：R167 起**保留续档** —— 回标题后可点「继续游戏」从地图检查点接着来。
	## （本局没结束，所以不写对战记录 —— 真的不打了，下次开新局 / 关窗口时才补「中断」。）
	if RunState.run_active:
		RunState.end_run(false)
	SceneFx.goto("res://scenes/title.tscn")


func _draw_menu_gear() -> void:
	## 齿轮图标（**自绘** —— 字体里的 ⚙ 不保证有）：hover 提亮，轴孔跟着底板走。
	var hot := _menu_btn.is_hovered()
	var col: Color = UiTheme.CHIP_SOLID_TEXT_HOVER if hot else UiTheme.CHIP_SOLID_TEXT
	var bg: Color = UiTheme.CHIP_SOLID_BG_HOVER if hot else UiTheme.CHIP_SOLID_BG
	UiTheme.draw_gear(_menu_btn, _menu_btn.size * 0.5, 8.0, col, bg)


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
	## ⚠️ R112 起卡组里不再有「运行时改写费用」的卡 —— 但 **R207** 起必须按
	## 「卡面签名」（id + 费用 + 力/生 + 词缀）聚合，不能只按 id：
	## 商店附魔（R181）生成的是**同 id 的独立副本**，只按 id 合并会把「+10 攻击的那张」
	## 并进原卡、面板上显示成没附魔的数值 —— 玩家花了钱却看不出效果。
	## 卡实例统一从 `RunState.build_deck()` 取（它负责把附魔烤进副本）。
	var repo := CardRepo.load_json()
	var seen := {}
	var out: Array = []
	for c: CardData in RunState.build_deck(repo):
		var key := "%d|%d|%d|%d|%s" % [c.id, c.cost, c.power, c.health,
				",".join(c.affixes)]
		if seen.has(key):
			out[seen[key]]["count"] += 1
			continue
		seen[key] = out.size()
		out.append({"id": c.id, "card": c, "count": 1})
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
			# R214：带附魔的卡在这一行前面标出附魔名（卡面费用正下方同时有附魔标记）——
			# 列表里一眼能挑出「花过钱的那几张」，不用凑近看卡面小徽章。
			var stat_txt := "费用 %d · %s" % [c.cost, CardFace.stats_line(c)]
			var stat_col := Color("9a968c")
			if c.has_enchant():
				stat_txt = "附魔「%s」· %s" % [CardData.enchant_name(c.enchant), stat_txt]
				stat_col = CardData.enchant_color(c.enchant)
			draw_string(_font, r.position + Vector2(68, 45), stat_txt,
					HORIZONTAL_ALIGNMENT_LEFT, 372, UiTheme.FS_CAPTION, stat_col)
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
	# R148：Esc = 主菜单（菜单开着时它自己关掉自己）
	if _menu != null and _menu.handle_esc(event):
		return
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
	## 接手：命运替玩家挑路（第一步）。
	## 后续每一步由 `_tick_whisper` 在 `_process` 里持续驱动 —— 本函数只负责起头。
	_whisper_auto = true
	_whisper_next = RunState.whisper_pick()
	_whisper_wait = WHISPER_FIRST_DELAY
	queue_redraw()


func _tick_whisper(delta: float) -> void:
	## 鸭之低语的**持续代走**（R194）。
	## 旧实现是「`_ready` 挑一次 + 一次性 Timer 走一步」：那一步若落在**走过的**房间上
	## （`advance()` 不换场景），本场景就不会重跑 `_ready` → 再没人挑路，
	## 而 `_whisper_auto` 又挡着玩家点击 → 队伍卡死、「只走一格就停」（用户上报）。
	## 现在做成**本场景的常驻循环**：场景一空闲就接着走；走过旧房间不算数，
	## 一路走到「没走过的房间」为止（那一步会切去战斗 / 事件 / 商店，或就地开奖励窗）。
	##
	## 空闲 = 没在播进场过场、没开着奖励悬浮窗、还没入夜、也不在回放 / 出图钉帧。
	if not _whisper_auto or not RunState.run_active or _shot:
		return
	if not RunState.has_relic(RunState.WHISPER_RELIC_ID):
		return
	if not _anim_cell.is_empty() or RunState.boss_pending:
		return
	if _reward_panel != null and _reward_panel.is_open():
		return
	_whisper_wait = maxf(0.0, _whisper_wait - delta)
	if _whisper_wait > 0.0:
		return
	if _whisper_next.is_empty():
		_whisper_next = RunState.whisper_pick()
		if _whisper_next.is_empty():
			return                        # 无处可去（生成约束下不会发生）
		_whisper_wait = WHISPER_STEP_DELAY   # 先亮出紫圈，再落地
		queue_redraw()
		return
	var step := _whisper_next
	_whisper_next = {}
	sfx.play("click")
	_enter_node(step)
	# 走的是**走过的**房间（`_enter_node` 不起过场、RunState 已即时推进）→ 接着挑下一步；
	# 走的是新房间则由过场 + 场景切换接手（本场景即将卸载，下一步在 `_ready` 里重挑）。
	if _anim_cell.is_empty():
		_whisper_next = RunState.whisper_pick()
	_whisper_wait = WHISPER_STEP_DELAY
	queue_redraw()


