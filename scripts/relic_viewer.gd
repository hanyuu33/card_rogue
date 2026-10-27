class_name RelicViewer
extends CanvasLayer

const UiPop = preload("res://scripts/ui_pop.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const UiDrag = preload("res://scripts/ui_drag.gd")
## 通用「道具查看」悬浮层 —— 与 DeckViewer（牌库查看）**完全对等**的一对。
##
## 交互（R394 按用户口径重做）：
##   ① **悬停「道具 N」按钮**：不弹任何东西。
##      旧版是「鼠标一沾就弹一张浮层」，而且判定里带了**浮层自己的矩形** ——
##      浮层没显示时那块地方是**看不见的**，鼠标路过它就又冒出来
##      （用户报「光标没放到道具两个字上，只是放到那个没有显示的窗体上，它也会显示」）。
##   ② **点击「道具 N」**：在按钮下方那一行**从右往左**排出一串道具名胶囊，
##      排不下就换行；**再点一次收起**。
##   ③ 展开状态下把光标移到某个胶囊上 → 用共享悬浮件 `Mention.draw_tip()` 显示
##      那件道具的完整效果（名称 / 类型·来源 / 说明三段）。版式与事件页 / 占卜室
##      同一来源，不会再出现「名字和效果重叠」那种各写一套的偏差。
##
## 面板**不压暗背景**（与 DeckViewer 同款，用户要求）。
##
## R405（用户口径「安卓端要能查看全部遗物」）：胶囊行原来排到屏幕底就
## `break` —— 触屏没有滚轮，道具一多，底下那几件**永远看不到也点不到**。
## 现在整行**全部排出来**，可视窗固定成「按钮下沿 → 屏幕底」，多出来的靠
## 滚轮 / 按住拖动（`UiDrag`）上下滚；按钮文案在装不下时补一个 ▾ 作为提示。
## ⚠️ 出界的那几行仍然留在数组里（下标必须与 `_entries()` 一一对应），
##    只是**不画、不命中** —— 所以别在 `_chip_rects()` 里把它们删掉。
##
## 用法：在场景 _ready 里 `RelicViewer.attach(self)`（可选第二参数指定按钮位置）。
## 命令行 `-- --relicview`：模拟点击按钮（展开胶囊行，截图验证用）
## 命令行 `-- --relicpanel`：展开并钉住第一件道具的详情（截图验证版式用）

# ---- 道具名胶囊（点击后按下展开的那一行） ----
const CHIP_H := 30.0        # 胶囊高
const CHIP_GAP := 8.0       # 胶囊之间的横向间隔
const CHIP_PAD := 12.0      # 胶囊左右内边距
const CHIP_ROW_GAP := 6.0   # 换行时的行距
const CHIP_FS := UiTheme.FS_LABEL
const CHIPS_LEFT_MIN := 16.0   # 换行左界（再往左就换行）
const CHIP_TOP_GAP := 6.0      # 胶囊行与按钮下沿的间距

var _btn: Button
var _chip_block: Control         # 只盖住「胶囊行」那块矩形的点击拦截层
var _hover_layer: Control
var _font: Font
var _font_bold: Font
var _open := false               # 胶囊行展开中
var _hover_on := false           # 鼠标在「道具 N」按钮上（只用来做按钮高亮）
var _hover_chip := -1            # 悬停的胶囊下标（-1 = 没有）
var _blocked := false            # R121：被满屏覆盖层压着 → 一切悬停 / 展开让位
var _demo_lock := false          # 命令行演示：锁住状态不被 _process 的鼠标判定改掉
var _cached_n := -1              # 上次刷新按钮时的道具数（变了就重刷）
var _chip_scroll := 0.0          # R405：胶囊行的纵向滚动（px，正 = 内容上移）


static func attach(host: Node, btn_pos := Vector2(1150, 6)) -> RelicViewer:
	## 挂到任意界面：返回新建的悬浮层实例。
	var v := RelicViewer.new()
	host.add_child(v)
	v._btn.position = btn_pos
	return v


func _init() -> void:
	layer = 15


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()

	_btn = Button.new()
	_btn.custom_minimum_size = Vector2(100, 32)
	_btn.size = Vector2(100, 32)
	_btn.add_theme_font_override("font", _font)
	_btn.add_theme_font_size_override("font_size", UiTheme.FS_LABEL)
	# 禁用态（一件道具都没有）保持正常配色，别灰得看不出是什么
	_btn.add_theme_color_override("font_disabled_color", UiTheme.SAND)
	_btn.pressed.connect(_toggle)
	UiTheme.apply_chip(_btn, false, true)
	add_child(_btn)

	# 胶囊行会压在商店第一排商品上（用户口径就是「第二行」），而桌面端商品是**单击即买** ——
	# 没有拦截层的话，点道具名会顺手买下一张卡。这一层只盖胶囊行那块矩形，吞掉点击。
	_chip_block = Control.new()
	_chip_block.mouse_filter = Control.MOUSE_FILTER_STOP
	_chip_block.visible = false
	# R405：胶囊行自己的滚动入口（触屏拖动 / 滚轮）。拦截层本来就盖在行上，
	# 顺手当手势容器 —— 不用再叠一个控件。
	_chip_block.gui_input.connect(_on_chip_input)
	add_child(_chip_block)

	# 胶囊行 + 详情：IGNORE = 不吃点击也不挡下层界面（纯展示 + 自己算命中）
	_hover_layer = Control.new()
	_hover_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hover_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_layer.visible = false
	_hover_layer.draw.connect(_on_layer_draw)
	add_child(_hover_layer)

	_refresh_btn()
	_demo_start()


# ------------------------------------------------------------ 每帧

func _process(_delta: float) -> void:
	if _btn == null:
		return
	# R121：本层悬停判定读的是**鼠标坐标**，完全不认覆盖层 —— 所以必须显式问一句
	# UiGate：被奖励悬浮窗 / 牌库面板盖住时一律让位。
	var blocked := UiGate.blocked()
	if blocked != _blocked:
		_blocked = blocked
		if blocked:
			_hover_on = false
			_open = false
			_hover_chip = -1
			_hover_layer.visible = false
		_refresh_btn()
	if _demo_lock:
		return
	# 道具增减（战斗掉落 / 事件给予）后按钮文案与「有没有东西可看」要跟着变
	if _cached_n != RunState.relics.size():
		_refresh_btn()
	var mp := get_viewport().get_mouse_position()
	_hover_on = _want_hover(mp)
	_hover_chip = _chip_at(mp) if (_open and not _blocked) else -1
	var vis := _open and not _blocked
	if _hover_layer.visible != vis:
		_hover_layer.visible = vis
	if vis:
		# 拦截层跟着胶囊行的外接矩形走（零尺寸时 STOP 也吃不到东西）
		var bb := _chips_bbox()
		_chip_block.position = bb.position
		_chip_block.size = bb.size
		_chip_block.visible = bb.size.x > 0.0 and bb.size.y > 0.0
		_hover_layer.queue_redraw()
	elif _chip_block.visible:
		_chip_block.visible = false


func _on_chip_input(event: InputEvent) -> void:
	## 胶囊行的滚动（R405）：滚轮 / 按住拖动，走 `UiDrag` 唯一口。
	## 拖动时把悬停的高亮与详情清掉 —— 手指下面的胶囊一直在换，留着会闪。
	var d := UiDrag.scroll_delta(event, CHIP_H + CHIP_ROW_GAP)
	if d == 0.0:
		return
	_chip_scroll = clampf(_chip_scroll + d, 0.0, _chip_max_scroll())
	_hover_chip = -1
	_hover_layer.queue_redraw()


func _want_hover(mp: Vector2) -> bool:
	## 「鼠标在道具按钮上」的**唯一判定口**（绘制与测试都走这里）。
	## ⚠️ R394：**只认按钮矩形**。旧版把 `_hover_rect()`（浮层自己的矩形）也算进来，
	## 而那个浮层没显示时是**看不见的** —— 鼠标路过那块空白也会把浮层叫出来，
	## 正是用户报的那个 bug。要看道具就点按钮（展开胶囊行）。
	if UiGate.blocked():
		return false
	return not RunState.relics.is_empty() and _btn_rect().has_point(mp)


func _btn_rect() -> Rect2:
	return Rect2(_btn.position, _btn.size)


# ------------------------------------------------------------ 展开 / 收起

func _toggle() -> void:
	# 被覆盖层盖着时不给展开（看不见的入口不该响应）
	if UiGate.blocked():
		return
	_open = not _open
	_hover_chip = -1
	_chip_scroll = 0.0        # R405：每次展开都从第一件开始看
	_hover_layer.visible = _open
	if _open:
		UiPop.play(_hover_layer, 1.0)   # R151 P1-9：入场淡入 160ms
		_hover_layer.queue_redraw()
	_refresh_btn()


func _refresh_btn() -> void:
	_cached_n = RunState.relics.size()
	# R405：装不下时补一个 ▾ —— 触屏玩家不会知道「下面还有」，而这正是旧版的病根。
	var overflowing := _chip_max_scroll() > 0.5
	_btn.text = ("道具 %d ▾" % _cached_n) if overflowing else ("道具 %d" % _cached_n)
	# R394：按钮**永远可点** —— 点一下展开 / 收起胶囊行（旧版「装不下才可点」，
	# 装得下时按钮是禁用态，于是屏幕写着「点道具查看更多」却点不动，用户报的就是这个）。
	_btn.disabled = _cached_n <= 0
	# R121 / R353：不挂文字 tooltip —— Button 的 tooltip 是顶层弹窗，不认 CanvasLayer 层级。
	_btn.tooltip_text = ""


# ------------------------------------------------------------ 数据

func _entries() -> Array:
	## 本局道具条目：[{relic, note, spent}]，按获得顺序（RunState.relics 的顺序）。
	## 拿不到定义的 id 跳过（与卡组查看器对未知 id 的处理一致）。
	var repo := RelicRepo.load_json()
	var out: Array = []
	for id in RunState.relics:
		var rel := repo.get_relic(int(id))
		if rel == null:
			continue
		# R367：`spent` = 已耗尽（钢盆碎了 / 绳子用掉）—— 条目不删，画灰 + 标状态。
		out.append({"relic": rel, "note": RunState.relic_state_note(int(id)),
				"spent": RunState.is_relic_spent(int(id))})
	return out


func _tag_of(e: Dictionary) -> String:
	## R367：已耗尽的在标签前挂「已耗尽」—— 名称本身不塞状态词，读起来仍是原名。
	var rel: RelicData = e["relic"]
	return ("已耗尽 · " + rel.tag_line()) if bool(e.get("spent", false)) else rel.tag_line()


# ------------------------------------------------------------ 胶囊行版式

func _chip_text(e: Dictionary) -> String:
	var rel: RelicData = e["relic"]
	return RunState.relic_display_name(rel.id)


func _chip_size(e: Dictionary) -> Vector2:
	var t := _chip_text(e)
	var w := _font_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FS).x
	return Vector2(w + CHIP_PAD * 2.0, CHIP_H)


