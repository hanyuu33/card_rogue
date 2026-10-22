extends Control
## 卡组编辑（选卡第二步）—— 由 RunState 的「待办」决定模式：
##   RunState.pending_relic = 6004 失忆药水：从卡组中选一张卡删除；
##   RunState.pending_relic = 6002 源数之力：从卡组中选一张卡，变成一张随机奖励卡牌；
##   RunState.pending_relic = 6024 鸭血：从卡组中**最多选 2 张**卡，各复制一份加入卡组；
##   RunState.pending_deck_edit = "delete" 遗忘之泉（事件）：从卡组中选一张卡删除。
##   RunState.pending_deck_edit = "smith" 鸭鸭工匠（事件，R110）：从卡组中选一张卡锻造成 2 费铁栅栏。
##   RunState.pending_deck_edit = "transform_class" 卡片商人（R305）·旧换新：
##       选一张卡，变成一张随机**本职业**奖励卡。
##   RunState.pending_deck_edit = "vendor" 卡片商人（R305）·以卡易物：
##       选一张 **5 费及以上**的卡交出去，换一个大宝箱（道具 + 一组卡牌奖励 + 金币）。
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

# R191（用户口径「事件选卡也要用全屏大选卡」）：固定**每行 5 张放大卡** +
# 垂直滚动（滚轮 / 拖动 / 触屏拖动），卡面只留卡名，点选后描述在底部描述条读。
# 不再做「按张数挤一屏」的自适应缩小 —— 卡小到 46px 时什么都看不清。
const COLS := 5              # 每行 5 张（与战斗内选卡页同口径）
const GAP := 34.0            # 卡间距（要装得下一行徽章骑缝：≥ 2×徽章半径）
const GRID_PAD_TOP := 16.0   # 网格内容顶部留白（首行徽章向上出血不被 clip 裁掉）
const MARGIN := 72.0         # 网格左右留白
const TOP_Y := 108.0         # 网格顶部（标题栏 + 提示之下）
const BOTTOM_RESERVE := 178.0 # 底部：描述条 88 + 确定按钮带 76 + 间隙
const DESC_H := 88.0         # 底部描述条高（点选/悬停的卡在这里读描述）
const RATIO := 0.82          # 卡面 宽/高（与 CardFace 小卡比例一致）
const CARD_MAX_H := 252.0    # 卡面高度上限（≈ 奖励三选一的 216×260 规格）
const WHEEL_STEP := 64.0     # 滚轮一步
const DRAG_SLOP := 10.0      # 拖动超过它才算滚动（不是点选）

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null      # Esc 主菜单（R148）
var repo: CardRepo
var _cards: Array[int] = []   # 卡组每一张卡（按卡组顺序；重复卡各占一格）
var _uids: Array[int] = []    # R157：每张卡的实例号（与 _cards 平行）—— 补间键用它，重复 id 各归各位
var _uid_next := 0
var _sel: Array[int] = []     # 已选中的格子下标（单选模式最多 1 个，鸭血最多 2 个）
var _hover := -1
var _result := ""             # 完成提示（显示后 1.4s 回地图）
var _done := false

# ---- 网格布局（R191：固定 5 列 + 滚动；尺寸由 _layout() 算出）----
var _cw := 200.0
var _ch := 244.0
var _scroll := 0.0
var _press := {}           # {pos, scroll, moved} 拖滚动手势
var _clip: Control         # 裁剪容器（Godot 画布无裁剪 → clip_contents 容器裁子节点）
var _grid: Control         # 卡片网格自绘节点（本地坐标；y = -_scroll）

