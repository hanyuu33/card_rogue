class_name DeckViewer
extends CanvasLayer

const UiPop = preload("res://scripts/ui_pop.gd")
## 通用「牌库查看」悬浮层 —— 让牌库在游戏中任何界面都能查看。
##
## 右上角一个「牌库 N」按钮；点开后是本局卡组（RunState.deck_ids）的聚合网格：
## 相同卡（同 id）合并、左下角 ×N 张数角标、按（费用, id）排序、滚轮翻页、
## 点击任意处关闭。面板不压暗背景（用户要求）。
##
## 用法：在场景 _ready 里 `DeckViewer.attach(self)`（可选第二参数指定按钮位置）。
## 命令行 -- --deckview：打开后自动展开面板（截图验证用）。

const UiTheme = preload("res://scripts/ui_theme.gd")

const CARD_W := 76.0
const CARD_H := 92.0
## R117：间距要装得下骑在框上的数值（CARD_BLEED × k = 9.2 × 1.314 ≈ 12.09，左右各一份）
## → 需要 24.18，取 24（每侧 12.0，差 0.09px 亚像素）。
## ⚠️ 间距被**列数**反卡住：`cols = int((pw - 40) / (CARD_W + GAP))`。
##    直接把面板留在 1120 的话，GAP 24 会让列数从 11 掉到 10 —— 所以改成
##    **加宽面板**（1120 → 1150）把这一格吃回来：`int(1110 / 100) = 11` 仍是 11 列。
const GAP := 24.0

var _btn: Button
var _panel: Control
var _font: Font
var _font_bold: Font
var _open := false
var _scroll := 0.0          # 已滚动的行数（浮点，按行步进）
var _shown_n := -1          # 按钮上当前写的张数（R375：数量变了要自己刷新）


static func attach(host: Node, btn_pos := Vector2(1150, 6)) -> DeckViewer:
	## 挂到任意界面：返回新建的悬浮层实例。
	var v := DeckViewer.new()
	host.add_child(v)
	v._btn.position = btn_pos
	return v


func _init() -> void:
	layer = 15


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()

	_btn = Button.new()
	_btn.custom_minimum_size = Vector2(114, 32)
	_btn.size = Vector2(114, 32)
	_btn.add_theme_font_override("font", _font)
	_btn.add_theme_font_size_override("font_size", UiTheme.FS_LABEL)
	_btn.pressed.connect(_toggle)
	UiTheme.apply_chip(_btn, false, true)   # 关闭按钮：面板是 PAPER 亮底 + 固定 32px 高 → 浅底 compact
	add_child(_btn)

	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	_panel.draw.connect(_on_panel_draw)
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)
	_refresh_btn()
	# 命令行 -- --deckview：自动展开面板（截图验证用）
	if "--deckview" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.3
		t.one_shot = true
		t.timeout.connect(func(): if not _open: _toggle())
		add_child(t)
		t.start()


func _process(_delta: float) -> void:
	## R375：卡组会在**别的界面**里变（商店买卡 / 删卡 / 事件加卡 / 休息附魔），
	## 而按钮上的张数原来只在 `_ready` 与开关面板时刷新 —— 商店里买完卡，
	## 右上角还写着买之前的数字。这里只比一个 int，代价可以忽略。
	## 面板开着时连内容一起重画（同 id 的 ×N 张数角标也会跟着变）。
	var n := RunState.deck_ids.size()
	if n == _shown_n:
		return
	_refresh_btn()
	if _open:
		_panel.queue_redraw()


func _refresh_btn() -> void:
	_shown_n = RunState.deck_ids.size()
	_btn.text = "牌库 %d" % _shown_n


func _toggle() -> void:
	_open = not _open
	_panel.visible = _open
	if _open:
		UiPop.play(_panel, 1.0)   # R151 P1-9：入场淡入 160ms
	_scroll = 0.0
	_refresh_btn()
	_panel.queue_redraw()


# ------------------------------------------------------------ 数据