func _chip_view() -> Dictionary:
	## 胶囊行**可视窗**：[top, bottom]。上界 = 按钮下沿，下界 = 屏幕底（留 8px）。
	var top := _btn_rect().end.y + CHIP_TOP_GAP
	return {"top": top,
			"bottom": float(get_viewport().get_visible_rect().size.y) - 8.0}


func _chip_rects() -> Array[Rect2]:
	## 胶囊行的矩形（绘制 / 命中共用）。**从右往左**排，右沿对齐按钮右沿；
	## 排到左界就换一行继续往左排。
	## ⚠️ R405：**不按屏幕底截断**（旧版 `break` 就是「只看得到最上面一排」的原因）——
	##    全部排出来、整体减 `_chip_scroll`，再靠 `_chip_visible()` 决定画 / 命中。
	##    数组下标必须与 `_entries()` 严格对应，出界的也留着。
	var out: Array[Rect2] = []
	var list := _entries()
	if list.is_empty():
		return out
	var right := _btn_rect().end.x
	var x := right
	var y := _btn_rect().end.y + CHIP_TOP_GAP - _chip_scroll
	for e in list:
		var sz := _chip_size(e)
		if x - sz.x < CHIPS_LEFT_MIN:
			x = right
			y += CHIP_H + CHIP_ROW_GAP
		out.append(Rect2(Vector2(x - sz.x, y), sz))
		x -= sz.x + CHIP_GAP
	return out


