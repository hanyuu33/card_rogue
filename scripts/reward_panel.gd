class_name RewardPanel
extends CanvasLayer

const UiPop = preload("res://scripts/ui_pop.gd")
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
const CARDS_Y := 152.0
const DETAIL_STRIP_H := 152.0   # R155：悬停详情 = 三张卡正下方的横条（与卡组同一左右边界）

var _root: Control
var _btn: Button              # 常驻入口「✦ 待领奖励 N」
var _font: SystemFont
var _font_bold: SystemFont
var _btn_pos := Vector2(12, 40)
var _open := false
var _view := VIEW_LIST
var _sel := 0                 # 当前在看的条目下标（列表 → 详情带过去）
var _hover_row := -1
var _hover_card := -1
var _pick_sel := -1           # R167：卡牌三选一里「已点选、待确认」的那张（触屏没有悬停）
var _scroll := 0.0
var _cached_n := -1
var _replay_next_at := 0
var _repo_cards: CardRepo
var _repo_relics: RelicRepo


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


func blocks_replay() -> bool:
	## 回放时是否该等它：开着、且还有条目没处理 —— 这时不让外层（战斗结算）抢着点主按钮。
	return _open and RunState.pending_reward_count() > 0


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
	_refresh_btn()
	_root.queue_redraw()


func close() -> void:
	_open = false
	UiGate.pop(GATE_ID)
	_root.visible = false
	_view = VIEW_LIST
	_scroll = 0.0
	_pick_sel = -1
	_refresh_btn()


func _exit_tree() -> void:
	## R121：场景被切掉时也必须撤销登记 —— 否则「阻塞态」会漏进下一个场景，
	## 那边的道具悬停会莫名其妙全部失灵（而且再也恢复不了）。
	UiGate.pop(GATE_ID)


func _process(_delta: float) -> void:
	if _cached_n != RunState.pending_reward_count():
		_refresh_btn()
	if _open:
		_root.queue_redraw()
		_replay_tick()


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
	if str(e.get("kind", "")) == "relic":
		var r: RelicData = _repo_relics.get_relic(int(e.get("id", 0)))
		return r.relic_name if r != null else "未知道具"
	return "卡牌奖励（三选一）"


func _entry_tag(e: Dictionary) -> String:
	if str(e.get("kind", "")) == "relic":
		var r: RelicData = _repo_relics.get_relic(int(e.get("id", 0)))
		if r == null:
			return "奖励道具"
		return "%s · %s" % [r.source_label(), r.kind]
	return "卡牌奖励 · %s" % CardReward.type_label(str(e.get("type", "normal")))


func _entry_color(e: Dictionary) -> Color:
	if str(e.get("kind", "")) == "relic":
		var r: RelicData = _repo_relics.get_relic(int(e.get("id", 0)))
		if r != null:
			return r.source_color()
	return UiTheme.ACCENT_GOLD


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
	if not ReplayLog.playing:
		ReplayLog.ev("drop_claim")   # 录像：收下掉落道具
	RunState.claim_pending_reward(i)
	_view = VIEW_LIST
	_scroll = 0.0
	_root.queue_redraw()


func _skip_entry(i: int) -> void:
	if i < 0 or i >= RunState.pending_rewards.size():
		return
	if not ReplayLog.playing:
		ReplayLog.ev("drop_skip")   # 录像：放弃掉落道具
	RunState.skip_pending_reward(i)
	_view = VIEW_LIST
	_scroll = 0.0
	_root.queue_redraw()


func _pick_card(i: int, card_id: int) -> void:
	## 卡牌三选一：选中即入卡组 + 该条置灰。
	if i < 0 or i >= RunState.pending_rewards.size():
		return
	if not ReplayLog.playing:
		var cands: Array = (RunState.pending_rewards[i] as Dictionary).get("candidates", [])
		ReplayLog.ev("reward_pick", {"idx": cands.find(card_id), "id": card_id})
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
	if str(e.get("kind", "")) == "relic":
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
	match _view:
		VIEW_RELIC:
			_draw_relic()
		VIEW_CARDS:
			_draw_cards()
		_:
			_draw_list()


