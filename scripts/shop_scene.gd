extends Control
## 神秘商店（R181）：金币消费的三行商品，自适应铺满屏幕（右侧空出老板立绘区）。
##
## 第一行：随机本职业奖励卡（数量自适应货架宽，约 3~6 张，走 Boss 档概率 35/45/20）。
## 第二行：3 个随机附魔（从 4 种里抽 3 种不重复）：
##   * 费用 -1（只可费用 > 1 且非 X 费卡）价 50
##   * 伤害 +10（**只可技能卡**，R210；技能卡造成的伤害 +10）价 60
##   * 次元（盟友/工事，必须无次元、非效果卡；+2 力 +10 血）价 80（R210：50 → 80）
##   * 保存（回合结束手牌不丢弃，做成字段）价 60
## 第三行：固定 3 项：删一张卡 50 / +5 最大生命（并回血）50 / 买一块巧克力 120。
##
## 三行商品背后各有一层**货架**（shelf.png 素材，缺图回退程序画木板横条），
## 货架宽度 = 商品区宽度，随屏幕比例自适应。
##
## 附魔购买流程：选附魔 → 选卡（高亮可选卡）→ 成功入卡组，无候选卡则提示。
## 每件商品每次商店只能买一次，售罄后置灰。
## 金币不足 / 无可选卡时给出提示，不扣钱。

const UiTheme = preload("res://scripts/ui_theme.gd")

# 选卡覆盖层的卡片网格几何（绘制 + 命中**共用**，唯一口 `_pick_card_rect`）
const PICK_COLS := 5
const PICK_CARD_W := 150.0
const PICK_CARD_H := 190.0
const PICK_GAP_X := 20.0
const PICK_GAP_Y := 16.0
const PICK_Y0 := 130.0

# 附魔定义（id → 元数据）
const ENCHANTS := [
	{"id": "costdown", "name": "费用 -1", "desc": "每次战斗初次使用费用 -1（只能选费用 > 1 且非 X 费的卡）",
		"price": 50, "icon": "shop_icon_costdown"},
	{"id": "damage", "name": "伤害 +10", "desc": "这张技能卡造成的伤害 +10（只能选技能卡）",
		"price": 60, "icon": "shop_icon_damage"},
	{"id": "dimension", "name": "次元", "desc": "赋予「次元」并 +2 力 +10 血（盟友/工事，须无次元、非效果卡；离场消失）",
		"price": 80, "icon": "shop_icon_dimension"},
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
var _sel_row1 := -1            # 「选中查看」的第一行卡下标（R203：两段式购买首击）
var _sel_pick := -1            # 「选中查看」的选卡覆盖层卡下标（R203）

# 卡组展示（附魔选卡时）
var _deck_cards: Array = []    # [{id, name, card}]

var _hint := ""
var _hint_t := 0.0

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
	_setup_shop()
	# 演示参数：--shop 造一个 run + 金币（截图核验商店界面）。
	var args := OS.get_cmdline_user_args()
	if "--shop" in args:
		if not RunState.run_active:
			RunState.run_active = true
			RunState.start_run([], GameLayers.LAYER_DEFAULT)
		RunState.gold = 100
		RunState.pending_node = {"type": "shop"}
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
	# 第一行：随机本职业奖励卡（数量自适应，先按最多 6 张抽，绘制时按货架宽截断）。
	# 走 Boss 档概率（普通 35% / 稀有 45% / 史诗 20%）。
	var rolled := CardReward.roll(_repo, "boss", 6)
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
		{"key": "choco", "name": "巧克力", "desc": "获得一块巧克力（行动力 +1）", "price": 120,
			"icon": "chocolate", "sold": false},
	]
	# 全局编号偏移
	_row1_base = 0
	_row2_base = _row1.size()
	_row3_base = _row1.size() + _row2.size()


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
	## 顶部标题 + 金币条高度。
	return 64.0


