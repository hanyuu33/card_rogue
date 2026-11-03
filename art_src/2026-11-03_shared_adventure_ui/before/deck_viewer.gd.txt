class_name DeckViewer
extends CanvasLayer

const UiPop = preload("res://scripts/ui_pop.gd")
## 通用「牌库查看」悬浮层 —— 让牌库在游戏中任何界面都能查看。
##
## 右上角一个「牌库 N」按钮；点开后是本局卡组（RunState.deck_ids）的聚合网格：
## 相同卡（同 id）合并、左下角 ×N 张数角标、按（费用, id）排序、滚轮 / 按住拖动翻页、
## 点击任意处关闭。面板不压暗背景（用户要求）。
##
## R393b：**左键点一张卡 → 打开卡牌详情**（大卡 + 数值 + 本局永久成长 + 效果文），
## 详情页点空白处回网格、右键关面板。详情页的成长行与卡面角标同源
## （都读 `CardFace.growth_text()`），两处不会互相打脸。
## R405（用户口径「安卓端要能查看全部卡组」）：原来**只认滚轮** —— 触屏没有滚轮，
## 卡组一多就只看得到最上面一排。现在三种翻法并存：
##   ① 滚轮（桌面老手感不变）；
##   ② **按住拖动**（触屏与桌面同一套，走 `UiDrag`）—— 拖动过的抬起**不会关面板**；
##   ③ 面板右下角一对 **▲ / ▼** 按钮，点一下翻一屏（最可靠的兜底）。
## ⚠️ 拖动是**增量式**的：`_scroll` 单位仍是「行」，像素 / 行高换算在这里做。
## ⚠️ 详情页里三种翻法都停用（只有一张卡，翻了也没内容）。
##
## 用法：在场景 _ready 里 `DeckViewer.attach(self)`（可选第二参数指定按钮位置）。
## 命令行 -- --deckview：打开后自动展开面板（截图验证用）。

const UiTheme = preload("res://scripts/ui_theme.gd")
const UiDrag = preload("res://scripts/ui_drag.gd")

const CARD_W := 76.0
const CARD_H := 92.0
## R117：间距要装得下骑在框上的数值（CARD_BLEED × k = 9.2 × 1.314 ≈ 12.09，左右各一份）
## → 需要 24.18，取 24（每侧 12.0，差 0.09px 亚像素）。
## ⚠️ 间距被**列数**反卡住：`cols = int((pw - 40) / (CARD_W + GAP))`。
##    直接把面板留在 1120 的话，GAP 24 会让列数从 11 掉到 10 —— 所以改成
##    **加宽面板**（1120 → 1150）把这一格吃回来：`int(1110 / 100) = 11` 仍是 11 列。
const GAP := 24.0
## 详情页「本局永久成长」那一行的字色：纸面（PAPER #f7f5f0）上的深绿。
## ⚠️ 不能直接用 `UiTheme.BADGE_UP`（#2fd968）—— 那枚亮绿是给深底徽章画的，
##    压在纸面上对比度不到 2:1。同色相压暗，只改亮度。
const GROW_INK := Color("1d6b36")

var _btn: Button
var _panel: Control
var _font: Font
var _font_bold: Font
var _open := false
var _scroll := 0.0          # 已滚动的行数（浮点，按行步进）
var _shown_n := -1          # 按钮上当前写的张数（R375：数量变了要自己刷新）
var _detail := -1           # R393b：详情页当前看的是「合并后第几组」，-1 = 网格
## R405：按下状态 {pos, scroll, moved}。松手时靠它区分「点一下（关面板）」与「拖完松手」。
var _press := {}


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
	_detail = -1            # R393b：重开面板一定从网格开始，别停在上次那张详情上
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


# ------------------------------------------------------------ 翻页按钮（R405）

## 面板右下角那对 ▲ / ▼。尺寸按「手指点得到」定（触屏最小可靠尺寸 ~44px 见方，
## 这里受面板高度限制取 34×26 —— 仍比文字链接大得多）。
const PAGE_BTN_W := 34.0
const PAGE_BTN_H := 26.0
const PAGE_BTN_GAP := 6.0


func _max_scroll() -> float:
	## 滚动上限（单位「行」）—— 唯一口，绘制与输入都读它，避免两处各算一遍。
	var L := _layout(_merged().size())
	return maxf(0.0, float(int(L["rows"]) - int(L["view_rows"])))


func _page_btns() -> Array[Rect2]:
	## [上一屏, 下一屏] 的矩形，贴在面板底边内侧右角。
	var L := _layout(_merged().size())
	var px: float = L["px"]
	var py: float = L["py"]
	var pw: float = L["pw"]
	var ph: float = L["ph"]
	var y := py + ph - PAGE_BTN_H - 10.0
	var x2 := px + pw - 14.0 - PAGE_BTN_W
	var x1 := x2 - PAGE_BTN_GAP - PAGE_BTN_W
	return [Rect2(x1, y, PAGE_BTN_W, PAGE_BTN_H), Rect2(x2, y, PAGE_BTN_W, PAGE_BTN_H)]


