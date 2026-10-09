extends Control
## 卡牌奖励（肉鸽模式 · 演示界面）—— 关卡过关后弹出：
## 给 3 张按稀有度权重抽出的候选卡，玩家点 1 张收下，或点「跳过奖励」。
##
## 奖励类型与稀有度概率构成见 CardReward：normal（普通过关）/ boss（Boss 过关）。
## 未来接入肉鸽流程时：设置 reward_type → change_scene 进入本场景，
## 连接 reward_chosen / reward_skipped 信号即可，不需要改本界面的内部逻辑。

const UiTheme = preload("res://scripts/ui_theme.gd")

signal reward_chosen(card: CardData)
signal reward_skipped

const CARD_W := 216.0
const CARD_H := 260.0
const GAP := 44.0
const AREA_Y := 150.0
const LIFT := 10.0

# 悬停详情面板（窗口右侧，与三张候选卡同一水平带）
const DETAIL_X := 1014.0
const DETAIL_Y := 150.0
const DETAIL_W := 250.0
const DETAIL_H := 286.0

var reward_type := "normal"
var repo: CardRepo
var _cards: Array[CardData] = []     # 当前三张候选
var _hover := -1                     # 悬停的候选下标
var _decided := false                # 已选择或已跳过
var _chosen: CardData = null         # 选中的卡（跳过时为 null）
var _skipped := false
var _font: SystemFont
var _font_bold: SystemFont
var _granted_relic: RelicData = null  # 已收下的掉落道具（横幅展示用）
var _pending_relic: RelicData = null  # 待决定的掉落道具（先弹出，可跳过 / 稍后再决定）
var _relic_decided := false           # 掉落道具是否已决定（收下或跳过）
var _relic_panel: Control = null      # 掉落道具弹窗
var _relic_btn: Button = null         # 「待决定道具」重新打开按钮

@onready var title_label: Label = $TopBar/TitleLabel
@onready var back_btn: Button = $TopBar/BackBtn
@onready var card_area: Control = $CardArea
@onready var prob_label: Label = $ProbLabel
@onready var result_label: Label = $ResultLabel
@onready var skip_btn: Button = $Bottom/SkipBtn
@onready var normal_btn: Button = $Bottom/NormalBtn
@onready var boss_btn: Button = $Bottom/BossBtn
@onready var continue_btn: Button = $Bottom/ContinueBtn


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	repo = CardRepo.load_json()
	# 牌库任何时候都可以查看（无论在哪个界面）；返回按钮占着右上 → 按钮往左挪
	DeckViewer.attach(self, Vector2(1000, 6))
	RelicViewer.attach(self, Vector2(894, 6))
	# 命令行 -- --reward boss：以 Boss 过关奖励打开（演示/验证用）
	# --arcane：以「奥秘之泉 · 喝下泉水」的样子打开（只给效果 / 技能，截图验证用）
	var args := OS.get_cmdline_user_args()
	if "--arcane" in args:
		RunState.run_active = true
		RunState.reward_context = "event"
		RunState.reward_type = "normal"
		RunState.reward_kinds = ["效果", "技能"]
	# 肉鸽 run：奖励类型由流程设定（普通/精英战斗 = normal，Boss = boss，
	# 事件 = normal）；隐藏演示用的类型切换按钮
	if RunState.run_active and RunState.reward_context != "":
		reward_type = RunState.reward_type
		normal_btn.visible = false
		boss_btn.visible = false
	if "--reward" in args:
		var i := args.find("--reward")
		if i >= 0 and i + 1 < args.size() and args[i + 1] in CardReward.TYPES:
			reward_type = args[i + 1]
	skip_btn.pressed.connect(func():
		if not ReplayLog.playing:
			_on_skip())
	back_btn.pressed.connect(func():
		if not ReplayLog.playing:
			_on_continue())
	card_area.draw.connect(_on_cards_draw)
	card_area.gui_input.connect(_on_area_input)
	normal_btn.pressed.connect(func(): _switch_type("normal"))
	boss_btn.pressed.connect(func(): _switch_type("boss"))
	continue_btn.pressed.connect(func():
		if not ReplayLog.playing:
			_on_continue())
	# -- --relicdrop：演示掉落展示（截图验证用）
	if "--relicdrop" in args:
		var ri := args.find("--relicdrop")
		RunState.pending_relic_drop = 6005
		if ri >= 0 and ri + 1 < args.size() and args[ri + 1].is_valid_int():
			RunState.pending_relic_drop = int(args[ri + 1])
	# 精英掉落道具：先弹出道具决定弹窗（可收下 / 跳过 / 先浏览卡牌奖励再回来决定），
	# 不再进场景即自动发放
	if RunState.pending_relic_drop > 0:
		var relic := RelicRepo.load_json().get_relic(RunState.pending_relic_drop)
		if relic != null:
			_pending_relic = relic
			_build_relic_panel()
	_roll()
	# -- --hover N：强制悬停第 N 张候选（演示/验证详情面板用）
	if "--hover" in args:
		var hi := args.find("--hover")
		if hi >= 0 and hi + 1 < args.size():
			_hover = clampi(int(args[hi + 1]), 0, _cards.size() - 1)
	# --screenshot：自动截图退出（视觉验证用）
	if "--screenshot" in args:
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_reward.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	# 回放模式：自动执行奖励决策（R46）
	if ReplayLog.playing:
		var rt := Timer.new()
		rt.wait_time = 0.5
		rt.timeout.connect(_replay_tick)
		add_child(rt)
		rt.start()


