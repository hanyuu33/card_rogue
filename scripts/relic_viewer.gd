class_name RelicViewer
extends CanvasLayer
## 通用「道具查看」悬浮层 —— 与 DeckViewer（牌库查看）**完全对等**的一对。
##
## 右上角一个「道具 N」按钮。**看描述不用点**：鼠标悬浮在按钮上（或速览浮层上）
## 就展开一张速览浮层，逐条列出本局全部道具 —— 名称 + 来源标签 + 完整效果说明
## （长文本自动折行）+ 来源色块（初始白 / 奖励黄 / 事件紫 / 二层青 / 角色绿），
## 鼠标移开即消失。
##
## 只有当道具多到速览浮层**装不下全部**（条目数 > FOLD_MAX 或总高 > HOVER_MAX_H）时，
## 按钮才**可点击**：此时点开的是一份**字号明显更大**的完整面板（滚轮翻页、
## 点击任意处关闭）。装得下时按钮是禁用态 —— 悬浮即已看全，不需要点。
##
## 面板**不压暗背景**（与 DeckViewer 同款，用户要求）。
##
## 用法：在场景 _ready 里 `RelicViewer.attach(self)`（可选第二参数指定按钮位置）。
## 命令行 -- --relicview：模拟悬浮（展开速览浮层，截图验证用）
## 命令行 -- relicpanel：强制点开完整详情面板（截图验证用）

# ---- 悬浮速览浮层（R75：看描述的唯一日常入口，不用点） ----
const HOVER_W := 430.0            # 浮层宽
const HOVER_MAX_H := 430.0        # 浮层最大高（超过就装不下 → 允许点开详情）
const FOLD_MAX := 6               # 浮层最多完整列出的条目数（超过同样允许点开详情）
const HOVER_DESC_LINES := 3       # 浮层里单条说明最多折几行
const H_NAME := 19.0              # 浮层：名称行高
const H_LINE := 15.0              # 浮层：说明单行行高
const H_GAP := 7.0                # 浮层：条目之间的间隔

# ---- 点击才打开的完整详情面板（字号全面放大） ----
const PANEL_W := 1120.0
const PANEL_H := 600.0
const ROW_H := 70.0              # 单行高（名称行 + 至多 3 行折行的说明）
const PAD := 20.0
const P_NAME := 19.0             # 详情面板：名称字号
const P_TAG := 15.0              # 详情面板：来源标签字号
const P_DESC := 16.0             # 详情面板：说明字号
const P_LINE := 18.0             # 详情面板：说明行高

var _btn: Button
var _hover_layer: Control
var _panel: Control
var _font: SystemFont
var _font_bold: SystemFont
var _open := false
var _hover_on := false           # 鼠标当前在按钮或速览浮层上
var _demo_lock := false          # 命令行演示：锁住状态不被 _process 的鼠标判定改掉
var _cached_n := -1              # 上次刷新按钮时的道具数（变了就重刷 + 重判可否点击）
var _scroll := 0.0               # 已滚动的行数（浮点，按行步进）


static func attach(host: Node, btn_pos := Vector2(1150, 6)) -> RelicViewer:
	## 挂到任意界面：返回新建的悬浮层实例。
	var v := RelicViewer.new()
	host.add_child(v)
	v._btn.position = btn_pos
	return v


func _init() -> void:
	layer = 15


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
	_font_bold = SystemFont.new()
	_font_bold.font_names = _font.font_names

	_btn = Button.new()
	_btn.custom_minimum_size = Vector2(100, 32)
	_btn.size = Vector2(100, 32)
	_btn.add_theme_font_override("font", _font)
	_btn.add_theme_font_size_override("font_size", 14)
	# 禁用态（悬浮就能看全时）保持正常配色，别灰得看不出是什么
	_btn.add_theme_color_override("font_disabled_color", Color("e8e4da"))
	_btn.pressed.connect(_toggle)
	add_child(_btn)

	# 速览浮层：IGNORE = 不吃点击也不挡下层界面（纯展示）
	_hover_layer = Control.new()
	_hover_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hover_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_layer.visible = false
	_hover_layer.draw.connect(_on_hover_draw)
	add_child(_hover_layer)

	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	_panel.draw.connect(_on_panel_draw)
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)

	_refresh_btn()
	_demo_start()


# ------------------------------------------------------------ 悬浮检测（每帧）

