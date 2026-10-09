extends Control
## 卡组编辑（选卡第二步）—— 由 RunState 的「待办」决定模式：
##   RunState.pending_relic = 6004 失忆药水：从卡组中选一张卡删除；
##   RunState.pending_relic = 6002 源数之力：从卡组中选一张卡，变成一张随机奖励卡牌；
##   RunState.pending_relic = 6024 鸭血：从卡组中**最多选 2 张**卡，各复制一份加入卡组；
##   RunState.pending_deck_edit = "delete" 遗忘之泉（事件）：从卡组中选一张卡删除。
##   RunState.pending_deck_edit = "smith" 鸭鸭工匠（事件，R110）：从卡组中选一张卡锻造成 2 费铁栅栏。
## 模式判定见 _mode()：「遗忘之泉」优先于道具（两者不会同时存在）。
##
## 交互（v2：平铺网格 + 选中高亮 + 确定）：
##   1. 卡组全部卡牌在中央平铺成网格（重复卡各占一格，逐格可辨）；
##   2. 点一张卡只「高亮选中」，不会立刻生效，可以反复改选；
##   3. 底部「确定」按钮在选中后可用，点它才真正结算，随后回冒险地图。
## 「鸭血」是唯一的多选模式：_limit() 返回 2，再点已满时改为**替换最早选的那张**
## （而不是拒绝点击 —— 玩家点第三张的意图明确是「我改主意了」，静默忽略最让人困惑）。
##
## 选中状态统一存在 `_sel: Array[int]`（格子下标集合）里：单选模式的 limit 是 1，
## 于是「点新的替换旧的」是同一套代码的自然结果，不另开一条通道。

const UiTheme = preload("res://scripts/ui_theme.gd")

const GAP := 14.0            # 网格间距
const MARGIN := 40.0         # 网格左右留白
const TOP_Y := 108.0         # 网格顶部（标题栏 + 提示之下）
const BOTTOM_RESERVE := 96.0 # 底部留给「确定」按钮与结果文字
const RATIO := 0.82          # 卡面 宽/高（与 CardFace 小卡比例一致）
const CARD_MAX_H := 150.0    # 卡面最大高度（卡少时不要撑爆屏幕）
const CARD_MIN_H := 46.0     # 卡面最小高度（卡很多时仍可辨认）

var _font: SystemFont
var _font_bold: SystemFont
var sfx: Sfx
var repo: CardRepo
var _cards: Array[int] = []   # 卡组每一张卡（按卡组顺序；重复卡各占一格）
var _sel: Array[int] = []     # 已选中的格子下标（单选模式最多 1 个，鸭血最多 2 个）
var _hover := -1
var _result := ""             # 完成提示（显示后 1.4s 回地图）
var _done := false

# ---- 网格布局（由 _layout() 算出）----
var _cw := 92.0
var _ch := 112.0
var _cols := 1
var _grid_y := TOP_Y

