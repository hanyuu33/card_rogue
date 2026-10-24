class_name RewardPanel
extends CanvasLayer

const UiPop = preload("res://scripts/ui_pop.gd")
const UiAssets = preload("res://scripts/ui_assets.gd")
## 奖励悬浮窗（R119）—— 一次获得的**所有**奖励都在这里处理。
##
## 为什么要有它：
##   * 打完 Boss 掉的道具原来**当场自动发放**，玩家只看到结算按钮上的一行字 —— 介绍根本没机会看；
##   * 宝箱层开箱原来把 desc 塞进事件页的一行 result_label —— 长描述（「叠加态的鸭」这类）会画出框外；
##   * 卡牌奖励原来是一个独立场景，与道具奖励各走各的路，两边行为还不一样。
##
## 统一后的口径：**奖励先入队（`RunState.pending_rewards`），由本悬浮窗逐项展示** ——
##   ① 顺序自定：列表里点哪一条就看哪一条；
##   ② 看完能回列表，随时再看、再领（「返回」不消耗任何东西）；
##   ③ 领取 / 放弃过的那一条在列表里**置灰**（state = claimed / skipped）。
## 关掉悬浮窗**不会丢奖励** —— 界面上常驻一个「✦ 待领奖励 N」入口，随时可以回来处理。
##
## 三个视图（`_view`）：
##   VIEW_LIST   列表 —— 悬浮窗主界面，一屏列出本批全部奖励
##   VIEW_RELIC  道具详情 —— 完整 desc（折行 + 滚轮）＋ 领取 / 放弃 / 返回
##   VIEW_CARDS  卡牌三选一 —— 点一张候选即领取；也可整组放弃 / 返回
##
## ⚠️ 「卡牌奖励」是**三选一**，所以它不能「一键领取」：必须进详情挑一张。
##    `claim_all_relic_rewards()` 只收拾道具，卡牌组一律留给玩家自己选。
##
## 用法：在场景 `_ready` 里 `RewardPanel.attach(self, Vector2(12, 40))`；
## 入队之后调 `open()` 弹出（常驻入口按钮由本类自己维护）。
## 命令行 -- --r119：演示（造一批奖励并直接弹窗，截图验证用）。

const UiTheme = preload("res://scripts/ui_theme.gd")

const VIEW_LIST := 0
const VIEW_RELIC := 1
const VIEW_CARDS := 2
## R323：牛奶 6028 的「附魔贴上去了」演示视图 —— 只播动画，点一下就回列表。
const VIEW_ENCHANT := 3
const ENCH_CARD_IN := 220       # 两张卡淡入用时（ms）
const ENCH_STEP := 620          # 第一张开始贴 → 第二张开始贴，间隔
const ENCH_STAMP := 380         # 一张卡的「贴上去」时长
const ENCH_DROP := 64.0         # 徽章从上方多高落下（再高会压到标题）
const ENCH_BADGE_K := 1.9       # 演示里徽章放大倍数（比卡面大，看得清）

## R121：本面板是「满屏 + 接管鼠标」的覆盖层 → 打开/关闭时在 UiGate 登记/撤销，
## 让下层的道具悬停（RelicViewer 速览浮层等）自动让位。
const GATE_ID := "reward_panel"

const PANEL_W := 1020.0
const PANEL_H := 584.0
const PAD := 24.0
const ROW_H := 84.0
const ROW_GAP := 10.0
const HEAD_H := 66.0          # 面板头部高度（标题行之下就是列表）
const FOOT_H := 66.0          # 面板底部按钮带高度

# 卡牌三选一：版式尺度沿用原 card_reward 场景，玩家看到的位置不变
const CARD_W := 216.0
const CARD_H := 260.0
const CARD_GAP := 44.0
const DETAIL_STRIP_H := 176.0   # R155：悬停详情 = 三张卡正下方的横条（与卡组同一左右边界）
# R206：横条高度改为**按内容自适应**，这个值只是上限（可用空间不够时再往下压）

var _root: Control
var _btn: Button              # 常驻入口「✦ 待领奖励 N」
var _font: Font
var _font_bold: Font
var _btn_pos := Vector2(12, 40)
var _open := false
var _view := VIEW_LIST
var _sel := 0                 # 当前在看的条目下标（列表 → 详情带过去）
var _hover_row := -1
var _hover_card := -1
var _mention_hits: Array = []   # R168：本帧「提到的卡牌 / 道具」的命中矩形
var _hover_mention := {}        # R168：当前鼠标压中的那一个（{} = 没有）
var _mention_pin := {}          # R302：触屏点一下钉住的那份说明（再点别处收起）
var _pick_sel := -1           # R167：卡牌三选一里「已点选、待确认」的那张（触屏没有悬停）
var _scroll := 0.0
var _cached_n := -1
var _ench_t0 := 0                # R323：附魔演示的起点（毫秒）
var _ench_pin := -1.0            # R323：>=0 时把演示进度钉在这个毫秒数（出图核验）
var _ench_cards: Array = []      # R323：演示用的两份卡面（已烤好附魔数值）
var _ench_ids: Array = []        # R323：对应的附魔 id
var _repo_cards: CardRepo
var _repo_relics: RelicRepo
## R216：跳去选卡页**之前**让宿主收尾（战斗：房间标记完成 / Boss 推进层；事件：房间完成）。
## 顺序很重要 —— 先收尾再换场景，否则「跳走」会把没做完的结算甩掉。
var on_before_pick: Callable = Callable()
## 烟测接缝：非空时代替真跳转（headless 没有场景可换）。正式流程永远为空。
var route_fn: Callable = Callable()


static func attach(host: Node, btn_pos := Vector2(12, 40)) -> RewardPanel:
	## 挂到任意界面：返回新建的悬浮层实例。
	var p := RewardPanel.new()
	p._btn_pos = btn_pos
	host.add_child(p)
	return p


func _init() -> void:
	layer = 18   # 压在牌库(15)/道具(15)之上 —— 它是「必须先看一眼」的层


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	_repo_cards = CardRepo.load_json()
	_repo_relics = RelicRepo.load_json()

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	_root.draw.connect(_on_draw)
	_root.gui_input.connect(_on_input)
	add_child(_root)

	_btn = Button.new()
	_btn.position = _btn_pos
	_btn.size = Vector2(152, 32)
	_btn.custom_minimum_size = Vector2(152, 32)
	_btn.add_theme_font_override("font", _font)
	_btn.add_theme_font_size_override("font_size", UiTheme.FS_LABEL)
	_btn.add_theme_color_override("font_disabled_color", UiTheme.SAND)
	_btn.visible = false
	_btn.pressed.connect(open)
	UiTheme.apply_chip(_btn, false, true)
	add_child(_btn)
	_refresh_btn()

	_demo_start()


# ------------------------------------------------------------ 开关 / 每帧

func is_open() -> bool:
	return _open


func open() -> void:
	if RunState.pending_rewards.is_empty():
		return
	_open = true
	UiGate.push(GATE_ID)   # R121：登记覆盖层 —— 下层的道具悬停就此让位
	_root.visible = true
	UiPop.play(_root, 1.0)   # R151 P1-9：全屏自绘层只淡入（压暗条满屏，一缩就露边）
	_view = VIEW_LIST
	_sel = _first_pending("")
	if _sel < 0:
		_sel = 0
	_scroll = 0.0
	_hover_row = -1
	_hover_card = -1
	_pick_sel = -1
	_ench_t0 = 0
	_refresh_btn()
	_root.queue_redraw()


