class_name TutorialOverlay
extends CanvasLayer
## R744：新手教程的**唯一弹层**。
##
## 口径（用户定的三条）：
##   ① 教程**绑初次体验、不绑关卡** —— 关卡数据里那套 `tutorial` 数组是休眠代码，
##      这里只认 `ProfileData.tutorial_seen`。
##   ② 高亮区以外压暗 —— 玩家一眼知道「现在只讲这一块」。
##   ③ 悬浮对话框写文字 —— 左上角一个小头像（卷卷），右边正文，点击翻页。
##
## 用法（任意 Control 场景里）：
##     TutorialOverlay.play(self, pages, _on_done)
##   `pages` = [{ "text": "...", "cue": "hand" }, ...]
##   `cue` 交给宿主的 `tutorial_cue_rects(cue)` 解析成**屏幕坐标**矩形数组；
##   返回空数组 = 本页整屏压暗（不挖洞）。
##
## ⚠️ 坐标：本层是 CanvasLayer，坐标 = 屏幕坐标。宿主在 1280 舞台里算出来的矩形
##    必须自己加上舞台原点（`UiTheme.stage_origin()`）再返回 —— 见各场景的
##    `tutorial_cue_rects()`。
## ⚠️ 挖洞用「横条法」逐条画遮罩（见 `_draw_dim`）：四条带子拼洞在**多个洞**时会
##    互相叠加成黑块，而 CanvasItem 没有「擦除」混合模式；shader 那版在这台机器上
##    没生效（查不出是编译还是层序），所以退回纯绘制的条带法 —— 任意多洞都精确。

const UiTheme = preload("res://scripts/ui_theme.gd")

const PORTRAIT_PATH := "res://assets/ui/tutorial_quanquan.png"

const BOX_W := 940.0
const BOX_H := 172.0
const BOX_BOTTOM := 26.0
const PORTRAIT_SIZE := 84.0     # 「小一点」：不抢正文
const PORTRAIT_LIFT := 26.0     # 头像上顶出框外，别像贴纸
const TEXT_X := 116.0           # 正文起笔 = 边距 14 + 头像 84 + 间距 18
const PAD := 14.0

const DIM_ALPHA := 0.66         # 洞外压暗
const HOLE_ALPHA := 0.12        # 洞内也压一点，避免高亮区跳出来太亮
const FS_TITLE := 21
const FS_BODY := 18
const LINE_H := 27.0
const CPS := 46.0               # 打字机速度（字/秒）

var _ctrl: Control
var _pages: Array = []
var _idx := 0
var _on_done := Callable()
var _host: Node
var _font: Font
var _font_bold: Font
var _shown := 0.0
var _total := 0
var _lines := PackedStringArray()
var _prev_paused := false
var _pause := true
var _closed := false
var _t := 0.0
var _portrait: Texture2D


static func play(host: Node, pages: Array, on_done := Callable(),
		pause := true) -> TutorialOverlay:
	## pause=false 只给**出图验收**用（战斗页的截图按帧号触发，暂停整棵树就截不到）。
	if host == null or pages.is_empty():
		return null
	var v := TutorialOverlay.new()
	v._host = host
	v._pages = pages
	v._on_done = on_done
	v._pause = pause
	host.add_child(v)
	return v


func _init() -> void:
	layer = 60
	name = "TutorialOverlay"   # 与 TutorialDirector.OVERLAY_NAME 对齐（判重用）
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	_prev_paused = get_tree().paused
	if _pause:
		get_tree().paused = true

	# 绘制层：压暗 + 描边 + 对话框都由它自己画
	_ctrl = Control.new()
	_ctrl.name = "TutorialCanvas"
	_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP   # 吃掉点击，别让底下的棋盘接住
	_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctrl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ctrl)
	_ctrl.draw.connect(_on_draw)
	_show_page(0)


func _exit_tree() -> void:
	if not _closed:
		get_tree().paused = _prev_paused


# ------------------------------------------------------------ 页面推进

func _show_page(i: int) -> void:
	_idx = clampi(i, 0, _pages.size() - 1)
	var text := str(_pages[_idx].get("text", ""))
	_lines = _wrap(text, _font, FS_BODY, _text_width())
	_total = 0
	for ln in _lines:
		_total += ln.length()
	_shown = 0.0
	_ctrl.queue_redraw()


func _text_width() -> float:
	return BOX_W - TEXT_X - PAD - 6.0


func _advance() -> void:
	if _shown < float(_total):
		_shown = float(_total)
		_ctrl.queue_redraw()
		return
	if _idx + 1 < _pages.size():
		_show_page(_idx + 1)
	else:
		_close()


