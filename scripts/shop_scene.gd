extends Control
## 神秘商店（R181）：金币消费的三行商品。
##
## 第一行：3 张随机本职业奖励卡（价格按稀有度：普通 25 / 稀有 50 / 史诗 100）。
## 第二行：3 个随机附魔（从 4 种里抽 3 种不重复）：
##   * 费用 -1（只可费用 > 1 且非 X 费卡）价 50
##   * 伤害 +10（只可原本造成伤害的卡，即 power > 0）价 60
##   * 次元（盟友/工事，必须无次元、非效果卡；+2 力 +10 血）价 50
##   * 保存（回合结束手牌不丢弃，做成字段）价 60
## 第三行：固定 3 项：删一张卡 50 / +5 最大生命（并回血）50 / 买一块巧克力 60。
##
## 附魔购买流程：选附魔 → 选卡（高亮可选卡）→ 成功入卡组，无候选卡则提示。
## 每件商品每次商店只能买一次，售罄后置灰。
## 金币不足 / 无可选卡时给出提示，不扣钱。

const UiTheme = preload("res://scripts/ui_theme.gd")

const W := 1280.0
const H := 720.0

# 附魔定义（id → 元数据）
const ENCHANT_COSTDOWN := "costdown"
const ENCHANT_DAMAGE := "damage"
const ENCHANT_DIMENSION := "dimension"
const ENCHANT_SAVE := "save"