func _bottom_h() -> float:
	## 底部离开按钮带高度。
	return 64.0


func _row_rects() -> Array:
	## 三行商品的货架区矩形。第一行（卡牌）按**卡牌标准宽高比 58:70** 定高，
	## 第二、三行（附魔 / 固定项）均分剩余高度 —— 卡牌不再被拉伸失真。
	var top := _top_h()
	var bottom := _bottom_h()
	var area_h := _vs().y - top - bottom
	var shelf_h := 30.0          # 每层货架木板高
	var gap_v := 14.0            # 行与行之间的垂直留白
	var card_w := 150.0
	var card_h := card_w * 70.0 / 58.0          # 卡牌标准比例 → 高约 181
	var row1_h := card_h + shelf_h
	var row23_h := (area_h - row1_h - gap_v * 2.0) / 2.0
	row23_h = maxf(row23_h, 96.0 + shelf_h)     # 兜底：商品框至少 96 高
	var x0 := _goods_x0()
	var w := _goods_w()
	var y := top
	var out: Array = []
	# 第一行（卡牌）
	out.append({
		"row": Rect2(x0, y, w, card_h),
		"shelf": Rect2(x0, y + card_h, w, shelf_h),
	})
	y += row1_h + gap_v
	# 第二行
	out.append({
		"row": Rect2(x0, y, w, row23_h - shelf_h),
		"shelf": Rect2(x0, y + row23_h - shelf_h, w, shelf_h),
	})
	y += row23_h + gap_v
	# 第三行
	out.append({
		"row": Rect2(x0, y, w, row23_h - shelf_h),
		"shelf": Rect2(x0, y + row23_h - shelf_h, w, shelf_h),
	})
	return out


func _visible_row1_count() -> int:
	## 第一行货架能放下几张卡（卡宽 150 + 间距 32，4~5 张；卡更宽、之间有留白）。
	var w := _goods_w()
	var card_w := 150.0
	var gap := 32.0
	var n := int((w + gap) / (card_w + gap))
	return clampi(n, 4, mini(5, _row1.size()))


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
	# 三层货架 + 三行商品
	_draw_shelves()
	_draw_row1()
	_draw_row2()
	_draw_row3()
	_draw_pick_overlay()
	_draw_leave()
	_draw_desc_plate()   # R203：悬停/选中卡的描述板（卡面只留卡名后的详情入口）
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


func _draw_header() -> void:
	draw_string(_font_bold, Vector2(0, 30), "神 秘 商 店",
			HORIZONTAL_ALIGNMENT_CENTER, _vs().x, UiTheme.FS_HEADING, Color("ffd75a"))
	var icon: Texture2D = UiAssets.get_tex("icon_gold")
	var x := _goods_x0()
	if icon != null:
		draw_texture_rect(icon, Rect2(x, 40, 26, 26), false)
		x += 32
	draw_string(_font_bold, Vector2(x, 60), "金币 %d" % RunState.gold,
			HORIZONTAL_ALIGNMENT_LEFT, 180, UiTheme.FS_SUBHEAD, Color("ffd75a"))


func _draw_shelves() -> void:
	## 三层货架背景（放在商品背后）：有 shelf.png 则铺货架区，缺图回退程序画木板横条。
	var rects := _row_rects()
	var shelf_tex: Texture2D = UiAssets.get_tex("shelf")
	for i in 3:
		var shelf: Rect2 = rects[i]["shelf"]
		if shelf_tex != null:
			# 货架素材横向拉伸（木板横条形态，横向拉伸不破坏观感）
			draw_texture_rect(shelf_tex, Rect2(shelf.position.x, shelf.position.y - 40.0,
					shelf.size.x, shelf.size.y + 40.0), false)
		else:
			# 程序化木板：深棕横条 + 上沿高光 + 两端竖撑
			draw_rect(shelf, Color("5a3d22"), true)
			draw_rect(Rect2(shelf.position.x, shelf.position.y, shelf.size.x, 4.0),
					Color("8a6138"), true)
			draw_rect(Rect2(shelf.position.x, shelf.position.y, 8.0, shelf.size.y),
					Color("3a2815"), true)
			draw_rect(Rect2(shelf.end.x - 8.0, shelf.position.y, 8.0, shelf.size.y),
					Color("3a2815"), true)