func _draw_panel_box(r: Rect2) -> void:
	_root.draw_rect(r, UiTheme.PAPER)
	_root.draw_rect(r, UiTheme.ACCENT_GOLD, false, 2.0)


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
		_root.draw_string(_font, Vector2(r.position.x + PAD, done.position.y + 25),
				"「领取全部道具」不碰卡牌奖励 —— 卡牌要自己挑一张",
				HORIZONTAL_ALIGNMENT_LEFT, 560, UiTheme.FS_CAPTION, UiTheme.INK_500)
	else:
		_root.draw_string(_font, Vector2(r.position.x + PAD, done.position.y + 25),
				"卡牌奖励需要点进去挑一张（不能一键领取）" if pend > 0 else "全部奖励都已处理，可以点「完成」",
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
			UiTheme.FS_SUBHEAD, UiTheme.INK_900)
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
			UiTheme.FS_HEADING, UiTheme.INK_900)
	_root.draw_rect(Rect2(r.position.x + PAD, r.position.y + HEAD_H, PANEL_W - PAD * 2.0,
			PANEL_H - HEAD_H - FOOT_H), Color("f0ede4"), true)
	_root.draw_string(_font, Vector2(r.position.x + PAD * 2.0, r.position.y + HEAD_H + 30),
			"%s　·　状态：%s" % [_entry_tag(e), _state_label(e)],
			HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - PAD * 4.0, UiTheme.FS_BODY, UiTheme.INK_600)
	var lines := _wrap(_relic_desc_text(e), PANEL_W - PAD * 4.0, UiTheme.FS_BODY)
	var y := r.position.y + HEAD_H + 68.0 - _scroll
	var bottom := r.position.y + PANEL_H - FOOT_H - 8.0
	for ln in lines:
		if y > bottom:
			break
		if y >= r.position.y + HEAD_H + 56.0:
			_root.draw_string(_font, Vector2(r.position.x + PAD * 2.0, y), ln,
					HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - PAD * 4.0,
					UiTheme.FS_BODY, Color("3a342a"))
		y += 24.0
	if lines.size() * 24.0 > (PANEL_H - HEAD_H - FOOT_H - 68.0):
		_root.draw_string(_font, Vector2(r.position.x + PANEL_W - PAD - 120,
				r.position.y + PANEL_H - FOOT_H - 8.0),
				"滚轮滚动", HORIZONTAL_ALIGNMENT_RIGHT, 120, UiTheme.FS_CAPTION, UiTheme.INK_500)
	# 底部动作
	var claim := _btn_claim_rect()
	var skip := _btn_skip_rect()
	if settled:
		_root.draw_string(_font, Vector2(r.position.x + PAD, claim.position.y + 25),
				"这条已经%s了（不可再操作）" % ("领取" if _state_label(e) == "已领取" else "放弃"),
				HORIZONTAL_ALIGNMENT_LEFT, 420, UiTheme.FS_BODY, UiTheme.INK_500)
	else:
		_root.draw_string(_font, Vector2(r.position.x + PAD, claim.position.y + 25),
				"「返回列表」不会丢掉它 —— 可以随时再点进来看、再领取。",
				HORIZONTAL_ALIGNMENT_LEFT, 480, UiTheme.FS_CAPTION, UiTheme.INK_500)
	_draw_btn(skip, "放弃这件", false, settled)
	_draw_btn(claim, "领取" if not settled else "已处理", true, settled)


func _draw_cards() -> void:
	if _sel >= RunState.pending_rewards.size():
		_back_to_list()
		return
	var e: Dictionary = RunState.pending_rewards[_sel]
	var settled := _settled(e)
	var vs := _vs()
	# 卡牌视图是**整屏**的（三张卡 + 右侧详情），所以先铺一层不透明底：
	# 否则会透出下面的战场 / 事件页，卡面与标题糊在背景里读不清（实测复核过）。
	_root.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.914, 0.906, 0.886), true)
	var total := 3 * CARD_W + 2 * CARD_GAP
	var x0 := (vs.x - total) / 2.0
	var cands: Array = e.get("candidates", [])
	_root.draw_string(_font_bold, Vector2(0, 44),
			"卡牌奖励 —— 点一张看说明，再确认加入卡组（%s）" % _entry_tag(e),
			HORIZONTAL_ALIGNMENT_CENTER, vs.x, UiTheme.FS_HEADING, Color("2f2a20"))
	_root.draw_string(_font, Vector2(0, 74),
			"「%s」" % ("已领取：选了其中一张" if settled else "看完随时可以点下面「返回列表」"),
			HORIZONTAL_ALIGNMENT_CENTER, vs.x, UiTheme.FS_BODY, UiTheme.INK_600)
	for i in cands.size():
		var card: CardData = _repo_cards.get_card(int(cands[i]))
		if card == null:
			continue
		var rr := Rect2(x0 + i * (CARD_W + CARD_GAP), CARDS_Y, CARD_W, CARD_H)
		var is_pick := i == _pick_sel and not settled
		var hov := (i == _hover_card or is_pick) and not settled
		if hov:
			_root.draw_rect(rr.grow(6.0), Color(1, 1, 1, 0.75), true)   # R155：亮边与点选判定同圈（原来大 4px）
			if is_pick:
				# R167：已点选（待确认）那张补一圈金边 —— 触屏没有悬停，得让「我选了哪张」看得见
				_root.draw_rect(rr.grow(9.0), UiTheme.ACCENT_GOLD, false, 3.0)
		CardFace.draw(_root, card, rr, card.health, false, false, _font, _font_bold)
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
	_draw_btn(_btn_back_rect(), "← 返回列表", false, false)
	_draw_btn(_btn_cards_skip_rect(), "放弃这组", false, settled)
	# R167：确认按钮（触屏必需 —— 没有悬停就得靠它「先看后拿」）
	var can_pick := (not settled) and _pick_sel >= 0 and _pick_sel < cands.size()
	_draw_btn(_btn_confirm_rect(), "确认选择这张", true, not can_pick)
	_root.draw_string(_font, Vector2(0, vs.y - 100),
			"点一张卡先看说明 → 再点「确认选择这张」加入卡组" if not settled else "这组已经处理过了",
			HORIZONTAL_ALIGNMENT_CENTER, vs.x, UiTheme.FS_CAPTION, UiTheme.INK_600)