@onready var title_label: Label = $TopBar/TitleLabel
@onready var hint_label: Label = $HintLabel
@onready var confirm_btn: Button = $ConfirmBtn


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	repo = CardRepo.load_json()
	# 演示参数：-- --mode 6004 直接打开（截图/调试用，不依赖 run 流程）
	var args := OS.get_cmdline_user_args()
	if RunState.pending_relic <= 0 and "--mode" in args:
		var mi := args.find("--mode")
		if mi >= 0 and mi + 1 < args.size():
			RunState.run_active = true
			if RunState.deck_ids.is_empty():
				RunState.deck_ids = [8001, 8001, 8001, 8002, 8002, 8003]
			var mid := int(args[mi + 1])
			RunState.gain_relic(mid)          # 走真实获得路径（含即时结算）
			if RunState.pending_relic <= 0:
				RunState.pending_relic = mid  # 兜底：该道具不需要选卡
	_cards = RunState.deck_ids.duplicate()
	confirm_btn.pressed.connect(_on_confirm)
	resized.connect(_layout)
	_refresh_title()
	_layout()
	_refresh_ui()
	# -- --screenshot：自动截图退出（视觉验证用）
	if "--screenshot" in args:
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("screenshot_deck_edit.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _mode() -> String:
	## 当前模式："oblivion" = 事件「遗忘之泉」删卡 / "delete" = 失忆药水删卡 /
	## "smith" = 鸭鸭工匠锻造（把选中那张变成 2 费铁栅栏，R110）/ "" = 无待办（只读浏览）。
	if RunState.pending_deck_edit == "delete":
		return "oblivion"
	if RunState.pending_deck_edit == "smith":
		return "smith"
	if RunState.pending_relic == 6004:
		return "delete"
	if RunState.pending_relic == RunState.SOURCE_POWER_ID:
		return "transform"
	if RunState.pending_relic == RunState.DUCK_BLOOD_RELIC_ID:
		return "duplicate"
	return ""


func _limit() -> int:
	## 本模式最多能选几张卡。**只有鸭血是 2**，其余全是 1。
	## 上限取 RunState 的常量（界面不另写死数字）。
	if _mode() == "duplicate":
		return RunState.DUCK_BLOOD_MAX
	return 1


func _refresh_title() -> void:
	## 标题 / 提示按模式切换（遗忘之泉删卡 / 6004 删卡 / 6002 改造 / 6024 复制）。
	match _mode():
		"oblivion":
			title_label.text = "遗忘之泉 — 选择一张卡遗忘"
			hint_label.text = "点一张卡选中（高亮），再点下方「确定」，把它从卡组中永久删除。"
		"delete":
			title_label.text = "失忆药水 — 选择一张卡删除"
			hint_label.text = "点一张卡选中（高亮），再点下方「确定」，把它永远删除。"
		"transform":
			title_label.text = "源数之力 — 选择一张卡改造"
			hint_label.text = "点一张卡选中（高亮），再点下方「确定」，把它变成一张随机奖励卡牌。"
		"smith":
			title_label.text = "鸭鸭工匠 — 选择一张卡锻造成铁栅栏"
			hint_label.text = "点一张卡选中（高亮），再点下方「确定」，把它锻造成一张 2 费铁栅栏。"
		"duplicate":
			title_label.text = "鸭血 — 选择最多 %d 张卡复制" % _limit()
			hint_label.text = "点卡选中（可多选，已选 %d/%d），再点下方「确定」；每张被选中的卡都会复制一份加入卡组，原卡保留。一张都不选也可以。" % [_sel.size(), _limit()]
		_:
			title_label.text = "卡组编辑"
			hint_label.text = ""
	if not _cards.is_empty():
		hint_label.text += "　（卡组共 %d 张）" % _cards.size()
	if _mode() == "transform":
		hint_label.text += "　｜　代价：失去 %d 点最大生命（已结算）" \
				% RunState.SOURCE_POWER_HP_COST


# ------------------------------------------------------------ 网格布局

func _layout() -> void:
	## 平铺网格：先在「列数 1..n」里挑出让卡面最大的那种排法，
	## 同等大小时优先「每行都排满」的列数，其次列数更多（更扁更顺眼）。
	var n := _cards.size()
	if n <= 0:
		return
	var area_w: float = maxf(120.0, size.x - MARGIN * 2.0)
	var area_h: float = maxf(60.0, size.y - TOP_Y - BOTTOM_RESERVE)
	var best_h := 0.0
	var best_cols := 1
	for cols in range(1, n + 1):
		var rows := int(ceil(float(n) / float(cols)))
		var w_limit: float = (area_w - GAP * (cols - 1)) / float(cols)   # 列宽上限
		var h_limit: float = (area_h - GAP * (rows - 1)) / float(rows)   # 行高上限
		# 卡面高度同时受行高、列宽（按宽高比换算）与上限约束
		var ch: float = minf(minf(h_limit, w_limit / RATIO), CARD_MAX_H)
		if ch <= 0.0:
			continue
		var full: bool = (n % cols) == 0      # 该列数能把最后一行也排满
		var best_full: bool = (n % best_cols) == 0
		var better := false
		if ch > best_h + 0.001:
			better = true
		elif absf(ch - best_h) <= 0.001 and ((full and not best_full)
				or (full == best_full and cols > best_cols)):
			better = true
		if better:
			best_h = ch
			best_cols = cols
	_ch = maxf(best_h, CARD_MIN_H)
	_cw = _ch * RATIO
	_cols = best_cols
	var rows2 := int(ceil(float(n) / float(_cols)))
	var grid_h: float = rows2 * _ch + (rows2 - 1) * GAP
	_grid_y = TOP_Y + maxf(0.0, (area_h - grid_h) / 2.0)   # 网格整块垂直居中


func _row_count(r: int) -> int:
	## 第 r 行实际有几张卡（最后一行可能不满）。
	return clampi(_cards.size() - r * _cols, 0, _cols)


func _row_x0(r: int) -> float:
	## 每行单独水平居中，最后一行不满时也居中（不左对齐留空）。
	var cnt := _row_count(r)
	var w: float = cnt * _cw + maxf(0.0, cnt - 1) * GAP
	return MARGIN + maxf(0.0, (size.x - MARGIN * 2.0 - w) / 2.0)


func _card_rect(i: int) -> Rect2:
	if _cols <= 0 or _cw <= 0.0:
		return Rect2()
	var r := i / _cols
	var c := i % _cols
	return Rect2(Vector2(_row_x0(r) + c * (_cw + GAP), _grid_y + r * (_ch + GAP)),
			Vector2(_cw, _ch))


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	# 背景（根节点自绘在子节点之下，BG 色块会盖住 _draw，故在这里画）
	draw_rect(Rect2(Vector2.ZERO, size), Color("252a35"))
	if _cards.is_empty():
		draw_string(_font, Vector2(0, size.y / 2), "卡组是空的……（点击继续）",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.INK_ON_DARK)
		return
	_layout()
	for i in _cards.size():
		var rect := _card_rect(i)
		if rect.size.x <= 0.0:
			continue
		var selected := _sel.has(i)
		var hovered := i == _hover and not _done and not selected
		# 高亮底衬：选中 = 红底 + 金边发光；悬停 = 白色微亮
		if selected:
			draw_rect(rect.grow(7.0), Color(0.80, 0.18, 0.14, 0.34), true)
			draw_rect(rect.grow(7.0), UiTheme.ACCENT_GOLD, false, 2.0)
		elif hovered:
			draw_rect(rect.grow(5.0), Color(1, 1, 1, 0.10), true)
		var c := repo.get_card(_cards[i])
		if c != null:
			CardFace.draw(self, c, rect, c.health, selected, false, _font, _font_bold)
		if selected:
			_draw_check_badge(rect)
	if _result != "":
		draw_string(_font_bold, Vector2(0, size.y - 72), _result,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, Color("c8e6a0"))


func _draw_check_badge(rect: Rect2) -> void:
	## 选中角标：卡面右上角的红色对勾圆（不依赖字体，一定画得出来）。
	var r := clampf(rect.size.y * 0.075, 7.0, 12.0)
	var c := rect.position + Vector2(rect.size.x - r - 2.0, r + 2.0)
	draw_circle(c, r, UiTheme.STAT_HEALTH)
	draw_circle(c, r, Color("f4d47a"), false, 1.5)
	var s := r / 9.0
	draw_line(c + Vector2(-4.0, 0.0) * s, c + Vector2(-1.0, 3.4) * s, Color.WHITE, 2.0 * s)
	draw_line(c + Vector2(-1.0, 3.4) * s, c + Vector2(4.6, -3.2) * s, Color.WHITE, 2.0 * s)


# ------------------------------------------------------------ 交互

func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseMotion:
		var idx := _index_at(event.position)
		if idx != _hover:
			_hover = idx
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and not _cards.is_empty():
		var pick := _index_at(event.position)
		if pick >= 0:
			_toggle_sel(pick)     # 只改选中，不立即生效：可以反复改选
			sfx.play("click")
			_refresh_ui()


func _toggle_sel(pick: int) -> void:
	## 选中 / 取消选中一个格子。**已满时点新的 → 替换最早选的那个**（单选模式
	## limit=1，这套逻辑自然退化成「点新的替换旧的」，与原行为一致）。
	if _sel.has(pick):
		_sel.erase(pick)
		return
	while _sel.size() >= _limit():
		_sel.remove_at(0)
	_sel.append(pick)


func _index_at(pos: Vector2) -> int:
	_layout()
	for i in _cards.size():
		var rect := _card_rect(i)
		if rect.size.x > 0.0 and rect.grow(4.0).has_point(pos):
			return i
	return -1


func _refresh_ui() -> void:
	## 「确定」按钮状态与文案：未选卡时禁用并提示，选中后写明将要发生什么。
	## 鸭血是唯一「允许 0 张」的模式（复制 0 张也是合法结果），所以它的按钮一直可用。
	if _done:
		confirm_btn.disabled = true
		return
	if _mode() == "duplicate":
		_refresh_title()      # 提示里的「已选 N/M」跟着变
		confirm_btn.disabled = false
		if _sel.is_empty():
			confirm_btn.text = "不复制任何卡（继续）"
		else:
			var nms: Array[String] = []
			for i: int in _sel:
				var c := repo.get_card(_cards[i])
				nms.append(c.card_name if c != null else str(_cards[i]))
			confirm_btn.text = "确定复制 %d 张：%s" % [_sel.size(), "、".join(nms)]
		return
	if _sel.is_empty():
		confirm_btn.disabled = true
		confirm_btn.text = "请先选择一张卡"
		return
	var pick: int = _sel[0]
	var c2 := repo.get_card(_cards[pick])
	var nm: String = c2.card_name if c2 != null else str(_cards[pick])
	confirm_btn.disabled = false
	match _mode():
		"oblivion":
			confirm_btn.text = "确定遗忘「%s」" % nm
		"delete":
			confirm_btn.text = "确定删除「%s」" % nm
		_:
			confirm_btn.text = "确定改造「%s」" % nm


func _on_confirm() -> void:
	if ReplayLog.playing:
		return   # 回放模式：由驱动执行
	if _done:
		return
	if _mode() == "duplicate":
		_apply_duplicate()
		return
	if _sel.is_empty():
		return
	_apply(_sel[0])


func _apply_duplicate() -> void:
	## 鸭血：把选中的每张卡各复制一份加入卡组。
	## 录像记全部下标（不是单个 idx）—— 多选模式的决策是一个列表。
	# 录像：鸭血是**多选**模式，决策是一组下标（照旧单选模式的 idx 字段名会与
	# 未来其它多选待办撞车），回放侧按 "idxs" 还原成一个列表。
	ReplayLog.ev("deck_edit", {"idxs": _sel.duplicate()})
	_done = true
	sfx.play("click")
	var res := RunState.duplicate_deck_cards(repo, _sel)
	confirm_btn.disabled = true
	confirm_btn.text = "完成"
	var copied: Array = res["copied"]
	if copied.is_empty():
		_result = "鸭血：没有复制任何卡（卡组不变）"
	else:
		var nms: Array[String] = []
		for it: Dictionary in copied:
			nms.append(str(it["name"]))
		_result = "鸭血复制了「%s」各一份（卡组 +%d 张）" % ["、".join(nms), copied.size()]
	_go_back_soon()


func _apply(pick: int) -> void:
	ReplayLog.ev("deck_edit", {"idx": pick})   # 录像：卡组编辑选择
	_done = true
	sfx.play("click")
	var id: int = _cards[pick]
	var c := repo.get_card(id)
	var cname: String = c.card_name if c != null else str(id)
	if _mode() == "oblivion":
		if RunState.delete_deck_card(pick):
			_result = "「%s」已被遗忘，永远离开了卡组" % cname
		else:
			_result = "删除失败：卡组里没有这一张"
		RunState.pending_deck_edit = ""
	elif RunState.pending_relic == 6004:
		if RunState.delete_deck_card(pick):
			_result = "「%s」已从卡组中删除（失忆药水）" % cname
		else:
			_result = "删除失败：卡组里没有这一张"
	elif _mode() == "smith":
		var sres := RunState.smith_deck_card(pick)
		if bool(sres.get("ok", false)):
			_result = "「%s」被锻造成了一张 %d 费铁栅栏（卡组里那张的费用按 %d 计）" % [
					cname, int(sres.get("cost", 2)), int(sres.get("cost", 2))]
		else:
			_result = "锻造失败：卡组里没有这一张"
	elif RunState.pending_relic == RunState.SOURCE_POWER_ID:
		var res := RunState.transform_deck_card(repo, pick)
		var nc := repo.get_card(int(res["new_id"]))
		_result = "「%s」变成了「%s」（源数之力）" % [cname,
				nc.card_name if nc != null else str(res["new_id"])]
	else:
		_result = ""
	confirm_btn.disabled = true
	confirm_btn.text = "完成"
	_go_back_soon()


func _go_back_soon() -> void:
	var t := Timer.new()
	t.wait_time = 1.4
	t.one_shot = true
	t.timeout.connect(_go_back)
	add_child(t)
	t.start()


func _go_back() -> void:
	# 事件「遗忘之泉」的删卡待办：无论如何离开都清掉，免得地图反复把人送回来
	if RunState.pending_deck_edit != "":
		RunState.pending_deck_edit = ""
	get_tree().change_scene_to_file("res://scenes/map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	# 卡组为空时点击任意处继续（防御：正常流程卡组不会为空）
	if _cards.is_empty() and event is InputEventMouseButton \
			and event.pressed and not _done:
		_done = true
		_go_back()