func _page_hit(pos: Vector2) -> int:
	## -1 = 上一屏 / +1 = 下一屏 / 0 = 没点中。
	var rs := _page_btns()
	if rs[0].has_point(pos):
		return -1
	if rs[1].has_point(pos):
		return 1
	return 0


func _flip_page(dir: int) -> void:
	## 翻**一整屏**（不是一行）—— 触屏上一行一行点太累了。
	if dir == 0:
		return
	var L := _layout(_merged().size())
	_scroll = clampf(_scroll + float(int(L["view_rows"])) * float(signi(dir)),
			0.0, _max_scroll())
	_panel.queue_redraw()


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
	# R393b：详情页
	if n == 0:
		_detail = -1
	if _detail >= 0:
		_detail = clampi(_detail, 0, n - 1)
		_panel.draw_string(_font_bold, Vector2(px + 20, py + 32),
				"卡牌详情（左键点空白处返回卡组）",
				HORIZONTAL_ALIGNMENT_LEFT, pw - 40, UiTheme.FS_BODY, UiTheme.INK_800)
		_draw_detail(merged, L)
		return
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
		# ⚠️ 走 `_grid_rect()`（命中判定也用它）—— 两处各算一遍必然会漂。
		var rect := _grid_rect(i, L, skip_rows)
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
		_panel.draw_string(_font, Vector2(px + pw - 300, py + ph - 12),
				"第 %d/%d 屏（滚轮或按住拖动翻页）" % [skip_rows + 1, int(max_scroll) + 1],
				HORIZONTAL_ALIGNMENT_LEFT, 240, UiTheme.FS_CAPTION, UiTheme.INK_500)
		# R405：▲ / ▼ 兜底按钮 —— 触屏上最可靠的一手（拖动会被某些设备吞掉）
		var btns := _page_btns()
		for i in 2:
			var r: Rect2 = btns[i]
			var usable := (_scroll > 0.0) if i == 0 else (_scroll < max_scroll)
			var ink: Color = UiTheme.INK_800 if usable else UiTheme.INK_300
			_panel.draw_rect(r, UiTheme.PAPER)
			_panel.draw_rect(r, ink, false, 1.2)
			var c := r.get_center()
			var dir := -1.0 if i == 0 else 1.0
			_panel.draw_polyline(PackedVector2Array([
					Vector2(c.x - 6.0, c.y - dir * 4.0),
					Vector2(c.x, c.y + dir * 4.0),
					Vector2(c.x + 6.0, c.y - dir * 4.0)]), ink, 2.4, true)


func _grid_rect(i: int, L: Dictionary, skip_rows: int) -> Rect2:
	## 网格里第 i 组的卡框（绘制与命中判定共用 → 画在哪就点在哪）。
	var cols: int = L["cols"]
	var r: int = i / cols
	return Rect2(L["grid_x"] + (i % cols) * (CARD_W + GAP),
			L["grid_y"] + (r - skip_rows) * (CARD_H + GAP), CARD_W, CARD_H)


func _index_at(pos: Vector2, merged: Array, L: Dictionary) -> int:
	## 鼠标落在第几组卡上（-1 = 空白）。滚动位置与 `_on_panel_draw` 同口径。
	if merged.is_empty():
		return -1
	var view_rows: int = L["view_rows"]
	var skip_rows := int(clampf(_scroll, 0.0, maxf(0.0, float(L["rows"] - view_rows))))
	for i in merged.size():
		var r: int = i / int(L["cols"])
		if r < skip_rows or r >= skip_rows + view_rows:
			continue
		if _grid_rect(i, L, skip_rows).has_point(pos):
			return i
	return -1