func _draw_card_detail(cands: Array) -> void:
	## R155：详情从「钉在屏幕最右边缘」改成**三张卡正下方的横条**（与卡组同一左右边界）——
	## 旧版悬停最左一张卡时说明文字在最右侧，眼睛横跨整个屏幕（用户：文字和卡面对不上）。
	# R167：鼠标悬停优先；**触屏**没有悬停 → 用「已点选」的那张（点一下就能读到说明）。
	var idx := _hover_card if _hover_card >= 0 else _pick_sel
	if idx < 0 or idx >= cands.size():
		return
	var card: CardData = _repo_cards.get_card(int(cands[idx]))
	if card == null:
		return
	var vs := _vs()
	var total := 3 * CARD_W + 2 * CARD_GAP
	var x0 := (vs.x - total) / 2.0
	var box := Rect2(x0, CARDS_Y + CARD_H + 42.0, total,
			minf(DETAIL_STRIP_H, vs.y - (CARDS_Y + CARD_H + 42.0) - 92.0))
	# R164：白底 → **羊皮纸**（与卡面文字区同一种底，`UiTheme.PANEL_PAPER_BG`）。
	# 用户口径「白底上的字难认」—— 三选一这一屏统一到羊皮纸面上，卡面与详情是一套东西。
	_root.draw_rect(box, UiTheme.PANEL_PAPER_BG, true)
	_root.draw_rect(box, card.rarity_color(), false, 2.0)
	var pad := 14.0
	var col_w := 230.0
	var y := box.position.y + 27.0
	_root.draw_string(_font_bold, Vector2(box.position.x + pad, y),
			card.card_name, HORIZONTAL_ALIGNMENT_LEFT, col_w, UiTheme.FS_SUBHEAD, Color.BLACK)
	y += 23.0
	_root.draw_string(_font, Vector2(box.position.x + pad, y),
			"#%d  %s · %d 费 · %s" % [card.id, card.kind, card.cost, card.rarity_name()],
			HORIZONTAL_ALIGNMENT_LEFT, col_w, UiTheme.FS_CAPTION, UiTheme.INK_600)
	y += 19.0
	var stats := CardFace.stats_line(card)
	if stats != "":
		_root.draw_string(_font, Vector2(box.position.x + pad, y), stats,
				HORIZONTAL_ALIGNMENT_LEFT, col_w, UiTheme.FS_CAPTION, UiTheme.INK_600)
	# 右半：效果全文（折行）
	var ex := box.position.x + pad + col_w + 18.0
	var ew := box.end.x - pad - ex
	_root.draw_string(_font, Vector2(ex, box.position.y + 25.0), "效果",
			HORIZONTAL_ALIGNMENT_LEFT, ew, UiTheme.FS_CAPTION, Color("2a5a8a"))
	CardText.draw_wrapped(_root, _font, _font_bold, CardText.parse(card.effect_text),
			ex, box.position.y + 43.0, ew, 12, 17.0, Color("2a5a8a"))


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


func _btn_cards_skip_rect() -> Rect2:
	var vs := _vs()
	return Rect2(vs.x / 2.0 - 210.0, vs.y - 84.0, 140.0, 38.0)


func _btn_confirm_rect() -> Rect2:
	## R167：卡牌三选一的「确认选择这张」（放在「放弃这组」右侧）。
	var vs := _vs()
	return Rect2(vs.x / 2.0 + 20.0, vs.y - 84.0, 190.0, 38.0)


