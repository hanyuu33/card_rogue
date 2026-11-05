extends Control
## 神秘商店（R181）：金币消费的三行商品，自适应铺满屏幕（右侧空出老板立绘区）。
##
## 第一行：随机本职业奖励卡（数量自适应货架宽，约 3~6 张，走 Boss 档概率 35/45/20）。
## 第二行：3 个随机附魔（从 4 种里抽 3 种不重复）：
##   * 费用 -1（只可费用 > 1 且非 X 费卡）价 50
##   * 伤害 +10（**只可「能直接造成伤害」的技能卡**，R210 限技能卡 / R226 再收紧；
##     技能卡造成的伤害 +10）价 60
##   * 次元之力（赋字段「次元」；盟友/工事，必须无次元、非效果卡；+2 力 +10 血）价 80（R210：50 → 80）
##   * 保存（回合结束手牌不丢弃，做成字段）价 60
## 第三行：固定 3 项：删一张卡 50 / +5 最大生命（并回血）50 / 买一块巧克力 80（R295：120 → 80）。
##
## 三行商品背后各有一层**货架**（R508）：「后挡板 shelf_back.png」+ 「层板 shelf_board.png」，
## 都没有护栏/立柱 —— 商品（图标 / 卡牌）直接立在层板上，缺图时回退程序画纯色板与背板。
## 货架宽度 = 商品区宽度，随屏幕比例自适应。
##
## 附魔购买流程：选附魔 → 选卡（高亮可选卡）→ 成功入卡组，无候选卡则提示。
## 每件商品每次商店只能买一次，售罄后置灰。
## 金币不足 / 无可选卡时给出提示，不扣钱。

const UiTheme = preload("res://scripts/ui_theme.gd")
const TextWrap = preload("res://scripts/text_wrap.gd")

# 选卡覆盖层的卡片网格几何（绘制 + 命中**共用**，唯一口 `_pick_card_rect`）
const PICK_COLS := 5
const PICK_CARD_W := 150.0
const PICK_CARD_H := 190.0
const PICK_GAP_X := 20.0
const PICK_GAP_Y := 16.0
const PICK_Y0 := 130.0

# R390：买到的卡「飞进卡组」的时长（秒）。0.55 是实测手感：再短看不清，
# 再长会挡着下一次点击（飞行中的卡画在最上层，但它不收输入）。
const FLY_DUR := 0.55

# 第三行固定商品的价钱（R295：**唯一来源**）—— `_row3` 逐项引用，改价只改这里。
# 之前价钱写死在 `_row3` 字面量里，改一次要翻代码找，测试也没法按常量核对。
const PRICE_DELETE := 50
const PRICE_MAXHP := 50
const PRICE_CHOCO := 80      # R295：120 → 80

# R432（用户口径）：商店第一行的卡 **每张 20% 概率五折**。
# 折后价 = 基础价 × OFF_PCT，**向上取整**（25 → 13 / 50 → 25 / 80 → 40）——
# 取整方向写死在这里，绘制 / 提示 / 扣款都读 `_row1_price()`，别各算一份。
const OFF_CHANCE := 0.20
const OFF_PCT := 0.5

# R481（用户口径「窗口模式用小窗口会少显示一张」）：第一行**固定摆 5 张**，窗口窄了
# 就缩卡面，而不是少摆几张。原来 `_visible_row1_count()` 按货架宽算「能塞 4 还是 5 张」——
# 1280 基准窗口只有 836 宽，算出来正好 4 张，玩家以为货架缺货。
# 现在张数恒定，卡宽 / 间距等比缩（比例仍是 150:32），任何窗口都摆满同一批商品。
const ROW1_MAX := 5            # 第一行固定张数（抽卡数也是它，不再多抽留着截断）
const ROW1_CARD_W := 150.0     # 卡面基准宽（货架够宽时用这个）
const ROW1_GAP := 32.0         # 卡面基准间距
const ROW1_MIN_W := 100.0      # 卡面最小宽（再窄宁可轻微溢出，也不让卡面糊成一片）
const ROW2_ITEM_MAX_W := 330.0 # 附魔商品不再横向拉满货架
const ROW3_ITEM_MAX_W := 250.0 # 服务商品收窄，说明改到底部整宽折行

# 附魔定义（id → 元数据）
const ENCHANTS := [
	# ⚠️ 这里的 `name` 只是**冗余副本**，绘制一律走 `_ench_name()`（真源 = `CardData.ENCHANT_DEFS`）；
	# smoke 会逐条比对两处文案，分叉立刻红（R240）。
	{"id": "costdown", "name": "费用 -1", "desc": "每次战斗初次使用费用 -1（只能选费用 > 1 且非 X 费的卡）",
		"price": 50, "icon": "shop_icon_costdown"},
	{"id": "damage", "name": "伤害 +10", "desc": "这张技能卡造成的伤害 +10（只能选能直接造成伤害的技能卡）",
		"price": 60, "icon": "shop_icon_damage"},
	{"id": "dimension", "name": "次元之力", "desc": "赋字段「次元」+2力+10血，离场消失",
		"price": 80, "icon": "shop_icon_dimension"},
	{"id": "save", "name": "保存", "desc": "赋予「保存」——回合结束时手牌这张不丢弃",
		"price": 60, "icon": "shop_icon_save"},
	# R246：起手 50 → **30 金**（用户口径：第一回合抽到的附魔价格降为 30）。
	{"id": "opening", "name": "起手", "desc": "第一回合必定抽到（任何卡都能选）",
		"price": 30, "icon": "shop_icon_opening"},
	# R370：用户口径「打出后抽一张卡，售价 40」。
	{"id": "draw", "name": "抽牌 +1", "desc": "打出这张卡后抽一张卡（任何卡都能选）",
		"price": 40, "icon": "shop_icon_draw"},
]

var _font: Font
var _font_bold: Font
var _repo: CardRepo

# 三行商品状态
var _row1: Array = []          # [{card: CardData, sold: bool}]
var _row2: Array = []          # [{ench: Dictionary, sold: bool}]  3 个随机附魔
var _row3: Array = []          # [{key: "delete"/"maxhp"/"choco", sold: bool}]

# 附魔购买流程状态
var _enchanting := -1          # 第二行正在附魔的商品下标（-1 = 无）
var _deleting := false         # 第三行「删除一张卡」的选卡覆盖层（true = 弹卡组选一张删）
var _sel_goods := -1
var _hover := -1               # 悬停的商品下标（按全局编号）
var _hover_enchant_card := -1  # 附魔/删除选卡时悬停的卡下标
var _sel_row1 := -1            # 「选中查看」的第一行卡下标（R203：两段式购买首击）
var _sel_pick := -1            # 「选中查看」的选卡覆盖层卡下标（R203）

# 卡组展示（附魔选卡时）
var _deck_cards: Array = []    # [{id, name, card}]

var _hint := ""
var _hint_t := 0.0

# ---- R390：商店会话 / 平台分叉 ----
## 本次商店对应的地图格子 id（-1 = 演示 / 没有地图）。重进时用它去 RunState 找货架。
var _shop_node := -1
## 烟测接缝：非空时代替真跳转（headless / 冒烟里没有「下一个场景」可换）。
## 与 `reward_panel.route_fn` 同款 —— 正式流程永远为空。
var route_fn: Callable = Callable()
## 出图用：强制走触摸界面（安卓的「购买」按钮平时在桌面上不出现，没法截图核验）。
var _force_touch := false
## 买到的卡的飞行动画实例：`[{card, from: Rect2, t: float}]`
var _fly: Array = []
## 出图用（`--flyhold`）：把飞行卡钉在半路，否则截图那一刻它早飞到牌库去了。
var _fly_hold := false
## 飞行落点的那圈金环（> 0 时画，逐帧递减）—— 告诉玩家「卡进到这里了」。
var _deck_flash_t := 0.0

# R218：**请求重绘的次数**（只增不减）。唯一重绘口 `_ask_redraw()` 自增，
# 给「状态变了却没画」这类 bug 留一个可断言的接缝（Android 触摸没有鼠标移动，
# 少一次 queue_redraw 就是「点了没反应」）。
var _redraw_req := 0