func _card_price(card: CardData) -> int:
	match card.rarity:
		0: return 25
		1: return 50
		2: return 80
	return 25


func _draw_row1() -> void:
	var rects := _row_rects()
	var row: Rect2 = rects[0]["row"]
	var n := _visible_row1_count()
	var gap := 32.0
	var cw := 150.0
	var total_w := n * cw + (n - 1) * gap
	var x0 := row.position.x + (row.size.x - total_w) / 2.0
	var y := row.position.y
	var ch := row.size.y
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
		var price := _card_price(card)
		_draw_price(rr, price, sold)
		if sold:
			draw_rect(rr, Color(0, 0, 0, 0.55), true)
			draw_string(_font_bold, rr.position + Vector2(0, rr.size.y / 2),
					"已售罄", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, UiTheme.FS_SUBHEAD,
					Color("ff9a9a"))


func _draw_row2() -> void:
	var rects := _row_rects()
	var row: Rect2 = rects[1]["row"]
	var gap := 18.0
	var n := _row2.size()
	var bw := (row.size.x - (n - 1) * gap) / n
	var x0 := row.position.x
	var y := row.position.y
	var bh := row.size.y
	for i in n:
		var e: Dictionary = _row2[i]
		var ench: Dictionary = e["ench"]
		var sold: bool = e["sold"]
		var rr := Rect2(x0 + i * (bw + gap), y, bw, bh)
		_draw_goods_box(rr, str(ench["icon"]), str(ench["name"]), str(ench["desc"]),
				int(ench["price"]), sold, _hover == _row2_base + i, _enchanting == i and not sold,
				"enchant")
		if sold:
			_draw_sold_mask(rr)


func _draw_row3() -> void:
	var rects := _row_rects()
	var row: Rect2 = rects[2]["row"]
	var gap := 18.0
	var n := _row3.size()
	var bw := (row.size.x - (n - 1) * gap) / n
	var x0 := row.position.x
	var y := row.position.y
	var bh := row.size.y
	for i in n:
		var e: Dictionary = _row3[i]
		var sold: bool = e["sold"]
		var rr := Rect2(x0 + i * (bw + gap), y, bw, bh)
		_draw_goods_box(rr, str(e["icon"]), str(e["name"]), str(e["desc"]),
				int(e["price"]), sold, _hover == _row3_base + i, false, "service")
		if sold:
			_draw_sold_mask(rr)


func _draw_goods_box(rr: Rect2, icon_name: String, name: String, desc: String,
		price: int, sold: bool, hovered: bool, active: bool, category: String = "service") -> void:
	## 第二行（附魔 "enchant"）商品背景是**木板**、第三行（常驻 "service"）是**石板** ——
	## 每件商品是一块独立的板子，四边带不规则缺口（缺口处透明），不再用纯黑底。
	## 两行仍用「附魔紫 / 服务金」角标 + 悬停描边区分类别语义。
	var is_ench := category == "enchant"
	var accent := Color("9b6bd8") if is_ench else Color("c8951c")          # 悬停/激活描边
	var accent_dim := Color("5a4a78") if is_ench else Color("6b5a3a")      # 常态描边
	var tag_col := Color("c9a6f0") if is_ench else Color("e0c070")         # 角标文字色
	var tag_bg := Color("2a1f3a") if is_ench else Color("2a2413")          # 角标底
	# 木板 / 石板底（带缺口 + 木纹/石纹）
	_draw_plate(rr, is_ench, hovered or active)
	# 左上角类别角标（附魔 / 服务）
	var tag_text := "附魔" if is_ench else "服务"
	var tag_rect := Rect2(rr.position + Vector2(0, 10), Vector2(38, 18))
	draw_rect(tag_rect, tag_bg, true)
	draw_string(_font, tag_rect.position + Vector2(0, 13), tag_text,
			HORIZONTAL_ALIGNMENT_CENTER, tag_rect.size.x, 10, tag_col)
	var icon: Texture2D = UiAssets.get_tex(icon_name)
	if icon != null:
		draw_texture_rect(icon, Rect2(rr.position + Vector2(12, 34), Vector2(44, 44)), false)
	var tx := rr.position.x + 66.0
	draw_string(_font_bold, Vector2(tx, rr.position.y + 42), name,
			HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 120, UiTheme.FS_SUBHEAD, Color("ece7db"))
	draw_string(_font, Vector2(tx, rr.position.y + 66), desc,
			HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 76, 11, Color("b8b2a6"))
	draw_string(_font_bold, Vector2(rr.end.x - 52, rr.position.y + 42),
			"%d" % price, HORIZONTAL_ALIGNMENT_CENTER, 42, UiTheme.FS_SUBHEAD, Color("ffd75a"))


