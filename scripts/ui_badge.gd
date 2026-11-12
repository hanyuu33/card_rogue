extends Control
## 「有新东西」提示点（R590）—— 金色圆点 + 数字。
##
## 两处用它，画法只此一份：
##   * 真按钮上：`UiBadge.attach(btn, n)` 挂一个子控件，贴着按钮右上角
##     （按钮在 VBoxContainer 里会被重排，所以用锚点贴右、不用固定坐标）；
##   * 自绘行上：`UiBadge.draw_badge(canvas, center, n, font)` 直接画
##     （百科页的条目行是 `_draw()` 画的，没法挂控件）。
##
## 为什么不写成 Label + Panel：圆底要画圆、数字要居中小字，控件组合反而更绕；
## 这里一个 `_draw()` 就说完了，且两条路径共用同一套颜色与半径。

const UiTheme = preload("res://scripts/ui_theme.gd")

const DOT_R := 11.0          # 圆的半径（控件尺寸 = 28×28，正好装下带外圈的点）
const RING_W := 2.0          # 外圈白边：浅色纸底上也要能看清边界
const FS := 13               # 数字字号
const COL_DOT := Color("c8951c")     # 金：与 PAGE_INK / 描金同一套语汇
const COL_RING := Color("fdf8ec")
const COL_INK := Color("2b2317")

var count := 0

var _font: Font


static func attach(btn: Control, n: int) -> Control:
	## 给按钮挂一个提示点（按钮已有 Badge 子节点就复用，别叠两个）。
	if btn == null:
		return null
	var old := btn.get_node_or_null("Badge")
	if old != null:
		# 复用已有的：本脚本没有 class_name，静态类型上取不到 set_count → 走 call()。
		old.call("set_count", n)
		return old as Control
	var b: Control = load("res://scripts/ui_badge.gd").new()
	b.name = "Badge"
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 提示点不许挡住按钮点击
	btn.add_child(b)
	# 贴右上角：锚点固定在父控件右上，尺寸变化（VBox 重排 / 窗口缩放）自动跟随。
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 0.0
	b.anchor_bottom = 0.0
	b.offset_left = -12.0
	b.offset_right = 16.0
	b.offset_top = -12.0
	b.offset_bottom = 16.0
	b.call("set_count", n)
	return b


func set_count(n: int) -> void:
	count = maxi(0, n)
	visible = count > 0
	queue_redraw()


func _draw() -> void:
	draw_badge(self, size * 0.5, count, font())


func font() -> Font:
	if _font == null:
		_font = UiTheme.font_bold()
	return _font


static func draw_badge(canvas: CanvasItem, center: Vector2, n: int, f: Font) -> void:
	## 圆点唯一画法。`n <= 0` → 什么都不画（调用方不必先判空）。
	if canvas == null or n <= 0:
		return
	canvas.draw_circle(center, DOT_R + RING_W, COL_RING, true)
	canvas.draw_circle(center, DOT_R, COL_DOT, true)
	if f == null:
		return
	# 两位以上就写「9+」—— 圆点只有 22px，塞不下更长数字（也没人在意具体几段）。
	var t := str(n) if n < 10 else "9+"
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	canvas.draw_string(f, center + Vector2(-w * 0.5, FS * 0.36), t,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FS, COL_INK)
