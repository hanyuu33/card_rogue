extends Control
## 对战记录（R215）—— 每局一行：开始时间 / 角色 / 结果 / 难度 / 用时。
## R241：**点一行可以看详情** —— 种子 / 最终生命与最大生命 / 金币 / 层数 / 胜场 /
## 最终道具 / 最终卡组（含附魔）。数据来自 `RunRecord.finish()` 存下的快照；
## 老记录没有快照 → 详情里只有上面那几项，并注明「旧记录没有详情」。
##
## 取代原「录像回放」页（R46 的完整回放机制已删）：只留**最终结果**，
## 通关 / 失败 / 中途放弃 / **中断**（关掉游戏没打完）都会有一行，
## 写入与中断判定见 `RunRecord`。文件：`user://run_records.json`。

const UiTheme = preload("res://scripts/ui_theme.gd")

const ROW_H := 56.0
const ROW_W := 980.0
const LIST_Y := 132.0

var _font: Font
var _font_bold: Font
var sfx: Sfx
var _menu: UiMenu = null
var _rows: Array = []            # 新在前：[{record}]——直接就是记录字典
var _hover := -1
var _scroll := 0                  # 首行下标（滚轮）
var _clear_armed := false         # 「清空」二次确认
var _sel := -1                    # R241：已打开详情的记录下标（-1 = 列表）
var _deck_scroll := 0             # R241：详情里卡组列的滚动偏移
var _last_mp := Vector2.INF


func _ready() -> void:
	_font = UiTheme.font()
	_font_bold = UiTheme.font_bold()
	sfx = Sfx.new()
	add_child(sfx)
	Bgm.play("title")
	DeckViewer.attach(self)
	RelicViewer.attach(self, Vector2(1044, 6))
	_refresh()
	# 演示参数（R241）：--detail [N] 打开第 N 行（默认 0）的详情 —— 出图核验用。
	var _da := OS.get_cmdline_user_args()
	var _di := _da.find("--detail")
	if _di >= 0 and not _rows.is_empty():
		_open_detail(int(_da[_di + 1]) if _di + 1 < _da.size() else 0)
	if "--screenshot" in OS.get_cmdline_user_args():
		var t := Timer.new()
		t.wait_time = 0.6
		t.one_shot = true
		t.timeout.connect(func():
			var img := get_viewport().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://screenshot_records.png"))
			get_tree().quit())
		add_child(t)
		t.start()
	_menu = UiMenu.attach(self, _menu_items, {
		"back": "继续",
		"sub": "对战记录 · 按 Esc 返回",
	})


func _menu_items() -> Array:
	return [
		{"text": func(): return "音效：开" if sfx.enabled else "音效：关",
			"fn": _toggle_sound, "keep_open": true},
		{"text": "返回标题", "fn": _back_to_title},
	]


func _toggle_sound() -> void:
	sfx.enabled = not sfx.enabled
	if sfx.enabled:
		sfx.play("click")


func _unhandled_input(event: InputEvent) -> void:
	# R241：详情打开时 Esc 先关详情（别直接弹 Esc 菜单）。
	if _sel >= 0 and event is InputEventKey and event.pressed \
			and event.keycode == KEY_ESCAPE:
		_close_detail()
		get_viewport().set_input_as_handled()
		return
	if _menu != null and _menu.handle_esc(event):
		return


func _refresh() -> void:
	var all := RunRecord.list_records()
	_rows = []
	for i in range(all.size() - 1, -1, -1):     # 新在前
		_rows.append(all[i])
	_scroll = 0
	_clear_armed = false
	queue_redraw()


func _process(_delta: float) -> void:
	var mp := get_local_mouse_position()
	if mp != _last_mp:
		_last_mp = mp
		queue_redraw()


# ------------------------------------------------------------ 布局

func _row_rect(i: int) -> Rect2:
	return Rect2((size.x - ROW_W) / 2.0, LIST_Y + (i - _scroll) * ROW_H,
			ROW_W, ROW_H - 8.0)


func _back_rect() -> Rect2:
	return Rect2(14, 14, 110, 34)


func _clear_rect() -> Rect2:
	## 左下角（右上角被「道具 / 牌库」两个查看器占着，别压上去）。
	return Rect2(14.0, size.y - 54.0, 124.0, 34.0)


