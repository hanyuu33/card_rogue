extends Control
## R417 / R420：左栏明细滚动视口的**裁剪容器**。
##
## 父节点（BattleScene）每帧把要画的块与参数塞进来，再 `queue_redraw()`；
## 本节点 `clip_contents = true` 把越界的块 / 文本**像素级裁掉**
## （Godot 4 没有 `draw_set_clip`，`Control.clip_contents` 是官方裁剪手段，
## 且裁剪区起点 = 视口顶 `blocks_top`，天然不会盖到上方表头、下方提示）。
##
## ⚠️ R420：`clip_contents` **只裁子节点**，不会裁自身的 `_draw` ——
## 所以本节点是个空容器，真正落笔的是里面那个 `_canvas` 子节点（`draw` 信号）。
## 一开始写成「自己 `_draw` + clip_contents」是不生效的（当时父节点还用了不存在的
## `draw_set_clip`，两头都没裁住，详情一长就糊到表头上）。
##
## 坐标：父节点把内容按**屏幕坐标**算，画布本地坐标 = 屏幕坐标 - position；
## 命中矩形（悬停「提及」用）画完再 +position 转回屏幕坐标交还父节点。

const CardInfoBoxes = preload("res://scripts/card_info_boxes.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

var _canvas: Control
var _blocks: Array = []
var _left := 0.0
var _inner_w := 0.0
var _size := 0
var _scroll := 0.0
var _avail := 0.0
var _hits: Array = []
var _show_top_hint := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_canvas_draw)
	add_child(_canvas)


func _notification(what: int) -> void:
	# 裁剪矩形跟着本容器走；内部画布同步尺寸，避免出现「画布比视口小」时内容被二次截断。
	if what == NOTIFICATION_RESIZED and _canvas != null:
		_canvas.size = size


func render(blocks: Array, left: float, inner_w: float, size: int, scroll: float,
		avail: float, hits: Array, show_top_hint: bool) -> void:
	_blocks = blocks
	_left = left - position.x
	_inner_w = inner_w
	_size = size
	_scroll = scroll
	_avail = avail
	_hits = hits
	_show_top_hint = show_top_hint
	if _canvas != null:
		# ⚠️ 这里别写 `_canvas.size = size` —— 形参 `size` 是**字号**（int），
		# 赋给 Vector2 属性会直接 Parse Error（整份脚本挂不上，`render` 就成了
		# 「Nonexistent function」。R420 踩过）。画布尺寸只影响布局，不影响绘制坐标。
		_canvas.size = Vector2(_inner_w, _avail)
		_canvas.queue_redraw()


func _on_canvas_draw() -> void:
	## 真正落笔的地方 —— 只有挂在带 `clip_contents` 的父节点下才会被裁。
	var cv: CanvasItem = _canvas
	CardInfoBoxes.draw_all(cv, _blocks, _left, 0.0, _inner_w, _size, -1.0, _hits,
			_scroll, 0.0, _avail)
	# 命中矩形转回屏幕坐标（父节点用屏幕坐标做悬停判定）
	for h: Dictionary in _hits:
		if h.has("rect"):
			h["rect"].position += position
	if _show_top_hint:
		_draw_top_hint(cv)


func _draw_top_hint(cv: CanvasItem) -> void:
	## 「▲ 上滑查看」：已经滚下去、上面还有内容。画在裁剪区顶部内侧，位于块之上。
	var cx := _left + _inner_w / 2.0
	var pw := 138.0
	var ph := 20.0
	var r := Rect2(cx - pw / 2.0, 5.0, pw, ph)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.10, 0.88)
	sb.border_color = Color("caa24a")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	cv.draw_style_box(sb, r)
	var font := UiTheme.font_bold()
	var fs := 18
	cv.draw_string(font, Vector2(cx, r.get_center().y + font.get_ascent(fs) * 0.5),
			"▲ 上滑查看", HORIZONTAL_ALIGNMENT_CENTER, pw, fs, Color("ffe6a8"))
