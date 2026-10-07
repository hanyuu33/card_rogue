extends Control
## 对战主界面（Godot 副本）—— 布局与 Python/tkinter 版 1280x720 设计一致。
##
## 交互与 tkinter 版保持一致：
##   * 点手牌选中 → 点自己半场空格上场；双击/再点法术直接使用
##   * 点自己单位 → 绿色可移动 / 红色可攻击 / 深红打 HP 高亮
##   * 寒冰护盾需要选目标：紫色高亮所有战场单位，点一个结算
##   * 右键 / 点空白取消；「回合结束」后敌方 AI 逐单位行动
##
## 窗口缩放由 Godot 的 canvas_items 拉伸模式天然支持，无需手工适配。

# ------------------------------------------------------------ 布局常量（设计坐标 1280x720）

const WINDOW_W := 1280.0
const WINDOW_H := 720.0
const CARD_W := 58.0
const CARD_H := 70.0
const CELL := 76.0
const TAP_W := 70.0
const TAP_H := 58.0
const GRID_X := 560.0
const GRID_Y := 136.0
const GRID_W := 3.0 * CELL
const GRID_H := 6.0 * CELL
const COST_X := 310.0
const COST_Y := GRID_Y
const ENERGY_H := 96.0         # 左栏顶部能量面板高度（下面是效果区）
const DECK_X := WINDOW_W - CARD_W - 60.0
const DECK_Y := WINDOW_H - CARD_H - 44.0
const DISCARD_X := DECK_X
const DISCARD_Y := DECK_Y - CARD_H - 52.0
const OPP_HAND_Y := 14.0
# ---- 手牌：比战场小卡大一号，卡身一路长到窗口下沿之外 ----
# 空间账：手牌区只有 592~720 这 128px。既然「底部不必完全显示」，
# 就把卡底往屏幕外沉 HAND_CROP_BOTTOM 像素，省下的位置全换成卡面尺寸：
# 卡顶下移 → 卡看着更贴底、也更大；沉出去的那截只有底部留白（内容按可见高度重锚）。
const COL_COST_LOW_BG := Color("1d7a3f")        # 减费后的费用圆（深绿底）
const COL_COST_LOW_FG := Color("b9f6ca")        # 减费后的费用数字（浅绿字，绿色系）
const COL_GUARD := Color("1d9e4f")              # 替 HP 承伤（森林守护/以太守卫/铁栅栏）：绿环标记
const COL_TAUNT := Color("ff8f00")              # 嘲讽：战场单位的橙色脉冲光环（必须优先打它）
const COL_FROZEN := Color("6ec6ff")             # 冰封（寒冰箭/冻结陷阱/冰冻战吼）：冷蓝脉冲环 + 寒霜（这回合动不了）
const COL_SLEEP := Color("b07bff")              # 沉睡（恶魔鸭 9116）：紫脉冲环 + Zzz（还差 N 下挨打就醒）
const COL_FIELD_SELF := Color("ffb03a")         # 场地效果（R74）：我方放的 —— 琥珀色斜纹 + 名字角标
const COL_FIELD_FOE := Color("ff5d5d")          # 敌方放的场地 —— 红斜纹（一眼分清敌我）
const COL_FIELD_PERSIST := Color("5ad0e6")      # 持续型场地（R83：清泉）—— 冷青，静止描边（不是陷阱）
const HAND_CARD_SCALE := 1.70                   # 手牌相对战场小卡的放大倍数
const HAND_CARD_W := CARD_W * HAND_CARD_SCALE   # ≈ 98.6
const HAND_CARD_H := CARD_H * HAND_CARD_SCALE   # = 119.0（整张，含沉出屏幕的部分）
const HAND_CROP_BOTTOM := 18.0                  # 卡底沉到窗口下沿之外多少像素
const OWN_HAND_Y := WINDOW_H - HAND_CARD_H + HAND_CROP_BOTTOM   # = 619（卡顶）
# ---- 手牌扇形布局 ----
# 手牌整体可用宽度：卡变宽（98.6）后要留神右边 x=900 起的道具栏 —— 最右那张会绕底部中心
# 转出去（sin12° × 露出高度 ≈ 21px），356 是「满手也不越界」的上限（见 test_smoke 的越界断言）。
const HAND_FAN_WIDTH := 356.0     # 手牌整体可用宽度（装不下就靠重叠压缩）
const HAND_FAN_MIN_STEP := 0.40   # 最小步进 = 卡宽 × 此比例（即最多 60% 重叠）
const HAND_FAN_MAX_DEG := 12.0    # 两端最大倾角（度）
const HAND_FAN_DEG_PER := 4.0     # 相邻两张的倾角差（度）
const HAND_FAN_DROP := 4.0        # 扇弧两端相对扇心的下沉像素（正好把底边框沉掉）
const HAND_FAN_HOVER_LIFT := 16.0 # 悬停时抬手高度（纯显示，不影响命中判定）
const HAND_SELECT_RAISE := 16.0   # 选中手牌时抬起的高度
const INFO_X := 8.0
const INFO_W := 272.0   # 左栏（详细效果 / 对局记录）：宽一点，效果正文少折几行

# ------------------------------------------------------------ 颜色

const COL_BG := Color("e9e7e2")
const COL_CELL_LINE := Color("9a9a9a")
const COL_OWN_FRAME := Color("2e7d32")
const COL_ENEMY_FRAME := Color("c62828")
const COL_MOVE := Color(0.184, 0.682, 0.306, 0.55)
const COL_ATTACK := Color(0.831, 0.227, 0.184, 0.55)
const COL_HP := Color(0.545, 0.102, 0.102, 0.75)
const COL_SPELL := Color(0.416, 0.290, 0.839, 0.55)
const COL_FENCE_MERGE := Color(0.851, 0.545, 0.098, 0.60)   # 叠栅栏（栅栏修复术）：目标格 = 已有栅栏
## R102：两段式技能「已选中第一个单位」的标记 —— 金黄粗描边 + 角标「已选」。
## 与 COL_SPELL（候选目标）刻意区分开：那个是"还能点"，这个是"已经点过了"。
const COL_PICKED := Color(1.0, 0.784, 0.0, 0.95)
const COL_OPP_BACKROW := Color(0.541, 0.353, 0.165, 0.5)
const COL_OWN_BACKROW := Color(0.165, 0.353, 0.541, 0.5)
const COL_WIN := Color("c1121f")
const COL_LOSE := Color("1d3557")
const COL_INFO_BG := Color("f7f5f0")
## 手卡「现在打出能吃到额外效果」的金色高亮（R65）：与「减费绿」区分开，一眼看出是收益提醒。
const COL_HAND_BONUS := Color("f2c14e")

# 战斗内地图总览（R64）的节点配色与字形 —— **与 map_scene 保持同一套**，
# 这样「地图场景看到的颜色」和「战斗里回看地图的颜色」是同一种语义。
# （map_scene 里那份是它自己的 const，改这里时两边要一起改。）
const MAPVIEW_TYPE_COLORS := {
	"start": Color("7a94b8"),    # 起点 蓝灰
	"battle": Color("c6503c"),   # 普通战斗 红
	"elite": Color("8a30b8"),    # 精英 紫
	"rest": Color("3f9b5f"),     # 休息 绿
	"event": Color("d1a12a"),    # 事件 金
	"chest": Color("e0912a"),    # 宝箱层 橙金
	"boss": Color("33323b"),     # Boss 黑
}
const MAPVIEW_TYPE_GLYPHS := {
	"start": "起", "battle": "战", "elite": "英", "rest": "息",
	"event": "事", "chest": "箱", "boss": "王",
}

# 攻击投射演出时间轴（比例 × ATK_DUR_MS）
const ATK_DUR_MS := 1500        # 总时长
const ATK_WINDUP_T := 0.10      # 开始后仰蓄力
const ATK_LAUNCH_T := 0.30      # 弹体发射
const ATK_IMPACT_T := 0.62      # 弹体命中目标
const DESTROY_HOLD_MS := 140    # 命中后卡牌「留一帧」再消失：先看得见伤害，再击破
const MOVE_SLIDE_BASE_MS := 160     # 移动滑行：起步耗时（1 格 = 420ms，与旧版一致）
const MOVE_SLIDE_PER_STEP_MS := 260 # 移动滑行：每多走 1 格再加这么久

# ------------------------------------------------------------ 状态

var repo: CardRepo
var engine: GameEngine
var selection = null            # ["hand", idx] / ["board", Vector2i] / null
var move_targets: Array[Vector2i] = []
var attack_targets_arr: Array[Vector2i] = []
var hp_targets_arr: Array[Vector2i] = []
var spell_pending: int = -1     # 手牌序号（-1 = 不在选目标模式）
var spell_targets: Array[Vector2i] = []
var _infiltrate_src := Vector2i(-1, -1)   # 潜入（9100）第一段选中的己方盟友格
## 「双向传送」（8061，R102）的**两段式**第一段：已选中的**第一个单位**所在格
## （敌我皆可，所以不像 `_infiltrate_src` 那样限己方）。第二段点另一个单位即交换。
var _swap_src := Vector2i(-1, -1)
## 「系统升级」（8039，R90）的**两段式**第一段：已选中的「系统升级」手牌下标（-1 = 未选）。
## 它的目标是**手牌里**的卡（不是棋盘），所以不能走 `spell_targets`（那套是棋盘格），
## 选中后要**点手牌**完成第二段 —— 靠这个变量标记「正在等玩家选手牌」。
var _sys_upgrade_idx := -1
var status_text := ""
var _status_hold_until := 0     # 操作反馈的保护期：期间悬停文本不覆盖
var _whisper_txt := ""          # 道具「鸭之低语」：本回合随机到的强化（常驻显示）
var _hover_relic_tip := ""      # 道具悬停：完整说明走浮动折行面板（工具栏一行放不下）
var _demo_tip_text := ""       # --relictip 演示：每帧重设悬停提示（warp 的合成移动会清掉一次性设置）
var _demo_hover_idx := -1      # --xtext 演示：每帧重设悬停手牌卡（合成鼠标移动会清掉一次性设置）

# 拖拽释放：按住技能/效果卡拖到目标格（或棋盘）上松手即生效
const DRAG_THRESHOLD := 14.0    # 超过此位移判定为拖拽（否则视为点击）
var _press_idx := -1            # 按下的手牌下标（-1 = 按下点不在手牌）
var _press_pos := Vector2.ZERO
var _drag_idx := -1             # 正在拖拽的手牌下标（-1 = 无）
var _drag_pos := Vector2.ZERO
var _drag_spell_cells: Array[Vector2i] = []   # 拖拽中技能的有效目标格
var _drag_anywhere := false     # 拖到棋盘任意处即可释放（无目标技能/效果卡）
var _drag_place := false        # 拖拽的是随从/工事：落到自己半场空格放置
var _drag_place_cells: Array[Vector2i] = []   # 随从/工事的合法放置格（自己半场空格）


func _say(text: String) -> void:
	## 操作反馈消息：2.5 秒内不被悬停信息覆盖。
	status_text = text
	_status_hold_until = Time.get_ticks_msec() + 2500
var _ai_timer: Timer
var _bg_tex: Texture2D
var _back_tex: Texture2D
var _font: SystemFont
var _font_bold: SystemFont

# 关卡与教程：
var _cur_level: Dictionary = {}
var _tutorial: Array = []       # 教程步骤（Dictionary 数组，空 = 非教程关）
var tutorial_step := 0
var _tutorial_finished := true
var _level_menu: PopupMenu
const TUT_BAR_TOP := 36.0       # 工具栏高度之下
const TUT_BAR_MAX_H := 98.0     # 顶到棋盘第一行（GRID_Y=136）之前

# 教程引导条控件（_ready 里构建）
var _tut_bar: Panel
var _tut_title: Label
var _tut_prog: Label
var _tut_body: Label
var _tut_task: Label
var _tut_check: Label
var _tut_next_btn: Button
var _tut_close_btn: Button

# 动画状态（tkinter 版做不到的部分）：
var _slides := {}               # Placement -> {from,to: 像素中心, start, dur[, pts]} 上场/移动
                                # pts = 逐格路径的中心点数组；给了就按它分段滑行（多格移动走真实轨迹）
var _attacks := {}              # Placement -> {dir, src, dst, start, dur}     分阶段攻击动画
var _delayed: Array = []        # {at, kind, data}                             命中/击破定时特效
var _ghosts: Array = []         # {center, name, start, dur}                  击破淡出
var _dying: Array = []          # {cell, card, p, hide_at}                    已归零但仍要显示到命中时刻的卡
var _floaters: Array = []       # {pos, text, col, start, dur}                伤害/治疗飘字
var _flashes := {}              # Placement -> {col, start, dur}              受击闪色覆盖
var _hp_pending: Dictionary = {} # 尚未在「命中演出」中体现的待扣生命：
								 #   单位卡面 / HP 横幅 把显示数字冻结在「实际值 + 未演出伤害之和」，
								 #   等对应的 hit / hp_hit 定时特效触发时才移除这一笔，数字才往下掉。
var _bursts: Array = []         # {pos, start, dur, col, big}                 打击爆点（扩散环+火花）
var _wake_rings: Array = []     # {pos, start, dur, col}                       恶魔鸭苏醒的挣脱环（R72）
var _shake_until := 0           # 屏幕震动截止时刻
var _shake_mag := 0.0           # 屏幕震动幅度（像素）

# 打磨：音效 / 回合横幅 / 胜利彩带 / 对局记录 / 结算覆盖层
var sfx: Sfx
var _banner := {}               # {text, col, start, dur}  回合切换大字横幅
var _confetti: Array = []       # {pos, vel, rot, vr, size, col}  胜利彩带
var _log_visible := false       # 对局记录面板开关
var _map_visible := false       # 冒险地图总览面板开关（R64：战斗内查看地图，只读）
var _map_scroll := 0.0# 地图总览的纵向滚动量（层数放不进 720px 视口，层数见 RogueMap.COLS）
var _discard_visible := false   # 弃牌区浏览面板开关（点弃牌区切换）
var _effects_visible := false   # 效果区浏览面板开关（点左侧效果区查看）
var _enemy_effects_visible := false  # 敌方效果区浏览面板开关
var _deck_visible := false      # 卡组（抽牌堆）浏览面板开关（点卡组牌堆查看，不显示顺序）
var _relics_visible := false    # 道具浏览面板开关（道具栏装不下时点它查看全部）
var _relic_scroll := 0.0        # 道具浏览面板滚动量（道具太多时滚轮翻动）
# 「英雄」（9023）的弃牌代价：上场前让玩家自己挑 4 张手牌丢掉
# _hero_pick_idx = 待上场的英雄手牌下标（-1 = 没有待付代价的卡）
var _hero_pick_idx := -1
var _hero_pick_cell := Vector2i(-1, -1)   # 英雄要落到的空格
var _hero_pick_sel: Array[int] = []       # 已选要丢弃的手牌下标
var _hover_card: CardData = null  # 鼠标悬停的卡（左侧信息栏优先显示）
var _hover_pl: Placement = null   # 悬停的战场单位（可显示当前生命）
var _hover_hand := -1             # 悬停的手牌下标（-1 = 无）：仅用于绘制时抬手
var _over_shown := false        # 结算覆盖层是否已弹出（边沿检测）
var _replay_next_at := 0        # 回放下一条动作的执行时刻（msec，R46）
var _over_panel: PanelContainer
var _over_title: Label
var _over_hint: Label            # 结算面板副标题（难度档位信息等）
var _over_btn_restart: Button
var _over_btn_level: Button
var _over_btn_title: Button
var _run_boss_win := false      # run 结算：本场是否为 Boss 通关（决定按钮路由）
var _run_next_layer := 0        # Boss 通关后要进入的下一层（0 = 没有下一层 → 结束 run）

# 联机模式（NetSession.active 时启用）：镜像引擎 + 动作收发回放
var _net_mode := false
var _net_queue: Array = []      # 收到的对方消息（待回放）
var _net_replaying := false     # 回放间隔锁（看清对方做了什么）
var _net_wait := 0.0

@onready var toolbar: Panel = $Toolbar
@onready var turn_label: Label = $Toolbar/TurnLabel
@onready var hp_label: Label = $Toolbar/HpLabel
@onready var status_label: Label = $Toolbar/StatusLabel
@onready var end_turn_btn: Button = $Toolbar/EndTurnBtn
@onready var map_btn: Button = $Toolbar/MapBtn
@onready var level_btn: Button = $Toolbar/LevelBtn
@onready var title_btn: Button = $Toolbar/TitleBtn
@onready var log_btn: Button = $Toolbar/LogBtn
@onready var snd_btn: Button = $Toolbar/SndBtn


func _ready() -> void:
	_bg_tex = load("res://assets/battle_bg.png")
	_back_tex = load("res://assets/cardback.png")
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	_font_bold = SystemFont.new()
	_font_bold.font_names = _font.font_names
	sfx = Sfx.new()
	add_child(sfx)
	map_btn.pressed.connect(_toggle_map)
	end_turn_btn.pressed.connect(_on_end_turn)
	title_btn.pressed.connect(_on_back_to_title)
	for b: Button in [map_btn, end_turn_btn, title_btn, level_btn]:
		b.pressed.connect(func(): sfx.play("click"))
	_ai_timer = Timer.new()
	_ai_timer.wait_time = 1.6
	_ai_timer.timeout.connect(_ai_step)
	add_child(_ai_timer)
	_build_tut_bar()
	_build_level_menu()
	_build_over_panel()
	log_btn.pressed.connect(_toggle_log)
	snd_btn.pressed.connect(_toggle_sound)
	_load_entry_level()
	# 命令行 -- --screenshot / -- --demo：自动化演示与截图（验证视觉效果用）
	var args := OS.get_cmdline_user_args()
	_demo_args = args
	_shot_pending = "--screenshot" in args or "--demo" in args
	_demo_pending = "--demo" in args
	if _shot_pending:
		_demo_frame = 0
		_shot_frame = 45 if "--spellshot" in args else 150  # 45 = 法术飘字进行中
	if "--customdeck" in args:
		pass  # 卡组构筑已移除（肉鸽版固定初始卡组），参数保留兼容旧命令
	for i in args.size():
		if args[i] == "--level" and i + 1 < args.size():
			var li := int(args[i + 1])
			var levels := GameLevels.builtin_levels()
			if li >= 0 and li < levels.size():
				load_level(levels[li])  # 截图验证用：--level 0
		if args[i] == "--shotframe" and i + 1 < args.size():
			_shot_frame = maxi(int(args[i + 1]), 10)  # 截图时机（帧），捕弹体/爆点用
		if args[i] == "--shotms" and i + 1 < args.size():
			_shot_ms = maxi(int(args[i + 1]), 10)  # 截图时机（距演示动作的毫秒数）
	if "--over" in args:
		# 演示：直接进入结算（验证结算覆盖层 / 彩带 / 胜利音效）
		engine._finish("胜利", "演示：结算界面")
	if "--relics" in args and engine != null:
		# 演示：右栏道具栏（截图验证用；放在 args 循环后，避免被 --level 重建覆盖）
		engine.self_relics = [6001, 6005, 6010]   # 初始白 / 奖励黄 / 事件紫
		_whisper_txt = "本回合造成的伤害 +1"
	if "--layer2" in args and engine != null:
		# 演示：第二层起始道具（截图验证用）—— 生蛋鸭开场鸭蛋 + 冰淇淋与汽水开场 -3 生命
		engine.self_relics = [6016, 6018]
		engine.apply_battle_start_relics(repo)
		status_text = "第二层起始道具：生蛋鸭（开场鸭蛋）+ 冰淇淋与汽水（开场 -3 生命）"
		queue_redraw()
	if "--icecream" in args and engine != null:
		# 演示：冰淇淋与汽水（6016）—— 第 1 回合 +4 能量 / 多抽 3 张 → 台词飘字。
		# 必须重跑 load_level：第 1 回合结算发生在 start_game 内部，
		# 而 load_level 会用 RunState.relics 覆盖 engine.self_relics。
		RunState.relics = [6016]
		load_level(GameLevels.builtin_levels()[0])
		status_text = "冰淇淋与汽水：第 1 回合 +4 能量 / 多抽 3 张 ——「你跑不过我你信吗」"
		_shot_t0 = _now()
		queue_redraw()
	if "--fan" in args and engine != null:
		# 演示：扇形手牌 + 手牌上限 —— 继续抽到满手 10 张（第 3 次会广播 hand_full），
		# 并把中间一张伪装成「悬停抬起」（截图验证用）
		engine._draw_many(4)
		_hover_hand = engine.state.hand.size() / 2
		# 悬停 = 抬手 + 左侧详细效果面板（真机上是同一件事，截图要一起验证）
		_hover_card = engine.state.hand[_hover_hand]
		status_text = "扇形手牌：%d/%d 张（重叠 + 弧线），悬停抬起" % [
				engine.state.hand.size(), FieldState.HAND_LIMIT]
		_shot_t0 = _now()
		queue_redraw()
	if "--hero" in args and engine != null:
		# 演示：二层事件「绝赞五换一」的奖励卡「英雄」（9023）——
		# 上场必须额外丢弃 4 张手牌 → 直接打开「选择 4 张丢弃」面板（截图验证用）。
		var hero_card := repo.get_card(GameEngine.HERO_CARD_ID)
		if hero_card != null:
			while engine.state.hand.size() < 6:   # 英雄 + 至少 5 张可弃的
				if engine.state.draw() == null:
					break
			engine.state.hand.append(hero_card)
			_hero_pick_idx = engine.state.hand.size() - 1
			_hero_pick_cell = Vector2i(4, 1)
			_hero_pick_sel = []
			status_text = "英雄的代价：选择 4 张手牌丢弃（0/4）"
			_shot_t0 = _now()
			queue_redraw()
	if "--wmheal" in args and engine != null:
		# 演示：白魔法师回合开始的治疗（白魔法师压到 30%、骑士压到 40% →
		# 百分比最低的是白魔法师 → 结束回合后它给自己 +10）
		for c: Vector2i in engine.state.board.keys():
			var pp: Placement = engine.state.board[c]
			if pp.card.id == 9001:
				pp.health = 12          # 12/30 = 40%
			elif pp.card.id == 9021:
				pp.health = 30          # 30/100 = 30% ← 百分比最低
		_on_end_turn()
		_shot_t0 = _now()
	if "--pear" in args and engine != null:
		# 演示：鸭梨（6019）——我方 HP 受伤 → 最大生命 +1（只提高上限，不回复生命）
		engine.self_relics = [6019]
		var pear_before: int = engine.state.max_hp_self
		engine._damage_player(GameEngine.SIDE_SELF, 5, "演示：鸭梨")
		status_text = "鸭梨：受到 5 点伤害 → 最大生命 %d → %d（当前生命不回复）" % [
				pear_before, engine.state.max_hp_self]
		_shot_t0 = _now()
		queue_redraw()
	if "--bossnext" in args and engine != null:
		# 演示：第一层 Boss 通关 → 结算面板出现「进入第二层」按钮（截图验证用；
		# 配合 --level <Boss 关下标>）
		RunState.run_active = true
		RunState.current_layer = GameLayers.LAYER_DEFAULT
		RunState.hp = 30
		RunState.pending_node = {"type": "boss"}
		engine._finish("胜利", "演示：第一层 Boss 通关")
		queue_redraw()
	if "--newcards" in args and engine != null:
		# 演示：三张新卡（2026-09-30）的视觉验证 ——
		#   协同攻击 9035：我方场上 2 个盟友 → 实际费用 3-2=1，手牌费用圆显绿
		#   森林守护 9037：给一个盟友加「守护」→ 战场单位画绿环
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.COORD_ATTACK_ID))
		engine.state.hand.append(repo.get_card(GameEngine.BEAST_HEART_ID))
		engine.state.energy = 5
		engine.state.place(repo.get_card(8003), Vector2i(4, 0), GameEngine.SIDE_SELF)  # 农民（盟友）
		engine.state.place(repo.get_card(8003), Vector2i(4, 2), GameEngine.SIDE_SELF)  # 农民（盟友）
		engine._forest_guard(GameEngine.SIDE_SELF, Vector2i(4, 0))   # 4,0 的农民获得森林守护（绿环）
		_hover_hand = 0
		_hover_card = engine.state.hand[0]
		status_text = "三张新卡：协同攻击（2 盟友 → 费用 3→1，绿色）+ 森林守护（绿环）"
		_shot_t0 = _now()
		queue_redraw()
	if "--xtext" in args and engine != null:
		# 演示（2026-10-01）：长描述效果卡。
		# 悬停最长的那张（空间守护 9064）→ 左栏信息面板用于像素级核验「长描述不溢出」。
		# 镜像 9056 自 R35 起不再是「每回合第 X 次」组，但仍是长描述卡 → 留在演示里。
		engine.state.hand.clear()
		for _tid in [9057, 9056, 9063, 9064, 9069]:
			engine.state.hand.append(repo.get_card(_tid))
		engine.state.energy = 9
		_demo_hover_idx = 3
		status_text = "长描述改版：威慑 / 镜像 / 以太咆哮 / 空间守护 / 鸭窝"
		_shot_t0 = _now()
		queue_redraw()
	if "--mage" in args and engine != null:
		# 演示（2026-10-01）：白魔法师「精进」——每个自己的回合开始力量 +1（永久累计，无前置条件）。
		# 场上再摆一个农民 → 证明「不再要求只剩它自己」也成长：力量 2 → 3，飘字「精进 +1 攻」。
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(9021))
		engine.state.energy = 7
		engine.state.place(CardData.from_dict(repo.get_card(9021).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(repo.get_card(8003), Vector2i(5, 1), GameEngine.SIDE_SELF)
		engine._mage_growth(GameEngine.SIDE_SELF)
		_demo_hover_idx = 0
		status_text = "「精进」：每回合开始 +1 攻（已去掉「只剩它自己」）"
		_shot_t0 = _now()
		queue_redraw()
	if "--meteor" in args and engine != null:
		# 演示（2026-10-01）：流星雨（9083）—— X 费：消耗全部能量，对随机敌人打 9 伤 X 次。
		# 先用 5 能量打一次（5 颗、每次随机选目标）→ 看陨石爆点/飘字；
		# 再补一张进手牌并悬停 → 看卡面费用圆的「X」与左栏「费用 X（消耗全部能量）」。
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.METEOR_SHOWER_ID))
		engine.state.energy = 5
		engine.state.place(CardData.from_dict(repo.get_card(9001).to_dict()),
				Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(1053).to_dict()),
				Vector2i(1, 2), GameEngine.SIDE_OPPONENT)
		engine.use_spell(0)
		engine.state.energy = 3
		engine.state.hand.append(repo.get_card(GameEngine.METEOR_SHOWER_ID))
		_demo_hover_idx = 0
		status_text = "流星雨：X 费（消耗全部能量）→ 随机敌人挨 9 点伤害，重复 X 次"
		_shot_t0 = _now()
		queue_redraw()
	if "--fire" in args and engine != null:
		# 演示（2026-10-01）：火墙术（9084）—— 3 费，对一横行的敌人造成 15 点伤害；
		# 该行燃烧到下次自己回合开始，期间任何单位（不分敌我）经过 → 再受 10 点。
		# 沿用默认关卡的两只鸭子骑士（1,0)/(1,2)，烧中间那条行；再让白魔法师穿过 → 100→90。
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.FIRE_WALL_SPELL_ID))
		engine.state.energy = 5
		engine.use_spell(0, Vector2i(1, 1))
		engine.state.place(CardData.from_dict(repo.get_card(9021).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_SELF)
		engine.move(Vector2i(2, 1), Vector2i(1, 1))
		engine.state.hand.append(repo.get_card(GameEngine.FIRE_WALL_SPELL_ID))
		_demo_hover_idx = 0
		status_text = "火墙术：第 1 行敌人 -15，穿过该行的单位再 -10（不分敌我）"
		_shot_t0 = _now()
		queue_redraw()
	if "--charge" in args and engine != null:
		# 演示（2026-10-01）：蓄力（9085）—— 2 费史诗，本方使用的下一张技能生效 2 次。
		# 亡灵领主 8/55 摆在 (1,1)，先蓄力再火焰箭（17 伤）→ 17×2 = 34 → 55→21。
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.CHARGE_SPELL_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(9003).to_dict()))
		engine.state.energy = 5
		engine.use_spell(0)   # 蓄力（2 费）
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
		engine.use_spell(0, Vector2i(1, 1))   # 火焰箭 → 生效 2 次
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.CHARGE_SPELL_ID).to_dict()))
		_demo_hover_idx = 0
		_hover_hand = 0   # 让左栏信息面板走 cost_of
		status_text = "蓄力：下一张技能生效 2 次 —— 火焰箭 17 伤 ×2 = 34（亡灵领主 55→21）"
		_shot_t0 = _now()
		queue_redraw()
	if "--druid" in args and engine != null:
		# 演示（2026-10-01）：角色「森林精魄」—— 熊（8004）上场 / 发动回春 / 荒野形态反伤。
		# 亡灵领主（8/55）贴脸打熊 → 自己吃到「荒野形态」3 点（55→52）；
		# 熊被压到 6 血后发动回春 → 6→12 并横置。
		RunState.player_class = PlayerClass.DRUID   # 左栏「角色：」也要跟着演示走
		engine.self_relics = [GameEngine.WILD_FORM_RELIC_ID]
		engine.state.hand.clear()
		var dr_bear := engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.BEAR_ID).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		engine.attack(Vector2i(2, 1), Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		dr_bear.health = 6
		engine.activate(Vector2i(3, 1))
		engine.state.hand.append(repo.get_card(GameEngine.BEAR_ID))
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "森林精魄：熊发动回春 6→12 并横置；打它的敌人吃到「荒野形态」3 点反伤"
		_shot_t0 = _now()
		queue_redraw()
	if "--rogue" in args and engine != null:
		# 演示（2026-10-01）：角色「暗影刺客」—— 终结（9086）的 4+X 与「幻影斗篷」6023。
		#   先出 2 张牌（本回合已用 2 张）→ 突袭 X=2 → 4+2=6 伤（亡灵领主 55→49）；
		#   三张牌各触发一次斗篷 → 亡灵领主共 -3 力量（8 → 5）。
		RunState.player_class = PlayerClass.ROGUE   # 左栏「角色：」也要跟着演示走
		engine.self_relics = [GameEngine.PHANTOM_CLOAK_RELIC_ID]
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(8005).to_dict()))
		engine.state.hand.append(
				CardData.from_dict(repo.get_card(GameEngine.RAID_SPELL_ID).to_dict()))
		engine.state.energy = 5
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		engine.play_from_hand(0, Vector2i(4, 0))   # 木栅栏 → 本回合第 1 张
		engine.play_from_hand(0, Vector2i(4, 2))   # 幽影   → 本回合第 2 张
		engine.use_spell(0, Vector2i(2, 1))        # 突袭 → 4 + 2 = 6
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "暗影刺客：本回合已用 2 张牌 → 终结 4+2=6 伤；幻影斗篷三张牌共 -3 力量"
		_shot_t0 = _now()
		queue_redraw()
	if "--rogue2" in args and engine != null:
		# 演示（2026-10-02）：暗影刺客 R45 —— 终结 / 连刺 / 偷袭 / 潜影者 / 影魔 / 幽光。
		#   终结(X=0)→连刺(带卡组 0 费技能卡)→偷袭(满血 12 伤)→潜影者上场→
		#   影魔（手里两张 0 费终结 → 生命 11→17）→幽光进效果区→再用终结（潜影者 +1 力量）。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		for rid in [GameEngine.RAID_SPELL_ID, GameEngine.GOUGE_ID, GameEngine.SNEAK_ID,
				GameEngine.LURKER_ID, GameEngine.SHADOW_DEMON_ID, GameEngine.GLOW_ID,
				GameEngine.RAID_SPELL_ID]:
			engine.state.hand.append(CardData.from_dict(repo.get_card(rid).to_dict()))
		engine.state.deck.append(CardData.from_dict(repo.get_card(GameEngine.RAID_SPELL_ID).to_dict()))
		engine.state.energy = 15
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
		engine.use_spell(0, Vector2i(2, 0))        # 终结（X=0）→ 4 伤
		engine.use_spell(0, Vector2i(2, 0))        # 连刺 → 4 伤 + 卡组 0 费技能卡入手
		engine.use_spell(0, Vector2i(2, 2))        # 偷袭：满血 → 12 伤
		engine.play_from_hand(0, Vector2i(4, 1))   # 潜影者（本回合已用 3 张）
		engine.play_from_hand(0, Vector2i(4, 2))   # 影魔：手卡 0 费技能卡 ×2 → 生命 11→17
		engine.use_effect(0)                       # 幽光 → 效果区（下回合开始给荧光草）
		engine.use_spell(0, Vector2i(2, 0))        # 终结（X=6）→ 10 伤；潜影者 +1 力量
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "暗影刺客 R45：潜影者每用一张牌 +1 力量；影魔吃 0 费技能卡 +3 生命/张；幽光待发"
		_shot_t0 = _now()
		queue_redraw()
	if "--echo" in args and engine != null:
		# 演示（2026-10-02，R48）：回响（9102）—— 1 费稀有，所有敌人各 2 伤 + 力量 -1，
		#   使用后**返回手卡**（手卡里还在，费用最低 1）。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.ECHO_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.ECHO_ID).to_dict()))
		engine.state.energy = 5
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
		engine.use_spell(0, null)                  # 回响：两个敌人各 -2、力量 -1，卡回手
		engine.use_spell(0, null)                  # 再用一次（能量 5 → 4 → 3）
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "回响：所有敌人各 2 伤 + 力量 -1；使用后返回手卡（费用最低 1，能量 5→3）"
		_shot_t0 = _now()
		queue_redraw()
	if "--dodge" in args and engine != null:
		# 演示（2026-10-02，R48）：闪躲（9103）—— 0 费普通；直到下个回合开始，
		#   自己受到的伤害由随机盟友代受（盟友生命不足时超出部分仍由自己承担）。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.DODGE_ID).to_dict()))
		engine.state.energy = 5
		var dg_ally := engine.state.place(CardData.from_dict(repo.get_card(8005).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		engine.use_spell(0, null)                  # 闪躲：开窗口
		engine._damage_player(GameEngine.SIDE_SELF, 5, "演示")   # 5 伤 → 幽影（3/8）代受
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "闪躲：伤害由随机盟友代受（幽影 8 → %d，我方 HP 未掉）" % dg_ally.health
		_shot_t0 = _now()
		queue_redraw()
	if "--finisher" in args and engine != null:
		# 演示（2026-10-02，R49）：收尾（9104）—— 1 费稀有；平时 4 伤，**打出时它是手卡里
		#   仅剩的一张** → 15 伤。这里连着打两张：第一张（手卡还剩一张）打左敌 4 伤，
		#   第二张（只剩它）打右敌 15 伤 —— 两张飘字并排，一眼看出差别。
		#   实际出牌延到第 80 帧（_demo_tick），避开开局「我方回合」横幅压住飘字。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		for i in 2:
			engine.state.hand.append(CardData.from_dict(
					repo.get_card(GameEngine.FINISHER_ID).to_dict()))
		engine.state.energy = 5
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 2), GameEngine.SIDE_OPPONENT)
	if "--trap" in args and engine != null:
		# 演示（R80 更新口径）：爆炸陷阱（8011）—— **敌人移动经过即触发**（不必停留），
		#   十字（含中心）各 18 伤，不分敌我。亡灵领主速 2，(3,0) → (3,1) → (3,2)
		#   的路上撞上 (3,1) 的陷阱 → 触发 + **立刻停在 (3,1)**，走不到 (3,2)。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.TRAP_ID).to_dict()))
		engine.state.energy = 5
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(4, 0), GameEngine.SIDE_SELF)
		engine.play_from_hand(0, Vector2i(3, 1))   # 爆炸陷阱落在 (3,1) —— 敌人**路过**的那一格
		engine.move(Vector2i(3, 0), Vector2i(3, 2), GameEngine.SIDE_OPPONENT)   # 经过 → 触发 + 停在 (3,1)
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "爆炸陷阱：敌人**移动经过** (3,1) 就触发（不必停留）并**立刻停止移动** —— 停在 (3,1)、走不到 (3,2)，十字各 18 伤不分敌我"
		_shot_t0 = _now()
		queue_redraw()
	if "--traps" in args and engine != null:
		# 演示（2026-10-03，R51）：陷阱精通（9105）+ 冻结 / 剧毒陷阱。
		#   先拍陷阱精通 → 两个亡灵领主分别踩冻结陷阱（3+2×2=7 伤 + 冰冻）
		#   和剧毒陷阱（每跳 6+2×2=10）。冰霜陷阱（1 费：4+2=6 伤 + 禁足）机制见回归测试。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.TRAP_MASTERY_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.FREEZE_TRAP_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.POISON_TRAP_ID).to_dict()))
		engine.state.energy = 9
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		engine.use_effect(0)                       # 陷阱精通进效果区
		engine.play_from_hand(0, Vector2i(4, 1))   # 冻结陷阱 (4,1)
		engine.play_from_hand(0, Vector2i(4, 0))   # 剧毒陷阱 (4,0)
		engine.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 经过冻结陷阱
		engine.move(Vector2i(3, 0), Vector2i(4, 0), GameEngine.SIDE_OPPONENT)   # 经过剧毒陷阱
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "陷阱精通：陷阱伤害 +2×原费 —— 冻结陷阱 3+4=7 伤+冰冻；剧毒陷阱每跳 6+4=10"
		_shot_t0 = _now()
		queue_redraw()
	if "--hunt" in args and engine != null:
		# 演示（2026-10-03，R52）：紧急埋伏 + 陷阱工坊 + 暗影狩猎。
		#   ① 紧急埋伏：场上 2 敌人 → 卡组 2 张工事进手，手里的工事费用 -1（绿字）；
		#   ② 亡灵领主两击打死陷阱工坊（10 血）→ 工坊被破坏：攻击者反受 8 伤并记「触发过工事」；
		#   ③ 暗影狩猎打它 —— 本回合刚触发还不翻倍（12 伤）；「上回合触发 → 24」由回归测试验证。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.energy = 9
		engine.state.deck.append(CardData.from_dict(repo.get_card(GameEngine.TRAP_ID).to_dict()))
		engine.state.deck.append(CardData.from_dict(repo.get_card(GameEngine.POISON_TRAP_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.AMBUSH_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.HUNT_ID).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		var r52_foe := engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		r52_foe.health = 60
		engine.use_spell(0)                       # 紧急埋伏：2 张工事进手 + 下一张工事 -1
		engine.state.place(CardData.from_dict(repo.get_card(GameEngine.WORKSHOP_ID).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.attack(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 8 伤 → 工坊剩 2
		r52_foe.tapped = false
		engine.attack(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 破坏 → 反受 8
		r52_foe.tapped = false
		engine.use_spell(0, Vector2i(3, 1))       # 暗影狩猎：12（触发记在本回合，下回合才翻倍）
		_demo_hover_idx = 0
		_hover_hand = 0
		_hover_card = engine.state.hand[0]        # 手里的工事 → 费用圆显绿（紧急埋伏 -1）
		status_text = "陷阱工坊被攻击破坏 → 攻击者反受 8 伤；它「上回合触发过工事」→ 暗影狩猎改为 24"
		_shot_t0 = _now()
		queue_redraw()
	if "--double" in args and engine != null:
		# 演示（R53 起是「双重陷阱」；R74 改名「双重场地」）：双重场地（9108）+ 穿刺陷阱（8016）。
		#   ① 双重陷阱给己方冰霜陷阱（4,1）附魔（紫字）；
		#   ② 亡灵领主攻击它 → 冰霜陷阱即死并禁足攻击者，同时**原格立刻召唤**一张随机「陷阱」工事；
		#   ③ 另一个亡灵领主踩穿刺陷阱（4,0）→ 自己吃 14 伤（纯直伤，没有附加状态）。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.energy = 9
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.DOUBLE_TRAP_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.PIERCE_TRAP_ID).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(GameEngine.FROST_TRAP_ID).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		var r53_foe := engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		r53_foe.health = 60
		engine.use_spell(0, Vector2i(4, 1))       # 双重陷阱 → 附魔冰霜陷阱
		engine.attack(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 踩陷阱 → 原格召唤
		engine.state.place(CardData.from_dict(repo.get_card(GameEngine.PIERCE_TRAP_ID).to_dict()),
				Vector2i(4, 0), GameEngine.SIDE_SELF)
		var r53_foe2 := engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		r53_foe2.health = 60
		engine.attack(Vector2i(3, 0), Vector2i(4, 0), GameEngine.SIDE_OPPONENT)   # 踩穿刺陷阱 → 14 伤
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "双重场地：附魔的场地触发并结束后 → 同格补一个随机场地；穿刺陷阱：敌人移动进入吃 14 伤"
		_shot_t0 = _now()
		queue_redraw()
	if "--capture" in args and engine != null:
		# 演示（R54 起是「巨物捕获」工事；**R76 改成场地卡「巨物陷阱」**）+ 活体栅栏 + 警觉。
		#   ① 巨物陷阱（场地）落在 (4,1)，敌人移动进入 → 吃 12 伤（不分敌我）、场地消失；
		#   ② 活体栅栏（8018 工事）正常在场 —— 证明「工事」与「场地」是两套独立数据；
		#   ③ 警觉：随机一张工事进手（费用 -2，绿色圆标注）。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.energy = 20
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.MASS_TRAP_ID).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(GameEngine.LIVING_FENCE_ID).to_dict()),
				Vector2i(4, 2), GameEngine.SIDE_SELF)
		var r54_weak := CardData.from_dict(repo.get_card(1051).to_dict())
		r54_weak.power = 2
		var r54_foe := engine.state.place(r54_weak, Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		r54_foe.health = 60
		engine.play_from_hand(0, Vector2i(4, 1))                 # 巨物陷阱落到 (4,1)
		engine.move(Vector2i(3, 1), Vector2i(4, 1), GameEngine.SIDE_OPPONENT)   # 踩上去 → 12 伤 + 场地消失
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.ALERT_ID).to_dict()))
		engine.use_spell(0)                                      # 警觉：随机工事 -2 费进手
		_demo_hover_idx = 0
		_hover_hand = 0
		_hover_card = engine.state.hand[0]                       # 警觉摇到的工事 → 绿色费用圆
		status_text = "巨物陷阱（场地）：敌人**移动经过**即吃 12 伤并停止移动、场地消失；活体栅栏仍是工事；警觉：随机工事进手（-2 费）"
		_shot_t0 = _now()
		queue_redraw()
	if "--r80" in args and engine != null:
		# 演示（R80）：① 场地「移动经过即触发 + 立刻停止移动」——
		#   敌方速 2 的白狼从 (2,0) 出发，(2,1) 上有穿刺陷阱：它**路过**就吃 18 伤，
		#   并且**停在 (2,1)**，走不到原定的 (2,2)；
		#   ② 「行动两次」文字徽标 —— 白狼（卡面自带双动）与被哈气覆盖的树人各挂一个绿标。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.energy = 5
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.PIERCE_TRAP_ID).to_dict()))
		# 白狼（actions=2，自带双动）+ 一只速 2 的普通敌人 + 两只我方树人
		engine.state.place(CardData.from_dict(repo.get_card(9031).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		var r80_foe2 := CardData.from_dict(repo.get_card(8003).to_dict())
		r80_foe2.move_speed = 2
		engine.state.place(r80_foe2, Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(0, 2), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(2, 2), GameEngine.SIDE_SELF)
		engine.play_from_hand(0, Vector2i(2, 1))            # 穿刺陷阱落在 (2,1) —— 路过的那一格
		engine.move(Vector2i(2, 0), Vector2i(2, 2), GameEngine.SIDE_OPPONENT)   # 经过 → 触发 + 停在 (2,1)
		engine.current_side = GameEngine.SIDE_SELF
		engine.state.reset_units(GameEngine.SIDE_SELF)       # 让我方树人进入可行动状态
		_demo_hover_idx = -1
		status_text = "R80：白狼从 (2,0) 走向 (2,2)，**路过 (2,1) 的穿刺陷阱** → 吃 18 伤并**立刻停在 (2,1)**（绿色「行动两次」徽标 = 本回合还剩 2 轮行动）"
		_shot_t0 = _now()
		queue_redraw()
	if "--fountain" in args and engine != null:
		# 演示（R83）：持续型场地「清泉」——
		#   ① 清泉落在 (4,1)，一只受伤的树人站在上面 → 我方回合结束 +2 血；
		#   ② 敌方速 2 的单位**经过** (2,1) 上另一格清泉 → **不被拦停、不被消耗**。
		#   与 --r80 的穿刺陷阱对照：脉冲描边 vs 冷青静止描边。
		RunState.player_class = PlayerClass.DRUID
		engine.state.hand.clear()
		engine.state.energy = 5
		# 我方树人（先打伤，让清泉有东西可治）
		var r83_tree := CardData.from_dict(repo.get_card(8003).to_dict())
		engine.state.place(r83_tree, Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.FOUNTAIN_ID).to_dict()))
		engine.play_from_hand(0, Vector2i(4, 1))          # 清泉放在树人脚下
		engine._hit_unit(engine.state.unit_at(Vector2i(4, 1)), 3, "演示")
		# 敌方半场也放一格清泉 + 一只速 2 的敌人，稍后让它路过
		var r83_far_card: CardData = CardData.from_dict(repo.get_card(8003).to_dict())
		r83_far_card.move_speed = 2
		engine.state.place(r83_far_card, Vector2i(2, 0), GameEngine.SIDE_OPPONENT)
		engine.state.set_field(CardData.from_dict(repo.get_card(GameEngine.FOUNTAIN_ID).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_SELF)
		engine.state.reset_units(GameEngine.SIDE_SELF)
		status_text = "R83：清泉（冷青静止描边）= **持续型场地**，不因经过而触发；" + \
				"站在上面的单位在**自己回合结束**时 +2 血（树人已受伤）"
		_shot_t0 = _now()
		queue_redraw()
	if "--charge" in args and engine != null:
		# 演示（R91）：① 充电装置 8041（接通己方上下两格）② 战场字段徽标轮流显示
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 5
		# 装置在 (4,1)，己方树人 (4,0) / 木栅栏 (4,2) 与它四方向相邻 → 接通
		engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
				Vector2i(4, 0), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(8001).to_dict()),
				Vector2i(4, 2), GameEngine.SIDE_SELF)
		var r91_st: Placement = engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.CHARGE_STATION_ID).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		# 一只带「幻影 + 死亡」字段的树人，用来展示战场字段徽标
		var r91_ghost := CardData.from_dict(repo.get_card(8003).to_dict())
		r91_ghost.add_affix(GameEngine.AFFIX_PHANTOM)
		r91_ghost.add_affix(GameEngine.AFFIX_DEATH)
		var r91_gp: Placement = engine.state.place(r91_ghost, Vector2i(5, 1),
				GameEngine.SIDE_SELF)
		engine.state.unit_at(Vector2i(4, 0)).health = 2
		engine.state.unit_at(Vector2i(4, 2)).health = 2
		r91_st.health = 1
		r91_gp.health = 4
		engine.state.reset_units(GameEngine.SIDE_SELF)
		engine.end_turn()      # 我方回合结束 → 接通的己方单位各 +2 血
		_demo_hover_idx = -1
		status_text = "R91 充电装置（1费工事）：**接通**=闪电链的四方向相连，" + \
			"但**只算我方** —— (4,0)/(4,2) 各回 2 血；右侧树人头顶**轮流显示**" + \
			"「幻影 / 死亡」字段徽标"
		_shot_t0 = _now()
		queue_redraw()
	if "--sysup" in args and engine != null:
		# 演示（R90）：两张「改造手牌」的技能——
		#   ① 系统升级：进入两段式等目标状态（手牌里可改造的卡带青色「可改造」标记）；
		#   ② 批量传输：手牌 3 张一起改造 + 抽 1 张。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.deck = [CardData.from_dict(repo.get_card(8004).to_dict())]
		engine.state.hand.append(CardData.from_dict(repo.get_card(8003).to_dict()))  # 树人
		engine.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))  # 木栅栏
		engine.state.hand.append(CardData.from_dict(repo.get_card(8002).to_dict()))  # 攻击
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.SYS_UPGRADE_ID).to_dict()))
		engine.state.energy = 5
		engine.state.reset_units(GameEngine.SIDE_SELF)
		_clear_selection()
		selection = ["hand", 3]
		_use_hand_card(3)          # 第一段：只记下它，等点手牌
		_demo_hover_idx = 0        # 悬停树人，让「可改造」标记清楚可见
		status_text = "R90 系统升级：青框「可改造」= 合法目标（盟友/工事）；" + \
			"点它 → 树人变 4 费 6 攻 14 血（**本场战斗永久**，+1费/+3力/+6血）"
		_shot_t0 = _now()
		queue_redraw()
	if "--batcht" in args and engine != null:
		# 演示（R90）：批量传输 —— 手牌全体改造 + 抽 1 张。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.deck = [CardData.from_dict(repo.get_card(8004).to_dict())]
		engine.state.hand.append(CardData.from_dict(repo.get_card(8003).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(8002).to_dict()))
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.BATCH_TRANSFER_ID).to_dict()))
		engine.state.energy = 5
		engine.state.reset_units(GameEngine.SIDE_SELF)
		engine.use_spell(3, null)
		status_text = "R90 批量传输：手牌 2 张盟友/工事各 **+1 费 / +3 攻 / +6 血**（技能卡不动）" + \
			"并**抽 1 张**（抽到熊）—— 加成本场战斗永久"
		_shot_t0 = _now()
		queue_redraw()
	if "--armor" in args and engine != null:
		# 演示（R89）：无限装甲（8038）——
		#   ① 场上放装甲 + 手牌塞一张「升级」→ 打出去改造它
		#   ② 立刻多一张**手牌里 0 费**的改造牌（卡面原费 1~2）
		#   ③ 再打一次「升级」→ **本回合不再供能**（每回合一次）
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 5
		var r89_armor: Placement = engine.state.place(
			CardData.from_dict(repo.get_card(GameEngine.INF_ARMOR_ID).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.hand.append(CardData.from_dict(
			repo.get_card(GameEngine.UPGRADE_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(
			repo.get_card(GameEngine.UPGRADE_ID).to_dict()))
		engine.use_spell(0, Vector2i(4, 1))      # 第 1 次改造 → 供一张 0 费牌
		var r89_fed: CardData = null
		for c: CardData in engine.state.hand:
			if engine.state.hand_free.has(c) and engine.state.hand.has(c):
				r89_fed = c
		engine.state.reset_units(GameEngine.SIDE_SELF)
		status_text = "R89：无限装甲（4 攻 / 18 血）**每回合一次**被「升级」改造时，" + \
			"供一张「效果含改造」的技能牌到手 —— 那张牌在手牌里是 **0 费**" + \
			"（「%s」卡面 %d 费），打出/弃掉后恢复原价" % [
				"?" if r89_fed == null else r89_fed.card_name,
				0 if r89_fed == null else r89_fed.cost]
		_shot_t0 = _now()
		queue_redraw()
	if "--factory" in args and engine != null:
		# 演示（R88）：持续型场地的第二族（机械之心）——
		#   ① 维修间 8036（冷青）落在 (4,1)，受伤的树人站上面；
		#   ② 改造工厂 8037 落在 (5,1)，一只战斗骨骼站上面 → 每回合 +1 力 / +1 血；
		#   ③ 敌方后排也放一格维修间 —— **敌方单位站上去不受益**（「友」生效）。
		#   与 --fountain 对照：清泉是「双」（敌我双方都回血），这两张只治自己人。
		RunState.player_class = PlayerClass.MECH
		engine.state.hand.clear()
		engine.state.energy = 5
		# 我方：受伤的树人站维修间
		var r88_tree := CardData.from_dict(repo.get_card(8003).to_dict())
		var r88_tree_p: Placement = engine.state.place(r88_tree, Vector2i(4, 1),
				GameEngine.SIDE_SELF)
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.REPAIR_BAY_ID).to_dict()))
		engine.play_from_hand(0, Vector2i(4, 1))
		engine._hit_unit(r88_tree_p, 4, "演示")
		# 我方：战斗骨骼站改造工厂
		var r88_bone: Placement = engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.BATTLE_BONE_ID).to_dict()),
				Vector2i(5, 1), GameEngine.SIDE_SELF)
		engine.state.set_field(CardData.from_dict(
				repo.get_card(GameEngine.UPGRADE_FACTORY_ID).to_dict()),
				Vector2i(5, 1), GameEngine.SIDE_SELF)
		# 敌方：一只受伤的敌人站在**我方放的维修间**上（敌方后排 row 0）→ 不受益
		var r88_foe: Placement = engine.state.place(
				CardData.from_dict(repo.get_card(1011).to_dict()),
				Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
		r88_foe.health = maxi(1, r88_foe.health - 3)
		engine.state.set_field(CardData.from_dict(
				repo.get_card(GameEngine.REPAIR_BAY_ID).to_dict()),
				Vector2i(0, 1), GameEngine.SIDE_SELF)
		engine.state.reset_units(GameEngine.SIDE_SELF)
		status_text = "R88：维修间 / 改造工厂（冷青静止描边）= 持续型场地，" + \
			"只对**自己人**生效；改造工厂每回合 +1 力 / +1 血（可无限叠）" + \
			"（敌方后排那只敌人站在维修间上不受益）"
		_shot_t0 = _now()
		queue_redraw()
	if "--surplus" in args and engine != null:
		# 演示（2026-10-03，R55）：活力转移（9110）+ 地狱猫（8019）+ 鲜血堡垒（8020）。
		#   三张都读「自己回合结束时的剩余费用」：本回合留 3 点费用 →
		#   地狱猫 +3 力 +6 生、鲜血堡垒 +3 力 +9 生；活力转移 3/2 = 结转 1 点费用，
		#   结束本回合后进入下个我方回合，能量栏可见 5+1=6（飘字提示）。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.effects.append(CardData.from_dict(
				repo.get_card(GameEngine.VITALITY_ID).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(GameEngine.HELL_CAT_ID).to_dict()),
				Vector2i(4, 2), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(GameEngine.BLOOD_FORT_ID).to_dict()),
				Vector2i(5, 1), GameEngine.SIDE_SELF)
		engine.state.energy = 3          # 故意留 3 点不花
		engine.end_turn()               # 我方回合结束 → 结算剩余费用（成长 + 结转）
		engine.end_turn()               # 敌方空回合结束 → 回到我方回合，发放结转的费用
		_demo_hover_idx = -1
		_hover_hand = -1
		status_text = "剩余费用 3 → 地狱猫 +3力+6生、鲜血堡垒 +3力+9生；活力转移结转 1（%d/2）→ 下回合费用 5+1" \
				% GameEngine.VITALITY_COST
		_shot_t0 = _now()
		queue_redraw()
	if "--blade" in args and engine != null:
		# 演示（2026-10-03，R56）：黑暗领主 8021 + 暗影之刃 9111 + 暗影锁链 9112。
		#   ① 打出黑暗领主（4 费）→ 本回合只剩 1 点；回合结束时它**优先结算** +5 → 6 点，
		#      这 6 点被剩余费用类效果一起读到（地狱猫 +6力+12生、活力转移结转 3）；
		#   ② 暗影之刃：X = 本回合**已花掉**的 4 点 → 随机敌人受 4 伤；
		#   ③ 暗影锁链：6/3 = 2 次击退，每次把随机敌人往后推 2 格。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.energy = 5
		engine.state.effects.append(CardData.from_dict(
				repo.get_card(GameEngine.DARK_BLADE_ID).to_dict()))
		engine.state.effects.append(CardData.from_dict(
				repo.get_card(GameEngine.DARK_CHAIN_ID).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(8019).to_dict()),
				Vector2i(4, 2), GameEngine.SIDE_SELF)   # 地狱猫：看它吃到 +6
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.DARK_LORD_ID).to_dict()))
		var r56_foe := engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		r56_foe.health = 40
		engine.play_from_hand(0, Vector2i(4, 1))   # 黑暗领主上场（花掉 4 费 → 剩 1）
		engine.end_turn()                        # 结算：+5 优先 → 1+5=6，其余读 6 点
		engine.end_turn()                        # 敌方空过 → 回我方回合，看结转与飘字
		_demo_hover_idx = -1
		_hover_hand = -1
		status_text = "黑暗领主回合结束 +5（优先结算）→ 剩余费用 6：地狱猫 +6力+12生、活力转移结转 3、暗影锁链 2 次击退；暗影之刃按已花 4 费打 4 伤"
		_shot_t0 = _now()
		queue_redraw()
	if "--abyss" in args and engine != null:
		# 演示（2026-10-03，R57）：地狱咏唱者 8022 + 黑暗祭坛 8023 + 黑暗扩散 9113 + 无尽黑暗 9114。
		#   ① 地狱咏唱者（1/11 程2）与黑暗祭坛（1/15 程1）各攻击一次 → 每次攻击 +1 费用；
		#   ② 留 3 点费用结束回合 → 黑暗扩散：3 × 2 = 对两个敌人各 6 伤；
		#   ③ 进入下个回合：无尽黑暗**弹面板让玩家选 1 张手牌弃掉**（R70），
		#      选完才给费用 +2 —— 所以这帧看到的是弃牌面板（费用还是 5）。
		#      要看费用到账的样子，演示里再点面板上的一张即可。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.energy = 5
		engine.state.effects.append(CardData.from_dict(
				repo.get_card(GameEngine.DARK_SPREAD_ID).to_dict()))
		engine.state.effects.append(CardData.from_dict(
				repo.get_card(GameEngine.ENDLESS_DARK_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.CHANTER_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(8023).to_dict()))
		var r57_f1 := engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_OPPONENT)
		var r57_f2 := engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
		r57_f1.health = 40
		r57_f2.health = 40
		engine.play_from_hand(0, Vector2i(4, 0))     # 地狱咏唱者 (4,0)
		engine.play_from_hand(0, Vector2i(4, 1))     # 黑暗祭坛 (4,1)
		# 两者各攻击一次（程2 / 程1 都够得着 (3,0)）→ 各 +1 费用
		engine.attack(Vector2i(4, 0), Vector2i(3, 0), GameEngine.SIDE_SELF)
		engine.attack(Vector2i(4, 1), Vector2i(3, 1), GameEngine.SIDE_SELF)
		engine.state.energy = 3                      # 留 3 点不花
		engine.end_turn()                            # 黑暗扩散：3×2=6，敌人各挨 6
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "咏唱者/祭坛攻击各 +1 费；黑暗扩散 3×2=6 伤打到两个敌人（40→34）；无尽黑暗弹出弃牌面板"
		_shot_t0 = _now()
		queue_redraw()
	if "--demon" in args and engine != null:
		# 演示（2026-10-04，R63）：契约签订者 8024 + 恶魔鸭 9116 + 恶魔使魔 9117。
		#   ① 打出契约签订者（3 费）→ 回 4 费（本回合共 6 点）+ 本回合手卡全体涨价 4；
		#   ② 打出第二张契约签订者 → 看涨价**叠加**在费用之外（费用已回满再打一次）；
		#   ③ 我方 8 攻单位打恶魔鸭一下 → 沉睡 -1（100 → 92，还差 1 下才醒）；
		#   ④ 再打一下 → 完全醒来；此后再打 → 每挨一下力量永久 +1（5 → 6 → 7）。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.effects.clear()
		engine.state.board.clear()
		engine.state.energy = 5
		engine.enable_enemy_effects([CardData.from_dict(repo.get_card(9117).to_dict())])
		var dm_demo := engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.DEMON_DUCK_ID).to_dict()),
				Vector2i(0, 1), GameEngine.SIDE_OPPONENT)   # 恶魔鸭：敌方后排中央
		var dm_fam := engine.state.place(
				CardData.from_dict(repo.get_card(GameEngine.FAMILIAR_DUCK_ID).to_dict()),
				Vector2i(2, 0), GameEngine.SIDE_OPPONENT)   # 使魔鸭子：吃恶魔使魔的成长
		var dm_hero := engine.state.place(CardData.from_dict(repo.get_card(8007).to_dict()),
				Vector2i(3, 0), GameEngine.SIDE_SELF)          # 影魔 5 攻：够得着后排恶魔鸭
		engine.state.hand.append(CardData.from_dict(
				repo.get_card(GameEngine.CONTRACTOR_ID).to_dict()))
		engine.state.hand.append(CardData.from_dict(repo.get_card(8002).to_dict()))
		engine.play_from_hand(0, Vector2i(3, 1))            # 契约签订者上场
		_demo_hover_idx = 0
		_hover_hand = 0
		_hover_card = engine.state.hand[0]                  # 悬停手牌看涨价后的费用
		engine.attack(Vector2i(3, 0), Vector2i(0, 1), GameEngine.SIDE_SELF)
		status_text = "契约签订者：花 3 回 4（费用 %d）+ 本回合手卡涨价 4；影魔打恶魔鸭 → 提前醒来（%d/%d）" \
				% [engine.state.energy, maxi(0, dm_demo.health), dm_demo.card.health]
		_shot_t0 = _now()
		queue_redraw()
	if "--mapview" in args and engine != null:
		# 演示（R64）：战斗内地图总览面板 —— 打开并把视野对准当前位置。
		_toggle_map()
		_demo_hover_idx = -1
		_hover_hand = -1
		status_text = "战斗内地图总览：金色双环＝当前位置，绿环＝下一步可走，顶部写本层 Boss 名"
		_shot_t0 = _now()
		queue_redraw()
	if "--guard" in args and engine != null:
		# 演示（2026-10-01）：「替己方 HP 承伤」的三种卡必须**同一特效** ——
		#   森林守护盟友（9037）/ 铁栅栏（9072）/ 以太守卫（9067）各画一圈绿环，
		#   普通盟友（8003 农民）不画。判定走 engine.absorbs_for_hp()，与结算同源。
		engine.state.energy = 5
		engine.state.place(repo.get_card(8003), Vector2i(4, 2), GameEngine.SIDE_SELF)
		engine._forest_guard(GameEngine.SIDE_SELF, Vector2i(4, 2))
		engine.state.place(CardData.from_dict(repo.get_card(9072).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(9067).to_dict()),
				Vector2i(5, 1), GameEngine.SIDE_SELF)
		engine.state.place(repo.get_card(8003), Vector2i(5, 0), GameEngine.SIDE_SELF)
		status_text = "替 HP 承伤统一特效：森林守护 / 铁栅栏 / 以太守卫 都画绿环，普通农民不画"
		_shot_t0 = _now()
		queue_redraw()
	if "--lion" in args and engine != null:
		# 演示：狮子（9038，2026-09-30）—— ① 自己弃牌区每有一个盟友费用 -1（手牌费用圆显绿）
		#   ② 使用时自己场上其他盟友攻击 +2（不含狮子自己）
		for i in 3:
			engine.state.discard.append(repo.get_card(8003))   # 弃牌区 3 个盟友 → 费用 4-3 = 1
		engine.state.discard.append(repo.get_card(8002))       # 技能牌不计入减费
		engine.state.energy = 5
		engine.state.place(repo.get_card(8003), Vector2i(4, 0), GameEngine.SIDE_SELF)  # 农民（盟友）3 攻
		engine.state.place(repo.get_card(8003), Vector2i(4, 2), GameEngine.SIDE_SELF)  # 农民（盟友）3 攻
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.LION_ID))
		engine.state.hand.append(repo.get_card(GameEngine.LION_ID))
		engine.play_from_hand(0, Vector2i(3, 1))   # 打出一只：场上两个盟友 3 → 5 攻
		_hover_hand = 0
		_hover_card = engine.state.hand[0]         # 手里另一只 → 绿色费用「1」（原 4）
		status_text = "狮子：弃牌区 3 盟友 → 费用 4→1（绿色）；使用时场上盟友攻击 +2（3→5），自己保持 6"
		_shot_t0 = _now()
		queue_redraw()
	if "--crow" in args and engine != null:
		# 演示：乌鸦（9039，2026-09-30）—— 使用后必须从弃牌堆选一张盟友回到手牌（弹出选择面板）
		engine.state.energy = 5
		engine.state.place(repo.get_card(8003), Vector2i(4, 0), GameEngine.SIDE_SELF)
		for cid in [8003, 9031, 9032, 9033]:
			engine.state.discard.append(repo.get_card(cid))   # 4 个盟友 → 都会出现在面板里
		engine.state.discard.append(repo.get_card(8002))       # 攻击（技能）→ 不应出现在面板里
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.CROW_ID))
		engine.play_from_hand(0, Vector2i(4, 1))               # 打乌鸦 → 进入待选，弹面板
		_hover_card = null
		status_text = "乌鸦：使用后从弃牌堆选一张盟友回到手牌（面板只列盟友，必须选一张）"
		_shot_t0 = _now()
		queue_redraw()
	if "--hound" in args and engine != null:
		# 演示：猎犬（9040）+ 快速出击（9041）——
		#   ① 猎犬上场快照：场上 2 个其他盟友 → +4 力量（3 → 7）
		#   ② 快速出击：本回合手牌中的盟友费用 -1（手牌费用圆显绿）
		engine.state.energy = 5
		engine.state.place(repo.get_card(8003), Vector2i(4, 0), GameEngine.SIDE_SELF)
		engine.state.place(repo.get_card(8003), Vector2i(4, 2), GameEngine.SIDE_SELF)
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.QUICK_STRIKE_ID))
		engine.state.hand.append(repo.get_card(GameEngine.HOUND_ID))
		engine.state.hand.append(repo.get_card(8003))
		engine.use_spell(0)                                    # 快速出击：本回合盟友 -1
		engine.play_from_hand(0, Vector2i(4, 1))               # 打猎犬：3 → 7 力量（+4 快照）
		_hover_hand = 0
		_hover_card = engine.state.hand[0]                     # 手里的农民 → 绿色费用「2」（原 3）
		status_text = "猎犬：上场时 2 个其他盟友 → +4 力量（3→7）；快速出击：手牌盟友费用 -1（绿色）"
		_shot_t0 = _now()
		queue_redraw()
	if "--overflows" in args and engine != null:
		# 演示（2026-09-30）：效果/道具「过多」时的显示兜底 ——
		#   我方效果 7 张（同名合并后 6 种，可见 4）→ 末位改画「+N」摘要；
		#   敌方效果 5 张（合并后 4 种，可见 3）；道具 8 个（可见 6）。
		#   同名卡合并显示、左下角 ×N 张数角标（2026-10-01 用户要求）。
		#   配合 --relicpanel / --effectpanel 打开浏览面板（装不下时的查看入口）。
		engine.state.effects.clear()
		for eo_id in [9056, 9057, 9057, 9002, 9045, 9036, 9024]:
			var eo_c := repo.get_card(eo_id)
			if eo_c != null:
				engine.state.effects.append(eo_c)
		engine.state.enemy_effects.clear()
		for eo_eid in [9013, 9015, 9024, 9049, 9013]:
			var eo_e := repo.get_card(eo_eid)
			if eo_e != null:
				engine.state.enemy_effects.append(eo_e)
		engine.self_relics = [6001, 6002, 6003, 6005, 6006, 6007, 6008, 6010]
		if "--relicpanel" in args:
			_relics_visible = true
		if "--effectpanel" in args:
			_effects_visible = true
			# 顺带验证面板悬停链路：模拟鼠标悬停在面板第 2 张卡上 → 左侧信息栏显示明细
			var zl := _zone_panel_layout(_zone_panel_cards().size())
			_on_hover(_zone_card_rect(1, zl).get_center())
		status_text = "效果 %d 张（合并 %d 种）/ 敌方效果 %d 张（合并 %d 种）/ 道具 %d 个——点区域查看全部" % [
				engine.state.effects.size(), _merged_effects(engine.state.effects).size(),
				engine.state.enemy_effects.size(), _merged_effects(engine.state.enemy_effects).size(),
				engine.self_relics.size()]
		_shot_t0 = _now()
		queue_redraw()
	if "--stoneskin" in args and engine != null:
		# 演示（2026-09-30）：效果区卡面的「剩余次数」角标（石肤 9066 还剩几次挡刀）
		engine.state.effects.clear()
		for sk_id in [9066, 9002, 9063, 9064]:
			var sk_c := repo.get_card(sk_id)
			if sk_c != null:
				engine.state.effects.append(sk_c)
		engine._stoneskin_left = 3
		status_text = "石肤：效果区卡面右下角显示剩余次数（当前剩 3 次，可叠加、跨回合保留）"
		_shot_t0 = _now()
		queue_redraw()
	if "--taunt" in args and engine != null:
		# 演示（2026-10-01）：嘲讽单位的橙色脉冲光环 + 顶部「嘲讽」徽标
		var taunt_cells := [Vector2i(2, 0), Vector2i(2, 2)]
		var taunt_ids := [1011, 1055]
		for ti in taunt_ids.size():
			var tc := repo.get_card(taunt_ids[ti])
			if tc != null:
				engine.state.place(tc, taunt_cells[ti], GameEngine.SIDE_OPPONENT)
		status_text = "嘲讽：带嘲讽的单位有橙色脉冲光环 + 嘲讽徽标（敌方必须先打它）"
		_shot_t0 = _now()
		queue_redraw()
	if "--whale" in args and engine != null:
		# 演示：鲸鱼之怒（9050）—— 打出后弹出「从弃牌堆取 2 张」面板（可选、可跳过）
		engine.state.energy = 5
		engine.state.place(repo.get_card(9001), Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
		for cid in [8003, 9031, 9032, 9033, 8002]:
			engine.state.discard.append(repo.get_card(cid))   # 弃牌堆 5 张：面板里任意卡都能取
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(GameEngine.WHALE_WRATH_ID))
		engine.use_spell(0, Vector2i(0, 1))                    # 打鲸鱼之怒 → 进入取牌待选
		_hover_card = null
		status_text = "鲸鱼之怒：造成 11 伤 → 从弃牌堆取 2 张卡加入手卡（可选、可跳过）"
		_shot_t0 = _now()
		queue_redraw()
	if "--deckpanel" in args and engine != null:
		# 演示（2026-10-01）：卡组（抽牌堆）浏览面板 —— 相同卡合并、不显示抽牌顺序
		_deck_visible = true
		status_text = "卡组：点开浏览（相同卡合并 ×N，按费用排序，不显示抽牌顺序）"
		_shot_t0 = _now()
		queue_redraw()
	if "--fence" in args and engine != null:
		# 演示（2026-10-01）：道具「栅栏修复术」（6021）——栅栏可以打在已有栅栏的格子上。
		# 橙色「叠」格 = 与已有栅栏合并（生命 + 特性叠加）；绿色格 = 普通放置。
		RunState.relics = [6021]
		load_level(GameLevels.builtin_levels()[0])
		engine.self_relics = [6021]
		engine.state.hand.clear()
		for _k in 3:
			engine.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
		engine.state.energy = 5
		var f_whole := CardData.from_dict(repo.get_card(8001).to_dict())
		var f_hurt := CardData.from_dict(repo.get_card(8001).to_dict())
		engine.state.place(f_whole, Vector2i(4, 0), GameEngine.SIDE_SELF)
		var f_pl := engine.state.place(f_hurt, Vector2i(4, 1), GameEngine.SIDE_SELF)
		f_pl.health = 4        # 半血（4/6）→ 叠一张后是 10/12
		selection = ["hand", 0]
		_hover_card = engine.state.hand[0]
		status_text = "栅栏修复术：橙格「叠」= 与已有栅栏合并（生命+特性叠加）；绿格 = 普通放置"
		_shot_t0 = _now()
		queue_redraw()
	if "--relictip" in args and engine != null:
		# 演示（2026-10-01）：道具悬停浮动说明面板 —— 长描述折行，不再溢出工具栏
		RunState.relics = [6013]
		load_level(GameLevels.builtin_levels()[0])
		engine.self_relics = [6013]
		var rel := RelicRepo.load_json().get_relic(6013)
		_demo_tip_text = "「%s」（%s）%s\n当前复活概率 100%%。" % [rel.relic_name,
				rel.source_label(), rel.desc]
		_hover_relic_tip = _demo_tip_text
		Input.warp_mouse(_relic_rect(0).get_center())  # 真窗口下把鼠标挪到徽章上，走真实悬停路径
		_shot_t0 = _now()
		queue_redraw()
	if "--newspells" in args and engine != null:
		# 演示（2026-10-01，第 37 轮）：6 张新卡一起上手 ——
		# 魔法塔 9075 / 魔力核心 9076 / 陨石术 9077 / 复活术 9078 / 魔像术 9079 / 魔法学徒 9081。
		# 悬停最长的陨石术 → 左栏信息面板核验长文案折行；场上摆一座魔法塔 + 一个召唤出的魔像。
		engine.state.hand.clear()
		for _nid in [9075, 9076, 9077, 9078, 9079, 9081]:
			engine.state.hand.append(repo.get_card(_nid))
		engine.state.energy = 9
		engine.state.place(repo.get_card(9075), Vector2i(5, 0), GameEngine.SIDE_SELF)
		engine._golem_spell(GameEngine.SIDE_SELF, Vector2i(4, 1))
		_demo_hover_idx = 2
		status_text = "第 37 轮新卡：魔法塔 / 魔力核心 / 陨石术 / 复活术 / 魔像术 / 魔法学徒"
		_shot_t0 = _now()
		queue_redraw()
	if "--voidlord" in args and engine != null:
		# 演示（2026-10-01，第 38 轮）：虚空主宰（9082）——
		# 手卡里的本卡：本次对战已用技能对敌造成 3 次伤害 → 10 - 6 = 4 费；
		# 场上已有一座 → 手卡里的技能牌费用 -1（陨石术 10 → 9、魔像术 4 → 3）。
		engine.state.hand.clear()
		engine.state.energy = 30
		engine.state.void_dmg_spells = 3
		engine.state.hand.append(CardData.from_dict(repo.get_card(9082).to_dict()))
		for _vid in [9077, 9007, 9079]:
			engine.state.hand.append(CardData.from_dict(repo.get_card(_vid).to_dict()))
		engine.state.place(CardData.from_dict(repo.get_card(9082).to_dict()),
				Vector2i(5, 0), GameEngine.SIDE_SELF)
		_hover_card = engine.state.hand[0]
		_hover_hand = 0   # 让左栏信息面板走 cost_of（显示当前实际费用，低于卡面标绿）
		status_text = "虚空主宰：场上 1 张 → 技能牌 -1 费；已对敌伤害 3 次 → 本卡 10-6 = 4 费"
		_shot_t0 = _now()
		queue_redraw()
	if "--revive" in args and engine != null:
		# 演示（2026-10-01，第 37 轮）：复活术（9078）——打出后弹出「从弃牌区取一张盟友」面板。
		engine.state.energy = 5
		for _rid in [8003, 9031, 9032, 9033, 8002]:
			engine.state.discard.append(repo.get_card(_rid))
		engine.state.hand.clear()
		engine.state.hand.append(repo.get_card(9078))
		engine.use_spell(0)
		_hover_card = null
		status_text = "复活术：从弃牌区选择一张盟友回到手卡（必须选一张）"
		_shot_t0 = _now()
		queue_redraw()
	if NetSession.active:
		_setup_net()   # 联机已停用：NetSession.active 恒为 false（大厅已移除）


# R77：鸭语耳环（6015）逐张自动出牌的播放状态。
# 原来自动出牌在引擎的 _begin_turn 里一次跑完，玩家完全看不到过程。
var _earring_at := 0            # 上一次出牌的时刻（_now）
var _earring_i := 0             # 已播到第几张
var _earring_gap := 620         # 每张之间的停顿（ms）—— 严格按动画节奏走，不赶
var _earring_done := false      # 播完了（用来撤掉提示 / 解锁操作）
var _shot_pending := false
var _demo_pending := false
var _demo_args: Array = []      # -- 后的用户参数（demo 分支判断用）
var _demo_frame := 0
var _shot_frame := 150
var _shot_ms := 0               # --shotms：距演示动作的毫秒数（比帧号稳定）
var _shot_t0 := 0               # 演示动作起始时刻（_now）


func _demo_tick() -> void:
	_demo_frame += 1
	if _shot_pending and "--fan" in _demo_args and not engine.state.hand.is_empty():
		# 截图窗口打开时系统鼠标会触发一次真实 _on_hover，把 _ready 里设置的
		# 悬停清掉 → 截图期间每帧重新钉住（验证「抬手 + 左栏详情面板」用）
		_hover_hand = engine.state.hand.size() / 2
		_hover_card = engine.state.hand[_hover_hand]
	if _shot_pending and ("--newcards" in _demo_args or "--lion" in _demo_args or "--hound" in _demo_args) and not engine.state.hand.is_empty():
		# 同上：钉住 0 号手牌的悬停，让左栏详情显示「费用 N（原 M）」标绿
		_hover_hand = 0
		_hover_card = engine.state.hand[0]
	if _demo_pending and _demo_frame == 20 and _tutorial.is_empty():
		# 演示确定性：手牌里没有寒冰护盾就换进一张（仅新手试炼演示用）
		var has_shield := false
		for c in engine.state.hand:
			if c.id == 7202:
				has_shield = true
				break
		if not has_shield:
			var shields := repo.starter_deck().filter(func(c): return c.id == 7202)
			if not shields.is_empty():
				engine.state.hand[engine.state.hand.size() - 1] = shields[0]
	if _demo_pending and _demo_frame == 30:
		# 演示①：寒冰护盾完整走一遍「选中 → 进入选目标 → 点击目标结算」
		# （第 1 回合费用恰好 2，先放护盾，剑士让给后面的回合）
		for i in engine.state.hand.size():
			if engine.state.hand[i].id == 7202 and engine.can_pay(2) \
					and not engine.state.board.is_empty():
				_clear_selection()
				selection = ["hand", i]
				_use_hand_card(i)
				if spell_pending >= 0 and not spell_targets.is_empty():
					var target: Vector2i = spell_targets[0]
					_on_board_click(target)
					status_text = "演示：寒冰护盾选目标 %s 结算 ✓" % target
				break
		queue_redraw()
	if _demo_pending and _demo_frame == 60 and not engine.state.board.has(Vector2i(4, 1)):
		# 演示②：费用够就上场一名见习剑士，选中它展示高亮
		var idx := -1
		for i in engine.state.hand.size():
			if engine.state.hand[i].id == 7001:
				idx = i
				break
		if idx >= 0 and engine.can_pay_card(engine.state.hand[idx]):
			engine.play_from_hand(idx, Vector2i(4, 1))
			_select_board(Vector2i(4, 1))
			status_text = "演示：见习剑士上场，绿色=移动 红色=攻击 深红=打HP"
		queue_redraw()
	if _demo_frame == 90 and _demo_pending and engine.current_side == GameEngine.SIDE_SELF:
		_on_end_turn()  # 演示：结束回合，让 AI 推进
	if _demo_pending and "--projshot" in _demo_args and _demo_frame == 80:
		# 演示：构造一次攻击捕捉弹体投射（配合 --shotframe 125 截飞行中段）
		engine.state.place(repo.get_card(7001), Vector2i(3, 1), GameEngine.SIDE_SELF)
		engine.state.place(repo.get_card(7001), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		engine.attack(Vector2i(3, 1), Vector2i(2, 1))
		status_text = "演示：弹体投射特效"
		_hover_card = repo.get_card(8002)  # 模拟悬停：验证信息栏渲染
		queue_redraw()
	if "--killshot" in _demo_args and _demo_frame == 80:
		# 演示：构造一次「击杀」，用于验证「先掉血 → 卡牌才消失」的时序
		var atk_card := repo.get_card(8003)   # 农民 力3
		var weak := repo.get_card(1053)       # 骷髅兵 生2
		if atk_card != null and weak != null:
			engine.state.place(atk_card, Vector2i(3, 1), GameEngine.SIDE_SELF)
			engine.state.place(weak, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
			engine.attack(Vector2i(3, 1), Vector2i(2, 1))
			_shot_t0 = _now()
			status_text = "演示：击杀时序（先掉血，再击破）"
			queue_redraw()
	if "--aiattack" in _demo_args and _demo_frame == 70:
		# 演示：敌方「移动 + 攻击」连击 —— 验证动画排队（先滑行到位、再蓄力出手），
		# 而不是像以前那样攻击段被滑行盖住、动作一闪而过。
		for c: Vector2i in engine.state.board.keys():
			engine.state.board.erase(c)
		engine.state.place(repo.get_card(1053), Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
		engine.state.place(repo.get_card(8003), Vector2i(3, 1), GameEngine.SIDE_SELF)
		status_text = "演示：敌方移动+攻击（滑行完再出手）"
		queue_redraw()
	if "--aiattack" in _demo_args and _demo_frame == 90:
		_on_end_turn()          # 交给 AI：它会先推进、再攻击挡路的农民
		_shot_t0 = _now()
	if "--finisher" in _demo_args and _demo_frame == 80 and engine != null:
		# 收尾演示的实际出牌（延到第 80 帧，避开开局「我方回合」横幅盖住飘字）。
		engine.use_spell(0, Vector2i(2, 0))        # 手卡还剩一张 → 4 伤
		engine.use_spell(0, Vector2i(2, 2))        # 只剩它自己 → 15 伤
		_demo_hover_idx = -1
		_hover_hand = -1
		status_text = "收尾（9104）：1 费；手卡还有别的牌时 4 伤（左 51/55），只剩它自己时 15 伤（右 40/55）"
		_shot_t0 = _now()
		queue_redraw()
	if "--bypassshot" in _demo_args and _demo_frame == 60:
		# 演示：摆两格「不拦路」的工事（中路 + 我方后排），
		# 看 AI 是绕过去直击 HP（而不是像以前那样见工事就拆）。
		_log_visible = true
		log_btn.text = "记录*"
		engine.state.place(repo.get_card(8001), Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(repo.get_card(8001), Vector2i(5, 0), GameEngine.SIDE_SELF)
		status_text = "演示：工事不拦路 → AI 应当绕行直击 HP"
		queue_redraw()
	if "--bypassshot" in _demo_args and _demo_frame == 80:
		_on_end_turn()          # 交给 AI 行动，让它自己选路线
		_shot_t0 = _now()
	var shot_due := _shot_pending and _demo_frame == _shot_frame
	if _shot_pending and _shot_t0 > 0 and _now() - _shot_t0 >= _shot_ms \
			and "--shotms" in _demo_args:
		shot_due = true   # 按「距击杀动作的毫秒数」触发，比帧号稳定
	if shot_due:
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://screenshot.png"))
		get_tree().quit()


func _load_entry_level() -> void:
	## 进入战斗场景时的**首次开局**（原来叫 _restart，是「重开一局」按钮的处理函数；
	## R64 那个按钮没做用已删除，这里只保留开局装载的职责，名字改成不含「重开」）。
	if RunState.run_active:
		# 地图流程：进战斗前由 map_scene 设置 pending_level
		if not RunState.pending_level.is_empty():
			var lvl := RunState.pending_level
			RunState.pending_level = {}
			load_level(lvl)
		else:
			load_level(GameLevels.builtin_levels()[0])
		return
	load_level(GameLevels.builtin_levels()[0])  # 默认：怪物遭遇战


# ------------------------------------------------------------ 联机模式

func _setup_net() -> void:
	## 联机开局（对应 Python 版 NetFieldWindow）：双方各跑一份镜像引擎，
	## 我方动作发出去、对方动作收进来按 450ms 间隔回放。
	_net_mode = true
	level_btn.disabled = true
	var deck: Array[CardData] = repo.starter_deck()
	var state := FieldState.new(deck, 20, 20, -1, "联机对战", true)
	engine = GameEngine.new(state)
	engine.ai_enabled = false
	engine.action.connect(_on_engine_action)
	engine.start_game(5, NetSession.opp_deck_size, NetSession.i_start)
	_clear_selection()
	_slides.clear()
	_attacks.clear()
	_delayed.clear()
	_ghosts.clear()
	_dying.clear()
	_floaters.clear()
	_flashes.clear()
	_bursts.clear()
	_hp_pending.clear()
	_shake_until = 0
	_hover_card = null
	_hover_pl = null
	_cur_level = {}
	_tutorial = []
	tutorial_step = 0
	_tutorial_finished = true
	_tut_update_bar()
	_over_panel.visible = false
	_over_shown = false
	_confetti.clear()
	status_text = "联机对局 vs %s —— %s" % [NetSession.opp_name,
			"你先手，请行动" if NetSession.i_start else "等待对方行动…"]
	if NetSession.i_start:
		_show_banner("我方回合 · 第 1 回合")
	else:
		_show_banner("%s 行动中" % NetSession.opp_name, Color("8a2b2b"))
	queue_redraw()


func _net_locked() -> bool:
	## 联机时锁操作：对方回合 / 回放中。
	return _net_mode and (engine.current_side != GameEngine.SIDE_SELF or _net_replaying)


func _net_send(msg: Dictionary) -> void:
	## 发消息给对方（非联机模式是空操作）；失败按断线处理。
	if not _net_mode:
		return
	var link = NetSession.link
	if link == null or not link.send(msg):
		_net_disconnect()


func _net_poll(delta: float) -> void:
	## 每帧：收信 → 回放队列逐条出（间隔 NET_GAP）。
	var link = NetSession.link
	if link != null:
		link.poll()
		if link.drain_into(_net_queue):
			_net_disconnect()
			return
	if _net_replaying:
		_net_wait -= delta
		if _net_wait <= 0.0:
			_net_replaying = false
	if engine.over or _net_replaying or _net_queue.is_empty():
		return
	var msg: Dictionary = _net_queue.pop_front()
	_clear_selection()
	_apply_net_msg(msg)
	_net_replaying = true
	_net_wait = Net.NET_GAP_MS / 1000.0
	queue_redraw()


func _apply_net_msg(msg: Dictionary) -> void:
	## 对方一条消息在本机引擎上重放（镜像引擎，动作信号自动带动画/音效）。
	var t := str(msg.get("type"))
	if t == "bye":
		NetSession.opp_left = true
		return
	if engine.over or t != "action":
		return
	var args: Array = msg.get("args", []) if msg.has("args") else []
	match str(msg.get("act")):
		"play":
			engine.remote_play(CardData.from_dict(msg["card"]), _net_vec(msg["cell"]))
		"spell":
			engine.remote_spell(CardData.from_dict(msg["card"]),
					_net_cell_or_null(msg.get("target")))
		"move":
			engine.move(_net_vec(args[0]), _net_vec(args[1]), GameEngine.SIDE_OPPONENT)
		"attack":
			engine.attack(_net_vec(args[0]), _net_vec(args[1]), GameEngine.SIDE_OPPONENT)
		"hp":
			engine.attack_hp(_net_vec(args[0]), _net_vec(args[1]), GameEngine.SIDE_OPPONENT)
		"pass":
			# 对方移动后放弃攻击 → 镜像横置
			engine.pass_attack(_net_vec(args[0]), GameEngine.SIDE_OPPONENT)
		"activate":
			# 对方主动发动（熊 8004「回春」）
			engine.activate(_net_vec(args[0]), GameEngine.SIDE_OPPONENT)


func _net_vec(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


func _net_cell_or_null(v) -> Variant:
	if v is Array and v.size() == 2:
		return _net_vec(v)
	return null


func _net_disconnect() -> void:
	## 对方断线 / 离开：提示后 2 秒回标题。
	if NetSession.opp_left:
		return
	status_text = "对方已离开对局或连接断开"
	NetSession.opp_left = true
	NetSession.clear()   # 关闭连接
	queue_redraw()
	var t := Timer.new()
	t.wait_time = 2.0
	t.one_shot = true
	t.timeout.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	add_child(t)
	t.start()


func _on_back_to_title() -> void:
	_ai_timer.stop()
	if ReplayLog.recording:
		ReplayLog.finish("quit")   # 中途放弃：已录内容照常保存
	ReplayLog.stop_playback()
	if RunState.run_active:
		RunState.end_run()   # 战斗中退出 = 放弃本局（回标题重新开始）
	if _net_mode:
		_net_send({"type": "bye"})
	NetSession.clear()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func load_level(lvl: Dictionary) -> void:
	## 按关卡配置开局（对应 Python 版 Level.build_engine）。
	repo = CardRepo.load_json()
	# 肉鸽 run：用当前卡组（初始 + 奖励卡）；单关/演示模式用关卡默认卡组
	var deck: Array[CardData] = RunState.build_deck(repo) \
			if RunState.run_active and not RunState.deck_ids.is_empty() \
			else GameLevels.deck_for(str(lvl["deck_key"]), repo)
	# 玩家生命来自肉鸽 run 状态（最大/当前，跨战斗保留）；关卡里的 player_hp 仅作兜底
	var p_hp: int = RunState.hp if RunState.hp > 0 else int(lvl["player_hp"])
	# 道具「烤肉」（6011）：进入 Boss 战时自动消耗 → 回复 25% 最大生命。
	# 必须在创建战斗状态之前结算，这样开局血量就是回复后的值。
	# -1 = 本次未消耗（非 Boss 战 / 没带烤肉）；>= 0 = 已消耗，值为实际回复量。
	var bbq_heal := -1
	if int(lvl.get("tier", -1)) == GameLevels.TIER_BOSS:
		bbq_heal = RunState.consume_barbecue()
		if bbq_heal >= 0:
			p_hp = RunState.hp
	# R46 录像：战斗种子 = 本局随机链（run_rng）的下一环；回放时改用录像里记下的
	# 种子（run_rng 照常消耗一次，保证后续掉落/摇卡链条与录制时一致）。
	var battle_seed: int = RunState.run_rng.randi() if RunState.run_active else 0
	if RunState.run_active and ReplayLog.playing:
		var bb := ReplayLog.take("battle_begin")
		if not bb.is_empty() and bb.has("seed"):
			battle_seed = int(bb["seed"])
	var brng := RandomNumberGenerator.new()
	brng.seed = battle_seed
	var state := FieldState.new(
			deck, p_hp, GameLevels.enemy_hp_of(lvl),
			int(lvl["turn_limit"]), str(lvl["name"]), bool(lvl["shuffle"]), brng)
	state.max_hp_self = RunState.max_hp   # 上限独立于当前值（休息事件可回复）
	engine = GameEngine.new(state)
	if RunState.run_active:
		engine.rng.seed = battle_seed   # 战斗内全部随机（含 AI）可复现
		if ReplayLog.recording:
			ReplayLog.ev("battle_begin", {"seed": battle_seed,
					"level": str(lvl.get("name", "?")),
					"tier": int(lvl.get("tier", -1)),
					"node_type": str(RunState.pending_node.get("type", ""))})
	engine.ai_enabled = bool(lvl["enemy_ai"])
	engine.self_relics = RunState.relics   # 道具（鸡煲等战斗内效果由引擎结算）
	# R77：鸭语耳环（6015）改成**逐张**自动出牌 —— 由 _tick_earring_autoplay 每帧推进一步，
	# 这样每张牌的抽牌 / 出牌 / 落位动画都能看清。录像回放保持 false（回放按固定节奏走）。
	engine.autoplay_stepwise = not ReplayLog.playing
	engine.duck_revive_chance = RunState.duck_revive_chance   # 叠加态的鸭：复活概率跨战斗保留
	engine.action.connect(_on_engine_action)
	for e: Array in lvl["enemy_units"]:
		var card := CardData.new()
		var from_repo := repo.get_card(int(e[0]))
		if from_repo != null:
			card = from_repo  # 卡牌库里有定义（如鸭子骑士）：直接用，保证数据同源
		else:
			card.id = int(e[0])
			card.card_name = str(e[1])
			card.kind = "盟友"
			card.cost = 1
			card.power = int(e[2])
			card.health = int(e[3])
			card.attack_range = int(e[4])
			card.move_speed = int(e[5])
		engine.state.place(card, e[6], GameEngine.SIDE_OPPONENT)
	# 关卡成长曲线（二层「低开高走」）：开局削攻击力、之后随回合回升。
	# 必须在敌方单位摆好之后调用（它要按每张卡的基础攻击力算开局修正）。
	engine.configure_growth(lvl.get("enemy_growth", {}))
	# 关卡有敌方单位 → 消灭所有敌方场上单位即获胜（不依赖打空敌方 HP）
	engine.state.clear_win = not (lvl["enemy_units"] as Array).is_empty()
	# 敌方效果卡：开局即启用（进入敌方效果区，持续生效）
	var enemy_effect_cards: Array[CardData] = []
	for eid in lvl.get("enemy_effects", []):
		var ecard := repo.get_card(int(eid))
		if ecard != null:
			enemy_effect_cards.append(ecard)
	engine.enable_enemy_effects(enemy_effect_cards)
	# 先清掉上一局的显示残留（start_game 会掷出第 1 回合的鸭之低语，
	# 它的飘字/状态必须在 clear 之前进入 —— 否则会被下面这批 clear 抹掉）
	_whisper_txt = ""
	_floaters.clear()
	# 烤肉已消耗：开场飘字（血量在创建战斗状态之前就已回复完毕）
	if bbq_heal >= 0:
		sfx.play("heal")
		_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 14),
				"text": "烤肉 +%d HP" % bbq_heal, "col": Color("e08a2e"),
				"start": _now(), "dur": 2400})
	# 第二层起始道具的开场结算（冰淇淋与汽水 -3 生命 / 生蛋鸭放鸭蛋）：
	# 必须在 start_game 之前 —— 这样开局血量与场上单位的初始状态就是结算后的。
	engine.apply_battle_start_relics(repo)
	engine.start_game(int(lvl["starting_hand"]))
	_clear_selection()
	_slides.clear()
	_attacks.clear()
	_delayed.clear()
	_ghosts.clear()
	_dying.clear()
	# 注意：_floaters 不在这里 clear —— start_game 掷出的第 1 回合
	# 鸭之低语飘字需要在开场后正常展示（clear 已提前到 start_game 之前）。
	_flashes.clear()
	_bursts.clear()
	_hp_pending.clear()
	_shake_until = 0
	_hero_pick_idx = -1          # 换关/重开：待付代价的面板一并收掉
	_hero_pick_sel = []
	_hover_card = null
	_hover_pl = null
	_cur_level = lvl
	_tutorial = lvl["tutorial"]
	tutorial_step = 0
	_tutorial_finished = _tutorial.is_empty()
	_tut_update_bar()
	_over_panel.visible = false
	_over_shown = false
	_confetti.clear()
	var limit: int = int(lvl["turn_limit"])
	map_btn.visible = RunState.run_active and not RunState.map_columns.is_empty()
	level_btn.disabled = RunState.run_active
	if limit > 0:
		status_text = "%s：%d 回合内把敌方 HP（%d）打到 0！" % [
				lvl["name"], limit, GameLevels.enemy_hp_of(lvl)]
	elif not _tutorial.is_empty():
		status_text = "%s：跟着顶部引导条一步步做。" % lvl["name"]
	else:
		var tier_prefix := ""
		if lvl.has("tier"):
			tier_prefix = "【%s】" % GameLevels.tier_name(int(lvl["tier"]))
		status_text = "%s%s 开始！" % [tier_prefix, lvl["name"]]
	if bbq_heal >= 0:
		# 状态栏很窄（310px），只放简短标记；详细提示见开场飘字。
		status_text += "　｜　烤肉 +%d HP" % bbq_heal
	var intro := str(lvl.get("intro", ""))
	if intro != "":
		# 关卡开场台词（如「哈气骑士团」的「我要闹了」）：盖过回合横幅，停留更久
		_show_banner(intro, Color("b8860b"), 2400)
	else:
		_show_banner("我方回合 · 第 1 回合")
	queue_redraw()


# ------------------------------------------------------------ 选中 / 高亮

func _clear_selection() -> void:
	selection = null
	move_targets = []
	attack_targets_arr = []
	hp_targets_arr = []
	spell_pending = -1
	spell_targets = []
	_infiltrate_src = Vector2i(-1, -1)
	# R102：「双向传送」的两段式状态同样在这里收掉 —— 右键取消 / 换牌 / 敌方回合都走它。
	_swap_src = Vector2i(-1, -1)
	# R90：「系统升级」的两段式状态也在这里收掉 —— 它不在棋盘选中体系里，
	# 但换关 / 敌方回合 / 选别的牌时都该自动取消（否则面板会一直挂着）。
	_sys_upgrade_idx = -1


func _select_board(cell: Vector2i) -> void:
	selection = ["board", cell]
	var p := engine.state.unit_at(cell)
	if p != null and p.moved and not p.tapped:
		if p.acts_left > 1:
			# 多动单位：还能再消耗一次行动接着走（横着挪位后再压上去）
			move_targets = engine._reachable(cell, GameEngine.SIDE_SELF)
			status_text = ("%s：已移动。红色=攻击；点绿色再走一格 = 消耗一次行动（放弃这次攻击）"
					% p.card.card_name)
		else:
			move_targets = []  # 已移动过：不能再走，只能攻击或放弃（横置）
			status_text = ("%s：已移动。点红色/深红目标攻击，点其他地方 = 放弃攻击（横置）"
					% p.card.card_name)
	else:
		move_targets = engine._reachable(cell, GameEngine.SIDE_SELF)
	attack_targets_arr = engine.legal_attack_targets(cell)
	# 主动发动（熊 8004「回春」）：可发动时把发动方式写进提示
	if p != null and engine.can_activate(cell, GameEngine.SIDE_SELF):
		status_text = ("%s：绿色=移动 红色=攻击 深红=打HP；再点它一次或按 F = 发动（回复 %d 生命，之后横置）"
				% [p.card.card_name, GameEngine.BEAR_HEAL])
	# 嘲讽：射程内有对方嘲讽单位 → 只能打它，不能直击 HP（隐藏深红 HP 格）
	if engine.taunt_in_range(cell, GameEngine.SIDE_SELF):
		hp_targets_arr = []
	else:
		hp_targets_arr = engine.hp_targets(cell)


func _pass_moved_pending() -> void:
	## 选中的单位若已移动未攻击：任何非攻击操作 = 放弃攻击（横置）。
	if selection != null and selection[0] == "board":
		var src: Vector2i = selection[1]
		var p := engine.state.unit_at(src)
		if p != null and p.owner == GameEngine.SIDE_SELF and p.moved and not p.tapped:
			engine.pass_attack(src, GameEngine.SIDE_SELF)
			if _net_mode:
				_net_send({"type": "action", "act": "pass",
						"args": [[src.x, src.y]]})


# ------------------------------------------------------------ 输入

func _gui_input(event: InputEvent) -> void:
	if engine == null or engine.over or _net_locked() or ReplayLog.playing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 手牌按下：先不触发点击逻辑，等松手判定是点击还是拖拽
			_press_idx = _hand_index_at(event.position)
			_press_pos = event.position
			if _press_idx < 0:
				_on_left_click(event.position)
		else:
			# 松手：拖拽中 → 落点结算；否则按点击处理
			if _drag_idx >= 0:
				_finish_drag(event.position)
			elif _press_idx >= 0:
				_on_left_click(event.position)
			_press_idx = -1
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_UP
					or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		# 地图总览：内容比面板高时用滚轮翻动
		if _map_visible:
			var m_smax := _mapview_scroll_max()
			if m_smax > 0.0:
				_map_scroll = clampf(_map_scroll
						+ (-46.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 46.0),
						0.0, m_smax)
				queue_redraw()
			return
		# 道具浏览面板：内容放不下时用滚轮翻动
		if _relics_visible:
			_relic_scroll += -34.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 34.0
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_on_right_click()
		queue_redraw()
	elif event is InputEventMouseMotion:
		if _press_idx >= 0 and _drag_idx < 0 \
				and event.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_start_drag(_press_idx, event.position)
		if _drag_idx >= 0:
			_drag_pos = event.position
			queue_redraw()
		_on_hover(event.position)


func _hand_index_at(pos: Vector2) -> int:
	## 手牌会互相重叠 → 从**最上层**（画得最晚的那张）往前找。
	for i in range(engine.state.hand.size() - 1, -1, -1):
		if _hand_hit(i, pos):
			return i
	return -1


func _unhandled_key_input(event: InputEvent) -> void:
	## 键盘快捷键：Esc 取消 / E 结束回合 / M 地图 / L 记录面板 / F 主动发动。
	if engine == null or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if ReplayLog.playing:
		# 回放模式：空格切换倍速（1→2→4→8 循环），其余快捷键接管
		if k.keycode == KEY_SPACE:
			ReplayLog.speed = 1.0 if ReplayLog.speed >= 4.0 else ReplayLog.speed * 2.0
			_show_banner("回放倍速 ×%g" % ReplayLog.speed, Color("3f7fbf"))
			queue_redraw()
		return
	match k.keycode:
		KEY_ESCAPE:
			# 地图总览开着时，Esc 只关地图（不动手牌/选中的取消逻辑）
			if _map_visible:
				_map_visible = false
				queue_redraw()
				return
			if not engine.over:
				_on_right_click()
				queue_redraw()
		KEY_E:
			_on_end_turn()
			queue_redraw()
		KEY_M:
			_toggle_map()
		KEY_L:
			_toggle_log()
		KEY_F:
			# 主动发动（熊 8004「回春」）：选中它之后按 F
			if selection != null and selection[0] == "board":
				var fc: Vector2i = selection[1]
				if engine.can_activate(fc, GameEngine.SIDE_SELF):
					engine.activate(fc, GameEngine.SIDE_SELF)
					_clear_selection()
			queue_redraw()


func _hand_cue_rect(i: int) -> Rect2:
	## 引导框用的手牌矩形：卡底沉出窗口时只圈**看得见的部分**（否则框线被裁掉一半）。
	var r := _hand_rect(i)
	return Rect2(r.position, Vector2(r.size.x, minf(r.size.y, WINDOW_H - r.position.y)))


func _hand_step(count: int) -> float:
	## 相邻手牌的横向步进：手牌少时不重叠，多了逐步压到最小步进（重叠最多 55%）。
	if count <= 1:
		return HAND_CARD_W
	return clampf(HAND_FAN_WIDTH / float(count - 1),
			HAND_CARD_W * HAND_FAN_MIN_STEP, HAND_CARD_W)


func _hand_fan_k(i: int) -> float:
	## 第 i 张相对扇心的偏移：-1 = 最左，0 = 中间，+1 = 最右。
	var n := engine.state.hand.size()
	if n <= 1:
		return 0.0
	return (float(i) - float(n - 1) / 2.0) / (float(n - 1) / 2.0)


func _hand_angle(i: int) -> float:
	## 第 i 张的旋转弧度（绕卡牌底部中心）：左负右正，两端不超过 ±HAND_FAN_MAX_DEG。
	var n := engine.state.hand.size()
	if n <= 1:
		return 0.0
	var span := minf(HAND_FAN_MAX_DEG * 2.0, HAND_FAN_DEG_PER * float(n - 1))
	return deg_to_rad(span / 2.0 * _hand_fan_k(i))


func _hand_drop(i: int) -> float:
	## 扇弧：越靠两边越往下沉（两端相对扇心下沉 HAND_FAN_DROP，一起沉进窗口下沿）。
	return HAND_FAN_DROP * _hand_fan_k(i) * _hand_fan_k(i)


func _hand_vis_h(i: int) -> float:
	## 第 i 张**露在屏幕内**的高度（**不含**悬停/选中的视觉抬手）——仅测试断言用，
	## 用来确认「卡沉下去之后还剩多少是看得见的」。卡面绘制**不用**它（整张排版后由视口裁）。
	return WINDOW_H - (OWN_HAND_Y + _hand_drop(i))


func _hand_rect(i: int) -> Rect2:
	## 手牌第 i 张的**未旋转**矩形；命中判定 / 拖拽起点 / 引导框都基于它。
	## 卡底会落在窗口下沿之外（HAND_CROP_BOTTOM）：卡面照整张排版画，多出的那截由视口裁掉。
	var n := engine.state.hand.size()
	var step := _hand_step(n)
	var total: float = step * (n - 1) + HAND_CARD_W
	var x: float = (WINDOW_W - total) / 2 + step * i
	var raised := HAND_SELECT_RAISE \
			if selection != null and selection[0] == "hand" and selection[1] == i else 0.0
	return Rect2(x, OWN_HAND_Y - raised + _hand_drop(i), HAND_CARD_W, HAND_CARD_H)


func _hand_pivot(i: int) -> Vector2:
	## 旋转轴心 = 卡牌底部中心（扇形就是绕这里张开的）。
	## 手牌卡底正好落在窗口下沿，所以轴心几乎贴着屏幕边缘 → 扇形的圆心也在那里。
	var r := _hand_rect(i)
	return Vector2(r.position.x + HAND_CARD_W / 2, r.position.y + HAND_CARD_H)


func _hand_hit(i: int, pos: Vector2) -> bool:
	## 精确命中：把鼠标点**反向旋转**回卡牌本地坐标再判矩形。
	## （卡是转着画的，直接拿轴对齐矩形判会在两端错位；这里用同一条 _hand_angle。）
	## 注意：悬停抬手只影响绘制、不进 _hand_rect，所以不会出现「抬起→不再命中→闪」。
	var pivot := _hand_pivot(i)
	var local := pivot + (pos - pivot).rotated(-_hand_angle(i))
	return Rect2(_hand_rect(i).position, Vector2(HAND_CARD_W, HAND_CARD_H)).has_point(local)


func _cell_at(pos: Vector2) -> Variant:
	var c := int(floor((pos.x - GRID_X) / CELL))
	var r := int(floor((pos.y - GRID_Y) / CELL))
	if r >= 0 and r < FieldState.BOARD_ROWS and c >= 0 and c < FieldState.BOARD_COLS:
		return Vector2i(r, c)
	return null


func _on_left_click(pos: Vector2) -> void:
	# 英雄的弃牌代价面板：开着时只处理面板内的点击（棋盘/手牌一律不响应）
	if _hero_pick_idx >= 0:
		_on_hero_pick_click(pos)
		return
	# 乌鸦的回手面板：必须选一张，开着时只处理面板内的点击
	if engine.crow_pending:
		_on_crow_pick_click(pos)
		return
	# 鲸鱼之怒的取牌面板：可选可跳过（面板底部有「不选了」按钮）
	if engine.whale_pending:
		_on_whale_pick_click(pos)
		return
	# 无尽黑暗 9114（R70）：强制弃 1 张手牌，**不能不选** → 面板开着时只处理面板内点击
	if engine.endless_pending:
		_on_endless_pick_click(pos)
		return
	# 复活术的取牌面板：必须选一张盟友（开着时只处理面板内的点击）
	if engine.revive_pending:
		_on_revive_pick_click(pos)
		return
	# 预判（9097）：二选一面板
	if engine.foresight_mode:
		_on_foresight_mode_click(pos)
		return
	# 预判①：弃牌区选 0 费技能卡（必须选一张）
	if engine.foresight_pick:
		_on_foresight_pick_click(pos)
		return
	# 拒绝命运（9098）：弃牌区选回 N 张（必须选满）
	if engine.fate_pending:
		_on_fate_pick_click(pos)
		return
	# 浏览面板：开着时点任意处关闭
	if _map_visible:
		# 地图总览：纯只读，点任意处关闭（不能在这里改路线）
		_map_visible = false
		queue_redraw()
		return
	if _discard_visible or _effects_visible or _enemy_effects_visible or _relics_visible\
			or _deck_visible:
		_discard_visible = false
		_effects_visible = false
		_enemy_effects_visible = false
		_relics_visible = false
		_deck_visible = false
		_relic_scroll = 0.0
		queue_redraw()
		return
	# 效果区：点击查看全部效果卡（持续生效中）
	var effects_rect := Rect2(COST_X, COST_Y + ENERGY_H, TAP_W + 12, GRID_H - ENERGY_H)
	if effects_rect.has_point(pos) and not engine.state.effects.is_empty():
		_pass_moved_pending()
		_effects_visible = true
		queue_redraw()
		return
	# 敌方效果区：点击查看敌方效果卡（开局启用，持续生效中）
	if _enemy_zone_rect().has_point(pos) and not engine.state.enemy_effects.is_empty():
		_pass_moved_pending()
		_enemy_effects_visible = true
		queue_redraw()
		return
	# 道具栏：悬浮已能逐个看描述；**只有装不下（栏里出现「+N」摘要）时**才允许点开浏览面板
	if _relic_zone_rect().has_point(pos) and _relic_bar_overflowed():
		_pass_moved_pending()
		_relics_visible = true
		_relic_scroll = 0.0
		queue_redraw()
		return
	var discard_rect := Rect2(DISCARD_X, DISCARD_Y, CARD_W, CARD_H)
	if discard_rect.has_point(pos) and not engine.state.discard.is_empty():
		_pass_moved_pending()
		_discard_visible = true
		queue_redraw()
		return
	# 卡组（抽牌堆）：点开浏览 —— 相同卡合并显示张数，不泄露抽牌顺序
	var deck_rect := Rect2(DECK_X, DECK_Y, CARD_W, CARD_H)
	if deck_rect.has_point(pos) and not engine.state.deck.is_empty():
		_pass_moved_pending()
		_deck_visible = true
		queue_redraw()
		return
	# 手牌：必须和悬停/拖拽用同一套判定（卡是转着画的、还会互相重叠），
	# 否则会出现「悬停显示 A、点下去选中 B」。
	var hi := _hand_index_at(pos)
	if hi >= 0:
		# R71：同样只允许我方回合出牌（与 _on_board_click 的门禁成对；否则玩家能在敌方
		# 回合抢先出牌 → `_ai_step` 随后驱动的 AI 队列与实际战场状态对不上）。
		if engine.current_side != GameEngine.SIDE_SELF:
			_say("现在是敌方回合，等对手行动完再出牌")
			return
		_pass_moved_pending()  # 切去选手牌 = 放弃已移动单位的攻击
		# R90「系统升级」第二段：正在等玩家点一张**手牌**时，点哪张就是改造目标。
		# 放在「再点一次 = 使用」之前 —— 否则会先把「系统升级」自己打出去。
		if _sys_upgrade_idx >= 0:
			if hi == _sys_upgrade_idx:
				_sys_upgrade_idx = -1
				_clear_selection()
				status_text = "已取消：系统升级仍在手牌（未扣费）"
				queue_redraw()
				return
			var tgt: CardData = engine.state.hand[hi]
			if tgt.kind != "盟友" and not tgt.is_fort():
				_say("只能改造盟友或工事（%s 是%s）" % [tgt.card_name, tgt.kind])
				return
			var src := _sys_upgrade_idx
			_sys_upgrade_idx = -1
			_clear_selection()
			var su_card: CardData = engine.state.hand[src]
			status_text = "系统升级 → %s" % engine.cast_sys_upgrade(src, hi)
			_net_send({"type": "action", "act": "spell", "card": su_card.to_dict(),
					"target": null})
			queue_redraw()
			return
		if selection != null and selection[0] == "hand" and selection[1] == hi:
			_use_hand_card(hi)  # 再点一次 = 使用
		else:
			_clear_selection()
			selection = ["hand", hi]
			var card := engine.state.hand[hi]
			if card.is_effect():
				status_text = "%s（效果卡）：再点一次启用，放入左侧效果区持续生效" % card.card_name
			elif card.is_spell() and card.needs_target():
				status_text = "%s（技能）：再点一次使用，需点击一个目标" % card.card_name
			elif card.is_spell() and card.x_cost:
				status_text = "%s（技能）：再点一次使用 —— 消耗当前全部能量 %d 点，随机砸 %d 次" % [
						card.card_name, engine.energy_of(), engine.energy_of()]
			elif card.is_spell():
				status_text = "%s（技能）：再点一次使用" % card.card_name
			elif engine.discard_cost_of(card) > 0:
				status_text = "%s：点击自己半场（下 3 行）空格放置 —— 上场需额外丢弃 %d 张手牌" \
						% [card.card_name, engine.discard_cost_of(card)]
			elif not card.is_spell() and not engine.can_pay_card(card):
				_say("能量不足：%s 需要 %d，当前能量 %d" % [
						card.card_name, engine.cost_of(card), engine.energy_of()])
			elif engine.fence_merge_allowed(card):
				status_text = "%s：点绿格放置；点橙色「叠」格 = 与已有栅栏合并；再点一次 = 使用" % card.card_name
			else:
				status_text = "%s：点击自己半场（下 3 行）空格放置；再点一次 = 使用" % card.card_name
		return
	# 棋盘格
	var cell = _cell_at(pos)
	if cell != null:
		_on_board_click(cell)


func _use_hand_card(i: int) -> void:
	var card := engine.state.hand[i]
	if card.is_effect():
		# 效果卡：支付能量 → 进入左侧效果区持续生效
		if not engine.can_pay_card(card):
			_say("能量不足：%s 需要 %d，当前能量 %d" % [card.card_name, engine.cost_of(card), engine.energy_of()])
		else:
			engine.use_effect(i)
			_net_send({"type": "action", "act": "effect", "card": card.to_dict()})
		_clear_selection()
		queue_redraw()
		return
	if not card.is_spell():
		return  # 随从/工事：等待点击棋盘格放置
	if not engine.can_pay_card(card):
		_say("能量不足：%s 需要 %d，当前能量 %d" % [card.card_name, engine.cost_of(card), engine.energy_of()])
		_clear_selection()
		return
	if not engine.can_use_card(card):
		_say("%s：本回合还需先使用 %d 张其他卡（已用 %d）" % [
				card.card_name, GameEngine.WHIRL_BLADE_NEED, engine.state.self_card_plays])
		_clear_selection()
		return
	# 「系统升级」（8039，R90）：目标在**手牌**里，所以**不进 spell_targets**
	# （那套是棋盘格）—— 这里只记下它自己，等玩家再点一张手牌。
	if card.id == GameEngine.SYS_UPGRADE_ID:
		_sys_upgrade_idx = i
		status_text = "系统升级：点手牌里的一个**盟友或工事**（再点一次系统升级取消）"
		return
	if card.needs_target():
		# 需要选目标的技能：进入选目标模式（技能还在手牌，能量未付）
		var targets := _spell_target_cells(card)
		if targets.is_empty():
			if card.id in [8002, 9003]:
				engine.use_spell(i)  # 没有单位可打：伤害直接结算给对方玩家
				_net_send({"type": "action", "act": "spell",
						"card": card.to_dict(), "target": null})
			else:
				_say("没有可指定的目标")
			_clear_selection()
		else:
			spell_pending = i
			spell_targets = targets
			var target_hint := "一个格子" if card.id == 9007 else "一个目标"
			if card.id == GameEngine.FIRE_WALL_SPELL_ID:
				target_hint = "一条横行（点该行任意一格）"
			elif card.id == GameEngine.INFILTRATE_ID:
				target_hint = "一个自己的盟友（之后再点目的格）"
			elif card.id == GameEngine.SWAP_UNITS_ID:
				target_hint = "第一个单位（之后再点第二个单位）"
			elif card.id == GameEngine.DOUBLE_TRAP_ID:
				target_hint = "一个自己的工事"
			elif card.id == GameEngine.UPGRADE_ID:
				target_hint = "**自己的一个盟友或工事**（+2 攻 / +8 血）"
			elif card.id == GameEngine.ARMOR_PLATE_ID:
				target_hint = "**自己的一个盟友**（生命 +4，算一层改造）"
			elif card.id == GameEngine.DEMOLISH_ID:
				target_hint = "**自己的一个盟友或工事**：破坏它、回 3 费、手牌+素体；被改造则额外+升级"
			elif card.id == GameEngine.REORG_ID:
				target_hint = "**自己的一个盟友或工事**：回复至满生命"
			elif card.id == GameEngine.TRANSCEND_ID:
				target_hint = "**自己的一个盟友或工事**（还没超负荷）：挂上超负荷 + 算一层改造"
			elif card.id == GameEngine.REBOOT_ID:
				target_hint = "**自己的一个盟友或工事**：返回手卡（0 费，离手重置）"
			elif card.id == GameEngine.WHIRL_BLADE_ID:
				target_hint = "十字中心格"
			status_text = "%s：点击%s（右键取消）" % [card.card_name, target_hint]
	else:
		engine.use_spell(i)
		_net_send({"type": "action", "act": "spell",
				"card": card.to_dict(), "target": null})
		_clear_selection()
	queue_redraw()


# ------------------------------------------------------------ 拖拽释放

func _start_drag(i: int, pos: Vector2) -> void:
	## 开始拖拽一张手牌：技能/效果卡拖到棋盘释放；随从/工事拖到自己半场空格放置。
	var card := engine.state.hand[i]
	_pass_moved_pending()   # 拖拽 = 放弃已移动单位的攻击
	_clear_selection()
	_drag_idx = i
	_drag_pos = pos
	_drag_place = false
	_drag_place_cells = []
	if not card.is_spell() and not card.is_effect():
		# 随从 / 工事：拖到自己半场（下 3 行）的空格放置；
		# 持「栅栏修复术」且手里是栅栏 → 已有栅栏的格子也可落（叠栅栏，橙色）
		_drag_spell_cells = []
		_drag_anywhere = false
		_drag_place = true
		_drag_place_cells = _own_place_cells(card)
		if not engine.can_pay_card(card):
			status_text = "%s：能量不足（需要 %d，当前 %d）——松手不会生效" % [
					card.card_name, engine.cost_of(card), engine.energy_of()]
		elif engine.fence_merge_allowed(card):
			status_text = "%s：拖到绿色格子放置；拖到橙色「叠」格 = 与已有栅栏合并" % card.card_name
		elif card.has_affix(GameEngine.AFFIX_SWAP):
			status_text = "%s：拖到绿色空格放置；也可拖到己方单位上 → 把它顶回手" % card.card_name
		else:
			status_text = "%s：拖到绿色格子放置（自己半场空格）" % card.card_name
		queue_redraw()
		return
	if card.id == GameEngine.INFILTRATE_ID:
		# R76：潜入是**两段式**技能，拖拽也必须走两段（原来拖拽直接落到 use_spell 的
		# 单段分支，引擎自己挑「第一个空格」= 前排左边，看起来就是卡片自己跑掉了）。
		# 第一段：拖到己方盟友上 → 只记下它，高亮所有可去的空格，等第二次点/拖。
		_drag_spell_cells = _spell_target_cells(card)
		_drag_anywhere = false
		if _drag_spell_cells.is_empty():
			status_text = "潜入：场上没有可移动的己方盟友（已取消）"
			_drag_spell_cells = []
		else:
			status_text = "潜入：拖到一个己方盟友上（第二段再拖到目的格）"
		queue_redraw()
		return
	if card.id == GameEngine.SWAP_UNITS_ID:
		# R102：双向传送同样是**两段式**，拖拽也必须走两段（否则会掉进 use_spell
		# 的单段分支被引擎拒绝，或者自动挑一对自动交换掉）。
		_drag_spell_cells = _spell_target_cells(card)
		_drag_anywhere = false
		if _drag_spell_cells.size() < 2:
			status_text = "双向传送：场上不足两个单位（已取消）"
			_drag_spell_cells = []
		else:
			status_text = "双向传送：拖到第一个单位上（第二段再拖到另一个单位）"
		queue_redraw()
		return
	if card.is_spell() and card.needs_target():
		_drag_spell_cells = _spell_target_cells(card)
		# 目标格为空但可直击对方玩家的技能（攻击/火焰箭）：拖到棋盘任意处释放
		_drag_anywhere = _drag_spell_cells.is_empty() and card.id in [8002, 9003]
	else:
		_drag_spell_cells = []
		_drag_anywhere = true   # 无目标技能 / 效果卡：拖到棋盘任意处生效
	if card.is_effect():
		status_text = "%s：拖到棋盘上启用" % card.card_name
	elif not _drag_spell_cells.is_empty():
		status_text = "%s：拖到高亮目标上释放" % card.card_name
	else:
		status_text = "%s：拖到棋盘上释放" % card.card_name
	queue_redraw()


func _own_place_cells(card: CardData) -> Array[Vector2i]:
	## 合法放置格。
	## 场地卡（R74）：**不要求格子空着** —— 已有场地会被顶掉、已有单位也允许
	## （场地不是单位，两套数据互不影响）。
	## 能放哪些格由**这张场地的生效对象**决定（R78）：
	##   * 陷阱（等敌人踩）→ 我方后排禁放（敌人永远进不去）；敌方半场 0..4 全允许。
	##   * 只对己方生效 → 敌方后排禁放（我们自己进不去）。
	##   * 对双方生效 → 全场无限制。
	## 判据是「目标方能不能走到这一格」，不是「后排」这个位置本身。
	if card.is_field():
		return _field_place_cells(card)
	## 普通随从/工事：自己半场（下 3 行）的空格 + 可合并的己方栅栏格
	## （持「栅栏修复术」且手里是栅栏卡时，栅栏可以打在已有栅栏上）。
	## 带「交换」字段的卡（R101，救援构装体）：还能打在**已有己方单位**的格子上
	## （原单位被顶回手、新卡占据该格；引擎 play_from_hand 里的交换分支负责顶回手）。
	var out: Array[Vector2i] = []
	for x in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
		for y in FieldState.BOARD_COLS:
			var c := Vector2i(x, y)
			if not engine.state.board.has(c):
				out.append(c)
			elif engine.fence_merge_target(c, card):
				out.append(c)
			elif card.has_affix(GameEngine.AFFIX_SWAP) \
					and engine.state.board[c].owner == GameEngine.SIDE_SELF:
				out.append(c)
	return out


func _field_place_cells(card: CardData) -> Array[Vector2i]:
	## 场地卡的合法格：按**这张卡的生效对象**逐格问引擎（field_place_allowed）。
	## 刻意**不**自己算禁行 —— R78 之前界面算一遍 ban 行、引擎也算一遍，
	## 两边万一不同步极难查（R76 的双重场地就是这么坏的）。委托唯一口就只有一个真相。
	## card 传 null 时引擎按「敌」处理（陷阱默认口径）。
	var aim := GameEngine.field_aim(card)
	var out: Array[Vector2i] = []
	for x in FieldState.BOARD_ROWS:
		for y in FieldState.BOARD_COLS:
			var c := Vector2i(x, y)
			if GameEngine.field_place_allowed(c, aim):
				out.append(c)
	return out


func _fence_merge_cells(card: CardData) -> Array[Vector2i]:
	## 可「叠栅栏」的己方栅栏格（仅用于高亮提示）。
	var out: Array[Vector2i] = []
	if not engine.fence_merge_allowed(card):
		return out
	for x in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
		for y in FieldState.BOARD_COLS:
			var c := Vector2i(x, y)
			if engine.fence_merge_target(c, card):
				out.append(c)
	return out


func _finish_drag(pos: Vector2) -> void:
	## 松手：按落点结算拖拽（有效 → 释放/放置；否则取消，卡留在手牌）。
	## R71：拖拽是**独立于 `_on_board_click` 的另一条出手路径**，所以回合门禁要单独写一份
	## （只加在 `_on_board_click` 的话，敌方回合照样能拖牌上场）。
	# R77：鸭语耳环自动出牌播送中 → 拖拽也锁住（与 _on_left_click 同一条理由）。
	if engine != null and engine.earring_autoplay_active():
		_drag_idx = -1
		_press_idx = -1
		_drag_spell_cells = []
		_drag_anywhere = false
		_drag_place = false
		_drag_place_cells = []
		_say("鸭语耳环正在自动出牌，等它出完（%d 张）" % engine.earring_played)
		return
	if engine == null or engine.over or engine.current_side != GameEngine.SIDE_SELF:
		_drag_idx = -1
		_press_idx = -1
		_drag_spell_cells = []
		_drag_anywhere = false
		_drag_place = false
		_drag_place_cells = []
		_say("现在是敌方回合，等对手行动完再出牌")
		return
	var i := _drag_idx
	_drag_idx = -1
	var cells := _drag_spell_cells
	var anywhere := _drag_anywhere
	var place := _drag_place
	var place_cells := _drag_place_cells
	_drag_spell_cells = []
	_drag_anywhere = false
	_drag_place = false
	_drag_place_cells = []
	var card := engine.state.hand[i]
	var infil_drop = _cell_at(pos)
	if card.id == GameEngine.INFILTRATE_ID and cells.has(infil_drop):
		# R76 潜入第一段：拖到己方盟友 = 选定它，然后高亮所有可去的空格。
		# 这里**不结算**（卡还在手上、也没扣费），等第二段点/拖目的格才真正施放。
		_infiltrate_src = infil_drop
		_drag_spell_cells = _infiltrate_dst_cells()
		if _drag_spell_cells.is_empty():
			_clear_selection()
			_drag_idx = -1
			_say("潜入：没有可去的空格，技能仍在手牌")
			return
		spell_pending = i
		spell_targets = _drag_spell_cells
		_drag_idx = -1
		queue_redraw()
		return
	if card.id == GameEngine.SWAP_UNITS_ID and _swap_src.x >= 0 \
			and infil_drop != null and cells.has(infil_drop) \
			and infil_drop != _swap_src:
		# R102 双向传送第二段：拖到另一个单位 = 真正交换（清选中 → 引擎两段结算）。
		var sw_a := _swap_src
		_clear_selection()
		spell_pending = -1
		spell_targets = []
		if not engine.can_pay_card(card):
			_say("能量不足：%s 需要 %d，当前能量 %d" % [
					card.card_name, engine.cost_of(card), engine.energy_of()])
			return
		status_text = "双向传送 → %s" % engine.cast_swap_units(i, sw_a, infil_drop)
		_net_send({"type": "action", "act": "spell", "card": card.to_dict(),
				"target": null})
		queue_redraw()
		return
	if card.id == GameEngine.SWAP_UNITS_ID and cells.has(infil_drop):
		# R102 双向传送第一段：拖到任意单位 = 选定它，然后高亮其余单位。
		_swap_src = infil_drop
		_drag_spell_cells = []
		for c: Vector2i in engine.state.board:
			if c != infil_drop:
				_drag_spell_cells.append(c)
		_drag_spell_cells.sort()
		var sw_pick: Placement = engine.state.unit_at(_swap_src)
		if _drag_spell_cells.is_empty():
			_clear_selection()
			_drag_idx = -1
			_say("双向传送：场上只有 %s 一个单位，技能仍在手牌" % sw_pick.card.card_name)
			return
		spell_pending = i
		spell_targets = _drag_spell_cells
		_drag_idx = -1
		queue_redraw()
		return
	if place:
		# 随从/工事：落到自己半场空格 = 上场
		var drop = _cell_at(pos)
		if drop != null and place_cells.has(drop):
			if not engine.can_pay_card(card):
				_say("能量不足：%s 需要 %d，当前能量 %d" % [
						card.card_name, engine.cost_of(card), engine.energy_of()])
				return
			_try_play_hand_card(i, drop)   # 英雄要先付「弃 4 张」的代价
		elif engine.fence_merge_allowed(card):
			_say("%s：拖到绿色空格；或拖到橙色「叠」格与已有栅栏合并（已取消）" % card.card_name)
		else:
			_say("%s：拖到自己半场（下 3 行）的空格放置（已取消）" % card.card_name)
		return
	var cell = _cell_at(pos)
	if card.id == GameEngine.INFILTRATE_ID and _infiltrate_src.x >= 0 \
			and cell != null and _infiltrate_dst_cells().has(cell):
		# R76 潜入第二段：拖到空格 = 真正施放（清选中 → cast_infiltrate 两段结算）。
		var src := _infiltrate_src
		_infiltrate_src = Vector2i(-1, -1)
		spell_pending = -1
		spell_targets = []
		if not engine.can_pay_card(card):
			_clear_selection()
			_say("能量不足：%s 需要 %d，当前能量 %d" % [
					card.card_name, engine.cost_of(card), engine.energy_of()])
			return
		_clear_selection()
		status_text = "潜入 → %s" % engine.cast_infiltrate(i, src, cell)
		_net_send({"type": "action", "act": "spell", "card": card.to_dict(),
				"target": null})
		queue_redraw()
		return
	if card.is_spell():
		if not cells.is_empty():
			# 需要目标：必须落在有效目标格（目标单位/格子）上
			if cell != null and cells.has(cell):
				if not engine.can_pay_card(card):
					_say("能量不足：%s 需要 %d，当前能量 %d" % [
							card.card_name, engine.cost_of(card), engine.energy_of()])
					return
				_cast_spell(i, cell, card)
			else:
				_say("%s：拖到高亮目标上释放（已取消）" % card.card_name)
			return
		if anywhere and cell != null:
			if not engine.can_pay_card(card):
				_say("能量不足：%s 需要 %d，当前能量 %d" % [
						card.card_name, engine.cost_of(card), engine.energy_of()])
				return
			engine.use_spell(i)
			_net_send({"type": "action", "act": "spell",
					"card": card.to_dict(), "target": null})
			return
		_say("%s：拖到棋盘上释放（已取消）" % card.card_name)
		return
	# 效果卡：拖到棋盘 = 启用
	if cell != null:
		if not engine.can_pay_card(card):
			_say("能量不足：%s 需要 %d，当前能量 %d" % [
					card.card_name, engine.cost_of(card), engine.energy_of()])
			return
		engine.use_effect(i)
		_net_send({"type": "action", "act": "effect", "card": card.to_dict()})
		return
	_say("%s：拖到棋盘上启用（已取消）" % card.card_name)


func _cast_spell(i: int, cell: Vector2i, card: CardData) -> void:
	## 释放指定目标的技能（点击选目标与拖拽共用）。
	# R76：潜入的两段判定都收在 _infiltrate_src 上 —— 它是「已选盟友」的**唯一标记**。
	# 为 -1 说明这是第一段（还没选盟友），此时**不能**施放，否则会掉进 use_spell 的
	# 单段分支、由引擎自己挑落点（表现为卡片自己跑到前排左边）。
	if card.id == GameEngine.INFILTRATE_ID and _infiltrate_src.x < 0:
		_clear_selection()
		_say("潜入：先点一个己方盟友，再点目的格")
		return
	if card.id == GameEngine.INFILTRATE_ID and _infiltrate_src.x >= 0:
		# 潜入第二段：盟友已选，这里点的是目的格
		var src := _infiltrate_src
		_clear_selection()
		status_text = "潜入 → %s" % engine.cast_infiltrate(i, src, cell)
		_net_send({"type": "action", "act": "spell", "card": card.to_dict(),
				"target": null})
		queue_redraw()
		return
	# R102：双向传送的两段判定同样收在 _swap_src 上（与潜入同套路）。
	if card.id == GameEngine.SWAP_UNITS_ID and _swap_src.x < 0:
		_clear_selection()
		_say("双向传送：先点第一个单位，再点第二个单位")
		return
	if card.id == GameEngine.SWAP_UNITS_ID and _swap_src.x >= 0:
		var sw_a := _swap_src
		_clear_selection()
		status_text = "双向传送 → %s" % engine.cast_swap_units(i, sw_a, cell)
		_net_send({"type": "action", "act": "spell", "card": card.to_dict(),
				"target": null})
		queue_redraw()
		return
	if not engine.can_use_card(card):
		_say("%s：本回合还需先使用 %d 张其他卡（已用 %d）" % [
				card.card_name, GameEngine.WHIRL_BLADE_NEED, engine.state.self_card_plays])
		_clear_selection()
		return
	_clear_selection()
	engine.use_spell(i, cell)
	_net_send({"type": "action", "act": "spell", "card": card.to_dict(),
			"target": [cell.x, cell.y]})


# ------------------------------------------------------------ 英雄（9023）的弃牌代价

func _try_play_hand_card(i: int, cell: Vector2i) -> void:
	## 手牌落到自己半场空格：普通卡直接上场；
	## 「英雄」这类有额外代价的卡 → 先弹「选择 N 张手牌丢弃」面板，由玩家自己挑。
	var card := engine.state.hand[i]
	var need := engine.discard_cost_of(card)
	if need <= 0:
		_finish_play(i, cell)
		return
	var others: int = engine.state.hand.size() - 1
	if others < need:
		_say("%s 需要额外丢弃 %d 张手牌，手牌不足（除它以外只有 %d 张）"
				% [card.card_name, need, others])
		return
	_hero_pick_idx = i
	_hero_pick_cell = cell
	_hero_pick_sel = []
	status_text = "英雄的代价：选择 %d 张手牌丢弃（0/%d）" % [need, need]
	queue_redraw()


func _finish_play(i: int, cell: Vector2i) -> void:
	## 手牌上场（无额外代价的普通卡）：清选中 → 放置 → 联机同步。
	_clear_selection()
	var card := engine.state.hand[i]
	engine.play_from_hand(i, cell)
	_net_send({"type": "action", "act": "play", "card": card.to_dict(),
			"cell": [cell.x, cell.y]})
	queue_redraw()   # 乌鸦上场会立刻弹出「从弃牌堆选盟友」面板


func _hero_pick_options() -> Array[int]:
	## 可以拿来当代价的手牌下标（不含英雄自己）。
	var out: Array[int] = []
	if _hero_pick_idx < 0:
		return out
	for i in engine.state.hand.size():
		if i != _hero_pick_idx:
			out.append(i)
	return out


func _hero_pick_layout() -> Dictionary:
	## 代价面板的布局（绘制与点击判定共用，改一处即可）。
	var opts := _hero_pick_options()
	var n := opts.size()
	var pw := minf(WINDOW_W - 240.0, 120.0 + n * (CARD_W + 8.0))
	var ph := CARD_H + 150.0
	var px := (WINDOW_W - pw) / 2.0
	var py := (WINDOW_H - ph) / 2.0
	var spacing: float = minf(CARD_W + 8.0, maxf(24.0, (pw - 60.0) / maxf(n, 1)))
	var x0 := px + (pw - (spacing * (n - 1) + CARD_W)) / 2.0
	var bw := 116.0
	var by := py + ph - 52.0
	return {"opts": opts, "px": px, "py": py, "pw": pw, "ph": ph, "x0": x0,
			"spacing": spacing, "card_y": py + 46.0,
			"ok": Rect2(WINDOW_W / 2.0 + 12.0, by, bw, 34.0),
			"cancel": Rect2(WINDOW_W / 2.0 - 12.0 - bw, by, bw, 34.0)}


func _draw_hero_pick() -> void:
	## 「英雄的代价」面板：手牌（除英雄外）横排 → 点选 4 张 → 确定 → 英雄上场。
	var L := _hero_pick_layout()
	var need := GameEngine.HERO_DISCARD
	# 面板不再压暗背景（用户要求：点开面板时后面区域不要变暗）
	draw_rect(Rect2(L.px, L.py, L.pw, L.ph), Color.WHITE)
	draw_rect(Rect2(L.px, L.py, L.pw, L.ph), Color("555555"), false, 2.0)
	_draw_string_center(_font_bold, 13, "英雄的代价：选择 %d 张手牌丢弃（已选 %d/%d）"
					% [need, _hero_pick_sel.size(), need],
			Vector2(WINDOW_W / 2, L.py + 26), Color("333333"))
	var opts: Array = L["opts"]
	for k in opts.size():
		var idx: int = opts[k]
		var c: CardData = engine.state.hand[idx]
		var r := Rect2(L["x0"] + L["spacing"] * k, L["card_y"], CARD_W, CARD_H)
		var picked := _hero_pick_sel.has(idx)
		if picked:
			draw_rect(r.grow(5.0), Color("c1121f"), false, 2.0)
		_draw_card_face(c, r, c.health, picked, false, engine.cost_of(c))
	var full: bool = _hero_pick_sel.size() == need
	draw_rect(L["ok"], Color("2e7d32") if full else Color("b0aaa0"))
	_draw_string_center(_font_bold, 12, "确定（丢弃 %d 张）" % _hero_pick_sel.size(),
			Vector2(L["ok"].position.x + L["ok"].size.x / 2.0,
					L["ok"].position.y + L["ok"].size.y / 2.0 + 4.0), Color.WHITE)
	draw_rect(L["cancel"], Color("8a8578"))
	_draw_string_center(_font_bold, 12, "取消",
			Vector2(L["cancel"].position.x + L["cancel"].size.x / 2.0,
					L["cancel"].position.y + L["cancel"].size.y / 2.0 + 4.0), Color.WHITE)
	_draw_string_center(_font, 9,
			"点卡牌选中 / 取消；选满 %d 张后点确定 —— 英雄随即上场" % need,
			Vector2(WINDOW_W / 2, L["py"] + L["ph"] - 12.0), Color("666666"))


func _on_hero_pick_click(pos: Vector2) -> void:
	## 代价面板的点击：卡牌切换选中 / 确定 / 取消。
	var L := _hero_pick_layout()
	var need := GameEngine.HERO_DISCARD
	if L["cancel"].has_point(pos):
		var nm := engine.state.hand[_hero_pick_idx].card_name
		_hero_pick_idx = -1
		_hero_pick_sel = []
		status_text = "已取消：%s 仍在手牌（未付代价）" % nm
		queue_redraw()
		return
	if L["ok"].has_point(pos):
		if _hero_pick_sel.size() != need:
			_say("还要再选 %d 张手牌当作代价" % (need - _hero_pick_sel.size()))
			return
		var i := _hero_pick_idx
		var cell := _hero_pick_cell
		var sel := _hero_pick_sel.duplicate()
		_hero_pick_idx = -1
		_hero_pick_sel = []
		var card := engine.state.hand[i]
		if engine.play_hero_from_hand(i, cell, sel) == null:
			_say("%s：代价结算失败，卡仍在手牌" % card.card_name)
		else:
			_clear_selection()
			_net_send({"type": "action", "act": "play", "card": card.to_dict(),
					"cell": [cell.x, cell.y]})
			status_text = "%s 上场：付出代价（丢弃 %d 张手牌）" % [card.card_name, sel.size()]
		queue_redraw()
		return
	var opts: Array = L["opts"]
	for k in opts.size():
		var idx: int = opts[k]
		var r := Rect2(L["x0"] + L["spacing"] * k, L["card_y"], CARD_W, CARD_H)
		if r.has_point(pos):
			if _hero_pick_sel.has(idx):
				_hero_pick_sel.erase(idx)
			elif _hero_pick_sel.size() < need:
				_hero_pick_sel.append(idx)
			else:
				_say("最多只能丢弃 %d 张" % need)
			queue_redraw()
			return


func _crow_panel_layout() -> Dictionary:
	## 乌鸦回手面板布局（绘制与点击判定共用一份，改一处即可）。
	## 弃牌堆里的盟友可能很多 → 网格排布 + 略缩小卡面，避免单行挤成一团。
	var opts := engine.crow_options()
	var n := maxi(opts.size(), 1)
	var cw := CARD_W * 0.8
	var ch := CARD_H * 0.8
	var step_x := cw + 8.0
	var step_y := ch + 8.0
	var cols: int = clampi(int((WINDOW_W - 220.0) / step_x), 1, mini(n, 10))
	var rows: int = int(ceil(float(n) / float(cols)))
	var content_w: float = step_x * cols - 8.0
	var content_h: float = step_y * rows - 8.0
	var pw: float = minf(WINDOW_W - 120.0, content_w + 60.0)
	var ph: float = minf(WINDOW_H - 80.0, content_h + 132.0)
	var px: float = (WINDOW_W - pw) / 2.0
	var py: float = (WINDOW_H - ph) / 2.0
	return {"opts": opts, "cols": cols, "cw": cw, "ch": ch,
			"step_x": step_x, "step_y": step_y,
			"x0": px + (pw - content_w) / 2.0, "card_y": py + 52.0,
			"px": px, "py": py, "pw": pw, "ph": ph}


func _crow_panel_rect(L: Dictionary, k: int) -> Rect2:
	var cols: int = L["cols"]
	return Rect2(L["x0"] + L["step_x"] * (k % cols),
			L["card_y"] + L["step_y"] * int(k / cols), L["cw"], L["ch"])


func _draw_crow_pick() -> void:
	## 乌鸦（9039）「从弃牌堆选一张盟友回到手牌」面板：只列盟友，点哪张拿哪张（必须选）。
	var L := _crow_panel_layout()
	# 面板不再压暗背景（用户要求：点开面板时后面区域不要变暗）
	draw_rect(Rect2(L["px"], L["py"], L["pw"], L["ph"]), Color.WHITE)
	draw_rect(Rect2(L["px"], L["py"], L["pw"], L["ph"]), Color("555555"), false, 2.0)
	_draw_string_center(_font_bold, 13, "乌鸦：选择弃牌堆一张盟友回到手卡（必须选一张）",
			Vector2(WINDOW_W / 2, L["py"] + 26), Color("333333"))
	var opts: Array = L["opts"]
	for k in opts.size():
		var idx: int = opts[k]
		var c: CardData = engine.state.discard[idx]
		_draw_card_face(c, _crow_panel_rect(L, k), c.health, false, false)
	_draw_string_center(_font, 9, "点击一张卡：它立即回到你的手牌",
			Vector2(WINDOW_W / 2, L["py"] + L["ph"] - 12.0), Color("666666"))


func _on_crow_pick_click(pos: Vector2) -> void:
	var L := _crow_panel_layout()
	var opts: Array = L["opts"]
	for k in opts.size():
		if _crow_panel_rect(L, k).has_point(pos):
			var idx: int = opts[k]
			var nm := "?"
			if idx >= 0 and idx < engine.state.discard.size():
				nm = engine.state.discard[idx].card_name
			if engine.crow_recall(idx):
				status_text = "乌鸦：%s 从弃牌堆回到手牌" % nm
			_clear_selection()
			queue_redraw()
			return


func _whale_panel_layout() -> Dictionary:
	## 鲸鱼之怒取牌面板布局（与乌鸦面板同款：网格排布 + 略缩小卡面）。
	var opts := engine.whale_options()
	var n := maxi(opts.size(), 1)
	var cw := CARD_W * 0.8
	var ch := CARD_H * 0.8
	var step_x := cw + 8.0
	var step_y := ch + 8.0
	var cols: int = clampi(int((WINDOW_W - 220.0) / step_x), 1, mini(n, 10))
	var rows: int = int(ceil(float(n) / float(cols)))
	var content_w: float = step_x * cols - 8.0
	var content_h: float = step_y * rows - 8.0
	var pw: float = minf(WINDOW_W - 120.0, content_w + 60.0)
	var ph: float = minf(WINDOW_H - 80.0, content_h + 132.0)
	var px: float = (WINDOW_W - pw) / 2.0
	var py: float = (WINDOW_H - ph) / 2.0
	return {"opts": opts, "cols": cols, "cw": cw, "ch": ch,
			"step_x": step_x, "step_y": step_y,
			"x0": px + (pw - content_w) / 2.0, "card_y": py + 52.0,
			"px": px, "py": py, "pw": pw, "ph": ph}


func _whale_panel_rect(L: Dictionary, k: int) -> Rect2:
	var cols: int = L["cols"]
	return Rect2(L["x0"] + L["step_x"] * (k % cols),
			L["card_y"] + L["step_y"] * int(k / cols), L["cw"], L["ch"])


func _whale_skip_rect(L: Dictionary) -> Rect2:
	## 「不选了」按钮（面板底部居中）—— 鲸鱼之怒的取牌是可选的。
	var bw := 132.0
	var bh := 26.0
	return Rect2(WINDOW_W / 2.0 - bw / 2.0, L["py"] + L["ph"] - bh - 8.0, bw, bh)


func _draw_whale_pick() -> void:
	## 鲸鱼之怒（9050）面板：从弃牌堆取卡入手（可选可跳过；取满 2 张自动关闭）。
	var L := _whale_panel_layout()
	# 面板不再压暗背景（用户要求：点开面板时后面区域不要变暗）
	draw_rect(Rect2(L["px"], L["py"], L["pw"], L["ph"]), Color.WHITE)
	draw_rect(Rect2(L["px"], L["py"], L["pw"], L["ph"]), Color("555555"), false, 2.0)
	_draw_string_center(_font_bold, 13,
			"鲸鱼之怒：从弃牌堆取卡加入手卡（还可取 %d 张）" % engine.whale_remaining,
			Vector2(WINDOW_W / 2, L["py"] + 26), Color("333333"))
	var opts: Array = L["opts"]
	for k in opts.size():
		var idx: int = opts[k]
		var c: CardData = engine.state.discard[idx]
		_draw_card_face(c, _whale_panel_rect(L, k), c.health, false, false)
	var sk := _whale_skip_rect(L)
	draw_rect(sk, Color("dcdcdc"))
	draw_rect(sk, Color("777777"), false, 1.5)
	_draw_string_center(_font_bold, 11, "不选了（结束取牌）",
			sk.position + sk.size / 2.0, Color("222222"))


func _on_whale_pick_click(pos: Vector2) -> void:
	var L := _whale_panel_layout()
	if _whale_skip_rect(L).has_point(pos):
		var left := engine.whale_remaining
		engine.whale_skip()
		status_text = "鲸鱼之怒：放弃剩余 %d 张的取牌" % left
		_clear_selection()
		queue_redraw()
		return
	var opts: Array = L["opts"]
	for k in opts.size():
		if _whale_panel_rect(L, k).has_point(pos):
			var idx: int = opts[k]
			var nm := "?"
			if idx >= 0 and idx < engine.state.discard.size():
				nm = engine.state.discard[idx].card_name
			if engine.whale_pick(idx):
				status_text = "鲸鱼之怒：%s 从弃牌堆回到手牌" % nm
			_clear_selection()
			queue_redraw()
			return


func _endless_panel_layout() -> Dictionary:
	## 无尽黑暗（9114，R70）弃牌面板布局：列出**手牌**，玩家点一张弃掉。
	## 与鲸鱼面板同一套网格逻辑（略缩小卡面），只是数据源从弃牌堆换成手牌。
	var opts := engine.endless_options()
	var n := maxi(opts.size(), 1)
	var cw := CARD_W * 0.8
	var ch := CARD_H * 0.8
	var step_x := cw + 8.0
	var step_y := ch + 8.0
	var cols: int = clampi(int((WINDOW_W - 220.0) / step_x), 1, mini(n, 10))
	var rows: int = int(ceil(float(n) / float(cols)))
	var content_w: float = step_x * cols - 8.0
	var content_h: float = step_y * rows - 8.0
	var pw: float = minf(WINDOW_W - 120.0, content_w + 60.0)
	var ph: float = minf(WINDOW_H - 80.0, content_h + 96.0)
	var px: float = (WINDOW_W - pw) / 2.0
	var py: float = (WINDOW_H - ph) / 2.0
	return {"opts": opts, "cols": cols, "cw": cw, "ch": ch,
			"step_x": step_x, "step_y": step_y,
			"x0": px + (pw - content_w) / 2.0, "card_y": py + 52.0,
			"px": px, "py": py, "pw": pw, "ph": ph}


func _endless_panel_rect(L: Dictionary, k: int) -> Rect2:
	var cols: int = L["cols"]
	return Rect2(L["x0"] + L["step_x"] * (k % cols),
			L["card_y"] + L["step_y"] * int(k / cols), L["cw"], L["ch"])


func _draw_endless_pick() -> void:
	## 无尽黑暗（9114，R70）面板：每回合抽牌后强制弃 1 张手牌，**不能不选**，所以没有跳过按钮。
	var L := _endless_panel_layout()
	draw_rect(Rect2(L["px"], L["py"], L["pw"], L["ph"]), Color.WHITE)
	draw_rect(Rect2(L["px"], L["py"], L["pw"], L["ph"]), Color("555555"), false, 2.0)
	_draw_string_center(_font_bold, 13,
			"无尽黑暗：选择 1 张手牌弃掉（不能不选）→ 之后费用 +%d"
			% GameEngine.ENDLESS_DARK_ENERGY,
			Vector2(WINDOW_W / 2, L["py"] + 26), Color("333333"))
	var opts: Array = L["opts"]
	for k in opts.size():
		var idx: int = opts[k]
		var c: CardData = engine.state.hand[idx]
		_draw_card_face(c, _endless_panel_rect(L, k), c.health, false, false)


func _on_endless_pick_click(pos: Vector2) -> void:
	var L := _endless_panel_layout()
	var opts: Array = L["opts"]
	for k in opts.size():
		if _endless_panel_rect(L, k).has_point(pos):
			var idx: int = opts[k]
			var nm := "?"
			if idx >= 0 and idx < engine.state.hand.size():
				nm = engine.state.hand[idx].card_name
			if engine.endless_pick(idx):
				status_text = "无尽黑暗：弃掉 %s → 费用 +%d" % [
						nm, GameEngine.ENDLESS_DARK_ENERGY]
			_clear_selection()
			queue_redraw()
			return


func _infiltrate_dst_cells() -> Array[Vector2i]:
	## 潜入（9100）第二段的目的格：全棋盘任意空格，对方后排（移动禁区）除外。
	var out: Array[Vector2i] = []
	for x in FieldState.BOARD_ROWS:
		for y in FieldState.BOARD_COLS:
			var c := Vector2i(x, y)
			if not engine.state.board.has(c)\
					and x != GameEngine.forbidden_row_for(GameEngine.SIDE_SELF):
				out.append(c)
	out.sort()
	return out


func _foresight_mode_rects() -> Array:
	var bw := 460.0
	var bh := 40.0
	var x := WINDOW_W / 2.0 - bw / 2.0
	var y0 := WINDOW_H / 2.0 - 58.0
	return [Rect2(x, y0, bw, bh), Rect2(x, y0 + bh + 14.0, bw, bh)]


func _draw_foresight_mode() -> void:
	## 预判（9097）二选一面板。
	var rs: Array = _foresight_mode_rects()
	var box := Rect2(rs[0].position.x - 26.0, rs[0].position.y - 54.0,
			rs[0].size.x + 52.0, 168.0)
	draw_rect(box, Color.WHITE)
	draw_rect(box, Color("555555"), false, 2.0)
	_draw_string_center(_font_bold, 13, "预判：选择一个效果",
			Vector2(WINDOW_W / 2, rs[0].position.y - 28), Color("333333"))
	var labels := [
		"① 从弃牌区选一张费用为 0 的技能卡加入手卡（之后本卡消失）",
		"② 从卡组将一张随机费用不为 0 的技能卡加入手卡",
	]
	for k in 2:
		draw_rect(rs[k], Color("e8e2f4") if k == 0 else Color("e2ecf4"))
		draw_rect(rs[k], Color("7a5ea8") if k == 0 else Color("4a7ea8"), false, 1.5)
		_draw_string_center(_font, 11, labels[k],
				rs[k].position + rs[k].size / 2.0, Color("222222"))


func _on_foresight_mode_click(pos: Vector2) -> void:
	var rs: Array = _foresight_mode_rects()
	for k in 2:
		if (rs[k] as Rect2).has_point(pos):
			engine.foresight_choose(k + 1)
			_clear_selection()
			queue_redraw()
			return


func _foresight_panel_layout() -> Dictionary:
	## 预判①取牌面板布局（与复活术面板同款：网格排布 + 略缩小卡面）。
	var opts := engine.foresight_options()
	var n := maxi(opts.size(), 1)
	var cw := CARD_W * 0.8
	var ch := CARD_H * 0.8
	var step_x := cw + 8.0
	var step_y := ch + 8.0
	var cols: int = clampi(int((WINDOW_W - 220.0) / step_x), 1, mini(n, 10))
	var rows: int = int(ceil(float(n) / float(cols)))
	var content_w: float = step_x * cols - 8.0
	var content_h: float = step_y * rows - 8.0
	var pw: float = minf(WINDOW_W - 120.0, content_w + 60.0)
	var ph: float = minf(WINDOW_H - 80.0, content_h + 132.0)
	var px: float = (WINDOW_W - pw) / 2.0
	var py: float = (WINDOW_H - ph) / 2.0
	return {"opts": opts, "cols": cols, "cw": cw, "ch": ch,
			"step_x": step_x, "step_y": step_y,
			"x0": px + (pw - content_w) / 2.0, "card_y": py + 52.0,
			"px": px, "py": py, "pw": pw, "ph": ph}


func _foresight_panel_rect(L: Dictionary, k: int) -> Rect2:
	var cols: int = L["cols"]
	return Rect2(L["x0"] + L["step_x"] * (k % cols),
			L["card_y"] + L["step_y"] * int(k / cols), L["cw"], L["ch"])


func _draw_foresight_pick() -> void:
	## 预判①「从弃牌区选一张 0 费技能卡」面板：只列 0 费技能卡，点哪张拿哪张。
	var L := _foresight_panel_layout()
	draw_rect(Rect2(L["px"], L["py"], L["pw"], L["ph"]), Color.WHITE)
	draw_rect(Rect2(L["px"], L["py"], L["pw"], L["ph"]), Color("555555"), false, 2.0)
	_draw_string_center(_font_bold, 13,
			"预判①：选择弃牌区一张费用为 0 的技能卡（必须选一张，之后本卡消失）",
			Vector2(WINDOW_W / 2, L["py"] + 26), Color("333333"))
	var opts: Array = L["opts"]
	for k in opts.size():
		var idx: int = opts[k]
		var c: CardData = engine.state.discard[idx]
		_draw_card_face(c, _foresight_panel_rect(L, k), c.health, false, false)
	_draw_string_center(_font, 9, "点击一张卡：它立即回到你的手牌",
			Vector2(WINDOW_W / 2, L["py"] + L["ph"] - 30), Color("555555"))


func _on_foresight_pick_click(pos: Vector2) -> void:
	var L := _foresight_panel_layout()
	var opts: Array = L["opts"]
	for k in opts.size():
		if _foresight_panel_rect(L, k).has_point(pos):
			var idx: int = opts[k]
			var nm := "?"
			if idx >= 0 and idx < engine.state.discard.size():
				nm = engine.state.discard[idx].card_name
			if engine.foresight_pick_card(idx):
				status_text = "预判：%s 回到手卡（本卡已消失）" % nm
			_clear_selection()
			queue_redraw()
			return


func _fate_panel_layout() -> Dictionary:
	## 拒绝命运取牌面板布局（与鲸鱼面板同款；必须选满，没有「不选了」）。
	var opts := engine.fate_options()
	var n := maxi(opts.size(), 1)
	var cw := CARD_W * 0.8
	var ch := CARD_H * 0.8
	var step_x := cw + 8.0
	var step_y := ch + 8.0
	var cols: int = clampi(int((WINDOW_W - 220.0) / step_x), 1, mini(n, 10))
	var rows: int = int(ceil(float(n) / float(cols)))
	var content_w: float = step_x * cols - 8.0
	var content_h: float = step_y * rows - 8.0
	var pw: float = minf(WINDOW_W - 120.0, content_w + 60.0)
	var ph: float = minf(WINDOW_H - 80.0, content_h + 132.0)
	var px: float = (WINDOW_W - pw) / 2.0
	var py: float = (WINDOW_H - ph) / 2.0
	return {"opts": opts, "cols": cols, "cw": cw, "ch": ch,
			"step_x": step_x, "step_y": step_y,
			"x0": px + (pw - content_w) / 2.0, "card_y": py + 52.0,
			"px": px, "py": py, "pw": pw, "ph": ph}


func _fate_panel_rect(L: Dictionary, k: int) -> Rect2:
	var cols: int = L["cols"]
	return Rect2(L["x0"] + L["step_x"] * (k % cols),
			L["card_y"] + L["step_y"] * int(k / cols), L["cw"], L["ch"])


func _draw_fate_pick() -> void:
	## 拒绝命运（9098）面板：从弃牌区选回等量的卡（必须选满，本卡已消失不在列表里）。
	var L := _fate_panel_layout()
	draw_rect(Rect2(L["px"], L["py"], L["pw"], L["ph"]), Color.WHITE)
	draw_rect(Rect2(L["px"], L["py"], L["pw"], L["ph"]), Color("555555"), false, 2.0)
	_draw_string_center(_font_bold, 13,
			"拒绝命运：从弃牌区选 %d 张卡加入手卡（必须选满）" % engine.fate_count,
			Vector2(WINDOW_W / 2, L["py"] + 26), Color("333333"))
	var opts: Array = L["opts"]
	for k in opts.size():
		var idx: int = opts[k]
		var c: CardData = engine.state.discard[idx]
		_draw_card_face(c, _fate_panel_rect(L, k), c.health, false, false)
	_draw_string_center(_font, 9, "点击一张卡：它立即回到你的手牌（还要选 %d 张）" % engine.fate_count,
			Vector2(WINDOW_W / 2, L["py"] + L["ph"] - 30), Color("555555"))


func _on_fate_pick_click(pos: Vector2) -> void:
	var L := _fate_panel_layout()
	var opts: Array = L["opts"]
	for k in opts.size():
		if _fate_panel_rect(L, k).has_point(pos):
			var idx: int = opts[k]
			var nm := "?"
			if idx >= 0 and idx < engine.state.discard.size():
				nm = engine.state.discard[idx].card_name
			if engine.fate_pick(idx):
				status_text = "拒绝命运：%s 回到手牌" % nm
			_clear_selection()
			queue_redraw()
			return


func _revive_panel_layout() -> Dictionary:
	## 复活术（9078）取牌面板布局（与乌鸦/鲸鱼面板同款：网格排布 + 略缩小卡面）。
	var opts := engine.revive_options()
	var n := maxi(opts.size(), 1)
	var cw := CARD_W * 0.8
	var ch := CARD_H * 0.8
	var step_x := cw + 8.0
	var step_y := ch + 8.0
	var cols: int = clampi(int((WINDOW_W - 220.0) / step_x), 1, mini(n, 10))
	var rows: int = int(ceil(float(n) / float(cols)))
	var content_w: float = step_x * cols - 8.0
	var content_h: float = step_y * rows - 8.0
	var pw: float = minf(WINDOW_W - 120.0, content_w + 60.0)
	var ph: float = minf(WINDOW_H - 80.0, content_h + 132.0)
	var px: float = (WINDOW_W - pw) / 2.0
	var py: float = (WINDOW_H - ph) / 2.0
	return {"opts": opts, "cols": cols, "cw": cw, "ch": ch,
			"step_x": step_x, "step_y": step_y,
			"x0": px + (pw - content_w) / 2.0, "card_y": py + 52.0,
			"px": px, "py": py, "pw": pw, "ph": ph}


func _revive_panel_rect(L: Dictionary, k: int) -> Rect2:
	var cols: int = L["cols"]
	return Rect2(L["x0"] + L["step_x"] * (k % cols),
			L["card_y"] + L["step_y"] * int(k / cols), L["cw"], L["ch"])


func _draw_revive_pick() -> void:
	## 复活术（9078）「从弃牌区选一张盟友回到手牌」面板：只列盟友，点哪张拿哪张。
	var L := _revive_panel_layout()
	draw_rect(Rect2(L["px"], L["py"], L["pw"], L["ph"]), Color.WHITE)
	draw_rect(Rect2(L["px"], L["py"], L["pw"], L["ph"]), Color("555555"), false, 2.0)
	_draw_string_center(_font_bold, 13, "复活术：选择弃牌区一张盟友回到手卡（必须选一张）",
			Vector2(WINDOW_W / 2, L["py"] + 26), Color("333333"))
	var opts: Array = L["opts"]
	for k in opts.size():
		var idx: int = opts[k]
		var c: CardData = engine.state.discard[idx]
		_draw_card_face(c, _revive_panel_rect(L, k), c.health, false, false)
	var rv_tip := "点击一张卡：它立即回到你的手牌"
	if engine.revive_remaining > 1:
		rv_tip = "点击一张卡：它立即回到你的手牌（还要选 %d 张）" % engine.revive_remaining
	_draw_string_center(_font, 9, rv_tip,
			Vector2(WINDOW_W / 2, L["py"] + L["ph"] - 12.0), Color("666666"))


func _on_revive_pick_click(pos: Vector2) -> void:
	var L := _revive_panel_layout()
	var opts: Array = L["opts"]
	for k in opts.size():
		if _revive_panel_rect(L, k).has_point(pos):
			var idx: int = opts[k]
			var nm := "?"
			if idx >= 0 and idx < engine.state.discard.size():
				nm = engine.state.discard[idx].card_name
			if engine.revive_recall(idx):
				status_text = "复活术：%s 从弃牌区回到手牌" % nm
			_clear_selection()
			queue_redraw()
			return


func _spell_target_cells(card: CardData) -> Array[Vector2i]:
	## 技能的可点目标格：火球术=任意格；击退/龙息=敌方单位；狂暴=己方盟友；其余=战场上所有单位。
	var out: Array[Vector2i] = []
	if card.id == 9007:
		for x in FieldState.BOARD_ROWS:
			for y in FieldState.BOARD_COLS:
				out.append(Vector2i(x, y))
	elif card.id == 9004 or card.id == GameEngine.DRAGON_BREATH_ID:
		for c: Vector2i in engine.state.board:
			if engine.state.board[c].owner == GameEngine.SIDE_OPPONENT:
				out.append(c)
		out.sort()
	elif card.id == GameEngine.FRENZY_ID:
		# 狂暴：只认己方「盟友」（工事/随从以外的单位不可选，敌方单位也不可选）
		for c: Vector2i in engine.state.board:
			var fp: Placement = engine.state.board[c]
			if fp.owner == GameEngine.SIDE_SELF and fp.card.kind == "盟友":
				out.append(c)
		out.sort()
	elif card.id == GameEngine.UPGRADE_ID:
		# 升级 8027（R82，机械之心）：只列**己方盟友或工事**。
		# 必须在这里过滤掉敌方 —— 引擎侧 `_upgrade_unit` 也会拒敌方单位，
		# 但那时玩家已经付了费用、点了格子，提示「只能改造自己的单位」太晚。
		for c: Vector2i in engine.state.board:
			var up: Placement = engine.state.board[c]
			if up.owner == GameEngine.SIDE_SELF \
					and (up.card.kind == "盟友" or up.card.is_fort()):
				out.append(c)
		out.sort()
	elif card.id == GameEngine.ARMOR_PLATE_ID:
		# 加厚装甲 8044（R95，机械之心）：只列**己方盟友**（工事不能选，
		# 与「升级」不同）。同样必须在这里过滤，别等玩家付了费才被拒。
		for c: Vector2i in engine.state.board:
			var ap: Placement = engine.state.board[c]
			if ap.owner == GameEngine.SIDE_SELF and ap.card.kind == "盟友":
				out.append(c)
		out.sort()
	elif card.id == GameEngine.DEMOLISH_ID:
		# 拆解 8049（R97，机械之心）：只列**己方盟友或工事**（与升级同口径）。
		# ⚠️ 必须在这里过滤掉敌方 —— 引擎侧 `_demolish` 也会拒，但那时已付费。
		for c: Vector2i in engine.state.board:
			var dp: Placement = engine.state.board[c]
			if dp.owner == GameEngine.SIDE_SELF \
					and (dp.card.kind == "盟友" or dp.card.is_fort()):
				out.append(c)
		out.sort()
	elif card.id == GameEngine.REORG_ID:
		# 重组 8051（R99，机械之心）：只列**己方盟友或工事**（与升级同口径）。
		for c: Vector2i in engine.state.board:
			var rp: Placement = engine.state.board[c]
			if rp.owner == GameEngine.SIDE_SELF \
					and (rp.card.kind == "盟友" or rp.card.is_fort()):
				out.append(c)
		out.sort()
	elif card.id == GameEngine.TRANSCEND_ID:
		# 超越极限 8053（R99，机械之心）：只列**己方盟友或工事**，且**还没有超负荷**
		# （有了就别列，避免点上去被引擎拒「已拥有超负荷」）。
		for c: Vector2i in engine.state.board:
			var tp: Placement = engine.state.board[c]
			if tp.owner == GameEngine.SIDE_SELF \
					and (tp.card.kind == "盟友" or tp.card.is_fort()) \
					and not tp.card.has_affix(GameEngine.AFFIX_OVERLOAD):
				out.append(c)
		out.sort()
	elif card.id == GameEngine.REBOOT_ID:
		# 重启 8054（R100，机械之心）：只列**己方盟友或工事**（与升级同口径）。
		for c: Vector2i in engine.state.board:
			var rp: Placement = engine.state.board[c]
			if rp.owner == GameEngine.SIDE_SELF \
					and (rp.card.kind == "盟友" or rp.card.is_fort()):
				out.append(c)
		out.sort()
	elif card.id == GameEngine.FIRE_WALL_SPELL_ID:
		# 火墙术：任意一条横行都能烧 → 全棋盘任意格都可点（点该行任一格即选中整行）
		for x in FieldState.BOARD_ROWS:
			for y in FieldState.BOARD_COLS:
				out.append(Vector2i(x, y))
	elif card.id == GameEngine.ICE_WALL_SPELL_ID:
		# 冰墙术：目标是自己半场的一条横行 → 自己半场（下 3 行）的任一格都可点
		for x in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
			for y in FieldState.BOARD_COLS:
				out.append(Vector2i(x, y))
	elif card.id == GameEngine.IRON_FENCE_SPELL_ID:
		# 在启动了：在自己半场选一格召唤铁栅栏 → 只列出自己半场的空格
		for x in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
			for y in FieldState.BOARD_COLS:
				var c := Vector2i(x, y)
				if not engine.state.board.has(c):
					out.append(c)
	elif card.id == GameEngine.SWAP_UNITS_ID:
		# 双向传送（8061，R102）：第一段 = 场上**任意单位**（敌我皆可）；
		# 第二段的可选集合在 _on_board_click 里按「除已选那个」现算。
		for c: Vector2i in engine.state.board:
			out.append(c)
		out.sort()
	elif card.id == GameEngine.INFILTRATE_ID:
		# 潜入：第一段只认己方「盟友」（工事不能动）；第二段目的格另给
		for c: Vector2i in engine.state.board:
			var ip: Placement = engine.state.board[c]
			if ip.owner == GameEngine.SIDE_SELF and ip.card.kind == "盟友":
				out.append(c)
		out.sort()
	elif card.id == GameEngine.DOUBLE_TRAP_ID:
		# 双重场地（9108，R74 由「双重陷阱」改名）：目标是**已有场地的格子**。
		# R76 修：原来这里还在找「己方工事」，与 cards.json 的新口径完全对不上 ——
		# 于是这张卡在 R74 之后**一个目标都选不出来**（点哪儿都取消）。
		# R83：排除**持续型场地**（清泉 8028）—— 它永不触发，附魔等于白花一张牌。
		for c: Vector2i in engine.state.field_effects:
			if str(engine.state.field_owner.get(c, GameEngine.SIDE_SELF)) \
					!= GameEngine.SIDE_SELF:
				continue
			if GameEngine.is_persistent_field(engine.state.field_at(c)):
				continue
			out.append(c)
		out.sort()
	elif card.id == GameEngine.WHIRL_BLADE_ID:
		# 回旋斩：十字中心格 = 全棋盘任意格（只有敌方单位吃伤害）
		for x in FieldState.BOARD_ROWS:
			for y in FieldState.BOARD_COLS:
				out.append(Vector2i(x, y))
	elif card.id == GameEngine.METEOR_ID:
		# 陨石术：十字范围不分敌我 → 全棋盘任意格都能砸（含空格：打后排放 HP）
		for x in FieldState.BOARD_ROWS:
			for y in FieldState.BOARD_COLS:
				out.append(Vector2i(x, y))
	elif card.id == GameEngine.GOLEM_SPELL_ID:
		# 魔像术：在自己半场选一格召唤魔像 → 只列出自己半场的空格
		for x in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
			for y in FieldState.BOARD_COLS:
				var gc := Vector2i(x, y)
				if not engine.state.board.has(gc):
					out.append(gc)
	else:
		for c: Vector2i in engine.state.board.keys():
			out.append(c)
	return out


func _on_board_click(cell: Vector2i) -> void:
	# **R71：只能在「我方回合」操作我方单位。**
	# 原来这里没有任何回合门禁 → 敌方 AI 正在行动时，玩家仍能点选/移动/攻击自己的单位，
	# 于是「AI 动到一半被我抢走操作权」，看起来就像 AI 在错误地操作我方没行动过的单位。
	# 放在函数最前面：技能选目标、点手牌上场等后续分支都一并被挡住（它们也全是玩家操作）。
	if engine == null or engine.over:
		return
	# R77：鸭语耳环自动出牌播送中 —— 玩家不能插手，否则会跟自动出牌抢手牌/格子。
	if engine.earring_autoplay_active():
		_say("鸭语耳环正在自动出牌，等它出完（%d 张）" % engine.earring_played)
		return
	if engine.current_side != GameEngine.SIDE_SELF:
		_say("现在是敌方回合，等对手行动完再操作自己的单位")
		return
	# 技能选目标模式
	if spell_pending >= 0:
		var sp_card: CardData = engine.state.hand[spell_pending]
		if spell_targets.has(cell):
			var idx := spell_pending
			# 潜入（9100）两段操作：第一段点己方盟友 → 第二段点目的格空格
			if sp_card.id == GameEngine.INFILTRATE_ID and _infiltrate_src.x < 0:
				_infiltrate_src = cell
				spell_targets = _infiltrate_dst_cells()
				if spell_targets.is_empty():
					_clear_selection()
					status_text = "潜入：没有可去的空格，技能仍在手牌"
				else:
					status_text = "潜入：再点一个空格作为目的地（右键取消）"
				queue_redraw()
				return
			# 双向传送（8061，R102）两段操作：第一段点单位甲 → 第二段点单位乙
			if sp_card.id == GameEngine.SWAP_UNITS_ID and _swap_src.x < 0:
				_swap_src = cell
				# 第二段的可选集合 = 场上**除它以外**的所有单位（敌我皆可）
				spell_targets = []
				for c: Vector2i in engine.state.board:
					if c != cell:
						spell_targets.append(c)
				spell_targets.sort()
				var picked: Placement = engine.state.unit_at(_swap_src)
				if spell_targets.is_empty():
					_clear_selection()
					status_text = "双向传送：场上只有 %s 一个单位，技能仍在手牌" % \
							picked.card.card_name
				else:
					status_text = "双向传送：已选 %s，再点另一个单位交换位置（右键取消）" % \
							picked.card.card_name
				queue_redraw()
				return
			_cast_spell(idx, cell, sp_card)
		else:
			_clear_selection()
			status_text = "已取消目标选择，技能仍在手牌"
		return
	# 已选中我方单位：执行移动 / 攻击 / 打 HP
	if selection != null and selection[0] == "board":
		var src: Vector2i = selection[1]
		# 再点自己一次 = 主动发动（熊 8004「回春」）
		if cell == src and engine.can_activate(src, GameEngine.SIDE_SELF):
			engine.activate(src, GameEngine.SIDE_SELF)
			_clear_selection()
			_net_send({"type": "action", "act": "activate", "args": [[src.x, src.y]]})
			return
		if hp_targets_arr.has(cell):
			_clear_selection()
			engine.attack_hp(src, cell)
			_net_send({"type": "action", "act": "hp",
					"args": [[src.x, src.y], [cell.x, cell.y]]})
			return
		if attack_targets_arr.has(cell):
			_clear_selection()
			engine.attack(src, cell)
			_net_send({"type": "action", "act": "attack",
					"args": [[src.x, src.y], [cell.x, cell.y]]})
			return
		if move_targets.has(cell):
			engine.move(src, cell)
			_net_send({"type": "action", "act": "move",
					"args": [[src.x, src.y], [cell.x, cell.y]]})
			var moved := engine.state.unit_at(cell)
			if moved != null and not moved.tapped:
				_select_board(cell)  # 已移动：只剩攻击或放弃
			else:
				_clear_selection()
			return
		# 没点中任何有效目标：说明可做的事（随后按放弃/切换处理）
		var sel_p := engine.state.unit_at(src)
		if sel_p != null and hp_targets_arr.size() + attack_targets_arr.size() + move_targets.size() > 0:
			_say("%s 到不了那里：绿色=可移动，红色=可攻击，深红=打HP" % sel_p.card.card_name)
	# 已移动未攻击的单位：非攻击操作 = 放弃攻击（横置）
	_pass_moved_pending()
	# 点自己半场空格 + 手牌选中 → 上场（分步给失败原因）
	var p := engine.state.unit_at(cell)
	if selection != null and selection[0] == "hand":
		var i: int = selection[1]
		var card := engine.state.hand[i]
		if not card.is_spell():
			# 带「交换」字段的卡（R101）可以落在己方已有单位上 → 顶回手；其余占用格拒绝
			if p != null and not engine.fence_merge_target(cell, card) \
					and not (card.has_affix(GameEngine.AFFIX_SWAP) \
					and p.owner == GameEngine.SIDE_SELF):
				_say("那格已有 %s，换一格放置" % p.card.card_name)
			elif FieldState.cell_owner(cell.x) != "self":
				_say("%s 只能放到自己半场（下 3 行）" % card.card_name)
			elif not engine.can_pay_card(card):
				_say("能量不足：%s 需要 %d，当前能量 %d" % [
						card.card_name, engine.cost_of(card), engine.energy_of()])
			else:
				_try_play_hand_card(i, cell)   # 英雄要先付「弃 4 张」的代价
				return
		else:
			_say("%s 是技能：再点一次手牌上的它来使用" % card.card_name)
		return
	# 选中战场单位
	if p != null and p.owner == GameEngine.SIDE_SELF and not p.tapped:
		_select_board(cell)
		status_text = "%s：绿色=移动 红色=攻击 深红=打HP" % p.card.card_name
		return
	_clear_selection()
	status_text = ""


func _on_right_click() -> void:
	# 乌鸦的回手面板：必须选一张（不接受取消）
	if engine.crow_pending:
		_say("乌鸦：必须从弃牌堆选择一张盟友回到手牌")
		return
	# 鲸鱼之怒的取牌面板：右键 = 放弃剩余的取牌（本效果可选）
	if engine.whale_pending:
		engine.whale_skip()
		status_text = "鲸鱼之怒：放弃剩余取牌"
		queue_redraw()
		return
	# 无尽黑暗 9114（R70）：**不能不选** → 右键/Esc 只提示，不取消（与乌鸦同款）
	if engine.endless_pending:
		_say("无尽黑暗：必须从手牌里选一张弃掉（不能不选）")
		return
	# 复活术的取牌面板：必须选一张（不接受取消）
	if engine.revive_pending:
		_say("复活术：必须从弃牌区选择一张盟友回到手牌")
		return
	if engine.foresight_mode:
		_say("预判：必须选择一个效果")
		return
	if engine.foresight_pick:
		_say("预判：必须从弃牌区选择一张费用为 0 的技能卡")
		return
	if engine.fate_pending:
		_say("拒绝命运：必须从弃牌区选 %d 张卡" % engine.fate_count)
		return
	# 英雄的弃牌代价面板：右键 = 取消支付（卡留在手牌）
	if _hero_pick_idx >= 0:
		var hero_nm := engine.state.hand[_hero_pick_idx].card_name
		_hero_pick_idx = -1
		_hero_pick_sel = []
		status_text = "已取消：%s 仍在手牌（未付代价）" % hero_nm
		queue_redraw()
		return
	_pass_moved_pending()  # 右键取消 = 已移动单位放弃攻击（横置）
	var pick_src := _picked_src()   # R102：两段式技能「已选的第一个单位」（潜伏/双向传送共用）
	_clear_selection()
	if pick_src.x >= 0 and engine.state.board.has(pick_src):
		# 明确告诉玩家"取消的是哪一个" —— 否则金黄标记消失后不知道刚才点的是谁。
		status_text = "已取消：%s 的选择已撤销，技能仍在手牌（右键取消）" % \
				engine.state.board[pick_src].card.card_name
	else:
		status_text = "已取消"


func _on_hover(pos: Vector2) -> void:
	## 悬停任何有信息的卡（战场/手牌/费用区/弃牌区）→ 左侧信息栏 + 状态栏。
	## 操作反馈保护期只保护状态栏文字；信息栏始终跟随悬停。
	# 英雄的弃牌代价面板开着时：不跟手牌/棋盘（面板挡在上面，避免信息栏乱跳）
	if _hero_pick_idx >= 0:
		_hover_card = null
		_hover_pl = null
		_hover_hand = -1
		return
	_hover_card = null
	_hover_pl = null
	_hover_hand = -1
	var tip := ""
	_hover_relic_tip = ""
	# ⓪ 区域浏览面板（效果区 / 敌方效果区 / 弃牌区）开着时：面板盖住了棋盘与手牌，
	#    只认面板里的卡 → 悬停哪张就在左侧信息栏看哪张，面板空白处什么都不显示。
	var zp := _zone_panel_cards()
	if not zp.is_empty():
		var zl := _zone_panel_layout(zp.size())
		for i in zp.size():
			if _zone_card_rect(i, zl).has_point(pos):
				var zc: CardData = zp[i]
				_hover_card = zc
				if Time.get_ticks_msec() >= _status_hold_until:
					status_text = "%s 费用%d（效果见左侧）" % [zc.card_name,
							engine.cost_of(zc)]
				return
		return
	# ① 战场单位（双方都可查看）
	for cell: Vector2i in engine.state.board:
		var rect := Rect2(GRID_X + cell.y * CELL, GRID_Y + cell.x * CELL, CELL, CELL)
		if rect.has_point(pos):
			var p: Placement = engine.state.board[cell]
			_hover_card = p.card
			_hover_pl = p
			tip = "%s 力%d 生%d 程%d 速%d" % [p.card.card_name,
					p.effective_power(), p.health, p.card.attack_range, p.card.move_speed]
			# R68：冰封 / 禁足是看不见的状态，悬停时直接说明「为什么它动不了」
			if p.frozen:
				tip += "　❄ 冰封（本回合不能行动）"
			elif p.rooted > 0:
				tip += "　⊥ 禁足（不能移动，仍可攻击）"
			# R76：沉睡是**挨打计数**（初始 2，每挨一下 -1，归零立刻能行动），
			# 不是回合计数 —— 所以要写清「还差几下」，玩家才知道该不该现在就打。
			if p.sleep_left > 0:
				tip += "　💤 沉睡（再挨 %d 下就醒，醒后立刻行动）" % p.sleep_left
			# R87：护盾 / 自我修复都是隐藏状态，悬停必须写明「为什么它没掉血」。
			if p.first_hit_shield:
				tip += "　🛡 能量屏障（**第一次受到的伤害为 0**，用完消失）"
			if p.regen > 0:
				tip += "　✚ 自我修复（每回合结束回 %d 血）" % p.regen
			if p.upgrade_stacks > 0:
				tip += "　改造 %d 层" % p.upgrade_stacks
			# R89：无限装甲（trait「改造供能」）——「本回合已用过 / 本回合还没用」是
			# 玩家必须能看到的信息（每回合一次的额度），否则会以为机制没生效。
			if p.card != null and p.card.traits.has(GameEngine.INF_ARMOR_TRAIT):
				if p.upgrade_feed_turn == engine.turn_total:
					tip += "　⟳ 本回合已供能（下回合再用改造刷新）"
				else:
					tip += "　⟳ 被改造时供一张 0 费改造牌"
			# 【字段系统 R91】列出这张卡**此刻生效**的字段（自动，不用为每个字段写一行）。
			# 读 `active_affixes`：疾行用掉一轮后、护盾用掉后都会自动从列表里消失。
			if p.card != null and not p.card.affixes.is_empty():
				for a in p.card.active_affixes(p.acts_left, p.first_hit_shield):
					tip += "　【%s】%s" % [CardData.affix_label(a),
						CardData.affix_desc(a)]
			break
	# ①b 场地（R84）：场地**不是单位**，上面那条循环查不到它 —— 挂在有场地、
	#   即使没单位的格子上，把 `trigger`（触发类型）显式写出来。
	#   这是 trigger 字段的**第一个消费者**：玩家在战场上就能看到「这格踩上去会发生什么」。
	if _hover_card == null and tip == "":
		for cell2: Vector2i in engine.state.field_effects:
			var frect := Rect2(GRID_X + cell2.y * CELL, GRID_Y + cell2.x * CELL, CELL, CELL)
			if not frect.has_point(pos):
				continue
			var fc: CardData = engine.state.field_at(cell2)
			if fc == null:
				continue
			_hover_card = fc
			var fc_aim := GameEngine.field_aim(fc)
			if GameEngine.is_persistent_field(fc):
				# 持续型：没有「触发类型」可言，它的口径就是持续生效。
				# ⚠️ **必须按生效对象分文案**（R88）：清泉是「双」→ 敌我双方都受益；
				# 维修间 / 改造工厂是「友」→ 只有自己人受益。写成统一的「敌我双方都算」
				# 会让玩家以为敌方也能占便宜，白往敌方半场放。
				var fc_who := "敌我双方都算"
				if fc_aim == GameEngine.FIELD_AIM_ALLY:
					fc_who = "只对自己的单位生效"
				tip = "场地「%s」（持续生效，%s）" % [fc.card_name, fc_who]
				if fc.traits.has(GameEngine.PERSIST_UPGRADE_TRAIT):
					tip += "　每回合获得改造 +1 力 / +1 血（可无限叠）"
			else:
				tip = "场地「%s」（敌人移动经过时触发并停止移动）" % fc.card_name
			if fc.trigger != "":
				tip += "　触发：%s" % fc.trigger
			break
	# ② 己方手牌（会重叠 → 从最上层往前找）
	if _hover_card == null:
		for i in range(engine.state.hand.size() - 1, -1, -1):
			if _hand_hit(i, pos):
				_hover_hand = i
				_hover_card = engine.state.hand[i]
				# 效果详情显示在左侧信息栏（自动换行），顶部状态栏只留简短提示
				tip = "%s 费用%d（效果见左侧）" % [_hover_card.card_name,
						_hover_card.cost]
				# R65：这张现在打出去能吃到额外效果 → 状态栏补一句金色高亮的理由
				var bonus_txt := engine.hand_bonus_text(_hover_card)
				if bonus_txt != "":
					tip += "　★ " + bonus_txt
				break
	# ③ 左栏：能量面板 / 效果区（正面朝上，可逐张悬停查看）
	if _hover_card == null:
		var energy_rect := Rect2(COST_X, COST_Y, TAP_W + 12, ENERGY_H)
		if energy_rect.has_point(pos):
			tip = "能量 %d：每回合 5 点，回合结束重置（不累积），出牌消耗" % engine.state.energy
	if _hover_card == null:
		var merged_eff := _merged_effects(engine.state.effects)
		for i in merged_eff.size():
			if _effect_rect(i).has_point(pos):
				var m: Dictionary = merged_eff[i]
				_hover_card = m["card"]
				var cnt: int = m["count"]
				tip = "效果区 %d/%d 种：%s%s（效果见左侧，点击查看全部）" % [i + 1,
						merged_eff.size(), _hover_card.card_name,
						" ×%d" % cnt if cnt > 1 else ""]
				break
	if _hover_card == null:
		var zone_rect := Rect2(COST_X, COST_Y + ENERGY_H, TAP_W + 12, GRID_H - ENERGY_H)
		if zone_rect.has_point(pos):
			if engine.state.effects.is_empty():
				tip = "效果区（空）：效果卡使用后放在这里，持续生效"
			else:
				tip = "效果区 %d 张，持续生效中（点击查看全部）" % engine.state.effects.size()
	# ③' 右栏：敌方效果区（开局启用，正面朝上，可逐张悬停查看）
	if _hover_card == null:
		var merged_ee := _merged_effects(engine.state.enemy_effects)
		for i in merged_ee.size():
			if _enemy_effect_rect(i).has_point(pos):
				var m: Dictionary = merged_ee[i]
				_hover_card = m["card"]
				var cnt: int = m["count"]
				tip = "敌方效果 %d/%d 种：%s%s（效果见左侧，点击查看全部）" % [i + 1,
						merged_ee.size(), _hover_card.card_name,
						" ×%d" % cnt if cnt > 1 else ""]
				break
	if _hover_card == null and _enemy_zone_rect().has_point(pos):
		if engine.state.enemy_effects.is_empty():
			tip = "敌方效果区（空）"
		else:
			tip = "敌方效果 %d 张，持续生效中（点击查看全部）" % engine.state.enemy_effects.size()
	# ③'' 右栏道具栏：悬停看道具描述（装不下时悬停「+N」摘要 → 提示点开看全部）
	if _hover_card == null:
		var rel_hit := false
		for i in engine.self_relics.size():
			if _relic_rect(i).has_point(pos):
				rel_hit = true
				var rel := RelicRepo.load_json().get_relic(engine.self_relics[i])
				if rel != null:
					# 道具描述可能很长（叠加态的鸭等）：完整说明走浮动折行面板，
					# 不再塞进工具栏一行（会横向溢出窗口）
					var note := RunState.relic_state_note(engine.self_relics[i])
					_hover_relic_tip = "「%s」（%s）%s%s" % [rel.relic_name,
							rel.source_label(), rel.desc,
							("\n" + note) if note != "" else ""]
				break
		if not rel_hit and tip == "" and _relic_zone_rect().has_point(pos):
			# 悬浮就能逐个看描述；装不下时才有「点开看全部」这条路
			tip = "道具 %d 个（悬浮看说明%s）" % [engine.self_relics.size(),
					"，点击查看全部" if _relic_bar_overflowed() else "，已全部列出"]
	# ④ 弃牌区：悬停顶牌详情
	if _hover_card == null:
		var discard_rect := Rect2(DISCARD_X, DISCARD_Y, CARD_W, CARD_H)
		if discard_rect.has_point(pos):
			var dis := engine.state.discard
			if dis.is_empty():
				tip = "弃牌区（空）：被击破/用掉/弃掉的卡会进这里"
			else:
				_hover_card = dis.back()
				tip = "弃牌区 %d 张，最新「%s」（点击浏览全部）" % [
						dis.size(), dis.back().card_name]
	# ⑤ 卡组：点击查看（相同卡合并，不泄露抽牌顺序）
	if _hover_card == null:
		var deck_rect := Rect2(DECK_X, DECK_Y, CARD_W, CARD_H)
		if deck_rect.has_point(pos):
			if engine.state.deck.is_empty():
				tip = "卡组（空）：抽牌堆用完了会把弃牌洗回来"
			else:
				tip = "卡组 %d 张（点击查看，不显示抽牌顺序）" % engine.state.deck.size()
	if tip != "" and Time.get_ticks_msec() >= _status_hold_until:
		status_text = tip


# ------------------------------------------------------------ 教程引导条

func _build_tut_bar() -> void:
	## 教程关卡的引导条：叠放在顶部对手手牌区上（教程对手不用手牌）。
	_tut_bar = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fff3d6")
	sb.border_color = Color("c8a03c")
	sb.set_border_width_all(2)
	_tut_bar.add_theme_stylebox_override("panel", sb)
	_tut_bar.position = Vector2(0, TUT_BAR_TOP)
	_tut_bar.size = Vector2(WINDOW_W, TUT_BAR_MAX_H)
	_tut_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_tut_bar.visible = false
	add_child(_tut_bar)

	_tut_title = Label.new()
	_tut_title.position = Vector2(12, 2)
	_tut_title.add_theme_font_size_override("font_size", 13)
	_tut_title.add_theme_color_override("font_color", Color("7a5200"))
	_tut_bar.add_child(_tut_title)

	_tut_prog = Label.new()
	_tut_prog.position = Vector2(WINDOW_W - 330, 2)
	_tut_prog.add_theme_font_size_override("font_size", 11)
	_tut_prog.add_theme_color_override("font_color", Color("c08a1a"))
	_tut_bar.add_child(_tut_prog)

	_tut_check = Label.new()
	_tut_check.position = Vector2(WINDOW_W - 190, 2)
	_tut_check.add_theme_font_size_override("font_size", 11)
	_tut_check.add_theme_color_override("font_color", Color("2e7d32"))
	_tut_bar.add_child(_tut_check)

	_tut_body = Label.new()
	_tut_body.position = Vector2(12, 20)
	_tut_body.size = Vector2(WINDOW_W - 170, 56)
	_tut_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tut_body.add_theme_font_size_override("font_size", 11)
	_tut_body.add_theme_color_override("font_color", Color("3d3325"))
	_tut_bar.add_child(_tut_body)

	_tut_task = Label.new()
	_tut_task.position = Vector2(12, TUT_BAR_MAX_H - 22)
	_tut_task.size = Vector2(WINDOW_W - 170, 20)
	_tut_task.add_theme_font_size_override("font_size", 11)
	_tut_task.add_theme_color_override("font_color", Color("a05a00"))
	_tut_bar.add_child(_tut_task)

	_tut_next_btn = Button.new()
	_tut_next_btn.text = "下一步 ▸"
	_tut_next_btn.position = Vector2(WINDOW_W - 148, 30)
	_tut_next_btn.size = Vector2(136, 28)
	_tut_next_btn.pressed.connect(_tut_advance)
	_tut_bar.add_child(_tut_next_btn)

	_tut_close_btn = Button.new()
	_tut_close_btn.text = "✓ 关闭引导条"
	_tut_close_btn.position = Vector2(WINDOW_W - 148, 64)
	_tut_close_btn.size = Vector2(136, 28)
	_tut_close_btn.pressed.connect(_tut_close)
	_tut_bar.add_child(_tut_close_btn)


func _build_level_menu() -> void:
	_level_menu = PopupMenu.new()
	for i in GameLevels.level_names().size():
		_level_menu.add_item(GameLevels.level_names()[i], i)
	_level_menu.id_pressed.connect(func(idx: int):
		load_level(GameLevels.builtin_levels()[idx]))
	add_child(_level_menu)
	level_btn.pressed.connect(func():
		_level_menu.position = level_btn.get_screen_position() + Vector2(0, level_btn.size.y)
		_level_menu.popup())


# ------------------------------------------------------------ 结算覆盖层 / 横幅 / 彩带 / 记录面板

func _build_over_panel() -> void:
	## 胜负结算覆盖层：弹出「再来一局 / 选关 / 回到标题」。
	_over_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.97)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(20.0)
	_over_panel.add_theme_stylebox_override("panel", sb)
	_over_panel.position = Vector2(GRID_X + GRID_W / 2 - 140, GRID_Y + GRID_H / 2 - 150)
	_over_panel.custom_minimum_size = Vector2(280, 0)
	_over_panel.visible = false
	add_child(_over_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_over_panel.add_child(box)
	_over_title = Label.new()
	_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_title.add_theme_font_size_override("font_size", 30)
	box.add_child(_over_title)
	var hint := Label.new()
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("666666"))
	box.add_child(hint)
	_over_hint = hint
	_over_btn_restart = Button.new()
	_over_btn_restart.text = "再来一局"
	_over_btn_restart.custom_minimum_size = Vector2(220, 40)
	_over_btn_restart.add_theme_font_size_override("font_size", 16)
	_over_btn_restart.pressed.connect(_on_over_restart)
	box.add_child(_over_btn_restart)
	_over_btn_level = Button.new()
	_over_btn_level.text = "选关"
	_over_btn_level.custom_minimum_size = Vector2(220, 40)
	_over_btn_level.add_theme_font_size_override("font_size", 16)
	_over_btn_level.pressed.connect(func():
		_level_menu.position = _over_panel.get_screen_position() + Vector2(30, 60)
		_level_menu.popup())
	box.add_child(_over_btn_level)
	_over_btn_title = Button.new()
	_over_btn_title.text = "回到标题"
	_over_btn_title.custom_minimum_size = Vector2(220, 40)
	_over_btn_title.add_theme_font_size_override("font_size", 16)
	_over_btn_title.pressed.connect(_on_back_to_title)
	box.add_child(_over_btn_title)
	for b: Button in [_over_btn_restart, _over_btn_level, _over_btn_title]:
		b.pressed.connect(func(): sfx.play("click"))


func _on_over_restart() -> void:
	## 结算面板主按钮：
	##   * Boss 通关且有下一层 → 推进到下一层（满血 + 新地图）→ 起始道具三选一；
	##   * run 中（非 Boss 通关）→ 领取卡牌奖励回地图；
	##   * 其余（通关无下一层 / 失败 / 单关）→ 回标题。
	if RunState.run_active and _run_next_layer > 0:
		RunState.advance_layer(_run_next_layer)
		get_tree().change_scene_to_file("res://scenes/relic_pick.tscn")
	elif RunState.run_active and not _run_boss_win:
		RunState.reward_context = "battle"
		get_tree().change_scene_to_file("res://scenes/card_reward.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/title.tscn")


func _show_over(win: bool) -> void:
	_over_shown = true
	_run_next_layer = 0
	_over_hint.text = ""
	_over_hint.add_theme_color_override("font_color", Color("666666"))
	# 叠加态的鸭（6013）：本场消耗掉的复活概率写回 run（跨战斗永久保留）
	RunState.duck_revive_chance = engine.duck_revive_chance
	# 自愈（9065）：战斗结束后回复生命（写回 run 血量之前结算，才不会白回）
	if win:
		engine.battle_end_heal()
	var lvl: Dictionary = _cur_level if not _cur_level.is_empty() else {}
	var tier: int = int(lvl.get("tier", -1))
	if RunState.run_active:
		# 肉鸽 run 结算：写战斗记录（卡组内容 / 是否失败 / 最终血量）
		if win:
			RunState.hp = maxi(0, engine.state.hp_self)
			# 鸭梨（6019）：战斗内每次 HP 受伤累计的最大生命提升，写回 run（跨战斗保留）
			RunState.max_hp = maxi(RunState.max_hp, engine.state.max_hp_self)
			# 难度档位（R47）：0 档「宽松」→ 每场战斗胜利回复 3 点生命
			# （必须在写战斗记录 / 回放条目之前结算，记录里的血量才是治疗后的值）
			var bheal := RunState.battle_win_heal()
			var healed := RunState.heal(bheal) if bheal > 0 else 0
			if healed > 0:
				_over_hint.text = "难度 %d · %s：战斗结束回复 %d 点生命（当前 %d/%d）" % [
						RunState.difficulty, RunState.difficulty_name(), healed,
						RunState.hp, RunState.max_hp]
				_over_hint.add_theme_color_override("font_color", Color("1b5e20"))
			var node_type := str(RunState.pending_node.get("type", ""))
			RunState.on_battle_won(node_type)
			RunState.record_battle(repo, str(lvl.get("name", "?")), tier,
					true, RunState.hp)
			_run_boss_win = tier == GameLevels.TIER_BOSS
			RunState.reward_type = "boss" if _run_boss_win else "normal"
			# 精英 / Boss 掉落道具（不与已拥有的重复；奖励池掉空则不掉）。
			# Boss 通关无奖励页：当场发放；精英：奖励页弹出「掉落道具」弹窗，
			# 由玩家决定收下或跳过（可先浏览卡牌奖励再决定）。
			var dropped := RunState.offer_relic_drop(node_type)
			var rname := ""
			if dropped > 0:
				if _run_boss_win:
					RunState.claim_relic_drop()
				var rel := RelicRepo.load_json().get_relic(dropped)
				rname = rel.relic_name if rel != null else str(dropped)
			if _run_boss_win:
				# Boss 通关：本层打完了 —— 有下一层就推进（满血 + 新地图 + 起始道具
				# 三选一），没有下一层才结束整局 run。
				_run_next_layer = GameLayers.next_layer(RunState.current_layer)
			if _run_boss_win:
				if _run_next_layer > 0:
					_over_btn_restart.text = "通关%s！进入%s（恢复全部生命 + 起始道具三选一）%s" % [
							GameLayers.layer_name(RunState.current_layer),
							GameLayers.layer_name(_run_next_layer),
							"　｜　获得道具「%s」" % rname if dropped > 0 else ""]
				else:
					_over_btn_restart.text = ("通关！获得道具「%s」→ 返回标题" % rname) \
							if dropped > 0 else "通关！返回标题"
			else:
				_over_btn_restart.text = "领取奖励（有道具掉落待决定）" \
						if dropped > 0 else "领取奖励"
			_over_btn_restart.visible = true
			_over_btn_restart.disabled = false
			_over_btn_level.visible = false
			_over_btn_title.visible = false
			if _run_boss_win and _run_next_layer <= 0:
				RunState.end_run()   # 通关：run 结束（记录已写入）
		else:
			RunState.record_battle(repo, str(lvl.get("name", "?")), tier,
					false, maxi(0, engine.state.hp_self))
			RunState.end_run()
			_run_boss_win = false
			_over_btn_restart.visible = false
			_over_btn_level.visible = false
			_over_btn_title.text = "返回标题"
			_over_btn_title.visible = true
	else:
		# 单关/演示模式：胜利 → 剩余生命带回 run（下一场接着用）；失败 → 重置满血再来
		_run_boss_win = false
		if win:
			RunState.hp = maxi(0, engine.state.hp_self)
			RunState.max_hp = maxi(RunState.max_hp, engine.state.max_hp_self)
		else:
			RunState.reset(RunState.max_hp)
		_over_btn_restart.text = "再来一局"
		_over_btn_restart.visible = true
		_over_btn_level.visible = true
		_over_btn_title.text = "回到标题"
		_over_btn_title.visible = true
	if _net_mode:
		_net_send({"type": "bye"})
		_over_btn_restart.disabled = true   # 联机不能重开（同 Python 版）
	var sb := _over_panel.get_theme_stylebox("panel") as StyleBoxFlat
	sb.border_color = COL_WIN if win else COL_LOSE
	_over_title.text = "胜  利" if win else "失  败"
	_over_title.add_theme_color_override("font_color", COL_WIN if win else COL_LOSE)
	if ReplayLog.recording:
		ReplayLog.ev("battle_end", {"win": win,
				"hp": RunState.hp if win else maxi(0, engine.state.hp_self)})
		if not RunState.run_active:
			ReplayLog.finish("win" if win else "lose")   # 通关/失败：整局落盘
	_over_panel.visible = true
	sfx.play("win" if win else "lose")
	if win:
		_spawn_confetti()


func _spawn_confetti() -> void:
	## 胜利彩带：从棋盘上方撒下 70 条彩色纸屑。
	var palette := [Color("e63946"), Color("f4a261"), Color("2a9d8f"),
			Color("457b9d"), Color("ffb703"), Color("9b5de5")]
	for i in 70:
		_confetti.append({
			"pos": Vector2(randf_range(GRID_X - 30, GRID_X + GRID_W + 30),
					randf_range(-160, -8)),
			"vel": Vector2(randf_range(-24, 24), randf_range(90, 190)),
			"rot": randf_range(0, TAU),
			"vr": randf_range(-4.0, 4.0),
			"size": Vector2(randf_range(5, 9), randf_range(9, 16)),
			"col": palette[randi() % palette.size()],
		})


func _tick_confetti(delta: float) -> bool:
	var alive := false
	for c: Dictionary in _confetti:
		c.pos += c.vel * delta
		c.rot += c.vr * delta
		c.vel.y = minf(c.vel.y + 60.0 * delta, 260.0)
		if c.pos.y < WINDOW_H + 40:
			alive = true
	return alive


func _show_banner(text: String, col := Color("1d3557"), dur := 1100) -> void:
	_banner = {"text": text, "col": col, "start": _now(), "dur": dur}


func _whisper_suffix() -> String:
	## 状态栏后缀：本回合鸭之低语随机到的强化。
	return "（鸭之低语：%s）" % _whisper_txt if _whisper_txt != "" else ""


func _toggle_log() -> void:
	_log_visible = not _log_visible
	log_btn.text = "记录*" if _log_visible else "记录"
	queue_redraw()


# ------------------------------------------------------------ 战斗内地图总览（R64）
#
# 布局约定（**唯一来源就是这几个常量 + _mapview_view_rect**）：
#   面板 = 标题区(MAPVIEW_TOP) + 地图可视区 + 底部图例区(MAPVIEW_BOT)；
#   地图纵向 = 起点层(col 0)在**下**、Boss 层(col COLS-1)在**上**（与地图场景同向）；
#   层数 × MAPVIEW_COL_DY 的总高通常 > 可视区高 → 用 _map_scroll 纵向滚动。
const MAPVIEW_COL_DY := 46.0# 总览里每层的纵向间距（比地图场景紧凑得多）
const MAPVIEW_NODE_R := 11.0         # 总览节点半径
const MAPVIEW_SLOT_DX := 62.0# 总览槽位间距（5 槽 = 248px，横向塞得进面板）
const MAPVIEW_TOP := 92.0            # 面板内标题区高度（下面才是地图）
const MAPVIEW_BOT := 70.0            # 面板内底部图例区高度
const MAPVIEW_PAD := 16.0            # 地图内容上下留白（节点不贴边）


func _mapview_available() -> bool:
	## 能不能看地图：必须在 run 中且本局确实有地图（单关/演示模式没有地图可看）。
	return RunState.run_active and not RunState.map_columns.is_empty()


func _toggle_map() -> void:
	## 「地图」按钮 / M 键：开关战斗内的地图总览面板。
	## 单关与演示模式没有地图 → 按钮不可见，这里也直接忽略。
	if not _mapview_available():
		return
	# 互斥：地图与其它浏览面板不同时开（免得叠在一起看不清）
	_map_visible = not _map_visible
	if _map_visible:
		_discard_visible = false
		_effects_visible = false
		_enemy_effects_visible = false
		_deck_visible = false
		_relics_visible = false
		_log_visible = false
		_map_scroll = _mapview_scroll_max()   # 打开时视野对准玩家当前所在层
	queue_redraw()


func _mapview_panel_rect() -> Rect2:
	## 总览面板矩形（居中；整体比窗口小一圈，四边都留出背景）。
	var pw := minf(WINDOW_W - 220.0, 640.0)
	var ph := minf(WINDOW_H - 80.0, 660.0)
	return Rect2((WINDOW_W - pw) * 0.5, (WINDOW_H - ph) * 0.5, pw, ph)


func _mapview_view_rect() -> Rect2:
	## 地图**可视区**（标题区与图例区之间的那块）—— 节点位置与剔除都以它为准，
	## 避免「位置算一套、裁剪算另一套」导致节点被剔掉却还占着滚动高度。
	var pr := _mapview_panel_rect()
	return Rect2(pr.position.x, pr.position.y + MAPVIEW_TOP,
			pr.size.x, maxf(40.0, pr.size.y - MAPVIEW_TOP - MAPVIEW_BOT))


func _mapview_content_h() -> float:
	## 地图内容总高（未滚动）：层数 × 层间距 + 上下留白（层数直接读 RogueMap.COLS）。
	return (RogueMap.COLS - 1) * MAPVIEW_COL_DY + MAPVIEW_NODE_R * 2.0 + MAPVIEW_PAD * 2.0


func _mapview_view_h() -> float:
	## 兼容旧调用：可视区高度。
	return _mapview_view_rect().size.y


func _mapview_scroll_max() -> float:
	## 可滚动的最大距离（内容比视口矮时锁死为 0）。
	return maxf(0.0, _mapview_content_h() - _mapview_view_h())


func _mapview_node_pos(node: Dictionary) -> Vector2:
	## 节点在窗口里的坐标：**唯一入口**。
	## 纵向 = 起点层在下、Boss 层在上（col 越大越靠上，与地图场景同向）；
	## 横向按 slot 分布；纵向再加 _map_scroll（往下滚 = 看起点，往上滚 = 看 Boss）。
	var view := _mapview_view_rect()
	var col := int(node["col"])
	var slot := int(node.get("slot", 2))
	# 横向中线取可视区正中 → 面板尺寸变了也不会偏
	var x := view.position.x + view.size.x * 0.5 + (slot - 2) * MAPVIEW_SLOT_DX
	var y := view.position.y + view.size.y - MAPVIEW_PAD - MAPVIEW_NODE_R \
			- col * MAPVIEW_COL_DY + _map_scroll
	return Vector2(x, y)


func _mapview_find_node(id: int) -> Dictionary:
	for col_nodes in RunState.map_columns:
		for node in col_nodes:
			if int(node["id"]) == id:
				return node
	return {}


func _mapview_is_current(node: Dictionary) -> bool:
	return int(node["id"]) == RunState.current_node_id


func _mapview_is_next(node: Dictionary) -> bool:
	## 「下一步可走」：RunState.available_nodes 是唯一判定口（与地图场景点击判定同源）。
	for n in RunState.available_nodes():
		if int(n["id"]) == int(node["id"]):
			return true
	return false


func _draw_map_panel() -> void:
	## 战斗内地图总览：**只读**的全局地图 —— 看清自己在第几层、走过哪些节点、
	## 前面还有多少、顶层 Boss 是谁。战斗进行中不能在这里改路线，所以不可点节点。
	##数据全部来自 RunState（地图本体就存在那），这里只负责画。
	var pr := _mapview_panel_rect()
	# 背景遮罩（比面板本体先画，压暗战场让面板更清楚）
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	draw_rect(pr, Color("1b1c22"))
	draw_rect(pr, Color("6a6f7d"), false, 2.0)
	# 标题行：层名 + 进度 + 关闭提示
	_draw_string_center(_font_bold, 16, "冒 险 地 图（战斗中查看）",
			Vector2(pr.position.x + pr.size.x * 0.5, pr.position.y + 26.0), Color("e8e4da"))
	var cleared := RunState.cleared_ids.size()
	var total := 0
	for col_nodes in RunState.map_columns:
		total += col_nodes.size()
	_draw_string_center(_font, 12,
			"%s    已通过 %d / %d 个节点    生命 %d/%d    卡组 %d 张" % [
				GameLayers.layer_name(RunState.current_layer), cleared, total,
				RunState.hp, RunState.max_hp, RunState.deck_ids.size()],
			Vector2(pr.position.x + pr.size.x * 0.5, pr.position.y + 48.0), Color("b8b4aa"))
	_draw_string_center(_font, 11, "M / 地图 按钮 或 点击任意处关闭（战斗中不能改路线）· 滚轮上下翻",
			Vector2(pr.position.x + pr.size.x * 0.5, pr.position.y + 68.0), Color("8f8b80"))
	# 地图区可视范围：层数 × MAPVIEW_COL_DY（层数见 RogueMap.COLS）通常装不进面板高度
	# → 按可视矩形**逐节点剔除**（Godot 4 的 CanvasItem 没有 draw_set_clip，面板外的东西要自己跳掉）。
	var view := _mapview_view_rect()
	_draw_map_edges(view)
	_draw_map_nodes(view)
	# 滚动条（内容比视口高时）
	var smax := _mapview_scroll_max()
	if smax > 0.0:
		var track := Rect2(pr.position.x + pr.size.x - 12.0, view.position.y, 6.0, view.size.y)
		draw_rect(track, Color(1, 1, 1, 0.08), true)
		var kh := maxf(28.0, view.size.y * (view.size.y / _mapview_content_h()))
		var ky := track.position.y + (track.size.y - kh) * (_map_scroll / smax)
		draw_rect(Rect2(track.position.x, ky, track.size.x, kh), Color("a8d8ff"), true)
	# 底部图例
	_draw_map_legend(pr)


func _draw_map_edges(view: Rect2) -> void:
	## 层间连线：已走过 = 金，其余 = 暗蓝白（总览里不需要「可走」高亮，
	##当前位置与可走节点用节点本身的金环/绿环表示就够了）。
	## view 之外的两个端点都不在可视矩形里就整条跳过。
	var vpad := view.grow(MAPVIEW_NODE_R + 10.0)
	for col_nodes in RunState.map_columns:
		for node in col_nodes:
			var from := _mapview_node_pos(node)
			for nid in node["next"]:
				var tnode := _mapview_find_node(int(nid))
				if tnode.is_empty():
					continue
				var to := _mapview_node_pos(tnode)
				if not vpad.has_point(from) and not vpad.has_point(to):
					continue
				var done: bool = RunState.cleared_ids.has(int(node["id"]))
				draw_line(from, to,
						Color("e6c86a") if done else Color(0.70, 0.81, 1.00, 0.40),
						2.6 if done else 1.6, true)


func _draw_map_nodes(view: Rect2) -> void:
	var t := float(Time.get_ticks_msec()) * 0.004
	# Boss 名牌挂在节点上方约 30px 处，所以剔除时要多留这段余量
	var vpad := view.grow(MAPVIEW_NODE_R + 32.0)
	for col_nodes in RunState.map_columns:
		for node in col_nodes:
			var pos := _mapview_node_pos(node)
			if not vpad.has_point(pos):
				continue
			var id := int(node["id"])
			var type := str(node["type"])
			var done: bool = RunState.cleared_ids.has(id)
			var cur := _mapview_is_current(node)
			var nxt := _mapview_is_next(node)
			var base: Color = MAPVIEW_TYPE_COLORS.get(type, Color("888888"))
			draw_circle(pos, MAPVIEW_NODE_R, base.darkened(0.45))
			draw_circle(pos, MAPVIEW_NODE_R - 2.0, base.darkened(0.5) if done else base)
			var label: String = str(MAPVIEW_TYPE_GLYPHS.get(type, "?"))
			draw_string(_font_bold, pos + Vector2(-10, 5), label,
					HORIZONTAL_ALIGNMENT_CENTER, 20, 14,
					Color(1, 1, 1, 0.45) if done else Color("f7f4ec"))
			if cur:
				# 当前位置：金双环（与地图场景同一套「当前位置」标记）
				draw_arc(pos, MAPVIEW_NODE_R + 4.0, 0, TAU, 28, Color("f2c14e"), 2.2, true)
				draw_arc(pos, MAPVIEW_NODE_R + 7.0, 0, TAU, 28, Color("f2c14e", 0.45), 1.1, true)
				var cw := 66.0
				var crect := Rect2(pos.x - cw * 0.5, pos.y + MAPVIEW_NODE_R + 5.0, cw, 16.0)
				draw_rect(crect, Color(0.09, 0.09, 0.12, 0.9), true)
				draw_rect(crect, Color("f2c14e"), false, 1.1)
				draw_string(_font_bold, crect.position + Vector2(0, 12.5), "当前位置",
						HORIZONTAL_ALIGNMENT_CENTER, cw, 11, Color("f2c14e"))
			elif nxt:
				var pulse := 0.5 + 0.5 * sin(t * 3.0)
				draw_arc(pos, MAPVIEW_NODE_R + 3.0 + pulse * 1.6, 0, TAU, 28,
						Color(0.45, 0.9, 0.5, 0.45 + 0.30 * pulse), 2.0, true)
			if type == "boss":
				_draw_map_boss_chip(pos)


func _draw_map_boss_chip(pos: Vector2) -> void:
	## Boss 节点上方的名牌：名字源与地图场景一致（RunState.boss_pick）。
	var lv: Dictionary = RunState.boss_pick
	if lv.is_empty():
		lv = GameLevels.boss_level(RunState.current_layer)
	var text := "Boss：" + str(lv.get("name", ""))
	if text == "Boss：":
		return
	var w := maxf(text.length() * 12.0 + 16.0, 58.0)
	var h := 20.0
	var rect := Rect2(pos.x - w * 0.5, pos.y - MAPVIEW_NODE_R - 6.0 - h, w, h)
	draw_rect(rect, Color(0.10, 0.09, 0.13, 0.92), true)
	draw_rect(rect, Color("f2c14e"), false, 1.2)
	draw_string(_font_bold, rect.position + Vector2(0, 14.0), text,
			HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color("f7e6b0"))


func _draw_map_legend(pr: Rect2) -> void:
	## 底部图例：七种节点类型各一格，附「已通过 / 可走 / 当前位置」说明。
	var y := pr.position.y + pr.size.y - MAPVIEW_BOT + 22.0
	var x := pr.position.x + 14.0
	for type in ["start", "battle", "elite", "rest", "event", "chest", "boss"]:
		var base: Color = MAPVIEW_TYPE_COLORS.get(type, Color("888888"))
		draw_circle(Vector2(x + 6.0, y - 4.0), 6.0, base)
		draw_string(_font, Vector2(x + 16.0, y), str(RogueMap.TYPE_LABELS.get(type, type)),
				HORIZONTAL_ALIGNMENT_LEFT, 60, 12, Color("cfd3da"))
		x += 74.0
	draw_string(_font, Vector2(x + 4.0, y), "金环＝当前位置　绿环＝下一步可走",
			HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - (x - pr.position.x) - 8.0, 12, Color("9aa0aa"))


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	snd_btn.text = "音效:开" if sfx.enabled else "音效:关"
	if sfx.enabled:
		sfx.play("click")


func _tut_step() -> Dictionary:
	if _tutorial_finished or tutorial_step >= _tutorial.size():
		return {}
	return _tutorial[tutorial_step]


func _tut_update_bar() -> void:
	var step := _tut_step()
	if step.is_empty():
		_tut_bar.visible = false
		return
	_tut_bar.visible = true
	_tut_title.text = "%s · %s" % [_cur_level["name"], step["title"]]
	# 进度点：◆ 当前 ● 已走完 ○ 还没到
	var dots := ""
	for i in _tutorial.size():
		dots += "◆" if i == tutorial_step else ("●" if i < tutorial_step else "○")
	_tut_prog.text = "%s  步骤 %d/%d" % [dots, tutorial_step + 1, _tutorial.size()]
	_tut_body.text = str(step["text"])
	_tut_task.text = "▶ %s" % step["task"]
	_tut_check.text = ""
	# 高度按正文行数自适应（上限 TUT_BAR_MAX_H，不遮敌方后排教学卡）
	var lines: int = str(step["text"]).split("\n").size()
	var h: float = clampf(24.0 + lines * 14.0 + 26.0, 72.0, TUT_BAR_MAX_H)
	_tut_bar.size = Vector2(WINDOW_W, h)
	_tut_task.position.y = h - 22.0
	_tut_next_btn.position.y = h - 68.0
	_tut_close_btn.position.y = h - 34.0


func _tut_advance() -> void:
	if _tutorial_finished:
		return
	if tutorial_step < _tutorial.size() - 1:
		tutorial_step += 1
		_tut_update_bar()
	else:
		_tut_close()


func _tut_close() -> void:
	_tutorial_finished = true
	_tut_bar.visible = false
	status_text = "教程完成，自由对局！"
	queue_redraw()


func _tutorial_check(key: String) -> bool:
	## 教程步骤完成判定（对应 Python 版 levels.py 的 _check_* 函数）。
	var own: Array[Placement] = []
	for cell: Vector2i in engine.state.board:
		var p: Placement = engine.state.board[cell]
		if p.owner == GameEngine.SIDE_SELF:
			own.append(p)
	if key == "played":
		return not own.is_empty()
	if key == "moved":
		return own.any(func(p): return p.moved or p.tapped)
	if key == "tapped":
		return own.any(func(p): return p.tapped)
	if key == "dummy_hit":
		# 训练木桩受伤或已离场 = 发生过攻击
		for cell2: Vector2i in engine.state.board:
			var q: Placement = engine.state.board[cell2]
			if q.owner != GameEngine.SIDE_SELF and q.card.id == GameLevels._DUMMY_ID:
				return q.health < GameLevels._DUMMY_HEALTH
		return true  # 木桩不在场 = 已被摧毁
	if key == "fort_played":
		return own.any(func(p): return p.card.kind == "工事")
	if key == "spell_used":
		return engine.log.any(func(line): return str(line).begins_with("使用技能"))
	if key == "turn2":
		return engine.turn_number >= 2
	if key == "practiced":
		return not own.is_empty() or _tutorial_check("spell_used")
	if key == "attack_mode":
		return selection != null and selection[0] == "board" \
				and not attack_targets_arr.is_empty()
	if key.begins_with("card:"):
		var cid := int(key.substr(5))
		return own.any(func(p): return p.card.id == cid)
	if key.begins_with("moved_card:"):
		var nm := key.substr(11)
		return engine.log.any(func(line): return str(line).begins_with("%s 移动" % nm))
	return false


func _tut_poll() -> void:
	## 每帧轮询：当前步骤的完成条件满足 → 显示 ✓（不自动跳步）。
	var step := _tut_step()
	if step.is_empty():
		return
	var key := str(step["check"])
	_tut_check.text = "✓ 本步已完成" if key != "" and _tutorial_check(key) else ""


func _tut_pick_hand(cue_card: String) -> int:
	## 教程提示挑手牌：指定卡名优先；否则付得起 → 费用低 → 靠前。
	var hand := engine.state.hand
	if cue_card != "":
		for i in hand.size():
			if hand[i].card_name == cue_card:
				return i
	var best := -1
	for i in hand.size():
		if best < 0:
			best = i
			continue
		var pa := engine.can_pay_card(hand[i])
		var pb := engine.can_pay_card(hand[best])
		if pa != pb:
			if pa:
				best = i
		elif hand[i].cost < hand[best].cost:
			best = i
	return best


func _tut_play_cell() -> Vector2i:
	## 教程提示的目标空格：指定格优先；否则我方半场最前排第一个空格。
	var step := _tut_step()
	if step["cue_cell"] != null:
		return step["cue_cell"]
	for row in [3, 4, 5]:
		for col in FieldState.BOARD_COLS:
			var t := Vector2i(row, col)
			if not engine.state.board.has(t):
				return t
	return Vector2i(5, 0)


func _tut_unit_cell() -> Variant:
	## 教程提示操作的单位格：指定格优先；否则第一个未横置的我方单位。
	var step := _tut_step()
	if step["cue_cell"] != null:
		return step["cue_cell"]
	var fallback = null
	for cell: Vector2i in engine.state.board:
		var p: Placement = engine.state.board[cell]
		if p.owner == GameEngine.SIDE_SELF:
			if fallback == null:
				fallback = cell
			if not p.tapped:
				return cell
	return fallback


func _tutorial_cue_rects() -> Array:
	## 当前步骤的操作提示 → 一组琥珀色闪烁矩形（对应 Python 版 TutorialCue）。
	var step := _tut_step()
	if step.is_empty() or _tutorial_finished:
		return []
	var cue := str(step["cue"])
	var rects: Array = []
	match cue:
		GameLevels.CUE_OWN_HALF:
			rects.append(Rect2(GRID_X, GRID_Y + 3 * CELL, GRID_W, 3 * CELL))
		GameLevels.CUE_HAND:
			var n := engine.state.hand.size()
			if n > 0:
				var r0 := _hand_rect(0)
				var r1 := _hand_rect(n - 1)
				# 卡底沉出窗口，框只圈看得见的那一截
				rects.append(Rect2(r0.position,
						Vector2(r1.end.x - r0.position.x, WINDOW_H - r0.position.y)))
		GameLevels.CUE_COST:
			rects.append(Rect2(COST_X, COST_Y, TAP_W + 12, GRID_H))
		GameLevels.CUE_PLAY:
			var ci := _tut_pick_hand(str(step["cue_card"]))
			if ci >= 0:
				rects.append(_hand_cue_rect(ci))
			rects.append(_cell_rect(_tut_play_cell()))
		GameLevels.CUE_UNIT:
			var uc = _tut_unit_cell()
			if uc != null:
				rects.append(_cell_rect(uc))
		GameLevels.CUE_TAPPED:
			for cell: Vector2i in engine.state.board:
				var p: Placement = engine.state.board[cell]
				if p.owner == GameEngine.SIDE_SELF and p.tapped:
					rects.append(_cell_rect(cell))
					break
		GameLevels.CUE_FORT:
			for cell: Vector2i in engine.state.board:
				var p: Placement = engine.state.board[cell]
				if p.owner == GameEngine.SIDE_SELF and p.card.kind == "工事":
					rects.append(_cell_rect(cell))
					break
		GameLevels.CUE_SPELL:
			for i in engine.state.hand.size():
				if engine.state.hand[i].is_spell():
					rects.append(_hand_rect(i))
					break
		GameLevels.CUE_NEXT:
			rects.append(_control_rect(_tut_next_btn))
		GameLevels.CUE_END:
			rects.append(_control_rect(end_turn_btn))
	return rects


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(GRID_X + cell.y * CELL, GRID_Y + cell.x * CELL, CELL, CELL)


func _control_rect(c: Control) -> Rect2:
	## 控件在画布（本节点）坐标系里的矩形：父容器位置 + 控件位置。
	var parent := c.get_parent() as Control
	return Rect2(parent.position + c.position, c.size)


func _draw_tutorial_cue() -> void:
	var rects := _tutorial_cue_rects()
	if rects.is_empty():
		return
	var step := _tut_step()
	var label := str(step["cue_label"])
	var t := Time.get_ticks_msec() / 1000.0
	var alpha := 0.55 + 0.35 * sin(t * 5.0)
	var col := Color(1.0, 0.62, 0.0, alpha)
	for r: Rect2 in rects:
		draw_rect(r, col, false, 3.0)
	_draw_string_nw(_font_bold, 11, label,
			rects[0].position + Vector2(4, -2), Color("a05a00"))
	# 动态鼠标图标：按键侧压下 + 点击波纹（对应 Python 版 guide.draw_mouse_icon）
	var right_click: bool = label.contains("右键")
	var arrow: bool = str(step["cue"]) == GameLevels.CUE_NEXT \
			or str(step["cue"]) == GameLevels.CUE_END
	var focus: Rect2 = rects[0]
	var mouse_pos := Vector2(focus.get_center().x,
			focus.position.y + focus.size.y - 24.0)
	if focus.size.y > CELL * 2:  # 大区域（整片半场/整排手牌）放中上，别挡住目标
		mouse_pos.y = focus.position.y + 40
	_draw_mouse_icon(mouse_pos, right_click, t, arrow)


func _draw_mouse_icon(pos: Vector2, right_click: bool, t: float, arrow: bool) -> void:
	## 简化版鼠标图标：22×32 白色鼠标，按下的那半键高亮 + 两道扩散波纹。
	var w := 22.0
	var h := 32.0
	var body := Rect2(pos - Vector2(w / 2, h / 2), Vector2(w, h))
	var cycle := fmod(t, 1.2) / 1.2          # 1.2 秒一个点击周期
	var pressed := cycle < 0.45
	var phase := cycle * 2.2                 # 波纹相位 0..1
	var col := Color("f77f00")
	# 波纹（从按键半边中心扩散，ease_out 收敛）
	var cx := body.position.x + (w * 0.72 if right_click else w * 0.28)
	var cy := body.position.y + 8
	for k in 2:
		var p: float = fposmod(phase + k * 0.5, 1.0)
		var r := 7.0 + 20.0 * (1.0 - pow(1.0 - p, 2.0))
		draw_arc(Vector2(cx, cy), r, 0, TAU, 24,
				Color(col.r, col.g, col.b, clampf(1.0 - p, 0.05, 1.0)), 2.0)
	# 指工具栏按钮的向上箭头
	if arrow:
		var tip := Vector2(body.get_center().x, body.position.y - 6)
		draw_line(tip, tip + Vector2(0, -16), Color("a05a00"), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(tip.x, tip.y - 24),
				Vector2(tip.x - 6, tip.y - 14), Vector2(tip.x + 6, tip.y - 14)]),
				Color("a05a00"))
	# 鼠标本体 + 左右键 + 滚轮
	draw_rect(body, Color.WHITE)
	draw_rect(body, Color("37474f"), false, 2.0)
	var split := body.position.y + h * 0.42
	var hit_dy := 2.0 if pressed else 0.0
	var active := col if pressed else Color("f2f2f2")
	# 左键半边
	var lrect := Rect2(body.position.x, body.position.y, w / 2 - 1, split - body.position.y + hit_dy)
	draw_rect(lrect, active if not right_click else Color("f2f2f2"))
	draw_rect(lrect, Color("37474f"), false, 1.0)
	# 右键半边
	var rrect := Rect2(body.position.x + w / 2 + 1, body.position.y, w / 2 - 1, split - body.position.y + hit_dy)
	draw_rect(rrect, active if right_click else Color("f2f2f2"))
	draw_rect(rrect, Color("37474f"), false, 1.0)
	# 滚轮
	draw_rect(Rect2(body.get_center().x - 2, body.position.y + 3, 4, 8), Color("cfd8dc"))


# ------------------------------------------------------------ 回合流程

func _on_end_turn() -> void:
	if engine == null or engine.over:
		return
	if engine.crow_pending:
		_say("乌鸦：请先选择一张要回到手牌的盟友")
		return
	if engine.whale_pending:
		_say("鲸鱼之怒：请先点一张卡取回，或点「不选了」结束取牌")
		return
	if engine.endless_pending:
		_say("无尽黑暗：请先从手牌里选一张弃掉（不能不选）")
		return
	if engine.revive_pending:
		_say("复活术：请先选择一张要回到手牌的盟友")
		return
	if engine.foresight_mode or engine.foresight_pick:
		_say("预判：请先完成选择")
		return
	if engine.fate_pending:
		_say("拒绝命运：请先从弃牌区选 %d 张卡" % engine.fate_count)
		return
	if _net_mode:
		# 联机：发给对方 → 本机进入对方回合 → 等待回放
		if engine.current_side != GameEngine.SIDE_SELF or _net_replaying:
			status_text = "等待 %s 行动…" % NetSession.opp_name
			return
		_pass_moved_pending()
		_net_send({"type": "end_turn"})
		_clear_selection()
		engine.end_turn()
		if not engine.over:
			status_text = "等待 %s 行动…" % NetSession.opp_name
		queue_redraw()
		return
	if engine.current_side != GameEngine.SIDE_SELF:
		return
	_pass_moved_pending()
	_clear_selection()
	engine.end_turn()
	if engine.over:
		queue_redraw()
		return
	if not engine.ai_enabled:
		# 教程关：对手不行动，直接轮回我方
		engine.end_turn()
		status_text = "第 %d 回合：能量重置为 5，抽 5 张%s" % [engine.turn_number, _whisper_suffix()]
		_show_banner("我方回合 · 第 %d 回合" % engine.turn_number, Color("1b5e20"))
		sfx.play("turn")
		queue_redraw()
		return
	status_text = "对手回合…"
	_show_banner("对手回合", Color("8a2b2b"))
	sfx.play("turn")
	queue_redraw()
	_ai_timer.start()


func _ai_step() -> void:
	if engine.over:
		_ai_timer.stop()
		status_text = "对局结束：%s（%s）" % [engine.result, engine.result_reason]
		queue_redraw()
		return
	var queue := engine.ai_action_queue()
	if queue.is_empty():
		_ai_timer.stop()
		engine.end_turn()
		if not engine.over:
			status_text = "第 %d 回合：能量重置为 5，抽 5 张%s" % [engine.turn_number, _whisper_suffix()]
			_show_banner("我方回合 · 第 %d 回合" % engine.turn_number, Color("1b5e20"))
			sfx.play("turn")
		queue_redraw()
		return
	engine.run_ai_unit(queue[0])
	queue_redraw()


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	if engine == null:
		return
	# 背景：铺满整个控件
	if _bg_tex != null:
		draw_texture_rect(_bg_tex, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	# 屏幕震动：棋盘相关绘制整体偏移（面板/结算不受影响）
	var shook := false
	if _now() < _shake_until:
		draw_set_transform(_shake_offset())
		shook = true
	_draw_grid()
	_draw_opponent_hand()
	_draw_cost_zone()
	_draw_deck_and_discard()
	_draw_attack_fx()
	_draw_board_cards()
	_draw_dying()
	_draw_flashes()
	_draw_ghosts()
	_draw_highlights()
	_draw_hp_banner()
	_draw_enemy_effects()
	_draw_bursts()
	_draw_wake_rings()
	_draw_floaters()
	if shook:
		draw_set_transform(Vector2.ZERO)  # 结束震动，后续 UI 不抖
	_draw_hand()
	_draw_drag()
	_draw_info_panel()
	if _log_visible:
		_draw_log_panel()
	if _map_visible:
		_draw_map_panel()
	if _discard_visible:
		_draw_discard_panel()
	if _deck_visible:
		_draw_zone_panel("卡组 %d 张（相同卡合并，不显示抽牌顺序）" % engine.state.deck.size(),
				_zone_panel_cards(), _zone_panel_counts())
	if _effects_visible:
		_draw_zone_panel("效果区 %d 张（同名合并，正面朝上，持续生效中）" % engine.state.effects.size(),
				_zone_panel_cards(), _zone_panel_counts())
	if _enemy_effects_visible:
		_draw_zone_panel("敌方效果 %d 张（同名合并，开局启用，持续生效中）" % engine.state.enemy_effects.size(),
				_zone_panel_cards(), _zone_panel_counts())
	if _relics_visible:
		_draw_relic_panel()
	_draw_relic_tip_panel()
	_draw_tutorial_cue()
	_draw_confetti()
	_draw_banner()
	# 英雄的弃牌代价面板：画在横幅**之后**（回合横幅不能盖住面板）
	if _hero_pick_idx >= 0:
		_draw_hero_pick()
	# 乌鸦的回手面板：同样画在横幅之后
	if engine.crow_pending:
		_draw_crow_pick()
	# 鲸鱼之怒的取牌面板：同样画在横幅之后
	if engine.whale_pending:
		_draw_whale_pick()
	# 无尽黑暗的弃牌面板（R70）：同样画在横幅之后
	if engine.endless_pending:
		_draw_endless_pick()
	# 复活术的取牌面板：同样画在横幅之后
	if engine.revive_pending:
		_draw_revive_pick()
	if engine.foresight_mode:
		_draw_foresight_mode()
	if engine.foresight_pick:
		_draw_foresight_pick()
	if engine.fate_pending:
		_draw_fate_pick()
	if engine.over:
		_draw_game_over()


func _art(card: CardData, rect: Rect2) -> void:
	var tex := CardFace.art_for(card.id)
	if tex == null:
		return
	# 保持比例放进插图区
	var tr := CardFace.fit_rect(tex.get_size(), rect)
	draw_texture_rect(tex, tr, false)


func _draw_card_face(card: CardData, rect: Rect2, hp: int, selected: bool, is_tapped: bool,
		cost_override := -1, power_override := -1) -> void:
	## 卡面一律按 rect 完整排版（含手牌）—— 卡底沉出窗口下沿的那截由视口裁掉，
	## 卡面内容**不做**任何偏移补偿：卡片是一个整体，被挡住就挡住。
	## cost_override >= 0 且不等于卡面费用 → 在费用圆上重画**绿色**数字，
	## 让玩家一眼看出「这张卡现在更便宜」（协同攻击等动态减费）。
	## power_override >= 0 → 用实际力量重画左下角标（战场单位传 effective_power()）。
	CardFace.draw(self, card, rect, hp, selected, is_tapped, _font, _font_bold, power_override)
	if not card.x_cost and cost_override >= 0 and cost_override != card.cost:
		var k := rect.size.y / CardFace.CARD_H_DESIGN
		var cost_r := 7.0 * k
		var cost_c := rect.position + Vector2(cost_r + 3, cost_r + 3)
		draw_circle(cost_c, cost_r, COL_COST_LOW_BG)
		_draw_string_center(_font_bold, int(9 * k), str(cost_override), cost_c, COL_COST_LOW_FG)


func _draw_card_back(rect: Rect2, tags := "") -> void:
	if _back_tex != null:
		draw_texture_rect(_back_tex, rect, false)
	else:
		draw_rect(rect, Color.BLACK)
		var inset: float = minf(rect.size.x, rect.size.y) * 0.18
		draw_line(rect.position + Vector2(inset, inset),
				rect.end - Vector2(inset, inset), Color.WHITE, 2.0)
		draw_line(Vector2(rect.end.x - inset, rect.position.y + inset),
				Vector2(rect.position.x + inset, rect.end.y - inset), Color.WHITE, 2.0)
	draw_rect(rect, Color("20283f"), false, 1.5)


func _draw_string_center(font: Font, px: int, text: String, center: Vector2, col: Color,
		outline := 0, outline_col := Color(1, 1, 1)) -> void:
	if px < 7:
		px = 7
	# Godot 4 在 width=-1（不换行）时会忽略对齐参数，文字会从 pos 点向右延伸（即左对齐）。
	# 因此这里手动按文本宽度计算偏移，使文字真正以 center 为中心居中。
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pos := Vector2(center.x - w * 0.5, center.y + px * 0.36)
	if outline > 0:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
				outline, outline_col)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw_string_nw(font: Font, px: int, text: String, pos: Vector2, col: Color,
		outline := 0, outline_col := Color(1, 1, 1)) -> void:
	if px < 7:
		px = 7
	if outline > 0:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
				outline, outline_col)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw_grid() -> void:
	_draw_string_center(_font_bold, 9, "战场", Vector2(GRID_X + GRID_W / 2, GRID_Y - 12), Color("555555"))
	for row in FieldState.BOARD_ROWS:
		for col in FieldState.BOARD_COLS:
			var rect := Rect2(GRID_X + col * CELL, GRID_Y + row * CELL, CELL, CELL)
			draw_rect(rect, Color(1, 1, 1, 0.02))
			draw_rect(rect, COL_CELL_LINE, false, 1.0)
	# 场地效果（R74）：画在格子底纹之上、单位之下 —— 它不是单位，只是格子上的标记。
	_draw_field_markers()
	# 后排色罩 + 半场分界线
	draw_rect(Rect2(GRID_X, GRID_Y, GRID_W, CELL), COL_OPP_BACKROW)
	draw_rect(Rect2(GRID_X, GRID_Y + 5 * CELL, GRID_W, CELL), COL_OWN_BACKROW)
	var mid_y := GRID_Y + 3 * CELL
	draw_line(Vector2(GRID_X, mid_y), Vector2(GRID_X + GRID_W, mid_y), Color("666666"), 2.0)
	# 火墙术（9084）：正在燃烧的横行（引擎是唯一数据源，施放方下次回合开始自动熄灭）
	for fw_row in engine.fire_wall_rows():
		var fw_rect := Rect2(GRID_X, GRID_Y + fw_row * CELL, GRID_W, CELL)
		draw_rect(fw_rect, Color(1.0, 0.42, 0.10, 0.20))
		draw_rect(fw_rect, Color("ff6a00"), false, 2.0)
		_draw_string_center(_font_bold, 9, "火墙",
				Vector2(GRID_X + GRID_W - 18, GRID_Y + fw_row * CELL + 11), Color("ff6a00"))
	# 敌我框 + 单位标记
	for cell: Vector2i in engine.state.board:
		var p: Placement = engine.state.board[cell]
		var rect := Rect2(GRID_X + cell.y * CELL, GRID_Y + cell.x * CELL, CELL, CELL)
		draw_rect(rect, COL_OWN_FRAME if p.owner == GameEngine.SIDE_SELF else COL_ENEMY_FRAME, false, 3.0)
		if p.tapped:
			_draw_string_nw(_font_bold, 9, "→", rect.position + Vector2(CELL - 14, 14), Color("777777"))


func _board_has_pulsing_field() -> bool:
	## 场上**有没有会脉动的场地**（一次性场地）。R83：持续型场地（清泉）是静止的，
	## 只有一个清泉在场上时不需要逐帧重绘 —— 这是 `_process` 里的重绘判据。
	if engine == null or engine.state.field_effects.is_empty():
		return false
	for c: Vector2i in engine.state.field_effects:
		if not GameEngine.is_persistent_field(engine.state.field_at(c)):
			return true
	return false


func _draw_field_markers() -> void:
	## 场地效果标记（R74）：画在格子上的**角标 + 斜纹底**，不是一张卡。
	## 为什么这么画：场地**不是单位**（不能被攻击、不占位），所以不能画成卡面 ——
	## 画成卡面会让玩家以为那是个能被点掉的东西。用「斜纹底 + 右下角小标签」表达
	## 「这格挂着个一次性效果」，斜纹是「陷阱/机关」的通用视觉语汇。
	## 判据直接读 engine.state.field_effects（引擎是唯一数据源）。
	var t := float(_now()) / 1000.0
	for cell: Vector2i in engine.state.field_effects:
		var card: CardData = engine.state.field_at(cell)
		if card == null:
			continue
		var rect := Rect2(GRID_X + cell.y * CELL, GRID_Y + cell.x * CELL, CELL, CELL)
		var mine: bool = str(engine.state.field_owner.get(cell, "")) == GameEngine.SIDE_SELF
		# 持续型场地（清泉 8028，R83）用**冷色**（青蓝）+ 静止描边 ——
		# 一次性场地是琥珀/红 + 呼吸描边（=「活的、会被踩爆」）。两族必须一眼能分开：
		# 玩家看到脉动的就知道那是陷阱，看到静止的就知道那是长期挂着的效果区。
		var persistent := GameEngine.is_persistent_field(card)
		var col := (COL_FIELD_PERSIST if persistent
				else (COL_FIELD_SELF if mine else COL_FIELD_FOE))
		# 斜纹底（4 条45° 短线）
		for k in 4:
			var off := float(k) * CELL / 4.0
			draw_line(rect.position + Vector2(off, 0),
					rect.position + Vector2(0, off), Color(col.r, col.g, col.b, 0.30), 2.0)
		draw_rect(rect, col, false, 2.0)
		# 右下角小标签（场地名，缩到能塞进角里）
		var tag := card.card_name
		var px := 10
		while px > 7 and _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > CELL - 10.0:
			px -= 1
		_draw_string_nw(_font_bold, px, tag,
				rect.position + Vector2(5, CELL - 6), col, 3, Color(0.06, 0.05, 0.09))
		# 双场地标记（9108）：左上角加一个「×2」提示
		if int(engine.state.field_chains.get(cell, 0)) > 0:
			_draw_string_nw(_font_bold, 11, "×2",
					rect.position + Vector2(CELL - 26, 15), Color("ffd24a"), 3,
					Color(0.10, 0.06, 0.0))
		# R84：触发类型角标（一次性场地）。「范围伤害」这类标签太长塞不进 6 字宽的角，
		#   缩字号 + 靠左排；清泉是持续型、**没有** trigger，不画这个（别误导成「会被触发」）。
		if not persistent and card.trigger != "":
			var tpx := 9
			while tpx > 6 and _font.get_string_size(card.trigger,
					HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x > CELL - 8.0:
				tpx -= 1
			_draw_string_nw(_font_bold, tpx, card.trigger,
					rect.position + Vector2(4, 13), col, 3, Color(0.06, 0.05, 0.09))
	# 缓慢呼吸的高亮描边（提示「这是活的、会被触发」）—— 有场地时才需逐帧重绘。
	# ⚠️ **持续型场地不画这个**（R83）：清泉是长期挂着、不会因经过而触发的效果区，
	# 画脉动描边等于骗玩家「走过去它会炸」→ 误导走位。
	if not engine.state.field_effects.is_empty():
		var pulse := (sin(t * 2.2) + 1.0) * 0.5
		for cell2: Vector2i in engine.state.field_effects:
			if GameEngine.is_persistent_field(engine.state.field_at(cell2)):
				continue
			var r2 := Rect2(GRID_X + cell2.y * CELL, GRID_Y + cell2.x * CELL, CELL, CELL)
			draw_rect(r2, Color(1.0, 0.85, 0.35, 0.10 + pulse * 0.14), false, 2.0)


func _draw_board_cards() -> void:
	# 动画中的单位最后画（浮在其他卡之上）
	var animating: Array = []
	for pair: Array in engine.state.iter_board():
		var cell: Vector2i = pair[0]
		var p: Placement = pair[1]
		if _slides.has(p) or _attacks.has(p):
			animating.append(pair)
			continue
		_draw_board_unit(cell, p)
	for pair2: Array in animating:
		_draw_board_unit(pair2[0], pair2[1])


func _draw_board_unit(cell: Vector2i, p: Placement) -> void:
	var center := _display_center(p, cell)
	var selected: bool = selection != null and selection[0] == "board" and selection[1] == cell
	var w := TAP_W if p.tapped else CARD_W
	var h := TAP_H if p.tapped else CARD_H
	# 顶部状态徽标的行号：嘲讽 → 冰封 → 沉睡，按出现顺序往下排（共用底座 _draw_state_badge）
	var _badge_row := 0
	_draw_card_face(p.card, Rect2(center - Vector2(w, h) / 2.0, Vector2(w, h)),
			_show_hp(p, p.health), selected, p.tapped, -1, p.effective_power())
	if engine.absorbs_for_hp(p):
		# 替己方 HP 承伤的统一表现（森林守护 9037 / 以太守卫 9067 / 铁栅栏 9072）：
		# 判定直接问引擎 absorbs_for_hp()，保证「同一机制 = 同一特效」，不再各写各的。
		draw_arc(center, Vector2(w, h).length() * 0.5, 0, TAU, 30, COL_GUARD, 2.5)
	if p.card.traits.has(GameEngine.TAUNT_TRAIT):
		# 嘲讽（铁壁卫兵 1011 / 骷髅兵 1055）：脉冲橙环 + 「嘲讽」徽标，
		# 让「射程内有它就必须打它」这件事在战场上一眼可见。
		_draw_taunt_aura(center, w, h, 0)
		_badge_row = 1
	if p.frozen:
		# 冰封（R68：寒冰箭 9011 / 冰冻术士战吼 / 冻结陷阱 8013）：
		# 「下回合不能行动」是**看卡面看不出来**的隐藏状态 → 必须常驻可见。
		_draw_frozen_aura(center, w, h, _badge_row)
		_badge_row += 1
	if p.sleep_left > 0:
		# 沉睡（R63/R72 补特效；R76 改口径）：恶魔鸭 9116 初始沉睡 2，
		# 每挨一下 -1、**归零立刻恢复行动**。徽标写出「还差几下」而不是「几回合」。
		_draw_sleep_aura(center, w, h, p.sleep_left, _badge_row)
		_badge_row += 1
	if p.first_hit_shield:
		# 能量屏障（8033，R87）：**首次受伤免掉**的一次性护盾。
		# 徽标同样交给字段系统（字段「护盾」），这里只留**呼吸青环**提示「还剩一次」——
		# 护盾是**隐藏状态**（卡面不写、图标上看不出来），必须有常驻可见提示。
		var sh_t := float(_now()) / 1000.0
		var sh_pulse := (sin(sh_t * 3.0) + 1.0) * 0.5
		var sh_r := Vector2(w, h).length() * 0.5 + 2.0 + sh_pulse * 2.5
		draw_arc(center, sh_r, 0.0, TAU, 40,
				Color(0.50, 0.84, 0.94, 0.40 + sh_pulse * 0.30), 2.0)
	# 【字段系统 R91】把这张卡**此刻生效**的字段逐个画在卡上方（轮流显示 = 依次往下排）。
	# ⚠️ **不硬编码任何字段**：判据是 `CardData.active_affixes()`，它读 `card.affixes`
	# 并按场上实况过滤（疾行用掉一轮就不显示、护盾用掉就不显示）。
	# 于是「过载给这张牌加了疾行」「能量屏障给了护盾」这类**后续赋予**的字段
	# 也会自动出现在战场上 —— 不需要在这里为每个字段写一段。
	_badge_row = _draw_affix_badges(center, w, h, p, _badge_row)


## 字段徽标（R91）：把 `p.card` 此刻生效的字段逐个画成顶部徽标。
## **「轮流显示」= 按顺序用 `_badge_row` 往下错开**，与冰封 / 沉睡 共用同一个底座
## （`_draw_state_badge`）—— 徽标多了不会互相盖住。
## 返回**下一个可用的 row**（调用方接着往下排）。
func _draw_affix_badges(center: Vector2, w: float, h: float, p: Placement,
		start_row: int) -> int:
	var row := start_row
	if p.card == null:
		return row
	for a in p.card.active_affixes(p.acts_left, p.first_hit_shield):
		# 嘲讽已经有脉冲橙环 + 徽标（`_draw_taunt_aura`），不重复画文字徽标。
		if a == GameEngine.AFFIX_TAUNT:
			continue
		var cols: Array = CardData.affix_colors(a)
		_draw_state_badge(center, w, h, row, CardData.affix_label(a),
				cols[0], cols[1], cols[1], Color(0.02, 0.02, 0.02, 0.75))
		row += 1
	return row


func _draw_frozen_aura(center: Vector2, w: float, h: float, badge_row: int) -> void:
	## 冰封特效（`Placement.frozen` 的唯一表现口）：冷蓝双环脉冲 + 顶部「冰封」徽标
	## + 卡面覆一层寒霜。判据直接读 `p.frozen`，保证「同一状态 = 同一特效」。
	## 与「禁足 rooted」（只是不能移动、仍可攻击）刻意做出形状差异，避免玩家看混。
	var t := float(_now()) / 1000.0
	var pulse := (sin(t * 2.6) + 1.0) * 0.5                 # 0..1 呼吸（比嘲讽慢）
	var base := Vector2(w, h).length() * 0.5
	# 卡面寒霜：半透明白蓝薄纱（tapped 时更明显，因为那时它真的动不了）
	draw_rect(Rect2(center - Vector2(w, h) / 2.0, Vector2(w, h)),
			Color(0.62, 0.84, 1.0, 0.16 + pulse * 0.10), true)
	# 双环：内环贴卡、外环外扩，冷蓝 → 近白
	var r1 := base + 1.0 + pulse * 2.0
	draw_arc(center, r1, 0.0, TAU, 44,
			Color(COL_FROZEN.r, COL_FROZEN.g, COL_FROZEN.b, 0.55 + pulse * 0.35), 2.5)
	draw_arc(center, r1 + 4.0, 0.0, TAU, 44,
			Color(0.85, 0.95, 1.0, 0.22 + pulse * 0.22), 1.5)
	# 四角冰晶：短斜线，随呼吸伸缩
	var arm := 5.0 + pulse * 3.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := center + Vector2(w / 2.0 * sx, h / 2.0 * sy)
			var dir := Vector2(-sx, 0.0)
			var dir2 := Vector2(0.0, -sy)
			draw_line(corner, corner + dir * arm, Color(0.88, 0.97, 1.0, 0.75), 2.0)
			draw_line(corner, corner + dir2 * arm, Color(0.88, 0.97, 1.0, 0.75), 2.0)
	_draw_state_badge(center, w, h, badge_row, "冰封",
			Color(0.04, 0.16, 0.30, 0.92), COL_FROZEN,
			Color(0.90, 0.98, 1.0), Color(0.02, 0.09, 0.18))


func _draw_sleep_aura(center: Vector2, w: float, h: float, left: int, badge_row: int) -> void:
	## 沉睡特效（`Placement.sleep_left` 的唯一表现口）：**紫色**脉冲环（与冰封的冷蓝
	## 明显区分）+ 卡面暗紫薄纱 + 右上角飘「Zzz」+ 顶部「沉睡 N」徽标。
	## 徽标**写出还差几下**是刻意的：沉睡的代价是「白挨几下」，
	## 玩家得能一眼判断「现在打它值不值」（R76：每挨一下沉睡 -1、打空立刻能行动），
	## 光写「沉睡」等于把这个决策藏起来。
	var t := float(_now()) / 1000.0
	var pulse := (sin(t * 1.7) + 1.0) * 0.5                # 0..1 呼吸（比冰封更慢 = 睡得更沉）
	var base := Vector2(w, h).length() * 0.5
	draw_rect(Rect2(center - Vector2(w, h) / 2.0, Vector2(w, h)),
			Color(0.42, 0.24, 0.70, 0.18 + pulse * 0.10), true)
	var r1 := base + 2.0 + pulse * 2.5
	draw_arc(center, r1, 0.0, TAU, 44,
			Color(COL_SLEEP.r, COL_SLEEP.g, COL_SLEEP.b, 0.50 + pulse * 0.35), 2.5)
	draw_arc(center, r1 + 5.0, 0.0, TAU, 44,
			Color(0.86, 0.76, 1.0, 0.20 + pulse * 0.20), 1.5)
	# 「Zzz」：三个字母依次向上飘并淡出（相位错开），卡在右上角内侧。
	for i in 3:
		var ph := fposmod(t * 0.55 - float(i) * 0.33, 1.0)
		var zpos := center + Vector2(w / 2.0 - 12.0 - float(i) * 3.0,
				-h / 2.0 + 14.0 - ph * 22.0)
		var za := (1.0 - ph) * 0.9
		var zs := 13 - i * 2
		_draw_string_center(_font_bold, zs, "Z", zpos,
				Color(0.90, 0.82, 1.0, za), 2, Color(0.20, 0.10, 0.34, za * 0.8))
	_draw_state_badge(center, w, h, badge_row, "沉睡 %d" % left,
			Color(0.13, 0.07, 0.24, 0.92), COL_SLEEP,
			Color(0.93, 0.86, 1.0), Color(0.08, 0.04, 0.16))


func _draw_state_badge(center: Vector2, w: float, h: float, row: int, text: String,
		bg: Color, border: Color, fg: Color, shadow: Color) -> void:
	## 战场单位顶部**状态徽标**的共用底座：嘲讽 / 冰封 / 沉睡三者位置完全相同，
	## 靠 `row`（第几个状态）往下错开 —— 各自算偏移早晚会在「三状态同时成立」时重叠，
	## 重叠 = 既有信息被盖掉，等于没显示。row 0 压在卡上沿（半内半外），
	## 之后每个往下挪一个徽标高。
	var bw := maxf(40.0, 14.0 + float(text.length()) * 11.0)
	var bh := 19.0
	var badge := Rect2(center + Vector2(-bw / 2.0,
			-h / 2.0 - bh * 0.45 + float(row) * (bh + 2.0)), Vector2(bw, bh))
	draw_rect(badge, bg, true)
	draw_rect(badge, border, false, 2.0)
	_draw_string_center(_font_bold, 12, text, badge.position + badge.size / 2.0, fg, 3, shadow)


func _draw_taunt_aura(center: Vector2, w: float, h: float, badge_row: int) -> void:
	## 嘲讽特效：外圈脉冲光环 + 顶部「嘲讽」徽标 —— 敌方单位射程内有它就必须打它。
	var t := float(_now()) / 1000.0
	var pulse := (sin(t * 3.4) + 1.0) * 0.5                  # 0..1 呼吸
	var base := Vector2(w, h).length() * 0.5
	var r := base + 3.0 + pulse * 5.0
	var a := 0.50 + pulse * 0.45
	draw_arc(center, r, 0.0, TAU, 48, Color(COL_TAUNT.r, COL_TAUNT.g, COL_TAUNT.b, a), 3.5)
	draw_arc(center, r + 5.0, 0.0, TAU, 48,
			Color(1.0, 0.78, 0.35, a * 0.40), 1.5)
	# 顶部徽标
	_draw_state_badge(center, w, h, badge_row, "嘲讽",
			Color(0.20, 0.11, 0.02, 0.92), Color(1.0, 0.62, 0.12, 0.95),
			Color(1.0, 0.84, 0.40), Color(0.12, 0.06, 0.01))


func _board_has_taunt() -> bool:
	## 棋盘上是否有带「嘲讽」的单位（有 → _process 需要逐帧重绘来驱动脉冲）。
	for cell: Vector2i in engine.state.board:
		if engine.state.board[cell].card.traits.has(GameEngine.TAUNT_TRAIT):
			return true
	return false


func _board_has_shield() -> bool:
	## 棋盘上是否有带「能量屏障」（首次受伤免掉）护盾的单位 —— 护盾环是脉冲动画，
	## 需要逐帧重绘（R87）。判据读 `Placement.first_hit_shield`。
	if engine == null:
		return false
	for _c: Vector2i in engine.state.board:
		if engine.state.board[_c].first_hit_shield:
			return true
	return false


func _board_has_frozen() -> bool:
	## 棋盘上是否有被冰封的单位（冰封环是脉冲动画 → 需要逐帧重绘）。
	for _cell: Vector2i in engine.state.board:
		if engine.state.board[_cell].frozen:
			return true
	return false


func _board_has_sleep() -> bool:
	## 棋盘上是否有沉睡中的单位（沉睡环 + 飘 Zzz 是动画 → 需要逐帧重绘）。
	for _cell: Vector2i in engine.state.board:
		if engine.state.board[_cell].sleep_left > 0:
			return true
	return false


func _draw_dying() -> void:
	## 垂死卡：引擎已把它移出场，但为了让「先受伤害 → 再消失」的次序看得见，
	## 在命中演出结束前仍在原位把它画出来（叠一层淡红表示已归零）。
	for d: Dictionary in _dying:
		var cell: Vector2i = d.cell
		var center := _cell_center(cell)
		var rect := Rect2(center - Vector2(CARD_W, CARD_H) / 2.0, Vector2(CARD_W, CARD_H))
		_draw_card_face(d.card as CardData, rect, 0, false, false)
		draw_rect(rect, Color(0.85, 0.12, 0.1, 0.30))


# ------------------------------------------------------------ 动画

func _replay_tick() -> void:
	## 回放驱动（R46）：按录像逐条执行玩家动作；AI 与结算由引擎确定性重建。
	## 空格切换倍速；战斗结束自动按结算面板主按钮继续整局流程。
	if not ReplayLog.playing or engine == null:
		return
	if _now() < _replay_next_at:
		return
	if engine.over:
		# 结算面板出现后自动点主按钮（领奖励 / 进下一层 / 返回标题）
		if _over_shown and _over_panel.visible:
			_replay_next_at = _now() + int(ReplayLog.delay(1600.0))
			if _over_btn_restart.visible:
				_over_btn_restart.pressed.emit()
			else:
				_over_btn_title.pressed.emit()
		return
	var e := ReplayLog.peek()
	if e.is_empty() or str(e.get("k", "")) != "act":
		return   # 其余条目（battle_end 等）由对应时机消费
	# 玩家回合才执行（回合之间等 AI 动作跑完；面板类操作随时可执行）
	var panel_f: bool = str(e.get("f", "")) in ["revive_recall", "whale_pick",
			"whale_skip", "crow_recall", "foresight_choose", "foresight_pick_card",
			"fate_pick", "endless_pick"]
	if not panel_f and engine.current_side != GameEngine.SIDE_SELF:
		return
	var f := str(e.get("f", ""))
	var a: Array = e.get("a", [])
	ReplayLog.advance()
	_replay_next_at = _now() + int(ReplayLog.delay(1400.0 if f == "end_turn" else 900.0))
	_clear_selection()
	match f:
		"end_turn":
			_on_end_turn()
		"play_from_hand":
			engine.play_from_hand(int(a[0]), ReplayLog.vec(a[1]))
		"play_hero":
			engine.play_hero_from_hand(int(a[0]), ReplayLog.vec(a[1]),
					a[2] if a.size() > 2 else [])
			_hero_pick_idx = -1
			_hero_pick_sel = []
		"use_spell":
			engine.use_spell(int(a[0]), ReplayLog.vec_or_null(a[1]))
		"use_effect":
			engine.use_effect(int(a[0]))
		"cast_infiltrate":
			engine.cast_infiltrate(int(a[0]), ReplayLog.vec(a[1]), ReplayLog.vec(a[2]))
		"cast_swap_units":
			engine.cast_swap_units(int(a[0]), ReplayLog.vec(a[1]), ReplayLog.vec(a[2]))
		"move":
			engine.move(ReplayLog.vec(a[0]), ReplayLog.vec(a[1]))
		"attack":
			engine.attack(ReplayLog.vec(a[0]), ReplayLog.vec(a[1]))
		"attack_hp":
			engine.attack_hp(ReplayLog.vec(a[0]), ReplayLog.vec(a[1]))
		"activate":
			engine.activate(ReplayLog.vec(a[0]))
		"pass":
			engine.pass_attack(ReplayLog.vec(a[0]))
		"revive_recall":
			engine.revive_recall(int(a[0]))
		"whale_pick":
			engine.whale_pick(int(a[0]))
		"whale_skip":
			engine.whale_skip()
		"endless_pick":
			# 无尽黑暗 9114（R70）：回放里复现「弃掉手牌 idx」这一步
			engine.endless_pick(int(a[0]))
		"crow_recall":
			engine.crow_recall(int(a[0]))
		"foresight_choose":
			engine.foresight_choose(int(a[0]))
		"foresight_pick_card":
			engine.foresight_pick_card(int(a[0]))
		"fate_pick":
			engine.fate_pick(int(a[0]))
		_:
			pass
	queue_redraw()


func _now() -> int:
	return Time.get_ticks_msec()


func _anim_end_for(p: Placement, cap_ms := 900) -> int:
	## 该单位身上「已排队动画」的结束时刻 —— 新动作排到它后面，避免后一个动作
	## 把前一段演出整段吞掉（AI 一步内连做移动+攻击时最明显）。
	## 上限 cap_ms：多动单位连续行动时不让队列越积越长，最多推迟这么久。
	var n0 := _now()
	var until := n0
	if _slides.has(p):
		var s: Dictionary = _slides[p]
		until = maxi(until, int(s.start) + int(s.dur))
	if _attacks.has(p):
		var a0: Dictionary = _attacks[p]
		until = maxi(until, int(a0.start) + int(a0.dur))
	return mini(until, n0 + cap_ms)


func _freeze_hp(key: Variant, dmg: int) -> void:
	## 记录一笔「尚未在命中演出中体现」的伤害：卡面 / HP 横幅数字冻结在扣血前，
	## 等对应的 hit / hp_hit 定时特效触发才移除这一笔，数字才往下掉。
	if dmg <= 0:
		return
	if not _hp_pending.has(key):
		_hp_pending[key] = []
	(_hp_pending[key] as Array).append(dmg)


func _show_hp(key: Variant, actual: int) -> int:
	## 取某把「卡面 / HP 横幅」的显示数字：实际值 + 尚未演出的伤害之和（即扣血前的值）。
	if not _hp_pending.has(key):
		return actual
	var s := 0
	for x in (_hp_pending[key] as Array):
		s += int(x)
	return actual + s


func _drop_hp(key: Variant) -> void:
	## 命中演出到点：移除最早一笔待扣伤害（数字自此开始往下掉）。
	if not _hp_pending.has(key):
		return
	var arr: Array = _hp_pending[key] as Array
	if not arr.is_empty():
		arr.pop_front()
	if arr.is_empty():
		_hp_pending.erase(key)


func _display_center(p: Placement, cell: Vector2i) -> Vector2:
	## 单位当前显示位置：静态格心 / 滑动插值 / 攻击突进。
	## 只认「已开始」的那一段：排队中的动画（start 未到）不参与，
	## 否则它会盖住正在播的动作，看起来就是「一闪而过」。
	var base := _cell_center(cell)
	var n := _now()
	if _slides.has(p):
		var a: Dictionary = _slides[p]
		if n >= int(a.start):
			var t := clampf(float(n - int(a.start)) / int(a.dur), 0.0, 1.0)
			var e := 1.0 - pow(1.0 - t, 3.0)  # ease-out
			var pts: Array[Vector2] = []
			if a.has("pts"):
				pts = a.get("pts", [])
			if pts.size() < 2:
				return (a.from as Vector2).lerp(a.to as Vector2, e)
			# 逐格路径：整段按格数均分，每格内部单独 ease-out（看起来是一格一格走过去）
			var segs := pts.size() - 1
			var f := t * segs
			var si := mini(int(floor(f)), segs - 1)
			var e2 := 1.0 - pow(1.0 - clampf(f - si, 0.0, 1.0), 3.0)
			return pts[si].lerp(pts[si + 1], e2)
	if _attacks.has(p):
		var l: Dictionary = _attacks[p]
		if n >= int(l.start):
			var t2 := clampf(float(n - int(l.start)) / int(l.dur), 0.0, 1.0)
			var adir := l.dir as Vector2
			var asrc := l.src as Vector2
			var is_hp := str(l.get("kind", "unit")) == "hp"
			# 攻击者原地演出：后仰蓄力 → 发射时前倾后坐 → 缓缓回正（弹体负责飞行）
			# 直击 HP 是「冲锋撞击」：没有弹体，前冲幅度更大、撞击感更强。
			var back := -24.0 if is_hp else -22.0
			var push := 30.0 if is_hp else 10.0
			var off := 0.0
			if t2 < ATK_LAUNCH_T:
				var k := clampf((t2 - ATK_WINDUP_T) / (ATK_LAUNCH_T - ATK_WINDUP_T), 0.0, 1.0)
				off = back * sin(k * PI * 0.5)           # 后仰蓄力
			elif t2 < ATK_IMPACT_T:
				var k2 := (t2 - ATK_LAUNCH_T) / (ATK_IMPACT_T - ATK_LAUNCH_T)
				off = lerpf(back, push, minf(k2 * 2.2, 1.0))   # 冲上去撞击
			else:
				var k3 := (t2 - ATK_IMPACT_T) / (1.0 - ATK_IMPACT_T)
				off = push * (1.0 - (1.0 - pow(1.0 - k3, 2.0)))  # 缓缓回正
			return asrc + adir * off
	return base


func _tick_earring_autoplay() -> bool:
	## 鸭语耳环自动出牌的**逐张播放**驱动（R77 唯一口）：每 `_earring_gap` 毫秒推进一步。
	## 返回 true = 还在播（界面要继续逐帧重绘、且玩家操作应被锁住）。
	if engine == null or not engine.earring_autoplay_active():
		return false
	var n := _now()
	if n - _earring_at < _earring_gap:
		return true
	_earring_at = n
	# 推进一步（引擎在 _autoplay_step 里真的出牌，并发 earring_autoplay_step 事件）
	engine._autoplay_step(_earring_i)
	_earring_i += 1
	return true


func _tick_anims() -> bool:
	## 清理过期动画，返回是否仍有活动动画。
	var n := _now()
	var any := false
	for key in _slides.keys():
		var a: Dictionary = _slides[key]
		if n - int(a.start) >= int(a.dur):
			_slides.erase(key)
		else:
			any = true
	for key2 in _attacks.keys():
		var l: Dictionary = _attacks[key2]
		if n - int(l.start) >= int(l.dur):
			_attacks.erase(key2)
		else:
			any = true
	# 延时特效：到点触发（命中 / 击破）
	while true:
		var due := -1
		for i in _delayed.size():
			if int(_delayed[i].at) <= n:
				due = i
				break
		if due < 0:
			break
		var ev: Dictionary = _delayed.pop_at(due)
		_apply_delayed(str(ev.kind), ev.data as Dictionary)
		any = true
	for key3 in _flashes.keys():
		var fl: Dictionary = _flashes[key3]
		if n - int(fl.start) >= int(fl.dur):
			_flashes.erase(key3)
		else:
			any = true
	_ghosts = _ghosts.filter(func(g): return n - int(g.start) < int(g.dur))
	_dying = _dying.filter(func(x): return int(x.hide_at) > n)
	_floaters = _floaters.filter(func(f): return n - int(f.start) < int(f.dur))
	_bursts = _bursts.filter(func(b): return n - int(b.start) < int(b.dur))
	_wake_rings = _wake_rings.filter(func(r): return n - int(r.start) < int(r.dur))
	return any or not _ghosts.is_empty() or not _floaters.is_empty() \
			or not _bursts.is_empty() or not _dying.is_empty() \
			or not _wake_rings.is_empty() \
			or not _delayed.is_empty() or n < _shake_until


func _on_engine_action(kind: String, data: Dictionary) -> void:
	## 引擎动作 → 动画 + 音效。
	var n := _now()
	match kind:
		"place":
			sfx.play("place")
			var cell: Vector2i = data["cell"]
			var pl := engine.state.unit_at(cell)
			if pl != null:
				_slides[pl] = {"from": _cell_center(cell) + Vector2(0, -110),
						"to": _cell_center(cell), "start": n, "dur": 450}
		"fence_merge":
			# 栅栏修复术（6021）：两张栅栏合并 → 加固爆点 + 「生+N」飘字
			sfx.play("place")
			var fm_cell: Vector2i = data["cell"]
			var fm_name := "栅栏"
			if data.get("card") is CardData:
				fm_name = (data["card"] as CardData).card_name
			_bursts.append({"pos": _cell_center(fm_cell), "start": n, "dur": 520,
					"col": Color("e08a2e"), "big": false})
			_floaters.append({"pos": _cell_center(fm_cell) + Vector2(0, -20),
					"text": "叠栅栏 生+%d" % int(data.get("gained", 0)),
					"col": Color("e08a2e"), "start": n, "dur": 1500, "size": 18})
			_say("▣ 栅栏修复术：两张栅栏合并 → %s 生命 %d" % [fm_name,
					int(data.get("health", 0))])
		"void_lord":
			# 虚空主宰（9082）：本次对战中每用技能牌对敌方造成一次伤害 → 手卡里的本卡费用 -2
			_say("◈ 虚空主宰：第 %d 次技能对敌造成伤害 → 本卡费用 -%d（现 %d 费）" % [
					int(data.get("count", 0)), int(data.get("discount", 0)),
					10 - int(data.get("discount", 0))])
		"move":
			var pl2 := engine.state.unit_at(data["dst"])
			if pl2 != null:
				# 多格移动：沿引擎给的逐格路径滑（不能从起点直连终点，那会穿墙/走捷径）
				var mv_pts: Array[Vector2] = []
				for mv_c in (data.get("path", []) as Array):
					mv_pts.append(_cell_center(mv_c as Vector2i))
				if mv_pts.size() < 2:
					mv_pts = [_cell_center(data["src"]),
							_cell_center(data["dst"])]
				var mv_steps := mv_pts.size() - 1
				_slides[pl2] = {"from": mv_pts[0], "to": mv_pts[mv_steps],
						"pts": mv_pts,
						"start": maxi(n, _anim_end_for(pl2)),
						"dur": MOVE_SLIDE_BASE_MS + MOVE_SLIDE_PER_STEP_MS * mv_steps}
		"attack":
			var src_c := _cell_center(data["src"])
			var dst_c := _cell_center(data["dst"])
			var adir: Vector2 = (dst_c - src_c).normalized()
			var atk_pl := engine.state.unit_at(data["src"])
			var def_pl := engine.state.unit_at(data["dst"])
			# 卡面生命冻结：伤害已在引擎里扣掉，但数字等到「命中」演出才往下掉
			if def_pl != null:
				_freeze_hp(def_pl, int(data["damage"]))
			# 攻击演出排在「该单位已排队的动作」之后：AI 一步内常连做「移动 + 攻击」，
			# 若两段同时起播，滑行会盖住蓄力/后坐，看起来就是「怪物一闪就打完了」。
			var a_start := n
			if atk_pl != null:
				a_start = maxi(n, _anim_end_for(atk_pl))
				_attacks[atk_pl] = {"kind": "unit", "dir": adir, "src": src_c, "dst": dst_c,
						"start": a_start, "dur": ATK_DUR_MS, "dmg": int(data["damage"])}
			# 弹体命中时刻 = ATK_IMPACT_T × 总时长：爆点/闪红/伤害数字那时才出现
			_delayed.append({"at": a_start + int(ATK_IMPACT_T * ATK_DUR_MS), "kind": "hit",
					"data": {"pos": dst_c, "dmg": int(data["damage"]), "def": def_pl}})
			_say("⚔ %s 攻击 %s！" % [data.get("atk_name", "?"), data.get("def_name", "?")])
		"hp":
			# 攻击方 side；被打的是对面 → 飘字/爆点落在对应 HP 横幅。
			# 直击 HP 也让单位「冲锋撞上去」——否则 AI 单位只闪一行数字、毫无动作。
			var hp_side := str(data.get("side", ""))
			var banner_y := GRID_Y + 22.0 if hp_side == GameEngine.SIDE_SELF \
					else GRID_Y + GRID_H - 20.0
			# 哪一方 HP 在掉：self 方攻击 → 敌方 HP 掉；opponent 方攻击 → 我方 HP 掉
			var hp_key: String = "hp_opp" if hp_side == GameEngine.SIDE_SELF \
					else "hp_self"
			_freeze_hp(hp_key, int(data["damage"]))   # 横幅数字冻结到撞击演出才掉
			var hp_atk := engine.state.unit_at(data["src"])
			var h_start := n
			if hp_atk != null:
				h_start = maxi(n, _anim_end_for(hp_atk))
				var hs := _cell_center(data["src"])
				var hd := _cell_center(data["dst"])
				var hdir: Vector2 = (hd - hs).normalized()
				_attacks[hp_atk] = {"kind": "hp", "dir": hdir, "src": hs, "dst": hd,
						"start": h_start, "dur": ATK_DUR_MS, "dmg": int(data["damage"])}
			# 撞击时刻才出爆点/飘字/震屏，与单位动作对齐
			_delayed.append({"at": h_start + int(ATK_IMPACT_T * ATK_DUR_MS),
					"kind": "hp_hit",
					"data": {"pos": Vector2(GRID_X + GRID_W + 46, banner_y),
					"dmg": int(data["damage"]), "hpkey": hp_key}})
			if hp_side == GameEngine.SIDE_SELF:
				_say("⚔ %s 直击敌方 HP！-%d" % [data.get("atk_name", "?"), int(data["damage"])])
			else:
				_say("⚔ %s 直击我方 HP！-%d" % [data.get("atk_name", "?"), int(data["damage"])])
		"trample":
			# 打穿挡在 HP 前面的单位 → 多出来的伤害漏到玩家 HP。
			# 排在这次攻击「命中」之后再播：弹体命中 → 击破 → 漏伤。
			var tr_side := str(data.get("side", ""))
			var tr_y := GRID_Y + 22.0 if tr_side == GameEngine.SIDE_SELF \
					else GRID_Y + GRID_H - 20.0
			var tr_key: String = "hp_self" if tr_side == GameEngine.SIDE_SELF \
					else "hp_opp"
			_freeze_hp(tr_key, int(data["amount"]))   # 溢出也冻结到溢出演出才掉
			var tr_at := n
			# 溢出可能来自攻击（带 src，等弹体命中后再漏），也可能来自爆炎鸭炸击 /
			# 范围伤害的批量击杀收尾（没有 src）→ 那种就当场播。
			var tr_src = data.get("src")
			var tr_atk = engine.state.unit_at(tr_src) if tr_src is Vector2i else null
			if tr_atk != null and _attacks.has(tr_atk):
				var la: Dictionary = _attacks[tr_atk]
				tr_at = int(la.start) + int(ATK_IMPACT_T * int(la.dur)) + 140
			_delayed.append({"at": maxi(tr_at, n), "kind": "hp_hit",
					"data": {"pos": Vector2(GRID_X + GRID_W + 46, tr_y),
					"dmg": int(data["amount"]),
					"label": "溢出 -%d" % int(data["amount"]),
					"hpkey": tr_key}})
			var tr_side_cn := "我方" if tr_side == GameEngine.SIDE_SELF else "敌方"
			if data.has("atk_name"):
				_say("⚔ %s 打穿 %s，溢出 %d 点直击%s HP！" % [data["atk_name"],
						data.get("def_name", "?"), int(data["amount"]), tr_side_cn])
			else:
				_say("💥 溢出伤害：%d 点越过 %s 直击%s HP！" % [int(data["amount"]),
						data.get("def_name", "?"), tr_side_cn])
		"spell":
			sfx.play("heal" if int(data["card"].id) in [2002, 7202] else "spell")
			var detail := str(data.get("detail", ""))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y - 36),
					"text": detail, "col": Color("7a2a7a"),
					"start": n, "dur": 1600})
		"effect":
			sfx.play("place")
			var ecard: CardData = data["card"]
			_say("✦ 效果卡「%s」启用，持续生效中" % ecard.card_name)
			_floaters.append({"pos": Vector2(COST_X + (TAP_W + 12) / 2, COST_Y + ENERGY_H + 70),
					"text": "%s 生效" % ecard.card_name, "col": Color("1d7a4f"),
					"start": n, "dur": 1500})
		"hand_full":
			# 手牌达上限（FieldState.HAND_LIMIT）：不再抽牌
			sfx.play("click")
			var hlim := int(data.get("limit", 0))
			_say("手牌已满（%d 张），不再抽牌" % hlim)
			_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
					"text": "手牌已满 %d/%d" % [int(data.get("hand", 0)), hlim],
					"col": Color("b26a00"), "size": 17,
					"start": n, "dur": 2200})
		"deck_empty":
			_say("已经没有卡牌可以抽了")
		"whisper":
			# 道具「鸭之低语」：每回合开始随机到的强化（费用/伤害/抽牌）
			_whisper_txt = str(data.get("text", ""))
			sfx.play("heal")
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y - 12),
					"text": "鸭之低语 · %s" % _whisper_txt, "col": Color("7b34b8"),
					"start": n, "dur": 2100})
		"wisdom":
			# 智慧喷涌（9059）：回合开始抽 1 张（效果卡还会被减费）
			sfx.play("draw")
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "智慧喷涌 · 额外抽 %d 张" % int(data.get("count", 0)),
					"col": Color("3f8fbf"), "start": n, "dur": 2100})
		"blessing":
			# 无尽加护（9061）：回合开始随机一张效果卡进手卡
			sfx.play("draw")
			_say("✦ 无尽加护：随机一张效果卡加入手卡（%d 张）" % int(data.get("count", 0)))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "无尽加护 · 效果卡 +%d" % int(data.get("count", 0)),
					"col": Color("4a9a5a"), "start": n, "dur": 2100})
		"crow_token":
			# 使魔之夜（9062）：使用效果牌 → 一张乌鸦进手卡（本回合 0 费）
			sfx.play("draw")
			_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
					"text": "使魔之夜 · 乌鸦 +1（本回合 0 费）", "col": Color("6a6a9a"), "size": 17,
					"start": n, "dur": 2100})
		"aether":
			# 以太屏障（9060）：本回合前 X 次受到的伤害变为 1
			sfx.play("heal")
			_say("✦ 以太屏障：本回合前 %d 次受到的伤害变为 1" % int(data.get("left", 0)))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "以太屏障 · 前 %d 次伤害→1" % int(data.get("left", 0)),
					"col": Color("4a7fd8"), "start": n, "dur": 2100})
		"aether_hit":
			# 以太屏障吸收了一次伤害
			sfx.play("heal")
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 66),
					"text": "以太屏障 · 伤害 %d → 1（还剩 %d 次）" % [
							int(data.get("amount", 0)), int(data.get("left", 0))],
					"col": Color("4a7fd8"), "size": 15, "start": n, "dur": 2000})
		"rice":
			# 道具「一袋米抗几楼」：本轮首次受伤 → 抽 1 张卡 + 本回合技能伤害 +1
			sfx.play("heal")
			_say("✦ 一袋米抗几楼：首次受伤 → 抽 1 张卡，本回合技能伤害 +1")
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "一袋米抗几楼 · 抽 1 张 / 技能 +1", "col": Color("d7a54a"),
					"start": n, "dur": 2100})
		"revive":
			# 道具「叠加态的鸭」：HP 归零 → 复活（回复 1 点生命，概率永久 -25%）
			sfx.play("heal")
			_say("✚ 叠加态的鸭：复活！回复 1 点生命（下次复活概率 %d%%）"
					% int(data.get("chance", 0)))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 26),
					"text": "叠加态的鸭 · 复活（回复 1 点生命）", "col": Color("c0392b"),
					"start": n, "dur": 2400})
		"heal":
			# 白魔法师（9021）：自己回合开始时治疗生命百分比最低的己方单位
			sfx.play("heal")
			var hcell: Variant = data.get("cell")
			var hpos := Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30)
			if hcell is Vector2i:
				hpos = _cell_center(hcell)
			var hname := str((data.get("card") as CardData).card_name) \
					if data.get("card") is CardData else "?"
			_floaters.append({"pos": hpos + Vector2(0, -12),
					"text": "治疗 +%d" % int(data.get("amount", 0)),
					"col": Color("2fa36b"), "start": n, "dur": 1500})
			if str(data.get("side", "")) == GameEngine.SIDE_OPPONENT:
				_say("✚ 白魔法师治疗了 %s（+%d）" % [hname, int(data.get("amount", 0))])
		"icecream":
			# 道具「冰淇淋与汽水」（6016）：第 1 回合 +4 能量 / 多抽 3 张 → 飘出台词
			# （刻意比开场 -3 生命的 relic 飘字高 66px，两条同时出现也不会叠在一起；
			#   用深一号的蓝 + 18px 字号，浅色棋盘上才读得清）
			sfx.play("heal")
			var ice_line := str(data.get("text", ""))
			_say("✦ 冰淇淋与汽水：+%d 能量 / 多抽 %d 张 ——「%s」"
					% [int(data.get("energy", 0)), int(data.get("draw", 0)), ice_line])
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 96),
					"text": ice_line, "col": Color("1f7fc4"), "size": 18, "outline": 6,
					"start": n, "dur": 2600})
		"relic":
			# 第二层起始道具的持续/开场提示（黄桃罐头 / 冰淇淋与汽水 等）
			sfx.play("heal")
			var rtext := str(data.get("text", ""))
			_say("✦ %s" % rtext)
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": rtext, "col": Color("3fc7d4"),
					"start": n, "dur": 1800})
		"pear":
			# 道具「鸭梨」：我方 HP 受伤 → 最大生命 +1（只提高上限，不回复生命）
			sfx.play("heal")
			_say("✦ 鸭梨：受到伤害 → 最大生命 +1（当前 %d/%d）"
					% [int(data.get("hp", 0)), int(data.get("max_hp", 0))])
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "鸭梨 · 最大生命 +1", "col": Color("a9b83c"),
					"start": n, "dur": 2100})
		"hero_cost":
			# 「英雄」（9023）上场的代价：玩家选中的 4 张手牌已弃掉 → 飘一行提示
			sfx.play("place")
			var hc_names: Array = data.get("names", [])
			var hc_txt: String = "英雄的代价：弃 %d 张（%s）" % [
					int(data.get("count", 0)), "、".join(hc_names)]
			_say("◆ %s" % hc_txt)
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 66),
					"text": hc_txt, "col": Color("8a5a1a"), "size": 15,
					"start": n, "dur": 2200})
		"self_clone":
			# 野兔 9032（R82）：使用后手牌增加一张自己的复制 → 飘字告诉玩家多了一张。
			# 没有提示的话玩家会以为手牌凭空少了一张（打出 -1、复制 +1 净值为 0）。
			# 音效用现成的 "draw"→ 没有该音色，这里用 click（短促）+ place（落地感）。
			sfx.play("click")
			var sc_name := "?"
			if data.get("card") is CardData:
				sc_name = (data["card"] as CardData).card_name
			_say("✦ %s：手牌增加一张复制（回合结束前可以打出）" % sc_name)
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "%s · 复制入手" % sc_name, "col": Color("7fd6a0"),
					"start": n, "dur": 2000})
		"barrier_grant":
			# 能量屏障 8033（R87）：给抽牌堆里一张卡加上「首次受伤免掉」。
			if bool(data.get("ok", false)) and data.get("card") is CardData:
				var bg_card: CardData = data["card"]
				sfx.play("place")
				_say("✦ 能量屏障：%s 获得能量屏障（下次上场时第一次挨打完全免掉）"
						% bg_card.card_name)
				_floaters.append({"pos": Vector2(DECK_X + CARD_W / 2, DECK_Y - 14),
						"text": "%s · 获得护盾" % bg_card.card_name,
						"col": Color("7fd6f0"), "start": n, "dur": 2200, "size": 14})
			else:
				_say("能量屏障：抽牌堆里没有「还没有能量屏障」的盟友 / 工事，效果落空")
		"barrier":
			# 护盾**挡下**伤害的瞬间（R87）：这是玩家最需要看到的反馈 —— 护盾消失且不扣血。
			sfx.play("heal")
			var ba_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var ba_name := "?"
			if data.get("card") is CardData:
				ba_name = (data["card"] as CardData).card_name
			_say("🛡 %s 的能量屏障挡住了 %d 点伤害（护盾消失）"
					% [ba_name, int(data.get("blocked", 0))])
			if ba_cell.x >= 0:
				_bursts.append({"pos": _cell_center(ba_cell), "start": n,
						"dur": 520, "col": Color("7fd6f0"), "big": true})
				_floaters.append({"pos": _cell_center(ba_cell) + Vector2(0, -14),
						"text": "护盾 · 0 伤", "col": Color("7fd6f0"),
						"start": n, "dur": 1600, "size": 17})
		"self_repair":
			# 自我修复 8035（R87）：改造一个己方盟友 → +2 最大生命 + 每回合回 4。
			sfx.play("heal")
			var sr_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_say("✚ 自我修复：%s 最大生命 +%d、每回合结束回 %d"
					% [str((data.get("card", null) as CardData).card_name),
						int(data.get("hp", 0)), int(data.get("regen", 0))])
			if (data.get("cell", Vector2i(-1, -1)) as Vector2i).x >= 0:
				_floaters.append({"pos": sr_pos, "text": "+%d 血 / 回 %d"
						% [int(data.get("hp", 0)), int(data.get("regen", 0))],
						"col": Color("8ce09a"), "start": n, "dur": 2000, "size": 14})
		"charge_heal":
			# 充电装置（8041，R91）：被「接通」的己方单位每回合结束回血 → 该格飘字。
			# 与「清泉 / 维修间 / 自我修复」共用冷青色系（都是 friendly 回血）。
			sfx.play("heal")
			var ch_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": ch_pos, "text": "+%d" % int(data.get("amount", 0)),
				"col": COL_FIELD_PERSIST, "start": n, "dur": 1400, "size": 18})
		"shield_redirect":
			# 护盾生成器（8042，R92）：接通的我方单位受伤 → 伤害**改由它承受**，溢出不再结算。
			# 演出分两头：受害格「接下 N」+ 生成器格爆点「-N」，让玩家看清伤害到底去了哪里。
			sfx.play("heal")
			var sr_src := data.get("cell", Vector2i(-1, -1)) as Vector2i
			var sr_dst := data.get("to", Vector2i(-1, -1)) as Vector2i
			var sr_n: int = int(data.get("amount", 0))
			_say("◈ %s 受到的 %d 点伤害被护盾生成器接下（溢出不再结算）"
					% [str((data.get("card", null) as CardData).card_name), sr_n])
			if sr_src.x >= 0:
				_floaters.append({"pos": _cell_center(sr_src) + Vector2(0, -14),
						"text": "接下 %d" % sr_n, "col": COL_FIELD_PERSIST,
						"start": n, "dur": 1600, "size": 16})
			if sr_dst.x >= 0:
				_bursts.append({"pos": _cell_center(sr_dst), "start": n,
						"dur": 520, "col": COL_FIELD_PERSIST, "big": true})
				_floaters.append({"pos": _cell_center(sr_dst) + Vector2(0, -14),
						"text": "-%d" % sr_n, "col": Color("f0a0a0"),
						"start": n, "dur": 1600, "size": 17})
		"mimic_upgrade":
			# 模仿者（8043，R92）：接通的我方盟友获得改造 → 它获得**相同改造**。
			var mu_cell := data.get("cell", Vector2i(-1, -1)) as Vector2i
			var mu_atk: int = int(data.get("atk", 0))
			var mu_hp: int = int(data.get("hp", 0))
			sfx.play("heal")
			_say("✧ 模仿者模仿 %s 的改造：+%d 攻 / +%d 血"
					% [str(data.get("from", "")), mu_atk, mu_hp])
			if mu_cell.x >= 0:
				_floaters.append({"pos": _cell_center(mu_cell),
					"text": "+%d 攻 / +%d 血" % [mu_atk, mu_hp],
					"col": Color("8ce09a"), "start": n, "dur": 1800, "size": 15})
		"chimera":
			# 嵌合暴君（8047，R96）：使用时破坏接通的己方卡并吸收其攻/血。
			var ch_cell := data.get("cell", Vector2i(-1, -1)) as Vector2i
			var ch_abs: int = int(data.get("absorbed", 0))
			var ch_atk: int = int(data.get("atk", 0))
			var ch_hp: int = int(data.get("hp", 0))
			if ch_abs <= 0:
				_say("嵌合暴君：周围没有己方卡可融合")
			else:
				sfx.play("attack")
				_say("嵌合暴君融合 %d 张卡：+%d 攻 / +%d 血" % [ch_abs, ch_atk, ch_hp])
				if ch_cell.x >= 0:
					_bursts.append({"pos": _cell_center(ch_cell), "start": n,
							"dur": 420, "col": COL_SPELL})
					_floaters.append({"pos": _cell_center(ch_cell),
							"text": "+%d 攻 / +%d 血" % [ch_atk, ch_hp],
							"col": Color("caa6ff"), "start": n, "dur": 1900, "size": 16})
		"recycler":
			# 零件回收者（8046，R96）：接通的己方卡被销毁 → 回收其力量 + 手牌加素体。
			var rc_cell := data.get("cell", Vector2i(-1, -1)) as Vector2i
			var rc_pow: int = int(data.get("power", 0))
			sfx.play("spell")
			_say("零件回收者回收 %d 力量，手牌 +1 张「素体」" % rc_pow)
			if rc_cell.x >= 0:
				_floaters.append({"pos": _cell_center(rc_cell),
						"text": "+%d 攻" % rc_pow,
						"col": Color("ffa41f"), "start": n, "dur": 1700, "size": 16})
		"prod_order":
			# 生产订单（8048，R96）：往抽牌堆加两张改造「素体」。
			var po_cnt: int = int(data.get("count", 0))
			var po_atk: int = int(data.get("atk", 0))
			var po_hp: int = int(data.get("hp", 0))
			sfx.play("place")
			_say("生产订单：卡组 +%d 张改造「素体」（各 +%d 攻 / +%d 血）" % [po_cnt, po_atk, po_hp])
		"demolish":
			# 拆解 8049（R97，机械之心）：破坏己方单位、回 3 费、手牌+素体；被改造则额外+升级。
			var dm_cell := data.get("cell", Vector2i(-1, -1)) as Vector2i
			var dm_up := bool(data.get("upgraded", false))
			var dm_refund: int = int(data.get("refund", 0))
			var dm_proto: int = int(data.get("got_proto", 0))
			var dm_upg: int = int(data.get("got_upg", 0))
			sfx.play("attack")
			if dm_up:
				_say("拆解：破坏被改造单位，回复 %d 费，手牌 +%d 素体 +%d 升级" % [dm_refund, dm_proto, dm_upg])
			else:
				_say("拆解：破坏单位，回复 %d 费，手牌 +%d 素体" % [dm_refund, dm_proto])
			if dm_cell.x >= 0:
				_floaters.append({"pos": _cell_center(dm_cell),
					"text": "+%d 费" % dm_refund,
					"col": Color("6ec6ff"), "start": n, "dur": 1500, "size": 16})
		"overload_die":
			# 超负荷（旧式机兵 8050，R98）：己方回合结束、生命仍为负 → 真正死亡。
			var od_cell := data.get("cell", Vector2i(-1, -1)) as Vector2i
			var od_card = data.get("card", null)
			var od_name: String = od_card.card_name if od_card != null else "单位"
			sfx.play("death")
			_say("超负荷：%s 生命仍为负（%d），回合结束死亡" % [od_name, int(data.get("health", 0))])
			if od_cell.x >= 0:
				_floaters.append({"pos": _cell_center(od_cell),
					"text": "超负荷死亡", "col": Color("ff7a3c"),
					"start": n, "dur": 1500, "size": 15})
		"overload_neg":
			# 超负荷（旧式机兵 8050，R98）：受到伤害后仍以负数血量存活 → 一格提示。
			var on_cell := data.get("cell", Vector2i(-1, -1)) as Vector2i
			if on_cell.x >= 0:
				_floaters.append({"pos": _cell_center(on_cell),
					"text": "负血存活 %d" % int(data.get("health", 0)),
					"col": Color("ff7a3c"), "start": n, "dur": 1400, "size": 14})
		"regen":
			# 自我修复的每回合回血（R87）：在该单位格上飘字。
			var rg_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": rg_pos, "text": "+%d" % int(data.get("amount", 0)),
					"col": Color("8ce09a"), "start": n, "dur": 1400, "size": 16})
		"night_erosion":
			# 夜蚀 8062（R103）：回合结束按剩余费用回复生命 —— 绿色回血飘字（同自我修复口径）。
			var ne_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": ne_pos, "text": "+%d" % int(data.get("amount", 0)),
					"col": Color("8ce09a"), "start": n, "dur": 1400, "size": 16})
			sfx.play("heal")
		"batch_upgrade":
			# 批量改造 8031（R86）：手牌里所有盟友/工事各 +1 生命。
			var bu_n: int = int(data.get("count", 0))
			if bu_n <= 0:
				_say("批量改造：手牌里没有盟友或工事，效果落空")
			else:
				sfx.play("heal")
				_say("✦ 批量改造：手牌里 %d 张盟友/工事各 +1 生命（本场战斗内一直有效）"
						% bu_n)
				_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
						"text": "批量改造 · %d 张 +1 血" % bu_n,
						"col": Color("8ad4f0"), "start": n, "dur": 2000})
		"overload":
			# 过载 8030（R85，机械之心）：给牌库里一张盟友加上「一回合行动两次」。
			# 目标是**牌库**里的牌（不在场上），所以飘字落在抽牌堆旁边而不是某个格子。
			if bool(data.get("ok", false)) and data.get("card") is CardData:
				var ov_card: CardData = data["card"]
				sfx.play("place")
				_say("✦ 过载：%s 现在一回合行动两次（之后每次抽到它都是双动）"
						% ov_card.card_name)
				_floaters.append({"pos": Vector2(DECK_X + CARD_W / 2, DECK_Y - 14),
						"text": "%s · 行动两次" % ov_card.card_name,
						"col": Color("b98cf0"), "start": n, "dur": 2200, "size": 14})
			else:
				# 落空要说清原因，否则玩家以为白花了 2 费
				_say("过载：牌库里没有「没有一回合行动两次」的盟友，效果落空")
		"auto_upgrade":
			# 自主升级 8045（R95，机械之心）：回合开始随机改造抽牌堆里一张盟友 / 工事。
			# 目标在**牌库**里（不在场上），所以飘字落在抽牌堆旁边 —— 与「过载」同一套路。
			if bool(data.get("ok", false)) and data.get("card") is CardData:
				var au_card: CardData = data["card"]
				sfx.play("spell")
				_say("✦ 自主升级：牌库里的「%s」被改造（+%d 攻 / +%d 血，之后抽到就带）" % [
						au_card.card_name,
						GameEngine.AUTO_UPGRADE_ATK, GameEngine.AUTO_UPGRADE_HP])
				_floaters.append({"pos": Vector2(DECK_X + CARD_W / 2, DECK_Y - 14),
						"text": "%s · +%d 攻 +%d 血" % [au_card.card_name,
							GameEngine.AUTO_UPGRADE_ATK, GameEngine.AUTO_UPGRADE_HP],
						"col": Color("ffc94d"), "start": n, "dur": 2200, "size": 14})
			else:
				_say("自主升级：抽牌堆里没有盟友 / 工事，本回合落空")
		"upgrade":
			# 「升级」8027（R82）/ 改造工厂 8037（R88）：改造一个盟友 / 工事 → 在**那一格**上飘字。
			# ⚠️ 「升级」技能与改造工厂**共用这个事件**，所以提示要按 `field` 字段分文案 ——
			# 不然改造工厂的每回合结算会显示成「◆ 升级：…」，玩家以为自己在打「升级」那张牌。
			sfx.play("spell")
			var ug_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var ug_name := "?"
			if data.get("card") is CardData:
				ug_name = (data["card"] as CardData).card_name
			var ug_txt := "%s +%d攻 +%d血" % [ug_name, int(data.get("atk", 0)),
					int(data.get("hp", 0))]
			var ug_from := str(data.get("field", ""))
			if ug_from != "":
				_say("◆ %s：%s（每回合结算，可叠加）" % [ug_from, ug_txt])
			else:
				_say("◆ 升级：%s" % ug_txt)
			if ug_cell.x >= 0:
				_floaters.append({"pos": _cell_center(ug_cell),
						"text": ug_txt, "col": Color("8ad4f0"),
						"start": n, "dur": 2200})
		"sys_upgrade":
			# 系统升级 8039（R90）：手牌里一张牌被改造（+1费/+3力/+6血）→ 手牌区飘字。
			# 目标在**手牌**里（不是棋盘），所以落点用整排手牌的中点。
			var su_c = data.get("card", null)
			if su_c is CardData:
				var su_d: CardData = su_c as CardData
				sfx.play("spell")
				_say("◆ 系统升级：%s → %d 费 / %d 攻 / %d 血（本场战斗永久）" % [
					su_d.card_name, su_d.cost, su_d.power, su_d.health])
				_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
					"text": "%s +1费 +3攻 +6血" % su_d.card_name,
					"col": Color("8ad4f0"), "start": n, "dur": 2000})
			else:
				_say("系统升级：手牌里没有可选的盟友或工事")
		"batch_transfer":
			# 批量传输 8040（R90）：手牌全体改造 + 抽 1 张。
			var bt_n := int(data.get("count", 0))
			var bt_drw := int(data.get("draw", 0))
			sfx.play("spell")
			if bt_n > 0:
				_say("◆ 批量传输：%d 张手牌 +1 费 / +3 攻 / +6 血，抽 %d 张卡" % [bt_n, bt_drw])
			else:
				_say("批量传输：手牌里没有盟友或工事（未改造），仍抽 %d 张卡" % bt_drw)
			_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
				"text": "批量改造 %d 张 · 抽 %d" % [bt_n, bt_drw],
				"col": Color("8ad4f0"), "start": n, "dur": 2000})
		"inf_armor":
			# 无限装甲（8038，R89）：被改造时供一张 0 费改造牌到手 —— 飘字落在**手牌区上方**，
			# 因为目标在手里、不在场上（与 `fetch_skill` 同一落点）。
			# ⚠️ 不需要进录像：回放会重放「use_spell → 升级」，`_upgrade_unit` 在回放里
			# **同样会触发**供能 —— 内部结算不记 action（同批量改造 / 过载的口径）。
			var ia_card = data.get("card", null)
			if ia_card is CardData:
				var ia_name: String = (ia_card as CardData).card_name
				sfx.play("draw")
				_say("◆ 无限装甲供能：「%s」入手（在手牌里 %d 费，离开手牌恢复原价）"
					% [ia_name, GameEngine.INF_ARMOR_FEED_COST])
				_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
					"text": "%s · 0 费入手" % ia_name, "col": Color("8ad4f0"),
					"start": n, "dur": 2000})
			else:
				_say("◆ 无限装甲：本次供能落空（没有可给的改造牌 / 手牌已满）")
		"crow_recall":
			sfx.play("place")
			var cr_name := "?"
			if data.get("card") is CardData:
				cr_name = (data["card"] as CardData).card_name
			_say("乌鸦：%s 从弃牌堆回到手牌" % cr_name)
		"whale_pick":
			sfx.play("place")
			var wp_name := "?"
			if data.get("card") is CardData:
				wp_name = (data["card"] as CardData).card_name
			_say("鲸鱼之怒：%s 从弃牌堆回到手牌" % wp_name)
		"endless_pick":
			# 无尽黑暗 9114（R70）：玩家选定弃牌 → 弃牌飘字 + 拿到费用的提示
			sfx.play("destroy")
			var en_name := "?"
			if data.get("card") is CardData:
				en_name = (data["card"] as CardData).card_name
			var en_gain: int = int(data.get("energy", GameEngine.ENDLESS_DARK_ENERGY))
			_say("无尽黑暗：弃掉 %s → 费用 +%d" % [en_name, en_gain])
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 66),
					"text": "弃 %s　费用 +%d" % [en_name, en_gain],
					"col": Color("6a4a9a"), "size": 15, "start": n, "dur": 2000})
		"revive_recall":
			sfx.play("place")
			var rv_name := "?"
			if data.get("card") is CardData:
				rv_name = (data["card"] as CardData).card_name
			_say("复活术：%s 从弃牌区回到手牌" % rv_name)
		"golem":
			sfx.play("place")
			_say("魔像术：在己方半场召唤一个魔像")
		"apprentice":
			var ap_name := "?"
			if data.get("card") is CardData:
				ap_name = (data["card"] as CardData).card_name
			_say("魔法学徒：本回合出牌费用 -1；从卡组取到「%s」" % ap_name)
		"aether_roar":
			# 以太咆哮（9063）：全体敌方 -N
			sfx.play("spell")
			var ar_dmg := int(data.get("dmg", 0))
			var ar_hits := int(data.get("hits", 0))
			_shake(6.0, 300)
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "以太咆哮 -%d" % ar_dmg,
					"col": Color("7a3fd0"), "start": n, "dur": 1600, "size": 20})
			_say("以太咆哮：%d 个敌人各 -%d" % [ar_hits, ar_dmg] if ar_hits > 0
					else "以太咆哮：场上没有敌人 → 直击敌方 HP -%d" % ar_dmg)
		"space_guard":
			# 空间守护（9064）：离己方 HP 最近的敌人被推回去
			sfx.play("spell")
			var sg_name := "?"
			if data.get("card") is CardData:
				sg_name = (data["card"] as CardData).card_name
			_say("空间守护：%s 后退 %d 格" % [sg_name, int(data.get("steps", 2))])
		"stoneskin":
			_say("石肤：己方 HP 接下来 %d 次伤害变为 1（累计剩余 %d 次）" % [
					int(data.get("add", 0)), int(data.get("left", 0))])
		"stoneskin_hit":
			var sk_left := int(data.get("left", 0))
			_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
					"text": "石肤 → 1", "col": Color("6a6a6a"),
					"start": n, "dur": 1600, "size": 18})
			_say("石肤：这次伤害变为 1（原本 %d，还剩 %d 次）" % [
					int(data.get("amount", 0)), sk_left])
		"guard_absorb":
			var ga_name := "?"
			if data.get("card") is CardData:
				ga_name = (data["card"] as CardData).card_name
			_say("%s：%s 替我方 HP 承受 %d 点伤害" % [
					str(data.get("how", "守护")), ga_name, int(data.get("amount", 0))])
		"echo":
			# 回响（9102）：每个敌人各吃 2 伤 + 力量 -1（紫色飘字压在卡上）
			sfx.play("spell")
			var ec_name := "?"
			if data.get("card") is CardData:
				ec_name = (data["card"] as CardData).card_name
			var ec_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": ec_pos, "start": n, "dur": 420,
					"col": Color("8e6cc8"), "big": false})
			_floaters.append({"pos": ec_pos + Vector2(0, -12),
					"text": "回响 -%d / 力量 -%d" % [int(data.get("dmg", 0)),
							int(data.get("amount", 0))],
					"col": Color("6a4aa0"), "start": n, "dur": 1500, "size": 15})
			_say("回响：%s -%d，力量 -%d" % [ec_name, int(data.get("dmg", 0)),
					int(data.get("amount", 0))])
		"dodge":
			sfx.play("spell")
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y - 62),
					"text": "闪躲：伤害由随机盟友代受",
					"col": Color("1d7a4f"), "size": 16, "outline": 6,
					"start": n, "dur": 2200})
			_say("闪躲：本回合你受到的伤害由随机盟友代替承受")
		"dodge_absorb":
			var da_name := "?"
			if data.get("card") is CardData:
				da_name = (data["card"] as CardData).card_name
			var da_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": da_pos + Vector2(0, -12),
					"text": "闪躲 → %s -%d" % [da_name, int(data.get("absorbed", 0))],
					"col": Color("1d7a4f"), "start": n, "dur": 1500, "size": 15})
			_say("闪躲：%s 替我方 HP 承受 %d 点伤害%s" % [
					da_name, int(data.get("absorbed", 0)),
					("（超出 %d 由自己承担）" % int(data.get("rest", 0)))
					if int(data.get("rest", 0)) > 0 else ""])
		"finisher":
			# 收尾（9104）：手卡里仅剩它 → 15 伤（金色大飘字）；平时 4 伤（普通飘字）。
			var fn_last := bool(data.get("last", false))
			var fn_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var fn_pos := _cell_center(fn_cell) if fn_cell.x >= 0 \
					else Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H / 2)
			_floaters.append({"pos": fn_pos + Vector2(0, -12),
					"text": "收尾 -%d" % int(data.get("dmg", 0)),
					"col": Color("b8860b") if fn_last else Color("6a4aa0"),
					"outline": 6 if fn_last else 0,
					"start": n, "dur": 1800 if fn_last else 1400,
					"size": 21 if fn_last else 15})
			if fn_last:
				sfx.play("spell")
				_say("收尾：这是你手卡里仅剩的一张 → %d 点伤害（平时只有 4 点）"
						% int(data.get("dmg", 0)))
		"egg_token":
			sfx.play("place")
			var eg_name := "?"
			if data.get("card") is CardData:
				eg_name = (data["card"] as CardData).card_name
			_say("鸭窝：一张「%s」加入手卡" % eg_name)
		"aether_guard":
			_say("以太守卫：效果区 %d 张效果卡 → +%d 力量、+%d 生命" % [
					int(data.get("n", 0)), int(data.get("n", 0)), 2 * int(data.get("n", 0))])
		"demon_fetch":
			var df_name := "?"
			if data.get("card") is CardData:
				df_name = (data["card"] as CardData).card_name
			_say("以太恶魔：从卡组取到「%s」，它的费用 -%d" % [df_name, 2])
		"owl_fetch":
			var ow_name := "?"
			if data.get("card") is CardData:
				ow_name = (data["card"] as CardData).card_name
			_say("猫头鹰：从卡组取到效果卡「%s」" % ow_name)
		"iron_fence":
			var if_name := "铁栅栏"
			if data.get("card") is CardData:
				if_name = (data["card"] as CardData).card_name
			_say("在启动了：召唤%s，它替你的 HP 承受伤害" % if_name)
		"knight_grow":
			var kg_name := "鸭子骑士"
			if data.get("card") is CardData:
				kg_name = (data["card"] as CardData).card_name
			var kg_center := _cell_center(data["cell"]) if data.has("cell") \
					else Vector2(WINDOW_W / 2, OWN_HAND_Y - 30)
			_floaters.append({"pos": kg_center + Vector2(0, -24),
					"text": "+%d 攻" % int(data.get("amount", 0)),
					"col": Color("ff8f00"), "start": _now(), "dur": 1500, "size": 20})
			_say("%s 击杀敌人 → 攻击力 +%d（当前 %d）" % [
					kg_name, int(data.get("amount", 0)), int(data.get("power", 0))])
		"deterrence":
			# 威慑（9057）：立即生效 —— 飘字 + 卡面力量当场变化（持续到下个自己回合开始）
			var dt_center := _cell_center(data["cell"]) if data.has("cell") \
					else Vector2(WINDOW_W / 2, GRID_Y + 40)
			var dt_name := "敌人"
			if data.get("card") is CardData:
				dt_name = (data["card"] as CardData).card_name
			_floaters.append({"pos": dt_center + Vector2(0, -24),
					"text": "威慑 -%d 攻" % int(data.get("amount", 0)),
					"col": Color("b0392f"), "start": n, "dur": 1600, "size": 20})
			_say("威慑：%s 力量 -%d，持续到你下个回合开始（当前 %d）" % [
					dt_name, int(data.get("amount", 0)), int(data.get("power", 0))])
		"night_grow":
			var ng_center := _cell_center(data["cell"]) if data.has("cell") \
					else Vector2(WINDOW_W / 2, GRID_Y + 40)
			var ng_name := "夜鸭"
			if data.get("card") is CardData:
				ng_name = (data["card"] as CardData).card_name
			_floaters.append({"pos": ng_center + Vector2(0, -24),
					"text": "夜行 +%d 攻" % int(data.get("amount", 0)),
					"col": Color("ff8f00"), "start": n, "dur": 1500, "size": 18})
			_say("%s 夜行：回合开始力量 +%d（当前 %d）" % [
					ng_name, int(data.get("amount", 0)), int(data.get("power", 0))])
		"mage_grow":
			# 精进（白魔法师 9021）：每个自己的回合开始力量 +1（永久累计，无前置条件）
			var mg_center := _cell_center(data["cell"]) if data.has("cell") \
					else Vector2(WINDOW_W / 2, GRID_Y + 40)
			var mg_name := "白魔法师"
			if data.get("card") is CardData:
				mg_name = (data["card"] as CardData).card_name
			_floaters.append({"pos": mg_center + Vector2(0, -24),
					"text": "精进 +%d 攻" % int(data.get("amount", 0)),
					"col": Color("ff8f00"), "start": n, "dur": 1500, "size": 18})
			_say("%s 精进：回合开始力量 +%d（当前 %d）" % [
				mg_name, int(data.get("amount", 0)), int(data.get("power", 0))])
		"familiar_grow":
			# 使魔之力（9115，R60）：回合开始带「使魔」trait 的单位力量 +1（永久）
			var fg_center := _cell_center(data["cell"]) if data.has("cell") \
					else Vector2(WINDOW_W / 2, GRID_Y + 40)
			var fg_name := "使魔鸭子"
			if data.get("card") is CardData:
				fg_name = (data["card"] as CardData).card_name
			_floaters.append({"pos": fg_center + Vector2(0, -24),
					"text": "使魔 +%d 攻" % int(data.get("amount", 0)),
					"col": Color("b06ad6"), "start": n, "dur": 1500, "size": 18})
			_say("%s 使魔之力：回合开始力量 +%d（当前 %d）" % [
				fg_name, int(data.get("amount", 0)), int(data.get("power", 0))])
		"enemy_growth":
			_floaters.append({"pos": Vector2(WINDOW_W / 2, GRID_Y - 16),
					"text": "敌方攻击力 %+d" % int(data.get("stacks", 0)),
					"col": Color("c62828"), "start": _now(), "dur": 1800, "size": 20})
			_say("关卡成长：敌方 %d 个单位攻击力 %+d" % [
					int(data.get("count", 0)), int(data.get("stacks", 0))])
		"self_heal":
			_floaters.append({"pos": Vector2(WINDOW_W / 2, OWN_HAND_Y - 30),
					"text": "+%d" % int(data.get("healed", 0)),
					"col": Color("2a9d55"), "start": n, "dur": 1800, "size": 22})
			var _sh := int(data.get("healed", 0))
			var _ph := int(data.get("peach", 0))
			var _src := "自愈 + 黄桃罐头" if _ph > 0 and _sh > _ph\
				else ("黄桃罐头" if _ph > 0 else "自愈")
			_say("%s：战斗结束回复 %d 点生命（剩余 %d）" % [
					_src, _sh, int(data.get("hp", 0))])
		"destroy":
			var center := _cell_center(data["cell"])
			# 若这是一次攻击动画的目标：等弹体命中后再演出击破，
			# 否则会出现「卡牌先消失、伤害数字后出现」的时序倒错。
			var delay_ms := 0
			for a: Dictionary in _attacks.values():
				if (a["dst"] as Vector2) == center:
					delay_ms = maxi(delay_ms,
							int(a["start"]) + int(ATK_IMPACT_T * int(a["dur"])) - n)
			var cell: Vector2i = data["cell"]
			# 无论哪种死法，都让这张卡在原位多留一小会儿：
			# 命中瞬间先闪红/掉血，稍后卡片才真正消失并播击破。
			var hide_at := n + delay_ms + DESTROY_HOLD_MS
			_dying.append({"cell": cell, "card": data["card"],
					"p": data.get("placement"), "hide_at": hide_at})
			_delayed.append({"at": hide_at, "kind": "destroy_fx",
					"data": {"center": center, "card": data["card"], "cell": cell}})
		"blast":
			# 爆炎鸭亡语 / 爆炸陷阱（R50）：尸体周围四格炸出的火焰（不分敌我）—— 同特效同源。
			# 起播稍微延后一点，读起来就是「先倒下 → 再爆开」。
			sfx.play("destroy")
			var bwhen := n + 120
			for c2 in data.get("cells", []):
				_bursts.append({"pos": _cell_center(c2 as Vector2i), "start": bwhen,
						"dur": 620, "col": Color("ff8a3d"), "big": true})
			var blast_center := _cell_center(data["center"])
			_floaters.append({"pos": blast_center + Vector2(0, -18),
					"text": "%s -%d" % [str(data["card"].card_name), int(data.get("amount", 0))],
					"col": Color("d84a12"), "start": bwhen, "dur": 1400, "size": 20})
			_shake(8.0, 360)
			_say("💥 %s 死亡爆炸：周围四格各 -%d" % [
					str(data["card"].card_name), int(data.get("amount", 0))])
		"trap_hit":
			# 冰霜 / 冻结陷阱（R51）：攻击者踩陷阱吃直伤 —— 蓝白火花 + 飘字（同源同特效）
			sfx.play("destroy")
			var th_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": th_pos, "start": n, "dur": 520,
					"col": Color("7ec8ff"), "big": false})
			_floaters.append({"pos": th_pos + Vector2(0, -12),
					"text": "%s -%d" % [str(data.get("kind", "陷阱")), int(data.get("amount", 0))],
					"col": Color("2b6fb3"), "start": n, "dur": 1400, "size": 18})
		"frozen":
			# 冰封（R68）：寒冰箭 9011 / 冰冻术士战吼 / 冻结陷阱 8013 的**唯一**施加特效。
			# 判据与常驻光环同源（引擎的 Placement.frozen），这里只演「施加的那一下」。
			var fz_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": fz_pos, "start": n, "dur": 620,
					"col": Color("9ad8ff"), "big": false})
			_bursts.append({"pos": fz_pos, "start": n + 90, "dur": 520,
					"col": Color("e8f6ff"), "big": false})
			_floaters.append({"pos": fz_pos + Vector2(0, -14), "text": "冰封",
					"col": Color("2b6fb3"), "start": n, "dur": 1500, "size": 20})
			_say("❄ %s 被冰封：下回合不能行动" % str(data.get("name", "")))
		"poison":
			# 剧毒陷阱（R51）：挂毒（apply）与回合开始的毒跳 —— 绿泡 + 飘字
			var po_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": po_pos, "start": n, "dur": 520,
					"col": Color("79c26a"), "big": false})
			if bool(data.get("apply", false)):
				_floaters.append({"pos": po_pos + Vector2(0, -12), "text": "中毒",
						"col": Color("3e8a2f"), "start": n, "dur": 1400, "size": 18})
				_say("☠ %s 中毒：每回合 %d 点伤害，持续 %d 回合" % [
						str(data.get("name", "")), int(data.get("dmg", 0)),
						int(data.get("left", 0))])
			else:
				_floaters.append({"pos": po_pos + Vector2(0, -12),
						"text": "中毒 -%d" % int(data.get("amount", 0)),
						"col": Color("3e8a2f"), "start": n, "dur": 1400, "size": 18})
		"hunt":
			# 暗影狩猎（9107，R52）：紫色爆点 —— 基础 12 伤；目标上回合触发过工事 → 24（金紫大字）
			sfx.play("spell")
			var hu_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			var hu_big := bool(data.get("big", false))
			_bursts.append({"pos": hu_pos, "start": n, "dur": 560,
					"col": Color("8a30b8"), "big": hu_big})
			_floaters.append({"pos": hu_pos + Vector2(0, -12),
					"text": ("狩猎翻倍！-%d" if hu_big else "暗影狩猎 -%d")
							% int(data.get("dmg", 0)),
					"col": Color("8a30b8"), "start": n, "dur": 1400,
					"size": 22 if hu_big else 18})
		"twin_trap":
			# 双重场地 9108：给某格挂上「触发后追加一个场地」的标记
			_say("⧉ 双重场地：%s 的场地触发后会追加一个随机场地" % str(data.get("cell", "")))
		"field_place":
			# 场地卡（R74）放置：斜纹格亮一下 + 提示挂在哪一格
			var fp_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var fp_pos := _cell_center(fp_cell)
			var fp_persist := GameEngine.is_persistent_field(data.get("card", null) as CardData)
			# 持续型场地（R83）用冷色 + 「持续生效」字样，别用一次性场地的「场地就位」。
			var fp_col := COL_FIELD_PERSIST if fp_persist else (
					COL_FIELD_SELF if str(data.get("side", GameEngine.SIDE_SELF)) == GameEngine.SIDE_SELF
					else COL_FIELD_FOE)
			_floaters.append({"pos": fp_pos + Vector2(0, -6),
					"text": "持续生效" if fp_persist else "场地就位",
					"col": fp_col, "start": n, "dur": 1200, "size": 15})
			_bursts.append({"pos": fp_pos, "start": n, "dur": 420,
				"col": fp_col, "big": false})
			if bool(data.get("chain", false)):
				_say("⧉ 双重场地连锁：%s 又挂上一个场地" % fp_cell)
			elif fp_persist:
				# 持续型场地（R83 清泉 / R88 维修间·改造工厂）：不会因经过而触发 →
				# 别说「移动经过时触发」，否则玩家会以为敌人走过去就把它引爆了。
				# 同样要**按生效对象分文案**：「友」的话明说只治自己人。
				var fpc := data.get("card", null) as CardData
				var fp_who := "只对自己的单位生效"
				if GameEngine.field_aim(fpc) == GameEngine.FIELD_AIM_ALLY:
					fp_who = "只对自己的单位生效"
				else:
					fp_who = "敌我双方都算"
				var fp_what := "站在这里的单位在自己回合结束时回血"
				if fpc.traits.has(GameEngine.PERSIST_UPGRADE_TRAIT):
					fp_what = "每回合获得改造 +1 力 / +1 血（可无限叠）"
				_say("%s → %s（持续生效：%s，%s）" % [
					fpc.card_name, fp_cell, fp_what, fp_who])
			else:
				_say("%s → %s（敌人移动经过时触发并停止移动）" % [
					str((data.get("card", null) as CardData).card_name), fp_cell])
		"fountain":
			# 持续型场地回血（清泉 8028 / 维修间 8036，R88）：自己回合结束时给站着的单位回血
			# → 该格飘字。`field` 带场地名（维修间与清泉共用这个事件）。
			sfx.play("heal")
			var fo_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": fo_pos, "text": "+%d" % int(data.get("amount", 0)),
					"col": COL_FIELD_PERSIST, "start": n, "dur": 1400, "size": 18})
		"field_trigger":
			# 场地触发（R74；R80 扩为「经过即触发」）：敌人移动路上撞到 → 一次性结算
			_say("⚡ 场地触发：%s 踩到了 %s（移动已停止）" % [str(data.get("name", "")),
				str((data.get("card", null) as CardData).card_name)])
			sfx.play("destroy")
		"twin_field":
			# 双重场地（9108，R74 由「双重陷阱」改名）：给格子上的场地挂连锁 —— 紫色微光 + 飘字
			var dt_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": dt_pos, "start": n, "dur": 420,
					"col": Color("8a30b8"), "big": false})
			_floaters.append({"pos": dt_pos + Vector2(0, -12), "text": "双重场地",
					"col": Color("5e35b1"), "start": n, "dur": 1400, "size": 18})
			_say("♻ 双重场地：%s 的场地触发并结束后 → 同格补一张随机场地" % str(data.get("name", "该格")))
		"charge":
			# 蓄力（9085）：攒一层 —— 下一张技能生效 N+1 次（金色提示，压在技能结算飘字上方）
			sfx.play("spell")
			var ch_n: int = int(data.get("count", 0))
			_say("⚡ 蓄力 ×%d：下一张技能生效 %d 次" % [ch_n, ch_n + 1])
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y - 62),
					"text": "蓄力 ×%d → 下一张技能生效 %d 次" % [ch_n, ch_n + 1],
					"col": Color("b8860b"), "size": 16, "outline": 6,
					"start": n, "dur": 2200})
		"bear_heal":
			# 熊（8004）发动回春：绿色爆点 + 「+N」飘字
			sfx.play("place")
			var bh_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": bh_pos, "start": n, "dur": 520,
					"col": Color("4caf50"), "big": false})
			_floaters.append({"pos": bh_pos + Vector2(0, -12),
					"text": "回春 +%d" % int(data.get("amount", 0)),
					"col": Color("1d7a4f"), "start": n, "dur": 1400, "size": 18})
			_say("❦ %s 发动回春：回复 %d 点生命，之后横置" % [
					str(data.get("name", "熊")), int(data.get("amount", 0))])
		"wild_form_guard":
			# 荒野形态（6022，R60 重做）：每场第一次我方 HP 被普通攻击打中 →
			# 这次伤害 -4（最少 1）+ 对攻击者反伤 4。
			var wg_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": wg_pos, "start": n, "dur": 560,
					"col": Color("4caf50"), "big": true})
			_floaters.append({"pos": wg_pos + Vector2(0, -30),
					"text": "荒野形态 减伤 %d" % int(data.get("reduced", 0)),
					"col": Color("7fd18a"), "start": n, "dur": 1500, "size": 17})
			_floaters.append({"pos": wg_pos + Vector2(0, -8),
					"text": "反伤 %d" % int(data.get("amount", 0)),
					"col": Color("e07a6a"), "start": n, "dur": 1500, "size": 19})
			_say("❦ 荒野形态（每场第一次）：我方伤害 -%d，并对 %s 造成 %d 点伤害" % [
					int(data.get("reduced", 0)), str(data.get("name", "敌人")),
					int(data.get("amount", 0))])
		"phantom_cloak":
			# 幻影斗篷（6023，暗影刺客角色道具）：R60 起每使用**两张**牌 → 随机敌方单位力量 -1
			var pc_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": pc_pos, "start": n, "dur": 420,
					"col": Color("7e57c2"), "big": false})
			_floaters.append({"pos": pc_pos + Vector2(0, -12),
					"text": "幻影斗篷 力量 -%d" % int(data.get("amount", 0)),
					"col": Color("5e35b1"), "start": n, "dur": 1400, "size": 17})
			_say("❧ 幻影斗篷：本回合每用一张牌 → %s 力量 -%d（当前 %d）" % [
					str(data.get("name", "敌人")), int(data.get("amount", 0)),
					int(data.get("power", 0))])
		"meteor":
			# 流星雨（9083）：每一颗的落点（引擎给 cell）—— 紫色爆点 + 伤害飘字
			var m_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var m_pos := _cell_center(m_cell) if m_cell.x >= 0 \
					else Vector2(GRID_X + GRID_W / 2, GRID_Y - 36)
			_bursts.append({"pos": m_pos, "start": n, "dur": 520,
					"col": Color("9b59d0"), "big": false})
			_floaters.append({"pos": m_pos + Vector2(0, -12),
					"text": "-%d" % int(data.get("dmg", 0)),
					"col": Color("7a2a7a"), "start": n, "dur": 1200})
		"fire_wall":
			# 火墙术（9084）：整行燃起 —— 三格同时起火 + 一行提示
			sfx.play("spell")
			var fw_row2: int = int(data.get("row", -1))
			for fw_col in FieldState.BOARD_COLS:
				_bursts.append({"pos": _cell_center(Vector2i(fw_row2, fw_col)),
						"start": n, "dur": 620, "col": Color("ff8a3d"), "big": false})
			_shake(6.0, 300)
			var fw_name := "火墙术"
			if data.get("card") is CardData:
				fw_name = (data["card"] as CardData).card_name
			_say("🔥 %s：第 %d 行燃起火墙（经过者 -%d，同一单位上限 %d）" % [
					fw_name, fw_row2, GameEngine.FIRE_WALL_PASS_DMG,
					GameEngine.FIRE_WALL_CAP])
		"fire_wall_hit":
			# 火墙开场那一炸：橙色爆点 + 伤害飘字
			var fh_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": fh_pos, "start": n, "dur": 560,
					"col": Color("ff6a00"), "big": false})
			_floaters.append({"pos": fh_pos + Vector2(0, -12),
					"text": "-%d" % int(data.get("dmg", 0)),
					"col": Color("d84a12"), "start": n, "dur": 1200})
		"fire_wall_pass":
			# 穿过燃烧横行的单位被灼烧（不分敌我）
			var fp_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": fp_pos, "start": n, "dur": 560,
					"col": Color("ff8a3d"), "big": false})
			_floaters.append({"pos": fp_pos + Vector2(0, -12),
					"text": "火墙 -%d" % int(data.get("dmg", 0)),
					"col": Color("d84a12"), "start": n, "dur": 1300, "size": 18})
		"stun_blow":
			# 敲晕（9088）：目标力量 -3（金色爆点 + 飘字）
			var sb_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": sb_pos, "start": n, "dur": 480,
					"col": Color("ffd54f"), "big": false})
			_floaters.append({"pos": sb_pos + Vector2(0, -12),
					"text": "敲晕 力量 -%d" % int(data.get("amount", 0)),
					"col": Color("b8860b"), "start": n, "dur": 1300, "size": 16})
		"dark_trap":
			# 黑暗陷阱（8063，R105）：踩中者本回合攻击时力量 -1（暗紫爆点 + 飘字）
			var dt_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": dt_pos, "start": n, "dur": 480,
					"col": Color("9b6bd6"), "big": false})
			_floaters.append({"pos": dt_pos + Vector2(0, -12),
					"text": "黑暗 力量 -%d" % int(data.get("amount", 0)),
					"col": Color("6a3fa0"), "start": n, "dur": 1300, "size": 16})
		"gale":
			# 疾风（9091）：随机敌人吃 2 伤
			var ga_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_bursts.append({"pos": ga_pos, "start": n, "dur": 420,
					"col": Color("9bdcff"), "big": false})
			_floaters.append({"pos": ga_pos + Vector2(0, -12),
					"text": "疾风 -%d" % int(data.get("dmg", 0)),
					"col": Color("2a7ab8"), "start": n, "dur": 1200})
		"lurker":
			# 潜影者（8009）：每用一张牌 +1 力量
			var lk_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": lk_pos + Vector2(0, -12),
					"text": "潜影者 +1 力量",
					"col": Color("6a4fb8"), "start": n, "dur": 1100, "size": 15})
		"attack_energy":
			# 地狱咏唱者 8022 / 黑暗祭坛 8023：攻击时回复费用
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y - 12),
					"text": "%s · 攻击时费用 +%d" % [str(data.get("name", "")),
						int(data.get("amount", 0))],
					"col": Color("2f9e5e"), "start": n, "dur": 1500})
			sfx.play("heal")
		"dark_spread":
			# 黑暗扩散 9113：剩余费用换算的全体敌人伤害
			var ds_dmg := int(data.get("dmg", 0))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H + 24),
					"text": "黑暗扩散 · 剩余 %d 费用 → 全体敌人 -%d"
						% [int(data.get("left", 0)), ds_dmg],
					"col": Color("5a2a8a"), "start": n, "dur": 2000})
			sfx.play("attack")
		"endless_dark":
			# 无尽黑暗 9114（R70）：不再随机弃牌，改为**开面板让玩家选**。
			# pending=true → 只提示「请选一张」；pending=false 且能量 0 → 手牌为空、本回合落空。
			if bool(data.get("pending", false)):
				_say("∞ 无尽黑暗：请从手牌里选 1 张弃掉（不能不选）→ 之后费用 +%d"
						% int(data.get("energy", 0)))
			elif int(data.get("energy", 0)) > 0:
				_say("∞ 无尽黑暗：费用 +%d" % int(data.get("energy", 0)))
			else:
				_say("∞ 无尽黑暗：手牌为空，没有可弃的牌 → 本回合不弃也不给费用")
		"dark_lord":
			# 黑暗领主（8021）：回合结束优先结算 → 费用 +5
			var dl_energy := int(data.get("amount", 0))
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H - 30),
					"text": "黑暗领主 · 回合结束费用 +%d" % dl_energy,
					"col": Color("8a2be2"), "start": n, "dur": 2000})
			sfx.play("heal")
		"dark_blade":
			# 暗影之刃（9111）：按本回合已花费用对随机敌人造成伤害
			var db_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			_floaters.append({"pos": _cell_center(db_cell) + Vector2(0, -12),
					"text": "暗影之刃 -%d" % int(data.get("dmg", 0)),
					"col": Color("6a4aa0"), "start": n, "dur": 1600, "size": 17})
			_bursts.append({"pos": _cell_center(db_cell), "start": n, "dur": 460,
					"col": Color("6a4aa0"), "big": false})
			sfx.play("attack")
		"dark_chain":
			# 暗影锁链（9112）：击退提示（_knockback 自己会 emit "move" 播移动动画）
			var dc_times := int(data.get("times", 0))
			var dc_moved := int(data.get("moved", 0))
			if dc_times > 0:
				_say("⛓ 暗影锁链：剩余费用换算 %d 次击退（每次 2 格），实际移动 %d 次"
						% [dc_times, dc_moved])
		"surplus":
			# 回合结束 · 剩余费用（R55）：地狱猫 8019 / 鲜血堡垒 8020 永久成长
			var sp_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var sp_pos := _cell_center(sp_cell)
			_floaters.append({"pos": sp_pos + Vector2(0, -12),
					"text": "+%d 力 +%d 生" % [int(data.get("atk", 0)), int(data.get("hp", 0))],
					"col": Color("c0392b"), "start": n, "dur": 1500, "size": 16})
			sfx.play("heal")
		"vitality":
			# 活力转移（9110）：上回合结转的额外费用在本回合开始发放
			var vt_side := str(data.get("side", GameEngine.SIDE_SELF))
			var vt_pos := Vector2(GRID_X + GRID_W / 2, GRID_Y - 12) \
					if vt_side == GameEngine.SIDE_SELF \
					else Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H + 24)
			_floaters.append({"pos": vt_pos,
					"text": "活力转移 · 本回合费用 +%d" % int(data.get("energy", 0)),
					"col": Color("2f9e5e"), "start": n, "dur": 2100})
			sfx.play("heal")
		"contractor":
			# 契约签订者（8024，R63）：登场回 4 费 + 本回合手卡全体涨价 4
			var ct_pos:= _cell_center(data.get("cell", Vector2i(-1, -1)))
			_floaters.append({"pos": ct_pos + Vector2(0, -18),
				"text": "契约签订者 +%d 费" % int(data.get("energy", 0)),
				"col": Color("8a2be2"), "start": n, "dur": 1800, "size": 17})
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H + 60),
				"text": "本回合手卡费用 +%d" % int(data.get("raise", 0)),
				"col": Color("b8860b"), "start": n, "dur": 2200, "size": 16})
			sfx.play("heal")
		"earring_autoplay_begin":
			# 鸭语耳环自动出牌开始（R77）：横幅提示 + 复位播放状态。
			_earring_at = _now()
			_earring_i = 0
			_earring_done = false
			_banner = {"text": "鸭语耳环 · 自动出牌", "col": Color("b07bff"),
					"start": _now(), "dur": 1600}
			status_text = "鸭语耳环：第 1 回合不抽牌，开始自动出牌（会一张一张出）"
			_say("鸭语耳环：自动出牌开始（逐张播放）")
		"earring_autoplay_step":
			# 每出一张：飘出「第 N 张 · 卡名」，玩家能看清到底出了什么。
			var es_name: String = str(data.get("card_name", "?"))
			var es_i: int = int(data.get("index", 0)) + 1
			_floaters.append({"pos": Vector2(WINDOW_W / 2, GRID_Y + 26),
					"text": "自动出牌 %d · %s" % [es_i, es_name],
					"col": Color("c9a0f0"), "start": n, "dur": 1100, "size": 20})
		"earring_autoplay_end":
			# 收尾：横幅换成完成提示，解锁玩家操作。
			_earring_done = true
			var ee_why: String = str(data.get("why", ""))
			var ee_played: int = int(data.get("played", 0))
			_banner = {"text": "鸭语耳环 · 自动出牌 %d 张" % ee_played,
					"col": Color("b07bff"), "start": _now(), "dur": 1500}
			status_text = "鸭语耳环：自动出牌结束（%d 张 · %s），可以行动了" % [ee_played, ee_why]
			_say("♬ 鸭语耳环：自动出牌 %d 张结束（%s）" % [ee_played, ee_why])
		"wake":
			# 恶魔鸭（9116，R63 / R72 补特效）：沉睡结束 / 被击中提前醒来。
			# R72：原来只有一圈爆点 + 飘字，「挣脱束缚」的观感不足；补一圈向外扩散的
			# 紫色冲击环（从卡面中心扩散出去），和常驻的沉睡环在颜色上呼应 ——
			# 玩家扫一眼就知道「刚才那圈紫的就是这个状态，现在它没了」。
			var wk_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var wk_pos:= _cell_center(wk_cell)
			var wk_txt := "恶魔鸭 苏醒"
			var wk_col := Color("9b6bff")
			if bool(data.get("hurt", false)):
				wk_txt = "恶魔鸭 提前醒来"
				wk_col = Color("d84a12")
			# 挣脱环：2 圈错峰扩散的描边圆（不是实心块，保留卡面可读性）
			for _wi in 2:
				_wake_rings.append({"pos": wk_pos, "start": n + _wi * 130,
					"dur": 620, "col": wk_col})
			_floaters.append({"pos": wk_pos + Vector2(0, -18), "text": wk_txt,
				"col": wk_col, "start": n, "dur": 1600, "size": 17})
			_bursts.append({"pos": wk_pos, "start": n, "dur": 520,
				"col": wk_col, "big": false})
			sfx.play("attack")
		"demon_rage":
			# 恶魔鸭（9116）：醒着受伤 → 永久 +1 力量
			var dr_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			_floaters.append({"pos": _cell_center(dr_cell) + Vector2(0, -18),
				"text": "恶魔鸭 力量 +%d（%d）" % [int(data.get("amount", 0)),
					int(data.get("power", 0))],
				"col": Color("c0392b"), "start": n, "dur": 1600, "size": 16})
			sfx.play("attack")
		"demon_revenge":
			# 恶魔鸭（复仇）9118：每次受伤 → **本回合**力量 +1（可叠加）。
			# 与 9116 的 `demon_rage`（永久 +1）刻意区分：这里飘的是**累计值**
			#（"本回合 +3"），让玩家一眼看到"我打得多，它就疼得多"，
			# 从而意识到「这一回合得收手了」——这是这只 Boss 的核心决策点。
			var rv_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var rv_pos := _cell_center(rv_cell)
			_floaters.append({"pos": rv_pos + Vector2(0, -18),
				"text": "复仇 本回合 +%d（力量 %d）" % [int(data.get("stacked", 0)),
					int(data.get("power", 0))],
				"col": Color("ff5722"), "start": n, "dur": 1500, "size": 16})
			_bursts.append({"pos": rv_pos, "start": n, "dur": 460,
				"col": Color("ff8a3d"), "big": false})
			sfx.play("attack")
		"demon_summon":
			# 恶魔使魔（9117）：每回合开始随机空格召唤使魔鸭子
			var dm_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			_bursts.append({"pos": _cell_center(dm_cell), "start": n, "dur": 560,
				"col": Color("9b6bff"), "big": true})
			_floaters.append({"pos": _cell_center(dm_cell) + Vector2(0, -22),
				"text": "恶魔使魔 召唤", "col": Color("6a3fb5"),
				"start": n, "dur": 1700, "size": 16})
			sfx.play("spell")
		"whirl_blade":
			# 回旋斩（9096）：十字命中提示
			_say("🌀 回旋斩：命中 %d 个敌方单位（各 %d 伤）" % [
					int(data.get("hits", 0)), int(data.get("dmg", 0))])
		"infiltrate":
			# 潜入（9100）：移动 + 本回合力量 +3
			_say("❧ 潜入：%s 移动 → 本回合力量 +%d（当前 %d）" % [
					str(data.get("name", "盟友")), int(data.get("amount", 0)),
					int(data.get("power", 0))])
		"latent":
			# 潜伏（9092）：回合开始多抽
			_say("🌙 潜伏：回合开始多抽 1 张「%s」" % str(data["card"].card_name))
		"glowgrass":
			# 幽光（9099）：荧光草塞进手卡
			_say("🌿 幽光：一张「荧光草」加入手卡")
		"ghost_fetch":
			var ghf_c = data.get("card")
			_say("👻 幽灵消散：%s" % (("「%s」加入手卡" % ghf_c.card_name) if ghf_c != null else "卡组里没有技能卡"))
		"sleepless":
			# 不眠（9101）：没手牌时补抽
			_say("🌙 不眠：手里没牌 → 抽 1 张「%s」" % str(data["card"].card_name))
		"shadow_cat":
			var sc_c = data.get("card")
			_say("🐈 影子猫：%s" % (("「%s」加入手卡" % sc_c.card_name) if sc_c != null else "卡组里没有技能卡"))
		"shadow_demon":
			# 影魔（8007）：技能牌 -1 费 + 0 费技能卡加生命
			_say("😈 影魔：手卡技能牌本回合 -1 费；0 费技能卡 %d 张 → 生命 +%d（当前 %d）" % [
					int(data.get("zero", 0)), int(data.get("gained", 0)),
					int(data.get("health", 0))])
		"foresight":
			var fs_c = data.get("card")
			_say("🔮 预判②：%s" % (("「%s」加入手卡" % fs_c.card_name) if fs_c != null else "卡组里没有非 0 费技能卡"))
		"foresight_pick":
			_say("🔮 预判：%s 回到手卡（本卡已消失）" % str(data["card"].card_name))
		"fate_pick":
			_say("🃏 拒绝命运：%s 回到手牌" % str(data["card"].card_name))
		"alert":
			# 警觉（9109，R54）：随机工事进手，那张卡费用 -2
			var al_c = data.get("card")
			var al_name: String = al_c.card_name if al_c != null else "?"
			var al_disc := int(data.get("discount", 0))
			_floaters.append({"pos": Vector2(WINDOW_W / 2, GRID_Y + GRID_H - 60),
					"text": "警觉 · %s -%d 费" % [al_name, al_disc],
					"col": Color("7a2a7a"), "start": n, "dur": 1800, "size": 18})
			_say("🃏 警觉：随机工事「%s」进入手卡（费用 -%d）" % [al_name, al_disc])


func _shake(mag: float, ms: int) -> void:
	## 触发屏幕震动（取更大幅度、更晚截止）。
	_shake_mag = maxf(_shake_mag if _now() < _shake_until else 0.0, mag)
	_shake_until = maxi(_shake_until, _now() + ms)


func _shake_offset() -> Vector2:
	var remain := _shake_until - _now()
	if remain <= 0:
		return Vector2.ZERO
	var t := float(remain) / 380.0  # 相对启动时长的衰减因子（近似）
	var m := _shake_mag * clampf(t, 0.15, 1.0)
	return Vector2(randf_range(-m, m), randf_range(-m, m))


func _draw_flashes() -> void:
	## 受击闪色：在卡片位置叠一层半透明色块（淡出）。
	## 也包括「垂死卡」——它们已离开棋盘，但仍在屏幕上显示到命中演出结束。
	var n := _now()
	var items: Array = []
	for pair: Array in engine.state.iter_board():
		var pl: Placement = pair[1]
		items.append([pl, pair[0], TAP_W if pl.tapped else CARD_W,
				TAP_H if pl.tapped else CARD_H])
	for d: Dictionary in _dying:
		if d.get("p") != null:
			items.append([d.p, d.cell, CARD_W, CARD_H])
	for it: Array in items:
		var p: Placement = it[0]
		if not _flashes.has(p):
			continue
		var fl: Dictionary = _flashes[p]
		var raw := float(n - int(fl.start)) / int(fl.dur)
		if raw <= 0.0:
			continue  # 延迟启动的闪色
		var t := clampf(raw, 0.0, 1.0)
		var cell: Vector2i = it[1]
		var w: float = it[2]
		var h: float = it[3]
		var rect := Rect2(_display_center(p, cell) - Vector2(w, h) / 2.0, Vector2(w, h))
		var col: Color = fl.col
		col.a = 0.62 * (1.0 - t)
		draw_rect(rect, col)
		draw_rect(rect, Color(col.r, col.g, col.b, 0.9 * (1.0 - t)), false, 2.5)


func _draw_bursts() -> void:
	## 打击爆点：扩散环 + 放射火花线。
	var n := _now()
	for b: Dictionary in _bursts:
		var t := clampf(float(n - int(b.start)) / int(b.dur), 0.0, 1.0)
		if t <= 0.0:
			continue
		var pos: Vector2 = b.pos
		var big: bool = b.big
		var r_max := 52.0 if big else 34.0
		var col: Color = b.col
		# 扩散环（外圈）
		var ring_r := r_max * (0.3 + 0.7 * t)
		col.a = 0.85 * (1.0 - t)
		draw_arc(pos, ring_r, 0.0, TAU, 28, col, 3.0 if big else 2.2)
		# 内圈亮环（前半段）
		if t < 0.5:
			var col2 := Color(1, 1, 1, 0.7 * (1.0 - t * 2.0))
			draw_arc(pos, ring_r * 0.55, 0.0, TAU, 20, col2, 2.0)
		# 放射火花（8 条短线，随时间飞出变短）
		var lines := 10 if big else 7
		var rot0 := pos.x * 0.7 + pos.y * 1.3  # 固定随机相位
		for i in lines:
			var ang := rot0 + TAU * i / lines
			var far := ring_r + 10.0
			var near := far * (0.55 - 0.35 * t)
			var dir := Vector2(cos(ang), sin(ang))
			var lcol := Color(col.r, col.g, col.b, 0.9 * (1.0 - t))
			draw_line(pos + dir * near, pos + dir * far, lcol, 2.0 if big else 1.5)


func _draw_wake_rings() -> void:
	## 恶魔鸭苏醒（R72）：一圈圈向外扩散并淡出的**空心**挣脱环。
	## 为什么不用 _bursts：那个是打击爆点（带放射火花、收缩的内圈），观感是「被打」。
	## 苏醒是「挣脱束缚」，用**只扩张、不收缩、无线条**的环，且比爆点晚画（压在上层）——
	## 常驻的紫色沉睡环正在同一位置消失，这一圈紫色扩散正好接上，状态变化的因果一眼可见。
	var n := _now()
	for r: Dictionary in _wake_rings:
		var t := clampf(float(n - int(r.start)) / int(r.dur), 0.0, 1.0)
		if t <= 0.0:
			continue
		var pos: Vector2 = r.pos
		var col: Color = r.col
		# 半径：卡面外扩到 ~1.6 倍卡宽；ease-out 让它「冲出去」再消失
		var ease := 1.0 - pow(1.0 - t, 2.0)
		var rad := 18.0 + ease * 52.0
		col.a = 0.9 * (1.0 - t)
		draw_arc(pos, rad, 0.0, TAU, 40, col, 3.0)
		if t < 0.55:
			# 内侧留一道更亮的细环，强化「冲破」的感觉
			var c2 := Color(1.0, 0.96, 1.0, 0.55 * (1.0 - t / 0.55))
			draw_arc(pos, rad * 0.86, 0.0, TAU, 32, c2, 1.5)


func _apply_delayed(kind: String, d: Dictionary) -> void:
	## 定时特效到点：攻击在冲刺结束那一刻才"命中"。
	var n := _now()
	match kind:
		"destroy_fx":
			if d.has("cell"):
				var c: Vector2i = d["cell"]
				_dying = _dying.filter(func(x): return x.cell != c)
			_play_destroy_fx(d.center as Vector2, d.card as CardData)
		"hit":
			sfx.play("attack")
			var def = d.get("def")
			if def != null:
				_flashes[def] = {"col": Color(0.9, 0.15, 0.1), "start": n, "dur": 420}
				_drop_hp(def)   # 命中演出到点：卡面生命数字才开始往下掉
			_bursts.append({"pos": d.pos, "start": n, "dur": 520,
					"col": Color("ffb300"), "big": false})
			_floaters.append({"pos": (d.pos as Vector2) + Vector2(0, -10),
					"text": "-%d" % int(d.dmg), "col": Color("c62828"),
					"start": n, "dur": 1150})
			_shake(5.0, 260)
		"hp_hit":
			var hk = d.get("hpkey")
			if hk != null:
				_drop_hp(hk)   # 撞击演出到点：HP 横幅数字才开始往下掉
			# 直击 HP 撞上横幅：爆点 + 掉血飘字 + 震屏（与冲锋动作对齐）；
			# 「溢出」用 label 字段区分，好认是哪一下漏过去的。
			sfx.play("attack")
			_bursts.append({"pos": d.pos as Vector2, "start": n, "dur": 600,
					"col": Color("ff7043"), "big": true})
			_floaters.append({"pos": (d.pos as Vector2) + Vector2(0, -6),
					"text": str(d.get("label", "-%d" % int(d.dmg))),
					"col": Color("c62828"), "start": n, "dur": 1250, "size": 20})
			_shake(6.5, 320)


func _play_destroy_fx(center: Vector2, card: CardData) -> void:
	## 击破演出：音效 + 卡牌幽灵淡出 + 大爆点 + 「击破」飘字 + 震屏。
	sfx.play("destroy")
	_ghosts.append({"center": center,
			"name": str(card.card_name), "start": _now(), "dur": 800})
	_bursts.append({"pos": center, "start": _now(), "dur": 640,
			"col": Color("e53935"), "big": true})
	_floaters.append({"pos": center + Vector2(0, -14), "text": "击破",
			"col": Color("555555"), "start": _now(), "dur": 1000})
	_shake(9.0, 380)


func _draw_attack_fx() -> void:
	## 「谁攻击了谁」投射演出：锁定环 → 攻击者蓄力 → 弹体沿轨迹飞向目标 → 命中。
	var n := _now()
	for pair: Array in engine.state.iter_board():
		var p: Placement = pair[1]
		if not _attacks.has(p):
			continue
		var a: Dictionary = _attacks[p]
		if n < int(a.start):
			continue   # 排队中：等前一段（如滑行）演完再开始，避免两段互相吞
		var t := clampf(float(n - int(a.start)) / int(a.dur), 0.0, 1.0)
		var src := a.src as Vector2
		var dst := a.dst as Vector2
		var adir := a.dir as Vector2
		var dmg := int(a.get("dmg", 2))
		var is_hp := str(a.get("kind", "unit")) == "hp"
		if not is_hp:
			# ① 目标锁定环：脉动双圈，命中前钉在目标头上，命中后淡出
			var ring_a := 0.9 * (0.75 + 0.25 * sin(n / 90.0)) * minf(t * 6.0, 1.0)
			if t > ATK_IMPACT_T:
				ring_a *= 1.0 - (t - ATK_IMPACT_T) / (1.0 - ATK_IMPACT_T)
			draw_arc(dst, 30.0, 0.0, TAU, 28, Color(0.85, 0.12, 0.1, ring_a), 3.0)
			draw_arc(dst, 38.0, 0.0, TAU, 28, Color(0.85, 0.12, 0.1, ring_a * 0.4), 1.6)
			# ② 预告轨迹线：虚线感的淡色引导线（发射前显示）
			if t < ATK_LAUNCH_T + 0.08:
				var guide := Color(1.0, 0.55, 0.15, 0.28)
				draw_dashed_line(src + adir * 30.0, dst, guide, 2.0, 10.0)
		# ③ 攻击者蓄力光环（发射前脉动变亮）
		if t < ATK_LAUNCH_T:
			var charge := t / ATK_LAUNCH_T
			draw_arc(src, 34.0 + 4.0 * sin(n / 70.0), 0.0, TAU, 24,
					Color(1.0, 0.6, 0.1, 0.25 + 0.45 * charge), 2.0 + charge * 2.0)
		if is_hp:
			# ④' 直击 HP：没有弹体，撞上去那一刻在身前炸开一道冲击弧
			if t >= ATK_IMPACT_T and t <= ATK_IMPACT_T + 0.28:
				var kh := (t - ATK_IMPACT_T) / 0.28
				draw_line(src + adir * 12.0, src + adir * (36.0 + 30.0 * kh),
						Color(1.0, 0.68, 0.28, 0.75 * (1.0 - kh)), 4.0)
				draw_arc(src + adir * 34.0, 34.0 + 66.0 * kh, 0.0, TAU, 26,
						Color(1.0, 0.45, 0.15, 0.85 * (1.0 - kh)), 3.5)
		elif t >= ATK_LAUNCH_T and t <= ATK_IMPACT_T + 0.06:
			# ④ 弹体：从攻击者飞向目标（加速），带拖尾与光晕
			var fk := clampf((t - ATK_LAUNCH_T) / (ATK_IMPACT_T - ATK_LAUNCH_T), 0.0, 1.0)
			var ke := fk * fk * 0.4 + fk * 0.6  # 轻微加速
			var pos := src.lerp(dst, ke)
			var r := 5.0 + minf(dmg, 6.0)       # 弹体大小随攻击力
			# 拖尾：沿飞行反方向渐隐
			var tail := pos - adir * (34.0 + 26.0 * (1.0 - fk))
			var trail := Color(1.0, 0.5, 0.1, 0.55 * (1.0 - fk * 0.5))
			draw_line(tail, pos, trail, r * 0.9)
			draw_line(tail - adir * 22.0, tail, Color(1.0, 0.5, 0.1, 0.22), r * 0.5)
			# 光晕 + 亮核
			draw_circle(pos, r + 6.0, Color(1.0, 0.55, 0.1, 0.35))
			draw_circle(pos, r, Color(1.0, 0.62, 0.12, 0.95))
			draw_circle(pos, r * 0.45, Color(1.0, 0.95, 0.75, 1.0))


func _draw_ghosts() -> void:
	var n := _now()
	for g: Dictionary in _ghosts:
		var t := clampf(float(n - int(g.start)) / int(g.dur), 0.0, 1.0)
		var alpha := 1.0 - t
		var center: Vector2 = g.center
		var rect := Rect2(center - Vector2(CARD_W, CARD_H) / 2.0, Vector2(CARD_W, CARD_H))
		draw_rect(rect, Color(1, 1, 1, 0.85 * alpha))
		draw_rect(rect, Color(0.6, 0.6, 0.6, alpha), false, 1.5)
		_draw_string_center(_font, 9, str(g.name), center + Vector2(0, 4),
				Color(0.3, 0.3, 0.3, alpha))


func _draw_floaters() -> void:
	var n := _now()
	for f: Dictionary in _floaters:
		var t := clampf(float(n - int(f.start)) / int(f.dur), 0.0, 1.0)
		if t <= 0.0:
			continue  # 延迟启动的飘字
		var alpha := 1.0 - t * t
		var pos: Vector2 = f.pos + Vector2(0, -30.0 * t)
		var col: Color = f.col
		# 伤害数字更大更醒目；文字类（法术/击破）保持原字号
		var size := int(f.get("size", 20 if str(f.text).begins_with("-") else 15))
		# 白色描边：浅色棋盘上飘字才够醒目（粗细随字号走；"outline": 0 可单条关掉）
		var ow := int(f.get("outline", clampi(int(round(size * 0.26)), 2, 5)))
		col.a = alpha
		var oc: Color = f.get("outline_col", Color(1, 1, 1))
		oc.a = alpha
		_draw_string_center(_font_bold, size, str(f.text), pos, col, ow, oc)


func _draw_highlights() -> void:
	for cell in move_targets:
		_hl(cell, COL_MOVE)
	for cell in attack_targets_arr:
		_hl(cell, COL_ATTACK)
	for cell in hp_targets_arr:
		_hl(cell, COL_HP)
		_draw_string_center(_font_bold, 14, "HP", _cell_center(cell), Color.WHITE)
	for cell in spell_targets:
		_hl(cell, COL_SPELL)
	# R102：两段式技能**已选中第一个单位**的标记（金黄粗描边 + 角标「已选」）。
	# 潜伏 9100 与双向传送 8061 共用这一套 —— 满足「选中哪个要看得见、右键能取消」。
	_draw_picked_marker()
	# 叠栅栏（栅栏修复术 6021）：选中的手牌是栅栏时，把可合并的己方栅栏格标成橙色「叠」
	if selection != null and selection[0] == "hand" \
			and selection[1] >= 0 and selection[1] < engine.state.hand.size():
		var sel_card: CardData = engine.state.hand[selection[1]]
		for mcell in _fence_merge_cells(sel_card):
			_hl(mcell, COL_FENCE_MERGE)
			_draw_string_center(_font_bold, 13, "叠", _cell_center(mcell), Color.WHITE)


func _picked_src() -> Vector2i:
	## 当前「两段式技能已选中的第一个单位」格 —— 潜入与双向传送共用一个入口。
	if _infiltrate_src.x >= 0:
		return _infiltrate_src
	if _swap_src.x >= 0:
		return _swap_src
	return Vector2i(-1, -1)


func _draw_picked_marker() -> void:
	## 在**已选中**的那个单位格上画金黄粗描边 + 角标「已选」。
	## 用描边而不是 `_hl` 的整格填充：填充会把单位本体盖住，正好违背"标明选中了哪个"。
	var src := _picked_src()
	if src.x < 0 or not engine.state.board.has(src):
		return
	var r := Rect2(GRID_X + src.y * CELL + 1, GRID_Y + src.x * CELL + 1,
			CELL - 2, CELL - 2)
	draw_rect(r, COL_PICKED, false, 4.0)
	# 角标：右上角小方块 + 「已选」两字
	var tag := Rect2(r.position.x + r.size.x - 34.0, r.position.y + 1.0, 33.0, 14.0)
	draw_rect(tag, COL_PICKED)
	_draw_string_center(_font_bold, 10, "已选",
			tag.position + tag.size / 2.0, Color.BLACK)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(GRID_X + cell.y * CELL + CELL / 2, GRID_Y + cell.x * CELL + CELL / 2)


func _hl(cell: Vector2i, col: Color) -> void:
	draw_rect(Rect2(GRID_X + cell.y * CELL + 2, GRID_Y + cell.x * CELL + 2, CELL - 4, CELL - 4), col)


func _draw_hp_banner() -> void:
	var mid_x := GRID_X + GRID_W + 18
	_draw_string_nw(_font_bold, 12, "敌方 HP\n%d" % _show_hp("hp_opp", engine.state.hp_opponent),
			Vector2(mid_x, GRID_Y + 8), COL_LOSE)
	_draw_string_nw(_font, 9, "敌方能量 %d" % engine.state.opp_energy,
			Vector2(mid_x, GRID_Y + 66), Color("8a5a00"))
	_draw_string_nw(_font_bold, 12, "我方 HP\n%d/%d" % [_show_hp("hp_self", engine.state.hp_self),
			engine.state.max_hp_self],
			Vector2(mid_x, GRID_Y + GRID_H - 30), Color("1b5e20"))
	_draw_string_nw(_font, 9, "能量 %d" % engine.state.energy,
			Vector2(mid_x, GRID_Y + GRID_H - 56), Color("1b5e20"))
	if engine.state.level_name != "":
		_draw_string_center(_font, 9, "关卡：%s" % engine.state.level_name,
				Vector2(GRID_X + GRID_W / 2, GRID_Y + GRID_H + 16), Color("666666"))


func _enemy_zone_rect() -> Rect2:
	## 右栏敌方效果区外框（敌方 HP/能量文本下方）。
	return Rect2(GRID_X + GRID_W + 18, GRID_Y + 88, TAP_W + 12, 3 * (TAP_H + 10) + 44)


func _enemy_effect_rect(i: int) -> Rect2:
	## 敌方效果区第 i 张卡的屏幕矩形（与绘制顺序一致）。
	var z := _enemy_zone_rect()
	return Rect2(z.position.x + 4, z.position.y + 32.0 + i * (TAP_H + 10.0),
			TAP_W, TAP_H)


func _draw_enemy_effects() -> void:
	## 右栏：敌方效果区（红色调，开局启用的效果卡正面朝上持续生效）。
	var state := engine.state
	var z := _enemy_zone_rect()
	draw_rect(z, Color(0.88, 0.72, 0.72, 0.30), true)
	draw_rect(z, Color("a87a7a"), false, 1.0)
	_draw_string_center(_font_bold, 9, "敌方效果 %d" % state.enemy_effects.size(),
			Vector2(z.position.x + z.size.x / 2, z.position.y + 22.0), Color("7a3a3a"))
	# 同名合并显示（左下角 ×N 角标）
	var merged_e := _merged_effects(state.enemy_effects)
	var n_ee := merged_e.size()
	var cap_e := _enemy_effect_zone_max_slots()
	if n_ee <= cap_e:
		for i in n_ee:
			var m: Dictionary = merged_e[i]
			_draw_card_face(m["card"], _enemy_effect_rect(i),
					(m["card"] as CardData).health, false, false)
			_draw_count_badge(_enemy_effect_rect(i), m["count"])
	else:
		for i in cap_e - 1:
			var m2: Dictionary = merged_e[i]
			_draw_card_face(m2["card"], _enemy_effect_rect(i),
					(m2["card"] as CardData).health, false, false)
			_draw_count_badge(_enemy_effect_rect(i), m2["count"])
		_draw_more_tile(_enemy_effect_rect(cap_e - 1), "+%d" % (n_ee - (cap_e - 1)),
				"点击查看全部")
	_draw_relic_bar()


func _enemy_effect_zone_max_slots() -> int:
	## 右栏敌方效果区在不越界的前提下能放几张卡（与 _enemy_zone_rect 的高度一致）。
	var z := _enemy_zone_rect()
	var top := z.position.y + 32.0
	return maxi(1, int((z.position.y + z.size.y - top) / (TAP_H + 10.0)))


## 道具浏览面板（R75：只有道具栏装不下时才可点开，字号全面大于悬浮提示）
const RELIC_PANEL_W := 860.0
const RELIC_P_NAME := 16          # 名称字号
const RELIC_P_DESC := 13          # 说明字号（悬浮提示是 12）
const RELIC_P_ROWH := 24.0        # 名称行高
const RELIC_P_LINE := 17.0        # 说明行高


func _relic_zone_rect() -> Rect2:
	## 右侧道具栏外框（棋盘右侧、卡组列左侧的空白带，避开我方 HP 文字）。
	return Rect2(900.0, GRID_Y + 350.0, 240.0, 172.0)


func _relic_rect(i: int) -> Rect2:
	## 道具栏第 i 个徽章矩形（与 _draw_relic_bar 一致）。
	var z := _relic_zone_rect()
	return Rect2(z.position.x + 4, z.position.y + 24.0 + i * 24.0, z.size.x - 8, 22.0)


func _relic_max_slots() -> int:
	## 道具栏在不越界的前提下能放几个徽章（每个高 22、步进 24，从 +24 起）。
	var z := _relic_zone_rect()
	var top := z.position.y + 24.0
	return maxi(1, int((z.position.y + z.size.y - top) / 24.0))


func _relic_bar_overflowed() -> bool:
	## 道具栏装不下全部道具（会出现「+N」摘要）—— 点开浏览面板的**唯一**判定口。
	## 装得下时悬浮已能看全，不给点击入口（用户要求）。
	return engine.self_relics.size() > _relic_max_slots()


func _draw_relic_bar() -> void:
	## 右栏道具栏：本局获得的道具（来源色块 = 初始白 / 奖励黄 / 事件紫）。
	var ids := engine.self_relics
	var z := _relic_zone_rect()
	draw_rect(z, Color(1.0, 0.96, 0.82, 0.30), true)
	draw_rect(z, Color("b09a5a"), false, 1.0)
	_draw_string_center(_font_bold, 9, "道具 %d" % ids.size(),
			Vector2(z.position.x + z.size.x / 2, z.position.y + 16.0), Color("7a6230"))
	var repo := RelicRepo.load_json()
	var n_rel := ids.size()
	var cap_r := _relic_max_slots()
	var shown_r := n_rel if n_rel <= cap_r else cap_r - 1
	for i in shown_r:
		var rel := repo.get_relic(ids[i])
		if rel == null:
			continue
		var rect := _relic_rect(i)
		var scol := rel.source_color()
		draw_rect(rect, Color(scol, 0.28), true)
		draw_rect(rect, scol, false, 1.2)
		# 来源色块（白色描述边在浅底上不醒目，配实心块 + 深描边）
		var chip := Rect2(rect.position + Vector2(4, 4), Vector2(6, rect.size.y - 8))
		draw_rect(chip, scol, true)
		draw_rect(chip, Color(0, 0, 0, 0.5), false, 1.0)
		_draw_string_center(_font_bold, 10, rel.relic_name,
				Vector2(rect.position.x + 12.0 + (rect.size.x - 12.0) / 2,
						rect.position.y + 14.0),
				Color("4a3c14"))
	# 道具太多装不下 → 末位换成「+N 点击查看全部」摘要行（点道具栏打开浏览面板）
	if n_rel > shown_r:
		_draw_more_tile(_relic_rect(shown_r), "+%d" % (n_rel - shown_r), "点击查看全部")
	# 鸭之低语：本回合随机得到的强化，常驻显示在道具栏下方
	if engine.self_relics.has(6010):
		draw_string(_font_bold, Vector2(z.position.x, z.position.y + z.size.y + 15.0),
				"鸭之低语：%s" % (_whisper_txt if _whisper_txt != "" else "…"),
				HORIZONTAL_ALIGNMENT_LEFT, z.size.x, 11, Color("7b34b8"))


func _draw_opponent_hand() -> void:
	var count := engine.state.opp_hand_count
	if count <= 0:
		_draw_string_center(_font, 9, "（对手手牌区）",
				Vector2(WINDOW_W / 2, OPP_HAND_Y + CARD_H / 2), Color("aaaaaa"))
		return
	var spacing: float = minf(CARD_W + 8, maxf(40, (WINDOW_W - 200) / count))
	var total: float = spacing * (count - 1) + CARD_W
	var x: float = (WINDOW_W - total) / 2
	for i in count:
		_draw_card_back(Rect2(x, OPP_HAND_Y, CARD_W, CARD_H))
		x += spacing


func _draw_cost_zone() -> void:
	## 左栏：顶部能量面板 + 下方效果区（效果卡正面朝上，持续生效）。
	var state := engine.state
	var mid_x := COST_X + (TAP_W + 12) / 2
	var bottom := GRID_Y + GRID_H
	_draw_string_center(_font_bold, 9, "能量",
			Vector2(mid_x, COST_Y - 12), Color("555555"))
	var epanel := Rect2(COST_X, COST_Y, TAP_W + 12, ENERGY_H)
	draw_rect(epanel, Color(1, 1, 1, 0.55), true)
	draw_rect(epanel, Color("c0bdb6"), false, 1.0)
	_draw_string_center(_font_bold, 24, str(state.energy),
			Vector2(mid_x, COST_Y + 46), Color("8a5a00"))
	_draw_string_center(_font, 8, "每回合重置为 5",
			Vector2(mid_x, COST_Y + 70), Color("888888"))
	# 蓄力（9085）：待用层数（0 层不画）—— 下一张技能的结算次数 = 1 + 层数
	var chg := engine.charge_count(GameEngine.SIDE_SELF)
	if chg > 0:
		_draw_string_center(_font_bold, 8, "蓄力 ×%d（下一张技能 ×%d）" % [chg, chg + 1],
				Vector2(mid_x, COST_Y + 84), Color("8a5a00"))
	# 闪躲（9103）：盟友代受窗口（未开启不画）
	if engine.dodge_active(GameEngine.SIDE_SELF):
		_draw_string_center(_font_bold, 8, "闪躲：伤害由盟友代受",
				Vector2(mid_x, COST_Y + 96), Color("1d7a4f"))
	# 角色（左栏常驻）：本局选定的角色
	_draw_string_center(_font_bold, 9, "角色：%s" % RunState.player_class,
			Vector2(mid_x, COST_Y - 26), Color("1d7a4f"))
	# 效果区
	var zone := Rect2(COST_X, COST_Y + ENERGY_H, TAP_W + 12, bottom - COST_Y - ENERGY_H)
	draw_rect(zone, Color(0.72, 0.86, 0.72, 0.30), true)
	draw_rect(zone, Color("7aa87a"), false, 1.0)
	_draw_string_center(_font_bold, 9, "效果区 %d" % state.effects.size(),
			Vector2(mid_x, COST_Y + ENERGY_H + 22.0), Color("4a6a4a"))
	# 效果卡：同名合并显示（左下角 ×N 角标），栏高固定、最多画满可见槽位；
	# 装不下的用一张「+N」摘要卡兜底（点区域看全部）
	var merged := _merged_effects(state.effects)
	var n_eff := merged.size()
	var cap := _effect_zone_max_slots()
	if n_eff <= cap:
		for i in n_eff:
			var m: Dictionary = merged[i]
			_draw_card_face(m["card"], _effect_rect(i),
					(m["card"] as CardData).health, false, false)
			_draw_counter_badge(m["card"], _effect_rect(i))
			_draw_count_badge(_effect_rect(i), m["count"])
	else:
		for i in cap - 1:
			var m2: Dictionary = merged[i]
			_draw_card_face(m2["card"], _effect_rect(i),
					(m2["card"] as CardData).health, false, false)
			_draw_counter_badge(m2["card"], _effect_rect(i))
			_draw_count_badge(_effect_rect(i), m2["count"])
		_draw_more_tile(_effect_rect(cap - 1), "+%d" % (n_eff - (cap - 1)), "点击查看全部")


func _merged_effects(cards: Array) -> Array:
	## 同名效果卡合并显示：[{card, count}]（按首次出现顺序；card 为该名第一张，作代表）。
	var order: Array = []
	var by_name := {}
	for c: CardData in cards:
		if not by_name.has(c.card_name):
			var e := {"card": c, "count": 0}
			by_name[c.card_name] = e
			order.append(e)
		by_name[c.card_name]["count"] += 1
	return order


func _draw_count_badge(rect: Rect2, count: int) -> void:
	## 同名合并的张数角标（左下角「×N」）：只有合并了 2 张以上才画。
	if count < 2:
		return
	var bw := 26.0
	var badge := Rect2(rect.position.x + 2.0,
			rect.position.y + rect.size.y - 18.0, bw, 16.0)
	draw_rect(badge, Color(0.15, 0.18, 0.15, 0.88), true)
	draw_rect(badge, Color("a8d8a8"), false, 1.0)
	_draw_string_center(_font_bold, 10, "×%d" % count,
			Vector2(badge.position.x + bw / 2, badge.position.y + 12.0), Color("d8f0d8"))


func _draw_counter_badge(c: CardData, rect: Rect2) -> void:
	## 效果卡的「剩余次数」角标（石肤 9066：己方 HP 还能把几次伤害变成 1）。
	## 没有计数概念的卡（engine.effect_counter < 0）不画。
	if engine == null or c == null:
		return
	var left := engine.effect_counter(c)
	if left < 0:
		return
	var bw := 30.0
	var badge := Rect2(rect.position.x + rect.size.x - bw - 2.0,
			rect.position.y + rect.size.y - 18.0, bw, 16.0)
	draw_rect(badge, Color(0.15, 0.15, 0.18, 0.88), true)
	draw_rect(badge, Color("d8cfa8"), false, 1.0)
	_draw_string_center(_font_bold, 10, "剩 %d" % left,
			Vector2(badge.position.x + bw / 2, badge.position.y + 12.0), Color("f0e6c8"))


func _effect_zone_max_slots() -> int:
	## 左栏效果区在不越界的前提下能放几张卡（卡高 TAP_H，步进 TAP_H+10）。
	var top := COST_Y + ENERGY_H + 32.0
	var bottom := GRID_Y + GRID_H
	return maxi(1, int((bottom - top) / (TAP_H + 10.0)))


func _draw_more_tile(rect: Rect2, label: String, sub: String) -> void:
	## 溢出摘要卡：某个区域装不下全部卡时，用这一张替代放不下的那些，
	## 标出还有多少张、并提示该区域可点开查看全部。
	var cx := rect.position.x + rect.size.x / 2
	draw_rect(rect, Color(0.96, 0.95, 0.88, 0.95), true)
	draw_rect(rect, Color("9a8f70"), false, 1.0)
	if rect.size.y >= 40.0:
		_draw_string_center(_font_bold, 13, label,
				Vector2(cx, rect.position.y + rect.size.y * 0.40), Color("6a6040"))
		_draw_string_center(_font, 8, sub,
				Vector2(cx, rect.position.y + rect.size.y * 0.72), Color("7a7050"))
	else:
		_draw_string_center(_font_bold, 9, "%s %s" % [label, sub],
				Vector2(cx, rect.position.y + rect.size.y * 0.5 + 3.0), Color("6a6040"))


func _effect_rect(i: int) -> Rect2:
	## 效果区第 i 张卡的屏幕矩形（与 _draw_cost_zone 的绘制顺序一致）。
	return Rect2(COST_X + 4, COST_Y + ENERGY_H + 32.0 + i * (TAP_H + 10.0),
			TAP_W, TAP_H)


func _draw_deck_and_discard() -> void:
	var state := engine.state
	_draw_string_center(_font_bold, 9, "卡组 %d" % state.deck.size(),
			Vector2(DECK_X + CARD_W / 2, DECK_Y - 14), Color("555555"))
	if state.deck.is_empty():
		draw_rect(Rect2(DECK_X, DECK_Y, CARD_W, CARD_H), Color(0, 0, 0, 0), false)
		draw_rect(Rect2(DECK_X, DECK_Y, CARD_W, CARD_H), Color("c0bdb6"), false, 1.0)
	else:
		_draw_card_back(Rect2(DECK_X, DECK_Y, CARD_W, CARD_H))
	_draw_string_center(_font_bold, 9, "弃牌区 %d" % state.discard.size(),
			Vector2(DISCARD_X + CARD_W / 2, DISCARD_Y - 14), Color("555555"))
	if state.discard.is_empty():
		draw_rect(Rect2(DISCARD_X, DISCARD_Y, CARD_W, CARD_H), Color(0, 0, 0, 0), false)
		draw_rect(Rect2(DISCARD_X, DISCARD_Y, CARD_W, CARD_H), Color("c0bdb6"), false, 1.0)
	else:
		_draw_card_face(state.discard.back(), Rect2(DISCARD_X, DISCARD_Y, CARD_W, CARD_H),
				state.discard.back().health, false, false)


func _draw_hand() -> void:
	var n := engine.state.hand.size()
	var full: bool = engine.state.hand_full()
	# 标签放在手牌左侧、竖直居中于**可见**卡面（卡底沉在窗口外，别贴着屏幕底）
	var label_y: float = OWN_HAND_Y + minf(HAND_CARD_H, WINDOW_H - OWN_HAND_Y) / 2
	var left: float = _hand_rect(0).position.x if n > 0 else WINDOW_W / 2
	_draw_string_center(_font_bold, 9, "手牌 %d/%d" % [n, FieldState.HAND_LIMIT],
			Vector2(minf(WINDOW_W / 2 - 330, left - 56), label_y),
			Color("c0392b") if full else Color("555555"))
	# 悬停的那张抬起来、并压在最上层（重叠时才看得清）
	var order: Array[int] = []
	for i in n:
		if i != _hover_hand:
			order.append(i)
	if _hover_hand >= 0 and _hover_hand < n:
		order.append(_hover_hand)
	for i in order:
		var card := engine.state.hand[i]
		var sel: bool = selection != null and selection[0] == "hand" and selection[1] == i
		_draw_hand_card(i, card, sel, HAND_FAN_HOVER_LIFT if i == _hover_hand else 0.0)


func _draw_hand_card(i: int, card: CardData, selected: bool, lift: float) -> void:
	## 按扇形角度画一张手牌：绕卡牌**底部中心**旋转。
	## lift 只是视觉抬手（不改 _hand_rect，所以命中判定不会因为抬手而抖）。
	## 卡底沉出窗口下沿：卡面照常整张排版，多出来的那截由视口裁掉（不补偿、不挪数值）。
	var r := _hand_rect(i)
	r.position.y -= lift
	var pivot := Vector2(r.position.x + HAND_CARD_W / 2, r.position.y + HAND_CARD_H)
	draw_set_transform(pivot, _hand_angle(i), Vector2.ONE)
	# 「现在打出能吃到额外效果」→ 金色高亮框 + 顶部金星标（R65）。
	# 判定走 engine.hand_bonus_ready（唯一口），条件不满足就不画。
	var bonus := engine.hand_bonus_ready(card)
	_draw_card_face(card, Rect2(r.position - pivot, r.size), card.health, selected, false,
			engine.cost_of(card))
	if bonus:
		_draw_hand_bonus_mark(Rect2(r.position - pivot, r.size))
	# R90：「系统升级」等目标时，把**可改造的手牌**（盟友 / 工事）标出来 ——
	# 不标的话玩家不知道该点哪张（技能卡点了会被拒，白试一次）。
	if _sys_upgrade_idx >= 0 and i != _sys_upgrade_idx \
			and (card.kind == "盟友" or card.is_fort()):
		var hr := Rect2(r.position - pivot, r.size)
		draw_rect(hr, Color("8ad4f0"), false, 3.0)
		_draw_string_nw(_font_bold, 11, "可改造", hr.position + Vector2(6, 14),
				Color("1a5f7a"), 3, Color(0.92, 0.98, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hand_bonus_mark(r: Rect2) -> void:
	## 手卡「额外效果可触发」的金色标记：外框 + 右上角一颗金星。
	## 只做视觉，判定在 engine.hand_bonus_ready。
	var k := r.size.y / CardFace.CARD_H_DESIGN
	var col := COL_HAND_BONUS
	draw_rect(r.grow(2.0 * k), Color(col.r, col.g, col.b, 0.20), true)
	draw_rect(r.grow(2.0 * k), col, false, 2.2 * k)
	var star := r.position + Vector2(r.size.x - 9.0 * k, 11.0 * k)
	draw_circle(star, 7.0 * k, Color(0.10, 0.09, 0.12, 0.92))
	draw_arc(star, 7.0 * k, 0, TAU, 20, col, 1.6 * k, true)
	_draw_string_center(_font_bold, int(10 * k), "★", star, col)


func _draw_drag() -> void:
	## 拖拽释放演出：目标格高亮 + 半透明卡牌跟随光标。
	if _drag_idx < 0 or _drag_idx >= engine.state.hand.size():
		return
	for cell in _drag_spell_cells:
		_hl(cell, COL_SPELL)
	if _drag_place:
		for cell in _drag_place_cells:
			# 已有栅栏的格子（叠栅栏）用橙色 + 「叠」标记，与绿色空格区分
			if engine.state.board.has(cell):
				_hl(cell, COL_FENCE_MERGE)
				_draw_string_center(_font_bold, 13, "叠", _cell_center(cell), Color.WHITE)
			else:
				_hl(cell, COL_MOVE)
	var card := engine.state.hand[_drag_idx]
	if card.id == GameEngine.DEMOLISH_ID and not _drag_spell_cells.is_empty():
		# 拆解 8049（R97）：拖到「被改造」的合法目标上时，金色高亮 + 「额外获得升级」提示。
		var near := _drag_spell_cells[0]
		var bestd := 999999
		for c in _drag_spell_cells:
			var d := int(_cell_center(c).distance_squared_to(_drag_pos))
			if d < bestd:
				bestd = d
				near = c
		var up: Placement = engine.state.unit_at(near)
		if up != null and (up.upgrade_stacks > 0 or up.upgrade_atk != 0 or up.upgrade_hp != 0):
			_hl(near, Color("ffd24a"))
			var nc := _cell_center(near)
			draw_arc(nc, CELL * 0.66, 0, TAU, 32, Color("ffd24a"), 4.0)
			_draw_string_center(_font_bold, 12, "额外获得升级",
				nc + Vector2(0, CELL * 0.44), Color("ffd24a"))
	# 跟着光标走的卡与手牌同尺寸（从手牌里"拿起来"不会突然变小）；
	var rect := Rect2(_drag_pos - Vector2(HAND_CARD_W, HAND_CARD_H) / 2.0,
			Vector2(HAND_CARD_W, HAND_CARD_H))
	_draw_card_face(card, rect, card.health, true, false, engine.cost_of(card))
	# 目标提示光圈（技能=紫色目标格 / 放置=绿色落点格）
	var ring_cells := _drag_spell_cells if not _drag_place else _drag_place_cells
	if not ring_cells.is_empty():
		var nearest := ring_cells[0]
		var best := 999999
		for c in ring_cells:
			var d := int(_cell_center(c).distance_squared_to(_drag_pos))
			if d < best:
				best = d
				nearest = c
		var cc := _cell_center(nearest)
		var rc := Color(0.55, 0.9, 1.0, 0.9)
		if _drag_place:
			rc = COL_FENCE_MERGE if engine.state.board.has(nearest) else COL_MOVE
		draw_arc(cc, CELL * 0.62, 0, TAU, 32, rc, 3.0)


func _draw_info_panel() -> void:
	## 左侧信息栏（悬停优先，其次选中的卡）：卡的**详细效果**。
	## 手牌卡底沉出窗口后，「程 / 速」这类小字只能在这里看全，所以这栏要写满：
	##   编号·名字 → 种类·费用·稀有度 → 数值（战场单位带当前/上限）→ 词条 →
	##   每回合行动数 → 效果正文（按面板宽度自动换行，放不下画省略号）。
	var card: CardData = null
	var pl: Placement = null
	if _hover_card != null:
		card = _hover_card
		pl = _hover_pl
	elif selection != null:
		if selection[0] == "hand":
			card = engine.state.hand[selection[1]]
		elif selection[0] == "board":
			pl = engine.state.unit_at(selection[1])
			if pl != null:
				card = pl.card
	if card == null:
		return
	var top := GRID_Y
	draw_rect(Rect2(INFO_X, top, INFO_W, GRID_H), COL_INFO_BG)
	draw_rect(Rect2(INFO_X, top, INFO_W, GRID_H), Color("c0bdb6"), false, 1.0)
	var left := INFO_X + 10.0
	var right := INFO_X + INFO_W - 10.0
	var inner_w := INFO_W - 20.0
	var y := top + 21.0
	_draw_string_nw(_font_bold, 12, "#%d %s" % [card.id, card.card_name],
			Vector2(left, y), card.rarity_color())
	y += 17.0
	# 费用：显示**当前实际费用**（悬停/选中手牌时套用本回合减费，低于卡面则标绿）
	var hand_idx := _hover_hand
	if hand_idx < 0 and selection != null and selection[0] == "hand":
		hand_idx = selection[1]
	var show_cost := card.cost
	var cost_low := false
	if hand_idx >= 0 and hand_idx < engine.state.hand.size() \
				and engine.state.hand[hand_idx] == card:
		show_cost = engine.cost_of(card)
		cost_low = show_cost < card.cost
	var cost_line: String = "%s · 费用 %d%s · %s" % [card.kind, show_cost,
			"（原 %d）" % card.cost if cost_low else "", card.rarity_name()]
	if card.x_cost:
		# X 费卡（流星雨）：费用随剩余能量浮动 → 左栏直接写「费用 X（消耗全部能量）」
		cost_line = "%s · 费用 X（消耗全部能量）· %s" % [card.kind, card.rarity_name()]
	_draw_string_nw(_font, 9, cost_line,
			Vector2(left, y), COL_COST_LOW_BG if cost_low else Color("444444"))
	y += 13.0
	draw_line(Vector2(left, y), Vector2(right, y), Color("cfcbc2"), 1.0)
	y += 17.0
	# 数值：与卡面同配色（力量金黄 / 生命红）；战场上的单位显示当前/上限
	if card.kind == "盟友" or card.kind == "工事":
		var hp_now: int = pl.health if pl != null else card.health
		var hp_txt: String = "%d/%d" % [hp_now, card.health] if pl != null else str(card.health)
		var pw_now: int = pl.effective_power() if pl != null else card.power
		var pw_txt: String = str(pw_now)
		if pl != null and pw_now != card.power:
			pw_txt = "%d（原 %d）" % [pw_now, card.power]
		_draw_string_nw(_font_bold, 10, "力量 %s" % pw_txt, Vector2(left, y),
				CardFace.COL_POWER)
		_draw_string_nw(_font_bold, 10, "生命 %s" % hp_txt, Vector2(left + inner_w / 2, y),
				CardFace.COL_HEALTH)
		y += 17.0
		var mv: String = "射程 %d   移速 %d" % [card.attack_range, card.move_speed] \
				if card.kind == "盟友" else "射程 %d" % card.attack_range
		_draw_string_nw(_font, 9, mv, Vector2(left, y), Color("444444"))
		y += 17.0
	if card.actions > 1:
		_draw_string_nw(_font, 9, "每回合可行动 %d 次" % card.actions, Vector2(left, y),
				Color("444444"))
		y += 17.0
	if not card.traits.is_empty():
		var tt := ""
		for t in card.traits:
			tt += (" · " if tt != "" else "") + str(t)
		_draw_string_nw(_font, 9, "词条：" + tt, Vector2(left, y), Color("886000"))
		y += 17.0
	_draw_string_nw(_font_bold, 9, "效果", Vector2(left, y), Color("2a5a8a"))
	y += 15.0
	# 效果描述：按面板宽度自动换行（不再单行溢出面板）。
	var shown_lines := 0
	for ln: String in CardFace.wrap_text(_font, card.effect_text, inner_w, 9):
		if shown_lines > 0 and y > top + GRID_H - 12.0:
			_draw_string_nw(_font, 9, "……", Vector2(left, y), Color("2a5a8a"))
			break   # 超出面板底部就不再绘制
		_draw_string_nw(_font, 9, ln, Vector2(left, y), Color("2a5a8a"))
		y += 14.0
		shown_lines += 1


func _draw_game_over() -> void:
	var win := engine.result == "胜利"
	var cx := GRID_X + GRID_W / 2
	var cy := GRID_Y + GRID_H / 2
	var col := COL_WIN if win else COL_LOSE
	draw_rect(Rect2(GRID_X + 12, cy - 58, GRID_W - 24, 116), Color.WHITE)
	draw_rect(Rect2(GRID_X + 12, cy - 58, GRID_W - 24, 116), col, false, 3.0)
	_draw_string_center(_font_bold, 26, "胜  利" if win else "失  败", Vector2(cx, cy - 20), col)
	_draw_string_center(_font, 10, engine.result_reason, Vector2(cx, cy + 28), Color("444444"))


func _draw_banner() -> void:
	## 回合切换大字横幅：淡入 → 停留 → 上浮淡出。
	if _banner.is_empty():
		return
	var p := clampf(float(_now() - int(_banner.start)) / int(_banner.dur), 0.0, 1.0)
	var alpha: float = minf(p * 8.0, 1.0) * minf((1.0 - p) * 5.0, 1.0)
	var col: Color = _banner.col
	col.a = alpha
	var cx := GRID_X + GRID_W / 2
	var cy := GRID_Y + GRID_H * 0.42 - 18.0 * p
	draw_rect(Rect2(cx - 150, cy - 30, 300, 60), Color(1, 1, 1, 0.72 * alpha))
	draw_rect(Rect2(cx - 150, cy - 30, 300, 60), Color(col.r, col.g, col.b, alpha), false, 2.0)
	_draw_string_center(_font_bold, 22, str(_banner.text), Vector2(cx, cy + 8), col)


func _draw_confetti() -> void:
	## 胜利彩带（旋转的小纸条）。
	for c: Dictionary in _confetti:
		draw_set_transform(c.pos, c.rot)
		var sz: Vector2 = c.size
		draw_rect(Rect2(-sz / 2.0, sz), c.col)
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_discard_panel() -> void:
	## 弃牌区浏览面板：全部弃牌正面横排，点击任意处关闭。
	_draw_zone_panel("弃牌区 %d 张（从左到右：先弃的在前）" % engine.state.discard.size(),
			engine.state.discard)


func _zone_panel_cards() -> Array:
	## 当前打开的「区域浏览面板」里的卡（都没打开 → 空数组）。
	## 效果类面板同名合并 / 卡组面板同 id 合并：只放代表卡（与面板显示一致）。
	if _effects_visible:
		return _merged_effects(engine.state.effects).map(
				func(m: Dictionary) -> CardData: return m["card"])
	if _enemy_effects_visible:
		return _merged_effects(engine.state.enemy_effects).map(
				func(m: Dictionary) -> CardData: return m["card"])
	if _deck_visible:
		return _merged_deck(engine.state.deck).map(
				func(m: Dictionary) -> CardData: return m["card"])
	if _discard_visible:
		return engine.state.discard
	return []


func _zone_panel_counts() -> Array:
	## 与 _zone_panel_cards 平行的合并张数（弃牌区不合并 → 空数组）。
	if _effects_visible:
		return _merged_effects(engine.state.effects).map(
				func(m: Dictionary) -> int: return m["count"])
	if _enemy_effects_visible:
		return _merged_effects(engine.state.enemy_effects).map(
				func(m: Dictionary) -> int: return m["count"])
	if _deck_visible:
		return _merged_deck(engine.state.deck).map(
				func(m: Dictionary) -> int: return m["count"])
	return []


func _merged_deck(cards: Array) -> Array:
	## 抽牌堆按 **id** 合并显示：[{card, count}]。
	## 按（费用, id）排序而非出现顺序 —— 玩家不能从面板推出抽牌顺序。
	var order: Array = []
	var by_id := {}
	for c: CardData in cards:
		if not by_id.has(c.id):
			var e := {"card": c, "count": 0}
			by_id[c.id] = e
			order.append(e)
		by_id[c.id]["count"] += 1
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: CardData = a["card"]
		var cb: CardData = b["card"]
		if ca.cost != cb.cost:
			return ca.cost < cb.cost
		return ca.id < cb.id)
	return order


func _zone_panel_layout(n: int) -> Dictionary:
	## 区域浏览面板的网格布局：绘制与悬停判定共用一份，改一处即可。
	# 先按可用宽度尽量多排几列（至少 1 列），再按张数算行数
	var cols := maxi(1, int((WINDOW_W - 180.0) / (CARD_W + 10.0)))
	cols = mini(cols, maxi(n, 1))
	var rows := maxi(1, int(ceil(float(n) / float(cols))))
	var grid_w := cols * (CARD_W + 10.0) - 10.0
	var pw := minf(WINDOW_W - 80.0, grid_w + 60.0)
	var ph := minf(WINDOW_H - 40.0, rows * (CARD_H + 10.0) + 86.0)
	var px := (WINDOW_W - pw) / 2
	var py := (WINDOW_H - ph) / 2
	var x0 := px + (pw - grid_w) / 2
	return {"cols": cols, "px": px, "py": py, "pw": pw, "ph": ph, "x0": x0}


func _zone_card_rect(i: int, L: Dictionary) -> Rect2:
	## 面板里第 i 张卡的矩形（悬停判定用）。
	var cols: int = L["cols"]
	return Rect2(L["x0"] + (i % cols) * (CARD_W + 10.0),
			L["py"] + 42.0 + int(i / cols) * (CARD_H + 10.0), CARD_W, CARD_H)


func _draw_zone_panel(title: String, cards: Array, counts: Array = []) -> void:
	## 区域浏览面板：全部卡按网格换行铺开（卡再多也能一张不漏地看清），点击任意处关闭。
	## 悬停任意一张 → 左侧信息栏显示它的明细（判定走 _zone_card_rect）。
	## counts 非空时与 cards 平行：>1 的在左下角画「×N」合并张数角标。
	var n := cards.size()
	var L := _zone_panel_layout(n)
	var pw: float = L["pw"]
	var ph: float = L["ph"]
	var px: float = L["px"]
	var py: float = L["py"]
	# 面板不再压暗背景（用户要求：点开面板时后面区域不要变暗）
	draw_rect(Rect2(px, py, pw, ph), Color.WHITE)
	draw_rect(Rect2(px, py, pw, ph), Color("555555"), false, 2.0)
	_draw_string_center(_font_bold, 13, "%s — 点击任意处关闭" % title,
			Vector2(WINDOW_W / 2, py + 24), Color("333333"))
	if n == 0:
		return
	for i in n:
		var c: CardData = cards[i]
		var face := _zone_card_rect(i, L)
		_draw_card_face(c, face, c.health, false, false)
		_draw_counter_badge(c, face)
		if not counts.is_empty():
			_draw_count_badge(face, counts[i])


func _wrap_lines(font: Font, px: int, text: String, max_w: float) -> PackedStringArray:
	## 按宽度逐字折行（draw_string 不会自动换行，长文本会画出面板外）。
	var out: PackedStringArray = []
	var cur := ""
	for i in text.length():
		var ch := text[i]
		if cur != "" and font.get_string_size(cur + ch,
				HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
			out.append(cur)
			cur = ch
		else:
			cur += ch
	if cur != "":
		out.append(cur)
	return out


func _relic_panel_rows() -> Array:
	## 道具面板的每行内容：[名称行, 描述折行数组, 来源色]。
	var ids := engine.self_relics
	var repo := RelicRepo.load_json()
	var rows: Array = []
	for i in ids.size():
		var rel := repo.get_relic(ids[i])
		var nm := rel.relic_name if rel != null else str(ids[i])
		var desc := rel.desc if rel != null else ""
		var scol := rel.source_color() if rel != null else Color.GRAY
		var tag := rel.source_label() if rel != null else "道具"
		rows.append(["「%s」（%s）" % [nm, tag],
				_wrap_lines(_font, RELIC_P_DESC, desc, RELIC_PANEL_W - 96.0), scol])
	return rows


func _relic_panel_rows_height() -> float:
	var h := 0.0
	for r in _relic_panel_rows():
		h += RELIC_P_ROWH + (r[1] as PackedStringArray).size() * RELIC_P_LINE + 10.0
	return h


func _draw_relic_panel() -> void:
	## 道具浏览面板：本局全部道具 + 完整说明（长描述自动折行；太多时滚轮翻动）。
	var ids := engine.self_relics
	var n := ids.size()
	var pw := minf(WINDOW_W - 160.0, RELIC_PANEL_W)
	var ph := minf(WINDOW_H - 40.0, 620.0)
	var px := (WINDOW_W - pw) / 2
	var py := (WINDOW_H - ph) / 2
	var rows := _relic_panel_rows()
	var scroll_max := maxf(0.0, _relic_panel_rows_height() + 66.0 - ph)
	_relic_scroll = clampf(_relic_scroll, 0.0, scroll_max)
	# 面板不再压暗背景（用户要求：点开面板时后面区域不要变暗）
	draw_rect(Rect2(px, py, pw, ph), Color.WHITE)
	draw_rect(Rect2(px, py, pw, ph), Color("555555"), false, 2.0)
	_draw_string_center(_font_bold, 19,
			"道具 %d 个 — 悬浮即可看说明，这里是放大版%s" % [n,
					"（滚轮翻动 · 点击任意处关闭）" if scroll_max > 0.0
					else "（点击任意处关闭）"],
			Vector2(WINDOW_W / 2, py + 30), Color("333333"))
	if n == 0:
		_draw_string_center(_font, 15, "本局还没有道具",
				Vector2(WINDOW_W / 2, py + 76), Color("888888"))
		return
	var y := py + 56.0 - _relic_scroll
	for r in rows:
		var name_line: String = r[0]
		var dlines: PackedStringArray = r[1]
		var scol: Color = r[2]
		var row_h: float = RELIC_P_ROWH + dlines.size() * RELIC_P_LINE + 10.0
		# 只画面板内可见的行（滚出面板的内容自然被面板矩形盖不住 → 手动跳过）
		if y + row_h > py + 46.0 and y < py + ph - 8.0:
			draw_rect(Rect2(px + 16, y - 16, 10, row_h - 8.0), scol, true)
			_draw_string_nw(_font_bold, RELIC_P_NAME, name_line,
					Vector2(px + 36, y), Color("4a3c14"))
			for d_i in dlines.size():
				_draw_string_nw(_font, RELIC_P_DESC, dlines[d_i],
						Vector2(px + 36, y + RELIC_P_ROWH - 8.0 + d_i * RELIC_P_LINE),
						Color("555555"))
		y += row_h


func _draw_relic_tip_panel() -> void:
	## 道具悬停说明：浮动折行面板画在道具栏上方（长描述如「叠加态的鸭」不溢出）。
	if _hover_relic_tip == "":
		return
	var w := 480.0
	var lines := CardFace.wrap_text(_font, _hover_relic_tip, w - 24.0, 13)
	var h := 14.0 + lines.size() * 18.0 + 10.0
	var z := _relic_zone_rect()
	var x: float = clampf(z.position.x + z.size.x - w, 8.0, WINDOW_W - w - 8.0)
	var y: float = z.position.y - h - 10.0
	if y < 46.0:
		y = 46.0
	draw_rect(Rect2(x, y, w, h), Color(0.10, 0.11, 0.15, 0.95), true)
	draw_rect(Rect2(x, y, w, h), Color("c8951c"), false, 1.2)
	for li in lines.size():
		draw_string(_font, Vector2(x + 12, y + 22.0 + li * 18.0), lines[li],
				HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 13, Color("f0ead8"))


func _draw_log_panel() -> void:
	## 对局记录面板：覆盖左侧信息栏区域，显示引擎日志尾部。
	var rect := Rect2(INFO_X, GRID_Y, INFO_W, GRID_H)
	draw_rect(rect, Color("2b2b2b"))
	draw_rect(rect, Color("c0bdb6"), false, 1.0)
	_draw_string_nw(_font_bold, 11, "对局记录（L 关闭）",
			Vector2(INFO_X + 10, GRID_Y + 18), Color("f0f0f0"))
	var lines := engine.log
	var show := mini(lines.size(), 21)
	var y := GRID_Y + 40.0
	for i in range(lines.size() - show, lines.size()):
		var t := str(lines[i])
		if t.length() > 28:
			t = t.substr(0, 28) + "…"
		_draw_string_nw(_font, 9, t, Vector2(INFO_X + 8, y), Color("d8d8d8"))
		y += 17.0


# ------------------------------------------------------------ 每帧刷新工具栏文字

func _process(delta: float) -> void:
	if _demo_tip_text != "":
		_hover_relic_tip = _demo_tip_text   # 演示：合成鼠标移动会清提示 → 每帧重设
	if _demo_hover_idx >= 0 and engine != null \
			and _demo_hover_idx < engine.state.hand.size():
		_hover_hand = _demo_hover_idx          # 演示：左栏信息面板常驻显示这张卡
		_hover_card = engine.state.hand[_demo_hover_idx]
		_hover_pl = null
	if engine == null:
		return
	if _shot_pending:
		_demo_tick()
	if _net_mode:
		_net_poll(delta)
	if ReplayLog.playing:
		_replay_tick()
	# R77：鸭语耳环逐张出牌 —— 放在 _tick_anims 之前，优先把「下一张」推出去，
	# 这样同一帧里刚出的牌动画能立刻开始播。
	var earring_busy := _tick_earring_autoplay()
	var anim_busy := _tick_anims()
	if anim_busy:
		queue_redraw()  # 动画播放中逐帧重绘
	if earring_busy:
		queue_redraw()
	if _board_has_taunt():
		queue_redraw()  # 嘲讽光环是脉冲动画 → 需要持续重绘
	if _board_has_frozen():
		queue_redraw()  # 冰封寒霜环同样是脉冲动画（R68）
	if _board_has_sleep():
		queue_redraw()  # 沉睡环 + 飘「Zzz」同样是脉冲动画（R72）
	if _board_has_shield():
		queue_redraw()  # 能量屏障的青色呼吸环 + 护盾徽标（R87）
	if engine != null and _board_has_pulsing_field():
		queue_redraw()  # 场地标记的呼吸描边是脉冲动画（R74）；持续型场地静止不重绘（R83）
	if not _confetti.is_empty():
		if _tick_confetti(delta):
			queue_redraw()
		else:
			_confetti.clear()
			queue_redraw()
	if not _banner.is_empty():
		if _now() - int(_banner.start) < int(_banner.dur):
			queue_redraw()
		else:
			_banner = {}
	# 结算面板：等所有攻击/命中/击破/飘字等动画特效播完后再弹出。
	if engine.over and not _over_shown and not anim_busy:
		_show_over(engine.result == "胜利")
	# 地图总览的「下一步可走」绿环是脉冲动画 → 开着时需持续重绘
	if _map_visible:
		queue_redraw()
	if not _tutorial_finished:
		_tut_poll()
	if _net_mode:
		if engine.over:
			turn_label.text = "对局结束"
		elif engine.current_side == GameEngine.SIDE_SELF:
			turn_label.text = "我方回合 · 第 %d 回合" % engine.turn_number
		else:
			turn_label.text = "%s 行动中" % NetSession.opp_name
	elif engine.current_side == GameEngine.SIDE_SELF and not engine.over:
		turn_label.text = "我方回合 · 第 %d 回合" % engine.turn_number
	elif engine.over:
		turn_label.text = "对局结束"
	else:
		turn_label.text = "对手回合"
	hp_label.text = "我方 HP %d/%d · 敌方 HP %d/%d" % [engine.state.hp_self,
			engine.state.max_hp_self, engine.state.hp_opponent, engine.state.max_hp_opponent]
	status_label.text = status_text