const ENCHANTS := [
	{"id": "costdown", "name": "费用 -1", "desc": "每次战斗初次使用费用 -1（只能选费用 > 1 且非 X 费的卡）",
		"price": 50, "icon": "shop_icon_costdown"},
	{"id": "damage", "name": "伤害 +10", "desc": "力量 +10（只能选原本就造成伤害的卡）",
		"price": 60, "icon": "shop_icon_damage"},
	{"id": "dimension", "name": "次元", "desc": "赋予「次元」并 +2 力 +10 血（盟友/工事，须无次元、非效果卡；离场消失）",
		"price": 50, "icon": "shop_icon_dimension"},
	{"id": "save", "name": "保存", "desc": "赋予「保存」——回合结束时手牌这张不丢弃",
		"price": 60, "icon": "shop_icon_save"},
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
var _hover := -1               # 悬停的商品下标（按全局编号）
var _hover_enchant_card := -1  # 附魔/删除选卡时悬停的卡下标

# 卡组展示（附魔选卡时）
var _deck_cards: Array = []    # [{id, name, card}]

var _hint := ""
var _hint_t := 0.0

# 全局商品编号：0~2 第一行，3~5 第二行，6~8 第三行
const ROW1_BASE := 0
const ROW2_BASE := 3
const ROW3_BASE := 6


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	_repo = CardRepo.load_json()
	_setup_shop()
	# 演示参数：--shop 造一个 run + 金币（截图核验商店界面）。
	var args := OS.get_cmdline_user_args()
	if "--shop" in args:
		if not RunState.run_active:
			RunState.run_active = true
			RunState.start_run([], GameLayers.LAYER_DEFAULT)
		RunState.gold = 100
		RunState.pending_node = {"type": "shop"}
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
	queue_redraw()


func _setup_shop() -> void:
	# 第一行：3 张随机本职业奖励卡（不重复名）
	var rolled := CardReward.roll(_repo, "normal", 3)
	_row1 = []
	for c: CardData in rolled:
		_row1.append({"card": c, "sold": false})
	# 第二行：从 4 种附魔随机抽 3 种不重复
	var pool := ENCHANTS.duplicate()
	pool.shuffle()
	_row2 = []
	for i in 3:
		_row2.append({"ench": pool[i], "sold": false})
	# 第三行：固定 3 项
	_row3 = [
		{"key": "delete", "name": "删除一张卡", "desc": "从卡组里删掉一张卡", "price": 50,
			"icon": "shop_icon_remove", "sold": false},
		{"key": "maxhp", "name": "+5 最大生命", "desc": "最大生命 +5，并回复 5 点生命", "price": 50,
			"icon": "shop_icon_maxhp", "sold": false},
		{"key": "choco", "name": "巧克力", "desc": "获得一块巧克力（行动力 +1）", "price": 60,
			"icon": "chocolate", "sold": false},
	]


func _process(delta: float) -> void:
	if _hint_t > 0.0:
		_hint_t -= delta
	queue_redraw()


func _draw() -> void:
	# 背景
	var bg: Texture2D = UiAssets.get_tex("bg_shop")
	if bg != null:
		draw_texture_rect(bg, Rect2(Vector2.ZERO, Vector2(W, H)), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color("1a1c22"))
	# 老板立绘（右侧）
	var keeper: Texture2D = UiAssets.get_tex("shop_keeper")
	if keeper != null:
		var kr := Rect2(W - 420, 140, 400, 480)
		draw_texture_rect(keeper, _fit_cover(keeper, kr), false)
	# 顶部标题
	draw_string(_font_bold, Vector2(0, 52), "神 秘 商 店",
			HORIZONTAL_ALIGNMENT_CENTER, W, UiTheme.FS_HEADING, Color("ffd75a"))
	_draw_gold()
	_draw_row1()
	_draw_row2()
	_draw_row3()
	_draw_pick_overlay()
	_draw_leave()
	_draw_hint()


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


func _draw_gold() -> void:
	var icon: Texture2D = UiAssets.get_tex("icon_gold")
	var x := 40.0
	if icon != null:
		draw_texture_rect(icon, Rect2(x, 40, 28, 28), false)
		x += 34
	draw_string(_font_bold, Vector2(x, 62), "金币 %d" % RunState.gold,
			HORIZONTAL_ALIGNMENT_LEFT, 160, UiTheme.FS_SUBHEAD, Color("ffd75a"))


func _card_price(card: CardData) -> int:
	match card.rarity:
		0: return 25
		1: return 50
		2: return 100
	return 25


func _draw_row1() -> void:
	var y := 96.0
	var cw := 150.0
	var ch := 190.0
	var gap := 24.0
	var x0 := 40.0
	for i in _row1.size():
		var e: Dictionary = _row1[i]
		var card: CardData = e["card"]
		var sold: bool = e["sold"]
		var rr := Rect2(x0 + i * (cw + gap), y, cw, ch)
		var hovered := not sold and _hover == ROW1_BASE + i and _enchanting < 0
		CardFace.draw(self, card, rr, card.health, hovered, false, _font, _font_bold)
		# 价格标签
		var price := _card_price(card)
		_draw_price(rr, price, sold)
		if sold:
			draw_rect(rr, Color(0, 0, 0, 0.55), true)
			draw_string(_font_bold, rr.position + Vector2(0, rr.size.y / 2),
					"已售罄", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, UiTheme.FS_SUBHEAD,
					Color("ff9a9a"))


func _draw_row2() -> void:
	var y := 300.0
	var bw := 240.0
	var bh := 96.0
	var gap := 20.0
	var x0 := 40.0
	for i in _row2.size():
		var e: Dictionary = _row2[i]
		var ench: Dictionary = e["ench"]
		var sold: bool = e["sold"]
		var rr := Rect2(x0 + i * (bw + gap), y, bw, bh)
		var hovered := not sold and _hover == ROW2_BASE + i and _enchanting < 0
		var enchanting := not sold and _enchanting == i
		var bg := Color("241f1a") if hovered or enchanting else Color("1e1a16")
		draw_rect(rr, bg, true)
		draw_rect(rr, Color("c8951c") if (hovered or enchanting) else Color("6b5a3a"),
				false, 2.0)
		var icon: Texture2D = UiAssets.get_tex(str(ench["icon"]))
		if icon != null:
			draw_texture_rect(icon, Rect2(rr.position + Vector2(10, 10), Vector2(40, 40)), false)
		draw_string(_font_bold, rr.position + Vector2(58, 30), str(ench["name"]),
				HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 120, UiTheme.FS_SUBHEAD, Color("ece7db"))
		draw_string(_font, rr.position + Vector2(58, 52), str(ench["desc"]),
				HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 68, 11, Color("b8b2a6"))
		draw_string(_font_bold, rr.position + Vector2(rr.size.x - 50, 30),
				"%d" % int(ench["price"]), HORIZONTAL_ALIGNMENT_CENTER, 40, UiTheme.FS_SUBHEAD,
				Color("ffd75a"))
		if sold:
			draw_rect(rr, Color(0, 0, 0, 0.55), true)
			draw_string(_font_bold, rr.position + Vector2(0, rr.size.y / 2),
					"已售罄", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, UiTheme.FS_SUBHEAD,
					Color("ff9a9a"))


func _draw_row3() -> void:
	var y := 410.0
	var bw := 240.0
	var bh := 96.0
	var gap := 20.0
	var x0 := 40.0
	for i in _row3.size():
		var e: Dictionary = _row3[i]
		var sold: bool = e["sold"]
		var rr := Rect2(x0 + i * (bw + gap), y, bw, bh)
		var hovered := not sold and _hover == ROW3_BASE + i and _enchanting < 0
		var bg := Color("241f1a") if hovered else Color("1e1a16")
		draw_rect(rr, bg, true)
		draw_rect(rr, Color("c8951c") if hovered else Color("6b5a3a"), false, 2.0)
		var icon: Texture2D = UiAssets.get_tex(str(e["icon"]))
		if icon != null:
			draw_texture_rect(icon, Rect2(rr.position + Vector2(10, 10), Vector2(40, 40)), false)
		draw_string(_font_bold, rr.position + Vector2(58, 30), str(e["name"]),
				HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 120, UiTheme.FS_SUBHEAD, Color("ece7db"))
		draw_string(_font, rr.position + Vector2(58, 52), str(e["desc"]),
				HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 68, 11, Color("b8b2a6"))
		draw_string(_font_bold, rr.position + Vector2(rr.size.x - 50, 30),
				"%d" % int(e["price"]), HORIZONTAL_ALIGNMENT_CENTER, 40, UiTheme.FS_SUBHEAD,
				Color("ffd75a"))
		if sold:
			draw_rect(rr, Color(0, 0, 0, 0.55), true)
			draw_string(_font_bold, rr.position + Vector2(0, rr.size.y / 2),
					"已售罄", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, UiTheme.FS_SUBHEAD,
					Color("ff9a9a"))


func _draw_price(rr: Rect2, price: int, sold: bool) -> void:
	var chip := Rect2(rr.end.x - 40, rr.position.y - 10, 40, 26)
	draw_rect(chip, Color("1a1c22"), true)
	draw_rect(chip, Color("c8951c"), false, 1.5)
	draw_string(_font_bold, chip.position + Vector2(0, 18), "%d" % price,
			HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, 12, Color("ffd75a"))


func _draw_leave() -> void:
	var rr := Rect2(W - 150, H - 60, 130, 44)
	var hovered := _hover == 100
	draw_rect(rr, Color("c8951c") if hovered else Color("8a6d1f"), true)
	draw_rect(rr, Color("ffd75a"), false, 2.0)
	draw_string(_font_bold, rr.position + Vector2(0, 29), "离开商店",
			HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, UiTheme.FS_BODY, Color("1a1c22"))


func _draw_hint() -> void:
	if _hint_t <= 0.0 or _hint == "":
		return
	draw_string(_font, Vector2(0, H - 26), _hint,
			HORIZONTAL_ALIGNMENT_CENTER, W, UiTheme.FS_BODY, Color("ffb0b0"))


func _set_hint(text: String) -> void:
	_hint = text
	_hint_t = 2.4


# ------------------------------------------------------------ 附魔选卡覆盖层

func _draw_pick_overlay() -> void:
	## 通用「选卡」覆盖层：附魔选卡（_enchanting >= 0）或删除选卡（_deleting）。
	if _enchanting < 0 and not _deleting:
		return
	# 压暗
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0, 0, 0, 0.55), true)
	# 标题
	if _deleting:
		draw_string(_font_bold, Vector2(0, 60), "选择要删除的卡",
				HORIZONTAL_ALIGNMENT_CENTER, W, UiTheme.FS_HEADING, Color("ff9a9a"))
		draw_string(_font, Vector2(0, 92), "点一张卡从卡组中删除（点「取消」返回）",
				HORIZONTAL_ALIGNMENT_CENTER, W, UiTheme.FS_BODY, Color("ece7db"))
	else:
		var ench: Dictionary = _row2[_enchanting]["ench"]
		draw_string(_font_bold, Vector2(0, 60), "选择要附魔的卡 —— %s" % str(ench["name"]),
				HORIZONTAL_ALIGNMENT_CENTER, W, UiTheme.FS_HEADING, Color("ffd75a"))
		draw_string(_font, Vector2(0, 92), "点一张高亮的卡完成附魔（点「取消」返回）",
				HORIZONTAL_ALIGNMENT_CENTER, W, UiTheme.FS_BODY, Color("ece7db"))
	# 列出可选卡
	_build_deck_cards()
	var cols := 5
	var cw := 150.0
	var ch := 190.0
	var gapx := 20.0
	var gapy := 16.0
	var x0 := (W - (cols * cw + (cols - 1) * gapx)) / 2.0
	var y0 := 130.0
	var any_ok := false
	for i in _deck_cards.size():
		var d: Dictionary = _deck_cards[i]
		var ok: bool = d["ok"]
		if ok:
			any_ok = true
		var col := i % cols
		var row := i / cols
		var rr := Rect2(x0 + col * (cw + gapx), y0 + row * (ch + gapy), cw, ch)
		var hovered := ok and _hover_enchant_card == i
		if ok:
			CardFace.draw(self, d["card"], rr, int(d["card"].health), hovered, false,
					_font, _font_bold)
		else:
			CardFace.draw(self, d["card"], rr, int(d["card"].health), false, false,
					_font, _font_bold)
			draw_rect(rr, Color(0, 0, 0, 0.6), true)
	if not any_ok:
		draw_string(_font, Vector2(0, 300),
				"没有符合这张附魔条件的卡" if not _deleting else "卡组里没有卡可删",
				HORIZONTAL_ALIGNMENT_CENTER, W, UiTheme.FS_SUBHEAD, Color("ffb0b0"))
	# 取消按钮
	var cancel := Rect2(W / 2.0 - 80, H - 80, 160, 44)
	draw_rect(cancel, Color("8a6d1f"), true)
	draw_rect(cancel, Color("ffd75a"), false, 2.0)
	draw_string(_font_bold, cancel.position + Vector2(0, 29), "取消",
			HORIZONTAL_ALIGNMENT_CENTER, cancel.size.x, UiTheme.FS_BODY, Color("1a1c22"))