func _max_rows() -> int:
	return maxi(1, int((size.y - LIST_Y - 24.0) / ROW_H))


func _row_at(pos: Vector2) -> int:
	var n := _max_rows()
	for i in n:
		var idx := _scroll + i
		if idx >= _rows.size():
			break
		if _row_rect(idx).has_point(pos):
			return idx
	return -1


# ------------------------------------------------------------ 输入

func _gui_input(event: InputEvent) -> void:
	# R241：详情面板打开时，输入全部交给面板自己处理（列表不响应）。
	if _sel >= 0:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if _detail_close_rect().has_point(event.position) \
						or not _detail_rect().has_point(event.position):
					sfx.play("click")
					_close_detail()
			return
		if event is InputEventMouseButton and event.pressed \
				and (event.button_index == MOUSE_BUTTON_WHEEL_DOWN
				or event.button_index == MOUSE_BUTTON_WHEEL_UP):
			var d_step := 3 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -3
			_deck_scroll = maxi(0, _deck_scroll + d_step)
			queue_redraw()
		return
	if event is InputEventMouseMotion:
		_hover = _row_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_clear_armed = false      # 点别处 → 取消「清空」待确认
		if _back_rect().has_point(event.position):
			sfx.play("click")
			_back_to_title()
			return
		var hit_row := _row_at(event.position)
		if hit_row >= 0:
			sfx.play("click")
			_open_detail(hit_row)   # R241：点一行看详情
			return
		if _clear_rect().has_point(event.position):
			if _rows.is_empty():
				return
			sfx.play("click")
			if not _clear_armed:
				_clear_armed = true
				queue_redraw()
				return
			RunRecord.clear_all()
			_refresh()
			sfx.play("attack")
			return
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_DOWN
			or event.button_index == MOUSE_BUTTON_WHEEL_UP):
		var step := 3 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -3
		var hi := maxi(0, _rows.size() - _max_rows())
		_scroll = clampi(_scroll + step, 0, hi)
		queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _menu != null:
			_menu.toggle()


func _back_to_title() -> void:
	SceneFx.goto("res://scenes/title.tscn")


# ------------------------------------------------------------ 绘制

func _draw() -> void:
	var top := Color("1c1f28")
	var bottom := Color("303443")
	for i in 36:
		var t := float(i) / 35.0
		draw_rect(Rect2(0, size.y * float(i) / 36.0, size.x, size.y / 36.0 + 1.0),
				top.lerp(bottom, t), true)
	draw_string(_font_bold, Vector2(0, 62), "对 战 记 录",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_HEADING, UiTheme.SAND)
	var wins := 0
	for r: Dictionary in _rows:
		if str(r.get("result", "")) == "win":
			wins += 1
	draw_string(_font, Vector2(0, 94),
			"共 %d 局 · 通关 %d 局（中断 / 中途放弃也会记在这里）" % [_rows.size(), wins],
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_LABEL, UiTheme.INK_ON_DARK)
	# 左上返回 / 右上清空
	var back := _back_rect()
	var hov_back := back.has_point(get_local_mouse_position())
	draw_rect(back, Color("414860") if hov_back else Color("343947"), true)
	draw_rect(back, Color(0, 0, 0, 0.35), false, 2.0)
	draw_string(_font_bold, back.position + Vector2(0, 22), "← 返回标题",
			HORIZONTAL_ALIGNMENT_CENTER, back.size.x, UiTheme.FS_LABEL, Color("e6e2d8"))
	var cl := _clear_rect()
	var hov_cl := cl.has_point(get_local_mouse_position()) and not _rows.is_empty()
	draw_rect(cl, Color("8a3030") if _clear_armed else (Color("4a2c2c") if hov_cl
			else Color("343947")), true)
	draw_rect(cl, Color(0, 0, 0, 0.35), false, 2.0)
	draw_string(_font_bold, cl.position + Vector2(0, 22),
			"确认清空？" if _clear_armed else "清空记录",
			HORIZONTAL_ALIGNMENT_CENTER, cl.size.x, UiTheme.FS_LABEL,
			Color("ffd8d8") if _clear_armed else Color("c8a8a8"))
	if _rows.is_empty():
		draw_string(_font, Vector2(0, LIST_Y + 40),
				"还没有记录 —— 从标题「开始对战」打一局，结束后这里会有一行结果。",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.INK_ON_DARK)
		return
	for i in _max_rows():
		var idx := _scroll + i
		if idx >= _rows.size():
			break
		_draw_row(idx, _rows[idx])
	if _sel >= 0 and _sel < _rows.size():
		_draw_detail()   # R241：详情盖在列表之上
	if _rows.size() > _max_rows():
		draw_string(_font, Vector2(0, size.y - 12),
				"滚轮翻页 · 第 %d–%d 条 / 共 %d 条"
				% [_scroll + 1, mini(_scroll + _max_rows(), _rows.size()), _rows.size()],
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION,
				UiTheme.INK_ON_DARK)
	# R241：列表底部提示「点一行看详情」（列表不长时也有地方说）
	if _rows.size() <= _max_rows():
		draw_string(_font, Vector2(0, size.y - 12), "点任意一行查看这局的最终详情",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION,
				Color("7d8590"))