# 全局商品编号：第一行 0..n-1，第二行紧跟，第三行再紧跟。
# 三行各自独立计数，全局编号在 _hit_at 里换算。这里用三个 base 偏移。
var _row1_base := 0
var _row2_base := 0
var _row3_base := 0


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	_repo = CardRepo.load_json()
	# R375（用户口径）：**商店里也要能查看自己的卡组与道具** —— 与事件 / 休息 / 选卡等
	# 界面同款的一对悬浮层（右上角「牌库 N」+「道具 N」）。
	# ⚠️ 两个必须**成对**挂：smoke 有「挂了牌库却没有道具 → 直接红」的对等断言。
	# ⚠️ 位置取默认 / 1044：商店顶部 0~84 是空的（标题居中、金币在左），
	#    老板立绘从 `_top_h() + 20` 才开始画 —— 两个按钮不会压到立绘或标题。
	DeckViewer.attach(self)
	RelicViewer.attach(self, Vector2(1044, 6))
	# ⚠️ `_setup_shop()` **必须在演示参数之后**（R390）：`--shop` 会造 run 并把
	# `current_node_id` 从 -1 补成一个有效格子，而 `_setup_shop()` 要拿它当
	# `_shop_node` 去存取货架状态。放在前面 → `_shop_node` 恒为 -1 → 状态存不下，
	# 出图核验「重进原样」时永远重摇（R390 踩过）。
	# 演示参数：--shop 造一个 run + 金币（截图核验商店界面）。
	var args := OS.get_cmdline_user_args()
	if "--shop" in args:
		if not RunState.run_active:
			RunState.run_active = true
			RunState.start_run([], GameLayers.LAYER_DEFAULT)
		RunState.gold = 100
		RunState.pending_node = {"type": "shop"}
		if RunState.current_node_id < 0:
			# 出图专用：`start_run([])` 没有地图 → 当前格是 -1，货架状态就没地方存
			# （`_sync_shop_state()` 见 `_shop_node < 0` 直接返回 → 重进必重摇）。
			# 真实流程永远是从地图格走进来，`current_node_id` 一定有效。
			RunState.current_node_id = 0
	# R390 出图：`--touchui` 强制走触摸界面 —— 安卓的「购买」按钮只在触屏出现，
	# 桌面出图否则永远截不到。只切绘制/交互分支，不碰任何数据。
	if "--touchui" in args:
		_force_touch = true
	# R390 出图：`--flyhold` 买下第一张卡并把飞行中的卡**钉在半路** —— 核验
	# 「卡飞进卡组」的形态。出图：`shop.tscn -- --screenshot --flyhold --shotframe ..`
	if "--flyhold" in args:
		var tf := Timer.new()
		tf.wait_time = 0.25
		tf.one_shot = true
		tf.timeout.connect(func():
			_buy_card(0)
			for f: Dictionary in _fly:
				f["t"] = 0.26
			_fly_hold = true
			_ask_redraw())
		add_child(tf)
		tf.start()
	# R390 出图：`--clickcard N` 用**真实点击路径**（`_on_click`）点第一行第 N 张 ——
	# 核验「电脑端单击一次就买」这条分支真的通（不是直接调 `_buy_card` 抄近路）。
	# 出图：`shop.tscn -- --screenshot --shop --clickcard 1`
	if "--clickcard" in args:
		var ci := args.find("--clickcard")
		var idx := int(args[ci + 1]) if ci + 1 < args.size() else 0
		var tc := Timer.new()
		tc.wait_time = 0.3
		tc.one_shot = true
		tc.timeout.connect(func():
			if idx >= 0 and idx < _row1.size():
				_on_click(_row1_rect(idx).get_center())
			_ask_redraw())
		add_child(tc)
		tc.start()
	# R390 出图：`--revisit` 在买完之后**再走一遍进店初始化**（等于离开再回来），
	# 截图里必须看到「已经买过的那张还是已售罄、其余位置没动」。
	# 出图：`shop.tscn -- --screenshot --shop --clickcard 0 --revisit`
	if "--revisit" in args:
		var tv := Timer.new()
		tv.wait_time = 0.45
		tv.one_shot = true
		tv.timeout.connect(func():
			_setup_shop()
			_ask_redraw())
		add_child(tv)
		tv.start()
	# 演示参数：--picksel N 选中查看第一行第 N 张卡（截图核验描述板 / 选中高亮）。
	var ps := args.find("--picksel")
	if ps >= 0 and ps + 1 < args.size():
		_sel_row1 = int(args[ps + 1])
	# 演示参数（R204 附魔卡死回归）：
	#   `--ench N`  打开附魔选卡页并「首击」选中第 N 张 → 截图里的高亮必须还在
	#               （旧 bug 会在重绘时把选中抹掉 → 截图里没有高亮 / 点不动）。
	#   `--ench2 N` 再点一次同一张 → 真的成交（覆盖层关闭 + 提示「获得附魔」）。
	var en := args.find("--ench")
	var en2 := args.find("--ench2")
	if en >= 0 or en2 >= 0:
		var pos_i := maxi(en, en2)
		var cand := int(args[pos_i + 1]) if pos_i + 1 < args.size() else 0
		var commit := en2 >= 0
		# R210：`--enchid <id>` 指定第二行第一件换成哪张附魔（截图核对「伤害 +10 只能选技能卡」）。
		var ench_id := "save"
		var eid := args.find("--enchid")
		if eid >= 0 and eid + 1 < args.size():
			ench_id = str(args[eid + 1])
		var t2 := Timer.new()
		t2.wait_time = 0.2          # 等布局定好（size 才是真实视口）
		t2.one_shot = true
		t2.timeout.connect(func(): _demo_enchant(cand, commit, ench_id))
		add_child(t2)
		t2.start()
	# 演示参数（R311）：`--r311basin` 持有不锈钢盆 + **0 金币** → 顶栏写「本次购买抵账」，
	# 并买下第一张卡，提示里应写「不锈钢盆抵账」（证明不花金币）。
	# 出图：`shop.tscn -- --screenshot --r311basin`
	if "--r311basin" in args:
		if not RunState.run_active:
			RunState.run_active = true
			RunState.start_run([], GameLayers.LAYER_DEFAULT)
		RunState.gold = 0
		RunState.pending_node = {"type": "shop"}
		RunState.relics = []
		RunState.basin_charge = 0
		RunState.gain_relic(RunState.BASIN_RELIC_ID)
		# 加 `--r311buy` 才真的买：不带它时截的是「买之前」的顶栏（盆还在、写余量）
		if "--r311buy" in args:
			var tb := Timer.new()
			tb.wait_time = 0.3
			tb.one_shot = true
			tb.timeout.connect(func(): _buy_card(0))
			add_child(tb)
			tb.start()
	# R394 出图：`--relicdemo` 塞 8 件道具（含用户报过的泉水 / 思想钢印），
	# 配合 `--relicview` / `--relicpanel` 核验「点击展开胶囊行 / 悬停看详情」。
	if "--relicdemo" in args:
		if not RunState.run_active:
			RunState.run_active = true
			RunState.start_run([], GameLayers.LAYER_DEFAULT)
		RunState.relics = []
		for rid: int in [6035, 6036, 6015, 6001, 6003, 6005, 6010, 6041]:
			RunState.gain_relic(rid)
	# R440 出图：`--r440` 塞「暗动力」6054 —— 核验商店「删除一张卡」被封成「暗动力」遮罩。
	# 出图：`shop.tscn -- --screenshot --r440`
	if "--r440" in args:
		if not RunState.run_active:
			RunState.run_active = true
			RunState.start_run([], GameLayers.LAYER_DEFAULT)
		if not RunState.relics.has(RunState.DARK_POWER_RELIC_ID):
			RunState.relics.append(RunState.DARK_POWER_RELIC_ID)
	_setup_shop()   # R390：见上面那条注释 —— 必须在所有「造 run / 改当前格」的演示参数之后
	# R444 出图：`--affixdemo` 把第一行头两张换成**带字段**的卡（钢铁卫士 = 超负荷 + 嘲讽、
	# 白狼 = 疾行），并「选中查看」第一张 —— 字段是随卡池随机来的，
	# 靠运气截图十次有九次截不到带字段的卡，等于没有核验手段。
	# 只换卡不 `_sync_shop_state()`：演示卡不该被写进货架存档。
	# 出图：`shop.tscn -- --screenshot --shop --affixdemo`
	if "--affixdemo" in args:
		var demo_ids := [8055, 9031]
		for k4 in mini(demo_ids.size(), _row1.size()):
			var dc: CardData = _repo.get_card(int(demo_ids[k4]))
			if dc != null:
				_row1[k4]["card"] = dc
		_sel_row1 = 0
		_ask_redraw()
	# R432 出图：`--off N` 把第一行第 N 张**强制设为五折** —— 五折本身是 20% 概率，
	# 截图核验不能靠运气（跑十次九次截不到贴纸，等于没有核验手段）。
	# 只改这一个标记，价格与贴纸全走正常渲染路径。
	# 出图：`shop.tscn -- --screenshot --shop --off 0`
	var of := args.find("--off")
	if of >= 0 and of + 1 < args.size():
		var oi := int(args[of + 1])
		if oi >= 0 and oi < _row1.size():
			_row1[oi]["off"] = true
			# 同步进 `shop_states`：配合 `--revisit` 走一遍「存盘 → 重进恢复」，
			# 才能证明折扣标记是**跟着货架存档走的**（而不是只在内存里活一帧）。
			_sync_shop_state()
			_ask_redraw()
	# 演示参数（R214）：`--delpick` 打开「删除一张卡」的选卡页 —— 核验**选卡页大卡**
	# （150×190，`CardFace.draw_pick()`）上也有附魔标记。顺带给卡组前两张塞附魔，
	# 否则初始卡组是一张张素卡，出图看不出任何标记。
	# 出图：`shop.tscn -- --screenshot --delpick`
	if "--delpick" in args:
		if not RunState.run_active:
			RunState.run_active = true
			RunState.start_run([], GameLayers.LAYER_DEFAULT)
		var t3 := Timer.new()
		t3.wait_time = 0.2
		t3.one_shot = true
		t3.timeout.connect(func():
			RunState.ensure_deck_mods()
			var em_list := ["costdown", "save"]
			for i in mini(em_list.size(), RunState.deck_ids.size()):
				RunState.deck_mods[i] = RunState.enchant_mod(str(em_list[i]))
			_deleting = true
			_build_deck_cards()
			_ask_redraw())
		add_child(t3)
		t3.start()
	# 演示参数（R218）：`--pickopen` / `--delopen`
	# 只走「打开选卡页」这一步，**不再额外请求重绘** —— 出图里选卡页必须在，
	# 用来证明 `_start_enchant` / `_buy_row3(delete)` 自己会重绘（Android 触摸的唯一依赖）。
	# 出图：`shop.tscn -- --screenshot --pickopen`
	var po := "--pickopen" in args
	var do_ := "--delopen" in args
	if po or do_:
		if not RunState.run_active:
			RunState.run_active = true
			RunState.start_run([], GameLayers.LAYER_DEFAULT)
		RunState.gold = 500
		var t4 := Timer.new()
		t4.wait_time = 0.2
		t4.one_shot = true
		t4.timeout.connect(func():
			if do_:
				_buy_row3(0)        # 「删除一张卡」→ 打开删除选卡页
			else:
				_start_enchant(0))  # 「附魔」→ 打开附魔选卡页
		add_child(t4)
		t4.start()
	# 命令行 -- --screenshot：自动截图退出（出图核验用）。
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
	_ask_redraw()


func _setup_shop() -> void:
	## 货架初始化。R390：**先看这一格有没有存下来的店** —— 有就原样恢复，绝不重摇。
	## ⚠️ 重摇不只是「商品变了」这么轻：它会消耗 `run_rng` 的随机数，
	##    同一份存档读两次就是两家不同的店，确定性直接破。
	_shop_node = RunState.current_node_id
	var saved := RunState.shop_state_of(_shop_node)
	if not saved.is_empty() and _restore_shop(saved):
		return
	# 第一行：随机本职业奖励卡 —— R481 起**正好抽 `ROW1_MAX`（5）张**。
	# 原来抽 6 张、绘制时按货架宽截断成 4~5 张：第 6 张永远见不到（纯废抽），
	# 窄窗口还会只剩 4 张。现在「抽几张 = 摆几张」。
	# 走 Boss 档概率（普通 35% / 稀有 45% / 史诗 20%）。
	# R241：必须走本局随机链 —— 原来没传 rng（= 全局随机源），同一份存档读两次
	# 会看到不同的商品，破坏「同一种子必然一致」。
	var rolled := CardReward.roll(_repo, "boss", ROW1_MAX, RunState.run_rng)
	_row1 = []
	for c: CardData in rolled:
		# R432：五折标记逐张独立摇，随机源走本局 `run_rng`。
		# ⚠️ 对**抽到的每一张都摇**：R481 起张数恒定（不再随窗口宽变化），这条更稳；
		#    但别改回「按可见数摇」—— 那会让「窗口尺寸不同 → 同一份存档消耗的随机数不同」。
		# ⚠️ 结果随 `_sync_shop_state()` 进 `shop_states`，重进商店**不重摇**。
		var off: bool = RunState.run_rng.randf() < OFF_CHANCE
		_row1.append({"card": c, "sold": false, "off": off})
	# 第二行：从全部附魔里随机抽 3 种不重复（R370 起 6 种 → 抽 3）
	var pool := ENCHANTS.duplicate()
	RunState.shuffle_rng(pool)   # R241：`Array.shuffle()` 是全局随机源，这里不能直接用
	_row2 = []
	for i in 3:
		_row2.append({"ench": pool[i], "sold": false})
	_row3 = _row3_template()
	_reindex_rows()
	_sync_shop_state()