func _draw_plate(rr: Rect2, wood: bool, lit: bool) -> void:
	## 程序化画一块「木板 / 石板」商品底板：**固定角度**的斜角板（不再随机抖动），
	## 四边留固定的小缺口（透明、不 fill 背景），再叠加木纹 / 石纹 + 边缘描边。
	## `lit`（悬停/激活）时板子「轻度向前倾斜」—— 顶边内缩、底边外扩成上窄下宽梯形。
	var w := rr.size.x
	var h := rr.size.y
	var x0 := rr.position.x
	var y0 := rr.position.y
	# 固定角度轮廓（不再随机抖动）：四角用固定的斜切量，形成规则的斜角板。
	# 顶部 / 底部各留一个固定的小缺口（透明），让板子边缘有「破损」感但角度恒定。
	var cut_top := 8.0     # 顶部左右各内缩（斜切量）
	var cut_bot := 10.0    # 底部左右各内缩
	var cut_edge := 6.0    # 上下边缘的浅缺口（模拟磨损，固定）
	# 悬停 / 激活时「轻度向前倾斜」：顶边再内缩、底边外扩，形成上窄下宽的梯形透视。
	var tilt := 6.0 if lit else 0.0
	var pts := PackedVector2Array([
		Vector2(x0 + cut_top + tilt, y0 + cut_edge),                    # 左上
		Vector2(x0 + w - cut_top - tilt, y0 + cut_edge),                # 右上
		Vector2(x0 + w - cut_bot + tilt, y0 + h - cut_edge),            # 右下
		Vector2(x0 + cut_bot - tilt, y0 + h - cut_edge),                # 左下
	])
	# 底板颜色
	var base: Color
	var edge: Color
	if wood:
		base = Color("6b4a2c") if not lit else Color("7d5836")     # 木板棕
		edge = Color("4a3018")
	else:
		base = Color("5a5a5e") if not lit else Color("6a6a6f")     # 石板灰
		edge = Color("3c3c40")
	# 底部阴影（向下偏移一点，让板子有立体感）
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, 3))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	# 板子主体
	draw_colored_polygon(pts, base)
	# 边缘描边（沿多边形，用细线多边形近似描边）
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
			Color(edge.r, edge.g, edge.b, 0.9) if not lit else Color("d9b56a"), 2.0)
	# 纹理：木板横纹 / 石板裂纹
	if wood:
		# 横向木纹线（几根贯穿的淡/深线，固定位置，被斜角自然截断）
		var stripes := 3
		for k in stripes:
			var yy := y0 + h * (0.28 + 0.22 * k)
			draw_line(Vector2(x0 + cut_top, yy), Vector2(x0 + w - cut_top, yy),
					Color(0, 0, 0, 0.18), 1.5)
			draw_line(Vector2(x0 + cut_top, yy + 1.5), Vector2(x0 + w - cut_top, yy + 1.5),
					Color(1.0, 0.95, 0.8, 0.10), 1.0)
		# 木节
		draw_circle(Vector2(x0 + w * 0.78, y0 + h * 0.32), 3.0, Color(0, 0, 0, 0.16))
	else:
		# 石板裂纹（细折线）+ 斑点
		draw_line(Vector2(x0 + w * 0.2, y0 + h * 0.35), Vector2(x0 + w * 0.42, y0 + h * 0.55),
				Color(0, 0, 0, 0.14), 1.5)
		draw_line(Vector2(x0 + w * 0.42, y0 + h * 0.55), Vector2(x0 + w * 0.34, y0 + h * 0.78),
				Color(0, 0, 0, 0.12), 1.5)
		draw_circle(Vector2(x0 + w * 0.75, y0 + h * 0.6), 2.5, Color(1, 1, 1, 0.10))
		draw_circle(Vector2(x0 + w * 0.6, y0 + h * 0.24), 2.0, Color(0, 0, 0, 0.12))