func _close() -> void:
	if _closed:
		return
	_closed = true
	if _pause:
		get_tree().paused = _prev_paused
	if _on_done.is_valid():
		_on_done.call()
	queue_free()


func _input(event: InputEvent) -> void:
	if _closed:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).keycode
		if k == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
		elif k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
			_advance()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_close()                     # 右键 = 跳过整套
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_advance()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_advance()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	if _shown < float(_total):
		_shown = minf(float(_total), _shown + CPS * delta)
		_ctrl.queue_redraw()
	elif fmod(_t, 0.8) < delta:
		_ctrl.queue_redraw()


# ------------------------------------------------------------ 高亮

func _cues() -> Array:
	var cue := str(_pages[_idx].get("cue", ""))
	if cue == "" or _host == null or not _host.has_method("tutorial_cue_rects"):
		return []
	var r: Variant = _host.call("tutorial_cue_rects", cue)
	return r if r is Array else []


func _draw_dim(vp: Vector2, holes: Array) -> void:
	## 「高亮区以外压暗」的**唯一画法**：把屏幕按所有洞的上下边界切成横条，
	## 每条里求出洞覆盖的 x 区间、取补集，只画补集。
	## 为什么不用 shader / 不用四条带子：
	##   · 四条带子拼洞在**多个洞**时会互相叠加，重叠处黑成一块（手牌 5 张就是 5 个洞）；
	##   · ColorRect + shader 在这台机器上不生效，查不出是编译还是层序问题，
	##     与其留个「有时不压暗」的坑，不如用纯绘制 —— 条带法任意多洞都精确。
	if holes.is_empty():
		_ctrl.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, DIM_ALPHA))
		return
	var ys: Array = [0.0, vp.y]
	for r0: Rect2 in holes:
		var r := r0 as Rect2
		ys.append(clampf(r.position.y, 0.0, vp.y))
		ys.append(clampf(r.end.y, 0.0, vp.y))
	ys.sort()
	var dim := Color(0, 0, 0, DIM_ALPHA)
	for i in ys.size() - 1:
		var y0 := float(ys[i])
		var y1 := float(ys[i + 1])
		if y1 - y0 < 0.01:
			continue
		# 本横条里，洞覆盖的 x 区间
		var spans: Array = []
		for r0: Rect2 in holes:
			var r := r0 as Rect2
			if y0 >= r.position.y - 0.01 and y1 <= r.end.y + 0.01:
				spans.append(Vector2(clampf(r.position.x, 0.0, vp.x),
						clampf(r.end.x, 0.0, vp.x)))
		spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var x := 0.0
		for sp: Vector2 in spans:
			if sp.x > x:
				_ctrl.draw_rect(Rect2(x, y0, sp.x - x, y1 - y0), dim)
			x = maxf(x, sp.y)
		if x < vp.x:
			_ctrl.draw_rect(Rect2(x, y0, vp.x - x, y1 - y0), dim)


# ------------------------------------------------------------ 绘制

func _box_rect() -> Rect2:
	## 对话框默认贴在舞台下沿。但高亮目标经常就在下半屏（地图下方的格子、
	## 战斗里的手牌一排），贴下沿会**正好盖住它在讲的东西**。
	## 所以这里两侧都算一遍重叠面积，挑重叠小的那侧 —— 顶部 / 底部二选一，
	## 不做任意摆位（那样每页位置都变，读起来晃）。
	var vp := _ctrl.size
	var stage_w := minf(UiTheme.STAGE_W, vp.x)
	var ox := UiTheme.stage_origin(vp).x
	var oy := UiTheme.stage_origin(vp).y
	var bw := minf(BOX_W, stage_w - 40.0)
	var x := ox + (stage_w - bw) * 0.5
	var y_bot := vp.y - BOX_BOTTOM - BOX_H
	var y_top := oy + 18.0
	var holes := _cues()
	var best_y := y_bot
	var best := -1.0
	for cand: float in [y_bot, y_top]:
		var br := Rect2(x, cand, bw, BOX_H)
		var ov := 0.0
		for r0: Rect2 in holes:
			ov += _overlap_area(br, r0 as Rect2)
		if best < 0.0 or ov < best:
			best = ov
			best_y = cand
	return Rect2(x, best_y, bw, BOX_H)


static func _overlap_area(a: Rect2, b: Rect2) -> float:
	var w := maxf(0.0, minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x))
	var h := maxf(0.0, minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y))
	return w * h


