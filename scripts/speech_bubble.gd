extends RefCounted
## R386 战场对话气泡 —— 让格子里的卡「说话」。
##
## 用户口径（R386）：「做一个完整的对话气泡动画，以便战场中的卡片可以说话。
## 需要可以随意添加文字，自适应大小，有弹出气泡动画和结束动画，文字要流式出现，
## 气泡要符合游戏风格。」
##
## ## 为什么是自绘 RefCounted，而不是 Control 场景节点
## `battle_scene` 是**一层 `_draw` 画到底**的（背景 → 棋盘 → 卡牌 → 遮罩 → 面板 → 手牌）。
## 气泡必须夹在「卡牌之上、手牌与左栏详情之下」这一层，加子节点会盖住父级的**全部**
## 绘制（含手牌和详情栏）。另外气泡位置要跟着棋盘滚动 / 震屏一起动 —— 只有活在
## `_draw` 里、并且每帧用 `_cell_rect()` 现算锚点，才天然跟得动。
## 所以本文件只有「布局 + 时间轴 + 画」三件事，谁持有、何时画由调用方决定。
##
## ## 时间轴（毫秒，`t0` 起算）
## ```
##   0        POP_MS                        hold_end          end
##   ├─ 弹出 ─┼─ 流式吐字 ────────────────┼── 停留 ──┼─ 收起 ─┤
##   │        │ 每字 TYPE_MS，末尾闪烁光标 │  按字数  │ 缩+淡出 │
## ```
## · 弹出：`scale` 0.72 → 1（ease-out-back，峰值约 1.09 的轻微过冲）+ 淡入，
##   变换中心是**锚点**（卡片顶部）→ 看起来是从卡里「冒」出来的。
## · 流式吐字：从弹出的 72% 处开始，避免「先弹完一个空气泡、再忽然蹦字」。
## · 收起：`scale` → 0.94、上浮 5px、淡出 —— 缩回去而不是炸开，收得干净。
##
## ## 自适应大小
## 折行走全工程唯一口 `TextWrap.wrap_plain`（禁则 / 西文成词 / 标点前置都由它保证），
## 再按「最长行宽 + 内距」定宽度，clamp 到 `[MIN_W, MAX_W]`；超过 `MAX_LINES` 行就
## 在第 5 行末尾加「…」（气泡不许长成一面墙）。
##
## ## 风格
## 羊皮纸奶油底（与卡面纸底同一族）+ 深褐描边 + 内圈淡金线 + 彩色尾巴（尾巴染成
## 说话者的颜色：我方绿 / 敌方红 / 卡牌职业色）。填充用**顶点色渐变**（上浅下深），
## 三角化后逐三角带顶点色，跨三角形连续、不会出现色带。

const UiTheme = preload("res://scripts/ui_theme.gd")

# ---------------------------------------------------------------- 版式
const PAD_X := 10.0             ## 左右内距
const PAD_Y := 7.0              ## 上下内距
const RADIUS := 10.0            ## 圆角半径
const ARC_SEG := 5              ## 每个圆角的折线段数（5 段≈肉眼无棱）
const TAIL_W := 14.0            ## 尾巴根部宽
const TAIL_H := 9.0             ## 尾巴伸出长度
const GAP := 7.0                ## 尾巴尖与卡片顶边的间隙
const EDGE := 5.0               ## 气泡与容器（棋盘可视窗）的最小留白
const MAX_W := 268.0            ## 最大宽度（棋盘 3 列共 372，够放下跨两格的话）
const MIN_W := 78.0             ## 最小宽度（「嗯。」这种短句也不许挤成竖条）
const MAX_LINES := 5            ## 最多 5 行，超出截断加「…」
const LINE_SPACING := 1.14      ## 行距倍率（基准 = 字体 height）
const FS := 14                  ## 字号：与 UiTheme.FS_LABEL 对齐（卡面 9 / 徽标 12 之上一档）

# ---------------------------------------------------------------- 时序（毫秒）
const POP_MS := 210             ## 弹出时长
const TYPE_MS := 26             ## 每字吐字间隔（中文 26ms ≈ 38 字/秒）
const TYPE_FROM := 0.72         ## 弹出进行到 72% 就开始吐字
const HOLD_MIN_MS := 780        ## 停留保底（再短的句子也给人留出阅读时间）
const HOLD_PER_CHAR_MS := 44    ## 停留按字数线性增加
const OUT_MS := 190             ## 收起时长
const POP_FROM := 0.72          ## 弹出起始缩放
const OUT_TO := 0.94            ## 收起终了缩放
const OUT_LIFT := 5.0           ## 收起时上浮像素

