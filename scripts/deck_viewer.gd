class_name DeckViewer
extends CanvasLayer
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
const GAP := 10.0

var _btn: Button
var _panel: Control
var _font: SystemFont
var _font_bold: SystemFont
var _open := false
var _scroll := 0.0          # 已滚动的行数（浮点，按行步进）


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


func _refresh_btn() -> void:
	_btn.text = "牌库 %d" % RunState.deck_ids.size()


func _toggle() -> void:
	_open = not _open
	_panel.visible = _open
	_scroll = 0.0
	_refresh_btn()
	_panel.queue_redraw()


# ------------------------------------------------------------ 数据

func _merged() -> Array:
	## 卡组按 **id** 聚合：[{card, count}]，按（费用, id）排序。
	## ⚠️ R112 起卡组里不再有「运行时改写费用」的卡（铁栅栏 9072 卡面就是 2 费），
	## 同名卡的费用必然相同 → 按 id 聚合即可，不再需要把费用并进聚合键。
	var repo := CardRepo.load_json()
	var order: Array = []
	var by_id := {}
	for i in RunState.deck_ids.size():
		var id: int = RunState.deck_ids[i]
		var c := repo.get_card(id)
		if c == null:
			continue
		if not by_id.has(id):
			var e := {"card": c, "count": 0}
			by_id[id] = e
			order.append(e)
		by_id[id]["count"] += 1
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: CardData = a["card"]
		var cb: CardData = b["card"]
		if ca.cost != cb.cost:
			return ca.cost < cb.cost
		return ca.id < cb.id)
	return order


func _layout(n: int) -> Dictionary:
	## 面板网格布局（绘制与滚动共用）。
	var pw := 1120.0
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
			"我的卡组（共 %d 张 · 相同卡合并 · 滚轮翻页 · 点击任意处关闭）" % RunState.deck_ids.size(),
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
			var badge := Rect2(rect.position + Vector2(2, rect.size.y - 18),
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