func close() -> void:
	_open = false
	UiGate.pop(GATE_ID)
	_root.visible = false
	_view = VIEW_LIST
	_scroll = 0.0
	_pick_sel = -1
	_ench_t0 = 0
	_refresh_btn()


func _exit_tree() -> void:
	## R121：场景被切掉时也必须撤销登记 —— 否则「阻塞态」会漏进下一个场景，
	## 那边的道具悬停会莫名其妙全部失灵（而且再也恢复不了）。
	UiGate.pop(GATE_ID)


func _process(_delta: float) -> void:
	if _cached_n != RunState.pending_reward_count():
		_refresh_btn()
	# R323：附魔演示是**时间基**动画 —— 只有这一种视图需要逐帧重绘
	if _view == VIEW_ENCHANT and _root != null and _root.visible:
		_root.queue_redraw()
	# R186：面板绘制无时间基元素（悬停 / 滚动 / 提及悬浮均由事件驱动重绘）
	# → 不逐帧重绘（移动端耗电；PC 端闲置占用同步下降）。


func _refresh_btn() -> void:
	_cached_n = RunState.pending_reward_count()
	_btn.visible = _cached_n > 0 and not _open
	_btn.text = "✦ 待领奖励 %d" % _cached_n
	_btn.tooltip_text = "点开处理这批奖励（查看 / 领取 / 放弃）"


func _vs() -> Vector2:
	## 视口尺寸（自绘坐标 = 屏幕坐标，`_root` 是满屏且在原点）。
	return get_viewport().get_visible_rect().size


func _panel_rect() -> Rect2:
	var vs := _vs()
	return Rect2(Vector2((vs.x - PANEL_W) / 2.0, (vs.y - PANEL_H) / 2.0),
			Vector2(PANEL_W, PANEL_H))


# ------------------------------------------------------------ 数据小工具

func _first_pending(kind: String) -> int:
	## 第一条还没处理的条目下标（kind == "" 表示不限类型）；没有返回 -1。
	for i in RunState.pending_rewards.size():
		var e: Dictionary = RunState.pending_rewards[i]
		if str(e.get("state", RunState.REWARD_PENDING)) != RunState.REWARD_PENDING:
			continue
		if kind != "" and str(e.get("kind", "")) != kind:
			continue
		return i
	return -1


func _cards_entry_with(card_id: int) -> int:
	## 哪一条卡牌奖励的候选里有这张卡（回放按 id 找回原文）。
	for i in RunState.pending_rewards.size():
		var e: Dictionary = RunState.pending_rewards[i]
		if str(e.get("kind", "")) != "cards":
			continue
		if (e.get("candidates", []) as Array).has(card_id):
			return i
	return -1


func _entry_name(e: Dictionary) -> String:
	var k := str(e.get("kind", ""))
	if k == "relic":
		var r: RelicData = _repo_relics.get_relic(int(e.get("id", 0)))
		return r.relic_name if r != null else "未知道具"
	# R351 月亮（9180）：这条不是「挑一张卡」，是「给一次删卡机会」。
	if k == "deck_delete":
		return "删除卡组中的一张卡"
	return "卡牌奖励（三选一）"


func _entry_tag(e: Dictionary) -> String:
	var k := str(e.get("kind", ""))
	if k == "relic":
		var r: RelicData = _repo_relics.get_relic(int(e.get("id", 0)))
		if r == null:
			return "奖励道具"
		return r.tag_line()
	if k == "deck_delete":
		return "卡组操作 · 点它领下，随后挑一张永久删除"
	return "卡牌奖励 · %s" % CardReward.type_label(str(e.get("type", "normal")))


func _entry_color(e: Dictionary) -> Color:
	var k := str(e.get("kind", ""))
	if k == "relic":
		var r: RelicData = _repo_relics.get_relic(int(e.get("id", 0)))
		if r != null:
			return r.badge_color()
	if k == "deck_delete":
		return Color("6f86b8")     # 月亮的凉色，和卡牌/道具两条都区分得开
	return UiTheme.ACCENT_GOLD


func _entry_name_color(e: Dictionary, base: Color) -> Color:
	## R343：条目名字色 —— 传奇道具走金橙（`RelicData.name_color`），其余保持调用方原色。
	## 界面里**不许**自己判 `tier == 传奇` 挑色，档位色的唯一口在数据层。
	if str(e.get("kind", "")) != "relic":
		return base
	var r: RelicData = _repo_relics.get_relic(int(e.get("id", 0)))
	return r.name_color(base) if r != null else base


func _state_label(e: Dictionary) -> String:
	match str(e.get("state", RunState.REWARD_PENDING)):
		RunState.REWARD_CLAIMED:
			return "已领取"
		RunState.REWARD_SKIPPED:
			return "已放弃"
	return "待领"


func _settled(e: Dictionary) -> bool:
	return str(e.get("state", RunState.REWARD_PENDING)) != RunState.REWARD_PENDING


func _relic_desc_text(e: Dictionary) -> String:
	var r: RelicData = _repo_relics.get_relic(int(e.get("id", 0)))
	if r == null:
		return "（这件道具的说明缺失）"
	var note := RunState.relic_state_note(r.id)
	return r.desc if note == "" else "%s  （%s）" % [r.desc, note]


func _wrap(text: String, max_w: float, size: int) -> Array[String]:
	## 中文友好的字符级换行（共享实现见 CardFace.wrap_text）。
	return CardFace.wrap_text(_font, text, max_w, size)


# ------------------------------------------------------------ 动作（唯一口）

func _claim_entry(i: int) -> void:
	if i < 0 or i >= RunState.pending_rewards.size():
		return
	var was_milk := _is_milk_entry(i)
	RunState.claim_pending_reward(i)
	_view = VIEW_LIST
	_scroll = 0.0
	# R323（用户口径）：牛奶附完魔，**把两张卡摆出来、用动画把标志贴上去** ——
	# 原来两张卡当场被默默改掉，玩家根本不知道附了什么。
	if was_milk and not RunState.milk_anim.is_empty():
		_open_enchant_view()
		return
	_root.queue_redraw()
	# R216：即时道具（鸭血 / 源数之力 / 失忆药水）领完**立刻**去选卡 ——
	# 旧版要玩家先关掉本界面、回到地图 `_ready` 才跳，表现就是「拿了鸭血没反应」。
	_route_if_waiting_pick()


func _is_milk_entry(i: int) -> bool:
	## 这条待领奖励是不是「牛奶 6028」。（牛奶也可能从陶罐里掉出来，所以按 id 判，
	## 不按来源判。）
	if i < 0 or i >= RunState.pending_rewards.size():
		return false
	var e: Dictionary = RunState.pending_rewards[i]
	return str(e.get("kind", "")) == "relic" \
			and int(e.get("id", -1)) == RunState.MILK_RELIC_ID


func _open_enchant_view() -> void:
	## R323：把 `RunState.milk_anim` 里那两张卡做成**卡面副本**（数值已烤上附魔），
	## 然后逐张播放「附魔标志从上方落下 → 印在费用正下方」的动画。
	## ⚠️ 副本上的 `enchant` 先清空 —— 静态标记由动画接管，否则会先出现一次再被贴一次。
	_ench_cards = []
	_ench_ids = []
	for it: Dictionary in RunState.milk_anim:
		var base: CardData = _repo_cards.get_card(int(it.get("card_id", 0)))
		var eid := str(it.get("ench", ""))
		if base == null or eid == "":
			continue
		var c := CardData.from_dict(base.to_dict())
		RunState._apply_mod(c, RunState.enchant_mod(eid))
		c.enchant = ""            # 静态标记交给动画画
		_ench_cards.append(c)
		_ench_ids.append(eid)
	if _ench_cards.is_empty():
		_root.queue_redraw()
		return
	# 正常路径是从「领取」进来的（面板本来就开着）；出图 / 演示路径是直接调这里，
	# 所以缺一次「真正打开」的登记（否则 `_on_draw` 开头的 `if not _open` 会直接吞掉）。
	if not _open:
		_open = true
		UiGate.push(GATE_ID)
		_root.visible = true
		UiPop.play(_root, 1.0)
	_view = VIEW_ENCHANT
	_ench_t0 = Time.get_ticks_msec()
	_root.queue_redraw()