# ---------------------------------------------------------------- 配色
const COL_TOP := Color("f8f1de")                        ## 纸面：上（受光）
const COL_BOT := Color("ebdfc2")                        ## 纸面：下（背光）
const COL_LINE := Color("574433")                       ## 外描边（与卡框同色）
const COL_GOLD := Color(0.78, 0.68, 0.45, 0.70)         ## 内圈淡金线
const COL_TEXT := Color("2a241b")                       ## 正文
const COL_SHADOW := Color(0.10, 0.08, 0.05, 0.15)       ## 投影
const COL_CURSOR := Color("a8621f")                     ## 吐字光标

# ---------------------------------------------------------------- 状态
var text := ""                          ## 要说的话（可随时改，改完 `restart()`）
var t0 := 0                             ## 本句起始时刻（毫秒，`Time.get_ticks_msec()` 口径）
var speaker := Color("8a5f00")          ## 说话者色（只用于尾巴）
var cell := Vector2i(-1, -1)            ## 说话者所在格（调用方标记，本文件不读）
var queue: Array[String] = []           ## 同一张卡连着说的话，排队一句句说

var _font: Font
var _lines: Array[String] = []
var _w := MAX_W
var _h := 0.0
var _laid := false
var _n_chars := 0
var _tail_up := false                   ## 本帧尾巴朝向（true = 气泡在卡片下方）


func _init(p_font: Font = null) -> void:
	_font = p_font if p_font != null else UiTheme.font()


## 换一句话（队列推进 / 手动重说）—— 重新折行、时间轴归零。
func restart(p_text: String, now_ms: int) -> void:
	text = p_text
	t0 = now_ms
	_laid = false
	_lines = []
	_h = 0.0


## 往队列里排一句（当前这句说完自动接上）。
func stack(t: String) -> void:
	if t.strip_edges() == "":
		return
	queue.append(t)


func has_queue() -> bool:
	return not queue.is_empty()


func elapsed(now_ms: int) -> int:
	return now_ms - t0


## 整句（含停留与收起）总共要多久 —— 调用方排期 / 测试都用这个。
func total_ms() -> int:
	_ensure_layout()
	return int(float(POP_MS) * TYPE_FROM) + _n_chars * TYPE_MS \
			+ HOLD_MIN_MS + _n_chars * HOLD_PER_CHAR_MS + OUT_MS


## 这一句是否已经彻底演完（可以接下一句 / 可以回收）。
func is_finished(now_ms: int) -> bool:
	_ensure_layout()
	return elapsed(now_ms) >= total_ms()


## 当前应该露出几个字（流式吐字的唯一判据）。
func visible_chars(now_ms: int) -> int:
	_ensure_layout()
	var el := elapsed(now_ms)
	if el < 0:
		return 0
	var type_t0 := int(float(POP_MS) * TYPE_FROM)
	if el <= type_t0:
		return 0
	return clampi((el - type_t0) / TYPE_MS, 0, _n_chars)


# ================================================================ 绘制

