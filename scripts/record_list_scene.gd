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
## R673：列表底部留白。原来只留 24 —— 1280x720 下算出 10 行，最后一行占到 y=684，
## 正压在页脚纸边和「第 N-M 条」那行上（用户口径「字压住框」）。留 48 后是 9 行，
## 最后一行收到 628，「第 N-M 条」（基线 684）上面还空 44。
const LIST_BOTTOM_PAD := 48.0

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
	UiTheme.attach_stage(self)   # R519：宽屏下内容居中，背景溢出铺满两侧
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
		"back": GameI18n.ui("shell", "RECORD_MENU_CONTINUE", "继续"),
		"sub": GameI18n.ui("shell", "RECORD_MENU_SUBTITLE", "对战记录"),
	})


func _menu_items() -> Array:
	return [
		{"text": func(): return GameI18n.ui("shell", "RECORD_SOUND_ON", "音效：开") if sfx.enabled else GameI18n.ui("shell", "RECORD_SOUND_OFF", "音效：关"),
			"fn": _toggle_sound, "keep_open": true},
		{"text": GameI18n.ui("shell", "RECORD_MENU_BACK_TITLE", "返回标题"), "fn": _back_to_title},
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
	return maxi(1, int((size.y - LIST_Y - LIST_BOTTOM_PAD) / ROW_H))


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
	UiTheme.draw_page(self, UiTheme.bleed_rect(self))   # R519：铺满窗口
	draw_string(_font_bold, Vector2(0, 62), GameI18n.ui("shell", "RECORD_TITLE", "对 战 记 录"),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_HEADING, UiTheme.PAGE_INK)
	var wins := 0
	for r: Dictionary in _rows:
		if str(r.get("result", "")) == "win":
			wins += 1
	draw_string(_font, Vector2(0, 94),
			GameI18n.ui("shell", "RECORD_SUMMARY", "共 %d 局 · 通关 %d 局（中断 / 中途放弃也会记在这里）") % [_rows.size(), wins],
			HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_LABEL, UiTheme.PAGE_MUTED)
	# 左上返回 / 右上清空
	var back := _back_rect()
	var hov_back := back.has_point(get_local_mouse_position())
	UiTheme.draw_action(self, back, false, false, hov_back)
	draw_string(_font_bold, back.position + Vector2(0, 22), GameI18n.ui("shell", "RECORD_BACK_TITLE", "← 返回标题"),
			HORIZONTAL_ALIGNMENT_CENTER, back.size.x, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	var cl := _clear_rect()
	var hov_cl := cl.has_point(get_local_mouse_position()) and not _rows.is_empty()
	draw_rect(cl, Color("8a3030") if _clear_armed else (Color("4a2c2c") if hov_cl
			else UiTheme.PAGE_PAPER), true)
	draw_rect(cl, Color(0, 0, 0, 0.35), false, 2.0)
	draw_string(_font_bold, cl.position + Vector2(0, 22),
			GameI18n.ui("shell", "RECORD_CLEAR_CONFIRM", "确认清空？") if _clear_armed else GameI18n.ui("shell", "RECORD_CLEAR", "清空记录"),
			HORIZONTAL_ALIGNMENT_CENTER, cl.size.x, UiTheme.FS_LABEL,
			Color("ffd8d8") if _clear_armed else UiTheme.PAGE_MUTED)
	if _rows.is_empty():
		draw_string(_font, Vector2(0, LIST_Y + 40),
				GameI18n.ui("shell", "RECORD_EMPTY", "还没有记录 —— 从标题「开始对战」打一局，结束后这里会有一行结果。"),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_BODY, UiTheme.PAGE_MUTED)
		return
	# R673：详情打开时**不画列表** —— 遮罩只有 0.55 黑压不住字，最后一行会从面板下沿
	# 漏出来，落在页脚纸边上（就是「字压住框」）。
	if _sel < 0:
		for i in _max_rows():
			var idx := _scroll + i
			if idx >= _rows.size():
				break
			_draw_row(idx, _rows[idx])
	if _sel >= 0 and _sel < _rows.size():
		_draw_detail()   # R241：详情盖在列表之上
	if _sel < 0 and _rows.size() > _max_rows():
		# R630：同故事页 / 禁卡页 —— -12 会被纸面九宫格的下边框横切，收到 -36。
		draw_string(_font, Vector2(0, size.y - 36),
				GameI18n.ui("shell", "RECORD_RANGE", "第 %d–%d 条 / 共 %d 条")
				% [_scroll + 1, mini(_scroll + _max_rows(), _rows.size()), _rows.size()],
				HORIZONTAL_ALIGNMENT_CENTER, size.x, UiTheme.FS_CAPTION,
				UiTheme.PAGE_MUTED)


# ------------------------------------------------------------ 详情（R241）

func _detail_rect() -> Rect2:
	return Rect2((size.x - 980.0) / 2.0, 96.0, 980.0, size.y - 148.0)


func _detail_close_rect() -> Rect2:
	## R673：右上角是 34px 角花，原来 +10 贴在花上；退到 +40 / -86 的花内空白处。
	var r := _detail_rect()
	return Rect2(r.end.x - 86.0, r.position.y + 40.0, 36.0, 30.0)


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
	# R367：已耗尽的道具**留在记录里**（钢盆碎了 / 绳子用掉）—— 名字加后缀并画灰。
	# 老记录没有 spent 字段 → 全视为生效。判定走 `RunRecord.is_spent_in()`（float 坑）。
	var out: Array = []
	for v: Variant in raw:
		var rel := repo.get_relic(int(v))
		if rel == null:
			continue
		var spent := RunRecord.is_spent_in(rec, int(v))
		# R343：名字另配一色（传奇金橙）—— `col` 仍是左侧圆点的徽章色。
		out.append({"name": (GameI18n.ui("shell", "RECORD_RELIC_SPENT", "%s（已耗尽）") % rel.relic_name) if spent else rel.relic_name,
				"col": Color("6a7078") if spent else rel.badge_color(),
				"ncol": Color("8d857a") if spent else rel.name_color(UiTheme.PAGE_INK)})
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
	## R673：面板九宫格四周各有 34px 角花 —— 内容原来从 +48 / +32 起算，结果标题左端被
	## 左上卷边切掉、字顶压在上边框花纹上，关闭钮和分隔线也都骑在角花上（用户口径
	## 「字压住框」）。这里统一把内容退到角花之内：左右 72、上 54、下 42。
	var r := _detail_rect()
	# 遮罩 + 面板
	draw_rect(UiTheme.bleed_rect(self), Color(0, 0, 0, 0.55), true)
	UiTheme.draw_panel_bg(self, r)
	var rec: Dictionary = _rows[_sel]
	var res := str(rec.get("result", ""))
	var x0 := r.position.x + 72.0
	var x1 := r.end.x - 72.0
	var top := r.position.y + 54.0
	var bot := r.end.y - 42.0
	# 标题：时间 + 结果
	draw_string(_font_bold, Vector2(x0, top),
			"%s · %s" % [RunRecord.fmt_time(str(rec.get("time", "?"))),
			RunRecord.result_label(res, int(rec.get("layer", -1)))],
			HORIZONTAL_ALIGNMENT_LEFT, 520, UiTheme.FS_HEADING,
			UiTheme.PAGE_INK)
	# 关闭
	var cr := _detail_close_rect()
	UiTheme.draw_close(self, cr, cr.has_point(get_local_mouse_position()))
	# 概览两行
	var seed_v := int(rec.get("seed", 0))
	draw_string(_font_bold, Vector2(x0, top + 26.0),
			GameI18n.ui("shell", "RECORD_SEED", "种子：%s") % ("—" if seed_v == 0 else RunState.seed_text_of(seed_v)),
			HORIZONTAL_ALIGNMENT_LEFT, 320, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	draw_string(_font, Vector2(x0 + 250.0, top + 26.0),
			GameI18n.ui("shell", "RECORD_CLASS_DIFFICULTY_TIME", "角色：%s · 难度 %d · 用时 %s")
			% [PlayerClass.legacy_id(str(rec.get("class", "?"))),
			int(rec.get("difficulty", 2)), RunRecord.fmt_secs(int(rec.get("secs", 0)))],
			HORIZONTAL_ALIGNMENT_LEFT, 640, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	var has_snap := rec.has("hp") or rec.has("deck") or rec.has("relics")
	if has_snap:
		var hp := int(rec.get("hp", 0))
		var mhp := int(rec.get("max_hp", 0))
		var hp_col := Color("e07a6a") if (res == "lose" or hp <= 0) else UiTheme.PAGE_GREEN
		draw_string(_font_bold, Vector2(x0, top + 50.0),
				GameI18n.ui("shell", "RECORD_HP", "生命 %d / %d") % [hp, mhp],
				HORIZONTAL_ALIGNMENT_LEFT, 220, UiTheme.FS_BODY, hp_col)
		draw_string(_font, Vector2(x0 + 250.0, top + 50.0),
				GameI18n.ui("shell", "RECORD_SNAPSHOT_STATS", "金币 %d · 层数 %d · 战斗胜场 %d（精英 %d）")
				% [int(rec.get("gold", 0)), int(rec.get("layer", 0)),
				int(rec.get("battles", 0)), int(rec.get("elites", 0))],
				HORIZONTAL_ALIGNMENT_LEFT, 640, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	# R367：每层打过的 Boss（老记录没有 `bosses` 字段 → 整行不画）
	var bosses: Variant = rec.get("bosses", [])
	if bosses is Array and not (bosses as Array).is_empty():
		var parts: Array[String] = []
		for b: Variant in bosses:
			if b is Dictionary:
				parts.append(GameI18n.ui("shell", "RECORD_BOSS_ITEM", "第 %d 层 · %s") % [int((b as Dictionary).get("layer", 0)),
						str((b as Dictionary).get("name", "?"))])
		draw_string(_font, Vector2(x0, top + 70.0),
				GameI18n.ui("shell", "RECORD_BOSS_LIST", "Boss：%s") % "　/　".join(parts),
				HORIZONTAL_ALIGNMENT_LEFT, 900, UiTheme.FS_LABEL, Color("e8b04a"))
	# 分隔线
	var sep_y := top + 88.0
	draw_line(Vector2(x0, sep_y), Vector2(x1, sep_y), Color("3d424e"), 1.0)
	var body_y := sep_y + 26.0
	if not has_snap:
		draw_string(_font, Vector2(r.position.x, body_y + 30.0),
				GameI18n.ui("shell", "RECORD_OLD_NO_SNAPSHOT", "这条记录是旧版本留下的，没有存最终道具 / 卡组（只记了结果与用时）。"),
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_BODY, UiTheme.PAGE_MUTED)
		return
	# ---- 左列：最终道具 ----
	var mid := r.position.x + 456.0
	draw_line(Vector2(mid - 14.0, body_y), Vector2(mid - 14.0, bot),
			Color("3d424e"), 1.0)
	var relics := _relic_entries(rec)
	draw_string(_font_bold, Vector2(x0, body_y),
			GameI18n.ui("shell", "RECORD_FINAL_RELICS", "最终道具（%d）") % relics.size(),
			HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	var ly := body_y + 24.0
	var max_rel := maxi(1, int((bot - ly) / 22.0))
	if relics.is_empty():
		draw_string(_font, Vector2(x0, ly + 14.0), GameI18n.ui("shell", "RECORD_NO_RELICS", "（这一局没有获得道具）"),
				HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_LABEL, UiTheme.PAGE_MUTED)
	else:
		for i in mini(relics.size(), max_rel):
			var e: Dictionary = relics[i]
			draw_circle(Vector2(x0 + 5.0, ly + 8.0), 4.0, e["col"])
			draw_string(_font, Vector2(x0 + 18.0, ly + 14.0), str(e["name"]),
					HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_LABEL,
					UiTheme.PAGE_INK)
			ly += 22.0
		if relics.size() > max_rel:
			draw_string(_font, Vector2(x0 + 18.0, ly + 14.0),
					GameI18n.ui("shell", "RECORD_MORE_RELICS", "…还有 %d 件") % (relics.size() - max_rel),
					HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)
	# ---- 右列：最终卡组（可滚轮） ----
	var deck := _deck_entries(rec)
	var total_cards := 0
	for e2: Dictionary in deck:
		total_cards += int(e2["n"])
	draw_string(_font_bold, Vector2(mid, body_y),
			GameI18n.ui("shell", "RECORD_FINAL_DECK", "最终卡组（%d 张 / %d 种）") % [total_cards, deck.size()],
			HORIZONTAL_ALIGNMENT_LEFT, 460, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	var dy := body_y + 24.0
	var row_h := 21.0
	# R673：底部界线从 `r.end.y - 16` 收到 `bot`（下角花 34 + 8）—— 原来多出来的十几行
	# 会把卡名画到下边框的花纹上；同时给「卡组 第 N–M 行」留一行位置。
	var max_deck := maxi(1, int((bot - 18.0 - dy) / row_h))
	var max_scroll := maxi(0, deck.size() - max_deck)
	if _deck_scroll > max_scroll:
		_deck_scroll = max_scroll
	for i2 in mini(max_deck, deck.size() - _deck_scroll):
		var d: Dictionary = deck[_deck_scroll + i2]
		var line := "%s ×%d" % [str(d["name"]), int(d["n"])] if int(d["n"]) > 1 \
				else str(d["name"])
		draw_string(_font, Vector2(mid, dy + 14.0), line,
				HORIZONTAL_ALIGNMENT_LEFT, 320, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
		var eid := str(d["ench"])
		if eid != "":
			draw_string(_font, Vector2(mid + 300.0, dy + 14.0),
					GameI18n.ui("shell", "RECORD_ENCHANT", "附魔：%s") % CardData.enchant_name(eid),
					HORIZONTAL_ALIGNMENT_LEFT, 170, UiTheme.FS_CAPTION,
					CardData.enchant_color(eid))
		dy += row_h
	if max_scroll > 0:
		draw_string(_font, Vector2(mid, bot),
				GameI18n.ui("shell", "RECORD_DECK_RANGE", "卡组 第 %d–%d 行 / 共 %d 行")
				% [_deck_scroll + 1, mini(_deck_scroll + max_deck, deck.size()), deck.size()],
				HORIZONTAL_ALIGNMENT_LEFT, 460, UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)


func _draw_row(idx: int, rec: Dictionary) -> void:
	var r := _row_rect(idx)
	var hov := idx == _hover
	draw_rect(r, UiTheme.ADVENTURE_INPUT if hov else UiTheme.PAGE_PAPER, true)
	draw_rect(r, UiTheme.ADVENTURE_BRASS if hov else UiTheme.ADVENTURE_BRASS, false, 1.6)
	var res := str(rec.get("result", ""))
	# 结果色条（左沿）：一眼分辨通关 / 失败 / 中断
	draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y),
			RunRecord.result_color(res), true)
	draw_string(_font_bold, r.position + Vector2(18, 22),
			RunRecord.fmt_time(str(rec.get("time", "?"))),
			HORIZONTAL_ALIGNMENT_LEFT, 220, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	draw_string(_font_bold, r.position + Vector2(246, 22),
			GameI18n.ui("shell", "RECORD_ROW_CLASS", "角色：%s") % PlayerClass.legacy_id(str(rec.get("class", "?"))),
			HORIZONTAL_ALIGNMENT_LEFT, 190, UiTheme.FS_BODY, UiTheme.PAGE_GREEN)
	draw_string(_font_bold, r.position + Vector2(446, 22),
			RunRecord.result_label(res, int(rec.get("layer", -1))),
			HORIZONTAL_ALIGNMENT_LEFT, 140, UiTheme.FS_BODY, UiTheme.PAGE_INK)
	draw_string(_font, r.position + Vector2(596, 22),
			GameI18n.ui("shell", "RECORD_ROW_DIFFICULTY_TIME", "难度 %d · 用时 %s") % [int(rec.get("difficulty", 2)),
			RunRecord.fmt_secs(int(rec.get("secs", 0)))],
			HORIZONTAL_ALIGNMENT_LEFT, 280, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	# R630：两行一起收（24/43 → 22/38）。行高 48（ROW_H 56 - 8）要塞 FS_BODY 16 + FS_CAPTION 12
	# 两行，第二行基线下探到 43 时字底已经贴住下框线（用户口径「可能压框」）。
	# 行距保持 16，底部留 7（原来 5），第一行顶部留 10。
	draw_string(_font, r.position + Vector2(18, 38),
			GameI18n.ui("shell", "RECORD_ROW_END_TIME", "结束于 %s") % RunRecord.fmt_time(str(rec.get("end", ""))),
			HORIZONTAL_ALIGNMENT_LEFT, 400, UiTheme.FS_CAPTION, UiTheme.PAGE_MUTED)
	# R261：种子码也列在列表行上（不用点进详情就能抄下来复现）
	var row_seed := int(rec.get("seed", 0))
	draw_string(_font, r.position + Vector2(430, 38),
			"种子：%s" % ("—" if row_seed == 0 else RunState.seed_text_of(row_seed)),
			HORIZONTAL_ALIGNMENT_LEFT, 220, UiTheme.FS_CAPTION, Color("b39a5e"))