func _close_enchant_view() -> void:
	RunState.milk_anim = []
	_ench_cards = []
	_ench_ids = []
	_view = VIEW_LIST
	_ench_t0 = 0
	_root.queue_redraw()


func _route_if_waiting_pick() -> void:
	## 领取后立刻结算的唯一出口 —— 单条领取与「一键领取」共用（后者也要能立刻跳）。
	var target := route_target_after_pick()
	if target != "":
		_settle_then_route(target)


static func route_target_after_pick() -> String:
	## 领取之后是否要立刻转去选卡页（"" = 不用）。判据只有 `RunState` 一个口。
	## R340（用户报「打完 Boss 拿完道具直接进二层、没拿卡牌奖励」）：
	## **本批奖励还没处理完时一律不跳走。**
	## 旧逻辑是「一领到即时道具（鸭血 6024 / 源数之力 6002 / 失忆药水 6004）就立刻转
	## `deck_edit`」，转之前会调宿主 `battle_scene._settle_before_pick()`，而那里在
	## Boss 通关（`_run_next_layer > 0`）时当场 `advance_layer()` —— 于是卡牌三选一
	## 还没展示，人已经在下一层了，条目还躺在队列里没人再弹。
	## 现在：先让玩家把这一批领完 / 选完，`pending_relic` 留在 `RunState` 里，
	## 由下一次 `waiting_pick_scene()` 接住（`map_scene._ready` 与 `curtain._leave`
	## 两个入口都查它），跳转时机就落在「本批真正结束之后」。
	if RunState.pending_reward_count() > 0:
		return ""
	return RunState.waiting_pick_scene()


func _settle_then_route(target: String) -> void:
	## 先让宿主收尾 → 关界面 → 换场景。
	if on_before_pick.is_valid():
		on_before_pick.call()
	close()
	if route_fn.is_valid():
		route_fn.call(target)      # 烟测：只记录目标，不真换场景
	else:
		SceneFx.goto(target)


func _skip_entry(i: int) -> void:
	if i < 0 or i >= RunState.pending_rewards.size():
		return
	RunState.skip_pending_reward(i)
	_view = VIEW_LIST
	_scroll = 0.0
	_root.queue_redraw()


func _pick_card(i: int, card_id: int) -> void:
	## 卡牌三选一：选中即入卡组 + 该条置灰。
	if i < 0 or i >= RunState.pending_rewards.size():
		return
	RunState.pick_pending_card(i, card_id)
	_view = VIEW_LIST
	_scroll = 0.0
	_pick_sel = -1
	_root.queue_redraw()


func _open_entry(i: int) -> void:
	if i < 0 or i >= RunState.pending_rewards.size():
		return
	_sel = i
	var e: Dictionary = RunState.pending_rewards[i]
	var k := str(e.get("kind", ""))
	# R351 删卡奖励没有候选可挑 —— 点它就直接领下，然后由
	# `_claim_entry → _route_if_waiting_pick` 决定是立刻跳 deck_edit 还是等本批处理完。
	if k == "deck_delete":
		if not _settled(e):
			_claim_entry(i)
		return
	if k == "relic":
		_view = VIEW_RELIC
	else:
		_view = VIEW_CARDS
	_scroll = 0.0
	_hover_card = -1
	_pick_sel = -1
	_root.queue_redraw()


func _back_to_list() -> void:
	_view = VIEW_LIST
	_scroll = 0.0
	_hover_card = -1
	_pick_sel = -1
	_root.queue_redraw()


# ------------------------------------------------------------ 绘制

func _on_draw() -> void:
	if not _open:
		return
	_root.draw_rect(Rect2(Vector2.ZERO, _vs()), Color(0, 0, 0, 0.45), true)
	_mention_hits = []   # 每帧重建（命中表由绘制过程自己填）
	match _view:
		VIEW_RELIC:
			_draw_relic()
		VIEW_CARDS:
			_draw_cards()
		VIEW_ENCHANT:
			_draw_enchant()
		_:
			_draw_list()
	_draw_mention_tip()   # R168：悬浮件画在最后（压在所有内容之上）


func _draw_panel_box(r: Rect2) -> void:
	## R191：羊皮卷底（九宫格自适应，**无边框** —— 用户口径「换成羊皮卷风格的底」）。
	UiTheme.draw_scroll_bg(_root, r)


func _draw_list() -> void:
	var r := _panel_rect()
	_draw_panel_box(r)
	var total := RunState.pending_rewards.size()
	var pend := RunState.pending_reward_count()
	_root.draw_string(_font_bold, Vector2(r.position.x + PAD, r.position.y + 40),
			"✦ 获得奖励", HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_HEADING, UiTheme.INK_900)
	_root.draw_string(_font, Vector2(r.position.x + 250, r.position.y + 38),
			"共 %d 件 · 待领 %d 件　（点任意一条查看详情）" % [total, pend],
			HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 300, UiTheme.FS_BODY, UiTheme.INK_600)

	# 条目列表
	var view_h := PANEL_H - HEAD_H - FOOT_H
	for i in total:
		var rr := _row_rect(i)
		if rr.end.y < r.position.y + HEAD_H - ROW_GAP:
			continue
		if rr.position.y > r.position.y + HEAD_H + view_h:
			break
		_draw_row(i, rr)
	if total > _rows_per_page():
		_root.draw_string(_font, Vector2(r.position.x + PANEL_W - PAD - 90,
				r.position.y + HEAD_H - 8),
				"滚轮翻页", HORIZONTAL_ALIGNMENT_RIGHT, 90, UiTheme.FS_CAPTION, UiTheme.INK_500)

	# 底部按钮
	var done := _btn_done_rect()
	var all := _btn_claim_all_rect()
	var any_relic := false
	for e: Dictionary in RunState.pending_rewards:
		if str(e.get("kind", "")) == "relic" and not _settled(e):
			any_relic = true
			break
	if any_relic:
		_draw_btn(all, "领取全部道具", true, false)
		_root.draw_string(_font, Vector2(r.position.x + PAD, done.position.y + 12),
				"「领取全部道具」不碰卡牌奖励 —— 卡牌要自己挑一张",
				HORIZONTAL_ALIGNMENT_LEFT, 560, UiTheme.FS_CAPTION, UiTheme.INK_500)
	else:
		_root.draw_string(_font, Vector2(r.position.x + PAD, done.position.y + 12),
				"卡牌奖励 / 删卡奖励要点进去处理（不能一键领取）" if pend > 0 else "全部奖励都已处理，可以点「完成」",
				HORIZONTAL_ALIGNMENT_LEFT, 620, UiTheme.FS_CAPTION, UiTheme.INK_500)
	_draw_btn(done, "完成", false, false)


func _rows_per_page() -> int:
	return maxi(1, int((PANEL_H - HEAD_H - FOOT_H) / (ROW_H + ROW_GAP)))