func _row3_template() -> Array:
	## 第三行固定三项的**唯一定义**（R390 抽出来）：恢复货架时要按 key 反查，
	## 两处各写一份 —— 改价只改一处、另一处还留着老价钱，是最典型的漂移。
	var out: Array = [
		{"key": "delete", "name": "删除一张卡", "desc": "从卡组里删掉一张卡", "price": PRICE_DELETE,
			"icon": "shop_icon_remove", "sold": false},
		{"key": "maxhp", "name": "+5 最大生命", "desc": "最大生命 +5，并回复 5 点生命", "price": PRICE_MAXHP,
			"icon": "shop_icon_maxhp", "sold": false},
	]
	# R399（用户口径「第三层应该不再提供巧克力」）：第三层是直道、每格 cost 恒 0，
	# 巧克力在那儿一块也用不掉 —— 这家店不再摆它。
	# ⚠️ 绘制 / 命中 / 恢复货架全都按 `_row3.size()` 自适应，少一项不会留空位
	#    （`_row3[0]` 仍是「删除一张卡」，没有硬编码下标会错位）。
	if RunState.current_layer != GameLayers.LAYER_THREE:
		out.append({"key": "choco", "name": "巧克力", "desc": "获得一块巧克力（行动力 +1）",
			"price": PRICE_CHOCO, "icon": "chocolate", "sold": false})
	return out


func _row3_def(key: String) -> Dictionary:
	## 按 key 取第三行商品定义（恢复货架用）。找不到返回空字典。
	for d: Dictionary in _row3_template():
		if str(d["key"]) == key:
			return d
	return {}


func _ench_by_id(id: String) -> Dictionary:
	## 按 id 取附魔定义。找不到返回空字典。
	for e: Dictionary in ENCHANTS:
		if str(e["id"]) == id:
			return e
	return {}


func _reindex_rows() -> void:
	## 全局商品编号：第一行 0..n1-1，第二行紧跟，第三行再紧跟（三行共用一套下标）。
	_row1_base = 0
	_row2_base = _row1.size()
	_row3_base = _row1.size() + _row2.size()


func _restore_shop(st: Dictionary) -> bool:
	## 从 `RunState.shop_states` 恢复三行货架（R390）。任何一个 id 找不到 →
	## 直接返回 false 让调用方重摇：宁可换一家店，也不能在货架上留一个空卡位
	## （空卡位点得到、买不了，是最难向玩家解释的那种 bug）。
	var r1: Array = st.get("row1", [])
	var r2: Array = st.get("row2", [])
	var r3: Array = st.get("row3", [])
	var o1: Array = []
	for it: Variant in r1:
		if not (it is Array) or (it as Array).size() < 2:
			return false
		var a: Array = it
		var c := _repo.get_card(int(a[0]))
		if c == null:
			return false
		# 第三列 = 五折标记。R432 之前的存档只有两列 → 兼容成「不打折」。
		var off := (int(a[2]) != 0) if a.size() > 2 else false
		o1.append({"card": c, "sold": int(a[1]) != 0, "off": off})
	var o2: Array = []
	for it2: Variant in r2:
		if not (it2 is Array) or (it2 as Array).size() < 2:
			return false
		var b: Array = it2
		var e := _ench_by_id(str(b[0]))
		if e.is_empty():
			return false
		o2.append({"ench": e, "sold": int(b[1]) != 0})
	var o3: Array = []
	for it3: Variant in r3:
		if not (it3 is Array) or (it3 as Array).size() < 2:
			return false
		var c3: Array = it3
		var d := _row3_def(str(c3[0]))
		if d.is_empty():
			return false
		d["sold"] = int(c3[1]) != 0
		o3.append(d)
	_row1 = o1
	_row2 = o2
	_row3 = o3
	_reindex_rows()
	return true


func _sync_shop_state() -> void:
	## 把当前三行货架写回 `RunState`（R390：重进必须原样）。
	## 只存 id 与「售罄」位 —— CardData 是运行时对象，不能进存档。
	## 每次商品状态变化（买入 / 附魔成交 / 删卡 / 服务售罄）都要调一次。
	if _shop_node < 0:
		return
	var r1: Array = []
	for e: Dictionary in _row1:
		var c: CardData = e["card"]
		r1.append([int(c.id), 1 if bool(e["sold"]) else 0,
				1 if bool(e.get("off", false)) else 0])
	var r2: Array = []
	for e2: Dictionary in _row2:
		var ench: Dictionary = e2["ench"]
		r2.append([str(ench["id"]), 1 if bool(e2["sold"]) else 0])
	var r3: Array = []
	for e3: Dictionary in _row3:
		r3.append([str(e3["key"]), 1 if bool(e3["sold"]) else 0])
	RunState.store_shop_state(_shop_node, {"row1": r1, "row2": r2, "row3": r3})


func _ask_redraw() -> void:
	## 场景内**唯一**重绘入口（R218）：所有「状态变了」的地方都走这里。
	## 为什么必须显式：`_draw()` 不会自己跑，改完状态不请求重绘 = 画面停在旧状态。
	## 桌面端有鼠标移动（`_on_motion` 里会请求重绘）罩着，问题被掩盖；
	## **Android 触摸没有那段移动**，于是表现为「点了没反应」。
	_redraw_req += 1
	queue_redraw()


func _process(delta: float) -> void:
	# R186：只在提示淡出动画期间逐帧重绘（原来无条件每帧重绘）；
	# 悬停高亮由 _on_motion 事件驱动重绘。
	if _hint_t > 0.0:
		_hint_t -= delta
		_ask_redraw()
	# R390：飞入卡组的动画。飞到终点的那一张摘掉，并点亮牌库按钮上的金环。
	if not _fly.is_empty() and not _fly_hold:
		var alive: Array = []
		for f: Dictionary in _fly:
			f["t"] = float(f["t"]) + delta
			if float(f["t"]) < FLY_DUR:
				alive.append(f)
			else:
				_deck_flash_t = 0.32
		_fly = alive
		_ask_redraw()
	if _deck_flash_t > 0.0:
		_deck_flash_t = maxf(0.0, _deck_flash_t - delta)
		_ask_redraw()


# ------------------------------------------------------------ 布局（自适应）

func _vs() -> Vector2:
	return size


func _keeper_zone_w() -> float:
	## 老板立绘占的右侧宽度（屏幕宽 30%，夹在 320~420 之间）。
	return clampf(_vs().x * 0.30, 320.0, 420.0)


func _goods_x0() -> float:
	return 32.0


func _goods_w() -> float:
	## 商品区宽度 = 屏幕宽 - 右侧老板区 - 左右边距。
	return _vs().x - _keeper_zone_w() - _goods_x0() - 28.0


func _top_h() -> float:
	## 顶部标题带高度（R481 起不再含金币行 —— 金币交给头像框 HUD，别在这里再画一份）。
	## R508：124 → 100。124 是上一轮为了躲开标题框临时顶上去的，代价是三行整体下压、
	## 第三行几乎贴到「离开商店」。100 的实测余量：标题框底 = 58（`_draw_header`），
	## 第一行卡顶 = 100，卡顶价签最高点 = 100 - 12 = 88，稀有度缎带探出约 20 → 80。
	## 三者都还在 58 以下留 20px 以上，任何窗口比例下都不会压到标题框。
	return 100.0


func _bottom_h() -> float:
	## 底部离开按钮带高度。
	return 64.0


func _row_rects() -> Array:
	## 三行商品的货架区矩形。第一行（卡牌）按**卡牌标准宽高比 58:70** 定高，
	## 第二、三行（附魔 / 固定项）均分剩余高度 —— 卡牌不再被拉伸失真。
	var top := _top_h()
	var bottom := _bottom_h()
	var bottom_pad := 16.0       # R508：第三行层板与「离开商店」按钮之间的呼吸位
	var area_h := _vs().y - top - bottom - bottom_pad
	var shelf_h := 30.0          # R508：层板厚 = `shelf_board.png` 的原始高度，不再垂直缩放
	var gap_v := 8.0             # R508：10 → 8（用户口径「降低 1-2、2-3 行的间距」）
	var card_h := _row1_card_h()   # R481：随卡宽等比（58:70）；窄窗卡面缩了，货架也跟着降
	var row1_h := card_h + shelf_h
	var row23_h := (area_h - row1_h - gap_v * 2.0) / 2.0
	# R508：**只保下限、不设上限**。原来卡 140 上限，1024×768 这类窄高窗口会把三行
	# 全挤在屏幕上半、底下空出 120px（实测）。现在商品区均分到底，多出来的竖向空间
	# 落在背板上 —— 货架本来就该有「上层还空着」的余地，比整块留白好看。
	row23_h = maxf(row23_h, 96.0 + shelf_h)
	var x0 := _goods_x0()
	var w := _goods_w()
	var y := top
	var out: Array = []
	# 每一行的三块几何（R508）：
	#   row   —— 商品摆放区（卡面 / 图标底盘），绘制与命中共用
	#   shelf —— 底部**层板**（`shelf_board.png`，比 row 宽 12px 表示板子出头）
	#   back  —— **后挡板**（`shelf_back.png`）：从商品区顶上方 10px 一直铺到层板下沿，
	#            左右各外扩 14px 暗示柜体侧板。画在商品**之前**，商品因此像"摆进架子里"。
	# 第一行（卡牌）
	out.append({
		"row": Rect2(x0, y, w, card_h),
		"shelf": Rect2(x0, y + card_h, w, shelf_h),
		"back": Rect2(x0 - 10.0, y, w + 20.0, card_h + shelf_h),
	})
	y += row1_h + gap_v
	# 第二行
	out.append({
		"row": Rect2(x0, y, w, row23_h - shelf_h),
		"shelf": Rect2(x0, y + row23_h - shelf_h, w, shelf_h),
		"back": Rect2(x0 - 10.0, y, w + 20.0, row23_h),
	})
	y += row23_h + gap_v
	# 第三行
	out.append({
		"row": Rect2(x0, y, w, row23_h - shelf_h),
		"shelf": Rect2(x0, y + row23_h - shelf_h, w, shelf_h),
		"back": Rect2(x0 - 10.0, y, w + 20.0, row23_h),
	})
	return out


func _visible_row1_count() -> int:
	## 第一行摆几张（R481：**固定 `ROW1_MAX` 张，不再随窗口宽减张数**）。
	## 用户报「小窗口只出现 4 张」—— 老实现是 `int((货架宽+32)/182)` 再夹到 4~5，
	## 1280 基准窗口算出来正好 4 张。现在张数恒定，塞不下就缩卡面（见 `_row1_card_w`）。
	## `_row1.size()` 兜底：抽卡池意外不足时按实际张数画，不多画空位。
	return mini(_row1.size(), ROW1_MAX)


func _row1_card_w() -> float:
	## R481：第一行卡面宽度 —— 按货架宽**等比缩**，保证 `_visible_row1_count()` 张一定塞得下。
	## 比例固定 150:32（卡宽:间距），所以整行总宽 = n*cw + (n-1)*gap，
	## 解出 cw = 货架宽 / (n + 32/150*(n-1))。基准 1280 窗口 → 约 143（原来是 150 但只有 4 张）。
	## ⚠️ 这里只依赖 `_goods_w()` / `_visible_row1_count()`，**不碰 `_row_rects()`** ——
	##    `_row_rects()` 反过来要用 `_row1_card_h()`，互相调就成环。
	var w := _goods_w()
	var n: int = maxi(1, _visible_row1_count())
	if n == 1:
		return ROW1_CARD_W
	var cw := w / (float(n) + ROW1_GAP / ROW1_CARD_W * float(n - 1))
	return clampf(cw, ROW1_MIN_W, ROW1_CARD_W)