@onready var title_label: Label = $TopBar/TitleLabel
@onready var hint_label: Label = $HintLabel
@onready var confirm_btn: Button = $ConfirmBtn


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	# R113：本页底色 #252A35 = 暗底 → 用暗底主按钮（金底墨字；深墨蓝在暗底上会沉下去）
	UiTheme.apply_button(confirm_btn, true, true)
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
	# R305 演示：-- --edit vendor / -- --edit transform_class 直接进卡片商人的选卡模式
	# （出图核验「只能选 5 费卡」与标题文案，不必真的从事件里点进来）。
	if "--edit" in args:
		var ei := args.find("--edit")
		if ei >= 0 and ei + 1 < args.size():
			RunState.run_active = true
			if RunState.deck_ids.is_empty():
				RunState.deck_ids = [8001, 8002, 8003, 9018, 8060, 9154]
				RunState.ensure_deck_mods()
			RunState.pending_deck_edit = str(args[ei + 1])
	_cards = RunState.deck_ids.duplicate()
	_reset_uids()
	# R191：滚动网格 —— 裁剪容器 + 自绘子节点（卡画在它上面，滚出视区的被裁掉）
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_grid)
	_grid.draw.connect(_draw_grid)
	confirm_btn.pressed.connect(_on_confirm)
	resized.connect(func(): _layout(); if _grid != null: _grid.queue_redraw(); queue_redraw())
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
	# -- --tweenshot：演示增删补间（R151 P1-11）—— 0.25s 删掉中间一张，
	# 0.37s 截图（补间 t≈0.6，其余卡正从旧位滑向新位）
	if "--tweenshot" in OS.get_cmdline_user_args():
		# 新局卡组是空的 → 自备 6 张演示卡组（补间要有卡可滑）
		RunState.deck_ids = [1011, 1013, 1050, 1051, 1053, 1055]
		_cards = RunState.deck_ids.duplicate()
		_reset_uids()
		var tw_t := Timer.new()
		tw_t.wait_time = 0.25
		tw_t.one_shot = true
		tw_t.timeout.connect(func():
			if _cards.size() >= 4:
				var di: int = _cards.size() / 2
				_cards.remove_at(di)
				_uids.remove_at(di))   # R157：与 _cards 平行
		add_child(tw_t)
		tw_t.start()
		var tw_s := Timer.new()
		tw_s.wait_time = 0.37
		tw_s.one_shot = true
		tw_s.timeout.connect(func():
			var tw_img := get_viewport().get_texture().get_image()
			tw_img.save_png(ProjectSettings.globalize_path("screenshot_deck_edit.png"))
			get_tree().quit())
		add_child(tw_s)
		tw_s.start()
	# -- --pickshot：演示「点选高亮切换」（配 --mode 用；也可独立跑，自带演示卡组）——
	# 走**真实 _gui_input 路径**依次点第 0、1 张卡，每次落定后各截一张图，
	# 核验「点新卡 → 旧卡高亮熄灭、新卡高亮亮起」（修 deck_edit 高亮不切换 bug 的回归）。
	if "--pickshot" in args:
		if _cards.is_empty():
			RunState.deck_ids = [8001, 8002, 8003, 1011, 1013, 1050]
			_cards = RunState.deck_ids.duplicate()
			_reset_uids()
		var pt := Timer.new()
		pt.wait_time = 0.6
		pt.one_shot = true
		pt.timeout.connect(_run_pickshot)
		add_child(pt)
		pt.start()
	queue_redraw()
	# R148：Esc 主菜单
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "继续",
		"sub": "卡组编辑 · 按 Esc 返回",
	})


func _run_pickshot() -> void:
	## --pickshot 演示：走**真实输入路径**（_gui_input）依次点选，核验高亮切换。
	var steps := mini(2, _cards.size())
	for step in steps:
		# 卡片中心（Control 本地坐标）= _clip.position + _grid.position + 卡心（grid 本地坐标）
		var c: Vector2 = _clip.position + _grid.position + _card_rect(step).get_center()
		var dn := InputEventMouseButton.new()
		dn.button_index = MOUSE_BUTTON_LEFT
		dn.pressed = true
		dn.position = c
		_gui_input(dn)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = c
		_gui_input(up)
		await get_tree().create_timer(0.15).timeout   # 等几帧，让 queue_redraw 的重绘真正渲染出来
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("screenshot_pick_%d.png" % step))
	get_tree().quit()