# ------------------------------------------------------------ 详情（R241）

func _detail_rect() -> Rect2:
	return Rect2((size.x - 980.0) / 2.0, 96.0, 980.0, size.y - 148.0)


func _detail_close_rect() -> Rect2:
	var r := _detail_rect()
	return Rect2(r.end.x - 50.0, r.position.y + 10.0, 36.0, 30.0)


func _open_detail(idx: int) -> void:
	if idx < 0 or idx >= _rows.size():
		return
	_sel = idx
	_deck_scroll = 0
	_clear_armed = false
	_hover = -1
	queue_redraw()


func _close_detail() -> void:
	_sel = -1
	queue_redraw()


func _relic_entries(rec: Dictionary) -> Array:
	## 最终道具：[{name, col}]。拿不到定义的 id 跳过（同 RelicViewer 的口径）。
	var raw: Variant = rec.get("relics", [])
	if not (raw is Array):
		return []
	var repo := RelicRepo.load_json()
	var out: Array = []
	for v: Variant in raw:
		var rel := repo.get_relic(int(v))
		if rel == null:
			continue
		out.append({"name": rel.relic_name, "col": rel.source_color()})
	return out


func _deck_entries(rec: Dictionary) -> Array:
	## 最终卡组：按「卡 id + 附魔 id」合并同名同附魔 → [{name, n, ench}]。
	## 顺序沿用卡组顺序（第一张出现的先后），便于和牌库对照。
	var raw: Variant = rec.get("deck", [])
	if not (raw is Array):
		return []
	var repo := CardRepo.load_json()
	var out: Array = []
	var pos := {}
	for v: Variant in raw:
		if not (v is Dictionary):
			continue
		var cid := int((v as Dictionary).get("id", 0))
		var eid := str((v as Dictionary).get("e", ""))
		var key := "%d|%s" % [cid, eid]
		if pos.has(key):
			var hit: Dictionary = out[int(pos[key])]
			hit["n"] = int(hit["n"]) + 1
			continue
		var card := repo.get_card(cid)
		if card == null:
			continue          # 老记录里的卡 id 在当前卡表里没了 → 跳过（不显示空白行）
		pos[key] = out.size()
		out.append({"name": card.card_name, "n": 1, "ench": eid})
	return out