func _on_draw() -> void:
	var rects := _cues()
	# 先压暗（洞外深、洞内浅），再画高亮框，最后画对话框
	_draw_dim(_ctrl.size, rects)
	for r1: Rect2 in rects:
		_ctrl.draw_rect(r1 as Rect2, Color(0, 0, 0, HOLE_ALPHA))
	# 高亮框：双层描边 + 呼吸，压暗层之上一眼就看得见
	var pulse := 0.5 + 0.5 * sin(_t * 3.2)
	for r0: Rect2 in rects:
		var r := (r0 as Rect2).grow(3.0)
		_ctrl.draw_rect(r, Color(1.0, 0.85, 0.50, 0.55 + 0.35 * pulse), false, 2.6)
		_ctrl.draw_rect(r.grow(3.0), Color(1.0, 0.85, 0.50, 0.14 + 0.10 * pulse), false, 1.2)
	_draw_box()


func _draw_box() -> void:
	var box := _box_rect()
	for i in 3:
		_ctrl.draw_rect(box.grow(float(i) * 3.0 + 2.0), Color(0, 0, 0, 0.10), false, 6.0)
	UiTheme.draw_panel_bg(_ctrl, box)
	_ctrl.draw_rect(box, Color(0.36, 0.27, 0.16, 0.90), false, 1.6)
	_ctrl.draw_rect(box.grow(-4.0), Color(0.79, 0.70, 0.49, 0.55), false, 1.0)

	# 头像：压住左上角，略微顶出框外
	var p := Rect2(box.position + Vector2(PAD, -PORTRAIT_LIFT),
			Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE))
	if _portrait == null:
		_portrait = load(PORTRAIT_PATH) as Texture2D
	if _portrait != null:
		_ctrl.draw_texture_rect(_portrait, p, false)

	var tx := box.position.x + TEXT_X
	var ty := box.position.y + 30.0
	_ctrl.draw_string(_font_bold, Vector2(tx, ty), "卷卷", HORIZONTAL_ALIGNMENT_LEFT, -1,
			FS_TITLE, Color("6b4f2a"))
	var nw := _font_bold.get_string_size("卷卷", HORIZONTAL_ALIGNMENT_LEFT, -1, FS_TITLE).x
	_ctrl.draw_line(Vector2(tx + nw + 10.0, ty - 6.0),
			Vector2(box.end.x - PAD, ty - 6.0), Color(0.72, 0.60, 0.36, 0.45), 1.0)

	var left := int(_shown)
	var y := box.position.y + 58.0
	for ln: String in _lines:
		if left <= 0:
			break
		var seg: String = ln if ln.length() <= left else ln.substr(0, left)
		left -= ln.length()
		_ctrl.draw_string(_font, Vector2(tx, y), seg, HORIZONTAL_ALIGNMENT_LEFT,
				_text_width(), FS_BODY, UiTheme.PAGE_INK)
		y += LINE_H

	var hint := "点击继续" if _idx + 1 < _pages.size() else "开始吧"
	if _shown < float(_total):
		hint = "点击显示全文"
	var foot := "%s   %d/%d" % [hint, _idx + 1, _pages.size()]
	var fw := _font.get_string_size(foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var fa := 0.55 + 0.35 * sin(_t * 2.6)
	_ctrl.draw_string(_font, Vector2(box.end.x - PAD - fw, box.end.y - 14.0), foot,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.35, 0.30, 0.22, 0.55 + 0.35 * fa))
	_ctrl.draw_string(_font, Vector2(tx, box.end.y - 14.0), "右键 / Esc 跳过",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.42, 0.36, 0.26, 0.45))


# ------------------------------------------------------------ 折行

func _wrap(text: String, face: Font, fs: int, width: float) -> PackedStringArray:
	## 手动折行：`draw_multiline_string` 会按整段重排，打字机时字会「跳行」。
	## 这里一次算死，之后只按字数截断，绝不回流。CJK 逐字断，ASCII 按词断。
	var out := PackedStringArray()
	for para: String in text.split("\n"):
		var cur := ""
		var i := 0
		while i < para.length():
			var ch := para[i]
			var unit := ch
			if _is_ascii_word_char(ch) and ch != " ":
				var j := i + 1
				while j < para.length() and _is_ascii_word_char(para[j]) and para[j] != " ":
					unit += para[j]
					j += 1
				i = j
			else:
				i += 1
			var probe := cur + unit
			if cur != "" and face.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1,
					fs).x > width:
				out.append(cur)
				cur = unit.strip_edges(true, false)
			else:
				cur = probe
		out.append(cur)
	return out


static func _is_ascii_word_char(c: String) -> bool:
	if c == "":
		return false
	return c.unicode_at(0) < 128 and c.unicode_at(0) > 32