func _row_rect(i: int) -> Rect2:
	var r := _panel_rect()
	return Rect2(r.position.x + PAD,
			r.position.y + HEAD_H + i * (ROW_H + ROW_GAP) - _scroll,
			PANEL_W - PAD * 2.0, ROW_H)


func _draw_row(i: int, rr: Rect2) -> void:
	var e: Dictionary = RunState.pending_rewards[i]
	var settled := _settled(e)
	var hovered := i == _hover_row
	var bg := Color("efece4") if not hovered else Color("e6e1d4")
	_root.draw_rect(rr, bg, true)
	_root.draw_rect(rr, UiTheme.INK_300, false, 1.0)
	# 左侧来源色条
	_root.draw_rect(Rect2(rr.position.x, rr.position.y + 8, 8, ROW_H - 16),
			_entry_color(e), true)
	# 名称 + 标签
	_root.draw_string(_font_bold, Vector2(rr.position.x + 24, rr.position.y + 34),
			"「%s」" % _entry_name(e), HORIZONTAL_ALIGNMENT_LEFT, 560,
			UiTheme.FS_SUBHEAD, _entry_name_color(e, UiTheme.INK_900))
	_root.draw_string(_font, Vector2(rr.position.x + 24, rr.position.y + 60),
			_entry_tag(e), HORIZONTAL_ALIGNMENT_LEFT, 560,
			UiTheme.FS_CAPTION, UiTheme.INK_600)
	# 右侧状态徽标
	var chip := Rect2(rr.end.x - 118, rr.position.y + 28, 100, 28)
	_root.draw_rect(chip, Color("cfc7b2") if not settled else Color("ddd8cc"), true)
	_root.draw_rect(chip, UiTheme.INK_300, false, 1.0)
	_root.draw_string(_font_bold, chip.position + Vector2(0, 19),
			_state_label(e), HORIZONTAL_ALIGNMENT_CENTER, chip.size.x,
			UiTheme.FS_CAPTION, UiTheme.INK_600 if settled else Color("7a5a10"))
	# 已处理 → 整条蒙一层白（置灰）
	if settled:
		_root.draw_rect(rr, Color(1, 1, 1, 0.62), true)


func _enchant_panel_rect() -> Rect2:
	## R323：附魔演示的面板（两张卡并排 + 标题 + 底部提示）。
	var vs := _vs()
	var pw := minf(vs.x - 72.0, 2.0 * CARD_W + 180.0)
	var ph := minf(vs.y - 64.0, CARD_H + 226.0)
	return Rect2(Vector2((vs.x - pw) / 2.0, (vs.y - ph) / 2.0), Vector2(pw, ph))


func _draw_enchant_badge(center: Vector2, r: float, eid: String, alpha: float) -> void:
	## R323：附魔徽章（与卡面 `_draw_enchant_mark` 同一套视觉：深色圆盘 + 种类色环 + 素材图标），
	## 但**透明度 / 半径由动画控制**，所以这里重画一份而不是调卡面那口。
	if r < 2.0 or alpha <= 0.01:
		return
	var col: Color = CardData.enchant_color(eid)
	var disc: Color = col.darkened(0.74)
	disc.a = 0.94 * alpha
	_root.draw_circle(center, r, disc)
	_root.draw_arc(center, r, 0.0, TAU, 28, Color(col.r, col.g, col.b, alpha),
			maxf(1.2, r * 0.20), true)
	var icon: Texture2D = UiAssets.enchant_icon(eid)
	if icon != null:
		var ir := r * 0.86
		_root.draw_texture_rect(icon,
				Rect2(center - Vector2(ir, ir), Vector2(ir, ir) * 2.0), false,
				Color(1, 1, 1, alpha))
	else:
		var fs: int = maxi(8, roundi(r * 1.1))
		_root.draw_string(_font_bold, center + Vector2(-fs * 0.5, fs * 0.38),
				CardData.enchant_name(eid).substr(0, 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))


func _draw_enchant() -> void:
	## R323（用户口径）：牛奶附魔后**显示这两张卡**，并用动画**把附魔标志贴上**。
	##   · 0 ~ ENCH_CARD_IN：两张卡淡入（微微放大落定）
	##   · 之后每张各来一次「徽章从上方落下 → 印在费用正下方 → 一圈扩散环」
	##   · 全部贴完 → 底部提示「点击任意处继续」
	var vs := _vs()
	var now := Time.get_ticks_msec()
	var el := _ench_pin if _ench_pin >= 0.0 else float(now - _ench_t0)
	_root.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.05, 0.045, 0.08, 0.90), true)
	var pr := _enchant_panel_rect()
	UiTheme.draw_scroll_bg(_root, pr)
	var ink := Color("2f2a20")
	_root.draw_string(_font_bold, Vector2(pr.position.x, pr.position.y + 46),
			"牛奶 —— 随机附魔", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x,
			UiTheme.FS_HEADING, ink)
	_root.draw_string(_font, Vector2(pr.position.x, pr.position.y + 76),
			"这两张卡被贴上了附魔（数值已经生效）",
			HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, UiTheme.FS_BODY, UiTheme.INK_600)
	var n := _ench_cards.size()
	var total := n * CARD_W + maxi(0, n - 1) * CARD_GAP
	var x0 := pr.position.x + (pr.size.x - total) / 2.0
	var y0: float = pr.position.y + 112.0
	var card_u := clampf(el / ENCH_CARD_IN, 0.0, 1.0)
	var all_done := true
	for i in n:
		var card: CardData = _ench_cards[i]
		var eid := str(_ench_ids[i])
		var rr := Rect2(x0 + i * (CARD_W + CARD_GAP), y0, CARD_W, CARD_H)
		# 卡面：淡入 + 从 0.94 放大到 1.0（用 draw 的缩放只能靠画两次，这里只做透明度）
		if card_u < 1.0:
			# 未完全淡入：先画一层暗的占位（避免「凭空出现」）
			_root.draw_rect(rr, Color(0.9, 0.88, 0.82, 0.20 * card_u), true)
		CardFace.draw_pick(_root, card, rr, _font, _font_bold, false)
		if card_u < 1.0:
			_root.draw_rect(rr, Color(0.05, 0.045, 0.08, 0.75 * (1.0 - card_u)), true)
		# 附魔标志下落 + 印上
		var dt := el - float(ENCH_CARD_IN + i * ENCH_STEP)
		if dt < 0.0:
			all_done = false
			continue
		var u := clampf(dt / float(ENCH_STAMP), 0.0, 1.0)
		var ev := 1.0 - pow(1.0 - u, 3.0)          # ease-out cubic
		var center := CardFace.enchant_badge_center(rr)
		var r: float = CardFace.badge_radius(rr) * ENCH_BADGE_K
		var drop := center + Vector2(0, -ENCH_DROP * (1.0 - ev))
		var a := clampf(u * 3.0, 0.0, 1.0)
		_draw_enchant_badge(drop, r * lerpf(1.25, 1.0, ev), eid, a)
		if u >= 0.62:
			# 印上去那一下：一圈扩散环
			var k := (u - 0.62) / 0.38
			var col: Color = CardData.enchant_color(eid)
			_root.draw_arc(center, r * (1.0 + 2.4 * k), 0.0, TAU, 28,
					Color(col.r, col.g, col.b, (1.0 - k) * 0.9), 2.5, true)
		if u < 1.0:
			all_done = false
		# 卡下：卡名 · 附魔名
		var label := "%s · %s" % [card.card_name, CardData.enchant_name(eid)]
		var lw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1,
				UiTheme.FS_BODY).x
		_root.draw_string(_font_bold,
				Vector2(rr.position.x + CARD_W / 2.0 - lw / 2.0, rr.end.y + 34.0),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_BODY,
				CardData.enchant_color(eid))
	if all_done or el > 3200.0:
		_root.draw_string(_font, Vector2(pr.position.x, pr.end.y - 30.0),
				"点击任意处继续", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x,
				UiTheme.FS_CAPTION, UiTheme.INK_600)