func _process(_delta: float) -> void:
	# R186：滑位动画（_tween 非空）或鼠标移动时才重绘（原来无条件每帧重绘）。
	# R191：卡片画在 `_grid` 子节点上 → 重绘要连带它（hover 高亮 / 补间都在那边）。
	if not _tween.is_empty():
		_grid.queue_redraw()
		return
	var mp := get_local_mouse_position()
	if mp != _last_mp:
		_last_mp = mp
		_grid.queue_redraw()
		queue_redraw()


func _mode() -> String:
	## 当前模式："oblivion" = 事件「遗忘之泉」删卡 / "delete" = 失忆药水删卡 /
	## "smith" = 鸭鸭工匠锻造（把选中那张变成 2 费铁栅栏，R110）/ "" = 无待办（只读浏览）。
	if RunState.pending_deck_edit == "delete":
		return "oblivion"
	if RunState.pending_deck_edit == "smith":
		return "smith"
	if RunState.pending_deck_edit == "transform_class":
		return "transform_class"      # R305 卡片商人 · 旧换新
	if RunState.pending_deck_edit == "vendor":
		return "vendor"               # R305 卡片商人 · 以卡易物
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
		"transform_class":
			title_label.text = "卡片商人 — 选择一张卡换掉"
			hint_label.text = "点一张卡选中（高亮），再点下方「确定」，它会变成一张随机本职业奖励卡。"
		"vendor":
			title_label.text = "卡片商人 — 交出 5 费卡换大宝箱"
			hint_label.text = "只能选 5 费及以上的卡（其余卡点不动）。确认后得到：一件道具 + 一组卡牌奖励 + %d 金币。" \
					% RunState.BIGCHEST_GOLD
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

# R151 P1-11：增删补间 —— 每张卡按 id 记「当前显示位置」，目标位变了就从旧位滑过去（200ms）。
var _tween := {}   # uid(int) -> {from: Vector2, t0: int}（R157：键从卡 id 改成实例号）
var _last_mp := Vector2.INF      # R186：上次重绘时的鼠标位置（不动不重绘）
var _shown := {}   # uid(int) -> Vector2（当前显示位置；没有 = 还没画过，直接落目标位）


func _reset_uids() -> void:
	## R157：给每张卡发实例号。⚠️ 补间键**不能用卡 id** —— 重复 id 会共享一条位置记录，
	## 后画的同 id 卡发现「当前位置 ≠ 目标位」就从**另一张同名卡的位置**起滑（失忆药水乱飞案）。
	_uids.clear()
	for _c in _cards:
		_uids.append(_uid_next)
		_uid_next += 1


func _layout() -> void:
	## R191：固定 5 列大卡。卡宽由可用宽度决定（适配各种屏幕），卡高按宽高比换算、
	## 封顶 CARD_MAX_H；内容高超视区就走滚动（`_scroll`）。
	if _clip == null:
		return
	var area_w: float = maxf(200.0, size.x - MARGIN * 2.0)
	_cw = minf((area_w - GAP * (COLS - 1)) / float(COLS), CARD_MAX_H * RATIO)
	_ch = _cw / RATIO
	_clip.position = Vector2(MARGIN, TOP_Y)
	_clip.size = Vector2(area_w, maxf(60.0, size.y - TOP_Y - BOTTOM_RESERVE))
	var rows := maxi(1, int(ceil(float(maxi(_cards.size(), 1)) / float(COLS))))
	_grid.size = Vector2(area_w, GRID_PAD_TOP + rows * (_ch + GAP) - GAP)
	_clamp_scroll()


func _clamp_scroll() -> void:
	_scroll = clampf(_scroll, 0.0, maxf(0.0, _grid.size.y - _clip.size.y))
	_grid.position = Vector2(0, -_scroll)