func _card_rect_in(e: Dictionary, i: int) -> Rect2:
	var vs := _vs()
	var total := 3 * CARD_W + 2 * CARD_GAP
	var x0 := (vs.x - total) / 2.0
	return Rect2(x0 + i * (CARD_W + CARD_GAP), CARDS_Y, CARD_W, CARD_H)


# ------------------------------------------------------------ 输入

func _on_input(event: InputEvent) -> void:
	if not _open:
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
	_hover_row = -1
	_hover_card = -1
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
	if old_row != _hover_row or old_card != _hover_card:
		_root.queue_redraw()


func _on_click(pos: Vector2) -> void:
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
			if _btn_back_rect().has_point(pos):
				_back_to_list()
				return
			if _btn_cards_skip_rect().has_point(pos):
				_skip_entry(_sel)
				return
			var e: Dictionary = RunState.pending_rewards[_sel]
			if _settled(e):
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
				if not ReplayLog.playing:
					for _i in RunState.pending_rewards.size():
						var ee2: Dictionary = RunState.pending_rewards[_i]
						if str(ee2.get("kind", "")) == "relic" and not _settled(ee2):
							ReplayLog.ev("drop_claim")
				RunState.claim_all_relic_rewards()
				_root.queue_redraw()
				return
			for i in RunState.pending_rewards.size():
				if _row_rect(i).has_point(pos):
					_open_entry(i)
					return


func _max_scroll() -> float:
	var n := RunState.pending_rewards.size()
	var content := n * (ROW_H + ROW_GAP) - ROW_GAP
	var view := PANEL_H - HEAD_H - FOOT_H
	return maxf(0.0, content - view)


# ------------------------------------------------------------ 回放

func _replay_tick() -> void:
	## 回放驱动（R46 的奖励分支搬到这里）：按录像执行奖励决策。
	ReplayLog.skip_info()   # R167：先跳掉无消费方的信息条目（battle_end / run_end）
	## ⚠️ 老录像里的 `drop_later`（先浏览卡牌奖励再回来决定）在新界面里没有对应动作 ——
	##    悬浮窗本来就能随时进出，所以直接消费掉、什么都不做。
	if not ReplayLog.playing:
		return
	if Time.get_ticks_msec() < _replay_next_at:
		return
	var e := ReplayLog.peek()
	if e.is_empty():
		return
	match str(e.get("k", "")):
		"drop_claim":
			var i := _first_pending("relic")
			if i >= 0:
				ReplayLog.advance()
				_replay_next_at = Time.get_ticks_msec() + 700
				_claim_entry(i)
		"drop_skip":
			var i2 := _first_pending("relic")
			if i2 >= 0:
				ReplayLog.advance()
				_replay_next_at = Time.get_ticks_msec() + 700
				_skip_entry(i2)
		"drop_later":
			ReplayLog.advance()
		"reward_pick":
			var cid := int(e.get("id", 0))
			var ic := _cards_entry_with(cid)
			if ic >= 0:
				ReplayLog.advance()
				_replay_next_at = Time.get_ticks_msec() + 700
				_pick_card(ic, cid)
		"reward_skip":
			var ic2 := _first_pending("cards")
			if ic2 >= 0:
				ReplayLog.advance()
				_replay_next_at = Time.get_ticks_msec() + 700
				_skip_entry(ic2)
		_:
			pass


# ------------------------------------------------------------ 命令行演示

func _demo_start() -> void:
	## -- --r119：造一批「长描述道具 + 卡牌奖励」并直接弹窗（截图验证用）。
	## --r119relic / --r119cards：额外切到「道具详情」/「卡牌三选一」视图，方便逐屏核验。
	## --r119pick：卡牌三选一 + **已点选待确认**（R167 触屏「先看后拿」流程的出图核验）。
	## --r119chip：只铺奖励、**不弹窗** —— 核验常驻入口「✦ 待领奖励 N」的位置。
	var args := OS.get_cmdline_user_args()
	var mode := ""
	for a: String in args:
		if a.begins_with("--r119"):
			mode = a
			break
	if mode == "":
		return
	RunState.run_active = true
	RunState.relics = []
	RunState.skipped_relics = []
	RunState.pending_relic_drop = -1
	RunState.pending_rewards = []
	RunState.queue_relic_reward(6013)   # 叠加态的鸭（描述最长的一件，专治「介绍太长」）
	RunState.queue_card_reward("boss")
	RunState.queue_relic_reward(6005)
	if mode == "--r119chip":
		return
	var t := Timer.new()
	t.wait_time = 0.35
	t.one_shot = true
	t.timeout.connect(func():
		open()
		if mode == "--r119relic":
			_open_entry(0)
		elif mode == "--r119cards":
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