func _roll() -> void:
	var roll_rng := RunState.run_rng if RunState.run_active else null
	_cards = CardReward.roll(repo, reward_type, CardReward.CHOICES, roll_rng,
			RunState.reward_kinds)
	_hover = -1
	_decided = false
	_chosen = null
	_skipped = false
	_refresh()


func _switch_type(t: String) -> void:
	if _decided or t == reward_type:
		return
	reward_type = t
	_roll()


func _refresh() -> void:
	title_label.text = "卡牌奖励 — %s" % CardReward.type_label(reward_type)
	if not RunState.reward_kinds.is_empty():
		# 事件限定卡类（如「奥秘之泉 · 喝下泉水」只在 效果 / 技能 里抽）
		title_label.text += "（限 %s）" % "、".join(RunState.reward_kinds)
	var w: Array = CardReward.TYPE_WEIGHTS[reward_type]
	prob_label.text = "出现概率：普通 %d%% · 稀有 %d%% · 史诗 %d%%   （三张互不重名，选 1 张或跳过）" \
			% [roundf(float(w[0]) * 100), roundf(float(w[1]) * 100), roundf(float(w[2]) * 100)]
	if not _decided:
		result_label.text = ""
		if _cards.is_empty():
			result_label.text = "暂无可获得的卡牌（奖励卡池中还没有普通/稀有/史诗卡）"
			result_label.add_theme_color_override("font_color", Color("888888"))
		continue_btn.visible = false
		skip_btn.disabled = false
		normal_btn.disabled = false
		boss_btn.disabled = false
	card_area.queue_redraw()


# ------------------------------------------------------------ 绘制

func _card_rect(i: int, lift := false) -> Rect2:
	var total := 3 * CARD_W + 2 * GAP
	var x0 := (card_area.size.x - total) / 2.0
	var y := AREA_Y - (LIFT if lift else 0.0)
	return Rect2(x0 + i * (CARD_W + GAP), y, CARD_W, CARD_H)


func _on_cards_draw() -> void:
	# 卡片背板 + 悬停垫高
	for i in _cards.size():
		var hovered := i == _hover and not _decided
		var rect := _card_rect(i, hovered)
		if hovered:
			card_area.draw_rect(rect.grow(10.0), Color(1, 1, 1, 0.75))
		CardFace.draw(card_area, _cards[i], rect, _cards[i].health, false, false,
				_font, _font_bold)
		# 卡下方稀有度文字（与边框同色）
		var rc: Color = _cards[i].rarity_color()
		var lw := 60.0
		card_area.draw_string(_font_bold, rect.position +
				Vector2(CARD_W / 2.0 - lw / 2.0, CARD_H + 26), _cards[i].rarity_name(),
				HORIZONTAL_ALIGNMENT_CENTER, lw, UiTheme.FS_BODY, rc)
		# 已决定后：未选中的卡蒙一层白，突出结果
		if _decided and not (_chosen == _cards[i] and not _skipped):
			card_area.draw_rect(rect, Color(1, 1, 1, 0.62), true)
	# 选中卡的加粗金框
	if _decided and not _skipped and _chosen != null:
		var idx := _cards.find(_chosen)
		if idx >= 0:
			card_area.draw_rect(_card_rect(idx).grow(4.0), Color("c8951c"), false, 3.0)
	# 悬停候选卡：右侧显示完整详情（卡面放不下效果文本）
	_draw_hover_detail()
	# 精英/Boss 掉落道具横幅（已自动发放，只做展示）
	_draw_granted_banner()