func _tweened_rect(i: int, target: Rect2, now_ms: int) -> Rect2:
	## R151 P1-11：第 i 张卡的显示矩形 —— 增删后目标位变了，从旧位置平滑滑到新位置（200ms）。
	var id: int = _uids[i]   # R157：键 = 实例号（同名卡各有记录，不再互相顶位置）
	var tp := target.position
	if not _shown.has(id):
		_shown[id] = tp
		_tween.erase(id)
		return target
	var cur: Vector2 = _shown[id]
	if cur.distance_squared_to(tp) > 1.0 and not _tween.has(id):
		_tween[id] = {"from": cur, "t0": now_ms}
	if _tween.has(id):
		var tw: Dictionary = _tween[id]
		var k := clampf(float(now_ms - int(tw.t0)) / 200.0, 0.0, 1.0)
		cur = (tw["from"] as Vector2).lerp(tp, 1.0 - pow(1.0 - k, 2.0))
		if k >= 1.0:
			_tween.erase(id)
			cur = tp
	_shown[id] = cur
	return Rect2(cur, target.size)


func _row_x0(r: int) -> float:
	## 每行单独水平居中（grid 本地坐标），最后一行不满时也居中。
	var cnt := clampi(_cards.size() - r * COLS, 0, COLS)
	var w: float = cnt * _cw + maxf(0.0, cnt - 1) * GAP
	return maxf(0.0, (_clip.size.x - w) / 2.0)


func _card_rect(i: int) -> Rect2:
	## 第 i 张卡在 **grid 本地坐标系**里的矩形（补间键用它，滚动不影响补间）。
	if _cw <= 0.0:
		return Rect2()
	var r := i / COLS
	var c := i % COLS
	return Rect2(Vector2(_row_x0(r) + c * (_cw + GAP), GRID_PAD_TOP + r * (_ch + GAP)),
			Vector2(_cw, _ch))


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	# 背景（根节点自绘在子节点之下，BG 色块会盖住 _draw，故在这里画）
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.SCREEN_BG)   # R154：墨蓝夜色锚点（清单 §2.6）
	if _cards.is_empty():
		draw_string(_font, Vector2(0, size.y / 2), "卡组是空的……（点击继续）",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.INK_ON_DARK)
		return
	_layout()
	# R191 描述条：卡面只留卡名 → 点选/悬停的卡在这里读描述（画在网格区之下、按钮之上）
	var desc_idx := _hover
	if desc_idx < 0 and not _sel.is_empty():
		desc_idx = _sel[-1]
	if desc_idx >= 0 and desc_idx < _cards.size():
		var dc := repo.get_card(_cards[desc_idx])
		if dc != null:
			var dr := Rect2(MARGIN, size.y - BOTTOM_RESERVE + 6.0,
					size.x - MARGIN * 2.0, DESC_H)
			draw_rect(dr, Color(0.08, 0.07, 0.12, 0.88))
			draw_rect(dr, Color("ffd27d"), false, 1.2)
			draw_string(_font_bold, dr.position + Vector2(14, 26), dc.card_name,
					HORIZONTAL_ALIGNMENT_LEFT, 170.0, UiTheme.FS_BODY, Color("ffd27d"))
			draw_string(_font, dr.position + Vector2(14, 48),
					"%s · %d 费 · %s" % [dc.kind, dc.cost, dc.rarity_name()],
					HORIZONTAL_ALIGNMENT_LEFT, 170.0, UiTheme.FS_CAPTION, Color("9a94a8"))
			var lines := CardFace.wrap_text(_font, CardText.naturalize(dc.effect_text),
					dr.size.x - 210.0, UiTheme.FS_BODY)
			for li in mini(lines.size(), 3):
				draw_string(_font, dr.position + Vector2(196, 24 + li * 20), lines[li],
						HORIZONTAL_ALIGNMENT_LEFT, dr.size.x - 210.0, UiTheme.FS_BODY, Color("e8e2d4"))
	if _result != "":
		draw_string(_font_bold, Vector2(0, size.y - 72), _result,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, Color("c8e6a0"))