func _draw_relic() -> void:
	var r := _panel_rect()
	_draw_panel_box(r)
	if _sel >= RunState.pending_rewards.size():
		_back_to_list()
		return
	var e: Dictionary = RunState.pending_rewards[_sel]
	var settled := _settled(e)
	_draw_btn(_btn_back_rect(), "← 返回列表", false, false)
	_root.draw_string(_font_bold, Vector2(r.position.x + 180, r.position.y + 40),
			"「%s」" % _entry_name(e), HORIZONTAL_ALIGNMENT_LEFT, 520,
			UiTheme.FS_HEADING, _entry_name_color(e, UiTheme.INK_900))
	# R206：改半透明奶油底（透出羊皮卷纹理）+ **高度随内容自适应** —— 与卡牌三选一的
	# 详情条同一语言。旧版是**实心** `f0ede4` 铺满整块，短描述就在卷轴上摊一张白纸，
	# 和两边卷边完全脱节；现在内容少就收短，长描述仍然吃满（超出照样滚动）。
	var prose := _relic_desc_text(e)
	var body_txt_w := PANEL_W - PAD * 4.0
	var body_h := clampf(30.0
			+ float(CardFace.wrap_text(_font, prose, body_txt_w, UiTheme.FS_BODY).size()) * 24.0
			+ Mention.block_height(_font, _font_bold, prose, body_txt_w, Mention.BLOCK_HEAD_H)
			+ 34.0, 150.0, PANEL_H - HEAD_H - FOOT_H)
	_root.draw_rect(Rect2(r.position.x + PAD, r.position.y + HEAD_H, PANEL_W - PAD * 2.0,
			body_h), Color(0.99, 0.97, 0.90, 0.55), true)
	_root.draw_string(_font, Vector2(r.position.x + PAD * 2.0, r.position.y + HEAD_H + 30),
			"%s　·　状态：%s" % [_entry_tag(e), _state_label(e)],
			HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - PAD * 4.0, UiTheme.FS_BODY, UiTheme.INK_600)
	# R168：正文改用富文本绘制 —— 「提到的卡牌 / 道具名」自动换色并交出命中矩形。
	var txt_w := PANEL_W - PAD * 4.0
	var txt_x := r.position.x + PAD * 2.0
	var bottom := r.position.y + PANEL_H - FOOT_H - 8.0
	var segs := CardText.parse(_relic_desc_text(e))
	var res := CardText.draw_wrapped_hits(_root, _font, _font_bold, segs, txt_x,
			r.position.y + HEAD_H + 68.0 - _scroll, txt_w, UiTheme.FS_BODY, 24.0,
			Color("3a342a"), bottom, r.position.y + HEAD_H + 56.0, Color("f0ede4"))
	# R302：**不再**把「这条文案里提到的…」固定列在详情底部 —— 只要悬停名字弹说明
	#（触屏：点一下钉住）。命中矩形由上面的 `draw_wrapped_hits` 直接交出。
	_mention_hits = res["hits"]
	if CardText.wrap_segments(_font, _font_bold, segs, txt_w, UiTheme.FS_BODY).size() \
			* 24.0 > (PANEL_H - HEAD_H - FOOT_H - 68.0):
		_root.draw_string(_font, Vector2(r.position.x + PANEL_W - PAD - 120,
				r.position.y + PANEL_H - FOOT_H - 8.0),
				"滚轮滚动", HORIZONTAL_ALIGNMENT_RIGHT, 120, UiTheme.FS_CAPTION, UiTheme.INK_500)
	# 底部动作
	var claim := _btn_claim_rect()
	var skip := _btn_skip_rect()
	if settled:
		_root.draw_string(_font, Vector2(r.position.x + PAD, claim.position.y + 12),
				"这条已经%s了（不可再操作）" % ("领取" if _state_label(e) == "已领取" else "放弃"),
				HORIZONTAL_ALIGNMENT_LEFT, 420, UiTheme.FS_BODY, UiTheme.INK_500)
	else:
		_root.draw_string(_font, Vector2(r.position.x + PAD, claim.position.y + 12),
				"「返回列表」不会丢掉它 —— 可以随时再点进来看、再领取。",
				HORIZONTAL_ALIGNMENT_LEFT, 480, UiTheme.FS_CAPTION, UiTheme.INK_500)
	_draw_btn(skip, "放弃这件", false, settled)
	_draw_btn(claim, "领取" if not settled else "已处理", true, settled)


func _cards_panel_rect() -> Rect2:
	## 卡牌三选一的羊皮卷面板（R191）：屏幕居中，留边适配各种屏幕。
	var vs := _vs()
	var pw := minf(vs.x - 72.0, 1056.0)
	var ph := minf(vs.y - 56.0, 668.0)
	return Rect2(Vector2((vs.x - pw) / 2.0, (vs.y - ph) / 2.0), Vector2(pw, ph))