func _chip_max_scroll() -> float:
	## 滚动上限 = 内容总高 - 可视窗高（不足时 0）。唯一口，输入与绘制都读它。
	var rs := _chip_rects()
	if rs.is_empty():
		return 0.0
	var v := _chip_view()
	var top: float = v["top"]
	var bottom: float = v["bottom"]
	var content := (rs[rs.size() - 1].end.y + _chip_scroll) - top
	return maxf(0.0, content - (bottom - top))


func _chip_visible(r: Rect2) -> bool:
	## 这一格的矩形整个落在可视窗里才算「能看」——半截的也被判出界，
	## 免得滚到一半时上半部分压在按钮上。
	var v := _chip_view()
	return (r.position.y >= float(v["top"]) - 0.5
			and r.end.y <= float(v["bottom"]) + 0.5)


func _chips_bbox() -> Rect2:
	## 胶囊行的外接矩形（点击拦截层用）。没有可视胶囊时返回零矩形。
	## ⚠️ 只并**可视**的那些：滚出屏幕的行若并进来，拦截层会盖到按钮或屏幕外。
	var r := Rect2()
	var got := false
	for x: Rect2 in _chip_rects():
		if not _chip_visible(x):
			continue
		r = x if not got else r.merge(x)
		got = true
	return r