## 唯一绘制口。`anchor` = 说话那张卡的**顶边中心**（每帧由调用方按棋格现算，
## 于是气泡天然跟着滚动 / 震屏走）；`bounds` = 允许出现的矩形容器（棋盘可视窗）。
func draw(cv: CanvasItem, now_ms: int, anchor: Vector2, bounds: Rect2) -> void:
	if cv == null or text == "":
		return
	_ensure_layout()
	var el := elapsed(now_ms)
	if el < 0 or el >= total_ms():
		return

	var type_end := int(float(POP_MS) * TYPE_FROM) + _n_chars * TYPE_MS
	var hold_end := type_end + HOLD_MIN_MS + _n_chars * HOLD_PER_CHAR_MS

	# ---- 时间轴 → 缩放 / 位移 / 透明度 ----
	var pop_t := clampf(float(el) / float(POP_MS), 0.0, 1.0)
	var out_t := clampf(float(el - hold_end) / float(OUT_MS), 0.0, 1.0)
	var sc := lerpf(POP_FROM, 1.0, _ease_out_back(pop_t))
	sc *= lerpf(1.0, OUT_TO, _ease_in_quad(out_t))
	var alpha := clampf(pop_t * 2.2, 0.0, 1.0) * (1.0 - _ease_in_quad(out_t))
	if alpha <= 0.01:
		return
	var lift := -OUT_LIFT * _ease_in_quad(out_t)

	# ---- 定位 ----
	var box := _place(anchor, bounds)
	var tx := _tail_x(box, anchor.x)      # 尾巴跟着说话者走，不钉在气泡中心
	var c := anchor                       # 变换中心 = 卡顶（气泡从卡里冒出来）
	var pts := _outline(box, _tail_up, false, tx)
	for i in pts.size():
		pts[i] = c + (pts[i] - c) * sc + Vector2(0.0, lift)

	# ---- 投影（先画，露在主体外的那一圈就是影子）----
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0.0, 3.0))
	_fill_poly(cv, shadow, COL_SHADOW, COL_SHADOW, alpha)

	# ---- 纸面（顶点色上下渐变）----
	_fill_poly(cv, pts, COL_TOP, COL_BOT, alpha)

	# ---- 尾巴染色（说话者色）----
	var tail := _tail_tri(box, _tail_up, tx)
	var ts := Color(speaker, 0.55)
	var tail_x := PackedVector2Array()
	for p in tail:
		tail_x.append(c + (p - c) * sc + Vector2(0.0, lift))
	_fill_poly(cv, tail_x, ts, ts)

	# ---- 外描边（连通轮廓，闭合）----
	var closed := PackedVector2Array(pts)
	if closed.size() > 0 and closed[closed.size() - 1].distance_to(closed[0]) > 0.01:
		closed.append(closed[0])
	cv.draw_polyline(closed, Color(COL_LINE, COL_LINE.a * alpha), 1.8, true)

	# ---- 内圈淡金线（缩进 2.5，不含尾巴）----
	var inner := _outline(box.grow(-2.5), _tail_up, true)
	for i in inner.size():
		inner[i] = c + (inner[i] - c) * sc + Vector2(0.0, lift)
	if inner.size() > 2:
		if inner[inner.size() - 1].distance_to(inner[0]) > 0.01:
			inner.append(inner[0])
		cv.draw_polyline(inner, Color(COL_GOLD, COL_GOLD.a * alpha), 1.0, true)

	# ---- 文字（流式）----
	_draw_text(cv, box, c, sc, lift, alpha, el)

	# ---- 吐字光标 ----
	var shown := visible_chars(now_ms)
	if shown > 0 and shown < _n_chars:
		var flick := 0.45 + 0.55 * absf(sin(float(el) / 110.0))
		var caret := _caret_pos(box, shown)
		caret = c + (caret - c) * sc + Vector2(0.0, lift)
		var fh := _line_h() * 0.86
		cv.draw_rect(Rect2(caret + Vector2(0.0, -fh * 0.78), Vector2(1.6, fh)),
				Color(COL_CURSOR, flick * alpha))


func _draw_text(cv: CanvasItem, box: Rect2, c: Vector2, sc: float, lift: float,
		alpha: float, el: int) -> void:
	var font := _font if _font != null else UiTheme.font()
	if font == null:
		return
	var shown := visible_chars(t0 + el)
	var col := Color(COL_TEXT, COL_TEXT.a * alpha)
	var lh := _line_h()
	var base_y := box.position.y + PAD_Y + font.get_ascent(FS)
	var remain := shown
	for i in _lines.size():
		var ln := _lines[i]
		var take := mini(remain, ln.length())
		remain = maxi(remain - ln.length(), 0)
		if take <= 0:
			continue
		var piece := ln.substr(0, take)
		var at := Vector2(box.position.x + PAD_X, base_y + float(i) * lh)
		at = c + (at - c) * sc + Vector2(0.0, lift)
		cv.draw_string(font, at, piece, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, col)