func _draw_cards() -> void:
	if _sel >= RunState.pending_rewards.size():
		_back_to_list()
		return
	var e: Dictionary = RunState.pending_rewards[_sel]
	var settled := _settled(e)
	var vs := _vs()
	# R191：整屏米白底 → **暗化罩 + 中央羊皮卷面板**（不透明，下层战场不会糊进来）。
	_root.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.05, 0.045, 0.08, 0.86), true)
	var pr := _cards_panel_rect()
	UiTheme.draw_scroll_bg(_root, pr)
	var total := 3 * CARD_W + 2 * CARD_GAP
	var x0 := pr.position.x + (pr.size.x - total) / 2.0
	var cands: Array = e.get("candidates", [])
	_root.draw_string(_font_bold, Vector2(pr.position.x, pr.position.y + 46),
			"卡牌奖励 —— 点一张看说明，再确认加入卡组（%s）" % _entry_tag(e),
			HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, UiTheme.FS_HEADING, Color("2f2a20"))
	_root.draw_string(_font, Vector2(pr.position.x, pr.position.y + 76),
			"「%s」" % ("已领取：选了其中一张" if settled else "看完随时可以点下面「返回列表」"),
			HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, UiTheme.FS_BODY, UiTheme.INK_600)
	for i in cands.size():
		var card: CardData = _repo_cards.get_card(int(cands[i]))
		if card == null:
			continue
		var rr := Rect2(x0 + i * (CARD_W + CARD_GAP), _cards_y(), CARD_W, CARD_H)
		var is_pick := i == _pick_sel and not settled
		var hov := (i == _hover_card or is_pick) and not settled
		if hov:
			_root.draw_rect(rr.grow(6.0), Color(1, 1, 1, 0.75), true)   # R155：亮边与点选判定同圈（原来大 4px）
			if is_pick:
				# R167：已点选（待确认）那张补一圈金边 —— 触屏没有悬停，得让「我选了哪张」看得见
				_root.draw_rect(rr.grow(9.0), UiTheme.ACCENT_GOLD, false, 3.0)
		CardFace.draw_pick(_root, card, rr, _font, _font_bold, false)   # R191：只留卡名
		# R155：稀有度铭牌 —— 宽度按文字实测（旧版写死 90px，和 216 宽的卡面对不上），
		# 深色底条压在**这张卡自己的中轴**正下方。
		var rn := card.rarity_name()
		var lw := _font_bold.get_string_size(rn, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FS_BODY).x + 18.0
		var plate := Rect2(rr.position.x + CARD_W / 2.0 - lw / 2.0, rr.position.y + CARD_H + 8.0, lw, 24.0)
		_root.draw_rect(plate, Color(0.13, 0.14, 0.18, 0.88), true)
		_root.draw_rect(plate, card.rarity_color(), false, 1.2)
		_root.draw_string(_font_bold, plate.position + Vector2(9, 17), rn,
				HORIZONTAL_ALIGNMENT_LEFT, lw - 18.0, UiTheme.FS_BODY, card.rarity_color())
		if settled:
			var picked := int(e.get("picked", -1))
			if card.id != picked:
				_root.draw_rect(rr, Color(1, 1, 1, 0.66), true)
			else:
				_root.draw_rect(rr.grow(4.0), UiTheme.ACCENT_GOLD, false, 3.0)
	# 悬停详情（卡面放不下效果文本）
	_draw_card_detail(cands)
	_draw_btn(_btn_cards_back_rect(), "← 返回列表", false, false)
	# R342 火柴：只在**持有**时出现（没有火柴就别放个永远点不动的按钮占位）。
	# 次数用完 → 保留按钮但置灰，让玩家看得见「3 次真的用光了」。
	if RunState.has_relic(RunState.MATCH_RELIC_ID):
		var rb := _btn_cards_reroll_rect()
		var left := maxi(0, RunState.match_charge)
		var rtxt := "刷新 · 剩 %d" % left if rb.size.x >= 132.0 else "刷新 %d" % left
		_draw_btn(rb, rtxt, false, settled or left <= 0)
	_draw_btn(_btn_cards_skip_rect(), "放弃这组", false, settled)
	# R167：确认按钮（触屏必需 —— 没有悬停就得靠它「先看后拿」）
	var can_pick := (not settled) and _pick_sel >= 0 and _pick_sel < cands.size()
	_draw_btn(_btn_confirm_rect(), "确认选择这张", true, not can_pick)
	_root.draw_string(_font, Vector2(pr.position.x, pr.end.y - 66.0),
			"点一张卡先看说明 → 再点「确认选择这张」加入卡组" if not settled else "这组已经处理过了",
			HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, UiTheme.FS_CAPTION, UiTheme.INK_600)


func _draw_card_detail(cands: Array) -> void:
	## R155：详情从「钉在屏幕最右边缘」改成**三张卡正下方的横条**（与卡组同一左右边界）。
	# R167：鼠标悬停优先；**触屏**没有悬停 → 用「已点选」的那张（点一下就能读到说明）。
	# R206：排版重做 —— ①左栏只放「卡名 / 编号·种类·费用·稀有度 / 数值」，②右栏放
	#   「效果 + 提及块」，两栏各有自己的 x 起点与栏宽（旧版把提及块**从右栏正文底部
	#   接到左栏 x** 起画 → 标题压着左栏数值行、摘要横跨两栏 → 用户口径「排版乱」）；
	#   ③提及强调色按**真实底色**挑（羊皮纸浅底 → 琥珀棕，不再是奶油色上看不清的亮金）；
	#   ④横条高度随内容自适应（下限 96 / 上限 DETAIL_STRIP_H），不再一律撑满留一大片空白。
	var idx := _hover_card if _hover_card >= 0 else _pick_sel
	if idx < 0 or idx >= cands.size():
		return
	var card: CardData = _repo_cards.get_card(int(cands[idx]))
	if card == null:
		return
	var pr2 := _cards_panel_rect()
	var bx := pr2.position.x + 36.0
	var bw := pr2.size.x - 72.0
	var top := _cards_y() + CARD_H + 40.0       # 卡下沿还挂着稀有度铭牌（+8~+32）
	var pad := 15.0
	var col_w := 232.0
	var ex := bx + pad + col_w + 24.0           # 右栏起点（= 分隔线 + 13）
	var ew := bx + bw - pad - ex                # 右栏宽度
	var bg := Color(0.99, 0.97, 0.90)           # 横条底色（半透明铺在羊皮卷上）
	var ink := Color("2a5a8a")                  # 效果正文色（沿用原口径）
	var stats := CardFace.stats_line(card)
	var segs := CardText.parse(card.effect_text)
	var stat_lines := 0
	if stats != "":
		stat_lines = CardFace.wrap_text(_font, stats, col_w, UiTheme.FS_CAPTION).size()
	var eff_lines: int = CardText.wrap_segments(_font, _font_bold, segs, ew, 13).size()
	var blk_h := Mention.block_height(_font, _font_bold, card.effect_text, ew,
			Mention.BLOCK_HEAD_H)
	var right_h := 22.0 + float(eff_lines) * 19.0 + (8.0 + blk_h if blk_h > 0.0 else 0.0)
	var left_h := 24.0 + 22.0 + float(stat_lines) * 17.0
	var avail := pr2.end.y - top - 76.0         # 下面还留着「返回列表 / 放弃 / 确认」那一排
	var box_h := clampf(maxf(left_h, right_h) + pad * 2.0, 96.0, minf(DETAIL_STRIP_H, avail))
	var box := Rect2(bx, top, bw, box_h)
	# R191：羊皮卷面板**内**的详情条 —— 淡色半透明底（透出羊皮卷纹理），无边框。
	_root.draw_rect(box, Color(bg.r, bg.g, bg.b, 0.55), true)
	# 左右分栏的细分隔线：让「这张卡是什么」与「它做什么」各成一块
	var sx := bx + pad + col_w + 11.0
	_root.draw_line(Vector2(sx, box.position.y + pad * 0.7),
			Vector2(sx, box.end.y - pad * 0.7), Color(0.35, 0.30, 0.20, 0.16), 1.0)
	# ── 左栏：卡名 / 元信息 / 数值 ─────────────────────────────
	var lx := bx + pad
	var ly := box.position.y + pad + 19.0
	_root.draw_string(_font_bold, Vector2(lx, ly), card.card_name,
			HORIZONTAL_ALIGNMENT_LEFT, col_w, UiTheme.FS_SUBHEAD, Color.BLACK)
	ly += 22.0
	_root.draw_string(_font, Vector2(lx, ly),
			"#%d  %s · %d 费 · %s" % [card.id, card.kind, card.cost, card.rarity_name()],
			HORIZONTAL_ALIGNMENT_LEFT, col_w, UiTheme.FS_CAPTION, UiTheme.INK_600)
	ly += 19.0
	if stats != "":
		for t: String in CardFace.wrap_text(_font, stats, col_w, UiTheme.FS_CAPTION):
			_root.draw_string(_font, Vector2(lx, ly), t,
					HORIZONTAL_ALIGNMENT_LEFT, col_w, UiTheme.FS_CAPTION, UiTheme.INK_600)
			ly += 17.0
	# ── 右栏：效果全文（折行，提及自动上色）+ 提及块 ───────────
	_root.draw_string(_font_bold, Vector2(ex, box.position.y + pad + 15.0), "效果",
			HORIZONTAL_ALIGNMENT_LEFT, ew, UiTheme.FS_CAPTION, ink)
	var res := CardText.draw_wrapped_hits(_root, _font, _font_bold, segs, ex,
			box.position.y + pad + 34.0, ew, 13, 19.0, ink, box.end.y - pad, -1.0, bg)
	# R302：同上 —— 提及只做「悬停弹窗」，不再固定列在详情底部。
	_mention_hits = res["hits"]


