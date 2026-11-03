class_name UiToast
extends CanvasLayer
## 通用轻提示唯一口（R151 批 2 · P2-17，动效设计 §五-17）——
## 非战斗场景的轻反馈（「已保存」「回放开始」「已删除」…）：`UiToast.toast("文本")`。
## 底部居中**硬边**深色小胶囊 + 亮字，1.6s，两端各 180ms 淡入淡出；多条往上叠。
##
## 美术纪律（规范 §3）：硬边色块、无辉光；金边不用（金 = 稀有 / 奖励语义）。
## class_name + 懒实例（同 SceneFx：`--headless --script` 烟测没有 autoload，懒实例自建）。
## layer = 99：SceneFx(100) 之下、各界面覆盖层之上 —— **跨场景切换它还在**（转场不遮提示）。

const DUR_MS := 1600
const FADE_MS := 180.0
const PILL_BG := Color(0.05, 0.045, 0.04, 0.92)
const PILL_LINE := Color(1.0, 0.95, 0.80, 0.22)
const PILL_TXT := Color("f2ecdd")

static var _inst: UiToast = null

var _items: Array = []     # {text, start, dur}
var _cv: Control = null
var _font: Font = null


static func toast(text: String, dur := DUR_MS) -> void:
	## 唯一入口。没有场景树（纯逻辑测试）时静默丢弃，不崩。
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	if _inst == null:
		_inst = load("res://scripts/ui_toast.gd").new()
		tree.root.add_child(_inst)
	_inst._push(text, dur)


func _ready() -> void:
	layer = 99
	_font = ThemeDB.fallback_font
	_cv = Control.new()
	_cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cv.draw.connect(_on_draw)
	add_child(_cv)


func _push(text: String, dur: int) -> void:
	_items.append({"text": text, "start": Time.get_ticks_msec(), "dur": dur})
	_cv.queue_redraw()


func _process(_delta: float) -> void:
	if _items.is_empty():
		return
	var n := Time.get_ticks_msec()
	_items = _items.filter(func(it): return n - int(it.start) < int(it.dur))
	_cv.queue_redraw()


func _on_draw() -> void:
	var n := Time.get_ticks_msec()
	var y := _cv.size.y - 64.0
	for it in _items:
		var age := n - int(it.start)
		var left := int(it.dur) - age
		var a := clampf(minf(float(age), float(left)) / FADE_MS, 0.0, 1.0)
		_draw_pill(Vector2(_cv.size.x / 2.0, y), str(it.text), a)
		y -= 40.0


func _draw_pill(center: Vector2, text: String, alpha: float) -> void:
	var px := 14
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var r := Rect2(center.x - tw / 2.0 - 14.0, center.y - 13.0, tw + 28.0, 26.0)
	_cv.draw_rect(r, Color(PILL_BG.r, PILL_BG.g, PILL_BG.b, PILL_BG.a * alpha), true)
	_cv.draw_rect(r, Color(PILL_LINE.r, PILL_LINE.g, PILL_LINE.b, PILL_LINE.a * alpha), false, 1.0)
	_cv.draw_string(_font, Vector2(r.position.x + 14.0, center.y + 5.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(PILL_TXT.r, PILL_TXT.g, PILL_TXT.b, alpha))