func _draw_detail() -> void:
	## 详情面板：上面概览（含种子 / 生命 / 最大生命），下面左道具右卡组。
	var r := _detail_rect()
	# 遮罩 + 面板
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55), true)
	draw_rect(r, Color("1e2129"), true)
	draw_rect(r, Color("6a768c"), false, 2.0)
	var rec: Dictionary = _rows[_sel]
	var res := str(rec.get("result", ""))
	var x0 := r.position.x + 24.0
	var x1 := r.end.x - 24.0
	# 标题：时间 + 结果
	draw_string(_font_bold, Vector2(x0, r.position.y + 32.0),
			"%s · %s" % [RunRecord.fmt_time(str(rec.get("time", "?"))),
			RunRecord.result_label(res)],
			HORIZONTAL_ALIGNMENT_LEFT, 520, UiTheme.FS_HEADING,
			RunRecord.result_color(res))
	# 关闭
	var cr := _detail_close_rect()
	draw_rect(cr, Color("4a2c2c") if cr.has_point(get_local_mouse_position())
			else Color("343947"), true)
	draw_string(_font_bold, cr.position + Vector2(0, 22),
			"×", HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, UiTheme.FS_BODY, Color("e6e2d8"))
	# 概览两行
	var seed_v := int(rec.get("seed", 0))
	draw_string(_font_bold, Vector2(x0, r.position.y + 58.0),
			"种子：%s" % ("—" if seed_v == 0 else RunState.seed_text_of(seed_v)),
			HORIZONTAL_ALIGNMENT_LEFT, 320, UiTheme.FS_LABEL, Color("f0c860"))
	draw_string(_font, Vector2(x0 + 250.0, r.position.y + 58.0),
			"角色：%s · 难度 %d · 用时 %s"
			% [PlayerClass.legacy_id(str(rec.get("class", "?"))),
			int(rec.get("difficulty", 2)), RunRecord.fmt_secs(int(rec.get("secs", 0)))],
			HORIZONTAL_ALIGNMENT_LEFT, 640, UiTheme.FS_LABEL, UiTheme.INK_300)
	var has_snap := rec.has("hp") or rec.has("deck") or rec.has("relics")
	if has_snap:
		var hp := int(rec.get("hp", 0))
		var mhp := int(rec.get("max_hp", 0))
		var hp_col := Color("e07a6a") if (res == "lose" or hp <= 0) else Color("9fd7a5")
		draw_string(_font_bold, Vector2(x0, r.position.y + 82.0),
				"生命 %d / %d" % [hp, mhp],
				HORIZONTAL_ALIGNMENT_LEFT, 220, UiTheme.FS_BODY, hp_col)
		draw_string(_font, Vector2(x0 + 250.0, r.position.y + 82.0),
				"金币 %d · 层数 %d · 战斗胜场 %d（精英 %d）"
				% [int(rec.get("gold", 0)), int(rec.get("layer", 0)),
				int(rec.get("battles", 0)), int(rec.get("elites", 0))],
				HORIZONTAL_ALIGNMENT_LEFT, 640, UiTheme.FS_LABEL, UiTheme.INK_300)
	# 分隔线
	var sep_y := r.position.y + 100.0
	draw_line(Vector2(x0, sep_y), Vector2(x1, sep_y), Color("3d424e"), 1.0)
	var body_y := sep_y + 26.0
	if not has_snap:
		draw_string(_font, Vector2(r.position.x, body_y + 30.0),
				"这条记录是旧版本留下的，没有存最终道具 / 卡组（只记了结果与用时）。",
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_BODY, Color("9a968c"))
		return
	# ---- 左列：最终道具 ----
	var mid := r.position.x + 456.0
	draw_line(Vector2(mid - 14.0, body_y), Vector2(mid - 14.0, r.end.y - 16.0),
			Color("3d424e"), 1.0)
	var relics := _relic_entries(rec)
	draw_string(_font_bold, Vector2(x0, body_y),
			"最终道具（%d）" % relics.size(),
			HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_BODY, UiTheme.SAND)
	var ly := body_y + 24.0
	var max_rel := maxi(1, int((r.end.y - 16.0 - ly) / 22.0))
	if relics.is_empty():
		draw_string(_font, Vector2(x0, ly + 14.0), "（这一局没有获得道具）",
				HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_LABEL, Color("7d8590"))
	else:
		for i in mini(relics.size(), max_rel):
			var e: Dictionary = relics[i]
			draw_circle(Vector2(x0 + 5.0, ly + 8.0), 4.0, e["col"])
			draw_string(_font, Vector2(x0 + 18.0, ly + 14.0), str(e["name"]),
					HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_LABEL, Color("d8d3c6"))
			ly += 22.0
		if relics.size() > max_rel:
			draw_string(_font, Vector2(x0 + 18.0, ly + 14.0),
					"…还有 %d 件" % (relics.size() - max_rel),
					HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_CAPTION, Color("7d8590"))
	# ---- 右列：最终卡组（可滚轮） ----
	var deck := _deck_entries(rec)
	var total_cards := 0
	for e2: Dictionary in deck:
		total_cards += int(e2["n"])
	draw_string(_font_bold, Vector2(mid, body_y),
			"最终卡组（%d 张 / %d 种）" % [total_cards, deck.size()],
			HORIZONTAL_ALIGNMENT_LEFT, 460, UiTheme.FS_BODY, UiTheme.SAND)
	var dy := body_y + 24.0
	var row_h := 21.0
	var max_deck := maxi(1, int((r.end.y - 16.0 - dy) / row_h))
	var max_scroll := maxi(0, deck.size() - max_deck)
	if _deck_scroll > max_scroll:
		_deck_scroll = max_scroll
	for i2 in mini(max_deck, deck.size() - _deck_scroll):
		var d: Dictionary = deck[_deck_scroll + i2]
		var line := "%s ×%d" % [str(d["name"]), int(d["n"])] if int(d["n"]) > 1 \
				else str(d["name"])
		draw_string(_font, Vector2(mid, dy + 14.0), line,
				HORIZONTAL_ALIGNMENT_LEFT, 320, UiTheme.FS_LABEL, Color("d8d3c6"))
		var eid := str(d["ench"])
		if eid != "":
			draw_string(_font, Vector2(mid + 300.0, dy + 14.0),
					"附魔：" + CardData.enchant_name(eid),
					HORIZONTAL_ALIGNMENT_LEFT, 170, UiTheme.FS_CAPTION,
					CardData.enchant_color(eid))
		dy += row_h
	if max_scroll > 0:
		draw_string(_font, Vector2(mid, r.end.y - 16.0),
				"滚轮翻卡组 · 第 %d–%d 行 / 共 %d 行"
				% [_deck_scroll + 1, mini(_deck_scroll + max_deck, deck.size()), deck.size()],
				HORIZONTAL_ALIGNMENT_LEFT, 460, UiTheme.FS_CAPTION, Color("7d8590"))