func _build_deck_cards() -> void:
	## 构建选卡候选列表。附魔模式按附魔条件过滤；删除模式所有卡都可选。
	_deck_cards = []
	if _enchanting < 0 and not _deleting:
		return
	for i in RunState.deck_ids.size():
		var id: int = RunState.deck_ids[i]
		var c := _repo.get_card(id)
		if c == null:
			continue
		var ok := true
		if not _deleting:
			var ench: Dictionary = _row2[_enchanting]["ench"]
			ok = _enchant_ok(str(ench["id"]), c, i)
		_deck_cards.append({"id": id, "card": c, "ok": ok, "idx": i})


func _enchant_ok(ench_id: String, c: CardData, deck_idx: int) -> bool:
	## 这张卡能否吃这个附魔。每张卡只能有一个附魔 → 已附魔的直接排除。
	if not RunState._mod_at(deck_idx).is_empty():
		return false
	match ench_id:
		"costdown":
			return c.cost > 1 and not c.x_cost
		"damage":
			return c.power > 0
		"dimension":
			return (c.kind == "盟友" or c.is_fort()) and not c.has_affix("次元") \
					and not c.is_effect()
		"save":
			return true          # 任何卡都能保存
	return false


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
		queue_redraw()


func _hit_at(pos: Vector2) -> int:
	if _enchanting >= 0 or _deleting:
		return -1
	if _row1_rect(0).position.y <= pos.y and pos.y <= _row1_rect(0).end.y:
		for i in _row1.size():
			if _row1_rect(i).has_point(pos) and not _row1[i]["sold"]:
				return ROW1_BASE + i
	if _row2_rect(0).has_point(pos):
		for i in _row2.size():
			if _row2_rect(i).has_point(pos) and not _row2[i]["sold"]:
				return ROW2_BASE + i
	if _row3_rect(0).position.y <= pos.y and pos.y <= _row3_rect(0).end.y:
		for i in _row3.size():
			if _row3_rect(i).has_point(pos) and not _row3[i]["sold"]:
				return ROW3_BASE + i
	var lv := _leave_rect()
	if lv.has_point(pos):
		return 100
	return -1