func _draw_hover_detail() -> void:
	if _decided or _hover < 0 or _hover >= _cards.size():
		return
	var card: CardData = _cards[_hover]
	var box := Rect2(DETAIL_X, DETAIL_Y, DETAIL_W, DETAIL_H)
	card_area.draw_rect(box, Color(1, 1, 1, 0.97))
	card_area.draw_rect(box, card.rarity_color(), false, 2.0)
	var pad := 12.0
	var inner_w := DETAIL_W - pad * 2.0
	var y := box.position.y + 24.0
	# 名称 + 编号
	card_area.draw_string(_font_bold, Vector2(box.position.x + pad, y),
			"%s" % card.card_name, HORIZONTAL_ALIGNMENT_LEFT, inner_w, UiTheme.FS_BODY, Color.BLACK)
	y += 20.0
	card_area.draw_string(_font, Vector2(box.position.x + pad, y),
			"#%d  %s · %d 费 · %s" % [card.id, card.kind, card.cost, card.rarity_name()],
			HORIZONTAL_ALIGNMENT_LEFT, inner_w, UiTheme.FS_CAPTION, Color("555555"))
	y += 18.0
	var stats := CardFace.stats_line(card)
	if stats != "":
		card_area.draw_string(_font, Vector2(box.position.x + pad, y), stats,
				HORIZONTAL_ALIGNMENT_LEFT, inner_w, UiTheme.FS_CAPTION, Color("444444"))
		y += 18.0
	# 效果文本（自动换行 + R106：Markdown 富文本，隐藏「（…）」补注）
	y += 4.0
	card_area.draw_string(_font, Vector2(box.position.x + pad, y), "效果",
			HORIZONTAL_ALIGNMENT_LEFT, inner_w, UiTheme.FS_CAPTION, Color("2a5a8a"))
	y += 17.0
	CardText.draw_wrapped(card_area, _font, _font_bold,
			CardText.parse(card.effect_text), box.position.x + pad, y, inner_w, 12,
			17.0, Color("2a5a8a"))


func _wrap_text(text: String, max_w: float, size: int) -> Array[String]:
	## 中文友好的字符级换行（共享实现见 CardFace.wrap_text）。
	return CardFace.wrap_text(_font, text, max_w, size)


func _on_area_input(event: InputEvent) -> void:
	if _decided or ReplayLog.playing:
		return
	if event is InputEventMouseMotion:
		var idx := _index_at(event.position)
		if idx != _hover:
			_hover = idx
			card_area.queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var idx := _index_at(event.position)
		if idx >= 0:
			_choose(_cards[idx])


func _index_at(pos: Vector2) -> int:
	for i in _cards.size():
		if _card_rect(i).grow(6.0).has_point(pos):
			return i
	return -1


# ------------------------------------------------------------ 决策

func _choose(card: CardData) -> void:
	if _decided:
		return
	ReplayLog.ev("reward_pick", {"idx": _cards.find(card), "id": card.id})   # 录像
	_decided = true
	_chosen = card
	_skipped = false
	if RunState.run_active and RunState.reward_context != "":
		RunState.add_card(card.id)   # 收下的卡加入肉鸽卡组
	result_label.text = "已收下「%s」（%s）" % [card.card_name, card.rarity_name()] \
			if not (RunState.run_active and RunState.reward_context != "") \
			else "「%s」已加入卡组（%s）" % [card.card_name, card.rarity_name()]
	result_label.add_theme_color_override("font_color", card.rarity_color())
	_after_decide()
	reward_chosen.emit(card)


func _on_skip() -> void:
	if _decided:
		return
	ReplayLog.ev("reward_skip")   # 录像
	_decided = true
	_chosen = null
	_skipped = true
	result_label.text = "已跳过本次奖励"
	result_label.add_theme_color_override("font_color", Color("666666"))
	_after_decide()
	reward_skipped.emit()


func _after_decide() -> void:
	continue_btn.visible = true
	skip_btn.disabled = true
	normal_btn.disabled = true
	boss_btn.disabled = true
	_hover = -1
	card_area.queue_redraw()


# ------------------------------------------------------------ 掉落道具弹窗