func _chip_at(mp: Vector2) -> int:
	if not _open:
		return -1
	var rs := _chip_rects()
	for i in rs.size():
		if _chip_visible(rs[i]) and rs[i].has_point(mp):
			return i
	return -1


func _tip_pos(chip: Rect2, sz: Vector2) -> Vector2:
	## 详情浮窗的位置：默认贴在胶囊**下方**、右沿对齐；装不下就翻到胶囊上方。
	var vp := get_viewport().get_visible_rect().size
	var x := clampf(chip.end.x - sz.x, 8.0, maxf(8.0, vp.x - sz.x - 8.0))
	var y := chip.end.y + 6.0
	if y + sz.y > vp.y - 8.0:
		y = maxf(8.0, chip.position.y - sz.y - 6.0)
	return Vector2(x, y)


# ------------------------------------------------------------ 绘制

func _on_layer_draw() -> void:
	if not _open:
		return
	var list := _entries()
	var rs := _chip_rects()
	for i in rs.size():
		if i >= list.size():
			break
		if not _chip_visible(rs[i]):
			continue          # R405：滚出可视窗的行不画（数组下标仍与 entries 对齐）
		var e: Dictionary = list[i]
		var rel: RelicData = e["relic"]
		var spent := bool(e.get("spent", false))
		var hot := (i == _hover_chip)
		var r := rs[i]
		_hover_layer.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.42), true)
		_hover_layer.draw_rect(r, Color("fff6df") if hot else UiTheme.PAPER, true)
		_hover_layer.draw_rect(r, UiTheme.ACCENT_GOLD if hot else UiTheme.INK_300, false,
				2.0 if hot else 1.0)
		# 左侧来源色块（初始白 / 奖励黄 / 事件紫 / 二层青 / 角色绿），已耗尽的压灰
		_hover_layer.draw_rect(Rect2(r.position.x + 5.0, r.position.y + 6.0, 5.0,
				r.size.y - 12.0), Color("6a7078") if spent else rel.badge_color(), true)
		var t := _chip_text(e)
		var tw := _font_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FS).x
		var col: Color = Color("8d8678") if spent else rel.name_color(UiTheme.INK_800)
		_hover_layer.draw_string(_font_bold,
				Vector2(r.get_center().x - tw * 0.5 + 3.0,
						r.position.y + r.size.y * 0.5 + CHIP_FS * 0.36),
				t, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FS, col)
	# 悬停的那件 → 共享悬浮件画完整效果（名称 / 类型·来源 / 说明）
	if _hover_chip >= 0 and _hover_chip < rs.size() and _hover_chip < list.size():
		var rel2: RelicData = (list[_hover_chip] as Dictionary)["relic"]
		var ref := {"kind": "relic", "id": rel2.id}
		var sz := Mention.tip_size(_font, ref)
		Mention.draw_tip(_hover_layer, _font, _font_bold, ref,
				_tip_pos(rs[_hover_chip], sz), 0.0, "")


# ------------------------------------------------------------ 命令行演示

func _demo_start() -> void:
	if "--relicview" in OS.get_cmdline_user_args():
		_demo("chips")
	elif "--relicpanel" in OS.get_cmdline_user_args():
		_demo("detail")


func _demo(tag: String) -> void:
	_demo_lock = true
	var t := Timer.new()
	t.wait_time = 0.3
	t.one_shot = true
	t.timeout.connect(func():
		_open = true
		_hover_layer.visible = true
		if tag == "detail":
			_hover_chip = 0 if not _entries().is_empty() else -1
		_hover_layer.queue_redraw())
	add_child(t)
	t.start()