func _draw_grid() -> void:
	## 卡片网格（`_grid` 子节点自绘，本地坐标；滚出 `_clip` 视区的部分被裁掉）。
	var now_ms := Time.get_ticks_msec()
	for i in _cards.size():
		var rect := _card_rect(i)
		if rect.size.x <= 0.0:
			continue
		rect = _tweened_rect(i, rect, now_ms)   # R151 P1-11：增删后从旧位滑到新位（200ms）
		var selected := _sel.has(i)
		var hovered := i == _hover and not _done and not selected
		# 高亮底衬：选中 = 红底 + 金边发光；悬停 = 白色微亮
		if selected:
			_grid.draw_rect(rect.grow(UiTheme.CARD_BLEED), Color(0.80, 0.18, 0.14, 0.34), true)
			_grid.draw_rect(rect.grow(UiTheme.CARD_BLEED), UiTheme.ACCENT_GOLD, false, 2.0)
		elif hovered:
			_grid.draw_rect(rect.grow(5.0), Color(1, 1, 1, 0.10), true)
		var c := repo.get_card(_cards[i])
		if c != null:
			# R191：选卡场景卡面只留卡名（描述在底部描述条读）
			CardFace.draw_pick(_grid, c, rect, _font, _font_bold, selected)
		if selected:
			_draw_check_badge(_grid, rect)
	# R151 P1-11：清理已移除卡的残留位置记录（它们的槽位已被别的卡滑过来补上）
	for old_id in _shown.keys():
		if not _uids.has(old_id):
			_shown.erase(old_id)
			_tween.erase(old_id)


func _draw_check_badge(canvas: CanvasItem, rect: Rect2) -> void:
	## 选中角标：卡面右上角的红色对勾圆（不依赖字体，一定画得出来）。
	var r := clampf(rect.size.y * 0.075, 7.0, 12.0)
	var c := rect.position + Vector2(rect.size.x - r - 2.0, r + 2.0)
	canvas.draw_circle(c, r, UiTheme.STAT_HEALTH)
	canvas.draw_circle(c, r, Color("f4d47a"), false, 1.5)
	var s := r / 9.0
	canvas.draw_line(c + Vector2(-4.0, 0.0) * s, c + Vector2(-1.0, 3.4) * s, Color.WHITE, 2.0 * s)
	canvas.draw_line(c + Vector2(-1.0, 3.4) * s, c + Vector2(4.6, -3.2) * s, Color.WHITE, 2.0 * s)


# ------------------------------------------------------------ 交互