func _draw_row(idx: int, rec: Dictionary) -> void:
	var r := _row_rect(idx)
	var hov := idx == _hover
	draw_rect(r, Color("3a4152") if hov else Color("22242c"), true)
	draw_rect(r, Color("6a768c") if hov else Color("4a4e58"), false, 1.6)
	var res := str(rec.get("result", ""))
	# 结果色条（左沿）：一眼分辨通关 / 失败 / 中断
	draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y),
			RunRecord.result_color(res), true)
	draw_string(_font_bold, r.position + Vector2(18, 24),
			RunRecord.fmt_time(str(rec.get("time", "?"))),
			HORIZONTAL_ALIGNMENT_LEFT, 220, UiTheme.FS_BODY, UiTheme.SAND)
	draw_string(_font_bold, r.position + Vector2(246, 24),
			"角色：%s" % PlayerClass.legacy_id(str(rec.get("class", "?"))),
			HORIZONTAL_ALIGNMENT_LEFT, 190, UiTheme.FS_BODY, Color("9fd7a5"))
	draw_string(_font_bold, r.position + Vector2(446, 24), RunRecord.result_label(res),
			HORIZONTAL_ALIGNMENT_LEFT, 140, UiTheme.FS_BODY, RunRecord.result_color(res))
	draw_string(_font, r.position + Vector2(596, 24),
			"难度 %d · 用时 %s" % [int(rec.get("difficulty", 2)),
			RunRecord.fmt_secs(int(rec.get("secs", 0)))],
			HORIZONTAL_ALIGNMENT_LEFT, 280, UiTheme.FS_LABEL, UiTheme.INK_300)
	draw_string(_font, r.position + Vector2(18, 43),
			"结束于 %s" % RunRecord.fmt_time(str(rec.get("end", ""))),
			HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_CAPTION, Color("7d8590"))
	# R261：种子码也列在列表行上（不用点进详情就能抄下来复现）
	var row_seed := int(rec.get("seed", 0))
	draw_string(_font, r.position + Vector2(430, 43),
			"种子：%s" % ("—" if row_seed == 0 else RunState.seed_text_of(row_seed)),
			HORIZONTAL_ALIGNMENT_LEFT, 220, UiTheme.FS_CAPTION, Color("b39a5e"))