func _merged() -> Array:
	## 卡组按 **卡面签名** 聚合：[{card, count}]，按（费用, id）排序。
	## ⚠️ R112 起卡组里不再有「运行时改写费用」的卡（铁栅栏 9072 卡面就是 2 费）。
	## ⚠️ R214：**不能只按 id 聚合**（与 `map_scene._build_deck_rows()` 同口径）——
	##    商店附魔（R181）生成的是**同 id 的独立副本**，只按 id 合并会把「附魔的那张」
	##    并进原卡：卡面上的附魔标记与烤进去的数值一起来路不明。
	##    卡实例统一从 `RunState.build_deck()` 取（它负责把附魔烤进副本并写 `enchant`）。
	var repo := CardRepo.load_json()
	var order: Array = []
	var by_key := {}
	for c: CardData in RunState.build_deck(repo):
		var key := "%d|%d|%d|%d|%s|%s" % [c.id, c.cost, c.power, c.health,
				",".join(c.affixes), c.enchant]
		if by_key.has(key):
			order[by_key[key]]["count"] += 1
			continue
		by_key[key] = order.size()
		order.append({"card": c, "count": 1})
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: CardData = a["card"]
		var cb: CardData = b["card"]
		if ca.cost != cb.cost:
			return ca.cost < cb.cost
		return ca.id < cb.id)
	return order


func _layout(n: int) -> Dictionary:
	## 面板网格布局（绘制与滚动共用）。
	var pw := 1150.0
	var ph := 560.0
	var cols := maxi(1, int((pw - 40.0) / (CARD_W + GAP)))
	var rows := maxi(1, int(ceil(float(n) / float(cols))))
	var px := (1280.0 - pw) / 2
	var py := (720.0 - ph) / 2
	var grid_x := px + (pw - (cols * (CARD_W + GAP) - GAP)) / 2
	var grid_y := py + 52.0
	var view_rows := int((py + ph - 16.0 - grid_y) / (CARD_H + GAP))
	return {"pw": pw, "ph": ph, "px": px, "py": py, "cols": cols, "rows": rows,
			"grid_x": grid_x, "grid_y": grid_y, "view_rows": view_rows}


# ------------------------------------------------------------ 绘制与输入

func _on_panel_draw() -> void:
	var merged := _merged()
	var n := merged.size()
	var L := _layout(n)
	var px: float = L["px"]
	var py: float = L["py"]
	var pw: float = L["pw"]
	var ph: float = L["ph"]
	# 面板不压暗背景（用户要求：点开面板时后面区域不要变暗）
	_panel.draw_rect(Rect2(px, py, pw, ph), UiTheme.PAPER)
	_panel.draw_rect(Rect2(px, py, pw, ph), UiTheme.INK_600, false, 2.0)
	_panel.draw_string(_font_bold, Vector2(px + 20, py + 32),
			"我的卡组（共 %d 张 · 相同卡合并）" % RunState.deck_ids.size(),
			HORIZONTAL_ALIGNMENT_LEFT, pw - 40, UiTheme.FS_BODY, UiTheme.INK_800)
	if n == 0:
		_panel.draw_string(_font, Vector2(px + 20, py + 80), "卡组是空的。",
				HORIZONTAL_ALIGNMENT_LEFT, 300, UiTheme.FS_LABEL, UiTheme.INK_500)
		return
	var cols: int = L["cols"]
	var view_rows: int = L["view_rows"]
	var max_scroll: float = maxf(0.0, float(L["rows"] - view_rows))
	_scroll = clampf(_scroll, 0.0, max_scroll)
	var skip_rows := int(_scroll)
	for i in n:
		var r := i / cols
		if r < skip_rows or r >= skip_rows + view_rows:
			continue
		var c: CardData = merged[i]["card"]
		var rect := Rect2(L["grid_x"] + (i % cols) * (CARD_W + GAP),
				L["grid_y"] + (r - skip_rows) * (CARD_H + GAP), CARD_W, CARD_H)
		CardFace.draw(_panel, c, rect, c.health, false, false, _font, _font_bold)
		var cnt: int = merged[i]["count"]
		if cnt > 1:
			# R114：右上角。卡片底部已归数值徽章（左下力/程、右下生/速）。
			var badge := Rect2(rect.position + Vector2(rect.size.x - 28, 2),
					Vector2(26, 16))
			_panel.draw_rect(badge, Color(0.15, 0.18, 0.15, 0.88))
			_panel.draw_rect(badge, Color("a8d8a8"), false, 1.0)
			_panel.draw_string(_font_bold, badge.position + Vector2(0, 12),
					"×%d" % cnt, HORIZONTAL_ALIGNMENT_CENTER, 26, UiTheme.FS_CAPTION, Color("d8f0d8"))
	# 滚动提示
	if max_scroll > 0:
		_panel.draw_string(_font, Vector2(px + pw - 220, py + ph - 12),
				"第 %d/%d 屏" % [skip_rows + 1, int(max_scroll) + 1],
				HORIZONTAL_ALIGNMENT_LEFT, 200, UiTheme.FS_CAPTION, UiTheme.INK_500)


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_scroll -= 1.0
				_panel.queue_redraw()
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll += 1.0
				_panel.queue_redraw()
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				_toggle()