func _enchant_card_at(pos: Vector2) -> int:
	if _enchanting < 0 and not _deleting:
		return -1
	var cols := 5
	var cw := 150.0
	var ch := 190.0
	var gapx := 20.0
	var gapy := 16.0
	var x0 := (W - (cols * cw + (cols - 1) * gapx)) / 2.0
	var y0 := 130.0
	for i in _deck_cards.size():
		var col := i % cols
		var row := i / cols
		var rr := Rect2(x0 + col * (cw + gapx), y0 + row * (ch + gapy), cw, ch)
		if rr.has_point(pos) and _deck_cards[i]["ok"]:
			return i
	return -1


func _on_click(pos: Vector2) -> void:
	if _enchanting >= 0 or _deleting:
		_on_pick_click(pos)
		return
	if _leave_rect().has_point(pos):
		_leave()
		return
	var hit := _hit_at(pos)
	if hit < 0:
		return
	if hit >= ROW1_BASE and hit < ROW1_BASE + 3:
		_buy_card(hit - ROW1_BASE)
	elif hit >= ROW2_BASE and hit < ROW2_BASE + 3:
		_start_enchant(hit - ROW2_BASE)
	elif hit >= ROW3_BASE and hit < ROW3_BASE + 3:
		_buy_row3(hit - ROW3_BASE)