func _menu_items() -> Array:
	## 本界面的 Esc 菜单项（R148）。⚠️ 每次打开菜单都会重新调用（见 UiMenu.attach 注释），
	## 所以音效这类随状态变的文案永远是最新的。
	return [
		{"text": func(): return "音效：开" if sfx.enabled else "音效：关",
			"fn": _toggle_sound, "keep_open": true},
		{"text": "返回标题", "fn": _on_back_to_title},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _on_back_to_title() -> void:
	## R167：回标题 = **保留本局**（只复位内存状态，续档留着）。
	if RunState.run_active:
		RunState.end_run(false)
	SceneFx.goto("res://scenes/title.tscn")


func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# R191：滚轮滚动网格
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_scroll -= WHEEL_STEP
			_clamp_scroll()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_scroll += WHEEL_STEP
			_clamp_scroll()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and not _cards.is_empty():
			if mb.pressed:
				_press = {"pos": mb.position, "scroll": _scroll, "moved": false}
			else:
				var moved: bool = _press.get("moved", true)
				_press = {}
				if not moved:
					var pick := _index_at(mb.position)
					if pick >= 0:
						_hover = pick          # R294：点中的卡就是描述条当前显示的那张
						_toggle_sel(pick)     # 只改选中，不立即生效：可以反复改选
						sfx.play("click")
						_refresh_ui()
						queue_redraw()        # 描述条跟着换（画在根节点）
						_grid.queue_redraw()  # 卡片选中高亮画在 _grid 子节点 → 必须一起重绘，
						                      # 否则点新卡时高亮不切换（要等鼠标移动才刷新）
			accept_event()
			return
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not _press.is_empty():
			# R191：按住拖动 = 滚动网格
			var dy: float = mm.position.y - (_press["pos"] as Vector2).y
			if absf(dy) > DRAG_SLOP:
				_press["moved"] = true
			if _press.get("moved", false):
				_scroll = (_press["scroll"] as float) - dy
				_clamp_scroll()
			accept_event()
			return
		var idx := _index_at(mm.position)
		if idx != _hover:
			_hover = idx
	elif event is InputEventScreenTouch:
		# R191：触屏 —— 按下/抬指=点选，拖动=滚动（与鼠标同一套手势）
		var st := event as InputEventScreenTouch
		if st.pressed:
			_press = {"pos": st.position, "scroll": _scroll, "moved": false}
		else:
			var moved2: bool = _press.get("moved", true)
			_press = {}
			if not moved2 and not _cards.is_empty():
				var pick2 := _index_at(st.position)
				if pick2 >= 0:
					_hover = pick2         # R294：触屏没有 motion → 点选也要同步描述条
					_toggle_sel(pick2)
					sfx.play("click")
					_refresh_ui()
					queue_redraw()
					_grid.queue_redraw()   # 同鼠标：选中高亮在 _grid 上，触屏点选后也要即时重绘
		accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _press.is_empty():
			var dy2: float = sd.position.y - (_press["pos"] as Vector2).y
			if absf(dy2) > DRAG_SLOP:
				_press["moved"] = true
			if _press.get("moved", false):
				_scroll = (_press["scroll"] as float) - dy2
				_clamp_scroll()
		accept_event()


func _pick_allowed(pick: int) -> bool:
	## R305：卡片商人的「以卡易物」只收 **5 费及以上**的卡 —— 其它格子点了不选中，
	## 免得玩家以为「点得动就交得出」。
	if _mode() != "vendor":
		return true
	if pick < 0 or pick >= _cards.size():
		return false
	var c := repo.get_card(int(_cards[pick]))
	return c != null and c.cost >= RunState.MERCHANT_MIN_COST


func _toggle_sel(pick: int) -> void:
	## 选中 / 取消选中一个格子。**已满时点新的 → 替换最早选的那个**（单选模式
	## limit=1，这套逻辑自然退化成「点新的替换旧的」，与原行为一致）。
	if not _pick_allowed(pick):
		return
	if _sel.has(pick):
		_sel.erase(pick)
		return
	while _sel.size() >= _limit():
		_sel.remove_at(0)
	_sel.append(pick)


func _index_at(pos: Vector2) -> int:
	## 屏幕坐标 → 格子下标（-1 = 没点中）。先判在不在网格视区内（视区外不命中），
	## 再换算 grid 本地坐标（加滚动偏移）。
	if _clip == null or not Rect2(_clip.position, _clip.size).has_point(pos):
		return -1
	var local := pos - _clip.position - _grid.position
	for i in _cards.size():
		var rect := _card_rect(i)
		if rect.size.x > 0.0 and rect.grow(4.0).has_point(local):
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
	elif _mode() == "transform_class":
		var tc := RunState.transform_deck_card(repo, pick, true)
		var tc_card := repo.get_card(int(tc.get("new_id", 0)))
		_result = "「%s」变成了「%s」（本职业奖励卡）" % [cname,
				tc_card.card_name if tc_card != null else str(tc.get("new_id", 0))]
		RunState.pending_deck_edit = ""
	elif _mode() == "vendor":
		var vr := RunState.vendor_deck_card(repo, pick)
		if bool(vr.get("ok", false)):
			var rel_txt := "一件道具" if int(vr.get("relic_id", -1)) > 0 else "道具（已全拿完）"
			_result = "「%s」换来了大宝箱：%s + 一组卡牌奖励 + %d 金币" % [cname, rel_txt,
					int(vr.get("gold", 0))]
		else:
			_result = "易物失败：这张卡不是 5 费卡"
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
	# R151 P2-17：结算结果同时发一条跨场景轻提示（回到地图也看得见）
	if _result != "":
		UiToast.toast(_result)
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
	SceneFx.goto("res://scenes/map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	# R148：Esc = 主菜单（菜单开着时它自己关掉自己）
	if _menu != null and _menu.handle_esc(event):
		return
	# 卡组为空时点击任意处继续（防御：正常流程卡组不会为空）
	if _cards.is_empty() and event is InputEventMouseButton \
			and event.pressed and not _done:
		_done = true
		_go_back()