func _row1_card_h() -> float:
	## 卡面高度 —— 始终守 58:70 标准比例，随 `_row1_card_w()` 一起缩，绝不单独拉伸。
	return _row1_card_w() * 70.0 / 58.0


func _row1_geom() -> Dictionary:
	## 第一行的几何**唯一口**（R481）：`w` 卡宽 / `h` 卡高 / `gap` 间距 / `x0` 起始 x。
	## 绘制（`_draw_row1`）与命中（`_row1_rect`，连带 `_buy_btn_rect`）都只从这里取 ——
	## 两处各算一份就会出现「看得到、点不中」（R204 踩过同款）。
	## 整行居中：`_goods_w()` 是货架宽，缩完的卡团比它窄时左右平分剩余。
	var cw := _row1_card_w()
	var n: int = maxi(1, _visible_row1_count())
	var gap := ROW1_GAP * (cw / ROW1_CARD_W)
	var total := float(n) * cw + float(n - 1) * gap
	return {"w": cw, "h": cw * 70.0 / 58.0, "gap": gap,
			"x0": _goods_x0() + (_goods_w() - total) / 2.0}


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	# 背景
	var bg: Texture2D = UiAssets.get_tex("bg_shop")
	if bg != null:
		draw_texture_rect(bg, Rect2(Vector2.ZERO, _vs()), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, _vs()), Color("1a1c22"))
	# 老板立绘（右侧）
	var keeper: Texture2D = UiAssets.get_tex("shop_keeper")
	if keeper != null:
		var kw := _keeper_zone_w()
		var kr := Rect2(_vs().x - kw, _top_h() + 20, kw - 20, _vs().y - _top_h() - _bottom_h() - 40)
		draw_texture_rect(keeper, _fit_cover(keeper, kr), false)
	# 顶部标题 + 金币
	_draw_header()
	# 三层货架 + 三行商品（R508：背板 → 商品 → 层板 → 购买按钮，四段顺序不能换）
	_draw_shelf_backs()   # 后挡板在商品后面
	_draw_row1()
	_draw_row2()
	_draw_row3()
	_draw_shelf_boards()  # 层板压在商品底部
	_draw_buy_buttons()   # R390：安卓专用（桌面端单击卡面即成交，不画按钮）—— 骑在层板上
	_draw_goods_popup()
	_draw_pick_overlay()
	_draw_leave()
	_draw_desc_plate()   # R203：悬停/选中卡的描述板（卡面只留卡名后的详情入口）
	_draw_affix_index()  # R444：字段解释浮窗（贴在这张卡左右两侧）
	_draw_hint()
	_draw_fly()          # R390：飞进卡组的卡（画在最上层，盖住一切）


func _fit_cover(tex: Texture2D, box: Rect2) -> Rect2:
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var r_t := tw / th
	var r_b := box.size.x / box.size.y
	var w := box.size.x
	var h := box.size.y
	if r_t > r_b:
		h = box.size.x / r_t
	else:
		w = box.size.y * r_t
	return Rect2(box.position + (box.size - Vector2(w, h)) / 2.0, Vector2(w, h))


func _draw_header() -> void:
	## R481（用户口径）：商店**不再自己画金币** —— 头像框那条 HUD 已经常驻显示金币，
	## 这里再摆一份纯属重复。标题带（64 高）只剩标题，基线随之下移居中（字高 24 → 41）。
	## ⚠️ 顶部留白别急着砍：`DeckViewer` / `RelicViewer` 两个悬浮按钮挂在右上角 (1150,6)/(1044,6)，
	##    标题带压到 40 以下就会贴到它们。
	UiTheme.draw_info_card(self, Rect2(_vs().x * 0.5 - 150, 10, 300, 48))
	draw_string(_font_bold, Vector2(0, 41), "神 秘 商 店",
			HORIZONTAL_ALIGNMENT_CENTER, _vs().x, UiTheme.FS_HEADING, UiTheme.PAGE_INK)



func _draw_shelf_backs() -> void:
	## R508 货架**后挡板**：画在三行商品之前，让商品是"摆进架子里"而不是浮在背景墙上。
	## 素材 `shelf_back.png`（512×176 竖木纹）整张拉伸 —— 不走九宫格：这块板本来就没有
	## 需要保形的描边/角花，拉伸只影响木纹疏密，看不出来。
	## ⚠️ 缺图回退：铺一层半透明深木色。背板的意义是"商品背后有东西"，这一层就够，
	##    不必再程序化画木纹（那是旧 `_draw_shelves` 的做法，也正是用户说的"护栏"观感来源）。
	var rects := _row_rects()
	var back_tex: Texture2D = UiAssets.get_tex("shelf_back")
	for i in 3:
		var back: Rect2 = rects[i]["back"]
		if back_tex != null:
			draw_texture_rect(back_tex, back, false)
		else:
			draw_rect(back, Color(0.19, 0.13, 0.09, 0.94), true)


func _draw_shelf_boards() -> void:
	## R508 货架**层板**：画在三行商品之后 —— 图标/卡面底部压在板上，才有"立在架子上"的
	## 重量感。素材 `shelf_board.png`（1070×32，从原 shelf.png 裁的真实横板）横向拉伸，
	## 竖向按 1:1 用（32 → 30 只差 2px，肉眼不可见）。
	## ⚠️ 不再有旧实现两端那两根 8px 竖撑 —— 那是"护栏"，正是本轮要拆掉的东西。
	var rects := _row_rects()
	var board_tex: Texture2D = UiAssets.get_tex("shelf_board")
	for i in 3:
		var shelf: Rect2 = rects[i]["shelf"]
		# 层板比背板左右各多 6px（16 vs 10）：板子伸出柜体，才看得出"层"。
		var visual := shelf.grow_individual(16.0, 0.0, 16.0, 0.0)
		if board_tex != null:
			draw_texture_rect(board_tex, visual, false)
		else:
			# 程序化层板：板面 + 上沿高光 + 下沿厚度阴影（仍是"一块板"，不是栏杆）
			draw_rect(visual, Color("5a3d22"), true)
			draw_rect(Rect2(visual.position.x, visual.position.y, visual.size.x, 5.0),
					Color("9a6f42"), true)
			draw_rect(Rect2(visual.position.x, visual.end.y - 4.0, visual.size.x, 4.0),
					Color("2f2114"), true)
		# R508：板下投影。没有这一层，层板就只是"贴在背板上的木纹条"；
		# 叠 7 条 2px 渐暗横带（Godot 2D 没有现成的线性渐变填充），
		# 板底立刻"伸"到背板前面，三行也就是三层架子而不是一面木墙。
		for j in 9:
			var a := 0.46 * pow(1.0 - float(j) / 9.0, 1.5)
			draw_rect(Rect2(visual.position.x, visual.end.y + float(j) * 2.0,
					visual.size.x, 2.0), Color(0.0, 0.0, 0.0, a), true)


func _card_price(card: CardData) -> int:
	## 基础价（原价）。**不是成交价** —— 第一行要算五折，一律走 `_row1_price()`。
	match card.rarity:
		0: return 25
		1: return 50
		2: return 80
	return 25


func _row1_price(e: Dictionary) -> int:
	## 第一行卡牌的**实际成交价**（R432 唯一口）：五折则半价、向上取整。
	## 绘制价签 / 触摸「购买」按钮 / 购买提示 / 扣款全读这里 ——
	## 漏一处就是「贴着 -50%，却按原价扣钱」。
	var base := _card_price(e["card"])
	if not bool(e.get("off", false)):
		return base
	return int(ceil(float(base) * OFF_PCT))


func _draw_row1() -> void:
	var rects := _row_rects()
	var row: Rect2 = rects[0]["row"]
	var n := _visible_row1_count()
	var g := _row1_geom()
	var cw: float = g["w"]
	var gap: float = g["gap"]
	var x0: float = g["x0"]
	var y := row.position.y
	var ch: float = g["h"]
	for i in n:
		var e: Dictionary = _row1[i]
		var card: CardData = e["card"]
		var sold: bool = e["sold"]
		var rr := Rect2(x0 + i * (cw + gap), y, cw, ch)
		var hovered := not sold and _hover == _row1_base + i and _enchanting < 0
		# R203：卡面只留卡名（name_only）；悬停或「选中查看」都走高亮。
		var picked := not sold and _sel_row1 == i and _enchanting < 0
		CardFace.draw(self, card, rr, card.health, hovered or picked, false, _font, _font_bold,
				-1, false, false, true)
		var off := bool(e.get("off", false))
		var price := _row1_price(e)
		_draw_price(rr, price, sold, off)
		if off and not sold:
			_draw_off_tag(rr)
		if sold:
			draw_rect(rr, Color(0, 0, 0, 0.55), true)
			draw_string(_font_bold, rr.position + Vector2(0, rr.size.y / 2),
					"已售罄", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, UiTheme.FS_SUBHEAD,
					UiTheme.PAGE_INK)


func _row23_item_rect(row_index: int, i: int) -> Rect2:
	## 第二/三行商品几何唯一口：限宽后整组居中，绘制与点击必须都走这里。
	var row: Rect2 = _row_rects()[row_index]["row"]
	var n := _row2.size() if row_index == 1 else _row3.size()
	var gap := 18.0
	var max_w := ROW2_ITEM_MAX_W if row_index == 1 else ROW3_ITEM_MAX_W
	var bw := minf((row.size.x - maxi(0, n - 1) * gap) / maxi(1, n), max_w)
	var total := n * bw + maxi(0, n - 1) * gap
	var x0 := row.position.x + (row.size.x - total) * 0.5
	return Rect2(x0 + i * (bw + gap), row.position.y, bw, row.size.y)


func _draw_row2() -> void:
	var n := _row2.size()
	for i in n:
		var e: Dictionary = _row2[i]
		var ench: Dictionary = e["ench"]
		var sold: bool = e["sold"]
		var rr := _row23_item_rect(1, i)
		_draw_goods_box(rr, str(ench["icon"]), _ench_name(ench), str(ench["desc"]),
				int(ench["price"]), sold, (_sel_goods if _is_touch() else _hover) == _row2_base + i, _enchanting == i and not sold,
				"enchant")
		if sold:
			_draw_sold_mask(rr)


func _draw_row3() -> void:
	var n := _row3.size()
	for i in n:
		var e: Dictionary = _row3[i]
		var sold: bool = e["sold"]
		# R440 暗动力（6054）：商店的「删除一张卡」被封掉 → 画封禁遮罩（与售罄两套文案）。
		var blocked := str(e["key"]) == "delete" and not RunState.shop_delete_allowed()
		var rr := _row23_item_rect(2, i)
		_draw_goods_box(rr, str(e["icon"]), str(e["name"]), str(e["desc"]),
				int(e["price"]), sold, (_sel_goods if _is_touch() else _hover) == _row3_base + i, false, "service")
		if blocked:
			_draw_block_mask(rr, "暗动力")
		elif sold:
			_draw_sold_mask(rr)