func _buy_card(i: int) -> void:
	var e: Dictionary = _row1[i]
	var card: CardData = e["card"]
	var price := _card_price(card)
	if not RunState.spend_gold(price):
		_set_hint("金币不足（需要 %d）" % price)
		return
	e["sold"] = true
	RunState.add_card(card.id)
	_set_hint("购买「%s」（%d 金币）" % [card.card_name, price])


func _start_enchant(i: int) -> void:
	_enchanting = i
	_hover_enchant_card = -1
	_build_deck_cards()


func _buy_row3(i: int) -> void:
	var e: Dictionary = _row3[i]
	var price: int = e["price"]
	var key: String = e["key"]
	if key == "delete":
		# R181b：点「删除一张卡」→ 弹选卡覆盖层（选一张删），选完才扣钱。
		if RunState.deck_ids.is_empty():
			_set_hint("卡组里没有卡可删")
			return
		if RunState.gold < price:
			_set_hint("金币不足（需要 %d）" % price)
			return
		_deleting = true
		_hover_enchant_card = -1
		_build_deck_cards()
	elif key == "maxhp":
		if not RunState.spend_gold(price):
			_set_hint("金币不足（需要 %d）" % price)
			return
		e["sold"] = true
		RunState.gain_max_hp(5)
		_set_hint("最大生命 +5（并回复 5 点）")
	elif key == "choco":
		if not RunState.spend_gold(price):
			_set_hint("金币不足（需要 %d）" % price)
			return
		e["sold"] = true
		RunState.chocolate += 1
		_set_hint("巧克力 +1")