func _draw_sold_mask(rr: Rect2) -> void:
	draw_rect(rr, Color(0, 0, 0, 0.55), true)
	draw_string(_font_bold, rr.position + Vector2(0, rr.size.y / 2),
			"已售罄", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, UiTheme.FS_SUBHEAD, Color("ff9a9a"))


func _draw_price(rr: Rect2, price: int, sold: bool) -> void:
	var chip := Rect2(rr.end.x - 40, rr.position.y - 12, 40, 26)
	draw_rect(chip, Color("1a1c22"), true)
	draw_rect(chip, Color("c8951c"), false, 1.5)
	draw_string(_font_bold, chip.position + Vector2(0, 18), "%d" % price,
			HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, 12, Color("ffd75a"))


func _draw_leave() -> void:
	var rr := _leave_rect()
	var hovered := _hover == 100
	draw_rect(rr, Color("c8951c") if hovered else Color("8a6d1f"), true)
	draw_rect(rr, Color("ffd75a"), false, 2.0)
	draw_string(_font_bold, rr.position + Vector2(0, 29), "离开商店",
			HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, UiTheme.FS_BODY, Color("1a1c22"))


func _draw_hint() -> void:
	if _hint_t <= 0.0 or _hint == "":
		return
	draw_string(_font, Vector2(0, _vs().y - 26), _hint,
			HORIZONTAL_ALIGNMENT_CENTER, _vs().x, UiTheme.FS_BODY, Color("ffb0b0"))


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


func _draw_desc_plate() -> void:
	## R203：商店卡面改为只留卡名后，效果描述的查看入口 = 底部这条描述板。
	## 桌面端鼠标悬停即显示；移动端无 hover → 两段式点击的「首击选中查看」同样显示。
	var card := _hover_card()
	if card == null:
		return
	var vs := _vs()
	var rr := Rect2(_goods_x0(), vs.y - 58.0, _goods_w(), 40.0)
	draw_rect(rr, Color(0.06, 0.07, 0.09, 0.88), true)
	draw_rect(rr, Color("c8951c"), false, 1.5)
	var affix: String = card.affix_line()
	var meta: String = card.kind + ((" · " + affix) if affix != "" else "")
	draw_string(_font_bold, rr.position + Vector2(10, 17),
			"%s   %s" % [card.card_name, meta],
			HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 20.0, 12, Color("ffd75a"))
	var eff: String = CardText.naturalize(card.effect_text).replace("\n", " ").strip_edges()
	if eff != "":
		draw_string(_font, rr.position + Vector2(10, 33),
				CardFace._ellipsize(_font, eff, rr.size.x - 20.0, 10),
				HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 20.0, 10, Color("ece7db"))


# ------------------------------------------------------------ 附魔选卡覆盖层