func _build_relic_panel() -> void:
	## 掉落道具弹窗：模态覆盖，先进道具决定（收下 / 跳过 / 先浏览卡牌奖励再回来）。
	_relic_panel = Control.new()
	_relic_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_relic_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_relic_panel)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_relic_panel.add_child(shade)

	var W := 480.0
	# 描述折行 → 弹窗高度自适应（长描述如「叠加态的鸭」不再溢出文本框）
	var desc_txt := "%s\n（%s · 不收下则放弃本次掉落）" % [
			_pending_relic.desc, _pending_relic.source_label()]
	var desc_lines := _wrap_text(desc_txt, W - 40.0, 13)
	var desc_h := desc_lines.size() * 19.0 + 10.0
	var H := 80.0 + desc_h + 8.0 + 36.0 + 10.0 + 72.0
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.985, 0.94)
	sb.border_color = Color("c8951c")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -W / 2.0
	panel.offset_right = W / 2.0
	panel.offset_top = -H / 2.0 - 40.0
	panel.offset_bottom = H / 2.0 - 40.0
	_relic_panel.add_child(panel)

	var title := Label.new()
	title.text = "✦ 掉落道具"
	title.position = Vector2(0, 14)
	title.size = Vector2(W, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UiTheme.FS_BODY)
	title.add_theme_color_override("font_color", Color("7a5a10"))
	panel.add_child(title)

	var name_lbl := Label.new()
	name_lbl.text = "「%s」" % _pending_relic.relic_name
	name_lbl.position = Vector2(0, 48)
	name_lbl.size = Vector2(W, 24)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", UiTheme.FS_BODY)
	name_lbl.add_theme_color_override("font_color", Color("3a3010"))
	panel.add_child(name_lbl)

	var desc := Label.new()
	# 预折行后按 \n 拼接：Label 的 autowrap 在先设 size 时会被最小宽度钳制，
	# 长描述（叠加态的鸭）会横向溢出 → 不依赖自动换行
	desc.text = "\n".join(desc_lines)
	desc.position = Vector2(20, 80)
	desc.size = Vector2(W - 40, desc_h)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", UiTheme.FS_LABEL)
	desc.add_theme_color_override("font_color", Color("5a4c28"))
	panel.add_child(desc)

	var hint := Label.new()
	hint.text = "也可以先「浏览卡牌奖励」，随时点下方按钮回来决定。"
	hint.position = Vector2(20, 80.0 + desc_h + 8.0)
	hint.size = Vector2(W - 40, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", UiTheme.FS_CAPTION)
	hint.add_theme_color_override("font_color", Color("8a7a50"))
	panel.add_child(hint)

	var hbox := HBoxContainer.new()
	hbox.anchor_top = 1.0
	hbox.anchor_bottom = 1.0
	hbox.anchor_left = 0.0
	hbox.anchor_right = 1.0
	hbox.offset_top = -56.0
	hbox.offset_bottom = -16.0
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	var take := Button.new()
	take.text = "收下道具"
	take.custom_minimum_size = Vector2(120, 40)
	take.pressed.connect(_on_relic_take)
	hbox.add_child(take)

	var skip := Button.new()
	skip.text = "跳过道具"
	skip.custom_minimum_size = Vector2(120, 40)
	skip.pressed.connect(_on_relic_skip)
	hbox.add_child(skip)

	var later := Button.new()
	later.text = "先浏览卡牌奖励"
	later.custom_minimum_size = Vector2(150, 40)
	later.pressed.connect(_on_relic_later)
	hbox.add_child(later)

	# 「待决定道具」常驻按钮：关闭弹窗后可随时重新打开（已决定则不显示）
	_relic_btn = Button.new()
	_relic_btn.text = "✦ 待决定道具：「%s」（点击决定收下或跳过）" % _pending_relic.relic_name
	_relic_btn.anchor_left = 0.5
	_relic_btn.anchor_right = 0.5
	_relic_btn.anchor_top = 1.0
	_relic_btn.anchor_bottom = 1.0
	_relic_btn.offset_left = -220.0
	_relic_btn.offset_right = 220.0
	_relic_btn.offset_top = -186.0
	_relic_btn.offset_bottom = -154.0
	_relic_btn.visible = false
	_relic_btn.pressed.connect(func(): _relic_panel.visible = true)
	add_child(_relic_btn)


func _on_relic_take() -> void:
	## 收下掉落道具：入道具栏，横幅展示。
	if _relic_decided or _pending_relic == null:
		return
	ReplayLog.ev("drop_claim")   # 录像
	RunState.claim_relic_drop()
	_relic_decided = true
	_granted_relic = _pending_relic
	_close_relic_panel()
	result_label.text = "获得道具「%s」（已加入道具栏）" % _granted_relic.relic_name
	result_label.add_theme_color_override("font_color", Color("a8821c"))


func _on_relic_skip() -> void:
	## 跳过掉落道具：放弃本次掉落（登记后本局后续不再随机出来）。
	if _relic_decided or _pending_relic == null:
		return
	ReplayLog.ev("drop_skip")   # 录像
	RunState.skip_relic_drop()
	_relic_decided = true
	_close_relic_panel()
	result_label.text = "已放弃道具「%s」（本局不会再出现）" % _pending_relic.relic_name
	result_label.add_theme_color_override("font_color", Color("666666"))


func _on_relic_later() -> void:
	## 暂不决定：关闭弹窗回去浏览卡牌奖励，「待决定道具」按钮保留入口。
	ReplayLog.ev("drop_later")   # 录像
	_relic_panel.visible = false
	_relic_btn.visible = not _relic_decided


func _close_relic_panel() -> void:
	_relic_panel.visible = false
	_relic_btn.visible = false
	card_area.queue_redraw()   # 刷新横幅（收下后展示「已加入道具栏」）


func _draw_granted_banner() -> void:
	## 掉落道具横幅：玩家在弹窗中收下后展示（已入道具栏）。
	if _granted_relic == null:
		return
	var w := 560.0
	# 描述折行 → 横幅高度自适应（长描述不再画出框外）
	var dlines := _wrap_text(_granted_relic.desc, w - 28.0, 12)
	var h := 30.0 + dlines.size() * 16.0 + 10.0
	var rect := Rect2((card_area.size.x - w) / 2.0, 530.0, w, h)
	card_area.draw_rect(rect, Color(1.0, 0.965, 0.85), true)
	card_area.draw_rect(rect, Color("c8951c"), false, 2.0)
	card_area.draw_string(_font_bold,
			Vector2(rect.position.x + 14, rect.position.y + 22),
			"✦ 掉落道具：获得「%s」（已加入道具栏）" % _granted_relic.relic_name,
			HORIZONTAL_ALIGNMENT_LEFT, w - 28, UiTheme.FS_BODY, Color("7a5a10"))
	for di in dlines.size():
		card_area.draw_string(_font,
				Vector2(rect.position.x + 14, rect.position.y + 42.0 + di * 16.0),
				dlines[di], HORIZONTAL_ALIGNMENT_LEFT, w - 28, UiTheme.FS_CAPTION,
				Color("6a5a30"))


func _on_continue() -> void:
	## run 模式：收下的卡已加入卡组 → 标记节点完成 → 回冒险地图；演示流程：回标题。
	if RunState.run_active:
		if _pending_relic != null and not _relic_decided:
			RunState.pending_relic_drop = -1   # 一直没决定道具 → 离开视为放弃掉落
		RunState.complete_current()
		RunState.reward_context = ""
		RunState.reward_kinds = []          # 事件限定的卡类只对这一次奖励生效
		RunState.pending_relic_drop = -1   # 兜底清理
		get_tree().change_scene_to_file("res://scenes/map.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/title.tscn")


func _replay_tick() -> void:
	## 回放模式：按录像执行奖励/掉落决策；全部决定后自动继续（map 条目由地图消费）。
	if not ReplayLog.playing:
		return
	var e := ReplayLog.peek()
	if e.is_empty():
		return
	match str(e.get("k", "")):
		"drop_claim":
			if _pending_relic != null and not _relic_decided:
				ReplayLog.advance()
				_on_relic_take()
		"drop_skip":
			if _pending_relic != null and not _relic_decided:
				ReplayLog.advance()
				_on_relic_skip()
		"drop_later":
			if _pending_relic != null and not _relic_decided:
				ReplayLog.advance()
				_on_relic_later()
		"reward_pick":
			if not _decided:
				var id := int(e.get("id", 0))
				var idx := -1
				for i in _cards.size():
					if _cards[i].id == id:
						idx = i
						break
				if idx >= 0:
					ReplayLog.advance()
					_choose(_cards[idx])
		"reward_skip":
			if not _decided:
				ReplayLog.advance()
				_on_skip()
		"map":
			# 本场景决策已全部完成（或从未有待决策）→ 自动继续。
			# 未决定的掉落按原语义视为放弃（_on_continue 兜底清理）。
			if _decided and (_pending_relic == null or _relic_decided):
				_on_continue()
			elif _pending_relic != null and not _relic_decided and not _decided:
				_on_continue()