func _draw_detail(merged: Array, L: Dictionary) -> void:
	## R393b：**卡牌详情页**（用户口径「在卡组查看卡片详情也可以显示（成长）」）。
	## 左半是大卡（照常走 `CardFace.draw()` → 卡面角标与数值徽章都在），
	## 右半是文字：种类 / 职业 / 稀有度 / 费用 → 数值 → **本局永久成长** → 效果文 → 卡组张数。
	## 成长期写「哪部分数字是长出来的 + 跨战斗保留 + 新开一局才清空」，
	## 与 `玩法说明.txt` 的 R393 口径一致（玩家的疑问只会是「这个会掉吗」）。
	var px: float = L["px"]
	var py: float = L["py"]
	var pw: float = L["pw"]
	var ph: float = L["ph"]
	var e: Dictionary = merged[_detail]
	var c: CardData = e["card"]
	var cnt: int = e["count"]
	# ── 左：大卡 ──
	var chh: float = minf(410.0, ph - 110.0)
	var cw: float = chh * 0.82
	var card_rect := Rect2(px + 44.0, py + 66.0, cw, chh)
	CardFace.draw(_panel, c, card_rect, c.health, false, false, _font, _font_bold)
	# ── 右：文字区 ──
	var x: float = card_rect.end.x + 40.0
	var w: float = px + pw - 44.0 - x
	var y: float = py + 84.0
	_panel.draw_string(_font_bold, Vector2(x, y), c.card_name,
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_TITLE, UiTheme.INK_900)
	y += 36.0
	var fee_txt := "X 费" if c.x_cost else "%d 费" % c.cost
	_panel.draw_string(_font, Vector2(x, y),
			"%s · %s · %s · %s" % [c.kind, c.card_class, c.rarity_name(), fee_txt],
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_LABEL, UiTheme.INK_600)
	y += 30.0
	# 数值行：`stats_line()` 对技能卡只说「直接使用」→ 这里把伤害写出来，
	# 否则「猎杀 25 伤害（长到 31）」的成长在详情页会没有落点。
	var st := CardFace.stats_line(c)
	if c.kind == "技能" and c.value > 0:
		st = "造成 %d 点伤害" % c.value
	_panel.draw_string(_font, Vector2(x, y), st,
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_LABEL, UiTheme.INK_800)
	y += 38.0
	# 本局永久成长
	var gt := CardFace.growth_text(c)
	if gt != "":
		_panel.draw_rect(Rect2(x, y - 20.0, w, 56.0), Color(0.14, 0.42, 0.22, 0.10), true)
		_panel.draw_rect(Rect2(x, y - 20.0, 3.0, 56.0), GROW_INK, true)
		_panel.draw_string(_font_bold, Vector2(x + 12.0, y + 2.0),
				"本局永久成长　%s" % gt, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0,
				UiTheme.FS_LABEL, GROW_INK)
		_panel.draw_string(_font, Vector2(x + 12.0, y + 26.0),
				"跨战斗保留 · 随存档走 · 新开一局才清空",
				HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, UiTheme.FS_CAPTION, UiTheme.INK_500)
		y += 56.0
	else:
		y += 8.0
	# 效果文
	var lines := CardFace.wrap_text(_font, CardText.naturalize(c.effect_text), w, UiTheme.FS_BODY)
	for li in mini(lines.size(), 7):
		_panel.draw_string(_font, Vector2(x, y), lines[li],
				HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_BODY, UiTheme.INK_800)
		y += 24.0
	y += 12.0
	_panel.draw_string(_font, Vector2(x, y), "卡组中同名同状态共 %d 张" % cnt,
			HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_LABEL, UiTheme.INK_600)
	_panel.draw_string(_font, Vector2(px + pw - 300.0, py + ph - 12.0),
			"左键点空白返回 · 右键关闭",
			HORIZONTAL_ALIGNMENT_LEFT, 280.0, UiTheme.FS_CAPTION, UiTheme.INK_500)


func _on_panel_input(event: InputEvent) -> void:
	# ① 滚轮 / 按住拖动（R405：触屏也能滚了，见 UiDrag 头部）
	var d := UiDrag.scroll_delta(event, CARD_H + GAP)
	if d != 0.0:
		if _detail >= 0:
			return          # R393b：详情页只有一张卡，滚了也没内容
		_scroll = clampf(_scroll + d / (CARD_H + GAP), 0.0, _max_scroll())
		if not _press.is_empty():
			_press["moved"] = true
		_panel.queue_redraw()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return
		if mb.pressed:
			_press = {"pos": mb.position, "scroll": _scroll, "moved": false}
			return
		# ② 松手：拖过的（含滚轮滚过）不算点击 —— 否则触屏一滑就把面板关了
		var moved := bool(_press.get("moved", true))
		_press = {}
		if moved:
			return
		# ③ 右键：任何时候都是「关面板」（详情页里也一样）
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_toggle()
			return
		# ④ R393b 详情页：左键点任意处先回网格（**不直接关面板**：
		#    玩家多半是想看下一张，直接关掉等于逼他重点开一次）。
		if _detail >= 0:
			_detail = -1
			_panel.queue_redraw()
			return
		# ⑤ 翻页按钮（R405）：触屏最可靠的一手
		var page := _page_hit(mb.position)
		if page != 0:
			_flip_page(page)
			return
		# ⑥ 点卡 → 详情；点空白 → 关面板（R393b 把「点任意处关」改成「点卡看详情」）
		var merged := _merged()
		var idx := _index_at(mb.position, merged, _layout(merged.size()))
		if idx >= 0:
			_detail = idx
			_panel.queue_redraw()
			return
		_toggle()
	elif event is InputEventMouseMotion:
		# 拖动位移已经在上面的 UiDrag 分支里消化掉了；这里只兜「按住但一个字都没动」的情况
		var mm := event as InputEventMouseMotion
		if not _press.is_empty() and UiDrag.drag_moved(_press["pos"], mm.position):
			_press["moved"] = true