func _draw_btn(r: Rect2, text: String, primary: bool, disabled: bool) -> void:
	var bg := UiTheme.ACCENT_GOLD if primary else Color("dcd6c8")
	var fg := Color("3a2c08") if primary else UiTheme.INK_800
	if disabled:
		bg = Color("e2ddd2")
		fg = Color("9a958a")
	_root.draw_rect(r, bg, true)
	_root.draw_rect(r, UiTheme.INK_300, false, 1.0)
	_root.draw_string(_font_bold, r.position + Vector2(0, r.size.y / 2.0 + 7.0), text,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_BODY, fg)


# ------------------------------------------------------------ 命中区（绘制与输入共用）

func _btn_done_rect() -> Rect2:
	var r := _panel_rect()
	return Rect2(r.end.x - PAD - 120.0, r.end.y - 52.0, 120.0, 38.0)


func _btn_claim_all_rect() -> Rect2:
	var d := _btn_done_rect()
	return Rect2(d.position.x - 186.0, d.position.y, 170.0, 38.0)


func _btn_back_rect() -> Rect2:
	var r := _panel_rect()
	return Rect2(r.position.x + PAD, r.position.y + 16.0, 130.0, 34.0)


func _btn_claim_rect() -> Rect2:
	var r := _panel_rect()
	return Rect2(r.end.x - PAD - 120.0, r.end.y - 52.0, 120.0, 38.0)


func _btn_skip_rect() -> Rect2:
	var c := _btn_claim_rect()
	return Rect2(c.position.x - 150.0, c.position.y, 136.0, 38.0)


func _cards_y() -> float:
	## 三张卡的顶边（面板内，R191）。
	return _cards_panel_rect().position.y + 104.0


func _btn_cards_back_rect() -> Rect2:
	## 卡牌三选一的「← 返回列表」（R191：挪到羊皮卷面板左下；列表/道具视图的
	## `_btn_back_rect` 在面板**顶部**，两者位置不同不能共用）。
	var pr := _cards_panel_rect()
	return Rect2(pr.position.x + 36.0, pr.end.y - 56.0, 130.0, 38.0)


func _btn_cards_reroll_rect() -> Rect2:
	## R342 火柴：「刷新」按钮（塞在「← 返回列表」与「放弃这组」之间）。
	## 面板宽度随屏幕变（`_cards_panel_rect` 有 min），所以宽度按**可用间隙**收缩 ——
	## 小窗口下宁可字少一点，也不要压到隔壁按钮。
	var back := _btn_cards_back_rect()
	var skip := _btn_cards_skip_rect()
	var gap := skip.position.x - back.end.x - 28.0
	var w := clampf(gap, 96.0, 150.0)
	var x := back.end.x + 14.0 + maxf(0.0, (gap - w) / 2.0)
	x = minf(x, skip.position.x - 8.0 - w)
	return Rect2(x, back.position.y, w, back.size.y)


func _btn_cards_skip_rect() -> Rect2:
	var pr := _cards_panel_rect()
	return Rect2(pr.position.x + pr.size.x / 2.0 - 160.0, pr.end.y - 56.0, 140.0, 38.0)


func _btn_confirm_rect() -> Rect2:
	## R167：卡牌三选一的「确认选择这张」（放在「放弃这组」右侧）。
	var pr := _cards_panel_rect()
	return Rect2(pr.position.x + pr.size.x / 2.0 + 20.0, pr.end.y - 56.0, 190.0, 38.0)


func _card_rect_in(e: Dictionary, i: int) -> Rect2:
	var pr := _cards_panel_rect()
	var total := 3 * CARD_W + 2 * CARD_GAP
	var x0 := pr.position.x + (pr.size.x - total) / 2.0
	return Rect2(x0 + i * (CARD_W + CARD_GAP), _cards_y(), CARD_W, CARD_H)


# ------------------------------------------------------------ 输入

func _on_input(event: InputEvent) -> void:
	if not _open:
		return
	# R323：附魔演示视图 —— 左键 / 右键都直接收起（不打断动画也不卡住玩家）
	if _view == VIEW_ENCHANT:
		if event is InputEventMouseButton and event.pressed \
				and (event.button_index == MOUSE_BUTTON_LEFT \
				or event.button_index == MOUSE_BUTTON_RIGHT):
			_close_enchant_view()
		return
	if event is InputEventMouseMotion:
		_on_motion(event.position)
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_scroll = maxf(0.0, _scroll - 40.0)
				_root.queue_redraw()
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll = minf(_max_scroll(), _scroll + 40.0)
				_root.queue_redraw()
			MOUSE_BUTTON_LEFT:
				_on_click(event.position)
			MOUSE_BUTTON_RIGHT:
				if _view != VIEW_LIST:
					_back_to_list()


func _on_motion(pos: Vector2) -> void:
	var old_row := _hover_row
	var old_card := _hover_card
	var old_men := _hover_mention
	_hover_row = -1
	_hover_card = -1
	_hover_mention = {}
	for h: Dictionary in _mention_hits:
		if (h["rect"] as Rect2).has_point(pos):
			_hover_mention = h
			break
	match _view:
		VIEW_LIST:
			var r := _panel_rect()
			var lo := r.position.y + HEAD_H
			var hi := r.position.y + PANEL_H - FOOT_H
			for i in RunState.pending_rewards.size():
				var rr := _row_rect(i)
				if rr.position.y >= lo - 4.0 and rr.end.y <= hi + 4.0 and rr.has_point(pos):
					_hover_row = i
					break
		VIEW_CARDS:
			var e: Dictionary = RunState.pending_rewards[_sel]
			var cands: Array = e.get("candidates", [])
			for i in cands.size():
				if _card_rect_in(e, i).grow(6.0).has_point(pos):
					_hover_card = i
					break
	if old_row != _hover_row or old_card != _hover_card \
			or not Mention.same(old_men, _hover_mention):
		_root.queue_redraw()