func _on_pick_click(pos: Vector2) -> void:
	## 选卡覆盖层的点击：附魔模式（_enchanting）或删除模式（_deleting）共用。
	# 取消
	var cancel := Rect2(W / 2.0 - 80, H - 80, 160, 44)
	if cancel.has_point(pos):
		_enchanting = -1
		_deleting = false
		_hover_enchant_card = -1
		queue_redraw()
		return
	var ci := _enchant_card_at(pos)
	if ci < 0:
		return
	var d: Dictionary = _deck_cards[ci]
	var idx: int = d["idx"]
	# ---- 删除模式 ----
	if _deleting:
		var del_price: int = _row3[0]["price"]
		if not RunState.spend_gold(del_price):
			_set_hint("金币不足（需要 %d）" % del_price)
			_deleting = false
			queue_redraw()
			return
		var del_name: String = str(_repo.get_card(RunState.deck_ids[idx]).card_name) \
				if _repo.get_card(RunState.deck_ids[idx]) != null else str(idx)
		RunState.delete_deck_card(idx)
		_row3[0]["sold"] = true
		_set_hint("删除了「%s」" % del_name)
		_deleting = false
		_hover_enchant_card = -1
		queue_redraw()
		return
	# ---- 附魔模式 ----
	var ench: Dictionary = _row2[_enchanting]["ench"]
	var price: int = ench["price"]
	if not RunState.spend_gold(price):
		_set_hint("金币不足（需要 %d）" % price)
		_enchanting = -1
		queue_redraw()
		return
	# 应用附魔
	var mod := _ench_mod(str(ench["id"]))
	if not RunState.enchant_deck_card(idx, mod):
		_set_hint("附魔失败")
		_enchanting = -1
		queue_redraw()
		return
	_row2[_enchanting]["sold"] = true
	var c := _repo.get_card(RunState.deck_ids[idx])
	_set_hint("「%s」获得附魔「%s」" % [c.card_name if c != null else str(idx), str(ench["name"])])
	_enchanting = -1
	_hover_enchant_card = -1
	queue_redraw()


func _ench_mod(ench_id: String) -> Dictionary:
	match ench_id:
		"costdown": return {"cost": -1}
		"damage": return {"power": 10}
		"dimension": return {"affix": "次元", "power": 2, "health": 10}
		"save": return {"affix": "保存"}
	return {}


func _leave() -> void:
	RunState.complete_current()
	SceneFx.goto("res://scenes/map.tscn")


# ------------------------------------------------------------ 命中区

func _row1_rect(i: int) -> Rect2:
	var y := 96.0
	var cw := 150.0
	var ch := 190.0
	var gap := 24.0
	var x0 := 40.0
	return Rect2(x0 + i * (cw + gap), y, cw, ch)


func _row2_rect(i: int) -> Rect2:
	var y := 300.0
	var bw := 240.0
	var bh := 96.0
	var gap := 20.0
	var x0 := 40.0
	return Rect2(x0 + i * (bw + gap), y, bw, bh)


func _row3_rect(i: int) -> Rect2:
	var y := 410.0
	var bw := 240.0
	var bh := 96.0
	var gap := 20.0
	var x0 := 40.0
	return Rect2(x0 + i * (bw + gap), y, bw, bh)


func _leave_rect() -> Rect2:
	return Rect2(W - 150, H - 60, 130, 44)