func _process(_delta: float) -> void:
	if _btn == null or _demo_lock:
		return
	# 道具增减（战斗掉落 / 事件给予）后按钮文案与「可否点击」要跟着变
	if _cached_n != RunState.relics.size():
		_refresh_btn()
	_hover_layer.queue_redraw()   # 速览浮层跟随鼠标（提示要画在鼠标旁边）
	var mp := get_viewport().get_mouse_position()
	var want := not _open and not RunState.relics.is_empty() \
			and (Rect2(_btn.position, _btn.size).has_point(mp) or _hover_rect().has_point(mp))
	if want != _hover_on:
		_hover_on = want
		_hover_layer.visible = want


func _btn_rect() -> Rect2:
	return Rect2(_btn.position, _btn.size)


func _hover_rect() -> Rect2:
	## 速览浮层的屏幕矩形（紧贴按钮下方；太靠下就上移到屏幕内）。
	var w := HOVER_W
	var sw := float(get_viewport().get_visible_rect().size.x)
	var h := _hover_h()
	var x: float = clampf(_btn_rect().end.x - w, 8.0, maxf(8.0, sw - w - 8.0))
	var y := _btn_rect().end.y + 6.0
	var sh := float(get_viewport().get_visible_rect().size.y)
	if y + h > sh - 8.0:
		y = maxf(8.0, _btn_rect().position.y - h - 6.0)
	return Rect2(x, y, w, h)


# ------------------------------------------------------------ 按钮

func _refresh_btn() -> void:
	_cached_n = RunState.relics.size()
	_btn.text = "道具 %d" % _cached_n
	var clickable := _need_detail()
	_btn.disabled = not clickable
	_btn.tooltip_text = "悬浮查看全部道具" if not clickable else "悬浮速览 · 点击看完整详情"


func _need_detail() -> bool:
	## 速览浮层装不下全部道具时，才需要（允许）点开大字号详情面板。
	## 判定唯一口：条目数超 FOLD_MAX，或按完整行高累加超 HOVER_MAX_H。
	var list := _entries()
	if list.size() > FOLD_MAX:
		return true
	var total := 0.0
	for e in list:
		total += _row_block(e, 99).h
	return total + 30.0 > HOVER_MAX_H


func _toggle() -> void:
	# 装得下时按钮是禁用态走不到这里；这里再挡一道（--relicpanel 强制打开除外）
	if not _open and not _need_detail() and not _force_panel():
		return
	_open = not _open
	_panel.visible = _open
	_hover_on = false
	_hover_layer.visible = false
	_scroll = 0.0
	_refresh_btn()
	_panel.queue_redraw()


func _force_panel() -> bool:
	return "--relicpanel" in OS.get_cmdline_user_args()


# ------------------------------------------------------------ 数据

func _entries() -> Array:
	## 本局道具条目：[{relic, note}]，按获得顺序（RunState.relics 的顺序）。
	## 拿不到定义的 id 跳过（与卡组查看器对未知 id 的处理一致）。
	var repo := RelicRepo.load_json()
	var out: Array = []
	for id in RunState.relics:
		var rel := repo.get_relic(int(id))
		if rel == null:
			continue
		out.append({"relic": rel, "note": RunState.relic_state_note(int(id))})
	return out


func _body_text(e: Dictionary) -> String:
	## 单条道具的说明正文：完整效果 + 动态状态备注（如「当前复活概率 100%」）。
	var rel: RelicData = e["relic"]
	var note := str(e["note"])
	return rel.desc if note == "" else ("%s  （%s）" % [rel.desc, note])