func _goods_icon_box(rr: Rect2) -> Rect2:
	## 第二/三行商品图标的方框 —— **唯一几何口**（R508）。
	## 原来 `_draw_goods_box` 与 `_draw_goods_popup` 各算一份（84 vs 80、下压 6% vs 不压），
	## 图标一改大详情板就会压住图标顶。两处都必须走这里。
	## 下压 6% 的理由：图标素材四周自带透明边距，正对着层板顶画会凭空悬空 30px 左右。
	# 84 → 随行高自适应（84~120）：4:3 窗口（逻辑 1280×960）里商品格高 246，
	# 固定 84 会让三件商品缩在格子底部、上面空一大片，不像陈列。
	var side := clampf(rr.size.y * 0.64, 84.0, 120.0)
	return Rect2(Vector2(rr.get_center().x - side / 2.0,
			rr.end.y - side + side * 0.06), Vector2(side, side))


func _draw_goods_box(rr: Rect2, icon_name: String, name: String, desc: String,
		price: int, sold: bool, hovered: bool, active: bool, category: String = "service") -> void:
	var box := _goods_icon_box(rr)
	var side := box.size.x
	# R508：商品像"摆"在层板上，靠两件事 ——
	#   ① 图标框整体下压 6%（见 `_goods_icon_box`）；
	#   ② 底部一枚扁椭圆落影：贴着层板，影子只有上半截露在板外面。
	# ⚠️ 影子必须画在图标**之前**，且层板在 `_draw_row2/_draw_row3` 之后才画
	#    （见 `_draw()` 的四段顺序），影子下半截才会被板自然盖掉 —— 这才叫"立"。
	draw_set_transform(Vector2(box.get_center().x, rr.end.y - side * 0.02),
			0.0, Vector2(1.0, 0.30))
	draw_circle(Vector2.ZERO, side * 0.38, Color(0.0, 0.0, 0.0, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hovered or active:
		draw_circle(box.get_center(), side * 0.58, Color(1, 0.85, 0.4, 0.25))
		draw_arc(box.get_center(), side * 0.58, 0, TAU, 48, Color("e4bd62"), 3, true)
	var icon: Texture2D = UiAssets.shop_icon(icon_name)
	if icon != null:
		draw_texture_rect(icon, box, false)


func _draw_goods_popup() -> void:
	if _enchanting >= 0 or _deleting:
		return
	var hit := _sel_goods if _is_touch() else _hover
	var entry: Dictionary
	var anchor: Rect2
	var title: String
	if hit >= _row2_base and hit < _row3_base:
		entry = _row2[hit - _row2_base]["ench"]
		anchor = _row2_rect(hit - _row2_base)
		title = _ench_name(entry)
	elif hit >= _row3_base and hit < _row3_base + _row3.size():
		entry = _row3[hit - _row3_base]
		anchor = _row3_rect(hit - _row3_base)
		title = str(entry["name"])
	else:
		return
	var width := minf(320.0, _vs().x - 24.0)
	var lines := TextWrap.wrap_plain(_font, str(entry["desc"]), width - 32, 18)
	var height := 78.0 + lines.size() * 25.0
	var icon_top := _goods_icon_box(anchor).position.y
	var x := clampf(anchor.get_center().x - width * 0.5, 12.0, _vs().x - width - 12.0)
	var y := maxf(12.0, icon_top - height - 16.0)
	var rr := Rect2(x, y, width, height)
	_draw_plate(rr, false, true)
	draw_string(_font_bold, rr.position + Vector2(16, 29), title,
			HORIZONTAL_ALIGNMENT_LEFT, width - 32, 22, UiTheme.PAGE_INK)
	for i in lines.size():
		draw_string(_font, rr.position + Vector2(16, 57 + i * 25), lines[i],
				HORIZONTAL_ALIGNMENT_LEFT, width - 32, 18, UiTheme.PAGE_INK)
	draw_string(_font_bold, Vector2(x + 16, rr.end.y - 15), "%d 金币" % int(entry["price"]),
			HORIZONTAL_ALIGNMENT_LEFT, width - 32, 18, UiTheme.PAGE_INK)


func _draw_plate(rr: Rect2, _wood: bool, lit: bool) -> void:
	UiTheme.draw_info_card(self, rr, lit)


func _draw_sold_mask(rr: Rect2) -> void:
	draw_rect(rr, Color(0, 0, 0, 0.55), true)
	draw_string(_font_bold, rr.position + Vector2(0, rr.size.y / 2),
			"已售罄", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, UiTheme.FS_SUBHEAD, UiTheme.PAGE_INK)


func _draw_block_mask(rr: Rect2, why: String) -> void:
	## R440：被道具封掉的货位（暗动力 6054 → 商店不能删卡）。与「已售罄」同一层遮罩，
	## 只是文案换成封禁原因；点下去仍然会有一句 `_set_hint` 的解释。
	draw_rect(rr, Color(0, 0, 0, 0.55), true)
	draw_string(_font_bold, rr.position + Vector2(0, rr.size.y / 2),
			why, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, UiTheme.FS_SUBHEAD, Color("c9a6f0"))


func _draw_price(rr: Rect2, price: int, sold: bool, off := false) -> void:
	## 第一行价签。`off = true` → 五折：底色转暗红（与卡面那张「-50%」贴纸同色系，
	## 视线一次就能把两者连起来），**金额转绿色**（R435 用户口径：折扣价用绿色读）。
	## ⚠️ 只有价签这一个口转绿。触摸端「购买 · N」按钮本来就是绿底，
	##    金额再转绿会直接糊在底色里 —— 那边保持深绿字，别顺手一起改。
	var chip := Rect2(rr.end.x - 40, rr.position.y - 12, 40, 26)
	draw_rect(chip, UiTheme.ADVENTURE_INPUT if off else UiTheme.PAGE_PAPER, true)
	draw_rect(chip, Color("e0634a") if off else Color("c8951c"), false, 1.5)
	draw_string(_font_bold, chip.position + Vector2(0, 18), "%d" % price,
			HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, 12,
			UiTheme.ADVENTURE_FOREST if off else UiTheme.PAGE_INK)


func _draw_off_tag(rr: Rect2) -> void:
	## R432/R435：五折贴纸「-50%」—— 斜 26° 贴在卡面**右上角**。
	## 位置特意压在稀有度缎带**下方**（缎带高 27k、从卡顶探出）：稀有度是卡面的
	## 主信息通道，贴纸只许挡卡图，不许挡缎带。
	## R435 两处改口径：
	##   ① 整体右移（-42k → -37k）。原来贴纸左端压到卡片中线，看着像贴在卡中间。
	##   ② 不再是规整矩形 —— 四角各错开、上下边各插一个起伏点；视觉最上端那个角
	##      **卷起来**（纸背朝外 + 弧形折痕 + 纸厚淡影 + 整块投影）。
	##      直角矩形读起来是「印刷标签」，卷一下才像人随手按上去的。
	## 全程 `draw_set_transform` 旋转绘制，不引入新素材 —— 贴纸随卡高等比缩放，
	## 4 张 / 5 张货架与任意分辨率都不会失形（换成 png 就得管九宫格与导入）。
	## ⚠️ 末尾**必须**复位 transform：`_draw_row1` 之后还要画售罄遮罩与「已售罄」字。
	var k := rr.size.y / 181.0          # 181 = 150 宽卡的标准高（`_row_rects` 同口径）
	# R435：尺寸 58×22 → 62×26。不是为了「变大」，是因为 22k 高的贴纸上
	# c≈7px 的折角在 720p 只有七八个像素，读不出来 —— 细节要有地方画。
	var w: float = 62.0 * k
	var h: float = 26.0 * k
	# 60k 不是随便定的：贴纸斜 26° 后视觉最高点在右上角（再高 25.2k），
	# 58k 时那个角会压到卡片顶边和稀有度缎带底 —— 60k 留出 8k 余量。
	var center := Vector2(rr.end.x - 37.0 * k, rr.position.y + 60.0 * k)
	draw_set_transform(center, deg_to_rad(-26.0), Vector2.ONE)
	var w2 := w * 0.5
	var h2 := h * 0.5
	var c := h * 0.36                    # 卷角的两条直角边（≈ 9.4k，占贴纸高 36%）
	# 别往大调：c = 0.46h 时缺口吃掉右上一大块，读起来像「被撕了一角」而不是「卷边」。
	# 折痕的两个端点 + 中点（中点朝**外**凸 → 折痕是弧，不是硬折的一条直线）。
	# 这两个点同时是红纸的缺口边缘 —— 折角必须和缺口共用同一条折痕，
	# 否则「缺口」和「米色三角」对不上，看起来就是一块贴歪的纸。
	var pa := Vector2(w2 + 0.15 * k, -h2 + c)        # 缺口终点（右边，往下 c）
	var pb := Vector2(w2 - c, -h2 - 0.1 * k)         # 缺口起点（上边，往左 c）
	var pn := (pa + pb) * 0.5 + Vector2(0.55, -0.55) * k
	var fc := Vector2(pb.x, pa.y)                    # 翻折落点（纸背三角的内角）
	# 纸面（非矩形，顺时针）：**右上角真的缺一块**。
	# ⚠️ R435 返修：先在完整矩形上盖一块米色三角是错的 —— 红框还是个方方正正的矩形，
	#    用户一眼就看出「卷边下面还是红色」。纸角翻了面，那个角就不在平面上了，
	#    红底必须少掉 pa-pn-pb 这块三角，缺口里露出的是卡片本身。
	# 四角另各错开一点点、上下边各插一个起伏点：纸贴在卡上本来就压不平。
	var body := PackedVector2Array([
		Vector2(-w2 + 0.5 * k, -h2 + 0.3 * k),
		Vector2(-w2 * 0.35, -h2 - 0.35 * k),
		pb,                                      # body[2] 缺口起点
		pn,                                      # body[3] 缺口弧（外凸）
		pa,                                      # body[4] 缺口终点
		Vector2(w2 + 0.15 * k, h2 - 0.2 * k),    # 右边略鼓
		Vector2(w2 * 0.3, h2 + 0.5 * k),
		Vector2(-w2 - 0.2 * k, h2 - 0.35 * k),
	])
	# 投影：整块斜移一点点再压半透明黑。没有这一层，贴纸就只是「画在卡上的色块」。
	var shadow := PackedVector2Array()
	for p in body:
		shadow.append(p + Vector2(1.3, 1.5) * k)
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.42))
	draw_colored_polygon(body, Color("b3221a"))                  # 贴纸纸底（暗红）
	# 轮廓：`draw_rect` 画不了缺口与起伏边，只能闭合折线。
	# 折痕那条边（pb→pn→pa）也在这条折线里 —— 它的粗细正是折角的暗影。
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color("3a0f0a"), 2.0 * k, true)
	# 翻折的纸角：沿折痕镜像后落到的位置，看到的是**纸背**。
	# ⚠️ 挑的是局部**右上角**：贴纸整体斜 -26°，右上角才是视觉上的「最上端」。
	# 折在右下角（视觉最右端）会紧贴着「%」的字脚，而且那边是贴纸最窄的地方。
	# ⚠️ 顶点顺序必须是「沿折痕弧走完 → 再走内角」，写成 pa→pn→fc→pb 会自交、
	#    三角化直接失败（`Invalid polygon data, triangulation failed`），贴纸整块消失。
	var curl := PackedVector2Array([pa, pn, pb, fc])
	draw_colored_polygon(curl, Color("f0dfba"))
	# 纸背靠内角一侧压暗：翻起来的纸在根部是背光的，纸厚就是这么读出来的。
	draw_line(fc, pb, Color(0.42, 0.24, 0.15, 0.5), 1.6 * k, true)
	draw_line(fc, pa, Color(0.42, 0.24, 0.15, 0.5), 1.6 * k, true)
	# 文字右移 1k：缺口在右上，红底的重心被削掉一块，纯按矩形居中会看着偏左。
	draw_string(_font_bold, Vector2(-w2 + 1.0 * k, -h2 + h * 0.78), "-50%",
			HORIZONTAL_ALIGNMENT_CENTER, w, int(round(13.5 * k)), Color("fff3cf"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_leave() -> void:
	var rr := _leave_rect()
	var hovered := _hover == 100
	UiTheme.draw_action(self, rr, false, false, hovered)
	draw_string(_font_bold, rr.position + Vector2(0, 29), "离开商店",
			HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, UiTheme.FS_BODY, Color("1a1c22"))


func _draw_hint() -> void:
	# R311 不锈钢盆：**常驻**一行（不是 2.4 秒就消失的 hint）—— 玩家得事先知道
	# 「这单不花金币」，而不是买完才从提示里发现盆没了。
	# ⚠️ 位置特意放**底部提示条上方**：顶部只剩 64 高的标题带，第一排商品的价签会压到它的下沿，
	#    实测「不锈钢盆 10」放那儿会被价签的水晶盖掉一半。
	if RunState.has_basin():
		draw_string(_font, Vector2(0, _vs().y - 48),
				"不锈钢盆 %d 点 · 本次购买优先抵账（不花金币）" % RunState.basin_charge,
				HORIZONTAL_ALIGNMENT_CENTER, _vs().x, UiTheme.FS_CAPTION, UiTheme.ADVENTURE_LIGHT)
	if _hint_t <= 0.0 or _hint == "":
		return
	draw_string(_font, Vector2(0, _vs().y - 26), _hint,
			HORIZONTAL_ALIGNMENT_CENTER, _vs().x, UiTheme.FS_BODY, UiTheme.ADVENTURE_LIGHT)


func _set_hint(text: String) -> void:
	_hint = text
	_hint_t = 2.4
	_ask_redraw()


# ------------------------------------------------------------ 悬停/选中描述板（R203）

func _hover_card() -> CardData:
	## 当前应该显示描述的卡：附魔/删除选卡列表优先，其次第一行「选中查看」的卡，
	## 最后才是鼠标悬停的第一行卡（桌面端）。返回 null = 不画描述板。
	if _hover_enchant_card >= 0 and _hover_enchant_card < _deck_cards.size():
		return _deck_cards[_hover_enchant_card]["card"]
	if _sel_row1 >= 0 and _sel_row1 < _row1.size():
		var e: Dictionary = _row1[_sel_row1]
		if not e["sold"]:
			return e["card"]
		return null
	if _hover < 0:
		return null
	if _hover >= _row1_base and _hover < _row1_base + _row1.size():
		var e2: Dictionary = _row1[_hover - _row1_base]
		if not e2["sold"]:
			return e2["card"]
	return null


func _hover_card_rect() -> Rect2:
	## `_hover_card()` 那张卡在屏幕上的矩形（尺寸 ≤ 0 = 没有卡）。两处取卡口径必须一一对应，
	## 否则字段浮窗会挂在别的卡旁边。
	## R444：字段索引用 —— 浮窗要贴住卡边，`_hover_card()` 只回 CardData，回不了位置。
	if _hover_enchant_card >= 0 and _hover_enchant_card < _deck_cards.size():
		return _pick_card_rect(_hover_enchant_card)
	if _sel_row1 >= 0 and _sel_row1 < mini(_row1.size(), _visible_row1_count()):
		if not _row1[_sel_row1]["sold"]:
			return _row1_rect(_sel_row1)
	if _hover >= _row1_base and _hover < _row1_base + mini(_row1.size(), _visible_row1_count()):
		var i := _hover - _row1_base
		if not _row1[i]["sold"]:
			return _row1_rect(i)
	return Rect2()


func _draw_affix_index() -> void:
	## R444：字段索引浮窗 —— 卡面（R203 起只留卡名）上「次元 / 嘲讽」没有解释可看。
	## 贴在当前这张卡的左右两侧，压住邻卡是明确允许的（卡间距只有 32px，本来就放不下）。
	## ⚠️ 必须画在 `_draw_pick_overlay()` **之后**：附魔 / 删除选卡页有一层 55% 黑罩，
	##    画在罩子下面就等于没画。
	var rr := _hover_card_rect()
	if rr.size.x <= 0.0:
		return
	CardFace.draw_affix_index(self, _hover_card(), rr, _font, _font_bold, 172.0,
			Rect2(Vector2.ZERO, _vs()))


func _draw_desc_plate() -> void:
	## R203：商店卡面改为只留卡名后，效果描述的查看入口 = 底部这条描述板。
	## 桌面端鼠标悬停即显示；移动端无 hover → 两段式点击的「首击选中查看」同样显示。
	var card := _hover_card()
	if card == null:
		return
	var vs := _vs()
	var rr := Rect2(_goods_x0(), vs.y - 58.0, _goods_w(), 40.0)
	UiTheme.draw_info_card(self, rr)
	var affix: String = card.affix_line()
	var meta: String = card.kind + ((" · " + affix) if affix != "" else "")
	draw_string(_font_bold, rr.position + Vector2(10, 17),
			"%s   %s" % [card.card_name, meta],
			HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 20.0, 12, UiTheme.PAGE_INK)
	var eff: String = CardText.naturalize(card.effect_text).replace("\n", " ").strip_edges()
	if eff != "":
		draw_string(_font, rr.position + Vector2(10, 33),
				CardFace._ellipsize(_font, eff, rr.size.x - 20.0, 10),
				HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 20.0, 10, UiTheme.PAGE_INK)


# ------------------------------------------------------------ 附魔选卡覆盖层

func _draw_pick_overlay() -> void:
	## 通用「选卡」覆盖层：附魔选卡（_enchanting >= 0）或删除选卡（_deleting）。
	if _enchanting < 0 and not _deleting:
		return
	var vs := _vs()
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55), true)
	UiTheme.draw_info_card(self, Rect2(vs.x * 0.5 - 290, 24, 580, 80))
	if _deleting:
		draw_string(_font_bold, Vector2(0, 60), "选择要删除的卡",
				HORIZONTAL_ALIGNMENT_CENTER, vs.x, UiTheme.FS_HEADING, UiTheme.PAGE_INK)
		draw_string(_font, Vector2(0, 92), "选中的卡会被永久删除。",
				HORIZONTAL_ALIGNMENT_CENTER, vs.x, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	else:
		var ench: Dictionary = _row2[_enchanting]["ench"]
		draw_string(_font_bold, Vector2(0, 60), "选择要附魔的卡 —— %s" % _ench_name(ench),
				HORIZONTAL_ALIGNMENT_CENTER, vs.x, UiTheme.FS_HEADING, UiTheme.PAGE_INK)
		draw_string(_font, Vector2(0, 92), "给选中的卡附加「%s」。" % _ench_name(ench),
				HORIZONTAL_ALIGNMENT_CENTER, vs.x, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	# ⚠️ 这里**绝对不能**调 `_build_deck_cards()`（R204 修卡死）：
	# 它会把 `_sel_pick` 重置成 -1，而 `_draw()` 在每次 `queue_redraw()` 之后都会跑 →
	# 「首击选中查看」刚设好的下标当场被抹掉 → 第二次点同一张永远走不到成交分支
	# → 附魔 / 删除的选卡页**点什么都没反应**（表现为卡死，只能点「取消」退出）。
	# 候选列表只在**打开覆盖层时**建一次（`_start_enchant` / `_buy_row3` 的删除分支）。
	var any_ok := false
	for i in _deck_cards.size():
		var d: Dictionary = _deck_cards[i]
		var ok: bool = d["ok"]
		if ok:
			any_ok = true
		var rr := _pick_card_rect(i)
		# R203：卡面只留卡名；悬停或「选中查看」都走高亮（移动端无 hover，靠选中查看）。
		var hovered := ok and (_hover_enchant_card == i or _sel_pick == i)
		if ok:
			CardFace.draw(self, d["card"], rr, int(d["card"].health), hovered, false,
					_font, _font_bold, -1, false, false, true)
		else:
			CardFace.draw(self, d["card"], rr, int(d["card"].health), false, false,
					_font, _font_bold, -1, false, false, true)
			draw_rect(rr, Color(0, 0, 0, 0.6), true)
	if not any_ok:
		draw_string(_font, Vector2(0, 300),
				"没有符合这张附魔条件的卡" if not _deleting else "卡组里没有卡可删",
				HORIZONTAL_ALIGNMENT_CENTER, vs.x, UiTheme.FS_SUBHEAD, UiTheme.ADVENTURE_LIGHT)
	# R235 + R353：「确定」按钮（选中卡后点它成交）—— 附魔与删除**都有**。
	# 原来删除只有「取消」，成交只能靠「再点一次同一张」，交互没有 UI 表达。
	var confirm := _pick_confirm_rect()
	var ready := _sel_pick >= 0
	UiTheme.draw_secondary_btn(self, confirm, "确定", false, not ready, true)
	var cancel := _pick_cancel_rect()
	UiTheme.draw_secondary_btn(self, cancel, "取消", false)


func _build_deck_cards() -> void:
	## 构建选卡候选列表。附魔模式按附魔条件过滤；删除模式所有卡都可选。
	_deck_cards = []
	_sel_pick = -1          # 列表重建 → 旧的「选中查看」下标失效
	if _enchanting < 0 and not _deleting:
		return
	for i in RunState.deck_ids.size():
		# R214：取**带附魔的副本**（`card_with_mod`），否则覆盖层里已附魔的卡
		# 显示成没附魔的样子 —— 「任何地方都显示附魔标记」在这一页也得成立。
		var c := RunState.card_with_mod(_repo, i)
		if c == null:
			continue
		var ok := true
		if _deleting:
			# R472：带锁的卡（月亮 9180 / 硬币 9181 / 罐子 9157）灰化 —— 判据只在
			# `RunState.remove_block_reason()` 一处，和卡组编辑页 / 月亮删卡同一套规则。
			ok = RunState.remove_block_reason(i) == ""
		else:
			var ench: Dictionary = _row2[_enchanting]["ench"]
			ok = _enchant_ok(str(ench["id"]), c, i)
		_deck_cards.append({"id": c.id, "card": c, "ok": ok, "idx": i})


func _enchant_ok(ench_id: String, c: CardData, deck_idx: int) -> bool:
	## 附魔资格判定。R224 起唯一口在 `RunState.enchant_ok`（商店选卡页与「牛奶」
	## 随机附魔共用同一份规则）；这里保留壳 —— smoke 直接调 `scene._enchant_ok(...)`。
	return RunState.enchant_ok(ench_id, c, deck_idx)


# ------------------------------------------------------------ 输入

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_on_motion(event.position)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click(event.position)


func _on_motion(pos: Vector2) -> void:
	var old := _hover
	_hover = _hit_at(pos)
	_hover_enchant_card = _enchant_card_at(pos)
	if old != _hover or _hover_enchant_card != -1:
		_ask_redraw()


func _hit_at(pos: Vector2) -> int:
	if _enchanting >= 0 or _deleting:
		return -1
	var n1 := _visible_row1_count()
	for i in n1:
		if _row1_rect(i).has_point(pos) and not _row1[i]["sold"]:
			return _row1_base + i
	for i in _row2.size():
		if _row2_rect(i).has_point(pos) and not _row2[i]["sold"]:
			return _row2_base + i
	for i in _row3.size():
		if _row3_rect(i).has_point(pos) and not _row3[i]["sold"]:
			return _row3_base + i
	if _leave_rect().has_point(pos):
		return 100
	return -1


func _pick_card_rect(i: int) -> Rect2:
	## 选卡覆盖层第 i 张卡的矩形 —— **唯一几何口**（绘制与命中都走这里，
	## 免得两处各写一份 150/190/gap → 改一处就点不中）。
	## R204：卡组一长（>3 行）第 4 行就掉到屏幕外，玩家以为「点不到 / 卡死」——
	## 这里按可用区域**整体等比缩小**（最小 0.45），保证每一张都在屏幕内、都点得到。
	var vs := _vs()
	var n: int = maxi(1, _deck_cards.size())
	var rows := ceili(float(n) / float(PICK_COLS))
	var s := 1.0
	var total_w := PICK_COLS * PICK_CARD_W + (PICK_COLS - 1) * PICK_GAP_X
	var total_h := rows * PICK_CARD_H + maxi(0, rows - 1) * PICK_GAP_Y
	var avail_w: float = maxf(200.0, vs.x - 40.0)
	var avail_h: float = maxf(200.0, vs.y - PICK_Y0 - 100.0)   # 底部留给「取消」
	if total_w > avail_w:
		s = minf(s, avail_w / total_w)
	if total_h > avail_h:
		s = minf(s, avail_h / total_h)
	s = clampf(s, 0.45, 1.0)
	var cw: float = PICK_CARD_W * s
	var ch: float = PICK_CARD_H * s
	var gx: float = PICK_GAP_X * s
	var gy: float = PICK_GAP_Y * s
	var x0 := (vs.x - (PICK_COLS * cw + (PICK_COLS - 1) * gx)) / 2.0
	var col := i % PICK_COLS
	var row := i / PICK_COLS
	return Rect2(x0 + col * (cw + gx), PICK_Y0 + row * (ch + gy), cw, ch)


func _pick_cancel_rect() -> Rect2:
	## 底部「取消」按钮矩形 —— 与「确定」并排（整组居中）。R353 起删除模式也有「确定」。
	var vs := _vs()
	return Rect2(vs.x / 2.0 + 12, vs.y - 80, 160, 44)


func _pick_confirm_rect() -> Rect2:
	## 「确定」按钮矩形（R353 起附魔与删除模式都显示、都响应）。
	var vs := _vs()
	return Rect2(vs.x / 2.0 - 172, vs.y - 80, 160, 44)


func _enchant_card_at(pos: Vector2) -> int:
	if _enchanting < 0 and not _deleting:
		return -1
	for i in _deck_cards.size():
		if _pick_card_rect(i).has_point(pos) and _deck_cards[i]["ok"]:
			return i
	return -1


func _pick_card_any_at(pos: Vector2) -> int:
	## 落在哪张卡上（**不筛 `ok`**）：只用来给「这张卡不符合条件」这类反馈找目标 ——
	## 原来点到灰卡是完全静默的，触摸端玩家会以为「又没反应了」（R218）。
	if _enchanting < 0 and not _deleting:
		return -1
	for i in _deck_cards.size():
		if _pick_card_rect(i).has_point(pos):
			return i
	return -1


func _on_click(pos: Vector2) -> void:
	if _enchanting >= 0 or _deleting:
		_on_pick_click(pos)
		return
	if _leave_rect().has_point(pos):
		_leave()
		return
	# R390：安卓的「购买」按钮 —— 必须判在 `_hit_at` **之前**：它就压在卡位下方的
	# 货架条上，先走 `_hit_at` 会被当成「点到了卡」。
	var bi := _buy_btn_at(pos)
	if bi >= 0:
		_buy_card(bi)
		return
	var hit := _hit_at(pos)
	if _is_touch() and hit >= _row2_base:
		if _sel_goods != hit:
			_sel_goods = hit
			_sel_row1 = -1
			_set_hint("再次点击选中商品购买")
			return
		_sel_goods = -1
	elif _is_touch():
		_sel_goods = -1
		_ask_redraw()

	if hit < 0:
		if _sel_row1 >= 0:            # 点空白 → 取消「选中查看」
			_sel_row1 = -1
			_ask_redraw()
		return
	if hit >= _row1_base and hit < _row1_base + _row1.size():
		var i := hit - _row1_base
		if _is_touch():
			# 触摸端（用户口径 R390）：点卡 = 看说明，成交点卡下的「购买」按钮。
			# 这里**不再保留「再点一次卡面就买」** —— 触摸上双击卡片等于误买，
			# 而看说明本来就会连点两下。
			_sel_row1 = i
			_ask_redraw()
		else:
			# 电脑端（用户口径 R390）：悬停已经给出效果说明，**左键单击一次直接成交**。
			_sel_row1 = -1
			_buy_card(i)
	elif hit >= _row2_base and hit < _row2_base + _row2.size():
		_start_enchant(hit - _row2_base)
	elif hit >= _row3_base and hit < _row3_base + _row3.size():
		_buy_row3(hit - _row3_base)


## R311 不锈钢盆（6041）：本次购买是不是用盆抵的账（由 `_pay()` 写，供提示用）。
var _paid_by_basin := false


func _can_pay(price: int) -> bool:
	## 付不付得起：**只要盆还在，就一定付得起**（用户口径：购买时优先用盆抵账）。
	## ⚠️ 判据必须与 `_pay()` 完全同源 —— 否则会出现「预检说不够、其实盆能抵」
	##    （附魔 / 删卡这两条是先预检、后扣款的路径，最容易被这种分叉咬到）。
	return RunState.has_basin() or RunState.gold >= price


func _pay(price: int) -> bool:
	## 商店付费的**唯一口**（卡 / 附魔 / 最大生命 / 巧克力 / 删卡 五处共用）。
	## R311（用户口径）：持有不锈钢盆时**优先用它交换** —— 不扣金币，改为失去道具。
	## 返回是否付成功（false = 金币不够且没有盆）。
	## ⚠️ 顺序不能反：先判盆、再扣金币。反过来会出现「既扣了钱又没了盆」。
	_paid_by_basin = RunState.basin_pay()
	if _paid_by_basin:
		return true
	return RunState.spend_gold(price)


func _paid_tag(price: int) -> String:
	## 购买提示的付费后缀（**唯一口**）：盆抵账 or 具体金币数。
	## 五处购买点共用，免得某处改成盆、另一处还在说「-50 金币」。
	return "不锈钢盆抵账" if _paid_by_basin else "%d 金币" % price


func _buy_card(i: int) -> void:
	var e: Dictionary = _row1[i]
	var card: CardData = e["card"]
	var price := _row1_price(e)          # R432：五折走同一口，别再读基础价
	if not _pay(price):
		_set_hint("金币不足（需要 %d）" % price)
		return
	e["sold"] = true
	RunState.add_card(card.id)
	_sync_shop_state()                                    # R390：重进要看到「已售罄」
	_start_fly(card, _row1_rect(i))                       # R390：卡飞进卡组
	_set_hint("购买「%s」（%s）" % [card.card_name, _paid_tag(price)])


func _start_enchant(i: int) -> void:
	## ⚠️ 末尾的 `_ask_redraw()` 不是可选项（R218 用户实测）：少了它，点第二行的附魔商品
	## 只会把 `_enchanting` 设上、画面却完全不动 → 玩家以为「点了没反应」，继续点，
	## 结果每一下都落在**看不见的**选卡页上 → 随机某张卡被选中/成交（「对象变成随机」）。
	_enchanting = i
	_hover_enchant_card = -1
	_build_deck_cards()
	_ask_redraw()


func _ench_name(e: Dictionary) -> String:
	## 附魔显示名的**唯一来源** = `CardData.ENCHANT_DEFS`（R240）。
	## 原来商店自己有 5 份文案副本，改名「次元 → 次元之力」时差点只改了字段那处 /
	## 只改了商店那处 —— 这里收成一口：ENCHANTS 的 name 只当兜底。
	var nm := CardData.enchant_name(str(e.get("id", "")))
	return nm if nm != "" else str(e.get("name", ""))


func _demo_enchant(cand: int, commit: bool, ench_id := "save") -> void:
	## R204 演示/回归：把第二行第一件商品换成指定附魔（默认「保存」，任何卡都能吃）→
	## 打开选卡页 → 按**真实点击路径**点第 cand 张；commit=true 时再点一次同一张（应当成交）。
	## R210：`ench_id` 可传 "damage" 出「伤害 +10 只能选技能卡」的对比图。
	var save_ench: Dictionary = {}
	for e: Dictionary in ENCHANTS:
		if str(e["id"]) == ench_id:
			save_ench = e
			break
	if save_ench.is_empty() or _row2.is_empty():
		return
	_row2[0]["ench"] = save_ench
	_start_enchant(0)
	if cand < 0 or cand >= _deck_cards.size():
		_ask_redraw()
		return
	var pos: Vector2 = _pick_card_rect(cand).get_center()
	_on_pick_click(pos)              # 首击 → 选中查看
	if commit:
		_on_pick_click(pos)          # 再击同一张 → 成交
	_ask_redraw()


func _buy_row3(i: int) -> void:
	var e: Dictionary = _row3[i]
	var price: int = e["price"]
	var key: String = e["key"]
	if key == "delete":
		# R440 暗动力（6054）：持有它就不能在商店删卡 —— 判据只问 RunState。
		if not RunState.shop_delete_allowed():
			_set_hint("暗动力：无法在商店删除卡牌")
			return
		if RunState.deck_ids.is_empty():
			_set_hint("卡组里没有卡可删")
			return
		if not _can_pay(price):
			_set_hint("金币不足（需要 %d）" % price)
			return
		_deleting = true
		_hover_enchant_card = -1
		_build_deck_cards()
		_ask_redraw()          # R218：同 `_start_enchant`，否则删除选卡页不出现
	elif key == "maxhp":
		if not _pay(price):
			_set_hint("金币不足（需要 %d）" % price)
			return
		e["sold"] = true
		_sync_shop_state()      # R390
		RunState.gain_max_hp(5)
		_set_hint("最大生命 +5（并回复 5 点）· %s" % _paid_tag(price))
	elif key == "choco":
		if not _pay(price):
			_set_hint("金币不足（需要 %d）" % price)
			return
		e["sold"] = true
		_sync_shop_state()      # R390
		RunState.add_chocolate(1)   # R236：体力回到 > 0 会撤销「耗尽→开 Boss」的待触发
		RunState.sync_fatigue()   # R223 难度 5：巧克力回到 6 以上 → 疲惫出卡组
		_set_hint("巧克力 +1 · %s" % _paid_tag(price))


func _on_pick_click(pos: Vector2) -> void:
	## 选卡覆盖层的点击：附魔模式（_enchanting）或删除模式（_deleting）共用。
	# R235 + R353：「确定」按钮 —— 选中一张卡后点它成交（复用「再点同一张」的成交路径；
	# 删除模式同样走这里）。
	if _pick_confirm_rect().has_point(pos):
		if _sel_pick < 0:
			_set_hint("请先点选一张卡")
			return
		_on_pick_click(_pick_card_rect(_sel_pick).get_center())
		return
	if _pick_cancel_rect().has_point(pos):
		_enchanting = -1
		_deleting = false
		_hover_enchant_card = -1
		_sel_pick = -1
		_ask_redraw()
		return
	var ci := _enchant_card_at(pos)
	if ci < 0:
		var any_i := _pick_card_any_at(pos)
		if any_i >= 0 and _deleting:
			# R472：删除模式点到带锁的灰卡 → 说清原因（旧行为是静默，玩家以为卡死）
			_set_hint(RunState.remove_block_reason(int(_deck_cards[any_i]["idx"])))
			return
		if any_i >= 0 and not _deleting:
			# 点到「不符合这张附魔条件」的灰卡 → 明确说一句，别让玩家以为死机
			_set_hint("这张卡不能吃「%s」（已附魔或类型不符）"
					% _ench_name(_row2[_enchanting]["ench"]))
			return
		if _sel_pick >= 0:            # 点空白 → 取消「选中查看」
			_sel_pick = -1
			_ask_redraw()
		return
	if _sel_pick != ci:
		# 首击 → 选中查看（R203 两段式：卡面只留卡名后，移动端靠这个看描述）
		_sel_pick = ci
		_ask_redraw()
		return
	_sel_pick = -1
	var d: Dictionary = _deck_cards[ci]
	var idx: int = d["idx"]
	# ---- 删除模式 ----
	if _deleting:
		var del_price: int = _row3[0]["price"]
		# R311：预检同样要认「有盆就一定付得起」（与 `_can_pay` 同源）
		if not _can_pay(del_price):
			_set_hint("金币不足（需要 %d）" % del_price)
			_deleting = false
			_ask_redraw()
			return
		var del_card: CardData = null
		if idx < RunState.deck_ids.size():
			del_card = _repo.get_card(RunState.deck_ids[idx])
		var del_name: String = del_card.card_name if del_card != null else str(idx)
		# R472：带锁的卡在这里就拦下，别等到「先删卡、再扣钱」那一步才报一个笼统的失败。
		var del_block := RunState.remove_block_reason(idx)
		if del_block != "":
			_set_hint(del_block)
			_deleting = false
			_ask_redraw()
			return
		# 先删卡、再扣钱（R204）：删失败绝不白扣。
		if not RunState.delete_deck_card(idx):
			_set_hint("删除失败")
			_deleting = false
			_ask_redraw()
			return
		_pay(del_price)   # R311：有盆就用盆抵（前面 `_can_pay` 已经把「付不起」挡掉了）
		_row3[0]["sold"] = true
		_sync_shop_state()      # R390
		_set_hint("删除了「%s」（%s）" % [del_name, _paid_tag(del_price)])
		_deleting = false
		_hover_enchant_card = -1
		_ask_redraw()
		return
	# ---- 附魔模式 ----
	var ench: Dictionary = _row2[_enchanting]["ench"]
	var price: int = ench["price"]
	if not _can_pay(price):
		_set_hint("金币不足（需要 %d）" % price)
		_enchanting = -1
		_ask_redraw()
		return
	var mod := _ench_mod(str(ench["id"]))
	# 先落附魔、再扣钱（R204）：附魔失败（越界 / 已有附魔）绝不白扣金币。
	if not RunState.enchant_deck_card(idx, mod):
		_set_hint("附魔失败")
		_enchanting = -1
		_ask_redraw()
		return
	_pay(price)   # R311：有盆就用盆抵（预检已过，这里不会失败）
	_row2[_enchanting]["sold"] = true
	_sync_shop_state()      # R390
	var c := _repo.get_card(RunState.deck_ids[idx])
	_set_hint("「%s」获得附魔「%s」（%s）" % [c.card_name if c != null else str(idx),
			_ench_name(ench), _paid_tag(price)])
	_enchanting = -1
	_hover_enchant_card = -1
	_ask_redraw()


func _ench_mod(ench_id: String) -> Dictionary:
	## R214：数值定义搬到 `RunState.enchant_mod()`（唯一口）—— 演示旗标 / 测试 /
	## 商店三处必须完全同源，否则「卡面标记显示的那种附魔」和「实际烤进去的数值」会漂移。
	return RunState.enchant_mod(ench_id)


func _leave() -> void:
	## 离开商店。R390（用户口径）：**在下一次移动之前**还能再进来，货架原样 ——
	## 窗口在这里登记，玩家走出这一格时由 `RunState.advance()` 自动关闭。
	RunState.shop_mark_revisit(_shop_node)
	RunState.complete_current()
	if route_fn.is_valid():
		route_fn.call("res://scenes/map.tscn")
	else:
		SceneFx.goto("res://scenes/map.tscn")


# ------------------------------------------------------------ 命中区

func _row1_rect(i: int) -> Rect2:
	## 第一行第 i 张卡的矩形 —— 与 `_draw_row1` 共用 `_row1_geom()`（R481）。
	var row: Rect2 = (_row_rects() as Array)[0]["row"]
	var g := _row1_geom()
	var cw: float = g["w"]
	var gap: float = g["gap"]
	return Rect2(float(g["x0"]) + i * (cw + gap), row.position.y, cw, float(g["h"]))


func _row2_rect(i: int) -> Rect2:
	return _row23_item_rect(1, i)


func _row3_rect(i: int) -> Rect2:
	return _row23_item_rect(2, i)


func _leave_rect() -> Rect2:
	var vs := _vs()
	return Rect2(vs.x - 160, vs.y - 60, 140, 44)


# ------------------------------------------------------------ R390：平台分叉购买

func _is_touch() -> bool:
	## 商店的交互风格按**平台**分叉（用户口径 R390）：
	##   * 电脑端：鼠标悬停看说明，**左键单击一次就买**；
	##   * 安卓端：触摸没有悬停 → 点卡看说明，再点卡下方的「购买」按钮成交。
	## ⚠️ 判据只看平台名，**不看输入事件类型**：桌面接鼠标的安卓设备极少，
	##    而按事件判会让第一下触摸落进桌面分支（就成了「点一下就买」的误触）。
	return _force_touch or OS.get_name() == "Android"


func _buy_btn_rect(i: int) -> Rect2:
	## 安卓「购买」按钮的矩形 —— 压在卡牌正下方的**货架条**上（高 30，
	## 按钮占 26 正好一条）。与 `_row1_rect` 同宽同起点：改卡宽只需改那一处。
	var rr := _row1_rect(i)
	# R508：层板高 30，按钮原来 26 高、距卡底 2px —— 等于把整条板盖住，第一行只剩一排绿按钮。
	# 收成 24 高、上下各留 3px，板的上沿高光和下沿厚度都还在。
	return Rect2(rr.position.x + 8.0, rr.position.y + rr.size.y + 3.0, rr.size.x - 16.0, 24.0)


func _buy_btn_at(pos: Vector2) -> int:
	## 命中哪张卡的「购买」按钮（-1 = 没有）。只认**还没卖掉**的。
	if not _is_touch() or _enchanting >= 0 or _deleting:
		return -1
	var n := _visible_row1_count()
	for i in n:
		if i >= _row1.size() or bool(_row1[i]["sold"]):
			continue
		if _buy_btn_rect(i).has_point(pos):
			return i
	return -1


func _draw_buy_buttons() -> void:
	## 安卓专用：卡下那条「购买 · 50」。桌面端不画 —— 那边单击卡面就成交，
	## 多摆一个按钮只会让人以为「必须按这里才能买」。
	if not _is_touch():
		return
	var n := _visible_row1_count()
	for i in n:
		if i >= _row1.size():
			continue
		var e: Dictionary = _row1[i]
		if bool(e["sold"]):
			continue
		var rr := _buy_btn_rect(i)
		var price := _row1_price(e)          # R432：触摸端按钮也要显示折后价
		var can := _can_pay(price)
		UiTheme.draw_secondary_btn(self, rr, "购买 · %d" % price, false, not can, true)


# ------------------------------------------------------------ R390：卡飞进卡组

func _deck_btn_center() -> Vector2:
	## 右上角「牌库 N」按钮的中心 = 飞行动画的终点。DeckViewer 固定贴在 (1150,6)、
	## 尺寸 114×32（R375 同款位置），这里只算中心、不依赖它的实例。
	return Vector2(_vs().x - 73.0, 22.0)


func _start_fly(card: CardData, from: Rect2) -> void:
	## 卡从货架上飞出去。`from` = 它刚才所在的那个卡位（不是固定坐标 ——
	## 第一行张数会变、位置会挪，写死坐标在 4 张 / 5 张时会从空处起飞）。
	_fly.append({"card": card, "from": from, "t": 0.0})
	_ask_redraw()


func _draw_fly() -> void:
	## 买到的卡飞向右上角「牌库」并缩小消失 —— 让「它现在在卡组里」是**看见的**，
	## 而不是只有底下一行提示。
	## ⚠️ 为什么自己画缩略卡、而不是把 `CardFace.draw` 的 rect 缩到 0.2：
	##    卡面排版按高度等比缩放，但文字有「最小字号 cap」不跟着缩 →
	##    巴掌大的小卡上挂着正常字号，糊成一团。这里只画纸底 + 卡图 + 描边，
	##    任何尺寸都干净。
	for f: Dictionary in _fly:
		var card: CardData = f["card"]
		var from: Rect2 = f["from"]
		var k: float = clampf(float(f["t"]) / FLY_DUR, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 2.4)        # 起步快、到点收 —— 像被吸过去
		var sc := lerpf(1.0, 0.16, e)
		var c: Vector2 = from.get_center().lerp(_deck_btn_center(), e)
		var rr := Rect2(c - from.size * sc * 0.5, from.size * sc)
		var tint := CardFace.paper_tint(card)
		tint.a = 1.0 - 0.2 * e
		draw_rect(rr, tint, true)
		var art := CardFace.art_for(card.id, false, 0)
		if art != null and rr.size.x > 20.0:
			var abox := Rect2(rr.position, Vector2(rr.size.x, rr.size.y * UiTheme.CARD_ART_RATIO))
			draw_texture_rect_region(art, abox,
					CardFace.cover_region(art.get_size(), abox),
					Color(1, 1, 1, 1.0 - 0.2 * e))
		draw_rect(rr, Color(1.0, 0.92, 0.62, 1.0 - 0.3 * e), false, maxf(1.2, 3.0 * sc))
	# 落点金环：卡「进」到牌库按钮上的那一下
	if _deck_flash_t > 0.0:
		var p := 1.0 - _deck_flash_t / 0.32
		draw_arc(_deck_btn_center(), 22.0 + 26.0 * p, 0.0, TAU, 32,
				Color(1.0, 0.86, 0.42, 0.9 * (1.0 - p)), 3.0, true)