func _draw_pick_overlay() -> void:
	## 通用「选卡」覆盖层：附魔选卡（_enchanting >= 0）或删除选卡（_deleting）。
	if _enchanting < 0 and not _deleting:
		return
	var vs := _vs()
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55), true)
	if _deleting:
		draw_string(_font_bold, Vector2(0, 60), "选择要删除的卡",
				HORIZONTAL_ALIGNMENT_CENTER, vs.x, UiTheme.FS_HEADING, Color("ff9a9a"))
		draw_string(_font, Vector2(0, 92), "点一张卡查看（再点一次删除；点「取消」返回）",
				HORIZONTAL_ALIGNMENT_CENTER, vs.x, UiTheme.FS_BODY, Color("ece7db"))
	else:
		var ench: Dictionary = _row2[_enchanting]["ench"]
		draw_string(_font_bold, Vector2(0, 60), "选择要附魔的卡 —— %s" % str(ench["name"]),
				HORIZONTAL_ALIGNMENT_CENTER, vs.x, UiTheme.FS_HEADING, Color("ffd75a"))
		draw_string(_font, Vector2(0, 92), "点一张高亮的卡查看（再点一次完成附魔；点「取消」返回）",
				HORIZONTAL_ALIGNMENT_CENTER, vs.x, UiTheme.FS_BODY, Color("ece7db"))
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
				HORIZONTAL_ALIGNMENT_CENTER, vs.x, UiTheme.FS_SUBHEAD, Color("ffb0b0"))
	var cancel := Rect2(vs.x / 2.0 - 80, vs.y - 80, 160, 44)
	draw_rect(cancel, Color("8a6d1f"), true)
	draw_rect(cancel, Color("ffd75a"), false, 2.0)
	draw_string(_font_bold, cancel.position + Vector2(0, 29), "取消",
			HORIZONTAL_ALIGNMENT_CENTER, cancel.size.x, UiTheme.FS_BODY, Color("1a1c22"))


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
		if not _deleting:
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
	var hit := _hit_at(pos)
	if hit < 0:
		if _sel_row1 >= 0:            # 点空白 → 取消「选中查看」
			_sel_row1 = -1
			_ask_redraw()
		return
	if hit >= _row1_base and hit < _row1_base + _row1.size():
		var i := hit - _row1_base
		if _sel_row1 == i:
			# 第二击同一张 → 确认购买（R203 两段式：首击查看，再击成交）
			_sel_row1 = -1
			_buy_card(i)
		else:
			# 首击 → 选中查看（卡面高亮 + 描述板），不扣钱；移动端无 hover 时的详情入口
			_sel_row1 = i
			_ask_redraw()
	elif hit >= _row2_base and hit < _row2_base + _row2.size():
		_start_enchant(hit - _row2_base)
	elif hit >= _row3_base and hit < _row3_base + _row3.size():
		_buy_row3(hit - _row3_base)


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
	## ⚠️ 末尾的 `_ask_redraw()` 不是可选项（R218 用户实测）：少了它，点第二行的附魔商品
	## 只会把 `_enchanting` 设上、画面却完全不动 → 玩家以为「点了没反应」，继续点，
	## 结果每一下都落在**看不见的**选卡页上 → 随机某张卡被选中/成交（「对象变成随机」）。
	_enchanting = i
	_hover_enchant_card = -1
	_build_deck_cards()
	_ask_redraw()


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
		if RunState.deck_ids.is_empty():
			_set_hint("卡组里没有卡可删")
			return
		if RunState.gold < price:
			_set_hint("金币不足（需要 %d）" % price)
			return
		_deleting = true
		_hover_enchant_card = -1
		_build_deck_cards()
		_ask_redraw()          # R218：同 `_start_enchant`，否则删除选卡页不出现
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
		RunState.sync_fatigue()   # R223 难度 5：巧克力回到 6 以上 → 疲惫出卡组
		_set_hint("巧克力 +1")