func _wrap(text: String, max_w: float, px: int) -> PackedStringArray:
	## 按宽度逐字折行（draw_string 不自动换行，长说明会画到面板外）。
	var out: PackedStringArray = []
	var cur := ""
	for i in text.length():
		var ch := text[i]
		if cur != "" and _font.get_string_size(cur + ch,
				HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
			out.append(cur)
			cur = ch
		else:
			cur += ch
	if cur != "":
		out.append(cur)
	return out


func _row_block(e: Dictionary, max_lines: int) -> Dictionary:
	## 浮层里单条道具的排版块：{name, tag, lines, scol, h}。
	## max_lines = 说明最多折几行（99 = 不截断，用于估算真实高度）。
	var rel: RelicData = e["relic"]
	var lines := _wrap(_body_text(e), HOVER_W - PAD * 2.0 - 16.0, 12)
	if max_lines < 99 and lines.size() > max_lines:
		lines = lines.slice(0, max_lines)
		lines[max_lines - 1] = lines[max_lines - 1] + "…"
	return {"name": rel.relic_name,
			"tag": "%s · %s" % [rel.source_label(), rel.kind],
			"lines": lines, "scol": rel.source_color(),
			"h": H_NAME + lines.size() * H_LINE + H_GAP}


func _hover_h() -> float:
	## 速览浮层实际高度（超 HOVER_MAX_H 就截断，底部提示还有几件没显示）。
	var list := _entries()
	if list.is_empty():
		return 46.0
	var h := 30.0
	for e in list:
		h += _row_block(e, HOVER_DESC_LINES).h
	return minf(h + 10.0, HOVER_MAX_H)


# ------------------------------------------------------------ 速览浮层绘制

func _on_hover_draw() -> void:
	if not _hover_on:
		return
	var list := _entries()
	var r := _hover_rect()
	_hover_layer.draw_rect(r, Color(0.10, 0.11, 0.15, 0.96), true)
	_hover_layer.draw_rect(r, Color("c8951c"), false, 1.2)
	if list.is_empty():
		_hover_layer.draw_string(_font, r.position + Vector2(PAD * 0.6, 26),
				"还没有获得任何道具。", HORIZONTAL_ALIGNMENT_LEFT,
				r.size.x - 24.0, 12, Color("b8b4aa"))
		return
	_hover_layer.draw_string(_font_bold, r.position + Vector2(PAD * 0.6, 20),
			"我的道具（共 %d 件 · 悬浮查看）" % list.size(),
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 13, Color("f0ead8"))
	var y := r.position.y + 30.0
	var bottom := r.end.y - 22.0
	var shown := 0
	for e in list:
		var b := _row_block(e, HOVER_DESC_LINES)
		if y + b.h > bottom + 6.0:
			break
		var rel: RelicData = e["relic"]
		var scol: Color = b["scol"]
		# 左侧来源色块（实心 + 深描边，浅色来源在深底上也要看得见）
		_hover_layer.draw_rect(Rect2(r.position.x + PAD * 0.5, y + 2, 6, H_NAME + 4),
				scol, true)
		_hover_layer.draw_rect(Rect2(r.position.x + PAD * 0.5, y + 2, 6, H_NAME + 4),
				Color(0, 0, 0, 0.5), false, 1.0)
		_hover_layer.draw_string(_font_bold, r.position + Vector2(PAD * 0.6 + 12, y + 15),
				"「%s」" % rel.relic_name, HORIZONTAL_ALIGNMENT_LEFT,
				180.0, 13, Color("f4eeda"))
		_hover_layer.draw_string(_font, r.position + Vector2(PAD * 0.6 + 196, y + 15),
				str(b["tag"]), HORIZONTAL_ALIGNMENT_LEFT, 180.0, 11, Color("9a927f"))
		var lines: PackedStringArray = b["lines"]
		for j in lines.size():
			_hover_layer.draw_string(_font, r.position + Vector2(PAD * 0.6 + 12,
					y + H_NAME + j * H_LINE), lines[j], HORIZONTAL_ALIGNMENT_LEFT,
					r.size.x - PAD * 1.2, 12, Color("ddd6c4"))
		y += b.h
		shown += 1
	# 底部：装不下就引导点按钮；装得下就明说「不用点」
	if shown < list.size():
		_hover_layer.draw_string(_font, Vector2(r.position.x + PAD * 0.6, r.end.y - 8),
				"…另有 %d 件，点「道具 %d」看完整详情" % [list.size() - shown, list.size()],
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 11, Color("c8951c"))
	elif _need_detail():
		_hover_layer.draw_string(_font, Vector2(r.position.x + PAD * 0.6, r.end.y - 8),
				"点「道具 %d」看完整详情（字号更大）" % list.size(),
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 11, Color("9a927f"))
	else:
		_hover_layer.draw_string(_font, Vector2(r.position.x + PAD * 0.6, r.end.y - 8),
				"已全部显示，无需点击", HORIZONTAL_ALIGNMENT_LEFT,
				r.size.x - 24.0, 11, Color("6f6a5e"))


# ------------------------------------------------------------ 完整详情面板

func _layout(n: int) -> Dictionary:
	## 面板布局（绘制与滚动共用）。
	var px := (1280.0 - PANEL_W) / 2.0
	var py := (720.0 - PANEL_H) / 2.0
	var grid_y := py + 62.0
	var view_rows := int((py + PANEL_H - 16.0 - grid_y) / ROW_H)
	return {"px": px, "py": py, "grid_y": grid_y,
			"view_rows": maxi(1, view_rows), "max_scroll": maxi(0, n - view_rows)}


func _row_lines(e: Dictionary) -> PackedStringArray:
	## 详情面板里单条道具的说明折行（更宽 + 更大字号）。
	var lines := _wrap(_body_text(e), PANEL_W - PAD * 2.0 - 130.0, P_DESC)
	if lines.size() > 3:
		lines = lines.slice(0, 3)
		lines[2] = lines[2] + "…"
	return lines


func _on_panel_draw() -> void:
	var list := _entries()
	var n := list.size()
	var L := _layout(n)
	var px: float = L["px"]
	var py: float = L["py"]
	# 面板不压暗背景（与 DeckViewer 同款）
	_panel.draw_rect(Rect2(px, py, PANEL_W, PANEL_H), Color("f5f2ea"))
	_panel.draw_rect(Rect2(px, py, PANEL_W, PANEL_H), Color("555555"), false, 2.0)
	_panel.draw_string(_font_bold, Vector2(px + PAD, py + 40),
			"我的道具（共 %d 件 · 完整效果 · 滚轮翻页 · 点击任意处关闭）" % n,
			HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - PAD * 2.0, 20, Color("333333"))
	if n == 0:
		_panel.draw_string(_font, Vector2(px + PAD, py + 96),
				"还没有获得任何道具。",
				HORIZONTAL_ALIGNMENT_LEFT, 300, 16, Color("888888"))
		return
	var grid_y: float = L["grid_y"]
	var view_rows: int = L["view_rows"]
	var max_scroll: int = L["max_scroll"]
	_scroll = clampf(_scroll, 0.0, float(max_scroll))
	var skip := int(_scroll)
	for i in n:
		if i < skip or i >= skip + view_rows:
			continue
		var e: Dictionary = list[i]
		var rel: RelicData = e["relic"]
		var y := grid_y + (i - skip) * ROW_H
		var scol := rel.source_color()
		# 左侧来源色块（白描边在浅底上不醒目，用实心块 + 深描边，与战斗道具栏一致）
		_panel.draw_rect(Rect2(px + PAD, y + 4, 10, ROW_H - 14), scol, true)
		_panel.draw_rect(Rect2(px + PAD, y + 4, 10, ROW_H - 14), Color(0, 0, 0, 0.45), false, 1.0)
		# 名称 + 来源标签 + 生效时机（字号比速览浮层大一档）
		_panel.draw_string(_font_bold, Vector2(px + PAD + 22, y + 22),
				"「%s」" % rel.relic_name, HORIZONTAL_ALIGNMENT_LEFT, 300, P_NAME, Color("2f2a20"))
		_panel.draw_string(_font, Vector2(px + PAD + 216, y + 22),
				"（%s）" % str(_tag_of(e)), HORIZONTAL_ALIGNMENT_LEFT, 300, P_TAG, Color("8a8172"))
		var lines := _row_lines(e)
		for j in lines.size():
			_panel.draw_string(_font, Vector2(px + PAD + 22, y + 44 + j * P_LINE),
					lines[j], HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - PAD * 2.0 - 40, P_DESC,
					Color("4a4438"))
		_panel.draw_line(Vector2(px + PAD, y + ROW_H - 6), Vector2(px + PANEL_W - PAD, y + ROW_H - 6),
				Color(0, 0, 0, 0.10), 1.0)
	# 滚动提示
	if max_scroll > 0:
		_panel.draw_string(_font, Vector2(px + PANEL_W - 220, py + PANEL_H - 14),
				"第 %d/%d 屏" % [skip + 1, max_scroll + 1],
				HORIZONTAL_ALIGNMENT_LEFT, 200, 12, Color("888888"))


func _tag_of(e: Dictionary) -> String:
	var rel: RelicData = e["relic"]
	return "%s · %s" % [rel.source_label(), rel.kind]


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


# ------------------------------------------------------------ 命令行演示

func _demo_start() -> void:
	# -- --relicview：模拟鼠标悬浮（截图验证速览浮层）
	if "--relicview" in OS.get_cmdline_user_args():
		_demo("relicview")
	# --relicpanel：强制点开完整详情面板（截图验证大字版式）
	elif _force_panel():
		_demo("relicpanel")


func _demo(tag: String) -> void:
	_demo_lock = true
	var t := Timer.new()
	t.wait_time = 0.3
	t.one_shot = true
	t.timeout.connect(func():
		if tag == "relicpanel":
			_open = true
			_panel.visible = true
			_panel.queue_redraw()
		else:
			_hover_on = true
			_hover_layer.visible = true
			_hover_layer.queue_redraw())
	add_child(t)
	t.start()