## 光标位置 = 当前可见文字的右端（与 `draw_string` 同一套测宽）。
func _caret_pos(box: Rect2, shown: int) -> Vector2:
	var font := _font if _font != null else UiTheme.font()
	if font == null:
		return box.position + Vector2(PAD_X, PAD_Y)
	var lh := _line_h()
	var remain := shown
	var last_i := 0
	var last_txt := ""
	for i in _lines.size():
		var ln := _lines[i]
		if remain <= 0:
			break
		var take := mini(remain, ln.length())
		last_i = i
		last_txt = ln.substr(0, take)
		remain -= ln.length()
	var w := 0.0
	if last_txt != "":
		w = font.get_string_size(last_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	return Vector2(box.position.x + PAD_X + w,
			box.position.y + PAD_Y + float(last_i) * lh + _line_h() * 0.5)


# ================================================================ 布局

func _ensure_layout() -> void:
	if _laid:
		return
	_laid = true
	var font := _font if _font != null else UiTheme.font()
	if font == null:
		var one: Array[String] = [text]
		_lines = one
		_w = MIN_W
		_h = PAD_Y * 2.0 + FS
		_n_chars = text.length()
		return
	var wrap_w := MAX_W - PAD_X * 2.0
	var raw := TextWrap.wrap_plain(font, text, wrap_w, FS)
	var out: Array[String] = []
	for ln in raw:
		out.append(ln)
	if out.is_empty():
		out.append("")
	if out.size() > MAX_LINES:
		var cut: Array[String] = []
		for k in MAX_LINES:
			cut.append(out[k])
		cut[MAX_LINES - 1] = _ellipsize(font, cut[MAX_LINES - 1], wrap_w)
		out = cut
	_lines = out
	var widest := 0.0
	for ln in _lines:
		widest = maxf(widest, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x)
	_w = clampf(widest + PAD_X * 2.0, MIN_W, MAX_W)
	_h = PAD_Y * 2.0 + _line_h() * float(maxi(_lines.size(), 1))
	_n_chars = 0
	for ln in _lines:
		_n_chars += ln.length()


func _line_h() -> float:
	var font := _font if _font != null else UiTheme.font()
	var base := float(FS)
	if font != null:
		base = font.get_height(FS)
	return base * LINE_SPACING


## 超行截断：从尾部删字直到「加省略号还放得下」。
func _ellipsize(font: Font, s: String, limit: float) -> String:
	var tail := "…"
	if font.get_string_size(s + tail, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x <= limit:
		return s + tail
	var cut := s
	while cut.length() > 1:
		cut = cut.substr(0, cut.length() - 1)
		if font.get_string_size(cut + tail, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x <= limit:
			break
	return cut + tail


## 气泡矩形：默认在卡片**上方**（尾巴朝下）；上方放不下就翻到下方。
## 水平以锚点为中心、并夹进容器；垂直再兜一次底（两面都放不下时宁可压住卡片）。
func _place(anchor: Vector2, bounds: Rect2) -> Rect2:
	_tail_up = false
	var top := anchor.y - GAP - _h
	# 上方只剩一条缝也翻到卡片下方 —— 「贴着顶边的一条」比「盖住卡片下半身」更难读
	if top < bounds.position.y + EDGE:
		_tail_up = true
		top = anchor.y + GAP
	var left := anchor.x - _w * 0.5
	left = clampf(left, bounds.position.x + EDGE, bounds.position.x + bounds.size.x - _w - EDGE)
	top = clampf(top, bounds.position.y + EDGE, bounds.position.y + bounds.size.y - _h - EDGE)
	return Rect2(left, top, _w, _h)


# ================================================================ 轮廓

## 连通轮廓（顺时针）：圆角矩形 + 一侧的三角尾巴。
## `flat` = true 时**不带尾巴**（内圈金线用）。
func _outline(box: Rect2, tail_up: bool, flat := false,
		tail_x := -1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x := box.position.x
	var y := box.position.y
	var w := box.size.x
	var h := box.size.y
	var r := minf(RADIUS, minf(w, h) * 0.5)
	var tx := tail_x if tail_x > 0.0 else x + w * 0.5

	# 顶边：左段 →（尾巴）→ 右段
	pts.append(Vector2(x + r, y))
	if not flat and not tail_up:
		pts.append(Vector2(tx - TAIL_W * 0.5, y))
		pts.append(Vector2(tx, y + TAIL_H))
		pts.append(Vector2(tx + TAIL_W * 0.5, y))
	pts.append(Vector2(x + w - r, y))
	_arc(pts, Vector2(x + w - r, y + r), r, -90.0, 0.0)      # 右上
	pts.append(Vector2(x + w, y + h - r))
	_arc(pts, Vector2(x + w - r, y + h - r), r, 0.0, 90.0)    # 右下
	if not flat and tail_up:
		pts.append(Vector2(tx + TAIL_W * 0.5, y + h))
		pts.append(Vector2(tx, y + h - TAIL_H))
		pts.append(Vector2(tx - TAIL_W * 0.5, y + h))
	pts.append(Vector2(x + r, y + h))
	_arc(pts, Vector2(x + r, y + h - r), r, 90.0, 180.0)      # 左下
	pts.append(Vector2(x, y + r))
	# ⚠️ 左上弧的**终点**正好等于整个轮廓的起点 (x+r, y)：再 append 就会出现
	# 首尾重合点 → 多边形退化，`draw_polygon` 每帧刷
	# 「Invalid polygon data, triangulation failed」。所以这段**不画终点**
	# （`include_end = false`），让首尾由闭合隐式连上 —— 只少 1/4 个圆角的最后
	# 一小段弦，肉眼无差，但三角化不再退化。
	_arc(pts, Vector2(x + r, y + r), r, 180.0, 270.0, ARC_SEG, false)   # 左上
	return pts


## 圆角折线（只 append，不另起数组）。
## `include_end = false` 时**不画 a1 那个端点** —— 用于「弧终点正好是整个轮廓
## 起点」的那一段（左上角），否则多边形首尾重合、`draw_polygon` 每帧报三角化失败。
func _arc(pts: PackedVector2Array, center: Vector2, r: float,
		a0: float, a1: float, n := ARC_SEG, include_end := true) -> void:
	if r <= 0.5:
		return
	var last := n if include_end else n - 1
	for i in range(1, last + 1):
		var a := deg_to_rad(lerpf(a0, a1, float(i) / float(n)))
		pts.append(center + Vector2(cos(a), sin(a)) * r)


## 尾巴的目标横坐标：adapter 把说话者卡片的中心夹进「气泡能长出尾巴的那一段」——
## 卡片贴边时气泡会被 clamp，尾巴若仍钉在气泡中心就会指歪 70px 以上。
func _tail_x(box: Rect2, want: float) -> float:
	var lo := box.position.x + RADIUS + TAIL_W * 0.5
	var hi := box.position.x + box.size.x - RADIUS - TAIL_W * 0.5
	if hi < lo:
		return box.position.x + box.size.x * 0.5
	return clampf(want, lo, hi)


## 尾巴三角形（根部往主体里插 1.5px，避免填充出现一条缝）。
func _tail_tri(box: Rect2, tail_up: bool, tail_x := -1.0) -> PackedVector2Array:
	var cx := box.position.x + box.size.x * 0.5
	if tail_x > 0.0:
		cx = tail_x
	var pts := PackedVector2Array()
	if tail_up:
		var by := box.position.y + box.size.y
		pts.append(Vector2(cx + TAIL_W * 0.5, by - 1.5))
		pts.append(Vector2(cx, by + TAIL_H))
		pts.append(Vector2(cx - TAIL_W * 0.5, by - 1.5))
	else:
		var ty := box.position.y
		pts.append(Vector2(cx - TAIL_W * 0.5, ty + 1.5))
		pts.append(Vector2(cx, ty - TAIL_H))
		pts.append(Vector2(cx + TAIL_W * 0.5, ty + 1.5))
	return pts


## 非凸多边形填充：三角化后逐三角带顶点色（顶点色跨三角共享 → 渐变连续无接缝）。
func _fill_poly(cv: CanvasItem, pts: PackedVector2Array, c_top: Color, c_bot: Color,
		alpha := 1.0) -> void:
	if pts.size() < 3:
		return
	var y0 := pts[0].y
	var y1 := pts[0].y
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var span := maxf(y1 - y0, 1.0)
	var cols := PackedColorArray()
	for p in pts:
		var col := c_top.lerp(c_bot, clampf((p.y - y0) / span, 0.0, 1.0))
		col.a *= alpha
		cols.append(col)
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		cv.draw_polygon(pts, cols)
		return
	for i in range(0, idx.size(), 3):
		var a := idx[i]
		var b2 := idx[i + 1]
		var d := idx[i + 2]
		# 零面积三角一律不画：`draw_polygon` 会往控制台每帧刷一条
		# 「Invalid polygon data, triangulation failed」
		var area := absf((pts[b2] - pts[a]).cross(pts[d] - pts[a]))
		if area < 0.05:
			continue
		cv.draw_polygon(PackedVector2Array([pts[a], pts[b2], pts[d]]),
				PackedColorArray([cols[a], cols[b2], cols[d]]))


# ================================================================ 缓动

static func _ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var u := t - 1.0
	return 1.0 + c3 * u * u * u + c1 * u * u


static func _ease_in_quad(t: float) -> float:
	return t * t