func _on_pick_click(pos: Vector2) -> void:
	## 选卡覆盖层的点击：附魔模式（_enchanting）或删除模式（_deleting）共用。
	var vs := _vs()
	var cancel := Rect2(vs.x / 2.0 - 80, vs.y - 80, 160, 44)
	if cancel.has_point(pos):
		_enchanting = -1
		_deleting = false
		_hover_enchant_card = -1
		_sel_pick = -1
		_ask_redraw()
		return
	var ci := _enchant_card_at(pos)
	if ci < 0:
		var any_i := _pick_card_any_at(pos)
		if any_i >= 0 and not _deleting:
			# 点到「不符合这张附魔条件」的灰卡 → 明确说一句，别让玩家以为死机
			_set_hint("这张卡不能吃「%s」（已附魔或类型不符）"
					% str(_row2[_enchanting]["ench"]["name"]))
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
		if RunState.gold < del_price:
			_set_hint("金币不足（需要 %d）" % del_price)
			_deleting = false
			_ask_redraw()
			return
		var del_card: CardData = null
		if idx < RunState.deck_ids.size():
			del_card = _repo.get_card(RunState.deck_ids[idx])
		var del_name: String = del_card.card_name if del_card != null else str(idx)
		# 先删卡、再扣钱（R204）：删失败绝不白扣。
		if not RunState.delete_deck_card(idx):
			_set_hint("删除失败")
			_deleting = false
			_ask_redraw()
			return
		RunState.gold -= del_price
		_row3[0]["sold"] = true
		_set_hint("删除了「%s」" % del_name)
		_deleting = false
		_hover_enchant_card = -1
		_ask_redraw()
		return
	# ---- 附魔模式 ----
	var ench: Dictionary = _row2[_enchanting]["ench"]
	var price: int = ench["price"]
	if RunState.gold < price:
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
	RunState.gold -= price
	_row2[_enchanting]["sold"] = true
	var c := _repo.get_card(RunState.deck_ids[idx])
	_set_hint("「%s」获得附魔「%s」" % [c.card_name if c != null else str(idx), str(ench["name"])])
	_enchanting = -1
	_hover_enchant_card = -1
	_ask_redraw()


func _ench_mod(ench_id: String) -> Dictionary:
	## R214：数值定义搬到 `RunState.enchant_mod()`（唯一口）—— 演示旗标 / 测试 /
	## 商店三处必须完全同源，否则「卡面标记显示的那种附魔」和「实际烤进去的数值」会漂移。
	return RunState.enchant_mod(ench_id)


func _leave() -> void:
	RunState.complete_current()
	SceneFx.goto("res://scenes/map.tscn")


# ------------------------------------------------------------ 命中区

func _row1_rect(i: int) -> Rect2:
	var rects := _row_rects()
	var row: Rect2 = rects[0]["row"]
	var n := _visible_row1_count()
	var gap := 32.0
	var cw := 150.0
	var total_w := n * cw + (n - 1) * gap
	var x0 := row.position.x + (row.size.x - total_w) / 2.0
	return Rect2(x0 + i * (cw + gap), row.position.y, cw, row.size.y)


func _row2_rect(i: int) -> Rect2:
	var rects := _row_rects()
	var row: Rect2 = rects[1]["row"]
	var gap := 18.0
	var n := _row2.size()
	var bw := (row.size.x - (n - 1) * gap) / n
	return Rect2(row.position.x + i * (bw + gap), row.position.y, bw, row.size.y)


func _row3_rect(i: int) -> Rect2:
	var rects := _row_rects()
	var row: Rect2 = rects[2]["row"]
	var gap := 18.0
	var n := _row3.size()
	var bw := (row.size.x - (n - 1) * gap) / n
	return Rect2(row.position.x + i * (bw + gap), row.position.y, bw, row.size.y)


func _leave_rect() -> Rect2:
	var vs := _vs()
	return Rect2(vs.x - 160, vs.y - 60, 140, 44)