func _on_click(pos: Vector2) -> void:
	# R302：触屏没有 hover —— 点「提及」那两个字 = 钉住说明（再点别处收起）。
	for h: Dictionary in _mention_hits:
		if (h["rect"] as Rect2).has_point(pos):
			_mention_pin = h
			_hover_mention = {}
			_root.queue_redraw()
			return
	if not _mention_pin.is_empty():
		_mention_pin = {}
		_root.queue_redraw()
	match _view:
		VIEW_RELIC:
			if _btn_back_rect().has_point(pos):
				_back_to_list()
				return
			if _btn_claim_rect().has_point(pos):
				_claim_entry(_sel)
				return
			if _btn_skip_rect().has_point(pos):
				_skip_entry(_sel)
				return
		VIEW_CARDS:
			if _btn_cards_back_rect().has_point(pos):
				_back_to_list()
				return
			if _btn_cards_skip_rect().has_point(pos):
				_skip_entry(_sel)
				return
			var e: Dictionary = RunState.pending_rewards[_sel]
			if _settled(e):
				return
			# R342 火柴：刷新 → 重摇一组候选 + 次数 -1。已点选的那张要清掉
			# （`_pick_sel` 是**下标**，刷新后它指向的是另一张卡，留着必错）。
			if RunState.has_relic(RunState.MATCH_RELIC_ID) \
					and _btn_cards_reroll_rect().has_point(pos):
				if RunState.reroll_pending_cards(_sel):
					_pick_sel = -1
					_hover_card = -1
					_root.queue_redraw()
				return
			var cands: Array = e.get("candidates", [])
			# R167：**先看后拿**。点卡 = 选中并显示说明（触屏没悬停，旧版一点就直接入组、
			# 根本看不到卡面效果），再点「确认选择这张」才真的加入卡组。
			if _btn_confirm_rect().has_point(pos):
				if _pick_sel >= 0 and _pick_sel < cands.size():
					_pick_card(_sel, int(cands[_pick_sel]))
				return
			for i in cands.size():
				if _card_rect_in(e, i).grow(6.0).has_point(pos):
					# R294：点卡 = 同时把描述条切到这张。描述条的口径是
					# 「有悬停看悬停，没悬停看 _pick_sel」→ 悬停若停在上一张，
					# 点新卡会被它压住，描述不换（触屏尤其明显）。
					_hover_card = i
					_pick_sel = i
					_root.queue_redraw()
					return
		_:
			if _btn_done_rect().has_point(pos):
				close()
				return
			var any_relic := false
			for ee: Dictionary in RunState.pending_rewards:
				if str(ee.get("kind", "")) == "relic" and not _settled(ee):
					any_relic = true
					break
			if any_relic and _btn_claim_all_rect().has_point(pos):
				RunState.claim_all_relic_rewards()
				_root.queue_redraw()
				_route_if_waiting_pick()   # R216：一键领到鸭血也要立刻去选卡
				return
			for i in RunState.pending_rewards.size():
				if _row_rect(i).has_point(pos):
					_open_entry(i)
					return


func _draw_mention_tip() -> void:
	## R168：悬浮「提到的卡 / 道具」→ 画详情（与事件页**同一套**悬浮件：暗底 + 金边，
	## 卡牌用真实卡面、道具用名称 + 来源 + 完整说明）—— 全工程一个语言。
	## 位置：优先贴命中矩形**右侧**，放不下换左侧，最后夹进窗口。
	var ref: Dictionary = _hover_mention if not _hover_mention.is_empty() else _mention_pin
	if ref.is_empty():
		return
	var vs := _vs()
	var sz := Mention.tip_size(_font, ref)
	var anchor: Rect2 = ref.get("rect", Rect2())
	var x := anchor.end.x + 12.0
	if x + sz.x > vs.x - 8.0:
		x = anchor.position.x - sz.x - 12.0
	x = clampf(x, 8.0, maxf(8.0, vs.x - sz.x - 8.0))
	var y := clampf(anchor.position.y - 8.0, 8.0, maxf(8.0, vs.y - sz.y - 8.0))
	Mention.draw_tip(_root, _font, _font_bold, ref, Vector2(x, y))


func _max_scroll() -> float:
	var n := RunState.pending_rewards.size()
	var content := n * (ROW_H + ROW_GAP) - ROW_GAP
	var view := PANEL_H - HEAD_H - FOOT_H
	return maxf(0.0, content - view)


# ------------------------------------------------------------ 命令行演示

func _demo_start() -> void:
	## -- --r119：造一批「长描述道具 + 卡牌奖励」并直接弹窗（截图验证用）。
	## --r119relic / --r119cards：额外切到「道具详情」/「卡牌三选一」视图，方便逐屏核验。
	## --r119pick：卡牌三选一 + **已点选待确认**（R167 触屏「先看后拿」流程的出图核验）。
	## --r119match：卡牌三选一 + **持有火柴**（R342「刷新」按钮）——
	##   默认剩 3 次；再加 `--matchleft 0` 可看「三次用完、按钮置灰」的样子。
	## --r119chip：只铺奖励、**不弹窗** —— 核验常驻入口「✦ 待领奖励 N」的位置。
	var args := OS.get_cmdline_user_args()
	var mode := ""
	for a: String in args:
		if a.begins_with("--r119") or a.begins_with("--r342"):
			mode = a
			break
	# R323 出图：牛奶附魔演示 —— 不碰卡组，直接造两份演示数据。
	#   `-- --screenshot --milkdemo`            整段动画（约 1.2s 后落定）
	#   `-- --screenshot --milkdemo --milkpin 900` 把进度钉在 900ms（一张已贴、一张在下落）
	if "--milkdemo" in args:
		RunState.run_active = true
		var pin := -1.0
		for k2 in args.size():
			if args[k2] == "--milkpin" and k2 + 1 < args.size():
				pin = float(int(args[k2 + 1]))
		# 两种不同附魔：颜色不同，玩家才看得出「这两张贴的不是同一种」
		RunState.milk_anim = [
			{"card_id": 8003, "ench": "costdown"},
			{"card_id": 8002, "ench": "damage"},
		]
		var tm := Timer.new()
		tm.wait_time = 0.25
		tm.one_shot = true
		tm.timeout.connect(func():
			_open_enchant_view()
			_ench_pin = pin)
		add_child(tm)
		tm.start()
		return
	if mode == "":
		return
	var forced := -1
	for k in args.size():
		if args[k] == "--r119card" and k + 1 < args.size():
			forced = int(args[k + 1])
	RunState.run_active = true
	RunState.relics = []
	RunState.skipped_relics = []
	RunState.pending_relic_drop = -1
	RunState.pending_rewards = []
	RunState.queue_relic_reward(6013)   # 叠加态的鸭（描述最长的一件，专治「介绍太长」）
	RunState.queue_card_reward("boss")
	RunState.queue_relic_reward(6005)
	if forced > 0:
		# --r119card <id>：候选固定成同一张卡的三份 —— 复现「长描述 + 提及块」的排版
		for i in RunState.pending_rewards.size():
			var en: Dictionary = RunState.pending_rewards[i]
			if str(en.get("kind", "")) == "cards":
				en["candidates"] = [forced, forced, forced]
	# R342 出图：`--r342relic` = 奖励列表里只放两件新道具
	# （核验徽章色：采集刀传奇橙金 / 火柴一般黄；以及长描述在行内的换行）
	if mode == "--r342relic":
		RunState.pending_rewards = []
		RunState.queue_relic_reward(RunState.HARVEST_KNIFE_RELIC_ID)
		RunState.queue_relic_reward(RunState.MATCH_RELIC_ID)
	# R342 火柴：`--r119match` 造「持火柴」的三选一画面
	if mode == "--r119match":
		RunState.relics.append(RunState.MATCH_RELIC_ID)
		var left_n := RunState.MATCH_CHARGES
		for k3 in args.size():
			if args[k3] == "--matchleft" and k3 + 1 < args.size():
				left_n = int(args[k3 + 1])
		RunState.match_charge = maxi(0, left_n)
	if mode == "--r119chip":
		return
	var t := Timer.new()
	t.wait_time = 0.35
	t.one_shot = true
	t.timeout.connect(func():
		open()
		if mode == "--r119relic":
			_open_entry(0)
		elif mode == "--r119cards" or mode == "--r119match":
			for i in RunState.pending_rewards.size():
				if str((RunState.pending_rewards[i] as Dictionary).get("kind", "")) == "cards":
					_open_entry(i)
					_hover_card = 0
					break
		elif mode == "--r119pick":
			# R167：不设悬停，改用「已点选」—— 复现触屏上「点一下卡 → 看说明 → 待确认」的画面
			for i in RunState.pending_rewards.size():
				if str((RunState.pending_rewards[i] as Dictionary).get("kind", "")) == "cards":
					_open_entry(i)
					_hover_card = -1
					_pick_sel = 0
					break
		_root.queue_redraw())
	add_child(t)
	t.start()
