class_name TelemetryConsent
extends Control
## R757：发布版**首次启动**的匿名数据询问 —— 一个模态小面板，问一次，之后不再打扰。
##
## 为什么要有这一屏：Steam 上架后这套事件流是**往外发**的，哪怕内容全是卡牌 id，
## 也得让玩家先点头（EU / 商店页隐私口径都要求「明确同意」，默认开是不行的）。
## 所以默认 `telemetry_opt_in = 0`（= 不发），玩家点了「同意发送」才变 1。
##
## 与设置页那一项的关系：这里是**首次询问**，设置页是**随时反悔**。两处写同一个字段，
## 判据都走 `GameSettings.telemetry_upload_allowed()` —— 不在任何地方重复判断。
##
## 不做「暂停游戏」：这一屏只出现在标题页（那一页本来就是静止的），
## 弹在战斗里会把玩家吓一跳，也会干扰教程。
##
## headless / 测试版：`maybe_ask()` 直接返回，不建节点 —— `_verify.py` 八套全是 headless。

const L10n = preload("res://scripts/l10n.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

const PANEL_W := 640.0
const PANEL_H := 372.0
const PAD := 30.0
const BTN_W := 200.0
const BTN_H := 46.0
const GAP := 14.0

const COL_DIM := Color(0.0, 0.0, 0.0, 0.56)
const COL_PANEL := Color("1c211d")
const COL_EDGE := Color("6b5a3a")
const COL_TITLE := Color("e8dcc0")
const COL_BODY := Color("b9b7a8")
const COL_BTN := Color("2a312b")
const COL_BTN_HL := Color("3a4438")

static var _open := false

var _hover := -1
var _title_lb: Label = null
var _body_lb: Label = null


# ------------------------------------------------------------ 入口

static func maybe_ask() -> void:
	## 唯一入口：发布版 + 还没回答过 + 有窗口，才弹。
	## 标题页 `_ready` 调一次就够 —— 它不会被每帧调用，也不会重复建节点。
	if _open:
		return
	if not GameSettings.needs_telemetry_ask():
		return
	if DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 92          # 高于设置浮层（80 档），低于最强制的转场黑幕
	tree.root.add_child(layer)
	# ⚠️ 用 `load()` 而不是 `TelemetryConsent.new()`：静态函数里引用自身 class_name
	#    在 `--check-only` 单文件解析时会报「Identifier not found」（同 `StoryUnlockToast`）。
	layer.add_child(load("res://scripts/telemetry_consent.gd").new())
	_open = true


static func is_open() -> bool:
	return _open


# ------------------------------------------------------------ 构建

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var font := UiTheme.font()
	var font_bold := UiTheme.font_bold()
	var p := _panel_rect()
	var inner_x := p.position.x + PAD
	var inner_w := p.size.x - PAD * 2.0

	_title_lb = Label.new()
	_title_lb.text = L10n.t("privacy.title")
	_title_lb.add_theme_font_override("font", font_bold)
	_title_lb.add_theme_font_size_override("font_size", 24)
	_title_lb.add_theme_color_override("font_color", COL_TITLE)
	_title_lb.position = Vector2(inner_x, p.position.y + PAD)
	_title_lb.size = Vector2(inner_w, 34)
	_title_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title_lb)

	_body_lb = Label.new()
	_body_lb.text = L10n.t("privacy.body")
	_body_lb.add_theme_font_override("font", font)
	_body_lb.add_theme_font_size_override("font_size", 16)
	_body_lb.add_theme_color_override("font_color", COL_BODY)
	_body_lb.position = Vector2(inner_x, p.position.y + PAD + 46)
	_body_lb.size = Vector2(inner_w, p.size.y - PAD * 2.0 - 46 - BTN_H - 18)
	_body_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lb.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_body_lb)

	# 入场：整块淡入（不做位移 —— 标题页背景本来就在动，再叠一层会很花）
	modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.22)
	queue_redraw()


func _panel_rect() -> Rect2:
	var w := minf(PANEL_W, size.x - 48.0)
	var h := minf(PANEL_H, size.y - 48.0)
	return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)


func _btn_rects() -> Array[Rect2]:
	## 画与点共用的几何唯一口（同 `settings_scene._vol_rects()` 的做法）。
	var p := _panel_rect()
	var y := p.position.y + p.size.y - PAD - BTN_H
	var cx := p.position.x + p.size.x * 0.5
	return [
		Rect2(cx - BTN_W - GAP * 0.5, y, BTN_W, BTN_H),
		Rect2(cx + GAP * 0.5, y, BTN_W, BTN_H),
	]


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COL_DIM)
	var p := _panel_rect()
	draw_rect(p, COL_PANEL)
	draw_rect(p, COL_EDGE, false, 2.0)
	var font_bold := UiTheme.font_bold()
	var labels := [L10n.t("privacy.agree"), L10n.t("privacy.decline")]
	var rects := _btn_rects()
	for i in rects.size():
		var r: Rect2 = rects[i]
		draw_rect(r, COL_BTN_HL if _hover == i else COL_BTN)
		draw_rect(r, COL_EDGE, false, 1.0)
		var txt: String = labels[i]
		var fs := 17
		var tw := font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font_bold, r.position + Vector2((r.size.x - tw.x) * 0.5, r.size.y * 0.5 + 6),
				txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_TITLE)


# ------------------------------------------------------------ 输入

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		var h := -1
		var rects := _btn_rects()
		for i in rects.size():
			if rects[i].has_point(m.position):
				h = i
		if h != _hover:
			_hover = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h >= 0 \
					else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var rects2 := _btn_rects()
			for i in rects2.size():
				if rects2[i].has_point(mb.position):
					_answer(i == 0)
					accept_event()
					return


# ------------------------------------------------------------ 收尾

func _answer(agree: bool) -> void:
	GameSettings.set_telemetry_opt_in(1 if agree else 2)
	Telemetry.flush()
	_open = false
	var layer := get_parent()
	queue_free()
	if layer != null:
		layer.queue_free()
